import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todayEntry = ref.read(logEntriesProvider.notifier).todayEntry;
      final profile = ref.read(profileProvider);
      final now = DateTime.now();
      final isAnchoredToday = profile?.lastPeriodStart != null &&
          profile!.lastPeriodStart!.year == now.year &&
          profile.lastPeriodStart!.month == now.month &&
          profile.lastPeriodStart!.day == now.day;

      if (todayEntry != null) {
        setState(() {
          _existingEntryId = todayEntry.id;
          if (todayEntry.mood != null) {
            _mood = todayEntry.mood!;
            _moodSelected = true;
          } else {
            _moodSelected = false;
          }
          _energy = todayEntry.energyLevel;
          _flow = todayEntry.flow;
          _cramps = todayEntry.cramps;
          _sleep = todayEntry.sleepQuality;
          _symptoms.clear();
          _symptoms.addAll(todayEntry.symptoms);
          if (todayEntry.notes != null) {
            _notesController.text = todayEntry.notes!;
          }
          _periodAlreadyLoggedToday = todayEntry.periodStarted || isAnchoredToday;
          _periodStarted = _periodAlreadyLoggedToday;
        });
      } else if (isAnchoredToday) {
        setState(() {
          _periodAlreadyLoggedToday = true;
          _periodStarted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getEnergyLabel(int? level) {
    switch (level) {
      case 1:
        return 'Drained · Depleted';
      case 2:
        return 'Low · Slow rhythm';
      case 3:
        return 'Balanced · Steady';
      case 4:
        return 'High · Energized';
      case 5:
        return 'Peak · Radiant';
      default:
        return 'Slide to record';
    }
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
      final entry = LogEntry(
        id: entryId,
        date: DateTime.now(),
        mood: _moodSelected ? _mood : null,
        energyLevel: _energy,
        flow: _flow,
        cramps: _cramps,
        sleepQuality: _sleep,
        symptoms: _symptoms,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        periodStarted: _periodStarted || _flow != null,
      );
      await ref.read(logEntriesProvider.notifier).addEntry(entry);

      // Update cycle anchor and history when period started is marked or active flow logged
      if (_periodStarted || _flow != null) {
        await ref.read(periodHistoryProvider.notifier).addPeriodStart(
          DateTime.now(),
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

    final lastPeriod = profile?.lastPeriodStart;
    final now = DateTime.now();
    final daysSinceAnchor =
        lastPeriod != null ? now.calendarDaysDifference(lastPeriod) : null;
    final periodLength = profile?.averagePeriodLength ?? 5;
    final isInActivePeriod =
        daysSinceAnchor != null && daysSinceAnchor > 0 && daysSinceAnchor < periodLength;

    // Inline detail badge for summary
    final List<String> detailSet = [
      if (_flow != null) ['Spotting', 'Light', 'Medium', 'Heavy'][_flow!.index],
      if (_sleep != null) _sleep!.label,
      if (_cramps != null) ['No cramps', 'Mild cramps', 'Moderate cramps', 'Severe cramps'][_cramps!.index],
    ];

    if (_saved) {
      return Scaffold(
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
      );
    }

    return Scaffold(
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
                            'Day ${cycleState.dayOfCycle} · ${cycleState.phaseInfo.name}',
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
                            'Today\'s check-in',
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
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
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

                        // ── Energy Level (Adult Interactive Slider) ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ENERGY LEVEL',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface.withValues(alpha: 0.35),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _getEnergyLabel(_energy),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: _energy != null
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _energy != null
                                        ? colors.accent
                                        : colors.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                                if (_energy != null) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _energy = null),
                                    child: Icon(Icons.close_rounded,
                                        size: 14,
                                        color: colors.onSurface.withValues(alpha: 0.35)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _energy != null
                                  ? colors.primary.withValues(alpha: 0.3)
                                  : colors.onSurface.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 8,
                                  activeTrackColor: colors.accent,
                                  inactiveTrackColor: colors.background.withValues(alpha: 0.8),
                                  thumbColor: colors.accent,
                                  overlayColor: colors.accent.withValues(alpha: 0.22),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 11,
                                    elevation: 3,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                  tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 3),
                                  activeTickMarkColor: Colors.white,
                                  inactiveTickMarkColor: colors.onSurface.withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: (_energy ?? 3).toDouble(),
                                  min: 1,
                                  max: 5,
                                  divisions: 4,
                                  onChanged: (val) {
                                    setState(() => _energy = val.round());
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '1 · Drained',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: _energy == 1 ? FontWeight.w700 : FontWeight.w500,
                                        color: _energy == 1
                                            ? colors.accent
                                            : colors.onSurface.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Text(
                                      '3 · Balanced',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: _energy == 3 ? FontWeight.w700 : FontWeight.w500,
                                        color: _energy == 3
                                            ? colors.accent
                                            : colors.onSurface.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    Text(
                                      '5 · Peak',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10.5,
                                        fontWeight: _energy == 5 ? FontWeight.w700 : FontWeight.w500,
                                        color: _energy == 5
                                            ? colors.accent
                                            : colors.onSurface.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 120.ms),

                        const SizedBox(height: 22),

                        // ── Period Status & Start Card ─────────────────
                        // Thoughtful & context-aware:
                        // 1. If period started today -> Confirmed state
                        // 2. If currently in active period -> In-progress state
                        // 3. Otherwise -> Clean, welcoming toggle to mark start
                        Builder(builder: (_) {
                          if (_periodStarted) {
                            return GestureDetector(
                              onTap: () => setState(() => _periodStarted = !_periodStarted),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD94F6E).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFD94F6E).withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🩸', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Period started today ✓',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFFF8FA3),
                                            ),
                                          ),
                                          Text(
                                            'Cycle Day 1 · All phases recalibrated to today',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              color: colors.onSurface.withValues(alpha: 0.45),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD94F6E),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (isInActivePeriod) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD94F6E).withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFD94F6E).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Text('🩸', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Period · Day ${daysSinceAnchor + 1}',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFFF8FA3),
                                          ),
                                        ),
                                        Text(
                                          'Active menstrual phase',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            color: colors.onSurface.withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _periodStarted = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD94F6E).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Reset to today',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFF8FA3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Cycle is ongoing / awaiting next period: Welcoming toggle
                            return GestureDetector(
                              onTap: () => setState(() => _periodStarted = !_periodStarted),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colors.onSurface.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🩸', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Period started today?',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: colors.onSurface.withValues(alpha: 0.85),
                                            ),
                                          ),
                                          Text(
                                            'Tap to record Day 1 of your new cycle',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              color: colors.onSurface.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.onSurface.withValues(alpha: 0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }).animate().fadeIn(delay: 140.ms),

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
        ],
      ),
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
