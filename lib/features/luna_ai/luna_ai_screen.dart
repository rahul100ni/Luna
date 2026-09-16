import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/log_entry.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/deepseek_service.dart';

class LunaAiScreen extends ConsumerStatefulWidget {
  const LunaAiScreen({super.key});

  @override
  ConsumerState<LunaAiScreen> createState() => _LunaAiScreenState();
}

class _LunaAiScreenState extends ConsumerState<LunaAiScreen>
    with TickerProviderStateMixin {
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
  List<_ChatMessage> _chatHistory = [];
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

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

  @override
  void dispose() {
    _textController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    if (_selectedMood == null && _textController.text.trim().isEmpty) return;
    if (_loading) return;

    final userText = _textController.text.trim();
    setState(() {
      _loading = true;
      _response = null;
    });

    final profile = ref.read(profileProvider);
    final cycleState = ref.read(cycleStateProvider);
    final todayEntry = ref.read(todayLogProvider);
    final patternProfile = ref.read(patternProfileProvider);
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
      );
    }

    // Store the user message text before we clear for check-in history seeding
    _lastUserText = userText;
    setState(() {
      _response = response;
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
            text: _response!.validation, isUser: false, time: DateTime.now()),
      ];
      _chatMode = true;
    });

    _scrollToBottom();
  }

  Future<void> _sendChatMessage([String? prefilledText]) async {
    final text = prefilledText ?? _chatController.text.trim();
    if (text.isEmpty || _chatLoading) return;
    if (prefilledText == null) {
      _chatController.clear();
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
    if (profile == null || cycleState == null) {
      setState(() => _chatLoading = false);
      return;
    }

    final hasCycleAnchor =
        profile.lastPeriodStart != null && cycleState.dayOfCycle > 0;
    final allSymptoms =
        {..._selectedSymptoms, ...?todayEntry?.symptoms}.toList();

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
      messages: _chatHistory
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList(),
    );

    setState(() {
      _chatHistory.add(
          _ChatMessage(text: response, isUser: false, time: DateTime.now()));
      _chatLoading = false;
    });
    _scrollToBottom();
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

    // Chat mode — full-screen chat UI
    if (_chatMode) {
      return _buildChatMode(context, colors, profile, cycleState);
    }

    // Check-in mode
    return Scaffold(
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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

                        const SizedBox(height: 32),

                        if (_response == null && !_loading) ...[
                          Text('How are you feeling right now?',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface),
                          ).animate().fadeIn(delay: 100.ms),
                          const SizedBox(height: 6),
                          Text('Be honest — Luna won\'t judge.',
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
                                    _textController.clear();
                                    _showScienceCard = false;
                                    _showTextInput = false;
                                    _lastUserText = '';
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
        ],
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
                          _chatHistory = [];
                          _chatController.clear();
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
                      return _buildMessageBubble(msg, colors);
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

  Widget _buildMessageBubble(_ChatMessage msg, dynamic colors) {
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
            child: Container(
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
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
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
  const _ChatMessage({required this.text, required this.isUser, required this.time});
}
