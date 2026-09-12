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
import '../../core/services/cycle_refinement_service.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  MoodLevel _mood = MoodLevel.decent;
  bool _moodSelected = false;
  bool _periodStarted = false;
  bool _periodAlreadyLoggedToday = false; // hides the toggle if already done
  String? _existingEntryId; // if re-logging today, update instead of insert
  final List<String> _symptoms = [];
  bool _showMore = false;
  bool _saved = false;

  // Optional deeper fields
  int _energy = 3;
  FlowLevel? _flow;
  CrampLevel? _cramps;
  final _notesController = TextEditingController();

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
    {'e': '🔥', 'l': 'Hot'},
    {'e': '🌟', 'l': 'Feeling good'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate from today's existing entry (if any)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todayEntry = ref.read(logEntriesProvider.notifier).todayEntry;
      if (todayEntry != null) {
        setState(() {
          _existingEntryId = todayEntry.id;
          _mood = todayEntry.mood;
          _moodSelected = true;
          _energy = todayEntry.energyLevel;
          _flow = todayEntry.flow;
          _cramps = todayEntry.cramps;
          _symptoms.clear();
          _symptoms.addAll(todayEntry.symptoms);
          if (todayEntry.notes != null) {
            _notesController.text = todayEntry.notes!;
          }
          // If period was already logged today, hide the toggle
          _periodAlreadyLoggedToday = todayEntry.periodStarted == true;
          _periodStarted = _periodAlreadyLoggedToday;
        });
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Reuse today's entry ID if we already have one — no duplicate entries
    final entryId = _existingEntryId ?? const Uuid().v4();
    final entry = LogEntry(
      id: entryId,
      date: DateTime.now(),
      mood: _mood,
      energyLevel: _energy,
      flow: _flow,
      cramps: _cramps,
      symptoms: _symptoms,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      periodStarted: _periodStarted,
    );
    await ref.read(logEntriesProvider.notifier).addEntry(entry);
    // If period started, immediately update cycle — the whole app reacts via Riverpod
    if (_periodStarted) {
      await ref.read(profileProvider.notifier).updateLastPeriod(DateTime.now());
    }
    // Refine cycle length based on logged data
    if (_periodStarted) {
      final entries = ref.read(logEntriesProvider);
      final profile = ref.read(profileProvider);
      if (profile != null) {
        final msg = await CycleRefinementService.checkAndRefine(
          profile: profile,
          allEntries: entries,
          onUpdateCycle: (v) => ref.read(profileProvider.notifier).saveProfile(profile.copyWith(averageCycleLength: v)),
          onUpdatePeriod: (v) => ref.read(profileProvider.notifier).saveProfile(profile.copyWith(averagePeriodLength: v)),
        );
        if (msg != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFF2A1F3D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
    setState(() => _saved = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      if (context.canPop()) { context.pop(); } else { context.go('/home'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final profile = ref.watch(profileProvider);
    final hasCycleAnchor = profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0;

    if (_saved) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💜', style: TextStyle(fontSize: 80))
                .animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('Logged 🌙',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 30, fontWeight: FontWeight.w700, color: colors.onSurface)),
            const SizedBox(height: 6),
            Text('You\'re showing up for yourself. That counts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.45))),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [colors.primary.withValues(alpha: 0.14), Colors.transparent]),
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
                        icon: Icon(Icons.close, color: colors.onSurface.withValues(alpha: 0.4), size: 22),
                        onPressed: () {
                          if (context.canPop()) { context.pop(); } else { context.go('/home'); }
                        },
                      ),
                      const Spacer(),
                      Column(children: [
                        Text('Today\'s check-in',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface)),
                        if (cycleState != null)
                          Text(
                            hasCycleAnchor
                                ? 'Day ${cycleState.dayOfCycle} · ${cycleState.phaseInfo.name}'
                                : 'Cycle Blueprint · ${profile?.averageCycleLength ?? 28}-day model',
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                          ),
                      ]),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── MOOD — big, centre, one tap ────────────────────────
                        Text(
                          'How\'s today feeling?',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 24, fontWeight: FontWeight.w700, color: colors.onSurface),
                        ).animate().fadeIn(),
                        const SizedBox(height: 4),
                        Text('Just tap one.',
                            style: GoogleFonts.dmSans(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))
                            .animate().fadeIn(delay: 50.ms),
                        const SizedBox(height: 16),

                        // Selected mood label shown above
                        if (_moodSelected)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              key: ValueKey(_mood),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_mood.emoji} ${_mood.label}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: colors.accent),
                              ),
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: MoodLevel.values.map((m) {
                            final sel = _mood == m && _moodSelected;
                            return GestureDetector(
                              onTap: () => setState(() { _mood = m; _moodSelected = true; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: sel ? colors.primary.withValues(alpha: 0.22) : colors.surface.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel ? colors.primary : colors.onSurface.withValues(alpha: 0.06),
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(m.emoji, style: TextStyle(fontSize: sel ? 26 : 22)),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 22),

                        // ── PERIOD TOGGLE ───────────────────────────────────────
                        if (_periodAlreadyLoggedToday)
                          // Already logged — show locked confirmed banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Text('🩸', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  'Period started today ✓',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                    color: colors.accent),
                                ),
                                Text(
                                  'Cycle day 1 — app updated',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                                ),
                              ]),
                            ]),
                          ).animate().fadeIn()
                        else
                          GestureDetector(
                            onTap: () => setState(() => _periodStarted = !_periodStarted),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: _periodStarted ? colors.primary.withValues(alpha: 0.18) : colors.surface.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _periodStarted ? colors.primary : colors.onSurface.withValues(alpha: 0.06),
                                  width: _periodStarted ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                const Text('🩸', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Text(
                                  'Period started today',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14, fontWeight: FontWeight.w500,
                                    color: colors.onSurface.withValues(alpha: 0.85)),
                                ),
                                const Spacer(),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: _periodStarted ? colors.primary : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _periodStarted ? colors.primary : colors.onSurface.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _periodStarted
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ]),
                            ),
                          ).animate().fadeIn(delay: 150.ms),

                        const SizedBox(height: 22),

                        // ── SYMPTOMS — quick chips ─────────────────────────────
                        Text(
                          'Anything going on?',
                          style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: colors.onSurface.withValues(alpha: 0.5), letterSpacing: 0.3),
                        ).animate().fadeIn(delay: 180.ms),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _quickSymptoms.map((s) {
                            final key = '${s['e']} ${s['l']}';
                            final sel = _symptoms.contains(key);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (sel) { _symptoms.remove(key); } else { _symptoms.add(key); }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? colors.primary.withValues(alpha: 0.22) : colors.surface.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: sel ? colors.primary : colors.onSurface.withValues(alpha: 0.06),
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(s['e']!, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 5),
                                  Text(
                                    s['l']!,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: sel ? colors.accent : colors.onSurface.withValues(alpha: 0.6),
                                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 20),

                        // ── MORE DETAIL (optional, collapsed) ─────────────────
                        GestureDetector(
                          onTap: () => setState(() => _showMore = !_showMore),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(children: [
                              Icon(
                                _showMore ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: colors.onSurface.withValues(alpha: 0.4), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _showMore ? 'Less detail' : 'Add flow, energy & note (optional)',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                              ),
                            ]),
                          ),
                        ).animate().fadeIn(delay: 220.ms),

                        if (_showMore) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Energy ⚡
                                _DetailLabel(emoji: '⚡', label: 'Energy today', colors: colors),
                                const SizedBox(height: 10),
                                Row(children: List.generate(5, (i) {
                                  final filled = i < _energy;
                                  return GestureDetector(
                                    onTap: () => setState(() => _energy = i + 1),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: filled ? colors.primary.withValues(alpha: 0.22) : colors.background.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: filled ? colors.primary : colors.onSurface.withValues(alpha: 0.06), width: filled ? 1.5 : 1),
                                        ),
                                        child: Center(child: Text('⚡', style: TextStyle(fontSize: filled ? 20 : 16, color: filled ? null : Colors.white.withValues(alpha: 0.25)))),
                                      ),
                                    ),
                                  );
                                })),

                                const SizedBox(height: 18),
                                Container(height: 1, color: colors.onSurface.withValues(alpha: 0.05)),
                                const SizedBox(height: 16),

                                // Flow 🩸
                                _DetailLabel(emoji: '🩸', label: 'Flow', colors: colors),
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
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: sel ? colors.primary.withValues(alpha: 0.22) : colors.background.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: sel ? colors.primary : Colors.transparent, width: 1.5),
                                          ),
                                          child: Center(child: Text(labels[f.index],
                                              style: GoogleFonts.dmSans(fontSize: 11, color: sel ? colors.accent : colors.onSurface.withValues(alpha: 0.55), fontWeight: sel ? FontWeight.w700 : FontWeight.w400))),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 18),
                                Container(height: 1, color: colors.onSurface.withValues(alpha: 0.05)),
                                const SizedBox(height: 16),

                                // Cramps
                                _DetailLabel(emoji: '😣', label: 'Cramps', colors: colors),
                                const SizedBox(height: 10),
                                Row(
                                  children: CrampLevel.values.map((c) {
                                    final labels = ['None', 'Mild', 'Moderate', 'Severe'];
                                    final emojis = ['😌', '😐', '😣', '😭'];
                                    final sel = _cramps == c;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _cramps = sel ? null : c),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: sel ? colors.primary.withValues(alpha: 0.22) : colors.background.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: sel ? colors.primary : Colors.transparent, width: 1.5),
                                          ),
                                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                                            Text(emojis[c.index], style: const TextStyle(fontSize: 16)),
                                            const SizedBox(height: 3),
                                            Text(labels[c.index],
                                                style: GoogleFonts.dmSans(fontSize: 10, color: sel ? colors.accent : colors.onSurface.withValues(alpha: 0.45))),
                                          ]),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 18),
                                Container(height: 1, color: colors.onSurface.withValues(alpha: 0.05)),
                                const SizedBox(height: 16),

                                // Notes
                                _DetailLabel(emoji: '✏️', label: 'Anything on your mind', colors: colors),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  style: GoogleFonts.dmSans(fontSize: 14, color: colors.onSurface),
                                  decoration: InputDecoration(
                                    filled: true, fillColor: colors.background.withValues(alpha: 0.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: colors.accent, width: 1.5)),
                                    hintText: 'Whatever\'s on your mind...',
                                    hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 13),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ── SAVE ────────────────────────────────────────────────
                        GestureDetector(
                          onTap: _save,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.35),
                                  blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Center(
                              child: Text('Save today 💜',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ).animate().fadeIn(delay: 250.ms),
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

class _DetailLabel extends StatelessWidget {
  final String emoji;
  final String label;
  final PhaseColors colors;
  const _DetailLabel({required this.emoji, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 7),
      Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: colors.onSurface.withValues(alpha: 0.5)),
      ),
    ]);
  }
}
