import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../shared/widgets/bottom_nav.dart';

String _monthName(int m) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  if (m >= 1 && m <= 12) return months[m - 1];
  return '';
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(phaseColorsProvider);
    final logs = ref.watch(logEntriesProvider);
    final profile = ref.watch(profileProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final todayEntry = ref.watch(todayLogProvider);
    final currentPhase = ref.watch(currentPhaseProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient luxury glow
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                // Top App Bar / Header
                _InsightsHeader(
                  colors: colors,
                  cycleState: cycleState,
                  profile: profile,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 20),

                // 1. Cycle Architecture & Blueprint Card (Always Visible & Active)
                _CycleBlueprintCard(
                  colors: colors,
                  profile: profile,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 18),

                // 2. Today's Biological Pulse Card (Logged or Inline Check-in)
                _TodayPulseCard(
                  colors: colors,
                  todayEntry: todayEntry,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 18),

                // 3. 7-Day Energy Rhythm (Actual Logs + Projected Phase Baseline)
                _EnergyRhythmCard(
                  colors: colors,
                  logs: logs,
                  profile: profile,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 18),

                // 4. Emotional Climate & Mood Trends
                _MoodClimateCard(
                  colors: colors,
                  logs: logs,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 18),

                // 5. Phase Hormone Intelligence (Metabolism, Sleep, & Training)
                _PhaseIntelligenceSection(
                  colors: colors,
                  currentPhase: currentPhase,
                  cycleState: cycleState,
                ),
                const SizedBox(height: 18),

                // 6. Symptom Watchlist & Logged History
                _SymptomsSection(
                  colors: colors,
                  logs: logs,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 18),

                // 7. Cycle & Period History
                _PeriodHistorySection(
                  colors: colors,
                  logs: logs,
                  profile: profile,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Floating Navigation Bar
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LunaBottomNav(currentIndex: 4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _InsightsHeader extends StatelessWidget {
  final PhaseColors colors;
  final CycleState? cycleState;
  final UserProfile? profile;
  final CyclePhase currentPhase;

  const _InsightsHeader({
    required this.colors,
    required this.cycleState,
    required this.profile,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    final phaseInfo = PhaseConstants.getPhaseInfo(currentPhase);
    final hasCycleStarted = profile?.lastPeriodStart != null && cycleState != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cycle Insights',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: hasCycleStarted ? colors.accent : Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasCycleStarted
                      ? '${phaseInfo.name} Phase · Day ${cycleState!.dayOfCycle} of ${profile!.averageCycleLength}'
                      : 'Cycle Blueprint · ${profile?.averageCycleLength ?? 28}-day model',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
        InkWell(
          onTap: () => context.push('/log'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 16, color: colors.accent),
                const SizedBox(width: 5),
                Text(
                  'Log Day',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. CYCLE BLUEPRINT & ARCHITECTURE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CycleBlueprintCard extends StatelessWidget {
  final PhaseColors colors;
  final UserProfile? profile;
  final CycleState? cycleState;
  final CyclePhase currentPhase;

  const _CycleBlueprintCard({
    required this.colors,
    required this.profile,
    required this.cycleState,
    required this.currentPhase,
  });

  void _showPhaseDetails(BuildContext context, CyclePhase phase) {
    final info = PhaseConstants.getPhaseInfo(phase);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${info.name} Phase',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      info.tagline,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              info.scienceBody,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.8),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Optimal Nutrition Focus:',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: info.eatThis.take(3).map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    e,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cycleLen = profile?.averageCycleLength ?? 28;
    final periodLen = profile?.averagePeriodLength ?? 5;
    final hasCycle = profile?.lastPeriodStart != null && cycleState != null;
    final dayNum = hasCycle ? cycleState!.dayOfCycle : 0;

    String nextPeriodText;
    String nextPeriodSub;
    if (hasCycle) {
      final daysLeft = cycleState!.daysUntilNextPeriod;
      if (daysLeft > 0) {
        nextPeriodText = 'In $daysLeft days';
        nextPeriodSub = 'Est. ${_monthName(cycleState!.nextPeriodDate!.month)} ${cycleState!.nextPeriodDate!.day}';
      } else if (daysLeft == 0) {
        nextPeriodText = 'Expected Today';
        nextPeriodSub = 'Flow anticipated';
      } else {
        nextPeriodText = '${daysLeft.abs()}d overdue';
        nextPeriodSub = 'Irregularity buffer';
      }
    } else {
      nextPeriodText = 'Ready';
      nextPeriodSub = 'Tap to record';
    }

    // Segment lengths based on cycle
    final mDays = periodLen.clamp(3, 7);
    final fDays = ((cycleLen / 2) - mDays).round().clamp(5, 12);
    const oDays = 3;
    final lDays = (cycleLen - mDays - fDays - oDays).clamp(6, 16);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle Architecture',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasCycle ? 'Day $dayNum of $cycleLen' : 'Active Model',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Pills
          Row(
            children: [
              _MetricTile(
                title: 'Cycle Length',
                value: '$cycleLen days',
                subtitle: 'Typical rhythm',
                colors: colors,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                title: 'Period Flow',
                value: '$periodLen days',
                subtitle: 'Window length',
                colors: colors,
              ),
              const SizedBox(width: 8),
              _MetricTile(
                title: 'Next Cycle',
                value: nextPeriodText,
                subtitle: nextPeriodSub,
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Horizontal Phase Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: mDays,
                    child: Container(
                      color: const Color(0xFFE07070),
                      margin: const EdgeInsets.only(right: 2),
                    ),
                  ),
                  Expanded(
                    flex: fDays,
                    child: Container(
                      color: const Color(0xFF4CAF87),
                      margin: const EdgeInsets.only(right: 2),
                    ),
                  ),
                  Expanded(
                    flex: oDays,
                    child: Container(
                      color: const Color(0xFFF2B43A),
                      margin: const EdgeInsets.only(right: 2),
                    ),
                  ),
                  Expanded(
                    flex: lDays,
                    child: Container(
                      color: const Color(0xFF9B84D4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Interactive 4-Phase Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PhasePill(
                emoji: '🩸',
                label: 'Menstrual',
                range: '1–$mDays d',
                color: const Color(0xFFE07070),
                onTap: () => _showPhaseDetails(context, CyclePhase.menstrual),
              ),
              _PhasePill(
                emoji: '🌱',
                label: 'Follicular',
                range: '${mDays + 1}–${mDays + fDays} d',
                color: const Color(0xFF4CAF87),
                onTap: () => _showPhaseDetails(context, CyclePhase.follicular),
              ),
              _PhasePill(
                emoji: '✨',
                label: 'Ovulation',
                range: '${mDays + fDays + 1}–${mDays + fDays + oDays} d',
                color: const Color(0xFFF2B43A),
                onTap: () => _showPhaseDetails(context, CyclePhase.ovulatory),
              ),
              _PhasePill(
                emoji: '🌙',
                label: 'Luteal',
                range: '${cycleLen - lDays + 1}–$cycleLen d',
                color: const Color(0xFF9B84D4),
                onTap: () => _showPhaseDetails(context, CyclePhase.lateLuteal),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final PhaseColors colors;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                color: colors.accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  final String emoji;
  final String label;
  final String range;
  final Color color;
  final VoidCallback onTap;

  const _PhasePill({
    required this.emoji,
    required this.label,
    required this.range,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              range,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. TODAY'S BIOLOGICAL PULSE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TodayPulseCard extends ConsumerWidget {
  final PhaseColors colors;
  final LogEntry? todayEntry;
  final CycleState? cycleState;
  final CyclePhase currentPhase;

  const _TodayPulseCard({
    required this.colors,
    required this.todayEntry,
    required this.cycleState,
    required this.currentPhase,
  });

  Future<void> _recordQuickMood(BuildContext context, WidgetRef ref, MoodLevel mood) async {
    final entry = LogEntry(
      id: todayEntry?.id ?? const Uuid().v4(),
      date: DateTime.now(),
      mood: mood,
      energyLevel: todayEntry?.energyLevel ?? 3,
      flow: todayEntry?.flow,
      cramps: todayEntry?.cramps,
      symptoms: todayEntry?.symptoms ?? [],
      notes: todayEntry?.notes,
      periodStarted: todayEntry?.periodStarted ?? false,
    );
    await ref.read(logEntriesProvider.notifier).addEntry(entry);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recorded ${mood.emoji} ${mood.label} for today 💜"),
          backgroundColor: const Color(0xFF2A1F3D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getBiologicalTakeaway(CyclePhase phase, MoodLevel mood, int energy) {
    if (phase == CyclePhase.menstrual) {
      if (energy <= 2) {
        return 'Systemic reset: Lowest progesterone & estrogen slow mitochondrial output. Resting today directly lowers cramping.';
      }
      return 'Restorative renewal: Your body is clearing the endometrial lining while beginning follicular recruitment.';
    } else if (phase == CyclePhase.follicular) {
      return 'Estrogen ascendance: Rising estradiol enhances frontal lobe connectivity, focus, and dopamine reception.';
    } else if (phase == CyclePhase.ovulatory) {
      return 'Peak radiance: The LH surge and testosterone spike boost confidence, verbal dexterity, and metabolic throughput.';
    } else {
      if (mood == MoodLevel.struggling || mood == MoodLevel.low) {
        return 'Amygdala sensitivity: Dropping progesterone temporarily reduces GABA receptors. Your feelings are neurochemically valid.';
      }
      return 'Progesterone plateau: Calorie burn rises by 5–10%. Slower digestion promotes steady nutrient extraction.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLogged = todayEntry != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasLogged
              ? colors.accent.withValues(alpha: 0.25)
              : colors.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasLogged ? "Today's Biological Pulse" : 'Daily Check-in',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasLogged
                      ? colors.accent.withValues(alpha: 0.15)
                      : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasLogged ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 11,
                      color: hasLogged ? colors.accent : Colors.amberAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasLogged ? 'Logged' : 'Awaiting pulse',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: hasLogged ? colors.accent : Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (hasLogged) ...[
            // Today's summary row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    todayEntry!.mood.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayEntry!.mood.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'Energy Level:',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ...List.generate(5, (i) {
                            final filled = i < todayEntry!.energyLevel;
                            return Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 14,
                                color: filled
                                    ? colors.accent
                                    : colors.onSurface.withValues(alpha: 0.15),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/log'),
                  icon: Icon(Icons.edit_outlined, size: 18, color: colors.accent),
                  tooltip: 'Edit today',
                ),
              ],
            ),

            if (todayEntry!.symptoms.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: todayEntry!.symptoms.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.onSurface.withValues(alpha: 0.07)),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getBiologicalTakeaway(currentPhase, todayEntry!.mood, todayEntry!.energyLevel),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.75),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Tap your mood to record your daily biological state:',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),

            // 6 Mood Emoji Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: MoodLevel.values.map((m) {
                return InkWell(
                  onTap: () => _recordQuickMood(context, ref, m),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
                    ),
                    child: Text(
                      m.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            InkWell(
              onTap: () => context.push('/log'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text(
                    'Open Detailed Logger (Energy, Flow, Symptoms) →',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 60.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. 7-DAY ENERGY RHYTHM MATRIX (NO BLANKS!)
// ─────────────────────────────────────────────────────────────────────────────
class _EnergyRhythmCard extends StatelessWidget {
  final PhaseColors colors;
  final List<LogEntry> logs;
  final UserProfile? profile;
  final CyclePhase currentPhase;

  const _EnergyRhythmCard({
    required this.colors,
    required this.logs,
    required this.profile,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final monday = now.subtract(Duration(days: todayWeekday - 1));

    final weekDays = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });

    const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    // Projected baseline energy per phase
    int baselineEnergy;
    switch (currentPhase) {
      case CyclePhase.menstrual:
        baselineEnergy = 2;
        break;
      case CyclePhase.follicular:
        baselineEnergy = 4;
        break;
      case CyclePhase.ovulatory:
        baselineEnergy = 5;
        break;
      case CyclePhase.earlyLuteal:
        baselineEnergy = 3;
        break;
      case CyclePhase.lateLuteal:
        baselineEnergy = 2;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Energy Rhythm',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Text(
                'Scale 1–5',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Actual logged levels paired with biological phase baseline',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),

          // 7 Days Chart
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final date = weekDays[i];
                final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                final isFuture = date.isAfter(now);

                // Find log for this day
                LogEntry? matchingLog;
                for (final l in logs) {
                  if (l.date.year == date.year && l.date.month == date.month && l.date.day == date.day) {
                    matchingLog = l;
                    break;
                  }
                }

                final hasLog = matchingLog != null;
                final displayEnergy = hasLog ? matchingLog.energyLevel : baselineEnergy;
                final barHeight = (displayEnergy / 5.0) * 64.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Energy badge on top of bar
                        Text(
                          hasLog ? '$displayEnergy' : '~$displayEnergy',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: hasLog ? FontWeight.w700 : FontWeight.w400,
                            color: hasLog
                                ? colors.accent
                                : colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // The Bar
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: hasLog
                                ? (isToday
                                    ? colors.accent
                                    : colors.primary.withValues(alpha: 0.75))
                                : colors.onSurface.withValues(alpha: isFuture ? 0.05 : 0.09),
                            borderRadius: BorderRadius.circular(6),
                            border: hasLog
                                ? null
                                : Border.all(
                                    color: colors.onSurface.withValues(alpha: 0.12),
                                    style: BorderStyle.solid,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Day label & date number
                        Text(
                          dayLabels[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday
                                ? colors.accent
                                : colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Logged Energy',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Hormonal Baseline (~$baselineEnergy/5)',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. EMOTIONAL CLIMATE & MOOD TRENDS
// ─────────────────────────────────────────────────────────────────────────────
class _MoodClimateCard extends StatelessWidget {
  final PhaseColors colors;
  final List<LogEntry> logs;
  final CycleState? cycleState;
  final CyclePhase currentPhase;

  const _MoodClimateCard({
    required this.colors,
    required this.logs,
    required this.cycleState,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]..sort((a, b) => b.date.compareTo(a.date));
    final moodCounts = <MoodLevel, int>{};
    for (final l in sorted) {
      moodCounts[l.mood] = (moodCounts[l.mood] ?? 0) + 1;
    }

    final totalCount = logs.length;
    final dominantMood = moodCounts.isEmpty
        ? null
        : moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emotional Climate',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              if (dominantMood != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dominantMood.emoji} ${dominantMood.label}',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (totalCount == 0) ...[
            Text(
              'Your emotional patterns become clearer as you log. In your ${PhaseConstants.getPhaseInfo(currentPhase).name} phase, hormones naturally modulate neurotransmitters like serotonin and dopamine.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Track 3+ check-ins to map luteal sensitivity vs. follicular optimism.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (totalCount == 1) ...[
            // Single entry anchor presentation
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      dominantMood!.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First Mood Anchor Recorded',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Feeling ${dominantMood.label} (100% of tracking)',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'As you continue logging through your cycle, Luna compares your emotional baseline across all 4 hormonal phases.',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
          ] else ...[
            // Multi-entry breakdown
            ...MoodLevel.values.reversed.where((m) => (moodCounts[m] ?? 0) > 0).map((m) {
              final count = moodCounts[m] ?? 0;
              final pct = count / totalCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(m.emoji, style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct.clamp(0.05, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${(pct * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 140.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PHASE HORMONE INTELLIGENCE (METABOLISM, SLEEP & TRAINING)
// ─────────────────────────────────────────────────────────────────────────────
class _PhaseIntelligenceSection extends StatelessWidget {
  final PhaseColors colors;
  final CyclePhase currentPhase;
  final CycleState? cycleState;

  const _PhaseIntelligenceSection({
    required this.colors,
    required this.currentPhase,
    required this.cycleState,
  });

  @override
  Widget build(BuildContext context) {
    final info = PhaseConstants.getPhaseInfo(currentPhase);

    String nutritionTip;
    String sleepTip;
    String workoutTip;

    switch (currentPhase) {
      case CyclePhase.menstrual:
        nutritionTip = 'Iron replenishing & magnesium-dense foods. Dark chocolate (70%+), red lentils, warm bone broths, and ginger tea.';
        sleepTip = 'Sleep needs increase by 1–2 hours. Uterine contractions demand cellular repair during deep non-REM delta wave sleep.';
        workoutTip = 'Restorative movement only. Gentle walks, pelvic yoga, and slow stretching. Avoid strenuous HIIT to prevent cortisol elevation.';
        break;
      case CyclePhase.follicular:
        nutritionTip = 'Insulin sensitivity is peak. Complex carbohydrates, sprouted seeds (flax & pumpkin), and fermented foods aid healthy estrogen metabolism.';
        sleepTip = 'High melatonin sensitivity and stable core temperature promote restorative sleep and natural morning alertness.';
        workoutTip = 'Estrogen acts as an anabolic driver. Ideal window for progressive strength training, learning new skills, and high cardio intensity.';
        break;
      case CyclePhase.ovulatory:
        nutritionTip = 'Liver clearance support. Increase cruciferous vegetables (broccoli, cabbage), zinc, and extra hydration for peak cervical fluid.';
        sleepTip = 'Energy is high and body temperature rises slightly with LH surge. Ensure 15 minutes of evening wind-down to ease neural stimulation.';
        workoutTip = 'Maximum strength and high pain tolerance. Optimal time for personal records and high-intensity sprint training.';
        break;
      case CyclePhase.earlyLuteal:
        nutritionTip = 'Progesterone elevates metabolic rate by 100–300 kcal/day. Prioritize magnesium, healthy fats (avocado, seeds), and steady protein.';
        sleepTip = 'Core body temperature rises by ~0.5°C. Keep your bedroom cooler (18°C) to prevent night waking and support REM cycles.';
        workoutTip = 'Shift towards steady-state endurance, moderate resistance, and Pilates. Longer rest periods between sets.';
        break;
      case CyclePhase.lateLuteal:
        nutritionTip = 'Serotonin production depends on steady blood sugar. Eat complex carbs every 3–4 hours (sweet potato, oats) to prevent mood crashes.';
        sleepTip = 'Progesterone drop can cause light, fragmented sleep. A warm magnesium bath and zero caffeine after 12pm greatly helps.';
        workoutTip = 'Cortisol sensitivity is heightened. Avoid high-stress workouts. Embrace walking in nature, slow swimming, and gentle movement.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(info.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Phase Science: ${info.name}',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.scienceTitle,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 16),

          _ScienceTipTile(
            icon: '🥗',
            title: 'Metabolism & Nutrition',
            body: nutritionTip,
            colors: colors,
          ),
          const SizedBox(height: 10),

          _ScienceTipTile(
            icon: '😴',
            title: 'Sleep & Circadian Rhythm',
            body: sleepTip,
            colors: colors,
          ),
          const SizedBox(height: 10),

          _ScienceTipTile(
            icon: '⚡',
            title: 'Movement & Training',
            body: workoutTip,
            colors: colors,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms, duration: 400.ms);
  }
}

class _ScienceTipTile extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final PhaseColors colors;

  const _ScienceTipTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.65),
                    height: 1.45,
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

// ─────────────────────────────────────────────────────────────────────────────
// 6. SYMPTOM WATCHLIST & LOGGED HISTORY
// ─────────────────────────────────────────────────────────────────────────────
class _SymptomsSection extends StatelessWidget {
  final PhaseColors colors;
  final List<LogEntry> logs;
  final CyclePhase currentPhase;

  const _SymptomsSection({
    required this.colors,
    required this.logs,
    required this.currentPhase,
  });

  @override
  Widget build(BuildContext context) {
    final symptomCounts = <String, int>{};
    for (final l in logs) {
      for (final s in l.symptoms) {
        symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
      }
    }

    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Phase-specific recommended watchlist
    List<String> phaseWatchlist;
    switch (currentPhase) {
      case CyclePhase.menstrual:
        phaseWatchlist = ['Cramps', 'Bloating', 'Fatigue', 'Headache', 'Backache'];
        break;
      case CyclePhase.follicular:
        phaseWatchlist = ['High Energy', 'Mental Clarity', 'Clear Skin', 'Light'];
        break;
      case CyclePhase.ovulatory:
        phaseWatchlist = ['Cervical Fluid', 'Ovulation Twinge', 'High Libido', 'Tender Breasts'];
        break;
      case CyclePhase.earlyLuteal:
        phaseWatchlist = ['Calm Focus', 'Appetite Increase', 'Bloating'];
        break;
      case CyclePhase.lateLuteal:
        phaseWatchlist = ['Mood Sensitivity', 'Cravings', 'Bloating', 'Insomnia', 'Tired'];
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Symptom Intelligence',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              InkWell(
                onTap: () => context.push('/log'),
                child: Text(
                  '+ Add today',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (sortedSymptoms.isNotEmpty) ...[
            Text(
              'Your tracked symptoms across all logs:',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedSymptoms.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value}×',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Typical signals for ${PhaseConstants.getPhaseInfo(currentPhase).name} phase:',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: phaseWatchlist.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
                ),
                child: Text(
                  s,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 220.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. CYCLE & PERIOD HISTORY SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodHistorySection extends ConsumerWidget {
  final PhaseColors colors;
  final List<LogEntry> logs;
  final UserProfile? profile;

  const _PeriodHistorySection({
    required this.colors,
    required this.logs,
    required this.profile,
  });

  Future<void> _recordPeriodDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile?.lastPeriodStart ?? now,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE07070),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1530),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await ref.read(profileProvider.notifier).updateLastPeriod(picked);
      final entry = LogEntry(
        id: const Uuid().v4(),
        date: picked,
        mood: MoodLevel.decent,
        energyLevel: 3,
        symptoms: [],
        periodStarted: true,
      );
      await ref.read(logEntriesProvider.notifier).addEntry(entry);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Period start logged: ${picked.day} ${_monthName(picked.month)} 🩸'),
            backgroundColor: const Color(0xFF2A1F3D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodLogs = logs.where((l) => l.periodStarted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Period History',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              InkWell(
                onTap: () => _recordPeriodDate(context, ref),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07070).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE07070).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🩸', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        'Set Date',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF8FA3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (periodLogs.isNotEmpty) ...[
            ...periodLogs.take(4).map((log) {
              final d = log.date;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07070).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${d.day}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF8FA3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_monthName(d.month)} ${d.day}, ${d.year}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          'Period start logged',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('🩸', style: TextStyle(fontSize: 15)),
                  ],
                ),
              );
            }),
          ] else if (profile?.lastPeriodStart != null) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07070).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${profile!.lastPeriodStart!.day}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF8FA3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthName(profile!.lastPeriodStart!.month)} ${profile!.lastPeriodStart!.day}, ${profile!.lastPeriodStart!.year}',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      'Active cycle anchor',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text('🩸', style: TextStyle(fontSize: 15)),
              ],
            ),
          ] else ...[
            Text(
              'No period start date recorded yet. Tap "Set Date" above whenever your cycle begins.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 260.ms, duration: 400.ms);
  }
}
