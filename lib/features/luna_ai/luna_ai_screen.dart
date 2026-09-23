import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/luna_memory_entry.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../core/services/deepseek_service.dart';
import '../../core/services/period_date_extractor.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/bottom_nav.dart';

String _monthName(int m) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (m >= 1 && m <= 12) return months[m - 1];
  return '';
}

String _formatPeriodDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'today (${_monthName(d.month)} ${d.day})';
  if (diff == 1) return 'yesterday (${_monthName(d.month)} ${d.day})';
  if (diff == 2) return '2 days ago (${_monthName(d.month)} ${d.day})';
  if (d.year == now.year) {
    return '${_monthName(d.month)} ${d.day}';
  }
  return '${_monthName(d.month)} ${d.day}, ${d.year}';
}

class LunaAiScreen extends ConsumerStatefulWidget {
  const LunaAiScreen({super.key});

  @override
  ConsumerState<LunaAiScreen> createState() => _LunaAiScreenState();
}

class _LunaAiScreenState extends ConsumerState<LunaAiScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    if (_chatMode) {
      setState(() {
        _chatMode = false;
        _chatLoading = false;
      });
      return true;
    }
    if (context.canPop()) {
      context.pop();
      return true;
    }
    context.go('/home');
    return true;
  }

  MoodLevel? _selectedMood;
  final Set<String> _selectedSymptoms = {};
  final _textController = TextEditingController();
  final _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showTextInput = false;
  LunaResponse? _response;
  bool _loading = false;
  bool _chatLoading = false;
  bool _chatMode = false;
  bool _showScienceCard = false;
  String? _lastAutoLogSummary;
  bool _isCheckInLogExpanded = false;
  final Set<int> _expandedChatLogIndices = {};
  List<_ChatMessage> _chatHistory = [];
  DateTime? _pendingPeriodDate;
  DateTime? _pendingStopDate;
  late AnimationController _pulseController;

  static const List<String> _quickSymptoms = [
    'Headache',
    'Brain fog',
    'Fatigue',
    'Cramps',
    'Bloating',
    'Anxious',
    'Irritable',
    'Cravings',
    'Backache',
    'Tender',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Bug 10 fix: restore last chat session from persistence
    _loadChatHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todayEntry = ref.read(todayLogProvider);
      if (todayEntry != null && mounted) {
        setState(() {
          _selectedMood ??= todayEntry.mood;
          _selectedSymptoms.addAll(todayEntry.symptoms);
        });
      }
    });
  }

  void _loadChatHistory() {
    final raw = StorageService.getLastChatSession();
    if (raw.isNotEmpty) {
      try {
        final messages = raw.map(_ChatMessage.fromMap).toList();
        DateTime? pending;
        for (int i = messages.length - 1; i >= 0; i--) {
          if (messages[i].pendingPeriodDate != null &&
              messages[i].periodDateConfirmed == null) {
            pending = messages[i].pendingPeriodDate;
            break;
          }
        }
        setState(() {
          _chatHistory = messages;
          _pendingPeriodDate = pending;
        });
      } catch (_) {}
    }
  }

  void _persistChatHistory() {
    StorageService.saveLastChatSession(
        _chatHistory.map((m) => m.toMap()).toList());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (_selectedMood == null && _textController.text.trim().isEmpty) return;
    if (_loading) return;

    // Clear previous session when user starts a fresh check-in
    await StorageService.clearLastChatSession();
    setState(() {
      _chatHistory = [];
      _lastAutoLogSummary = null;
      _isCheckInLogExpanded = false;
      _expandedChatLogIndices.clear();
    });

    final userText = _textController.text.trim();
    setState(() {
      _loading = true;
      _response = null;
    });

    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final todayEntry = ref.read(todayLogProvider);
    final patternProfile = ref.read(patternProfileProvider);
    final gapAnalysis = ref.read(cycleGapAnalysisProvider);
    if (profile == null || cycleState == null) {
      setState(() => _loading = false);
      return;
    }

    final hasCycleAnchor =
        profile.lastPeriodStart != null && cycleState.dayOfCycle > 0;
    final allSymptoms =
        {..._selectedSymptoms, ...?todayEntry?.symptoms}.toList();

    LunaResponse response;
    if (userText.isNotEmpty) {
      response = await DeepSeekService.getFreeTextResponse(
        userName: profile.name,
        hasCycleAnchor: hasCycleAnchor,
        phase: cycleState.phase,
        dayOfCycle: cycleState.dayOfCycle,
        cycleLength: profile.averageCycleLength,
        userMessage: userText,
        mood: _selectedMood ?? todayEntry?.mood,
        energyLevel: todayEntry?.energyLevel,
        symptoms: allSymptoms,
        patternProfile: patternProfile,
        gapAnalysis: gapAnalysis,
      );
    } else {
      response = await DeepSeekService.getMoodResponse(
        userName: profile.name,
        hasCycleAnchor: hasCycleAnchor,
        phase: cycleState.phase,
        dayOfCycle: cycleState.dayOfCycle,
        cycleLength: profile.averageCycleLength,
        mood: _selectedMood!,
        energyLevel: todayEntry?.energyLevel,
        symptoms: allSymptoms,
        patternProfile: patternProfile,
        gapAnalysis: gapAnalysis,
      );
    }

    // Auto-log immediately on check-in from the Luna Home Screen Phase!
    final autoLogSummary = await _processAutoLog(
      logMap: response.logMap,
      userText: userText,
      fallbackMood: _selectedMood,
      fallbackSymptoms: _selectedSymptoms.toList(),
    );

    // Store the user message text before we clear for check-in history seeding
    _lastUserText = userText;
    setState(() {
      _response = response;
      _lastAutoLogSummary = autoLogSummary;
      _loading = false;
    });
  }

  /// Holds the user message text used in the check-in, for seeding chat history
  String _lastUserText = '';

  void _enterChatMode() {
    final userMsg = _lastUserText.isNotEmpty
        ? _lastUserText
        : _selectedMood != null
            ? '${_selectedMood!.emoji} ${_selectedMood!.label}'
            : 'Hey Luna';

    setState(() {
      _chatHistory = [
        _ChatMessage(text: userMsg, isUser: true, time: DateTime.now()),
        _ChatMessage(
          text: _response!.validation,
          isUser: false,
          time: DateTime.now(),
          autoLogNote: null,
        ),
      ];
      _chatMode = true;
    });

    // Persist the initial conversation seed
    _persistChatHistory();

    _scrollToBottom();
  }

  Future<void> _confirmPeriodDateUpdate(DateTime date, [int? msgIndex]) async {
    await ref.read(periodHistoryProvider.notifier).updatePeriodStart(date);

    final currentToday = ref.read(todayLogProvider);
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday && currentToday?.periodStarted == true) {
      final updatedToday = currentToday!.copyWith(periodStarted: false);
      await ref.read(logEntriesProvider.notifier).addEntry(updatedToday);
    }

    setState(() {
      if (msgIndex != null && msgIndex < _chatHistory.length) {
        _chatHistory[msgIndex] =
            _chatHistory[msgIndex].copyWith(periodDateConfirmed: true);
      } else {
        for (int i = _chatHistory.length - 1; i >= 0; i--) {
          if (_chatHistory[i].pendingPeriodDate != null &&
              _chatHistory[i].periodDateConfirmed == null) {
            _chatHistory[i] =
                _chatHistory[i].copyWith(periodDateConfirmed: true);
            break;
          }
        }
      }
      final dateStr = _formatPeriodDate(date);
      _chatHistory.add(
        _ChatMessage(
          text:
              'Done! I\'ve updated your period start date to $dateStr. Your cycle days and phase calculations are now aligned 🌙',
          isUser: false,
          time: DateTime.now(),
        ),
      );
      _pendingPeriodDate = null;
    });

    _persistChatHistory();
    _scrollToBottom();
  }

  Future<void> _rejectPeriodDateUpdate([int? msgIndex]) async {
    setState(() {
      if (msgIndex != null && msgIndex < _chatHistory.length) {
        _chatHistory[msgIndex] =
            _chatHistory[msgIndex].copyWith(periodDateConfirmed: false);
      } else {
        for (int i = _chatHistory.length - 1; i >= 0; i--) {
          if (_chatHistory[i].pendingPeriodDate != null &&
              _chatHistory[i].periodDateConfirmed == null) {
            _chatHistory[i] =
                _chatHistory[i].copyWith(periodDateConfirmed: false);
            break;
          }
        }
      }
      _chatHistory.add(
        _ChatMessage(
          text: 'Understood, I\'ve kept your cycle dates as they were.',
          isUser: false,
          time: DateTime.now(),
        ),
      );
      _pendingPeriodDate = null;
    });

    _persistChatHistory();
    _scrollToBottom();
  }

  Future<void> _confirmPeriodStop(DateTime stopDate) async {
    final allEntries = ref.read(logEntriesProvider);
    final stopEntry = allEntries.where((e) =>
        e.date.year == stopDate.year &&
        e.date.month == stopDate.month &&
        e.date.day == stopDate.day).firstOrNull;

    if (stopEntry != null) {
      final updated = stopEntry.copyWith(flow: null, periodStarted: false);
      await ref.read(logEntriesProvider.notifier).addEntry(updated);
    }

    final profile = ref.read(profileProvider);
    final history = ref.read(periodHistoryProvider);
    final anchor = profile != null ? CycleEngine.findCycleStart(stopDate, profile, history) : null;
    int? durationDays;
    if (anchor != null) {
      durationDays = stopDate.calendarDaysDifference(anchor) + 1;
    }

    final stopStr = _formatPeriodDate(stopDate);
    setState(() {
      _chatHistory.add(
        _ChatMessage(
          text: durationDays != null
              ? 'Recorded: bleeding has ended on $stopStr ($durationDays-day duration). I\'ve updated your cycle tracking 🌸'
              : 'Recorded: bleeding has ended on $stopStr. I\'ve updated your cycle tracking 🌸',
          isUser: false,
          time: DateTime.now(),
        ),
      );
      _pendingStopDate = null;
    });

    _persistChatHistory();
    _scrollToBottom();
  }

  Future<void> _rejectPeriodStop() async {
    setState(() {
      _chatHistory.add(
        _ChatMessage(
          text: 'Understood, I\'ve kept your bleeding logs as they were.',
          isUser: false,
          time: DateTime.now(),
        ),
      );
      _pendingStopDate = null;
    });
    _persistChatHistory();
    _scrollToBottom();
  }

  Future<void> _sendChatMessage([String? prefilledText]) async {
    final text = prefilledText ?? _chatController.text.trim();
    if (text.isEmpty || _chatLoading) return;
    if (prefilledText == null) {
      _chatController.clear();
    }

    // ── Pending Stop Interception ──────────────────────────────────────────
    if (_pendingStopDate != null) {
      if (PeriodDateExtractor.isConfirmation(text)) {
        setState(() {
          _chatHistory.add(
              _ChatMessage(text: text, isUser: true, time: DateTime.now()));
        });
        await _confirmPeriodStop(_pendingStopDate!);
        return;
      } else if (PeriodDateExtractor.isCancellation(text)) {
        setState(() {
          _chatHistory.add(
              _ChatMessage(text: text, isUser: true, time: DateTime.now()));
        });
        await _rejectPeriodStop();
        return;
      }
    }

    // ── Pending Date Confirmation Interception ─────────────────────────────
    if (_pendingPeriodDate != null) {
      if (PeriodDateExtractor.isConfirmation(text)) {
        setState(() {
          _chatHistory.add(
              _ChatMessage(text: text, isUser: true, time: DateTime.now()));
        });
        await _confirmPeriodDateUpdate(_pendingPeriodDate!);
        return;
      } else if (PeriodDateExtractor.isCancellation(text)) {
        setState(() {
          _chatHistory.add(
              _ChatMessage(text: text, isUser: true, time: DateTime.now()));
        });
        await _rejectPeriodDateUpdate();
        return;
      }
    }

    final targetResult = PeriodDateExtractor.extractTargetDate(text);
    final requestedPeriodDate = PeriodDateExtractor.extractDate(text);
    final cycleDay = PeriodDateExtractor.extractCycleDay(text);
    final hasPeriodStop = PeriodDateExtractor.hasPeriodStopIntent(text);

    final isDirectCommand = requestedPeriodDate != null &&
        (PeriodDateExtractor.isDirectCorrectionCommand(text) || cycleDay != null);

    if (isDirectCommand) {
      // Direct explicit user command: apply update to SQLite & Riverpod immediately
      await ref.read(periodHistoryProvider.notifier).updatePeriodStart(requestedPeriodDate);

      final currentToday = ref.read(todayLogProvider);
      final now = DateTime.now();
      final isToday = requestedPeriodDate.year == now.year &&
          requestedPeriodDate.month == now.month &&
          requestedPeriodDate.day == now.day;
      if (!isToday && currentToday?.periodStarted == true) {
        final updatedToday = currentToday!.copyWith(periodStarted: false);
        await ref.read(logEntriesProvider.notifier).addEntry(updatedToday);
      }
      _pendingPeriodDate = null;
    }

    if (targetResult.isFuture) {
      // Save expectation in companion memory so Luna can check in tomorrow!
      await StorageService.saveMemory(
        LunaMemoryEntry(
          id: LunaMemoryEntry.newId(),
          category: 'body_pattern',
          content: 'Expected to experience: ${text.trim()}',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (hasPeriodStop) {
      final stopDate = targetResult.date;
      final allEntries = ref.read(logEntriesProvider);
      final stopEntry = allEntries.where((e) =>
          e.date.year == stopDate.year &&
          e.date.month == stopDate.month &&
          e.date.day == stopDate.day).firstOrNull;

      final hadHeavyOrMediumFlow = stopEntry?.flow == FlowLevel.heavy || stopEntry?.flow == FlowLevel.medium;
      if (hadHeavyOrMediumFlow && !PeriodDateExtractor.isConfirmation(text)) {
        _pendingStopDate = stopDate;
      } else {
        if (stopEntry != null) {
          final updated = stopEntry.copyWith(flow: null, periodStarted: false);
          await ref.read(logEntriesProvider.notifier).addEntry(updated);
        }
      }
    }

    setState(() {
      _chatHistory.add(
          _ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _chatLoading = true;
    });
    _scrollToBottom();

    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final todayEntry = ref.read(todayLogProvider);
    final patternProfile = ref.read(patternProfileProvider);
    final gapAnalysis = ref.read(cycleGapAnalysisProvider);
    if (profile == null || cycleState == null) {
      setState(() => _chatLoading = false);
      return;
    }

    final hasCycleAnchor =
        profile.lastPeriodStart != null && cycleState.dayOfCycle > 0;
    final allSymptoms =
        {..._selectedSymptoms, ...?todayEntry?.symptoms}.toList();

    final conversationMessages = _chatHistory
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    if (isDirectCommand) {
      final dateStr = _formatPeriodDate(requestedPeriodDate);
      conversationMessages.add({
        'role': 'system',
        'content':
            'SYSTEM CONFIRMATION: The app has already directly updated her cycle start date to $dateStr. Her cycle is now aligned to Day ${cycleState.dayOfCycle} · Menstrual. Acknowledge this with sisterly warmth and reassure her that her cycle is aligned.',
      });
    }

    if (targetResult.isFuture) {
      conversationMessages.add({
        'role': 'system',
        'content':
            'SYSTEM INSTRUCTION: The user mentioned a future date (${targetResult.futureSummary ?? 'in the future'}). Luna strictly cannot log future dates. Playfully, warmly and gently explain that you can\'t see the future yet, but reassure her you have remembered her prediction so you can check in on her then! DO NOT output any [LOG:...] tag.',
      });
    }

    if (hasPeriodStop) {
      final stopDate = targetResult.date;
      final allEntries = ref.read(logEntriesProvider);
      final stopEntry = allEntries.where((e) =>
          e.date.year == stopDate.year &&
          e.date.month == stopDate.month &&
          e.date.day == stopDate.day).firstOrNull;
      final hadHeavyOrMediumFlow = stopEntry?.flow == FlowLevel.heavy || stopEntry?.flow == FlowLevel.medium;
      if (hadHeavyOrMediumFlow && !PeriodDateExtractor.isConfirmation(text)) {
        conversationMessages.add({
          'role': 'system',
          'content':
              'SYSTEM CONTRADICTION: The user indicates her bleeding stopped, but she previously logged ${stopEntry!.flow!.name} flow for this day. Ask her gently with sisterly warmth if bleeding has fully ended now, so you can update her cycle record.',
        });
      } else {
        final anchor = CycleEngine.findCycleStart(stopDate, profile, ref.read(periodHistoryProvider));
        int? durationDays;
        if (anchor != null) {
          durationDays = stopDate.calendarDaysDifference(anchor) + 1;
        }
        conversationMessages.add({
          'role': 'system',
          'content':
              'SYSTEM CONFIRMATION: The app has recorded that bleeding ended on ${_formatPeriodDate(stopDate)}${durationDays != null ? ' (duration: $durationDays days)' : ''}. ${durationDays != null && durationDays <= 3 ? 'This 3-day bleed is shorter than her typical rhythm. Acknowledge this variation with biological warmth (stress, lower estrogen peak, or lighter cycle).' : 'Acknowledge this with sisterly warmth.'}',
        });
      }
    }

    final response = await DeepSeekService.getChatMessage(
      userName: profile.name,
      hasCycleAnchor: hasCycleAnchor,
      phase: cycleState.phase,
      dayOfCycle: cycleState.dayOfCycle,
      cycleLength: profile.averageCycleLength,
      mood: _selectedMood ?? todayEntry?.mood,
      energyLevel: todayEntry?.energyLevel,
      symptoms: allSymptoms,
      patternProfile: patternProfile,
      gapAnalysis: gapAnalysis,
      messages: conversationMessages,
    );

    // Extract [LOG:... if present in chat response
    String cleanResponse = response;
    String? rawLog;
    final logStartIdx = response.indexOf('[LOG:');
    if (logStartIdx != -1) {
      cleanResponse = response.substring(0, logStartIdx).trim();
      rawLog = response.substring(logStartIdx + 5).trim();
    }

    // Process auto-log with multi-layer parsing (JSON + regex + userText heuristics)
    final autoLogSummary = await _processAutoLog(
      rawAiLog: rawLog,
      userText: text,
      hasSpecificDateRequest: requestedPeriodDate != null,
    );

    // Safety clean: strip any dangling [LOG:... or trailing brackets from text
    cleanResponse =
        cleanResponse.replaceAll(RegExp(r'\s*\[LOG:[^\]]*\]?'), '').trim();
    cleanResponse = cleanResponse.replaceAll(RegExp(r'\]+$'), '').trim();

    if (requestedPeriodDate != null) {
      final dateStr = _formatPeriodDate(requestedPeriodDate);
      if (isDirectCommand) {
        // Clear any older pending confirmation cards
        for (int i = 0; i < _chatHistory.length; i++) {
          if (_chatHistory[i].pendingPeriodDate != null &&
              _chatHistory[i].periodDateConfirmed == null) {
            _chatHistory[i] =
                _chatHistory[i].copyWith(periodDateConfirmed: false);
          }
        }
        _pendingPeriodDate = null;
      } else {
        // Supersede any older pending confirmation cards in history
        for (int i = 0; i < _chatHistory.length; i++) {
          if (_chatHistory[i].pendingPeriodDate != null &&
              _chatHistory[i].periodDateConfirmed == null) {
            _chatHistory[i] =
                _chatHistory[i].copyWith(periodDateConfirmed: false);
          }
        }
        _pendingPeriodDate = requestedPeriodDate;
        final lower = cleanResponse.toLowerCase();
        if (!lower.contains('?') && !lower.contains(dateStr.toLowerCase())) {
          cleanResponse +=
              '\n\nWould you like me to update your period start date to $dateStr?';
        }
      }
    }

    setState(() {
      _chatHistory.add(
        _ChatMessage(
          text: cleanResponse,
          isUser: false,
          time: DateTime.now(),
          autoLogNote: autoLogSummary,
          pendingPeriodDate: requestedPeriodDate,
          periodDateConfirmed: isDirectCommand ? true : null,
        ),
      );
      _chatLoading = false;
    });
    // Persist after each new Luna response
    _persistChatHistory();
    _scrollToBottom();
  }

  /// Unified multi-layer auto-logging engine:
  /// Combines AI structured JSON log, tag parsing, and deterministic text heuristics.
  Future<String?> _processAutoLog({
    String? rawAiLog,
    Map<String, dynamic>? logMap,
    required String userText,
    MoodLevel? fallbackMood,
    List<String>? fallbackSymptoms,
    bool hasSpecificDateRequest = false,
  }) async {
    bool? detectedPeriodStarted;
    FlowLevel? detectedFlow;
    CrampLevel? detectedCramps;
    MoodLevel? detectedMood = fallbackMood;
    int? detectedEnergy;
    SleepQuality? detectedSleep;
    String? detectedNotes;
    String? detectedMemoryCategory;
    String? detectedMemoryNote;
    String? detectedDateStr;
    final detectedSymptoms = <String>[...?fallbackSymptoms];

    // 1. Process logMap (from AI JSON response)
    if (logMap != null) {
      if (logMap['date'] is String) {
        final dStr = (logMap['date'] as String).trim();
        if (dStr.isNotEmpty) detectedDateStr = dStr;
      }

      if (logMap['periodStarted'] is bool) {
        detectedPeriodStarted = logMap['periodStarted'] as bool;
      } else if (logMap['periodStarted'] is String) {
        detectedPeriodStarted =
            (logMap['periodStarted'] as String).toLowerCase() == 'true';
      }

      if (logMap['flow'] is String) {
        final fStr = (logMap['flow'] as String).toLowerCase().trim();
        detectedFlow = FlowLevel.values.cast<FlowLevel?>().firstWhere(
              (f) => f?.name.toLowerCase() == fStr,
              orElse: () => null,
            );
      }

      if (logMap['cramps'] is String) {
        final cStr = (logMap['cramps'] as String).toLowerCase().trim();
        detectedCramps = CrampLevel.values.cast<CrampLevel?>().firstWhere(
              (c) => c?.name.toLowerCase() == cStr,
              orElse: () => null,
            );
      }

      if (logMap['mood'] is String) {
        final mStr = (logMap['mood'] as String).toLowerCase().trim();
        detectedMood = MoodLevel.values.cast<MoodLevel?>().firstWhere(
              (m) => m?.name.toLowerCase() == mStr,
              orElse: () => detectedMood,
            );
      }

      if (logMap['energy'] is num) {
        detectedEnergy = (logMap['energy'] as num).toInt();
      } else if (logMap['energy'] is String) {
        detectedEnergy = int.tryParse(logMap['energy'] as String);
      }

      if (logMap['sleep'] is String) {
        final sStr = (logMap['sleep'] as String).toLowerCase().trim();
        detectedSleep = SleepQuality.values.cast<SleepQuality?>().firstWhere(
              (s) => s?.name.toLowerCase() == sStr,
              orElse: () => null,
            );
      }

      if (logMap['notes'] is String) {
        final nStr = (logMap['notes'] as String).trim();
        if (nStr.isNotEmpty) detectedNotes = nStr;
      }

      if (logMap['memory'] is Map) {
        final mem = logMap['memory'] as Map;
        final cat = mem['category']?.toString().trim() ?? 'preference';
        final note = mem['note']?.toString().trim() ?? '';
        if (note.isNotEmpty) {
          detectedMemoryCategory = cat;
          detectedMemoryNote = note;
        }
      }

      if (logMap['symptoms'] is List) {
        for (final s in (logMap['symptoms'] as List)) {
          final sStr = s.toString().trim();
          if (sStr.isNotEmpty && !detectedSymptoms.contains(sStr)) {
            detectedSymptoms.add(sStr);
          }
        }
      }
    }

    // 2. Process rawAiLog string (from [LOG:...])
    if (rawAiLog != null && rawAiLog.trim().isNotEmpty) {
      String trimmedLog = rawAiLog.trim();
      if (trimmedLog.endsWith(']')) {
        trimmedLog = trimmedLog.substring(0, trimmedLog.length - 1).trim();
      }

      bool parsedAsJson = false;
      if (trimmedLog.startsWith('{') && trimmedLog.endsWith('}')) {
        try {
          final map = jsonDecode(trimmedLog) as Map<String, dynamic>;
          parsedAsJson = true;

          if (map['date'] is String) {
            final dStr = (map['date'] as String).trim();
            if (dStr.isNotEmpty) detectedDateStr = dStr;
          }

          if (map['periodStarted'] is bool) {
            detectedPeriodStarted = map['periodStarted'] as bool;
          } else if (map['periodStarted'] is String) {
            detectedPeriodStarted =
                (map['periodStarted'] as String).toLowerCase() == 'true';
          }

          if (map['flow'] is String) {
            final fStr = (map['flow'] as String).toLowerCase().trim();
            detectedFlow = FlowLevel.values.cast<FlowLevel?>().firstWhere(
                  (f) => f?.name.toLowerCase() == fStr,
                  orElse: () => detectedFlow,
                );
          }

          if (map['cramps'] is String) {
            final cStr = (map['cramps'] as String).toLowerCase().trim();
            detectedCramps = CrampLevel.values.cast<CrampLevel?>().firstWhere(
                  (c) => c?.name.toLowerCase() == cStr,
                  orElse: () => detectedCramps,
                );
          }

          if (map['mood'] is String) {
            final mStr = (map['mood'] as String).toLowerCase().trim();
            detectedMood = MoodLevel.values.cast<MoodLevel?>().firstWhere(
                  (m) => m?.name.toLowerCase() == mStr,
                  orElse: () => detectedMood,
                );
          }

          if (map['energy'] is num) {
            detectedEnergy = (map['energy'] as num).toInt();
          } else if (map['energy'] is String) {
            detectedEnergy = int.tryParse(map['energy'] as String) ?? detectedEnergy;
          }

          if (map['sleep'] is String) {
            final sStr = (map['sleep'] as String).toLowerCase().trim();
            detectedSleep = SleepQuality.values.cast<SleepQuality?>().firstWhere(
                  (s) => s?.name.toLowerCase() == sStr,
                  orElse: () => detectedSleep,
                );
          }

          if (map['notes'] is String) {
            final nStr = (map['notes'] as String).trim();
            if (nStr.isNotEmpty) detectedNotes = nStr;
          }

          if (map['memory'] is Map) {
            final mem = map['memory'] as Map;
            final cat = mem['category']?.toString().trim() ?? 'preference';
            final note = mem['note']?.toString().trim() ?? '';
            if (note.isNotEmpty) {
              detectedMemoryCategory = cat;
              detectedMemoryNote = note;
            }
          }

          if (map['symptoms'] is List) {
            for (final s in (map['symptoms'] as List)) {
              final sStr = s.toString().trim();
              if (sStr.isNotEmpty && !detectedSymptoms.contains(sStr)) {
                detectedSymptoms.add(sStr);
              }
            }
          }
        } catch (_) {}
      }

      if (!parsedAsJson) {
        final dateMatch = RegExp(
                r'["\x27]?date["\x27]?\s*[:=]\s*["\x27]([^"\x27]+)["\x27]',
                caseSensitive: false)
            .firstMatch(trimmedLog);
        if (dateMatch != null) {
          detectedDateStr = dateMatch.group(1)?.trim();
        }

        final pMatch = RegExp(r'periodStarted\s*[:=]\s*(true|false)',
                caseSensitive: false)
            .firstMatch(trimmedLog);
        if (pMatch != null) {
          detectedPeriodStarted = pMatch.group(1)?.toLowerCase() == 'true';
        }

        final flowMatch = RegExp(r'flow\s*[:=]\s*(\w+)', caseSensitive: false)
            .firstMatch(trimmedLog);
        if (flowMatch != null) {
          final fStr = flowMatch.group(1)?.toLowerCase();
          detectedFlow = FlowLevel.values.cast<FlowLevel?>().firstWhere(
                (f) => f?.name.toLowerCase() == fStr,
                orElse: () => detectedFlow,
              );
        }

        final crampsMatch =
            RegExp(r'cramps\s*[:=]\s*(\w+)', caseSensitive: false)
                .firstMatch(trimmedLog);
        if (crampsMatch != null) {
          final cStr = crampsMatch.group(1)?.toLowerCase();
          detectedCramps = CrampLevel.values.cast<CrampLevel?>().firstWhere(
                (c) => c?.name.toLowerCase() == cStr,
                orElse: () => detectedCramps,
              );
        }

        final moodMatch = RegExp(r'mood\s*[:=]\s*(\w+)', caseSensitive: false)
            .firstMatch(trimmedLog);
        if (moodMatch != null) {
          final moodStr = moodMatch.group(1)?.toLowerCase();
          detectedMood = MoodLevel.values.cast<MoodLevel?>().firstWhere(
                (m) => m?.name.toLowerCase() == moodStr,
                orElse: () => detectedMood,
              );
        }

        final energyMatch =
            RegExp(r'energy\s*[:=]\s*(\d+)', caseSensitive: false)
                .firstMatch(trimmedLog);
        if (energyMatch != null) {
          detectedEnergy = int.tryParse(energyMatch.group(1) ?? '') ?? detectedEnergy;
        }

        final sleepMatch =
            RegExp(r'sleep\s*[:=]\s*(\w+)', caseSensitive: false)
                .firstMatch(trimmedLog);
        if (sleepMatch != null) {
          final sStr = sleepMatch.group(1)?.toLowerCase();
          detectedSleep = SleepQuality.values.cast<SleepQuality?>().firstWhere(
                (s) => s?.name.toLowerCase() == sStr,
                orElse: () => detectedSleep,
              );
        }

        final notesMatch =
            RegExp(r'notes\s*[:=]\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false)
                .firstMatch(trimmedLog);
        if (notesMatch != null) {
          detectedNotes = notesMatch.group(1)?.trim();
        }

        final symptomsMatch =
            RegExp(r'symptoms\s*[:=]\s*\[([^\]]*)\]', caseSensitive: false)
                .firstMatch(trimmedLog);
        if (symptomsMatch != null) {
          final rawList = symptomsMatch.group(1)?.split(',') ?? [];
          for (final item in rawList) {
            final trimmed =
                item.replaceAll('"', '').replaceAll("'", '').trim();
            if (trimmed.isNotEmpty && !detectedSymptoms.contains(trimmed)) {
              detectedSymptoms.add(trimmed);
            }
          }
        }
      }
    }

    // 3. Intelligent Heuristic Scanner on userText
    if (userText.trim().isNotEmpty) {
      final lower = userText.toLowerCase();

      // Flow scanner
      if (detectedFlow == null) {
        if (RegExp(r'\b(high\s+flow|heavy\s+flow|heavy\s+bleeding)\b').hasMatch(lower)) {
          detectedFlow = FlowLevel.heavy;
        } else if (RegExp(r'\b(medium\s+flow|moderate\s+flow)\b').hasMatch(lower)) {
          detectedFlow = FlowLevel.medium;
        } else if (RegExp(r'\b(light\s+flow|spotting)\b').hasMatch(lower)) {
          detectedFlow = FlowLevel.light;
        }
      }

      // Period start scanner (even if user said "started tomorrow", "started today", or "started bleeding")
      if (detectedPeriodStarted != true) {
        if (RegExp(r'\b(period\s+started|got\s+my\s+period|started\s+my\s+period|started\s+bleeding|my\s+period\s+came|period\s+is\s+here)\b').hasMatch(lower)) {
          detectedPeriodStarted = true;
        }
      }

      // Cramps scanner
      if (detectedCramps == null) {
        if (RegExp(r'\b(max\s+cramps|severe\s+cramps|terrible\s+cramps|worst\s+cramps|awful\s+cramps|intense\s+cramps)\b').hasMatch(lower)) {
          detectedCramps = CrampLevel.severe;
        } else if (RegExp(r'\b(bad\s+cramps|moderate\s+cramps|painful\s+cramps|cramping\s+badly)\b').hasMatch(lower)) {
          detectedCramps = CrampLevel.moderate;
        } else if (RegExp(r'\b(mild\s+cramps|slight\s+cramps|little\s+cramps)\b').hasMatch(lower)) {
          detectedCramps = CrampLevel.mild;
        } else if (RegExp(r'\b(cramp|cramps|cramping)\b').hasMatch(lower)) {
          detectedCramps = CrampLevel.moderate;
        }
      }

      // Energy scanner (handles "O energy", "0 energy", "zero energy")
      if (detectedEnergy == null) {
        if (RegExp(r'\b([o0]|zero|no)\s+energy\b').hasMatch(lower)) {
          detectedEnergy = 1;
        } else if (RegExp(r'\b(low\s+energy|exhausted|drained|no\s+stamina)\b').hasMatch(lower)) {
          detectedEnergy = 1;
        } else if (RegExp(r'\b(high\s+energy|energized|energetic)\b').hasMatch(lower)) {
          detectedEnergy = 5;
        }
      }

      // Sleep scanner
      if (detectedSleep == null) {
        if (RegExp(r'\b(worst\s+sleep|poor\s+sleep|terrible\s+sleep|awful\s+sleep|bad\s+sleep|couldn\x27?t\s+sleep|insomnia)\b').hasMatch(lower)) {
          detectedSleep = SleepQuality.poor;
        } else if (RegExp(r'\b(deep\s+sleep|great\s+sleep|amazing\s+sleep|best\s+sleep)\b').hasMatch(lower)) {
          detectedSleep = SleepQuality.great;
        }
      }

      // Mood scanner
      if (detectedMood == null) {
        if (RegExp(r'\b(day\s+is\s+ruined|struggling|crying|depressed|can\x27?t\s+take\s+this|miserable|overwhelmed)\b').hasMatch(lower)) {
          detectedMood = MoodLevel.struggling;
        } else if (RegExp(r'\b(sad|down|low|gloomy|unhappy)\b').hasMatch(lower)) {
          detectedMood = MoodLevel.low;
        } else if (RegExp(r'\b(amazing|thriving|fantastic|wonderful)\b').hasMatch(lower)) {
          detectedMood = MoodLevel.thriving;
        }
      }

      // Symptoms scanner
      void checkSymptom(RegExp reg, String name) {
        if (reg.hasMatch(lower) && !detectedSymptoms.contains(name)) {
          detectedSymptoms.add(name);
        }
      }
      checkSymptom(RegExp(r'\b(headache|headaches|migraine)\b'), 'Headache');
      checkSymptom(RegExp(r'\b(cramp|cramps|cramping)\b'), 'Cramps');
      checkSymptom(RegExp(r'\b(bloat|bloated|bloating)\b'), 'Bloating');
      checkSymptom(RegExp(r'\b(fatigue|fatigued|tired|exhausted)\b'), 'Fatigue');
      checkSymptom(RegExp(r'\b(brain\s+fog|foggy)\b'), 'Brain fog');
      checkSymptom(RegExp(r'\b(anxious|anxiety|panic)\b'), 'Anxious');
      checkSymptom(RegExp(r'\b(irritable|irritated|angry|moody)\b'), 'Irritable');
      checkSymptom(RegExp(r'\b(craving|cravings)\b'), 'Cravings');
      checkSymptom(RegExp(r'\b(backache|back\s+pain)\b'), 'Backache');
      checkSymptom(RegExp(r'\b(tender|breast\s+pain)\b'), 'Tender');
    }

    // Resolve target date from text or AI output
    final targetResult = PeriodDateExtractor.extractTargetDate(userText);
    if (targetResult.isFuture) {
      // Future dates are stored in companion memory, NEVER logged to database.
      return null;
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    DateTime targetDate;
    if (targetResult.isExplicit) {
      targetDate = DateTime(targetResult.date.year, targetResult.date.month, targetResult.date.day);
    } else if (detectedDateStr != null && detectedDateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(detectedDateStr);
      if (parsed != null) {
        final parsedNorm = DateTime(parsed.year, parsed.month, parsed.day);
        if (parsedNorm.isAfter(todayMidnight)) {
          // Future date from AI: do not write to log database
          return null;
        }
        targetDate = parsedNorm;
      } else {
        targetDate = todayMidnight;
      }
    } else {
      targetDate = todayMidnight;
    }

    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;

    // 4. CRITICAL BIOLOGICAL MANDATE:
    // If the log is for a past date, or user specified a specific period date,
    // do NOT anchor period start to TODAY.
    if (!isToday || hasSpecificDateRequest) {
      if (isToday) {
        detectedPeriodStarted = false;
        detectedFlow = null;
      }
    } else if (detectedFlow != null) {
      // Menstrual flow strictly implies period has started (for today only)
      detectedPeriodStarted = true;
    }

    // 5. Execute period start anchor if detected
    if (detectedPeriodStarted == true && !hasSpecificDateRequest) {
      if (isToday) {
        await ref.read(periodHistoryProvider.notifier).addPeriodStart(now, source: 'ai');
      } else {
        await ref.read(periodHistoryProvider.notifier).updatePeriodStart(targetDate);
      }
    }

    // 6. Persist memory if captured
    if (detectedMemoryNote != null && detectedMemoryNote.isNotEmpty) {
      await StorageService.saveMemory(
        LunaMemoryEntry(
          id: LunaMemoryEntry.newId(),
          category: detectedMemoryCategory ?? 'preference',
          content: detectedMemoryNote,
          createdAt: DateTime.now(),
        ),
      );
    }

    // 7. DIFFING ENGINE (VISION Pillar One, Two & Three):
    // Only treat biomarkers as NEW if they actually differ from what was ALREADY logged on targetDate!
    final allEntries = ref.read(logEntriesProvider);
    final targetEntry = allEntries.where((e) =>
        e.date.year == targetDate.year &&
        e.date.month == targetDate.month &&
        e.date.day == targetDate.day).firstOrNull;

    final isNewMood = detectedMood != null && detectedMood != targetEntry?.mood;
    final isNewEnergy = detectedEnergy != null && detectedEnergy != targetEntry?.energyLevel;
    final isNewSleep = detectedSleep != null && detectedSleep != targetEntry?.sleepQuality;
    final isNewFlow = detectedFlow != null && detectedFlow != targetEntry?.flow && (isToday ? !hasSpecificDateRequest : true);
    final isNewCramps = detectedCramps != null &&
        detectedCramps != CrampLevel.none &&
        detectedCramps != targetEntry?.cramps;
    final isNewPeriodStarted = detectedPeriodStarted == true &&
        (isToday ? !hasSpecificDateRequest : true) &&
        (targetEntry?.periodStarted != true);

    final existingSymptoms =
        LogEntry.canonicalizeSymptoms(targetEntry?.symptoms ?? []);
    final newSymptoms = <String>[];
    for (final s in LogEntry.canonicalizeSymptoms(detectedSymptoms)) {
      if (!existingSymptoms.contains(s) && !newSymptoms.contains(s)) {
        newSymptoms.add(s);
      }
    }

    final isNewNotes = detectedNotes != null &&
        detectedNotes.isNotEmpty &&
        !(targetEntry?.notes?.contains(detectedNotes) ?? false);

    final isNewMemory = detectedMemoryNote != null && detectedMemoryNote.isNotEmpty;

    final hasNewData = isNewMood ||
        isNewEnergy ||
        isNewSleep ||
        isNewFlow ||
        isNewCramps ||
        isNewPeriodStarted ||
        newSymptoms.isNotEmpty ||
        isNewNotes;

    // Save to LogEntry ONLY if there is genuinely new biomarker data
    if (hasNewData) {
      final entryId = targetEntry?.id ?? const Uuid().v4();
      final updatedSymptoms = LogEntry.canonicalizeSymptoms({
        ...?targetEntry?.symptoms,
        ...newSymptoms,
      });

      final updatedNotes = isNewNotes
          ? (targetEntry?.notes != null && targetEntry!.notes!.isNotEmpty
              ? '${targetEntry.notes} · $detectedNotes'
              : detectedNotes)
          : targetEntry?.notes;

      final newEntry = LogEntry(
        id: entryId,
        date: targetEntry?.date ?? targetDate,
        mood: detectedMood ?? targetEntry?.mood,
        energyLevel: detectedEnergy ?? targetEntry?.energyLevel,
        sleepQuality: detectedSleep ?? targetEntry?.sleepQuality,
        flow: detectedFlow ?? targetEntry?.flow,
        cramps: detectedCramps ?? targetEntry?.cramps,
        symptoms: updatedSymptoms,
        notes: updatedNotes,
        periodStarted: isNewPeriodStarted || (targetEntry?.periodStarted ?? false),
      );

      await ref.read(logEntriesProvider.notifier).addEntry(newEntry);
    }

    // 8. Generate summary badge ONLY with items that were newly captured in this interaction
    final parts = <String>[];
    if (isNewPeriodStarted) {
      parts.add('Period started 🩸');
    }
    if (isNewFlow) {
      parts.add(
          '${detectedFlow.name[0].toUpperCase()}${detectedFlow.name.substring(1)} flow');
    }
    if (isNewCramps) {
      parts.add(
          '${detectedCramps.name[0].toUpperCase()}${detectedCramps.name.substring(1)} cramps');
    }
    if (isNewMood) parts.add(detectedMood.label);
    if (isNewEnergy) parts.add('$detectedEnergy/5 energy');
    if (isNewSleep) parts.add('${detectedSleep.label} sleep');

    // Individual, deduplicated canonical symptoms that are newly captured
    for (final s in newSymptoms) {
      if (s == 'Cramps' && isNewCramps) continue;
      if (s == 'Period' && isNewPeriodStarted) continue;
      parts.add(s);
    }

    // Discreet memory note indicator (never dump raw paragraphs into chips)
    if (isNewMemory) {
      parts.add('Remembered 💜');
    }

    if (parts.isEmpty) return null;

    final summary = parts.join(' · ');
    if (!isToday) {
      final dateLabel = '${_monthName(targetDate.month)} ${targetDate.day}';
      return '$summary ($dateLabel)';
    }
    return summary;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final profile = ref.watch(profileProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final patternProfile = ref.watch(patternProfileProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_chatMode) {
            setState(() {
              _chatMode = false;
              _chatLoading = false;
            });
            return;
          }
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _chatMode
              ? KeyedSubtree(
                  key: const ValueKey('luna_chat_mode'),
                  child: _buildChatMode(context, colors, profile, cycleState),
                )
              : KeyedSubtree(
                  key: const ValueKey('luna_checkin_mode'),
                  child: Scaffold(
              backgroundColor: colors.background,
              body: Stack(
                children: [
                  // Ambient glow top-right
                  Positioned(
                    top: -80, right: -60,
                    child: Container(
                      width: 280, height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          colors.primary.withValues(alpha: 0.18), Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  // Ambient glow bottom-left
                  Positioned(
                    bottom: 100, left: -80,
                    child: Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          colors.secondary.withValues(alpha: 0.12), Colors.transparent,
                        ]),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_rounded,
                                    color: colors.onSurface.withValues(alpha: 0.5), size: 20),
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/home');
                                  }
                                },
                              ),
                              const Spacer(),
                              Column(children: [
                                Text('🌙 Luna',
                                    style: GoogleFonts.cormorantGaramond(
                                        fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface)),
                                Text('Your companion',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5)),
                              ]),
                              const Spacer(),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Luna orb + greeting
                        Center(
                          child: Column(children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      colors.primary.withValues(alpha: 0.9),
                                      colors.secondary.withValues(alpha: 0.5),
                                    ]),
                                    boxShadow: [BoxShadow(
                                      color: colors.primary.withValues(alpha: 0.35 + _pulseController.value * 0.2),
                                      blurRadius: 30 + _pulseController.value * 15,
                                      spreadRadius: 2,
                                    )],
                                  ),
                                  child: const Center(child: Text('🌙', style: TextStyle(fontSize: 40))),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Hey ${profile?.name ?? 'gorgeous'} 🌸',
                              style: GoogleFonts.cormorantGaramond(
                                  fontSize: 26, fontWeight: FontWeight.w700, color: colors.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (cycleState != null && profile?.lastPeriodStart != null && cycleState.dayOfCycle > 0)
                                  ? 'Day ${cycleState.dayOfCycle} · ${cycleState.phaseInfo.name} · ${cycleState.phaseInfo.tagline}'
                                  : 'Cycle Blueprint Active · ${profile?.averageCycleLength ?? 28}-day model',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5),
                            ),
                            if (patternProfile.hasSufficientData) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colors.primary.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🧠', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Neural Memory Active · ${patternProfile.totalLogsAnalyzed} check-ins',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ]),
                        ).animate().fadeIn(duration: 500.ms),

                        if (_chatHistory.isNotEmpty && _response == null && !_loading) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _chatMode = true);
                                _scrollToBottom();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('💬', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Resume conversation with Luna',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 14, color: colors.accent),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 80.ms),
                        ],

                        const SizedBox(height: 32),

                        if (_response == null && !_loading) ...[
                          Text('How are you feeling right now?',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface),
                          ).animate().fadeIn(delay: 100.ms),
                          const SizedBox(height: 6),
                          Text('Be honest: Luna is here for you.',
                            style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                          ).animate().fadeIn(delay: 150.ms),
                          const SizedBox(height: 20),

                          // Mood grid
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.3,
                            children: MoodLevel.values.map((m) {
                              final sel = _selectedMood == m;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedMood = sel ? null : m;
                                  _showTextInput = false;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? colors.primary.withValues(alpha: 0.25)
                                        : colors.surface.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel ? colors.primary : colors.onSurface.withValues(alpha: 0.06),
                                      width: sel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(fontSize: sel ? 28 : 22),
                                      child: Text(m.emoji),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      m.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: sel ? colors.accent : colors.onSurface.withValues(alpha: 0.5),
                                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ).animate().fadeIn(delay: 200.ms),

                          const SizedBox(height: 16),

                          // Optional symptom pills
                          Text(
                            'Any specific symptoms today?',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _quickSymptoms.map((s) {
                              final isSelected = _selectedSymptoms.contains(s);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedSymptoms.remove(s);
                                    } else {
                                      _selectedSymptoms.add(s);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.accent.withValues(alpha: 0.18)
                                        : colors.surface.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.accent.withValues(alpha: 0.6)
                                          : colors.onSurface.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Text(
                                    s,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected
                                          ? colors.accent
                                          : colors.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ).animate().fadeIn(delay: 220.ms),

                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: () => setState(() => _showTextInput = !_showTextInput),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _showTextInput
                                    ? colors.primary.withValues(alpha: 0.1)
                                    : colors.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _showTextInput
                                      ? colors.primary.withValues(alpha: 0.4)
                                      : colors.onSurface.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 15, color: colors.accent.withValues(alpha: 0.7)),
                                const SizedBox(width: 10),
                                Text('Or just tell me what\'s on your mind...',
                                  style: GoogleFonts.dmSans(fontSize: 13, color: colors.accent.withValues(alpha: 0.7))),
                              ]),
                            ),
                          ).animate().fadeIn(delay: 250.ms),

                          if (_showTextInput) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _textController,
                              autofocus: true,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onChanged: (v) => setState(() {}),
                              onSubmitted: (_) {
                                if (_textController.text.trim().isNotEmpty && !_loading) {
                                  _checkIn();
                                }
                              },
                              style: GoogleFonts.dmSans(fontSize: 14, color: colors.onSurface),
                              decoration: InputDecoration(
                                filled: true, fillColor: colors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.accent, width: 1.5)),
                                hintText: 'Vent, ask, or describe how you feel...',
                                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 14),
                                contentPadding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
                                suffixIcon: _textController.text.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: _loading ? null : _checkIn,
                                          child: Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: colors.primary,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: _loading
                                                ? const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ).animate().fadeIn(),
                          ],

                          const SizedBox(height: 24),

                          // CTA — Talk to Luna
                          GestureDetector(
                            onTap: (_selectedMood != null || _textController.text.isNotEmpty) && !_loading
                                ? _checkIn
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: (_selectedMood != null || _textController.text.isNotEmpty)
                                    ? LinearGradient(colors: [colors.primary, colors.secondary])
                                    : null,
                                color: (_selectedMood != null || _textController.text.isNotEmpty)
                                    ? null : colors.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: (_selectedMood != null || _textController.text.isNotEmpty)
                                    ? [BoxShadow(color: colors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 6))]
                                    : [],
                              ),
                              child: _loading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    )
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Text('🌙', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      Text('Talk to Luna',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 16, fontWeight: FontWeight.w600,
                                          color: (_selectedMood != null || _textController.text.isNotEmpty)
                                              ? Colors.white : colors.onSurface.withValues(alpha: 0.3),
                                        )),
                                    ]),
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                        ],

                        // Loading state
                        if (_loading) ...[
                          const SizedBox(height: 60),
                          Center(
                            child: Column(children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 70, height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(colors: [
                                        colors.primary.withValues(alpha: 0.8),
                                        colors.secondary.withValues(alpha: 0.3),
                                      ]),
                                      boxShadow: [BoxShadow(
                                        color: colors.primary.withValues(alpha: 0.3 + _pulseController.value * 0.3),
                                        blurRadius: 20 + _pulseController.value * 20,
                                        spreadRadius: 2,
                                      )],
                                    ),
                                    child: const Center(child: Text('🌙', style: TextStyle(fontSize: 30))),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              Text('Luna is thinking...',
                                  style: GoogleFonts.dmSans(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
                              const SizedBox(height: 6),
                              Text('Writing something just for you',
                                  style: GoogleFonts.dmSans(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
                            ]),
                          ),
                        ],

                        // Response
                        if (_response != null) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [colors.primary.withValues(alpha: 0.2), colors.secondary.withValues(alpha: 0.08)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.primary.withValues(alpha: 0.3)),
                                  child: const Center(child: Text('🌙', style: TextStyle(fontSize: 16))),
                                ),
                                const SizedBox(width: 10),
                                Text('Luna says',
                                    style: GoogleFonts.dmSans(fontSize: 12, color: colors.accent, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              ]),
                              const SizedBox(height: 14),
                              Text(_response!.validation,
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.55)),
                            ]),
                          ).animate().fadeIn().slideY(begin: 0.08),

                          if (_lastAutoLogSummary != null && _lastAutoLogSummary!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildAutoLogCard(_lastAutoLogSummary!, colors),
                          ],

                          const SizedBox(height: 14),

                          GestureDetector(
                            onTap: () => setState(() => _showScienceCard = !_showScienceCard),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: colors.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(18)),
                              child: Column(children: [
                                Row(children: [
                                  Icon(Icons.science_outlined, size: 16, color: colors.accent),
                                  const SizedBox(width: 10),
                                  Text('What\'s happening in your body',
                                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: colors.accent)),
                                  const Spacer(),
                                  Icon(_showScienceCard ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: colors.onSurface.withValues(alpha: 0.3), size: 18),
                                ]),
                                if (_showScienceCard) ...[
                                  const SizedBox(height: 12),
                                  Text(_response!.science,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75), height: 1.65)),
                                ],
                              ]),
                            ),
                          ).animate(delay: 150.ms).fadeIn(),

                          const SizedBox(height: 14),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: colors.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Icon(Icons.favorite_outline, size: 14, color: colors.accent),
                                const SizedBox(width: 8),
                                Text('What can actually help right now',
                                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: colors.accent)),
                              ]),
                              const SizedBox(height: 14),
                              ..._response!.actions.map((action) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(
                                    width: 5, height: 5,
                                    margin: const EdgeInsets.only(top: 7, right: 12),
                                    decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                                  ),
                                  Expanded(child: Text(action,
                                      style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.8), height: 1.55))),
                                ]),
                              )),
                            ]),
                          ).animate(delay: 300.ms).fadeIn(),

                          const SizedBox(height: 14),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [colors.accent.withValues(alpha: 0.1), colors.primary.withValues(alpha: 0.06)]),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(_response!.closing,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cormorantGaramond(
                                  fontSize: 17, fontStyle: FontStyle.italic, color: colors.onSurface.withValues(alpha: 0.85), height: 1.6)),
                          ).animate(delay: 450.ms).fadeIn(),

                          const SizedBox(height: 28),

                          // Two-button footer
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _enterChatMode,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [colors.primary, colors.secondary],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(alpha: 0.3),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Text('💬', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text('Keep talking',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _response = null;
                                    _selectedMood = null;
                                    _selectedSymptoms.clear();
                                    _textController.clear();
                                    _showScienceCard = false;
                                    _showTextInput = false;
                                    _lastUserText = '';
                                    _lastAutoLogSummary = null;
                                    _isCheckInLogExpanded = false;
                                    _expandedChatLogIndices.clear();
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: colors.surface.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
                                    ),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Text('🔄', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Text('Check in again',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55))),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ).animate(delay: 500.ms).fadeIn(),

                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LunaBottomNav(currentIndex: 2),
          ),
        ],
      ),
    ),
  ),
),
);
}

  Widget _buildChatMode(BuildContext context, dynamic colors, dynamic profile, dynamic cycleState) {
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.primary.withValues(alpha: 0.12), Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Chat header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded,
                            color: colors.onSurface.withValues(alpha: 0.5), size: 20),
                        onPressed: () => setState(() {
                          _chatMode = false;
                          _chatLoading = false;
                        }),
                      ),
                      // Small Luna orb
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                colors.primary.withValues(alpha: 0.9),
                                colors.secondary.withValues(alpha: 0.5),
                              ]),
                              boxShadow: [BoxShadow(
                                color: colors.primary.withValues(alpha: 0.3 + _pulseController.value * 0.15),
                                blurRadius: 16 + _pulseController.value * 8,
                                spreadRadius: 1,
                              )],
                            ),
                            child: const Center(child: Text('🌙', style: TextStyle(fontSize: 22))),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Luna',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface)),
                        Text(
                          (cycleState != null && profile?.lastPeriodStart != null && cycleState.dayOfCycle > 0)
                              ? 'Day ${cycleState.dayOfCycle} · ${cycleState.phaseInfo.name}'
                              : 'Active Blueprint · Your companion',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 0.4),
                        ),
                      ]),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh_rounded,
                            color: colors.onSurface.withValues(alpha: 0.45), size: 20),
                        tooltip: 'New conversation',
                        onPressed: () async {
                          await StorageService.clearLastChatSession();
                          setState(() {
                            _chatHistory = [];
                            _pendingPeriodDate = null;
                            _lastAutoLogSummary = null;
                            _expandedChatLogIndices.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Message list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _chatHistory.length + (_chatLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _chatHistory.length && _chatLoading) {
                        return _buildTypingIndicator(colors);
                      }
                      final msg = _chatHistory[index];
                      return _buildMessageBubble(msg, colors, index);
                    },
                  ),
                ),

                // Quick suggested conversation chips
                Container(
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildChatChip(
                        (cycleState != null && profile?.lastPeriodStart != null && cycleState.dayOfCycle > 0)
                            ? 'Why does this phase affect my focus?'
                            : 'Why am I having low energy today?',
                        colors,
                      ),
                      const SizedBox(width: 8),
                      _buildChatChip('What should I eat right now?', colors),
                      const SizedBox(width: 8),
                      _buildChatChip('Can I do a tough workout today?', colors),
                    ],
                  ),
                ),

                // Input row
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border(top: BorderSide(color: colors.onSurface.withValues(alpha: 0.06))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (_chatController.text.trim().isNotEmpty && !_chatLoading) {
                              _sendChatMessage();
                            }
                          },
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.dmSans(fontSize: 14, color: colors.onSurface),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(color: colors.accent, width: 1.5),
                            ),
                            hintText: 'Say anything...',
                            hintStyle: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.3), fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _chatLoading ? null : _sendChatMessage,
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _chatLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg, dynamic colors, int messageIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            // Luna avatar
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.primary.withValues(alpha: 0.8),
                  colors.secondary.withValues(alpha: 0.4),
                ]),
              ),
              child: const Center(child: Text('🌙', style: TextStyle(fontSize: 14))),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? colors.primary.withValues(alpha: 0.25)
                        : colors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                    ),
                    border: msg.isUser
                        ? Border.all(color: colors.primary.withValues(alpha: 0.2))
                        : Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
                  ),
                  child: Text(
                    msg.text,
                    style: msg.isUser
                        ? GoogleFonts.dmSans(
                            fontSize: 14, color: Colors.white, height: 1.5)
                        : GoogleFonts.dmSans(
                            fontSize: 14,
                            color: colors.onSurface.withValues(alpha: 0.88),
                            height: 1.6),
                  ),
                ),
                if (msg.autoLogNote != null) ...[
                  _buildChatLogBadge(messageIndex, msg.autoLogNote!, colors),
                ],
                if (msg.pendingPeriodDate != null) ...[
                  _buildPeriodDateConfirmationCard(msg, messageIndex, colors),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildChatLogBadge(int messageIndex, String summary, dynamic colors) {
    final items = summary
        .split(' · ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedChatLogIndices.contains(messageIndex);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedChatLogIndices.remove(messageIndex);
          } else {
            _expandedChatLogIndices.add(messageIndex);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(top: 6),
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: isExpanded ? 8 : 4.5,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: isExpanded ? 0.8 : 0.45),
          borderRadius: BorderRadius.circular(isExpanded ? 14 : 20),
          border: Border.all(
            color: colors.primary.withValues(alpha: isExpanded ? 0.24 : 0.14),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 5),
                Text(
                  isExpanded ? 'Noted in log' : 'Noted in log (${items.length})',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.accent.withValues(alpha: 0.85),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: colors.accent.withValues(alpha: 0.6),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: items
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: 0.2),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            item,
                            style: GoogleFonts.dmSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDateConfirmationCard(
      _ChatMessage msg, int messageIndex, dynamic colors) {
    final date = msg.pendingPeriodDate;
    if (date == null) return const SizedBox.shrink();
    final dateStr = _formatPeriodDate(date);

    if (msg.periodDateConfirmed == true) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: colors.accent),
            const SizedBox(width: 8),
            Text(
              'Period start updated to $dateStr',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    if (msg.periodDateConfirmed == false) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded,
                size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              'Date update cancelled',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    // Pending confirmation card with interactive buttons
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update cycle start to $dateStr?',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This will adjust your current cycle day and recalibrate phase timings.',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.55),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _confirmPeriodDateUpdate(date, messageIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Yes, update',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _rejectPeriodDateUpdate(messageIndex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.12)),
                    ),
                    child: Center(
                      child: Text(
                        'Keep current',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                colors.primary.withValues(alpha: 0.8),
                colors.secondary.withValues(alpha: 0.4),
              ]),
            ),
            child: const Center(child: Text('🌙', style: TextStyle(fontSize: 14))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
            ),
            child: Row(children: [
              _DotPulse(color: colors.accent),
              const SizedBox(width: 4),
              _DotPulse(color: colors.accent, delay: 150),
              const SizedBox(width: 4),
              _DotPulse(color: colors.accent, delay: 300),
            ]),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildChatChip(String text, dynamic colors) {
    return GestureDetector(
      onTap: _chatLoading ? null : () => _sendChatMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: colors.accent.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoLogCard(String summary, dynamic colors) {
    final items = summary
        .split(' · ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _isCheckInLogExpanded = !_isCheckInLogExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: _isCheckInLogExpanded ? 12 : 9,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: _isCheckInLogExpanded ? 0.75 : 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withValues(alpha: _isCheckInLogExpanded ? 0.25 : 0.16),
            width: 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 7),
                Text(
                  'Noted in your daily log',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _isCheckInLogExpanded ? 'Hide' : 'View details',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  _isCheckInLogExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            if (_isCheckInLogExpanded) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: colors.accent.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            item,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

/// Animated dot for typing indicator
class _DotPulse extends StatefulWidget {
  final Color color;
  final int delay;
  const _DotPulse({required this.color, this.delay = 0});

  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Chat message model
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final String? autoLogNote;
  final DateTime? pendingPeriodDate;
  final bool? periodDateConfirmed;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.autoLogNote,
    this.pendingPeriodDate,
    this.periodDateConfirmed,
  });

  _ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? time,
    String? autoLogNote,
    DateTime? pendingPeriodDate,
    bool? periodDateConfirmed,
    bool clearPendingPeriodDate = false,
  }) {
    return _ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      time: time ?? this.time,
      autoLogNote: autoLogNote ?? this.autoLogNote,
      pendingPeriodDate: clearPendingPeriodDate
          ? null
          : (pendingPeriodDate ?? this.pendingPeriodDate),
      periodDateConfirmed: periodDateConfirmed ?? this.periodDateConfirmed,
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'time': time.toIso8601String(),
        'autoLogNote': autoLogNote,
        'pendingPeriodDate': pendingPeriodDate?.toIso8601String(),
        'periodDateConfirmed': periodDateConfirmed,
      };

  factory _ChatMessage.fromMap(Map<String, dynamic> map) => _ChatMessage(
        text: map['text'] as String,
        isUser: map['isUser'] as bool,
        time: DateTime.parse(map['time'] as String),
        autoLogNote: map['autoLogNote'] as String?,
        pendingPeriodDate: map['pendingPeriodDate'] != null
            ? DateTime.tryParse(map['pendingPeriodDate'] as String)
            : null,
        periodDateConfirmed: map['periodDateConfirmed'] as bool?,
      );
}
