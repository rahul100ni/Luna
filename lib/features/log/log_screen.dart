import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../shared/widgets/bottom_nav.dart';

class LogScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const LogScreen({super.key, this.initialDate});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> with WidgetsBindingObserver {
  DateTime get _targetDate {
    final d = widget.initialDate ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  bool get _isLoggingToday {
    final now = DateTime.now();
    return _targetDate.year == now.year &&
        _targetDate.month == now.month &&
        _targetDate.day == now.day;
  }
  MoodLevel _mood = MoodLevel.decent;
  bool _moodSelected = false;
  bool _saved = false;
  bool _isSaving = false;
  String? _existingEntryId;

  // Energy level — adult slider (1 to 5, nullable if untouched)
  int? _energy;

  // Optional deeper fields
  FlowLevel? _flow;
  CrampLevel? _cramps;
  SleepQuality? _sleep;
  final _notesController = TextEditingController();

  // Period start state
  bool _periodStarted = false;
  bool _periodAlreadyLoggedToday = false;

  // Symptoms
  final List<String> _symptoms = [];

  static const List<Map<String, String>> _quickSymptoms = [
    {'e': '💧', 'l': 'Bloating'},
    {'e': '🤕', 'l': 'Headache'},
    {'e': '😴', 'l': 'Tired'},
    {'e': '🧠', 'l': 'Brain fog'},
    {'e': '😰', 'l': 'Anxious'},
    {'e': '😢', 'l': 'Sad'},
    {'e': '🍫', 'l': 'Cravings'},
    {'e': '😤', 'l': 'Irritable'},
    {'e': '🤢', 'l': 'Nausea'},
    {'e': '💪', 'l': 'Tender'},
    {'e': '🔥', 'l': 'Hot flashes'},
    {'e': '🌟', 'l': 'Feeling good'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final entries = ref.read(logEntriesProvider);
      final target = _targetDate;
      LogEntry? targetEntry;
      for (final e in entries) {
        if (e.date.year == target.year &&
            e.date.month == target.month &&
            e.date.day == target.day) {
          targetEntry = e;
          break;
        }
      }
      final profile = ref.read(profileProvider);
      final isAnchoredTarget = profile?.lastPeriodStart != null &&
          profile!.lastPeriodStart!.year == target.year &&
          profile.lastPeriodStart!.month == target.month &&
          profile.lastPeriodStart!.day == target.day;

      if (targetEntry != null) {
        final existing = targetEntry;
        setState(() {
          _existingEntryId = existing.id;
          if (existing.mood != null) {
            _mood = existing.mood!;
            _moodSelected = true;
          } else {
            _moodSelected = false;
          }
          _energy = existing.energyLevel;
          _flow = existing.flow;
          _cramps = existing.cramps;
          _sleep = existing.sleepQuality;
          _symptoms.clear();
          _symptoms.addAll(existing.symptoms);
          if (existing.notes != null) {
            _notesController.text = existing.notes!;
          }
          // Strictly true only if this target date is the true anchored cycle start
          _periodAlreadyLoggedToday = isAnchoredTarget;
          _periodStarted = _periodAlreadyLoggedToday;
        });
      } else if (isAnchoredTarget) {
        setState(() {
          _periodAlreadyLoggedToday = true;
          _periodStarted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    if (context.canPop()) {
      context.pop();
      return true;
    }
    context.go('/home');
    return true;
  }

  bool get _canSave =>
      _moodSelected ||
      _energy != null ||
      _symptoms.isNotEmpty ||
      _periodStarted ||
      _flow != null ||
      _cramps != null ||
      _sleep != null ||
      _notesController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_canSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Record at least one detail first 💜',
            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF2A1F3D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final entryId = _existingEntryId ?? const Uuid().v4();
      final profile = ref.read(profileProvider);
      final lastPeriod = profile?.lastPeriodStart;
      final daysSinceAnchor = lastPeriod != null
          ? _targetDate.calendarDaysDifference(lastPeriod)
          : null;

      // An active flow creates a new cycle start ONLY if no active cycle anchor exists
      // or if the previous period start was >= 14 days ago (brand new cycle).
      // Consecutive bleeding days (Day 2..13) are ongoing flow, NOT a new cycle start! (VISION Pillar Nine)
      final isNewCycleStartFromFlow =
          _flow != null && (daysSinceAnchor == null || daysSinceAnchor >= 14);

      final shouldMarkPeriodStarted = _periodStarted || isNewCycleStartFromFlow;

      final entry = LogEntry(
        id: entryId,
        date: _targetDate,
        mood: _moodSelected ? _mood : null,
        energyLevel: _energy,
        flow: _flow,
        cramps: _cramps,
        sleepQuality: _sleep,
        symptoms: _symptoms,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        periodStarted: shouldMarkPeriodStarted,
      );
      await ref.read(logEntriesProvider.notifier).addEntry(entry);

      // Update cycle anchor and history ONLY when explicitly marked or a genuine new cycle starts
      if (shouldMarkPeriodStarted) {
        await ref.read(periodHistoryProvider.notifier).addPeriodStart(
          _targetDate,
          source: 'logged',
        );
      }

      setState(() {
        _saved = true;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _openDetailSheet(PhaseColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: Color.lerp(colors.background, colors.surface, 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                Text(
                  'A little more?',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Only what you want to share. Nothing is saved unless you select it.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),

                // ── Flow ──────────────────────────────────────────────
                _SheetSectionLabel(label: 'Flow', colors: colors),
                const SizedBox(height: 10),
                Row(
                  children: FlowLevel.values.map((f) {
                    final labels = ['Spotting', 'Light', 'Medium', 'Heavy'];
                    final sel = _flow == f;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() => _flow = sel ? null : f);
                          setState(() => _flow = sel ? null : f);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? colors.primary.withValues(alpha: 0.22)
                                : colors.background.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.1),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              labels[f.index],
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel
                                    ? colors.accent
                                    : colors.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Sleep ─────────────────────────────────────────────
                _SheetSectionLabel(label: 'Sleep last night', colors: colors),
                const SizedBox(height: 10),
                Row(
                  children: SleepQuality.values.map((s) {
                    final sel = _sleep == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() => _sleep = sel ? null : s);
                          setState(() => _sleep = sel ? null : s);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? colors.primary.withValues(alpha: 0.22)
                                : colors.background.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.1),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              s.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                color: sel
                                    ? colors.accent
                                    : colors.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Cramps ───────────────────────────────────────────
                _SheetSectionLabel(label: 'Cramps', colors: colors),
                const SizedBox(height: 10),
                Row(
                  children: CrampLevel.values.map((c) {
                    final labels = ['None', 'Mild', 'Moderate', 'Severe'];
                    final emojis = ['😌', '😐', '😣', '😭'];
                    final sel = _cramps == c;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() => _cramps = sel ? null : c);
                          setState(() => _cramps = sel ? null : c);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? colors.primary.withValues(alpha: 0.22)
                                : colors.background.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.1),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emojis[c.index], style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 3),
                              Text(
                                labels[c.index],
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: sel
                                      ? colors.accent
                                      : colors.onSurface.withValues(alpha: 0.45),
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Notes ────────────────────────────────────────────
                _SheetSectionLabel(label: 'Anything specific?', colors: colors),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: GoogleFonts.dmSans(fontSize: 14, color: colors.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.background.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: colors.accent, width: 1.5)),
                    hintText: 'Notes, observations, anything...',
                    hintStyle:
                        TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),

                const SizedBox(height: 24),

                // Done button
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final profile = ref.watch(profileProvider);
    final hasCycleAnchor =
        profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;

    // ── Phase & Pattern based energy suggestion (dynamic baseline) ─────────
    final phase = cycleState?.phase;
    final patternProfile = ref.watch(patternProfileProvider);
    final bool isPersonalized = hasCycleAnchor &&
        phase != null &&
        patternProfile.hasSufficientData &&
        patternProfile.phaseEnergyAverages.containsKey(phase);

    final int suggestedEnergy;
    if (!hasCycleAnchor || phase == null) {
      suggestedEnergy = 3; // neutral middle
    } else if (isPersonalized) {
      final userAvg = patternProfile.phaseEnergyAverages[phase]!;
      suggestedEnergy = userAvg.round().clamp(1, 5);
    } else {
      switch (phase) {
        case CyclePhase.menstrual:    suggestedEnergy = 2; // typically lower
        case CyclePhase.follicular:   suggestedEnergy = 4; // rising energy
        case CyclePhase.ovulatory:    suggestedEnergy = 5; // peak
        case CyclePhase.earlyLuteal:  suggestedEnergy = 4; // steady
        case CyclePhase.lateLuteal:   suggestedEnergy = 2; // tends to dip
      }
    }

    // Contextual period started toggle visibility:
    // Hidden only when user is already in the middle of an active period (Day 2..periodLength)
    // and hasn't toggled it today.
    final lastPeriod = profile?.lastPeriodStart;
    final now = DateTime.now();
    final isToday = _targetDate.year == now.year &&
        _targetDate.month == now.month &&
        _targetDate.day == now.day;
    final daysSinceAnchor = lastPeriod != null ? _targetDate.calendarDaysDifference(lastPeriod) : null;
    final isMidCycleDay2To13 = daysSinceAnchor != null &&
        daysSinceAnchor >= 1 &&
        daysSinceAnchor < 14;
    final showPeriodStartedToggle = _periodStarted || !isMidCycleDay2To13;

    // Inline detail badge for summary
    final List<String> detailSet = [
      if (_flow != null) ['Spotting', 'Light', 'Medium', 'Heavy'][_flow!.index],
      if (_sleep != null) _sleep!.label,
      if (_cramps != null) ['No cramps', 'Mild cramps', 'Moderate cramps', 'Severe cramps'][_cramps!.index],
    ];

    final mainScaffold = _saved
        ? Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('💜', style: TextStyle(fontSize: 80))
                    .animate()
                    .scale(curve: Curves.elasticOut),
                const SizedBox(height: 20),
                Text(
                  'Logged 🌙',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 30, fontWeight: FontWeight.w700, color: colors.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  'You\'re showing up for yourself. That counts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: colors.onSurface.withValues(alpha: 0.45)),
                ),
              ]),
            ),
          )
        : Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // Phase context pill
                      if (hasCycleAnchor && cycleState != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _isLoggingToday
                                ? 'Day ${cycleState.dayOfCycle} · ${cycleState.phaseInfo.name}'
                                : '${DateFormat('MMM d').format(_targetDate)} · ${cycleState.phaseInfo.name}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isLoggingToday
                                ? 'Today\'s check-in'
                                : 'Check-in · ${DateFormat('MMMM d').format(_targetDate)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.onSurface.withValues(alpha: 0.35), size: 20),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Heading ────────────────────────────────────
                        Text(
                          'How are you\ntoday?',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                            height: 1.1,
                          ),
                        ).animate().fadeIn(),
                        const SizedBox(height: 4),
                        Text(
                          _moodSelected
                              ? '${_mood.emoji}  ${_mood.label}'
                              : 'Tap one',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: _moodSelected
                                ? colors.accent
                                : colors.onSurface.withValues(alpha: 0.35),
                            fontWeight: _moodSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ).animate().fadeIn(delay: 50.ms),

                        const SizedBox(height: 18),

                        // ── Mood orbs ─────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: MoodLevel.values.map((m) {
                            final sel = _mood == m && _moodSelected;
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (sel) {
                                  _moodSelected = false;
                                } else {
                                  _mood = m;
                                  _moodSelected = true;
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: sel ? 54 : 48,
                                height: sel ? 54 : 48,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? colors.primary.withValues(alpha: 0.2)
                                      : colors.surface.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? colors.primary
                                        : colors.onSurface.withValues(alpha: 0.07),
                                    width: sel ? 2 : 1,
                                  ),
                                  boxShadow: sel
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.3),
                                            blurRadius: 14,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(m.emoji,
                                      style: TextStyle(fontSize: sel ? 26 : 22)),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 80.ms),

                        const SizedBox(height: 24),

                        // ── Energy Level (Dynamic Cycle & Pattern Slider) ───
                        _EnergySection(
                          energy: _energy,
                          suggestedEnergy: suggestedEnergy,
                          isPersonalized: isPersonalized,
                          colors: colors,
                          onChanged: (v) => setState(() => _energy = v),
                        ),

                        // ── Contextual Period Started Toggle (Day 1) ───────────────
                        if (showPeriodStartedToggle) ...[
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: () => setState(() => _periodStarted = !_periodStarted),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _periodStarted
                                    ? const Color(0xFFD94F6E).withValues(alpha: 0.14)
                                    : colors.surface.withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _periodStarted
                                      ? const Color(0xFFD94F6E).withValues(alpha: 0.45)
                                      : colors.onSurface.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('🩸', style: TextStyle(fontSize: 15)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _periodStarted
                                          ? (isToday ? 'Period started today' : 'Period started on this day')
                                          : (isToday ? 'My period started today' : 'My period started on this day'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13.5,
                                        fontWeight: _periodStarted ? FontWeight.w600 : FontWeight.w500,
                                        color: _periodStarted
                                            ? const Color(0xFFFF8FA3)
                                            : colors.onSurface.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _periodStarted
                                          ? const Color(0xFFD94F6E)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _periodStarted
                                            ? const Color(0xFFD94F6E)
                                            : colors.onSurface.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _periodStarted
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 90.ms),
                        ],

                        // ── Ongoing Bleed & Flow Selector (Days 2 to 10) ───────────────
                        if (isMidCycleDay2To13 && daysSinceAnchor != null && daysSinceAnchor <= 10) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _flow != null
                                    ? const Color(0xFFD94F6E).withValues(alpha: 0.35)
                                    : colors.onSurface.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('🩸', style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PERIOD FLOW · DAY ${daysSinceAnchor + 1}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD94F6E),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_flow != null)
                                      GestureDetector(
                                        onTap: () => setState(() => _flow = null),
                                        child: Text(
                                          'No flow / ended',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            color: colors.onSurface.withValues(alpha: 0.45),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: FlowLevel.values.map((f) {
                                    final labels = ['Spotting', 'Light', 'Medium', 'Heavy'];
                                    final sel = _flow == f;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _flow = sel ? null : f),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? const Color(0xFFD94F6E).withValues(alpha: 0.22)
                                                : colors.background.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: sel
                                                  ? const Color(0xFFD94F6E)
                                                  : colors.onSurface.withValues(alpha: 0.1),
                                              width: sel ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              labels[f.index],
                                              style: GoogleFonts.dmSans(
                                                fontSize: 11.5,
                                                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                                color: sel ? const Color(0xFFFF8FA3) : colors.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 90.ms),
                        ],

                        const SizedBox(height: 24),

                        // ── Symptoms ──────────────────────────────────
                        Builder(builder: (_) {
                          final patternProfile = ref.watch(patternProfileProvider);
                          final currentPhase = cycleState?.phase;

                          // Adaptive symptom suggestion set
                          final suggestedLabels = <String>{};
                          if (hasCycleAnchor && currentPhase != null) {
                            switch (currentPhase) {
                              case CyclePhase.menstrual:
                                suggestedLabels.addAll(['Tired', 'Bloating', 'Headache', 'Sad', 'Tender']);
                                break;
                              case CyclePhase.follicular:
                                suggestedLabels.addAll(['Feeling good', 'Brain fog']);
                                break;
                              case CyclePhase.ovulatory:
                                suggestedLabels.addAll(['Feeling good', 'Tender', 'Hot flashes', 'Cravings']);
                                break;
                              case CyclePhase.earlyLuteal:
                                suggestedLabels.addAll(['Bloating', 'Cravings', 'Tired', 'Tender']);
                                break;
                              case CyclePhase.lateLuteal:
                                suggestedLabels.addAll(['Irritable', 'Bloating', 'Cravings', 'Anxious', 'Tired', 'Headache']);
                                break;
                            }
                            // Boost symptoms identified in personal patterns for this phase
                            final phaseSymptoms = patternProfile.dominantPhaseSymptoms[currentPhase];
                            if (phaseSymptoms != null && phaseSymptoms.isNotEmpty) {
                              for (final s in phaseSymptoms) {
                                suggestedLabels.add(s.split(' ').last);
                              }
                            }
                          }

                          // Sort symptoms: selected first, suggested next, remainder last
                          final sortedSymptoms = [..._quickSymptoms]..sort((a, b) {
                              final keyA = '${a['e']} ${a['l']}';
                              final keyB = '${b['e']} ${b['l']}';
                              final selA = _symptoms.contains(keyA);
                              final selB = _symptoms.contains(keyB);
                              if (selA != selB) return selA ? -1 : 1;

                              final sugA = suggestedLabels.contains(a['l']);
                              final sugB = suggestedLabels.contains(b['l']);
                              if (sugA != sugB) return sugA ? -1 : 1;

                              return 0;
                            });

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'WHAT\'S GOING ON',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface.withValues(alpha: 0.35),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  if (hasCycleAnchor && suggestedLabels.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '· Adaptive to your rhythm',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: colors.accent.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sortedSymptoms.map((s) {
                                  final key = '${s['e']} ${s['l']}';
                                  final sel = _symptoms.contains(key);
                                  final isSuggested = hasCycleAnchor && suggestedLabels.contains(s['l']);

                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      if (sel) {
                                        _symptoms.remove(key);
                                      } else {
                                        _symptoms.add(key);
                                      }
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? colors.primary.withValues(alpha: 0.22)
                                            : isSuggested
                                                ? colors.primary.withValues(alpha: 0.08)
                                                : colors.surface.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: sel
                                              ? colors.primary
                                              : isSuggested
                                                  ? colors.accent.withValues(alpha: 0.35)
                                                  : colors.onSurface.withValues(alpha: 0.07),
                                          width: sel ? 1.6 : (isSuggested ? 1.2 : 1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(s['e']!, style: const TextStyle(fontSize: 13)),
                                          const SizedBox(width: 5),
                                          Text(
                                            s['l']!,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12,
                                              color: sel
                                                  ? colors.accent
                                                  : isSuggested
                                                      ? colors.onSurface.withValues(alpha: 0.9)
                                                      : colors.onSurface.withValues(alpha: 0.6),
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : (isSuggested ? FontWeight.w600 : FontWeight.w400),
                                            ),
                                          ),
                                          if (isSuggested && !sel) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: colors.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        }).animate().fadeIn(delay: 160.ms),

                        const SizedBox(height: 24),

                        // ── Detail sheet trigger ──────────────────────
                        GestureDetector(
                          onTap: () => _openDetailSheet(colors),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: detailSet.isNotEmpty
                                    ? colors.primary.withValues(alpha: 0.35)
                                    : colors.onSurface.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  detailSet.isNotEmpty
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.add_circle_outline_rounded,
                                  size: 16,
                                  color: detailSet.isNotEmpty
                                      ? colors.accent
                                      : colors.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    detailSet.isNotEmpty
                                        ? detailSet.join(' · ')
                                        : 'Add flow, sleep & more (optional)',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: detailSet.isNotEmpty
                                          ? colors.accent
                                          : colors.onSurface.withValues(alpha: 0.35),
                                      fontWeight: detailSet.isNotEmpty
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: colors.onSurface.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 28),

                        // ── Save ─────────────────────────────────────
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _isSaving ? null : _save,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: _canSave
                                  ? LinearGradient(colors: [colors.primary, colors.secondary])
                                  : LinearGradient(colors: [
                                      colors.onSurface.withValues(alpha: 0.1),
                                      colors.onSurface.withValues(alpha: 0.07),
                                    ]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _canSave
                                  ? [
                                      BoxShadow(
                                        color: colors.primary.withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _saved
                                          ? 'Saved ✓'
                                          : (_canSave ? 'Save today 💜' : 'Record your check-in 💜'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: _canSave
                                            ? Colors.white
                                            : colors.onSurface.withValues(alpha: 0.3),
                                      ),
                                    ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 220.ms),
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
              child: LunaBottomNav(currentIndex: -1),
            ),
          ],
        ),
      );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: mainScaffold,
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  final PhaseColors colors;
  const _SheetSectionLabel({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: colors.onSurface.withValues(alpha: 0.4),
        letterSpacing: 1.1,
      ),
    );
  }
}

/// Clean, minimal energy slider with cycle-intelligent dynamic baseline.
/// Pinned zero-drift readout, continuous non-jumping interpolation, sharp architectural thumb.
class _EnergySection extends StatelessWidget {
  final int? energy;
  final int suggestedEnergy;
  final bool isPersonalized;
  final PhaseColors colors;
  final ValueChanged<int?> onChanged;

  const _EnergySection({
    required this.energy,
    required this.suggestedEnergy,
    this.isPersonalized = false,
    required this.colors,
    required this.onChanged,
  });

  static const List<String> _words = [
    'Drained',
    'Low',
    'Steady',
    'High',
    'Peak',
  ];

  static const List<String> _subs = [
    'Running on empty · gentle rest',
    'Low reserves · moving slowly',
    'Steady · balanced & present',
    'Good momentum · energized',
    'Radiant · peak physical vitality',
  ];

  @override
  Widget build(BuildContext context) {
    final hasValue = energy != null;
    final currentVal = (energy ?? suggestedEnergy).clamp(1, 5).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: hasValue ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, activeProgress, child) {
        final activeTrackColor = Color.lerp(
          colors.primary.withValues(alpha: 0.18),
          colors.primary.withValues(alpha: 0.45),
          activeProgress,
        )!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Section title & pinned status readout (zero horizontal drift)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ENERGY',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                // Pinned right-aligned container with zero lateral drift or floating
                SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      // Predicted / Baseline readout
                      AnimatedOpacity(
                        opacity: hasValue ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          ignoring: hasValue,
                          child: GestureDetector(
                            onTap: () => onChanged(suggestedEnergy),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.accent.withValues(alpha: 0.70),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isPersonalized
                                        ? 'Your usual · ${_words[suggestedEnergy - 1]}'
                                        : 'Predicted · ${_words[suggestedEnergy - 1]}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.accent.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Confirmed user readout (pinned to exact same right margin)
                      AnimatedOpacity(
                        opacity: hasValue ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          ignoring: !hasValue,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _words[(energy ?? suggestedEnergy).clamp(1, 5) - 1],
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => onChanged(null),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: colors.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Clean, non-jumping slider with sharp, architectural glowing thumb
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!hasValue) {
                  onChanged(suggestedEnergy);
                }
              },
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: activeTrackColor,
                  inactiveTrackColor: colors.onSurface.withValues(alpha: 0.06),
                  thumbShape: _LunaSliderThumbShape(
                    radius: 10.0 + 1.5 * activeProgress,
                    activeProgress: activeProgress,
                    primaryColor: colors.primary,
                    accentColor: colors.accent,
                    surfaceColor: colors.surface,
                    onSurfaceColor: colors.onSurface,
                  ),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: currentVal,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Bottom anchor hints & subtle feedback
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    'Drained',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: colors.onSurface.withValues(
                        alpha: (hasValue && energy == 1) ? 0.65 : 0.22,
                      ),
                      fontWeight: (hasValue && energy == 1) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hasValue
                          ? _subs[(energy ?? suggestedEnergy).clamp(1, 5) - 1]
                          : (isPersonalized
                              ? 'Matches your cycle pattern'
                              : 'Slide or tap to record rhythm'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(
                          alpha: hasValue ? 0.45 : 0.25,
                        ),
                        fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                  Text(
                    'Peak',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: colors.onSurface.withValues(
                        alpha: (hasValue && energy == 5) ? 0.65 : 0.22,
                      ),
                      fontWeight: (hasValue && energy == 5) ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ).animate().fadeIn(delay: 80.ms);
  }
}

/// Custom slider thumb that preserves sharp, elegant architectural character in both states.
/// Deep obsidian body, crisp precision rim, and blooming celestial jewel pip.
class _LunaSliderThumbShape extends SliderComponentShape {
  final double radius;
  final double activeProgress; // 0.0 (unconfirmed baseline) to 1.0 (confirmed)
  final Color primaryColor;
  final Color accentColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  const _LunaSliderThumbShape({
    required this.radius,
    required this.activeProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius + 3);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // 1. Crisp, subtle drop shadow (no loud blurry halo)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 1.5), radius, shadowPaint);

    // 2. Base body — stays dark, grounded, and sophisticated in both states
    final bodyColor = Color.lerp(
      surfaceColor,
      Color.lerp(surfaceColor, primaryColor, 0.22)!,
      activeProgress,
    )!;
    final bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bodyPaint);

    // 3. Crisp outer precision rim (1.5px) in accent color
    final ringColor = Color.lerp(
      accentColor.withValues(alpha: 0.55),
      accentColor.withValues(alpha: 0.92),
      activeProgress,
    )!;
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ringPaint);

    // 4. Center jewel pip — blooms confidently from delicate dot to rich jewel core
    final pipRadius = radius * (0.30 + 0.16 * activeProgress);
    final pipColor = Color.lerp(
      accentColor.withValues(alpha: 0.85),
      accentColor,
      activeProgress,
    )!;
    final pipPaint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pipRadius, pipPaint);

    // 5. Subtle specular highlight on the jewel when active for sharp character
    if (activeProgress > 0.25) {
      final specAlpha = 0.52 * activeProgress;
      final specPaint = Paint()
        ..color = Colors.white.withValues(alpha: specAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        center.translate(-pipRadius * 0.25, -pipRadius * 0.25),
        pipRadius * 0.32,
        specPaint,
      );
    }
  }
}
