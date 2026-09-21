import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/period_entry.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../core/services/pattern_analysis_service.dart';
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
    final patternProfile = ref.watch(patternProfileProvider);

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return true;
      },
      child: Scaffold(
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
                const SizedBox(height: 18),

                // 1. Cycle Architecture & Blueprint Card (Top Placement)
                _CycleBlueprintCard(
                  colors: colors,
                  profile: profile,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 16),

                // 2. Daily Check-in Card (Today's Biological Pulse)
                _TodayPulseCard(
                  colors: colors,
                  todayEntry: todayEntry,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 16),

                // 3. Phase Hormone Intelligence (Metabolism, Sleep, & Training)
                _PhaseIntelligenceSection(
                  colors: colors,
                  currentPhase: currentPhase,
                  cycleState: cycleState,
                ),
                const SizedBox(height: 16),

                // 4. 7-Day Energy Rhythm (Hidden if no energy logged this week)
                _EnergyRhythmCard(
                  colors: colors,
                  logs: logs,
                  profile: profile,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 16),

                // 5. Emotional Climate & Mood Trends
                _MoodClimateCard(
                  colors: colors,
                  logs: logs,
                  cycleState: cycleState,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 16),

                // 6. Symptom Watchlist & Logged History
                _SymptomsSection(
                  colors: colors,
                  logs: logs,
                  currentPhase: currentPhase,
                ),
                const SizedBox(height: 16),

                // 7. Pattern Intelligence (Personal Biomarker Discoveries)
                if (profile?.lastPeriodStart != null && (cycleState?.dayOfCycle ?? 0) > 0) ...[
                  _DiscoveredPatternsCard(
                    colors: colors,
                    patternProfile: patternProfile,
                  ),
                  const SizedBox(height: 16),
                ],

                // 8. Cycle & Period History
                _PeriodHistorySection(
                  colors: colors,
                  profile: profile,
                ),
                const SizedBox(height: 20),
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
class _CycleBlueprintCard extends ConsumerWidget {
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
      isScrollControlled: true,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleLen = profile?.averageCycleLength ?? 28;
    final periodLen = profile?.averagePeriodLength ?? 5;
    final hasCycle = profile?.lastPeriodStart != null && cycleState != null;
    final dayNum = hasCycle ? cycleState!.dayOfCycle : 0;
    final isUnknown = ref.watch(isCycleLengthUnknownProvider);

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
                value: isUnknown ? 'Calibrating' : '$cycleLen days',
                subtitle: isUnknown ? '28d baseline' : 'Typical rhythm',
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
                onTap: hasCycle ? null : () => context.push('/log'),
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
  final VoidCallback? onTap;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = onTap != null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isInteractive
                ? colors.primary.withValues(alpha: 0.14)
                : colors.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInteractive
                  ? colors.accent.withValues(alpha: 0.3)
                  : colors.onSurface.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: colors.onSurface.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isInteractive)
                    Icon(Icons.arrow_forward_rounded, size: 10, color: colors.accent),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isInteractive ? colors.accent : colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: isInteractive ? FontWeight.w600 : FontWeight.w400,
                  color: colors.accent.withValues(alpha: isInteractive ? 0.95 : 0.7),
                ),
              ),
            ],
          ),
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

  Future<void> _recordQuickMood(
      BuildContext context, WidgetRef ref, MoodLevel mood) async {
    if (todayEntry != null && todayEntry!.mood == mood) {
      // Tapped already selected mood: unlog mood cleanly
      if (!todayEntry!.periodStarted &&
          todayEntry!.symptoms.isEmpty &&
          todayEntry!.energyLevel == null &&
          todayEntry!.flow == null &&
          todayEntry!.cramps == null &&
          todayEntry!.sleepQuality == null &&
          (todayEntry!.notes == null || todayEntry!.notes!.isEmpty)) {
        await ref.read(logEntriesProvider.notifier).deleteTodayEntry();
      } else {
        await ref.read(logEntriesProvider.notifier).addEntry(
              todayEntry!.copyWith(clearMood: true),
            );
      }
      return;
    }

    final entry = LogEntry(
      id: todayEntry?.id ?? const Uuid().v4(),
      date: DateTime.now(),
      mood: mood,
      energyLevel: todayEntry?.energyLevel, // NEVER default to 3
      flow: todayEntry?.flow,
      cramps: todayEntry?.cramps,
      sleepQuality: todayEntry?.sleepQuality,
      symptoms: todayEntry?.symptoms ?? [],
      notes: todayEntry?.notes,
      periodStarted: todayEntry?.periodStarted ?? false,
    );
    await ref.read(logEntriesProvider.notifier).addEntry(entry);
  }

  String _getBiologicalTakeaway({
    required bool hasCycle,
    required CyclePhase phase,
    MoodLevel? mood,
    int? energy,
  }) {
    if (!hasCycle) {
      if (energy != null && energy <= 2) {
        return 'Nervous system reset: taking things slow today lets your body restore natural vitality.';
      } else if (energy != null && energy >= 4) {
        return 'Natural momentum: channel your high vitality into creative focus and activities that inspire you.';
      }
      return 'Mindful check-in: tuning into your body is the first step toward understanding your natural rhythms.';
    }

    if (phase == CyclePhase.menstrual) {
      if (energy != null && energy <= 2) {
        return 'Systemic reset: lowest estrogen and progesterone naturally lower energy output. Resting today directly eases cramping.';
      }
      return 'Restorative renewal: your body is clearing the uterine lining and resetting its endocrine balance.';
    } else if (phase == CyclePhase.follicular) {
      return 'Estrogen ascendance: rising estradiol enhances cognitive clarity, focus, and natural energy.';
    } else if (phase == CyclePhase.ovulatory) {
      return 'Peak radiance: peak estrogen and testosterone support stamina, verbal confidence, and vitality.';
    } else {
      if (mood == MoodLevel.struggling || mood == MoodLevel.low) {
        return 'Nervous system sensitivity: shifting progesterone temporarily alters GABA activity. Your feelings are neurochemically valid.';
      }
      return 'Progesterone phase: digestion slows for steady nutrient absorption and body temperature stays gently elevated.';
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
          // Header row with status badge and unlog button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Check-in',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              if (hasLogged)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 11,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Logged',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () async {
                        await ref
                            .read(logEntriesProvider.notifier)
                            .deleteTodayEntry();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text("Today's check-in unlogged 🌸"),
                              backgroundColor: const Color(0xFF2A1F3D),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 11,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Awaiting check-in',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            hasLogged
                ? 'Tap your selected mood again to unlog, or switch anytime:'
                : 'How are you feeling today?',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),

          // 6 Mood Emoji Selector (ALWAYS visible and interactive, circular style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: MoodLevel.values.map((m) {
              final isSelected = hasLogged && todayEntry!.mood == m;
              return InkWell(
                onTap: () => _recordQuickMood(context, ref, m),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 48 : 44,
                  height: isSelected ? 48 : 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.28)
                        : colors.onSurface.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? colors.accent
                          : colors.onSurface.withValues(alpha: 0.08),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.24),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      m.emoji,
                      style: TextStyle(fontSize: isSelected ? 24 : 21),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (hasLogged) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  todayEntry!.mood?.label ?? 'Check-in Recorded',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.accent,
                  ),
                ),
                if (todayEntry!.energyLevel != null) ...[
                  Text(
                    '  ·  Energy: ${todayEntry!.energyLevel}/5',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
            if (todayEntry!.symptoms.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: todayEntry!.symptoms.map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.07)),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: colors.primary.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getBiologicalTakeaway(
                        hasCycle: cycleState != null && cycleState!.dayOfCycle > 0,
                        phase: currentPhase,
                        mood: todayEntry!.mood,
                        energy: todayEntry!.energyLevel,
                      ),
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: colors.onSurface.withValues(alpha: 0.75),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          InkWell(
            onTap: () => context.push('/log'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    hasLogged
                        ? 'Edit detailed check-in (energy, flow, symptoms) →'
                        : 'Log in detail (energy, flow, symptoms) →',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 60.ms, duration: 400.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. 7-DAY ENERGY RHYTHM MATRIX (HIDDEN IF NO ENERGY LOGGED THIS WEEK)
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

    // Check if any energy has actually been logged during this 7-day window
    final hasAnyEnergyLogged = weekDays.any((d) => logs.any((l) =>
        l.energyLevel != null &&
        l.date.year == d.year &&
        l.date.month == d.month &&
        l.date.day == d.day));

    // When no energy is logged for this week, cleanly hide the card
    if (!hasAnyEnergyLogged) {
      return const SizedBox.shrink();
    }

    const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

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
                'Energy This Week',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '1–5 Scale',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your logged daily vitality levels',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),

          // 7 Days Clean Energy Bar Chart
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final date = weekDays[i];
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                // Find log for this day
                LogEntry? matchingLog;
                for (final l in logs) {
                  if (l.date.year == date.year &&
                      l.date.month == date.month &&
                      l.date.day == date.day) {
                    matchingLog = l;
                    break;
                  }
                }

                final hasLog =
                    matchingLog != null && matchingLog.energyLevel != null;
                final energy = hasLog ? matchingLog.energyLevel! : 0;
                final barHeight = hasLog ? ((energy / 5.0) * 52.0 + 8.0) : 6.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Energy badge on top of bar
                        Text(
                          hasLog ? '$energy' : '-',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight:
                                hasLog ? FontWeight.w700 : FontWeight.w400,
                            color: hasLog
                                ? colors.accent
                                : colors.onSurface.withValues(alpha: 0.25),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // The Bar / Dot
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: hasLog
                                ? LinearGradient(
                                    colors: [
                                      colors.primary,
                                      colors.accent,
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  )
                                : null,
                            color: hasLog
                                ? null
                                : colors.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: hasLog && isToday
                                ? [
                                    BoxShadow(
                                      color:
                                          colors.accent.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Day label & date number
                        Text(
                          dayLabels[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday
                                ? colors.accent
                                : colors.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: GoogleFonts.dmSans(
                            fontSize: 9.5,
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
      if (l.mood != null) {
        moodCounts[l.mood!] = (moodCounts[l.mood!] ?? 0) + 1;
      }
    }

    final totalCount = moodCounts.values.fold(0, (sum, count) => sum + count);
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
    if (cycleState == null || cycleState!.dayOfCycle <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
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
                const Text('🔬', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  'Phase Intelligence',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Once your cycle begins and you log your period start date, Luna unlocks personalized hormonal metabolism, sleep science, and workout rhythm for every phase.',
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => context.push('/log'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Record cycle start date →',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
      final daySymptoms = LogEntry.canonicalizeSymptoms(l.symptoms);
      for (final s in daySymptoms) {
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
  final UserProfile? profile;

  const _PeriodHistorySection({
    required this.colors,
    required this.profile,
  });

  Future<void> _recordPeriodDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final profile = ref.read(profileProvider);
    final history = ref.read(periodHistoryProvider);
    final initial = profile?.lastPeriodStart ?? now;
    final safeInitial = initial.isAfter(now) ? now : initial;
    final firstDate = safeInitial.isBefore(now.subtract(const Duration(days: 730)))
        ? safeInitial
        : now.subtract(const Duration(days: 730));

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              onPrimary: Colors.white,
              surface: colors.surface,
              onSurface: colors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final normPicked = DateTime(picked.year, picked.month, picked.day);
      final nearby = history.where((p) {
        final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        return (pNorm.difference(normPicked).inDays.abs()) < 14;
      }).firstOrNull;

      if (nearby != null) {
        await ref.read(periodHistoryProvider.notifier).editPeriodEntry(nearby.id, picked);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Period date updated: ${picked.day} ${_monthName(picked.month)} 🌙',
                style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF2A1F3D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        await ref.read(periodHistoryProvider.notifier).addPeriodStart(picked, source: 'insights');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Period start logged: ${picked.day} ${_monthName(picked.month)} 🩸',
                style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF2A1F3D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _editExistingPeriodDate(BuildContext context, WidgetRef ref, PeriodEntry entry) async {
    final now = DateTime.now();
    final initial = entry.startDate.isAfter(now) ? now : entry.startDate;
    final firstDate = initial.isBefore(now.subtract(const Duration(days: 730)))
        ? initial
        : now.subtract(const Duration(days: 730));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              onPrimary: Colors.white,
              surface: colors.surface,
              onSurface: colors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final oldNorm = entry.startDate;
      if (oldNorm.year == picked.year && oldNorm.month == picked.month && oldNorm.day == picked.day) {
        return;
      }

      await ref.read(periodHistoryProvider.notifier).editPeriodEntry(entry.id, picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Period date updated: ${picked.day} ${_monthName(picked.month)} 🌙',
              style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
            ),
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
    // Read from the dedicated period_history table — the single source of truth
    final periodHistory = ref.watch(periodHistoryProvider);
    final sortedHistory = [...periodHistory]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final seenDays = <String>{};
    final deduplicatedHistory = sortedHistory
        .where((p) => seenDays.add('${p.startDate.year}-${p.startDate.month}-${p.startDate.day}'))
        .toList();

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
                    color: colors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+ Log Period',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (deduplicatedHistory.isNotEmpty) ...[
            ...deduplicatedHistory.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final d = p.startDate;
              // Compute gap to previous period if available
              String? gapText;
              if (i + 1 < deduplicatedHistory.length) {
                final prev = deduplicatedHistory[i + 1];
                final a = DateTime.utc(d.year, d.month, d.day);
                final b = DateTime.utc(prev.startDate.year, prev.startDate.month, prev.startDate.day);
                final gap = a.difference(b).inDays;
                if (gap >= 14 && gap <= 60) gapText = '$gap-day cycle';
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _editExistingPeriodDate(context, ref, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${d.day}',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
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
                                gapText ?? (i == 0 ? 'Latest period start · Tap to edit' : 'Period start · Tap to edit'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _editExistingPeriodDate(context, ref, p),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.onSurface.withValues(alpha: 0.05),
                                ),
                                child: Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 14,
                                  color: colors.accent.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    backgroundColor: colors.surface,
                                    title: Text('Remove period record?',
                                        style: GoogleFonts.cormorantGaramond(
                                            color: colors.onSurface,
                                            fontWeight: FontWeight.w700)),
                                    content: Text(
                                        'Remove ${_monthName(d.month)} ${d.day}, ${d.year} from period history? Your cycle calculations will update.',
                                        style: GoogleFonts.dmSans(
                                            color: colors.onSurface.withValues(alpha: 0.8),
                                            fontSize: 13)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dlgCtx, false),
                                        child: Text('Cancel',
                                            style: GoogleFonts.dmSans(
                                                color: colors.onSurface.withValues(alpha: 0.6))),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(dlgCtx, true),
                                        child: Text('Remove',
                                            style: GoogleFonts.dmSans(
                                                color: const Color(0xFFD94F6E),
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref.read(periodHistoryProvider.notifier).removePeriodEntry(p.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.onSurface.withValues(alpha: 0.05),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ] else ...[
            Text(
              'No period start date recorded yet. Tap "+ Log Period" above whenever your cycle begins.',
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

// ─────────────────────────────────────────────────────────────────────────────
// 7. DISCOVERED LONGITUDINAL PATTERNS (DEEP BIOMARKER INTELLIGENCE)
// ─────────────────────────────────────────────────────────────────────────────
class _DiscoveredPatternsCard extends StatelessWidget {
  final PhaseColors colors;
  final LongitudinalProfile patternProfile;

  const _DiscoveredPatternsCard({
    required this.colors,
    required this.patternProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hasPatterns = patternProfile.patterns.isNotEmpty;
    final totalLogs = patternProfile.totalLogsAnalyzed;
    final progress = (totalLogs / 7).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (hasPatterns ? colors.accent : colors.primary)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🧬', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pattern Intelligence',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      hasPatterns
                          ? 'Longitudinal biomarker discoveries'
                          : 'Personal pattern calibration',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasPatterns ? colors.accent : colors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (hasPatterns ? colors.accent : colors.primary)
                        .withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasPatterns ? colors.accent : colors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPatterns
                          ? '${patternProfile.patterns.length} Identified'
                          : '$totalLogs/7 Check-ins',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasPatterns ? colors.accent : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasPatterns) ...[
            // Calibration / Learning State (Calm, dignified, honest)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    totalLogs == 0
                        ? 'Luna tracks your mood, energy, and symptoms across cycle phases to identify your personal patterns with biological precision.'
                        : 'Luna needs at least 7 daily check-ins with symptoms or wellness data across different phases to detect your personal hormonal rhythm without guessing ($totalLogs of 7 logged with symptoms or mood).',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Progress Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            colors.onSurface.withValues(alpha: 0.08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$totalLogs of 7 wellness check-ins logged',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        totalLogs < 7
                            ? '${7 - totalLogs} more needed'
                            : 'Analyzing trends',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'Upcoming discoveries:',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _PatternPreviewBadge(
                          icon: '📉', label: 'Energy dips', colors: colors),
                      _PatternPreviewBadge(
                          icon: '⚡', label: 'Stamina peaks', colors: colors),
                      _PatternPreviewBadge(
                          icon: '💜', label: 'Mood shifts', colors: colors),
                      _PatternPreviewBadge(
                          icon: '🩸', label: 'Cramp patterns', colors: colors),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Active Discovered Patterns List with Progressive Disclosure
            Text(
              'Recurring hormonal tendencies identified from your logged cycle data. Tap any pattern for deep endocrine breakdown.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: patternProfile.patterns.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pattern = patternProfile.patterns[index];
                return _PatternTile(
                  key: ValueKey(pattern.id),
                  pattern: pattern,
                  colors: colors,
                );
              },
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _PatternPreviewBadge extends StatelessWidget {
  final String icon;
  final String label;
  final PhaseColors colors;

  const _PatternPreviewBadge({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternTile extends StatefulWidget {
  final DiscoveredPattern pattern;
  final PhaseColors colors;

  const _PatternTile({
    super.key,
    required this.pattern,
    required this.colors,
  });

  @override
  State<_PatternTile> createState() => _PatternTileState();
}

class _PatternTileState extends State<_PatternTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pattern = widget.pattern;
    final colors = widget.colors;
    final isConfirmed = pattern.confidence.contains('Confirmed') || pattern.confidence.contains('High');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isConfirmed ? colors.accent : colors.primary).withValues(alpha: _isExpanded ? 0.35 : 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Emoji, Title, Confidence Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surface.withValues(alpha: 0.8),
                ),
                child: Center(
                  child: Text(pattern.emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pattern.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isConfirmed ? colors.accent : colors.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pattern.confidence,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isConfirmed ? colors.accent : colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Brief Observation (Clean 1-liner accessible to all users)
          Text(
            pattern.description,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),

          // Footer Row: Cycle Days & Expandable Deep Science Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (pattern.cycleDays.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Days ${pattern.cycleDays.first}–${pattern.cycleDays.last}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),

              // Deep Science Toggle (Opt-in for those who want to dive deep!)
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Hide breakdown' : 'Hormonal breakdown',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Collapsible Deep Endocrine Breakdown
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🧬', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Endocrine Mechanism',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pattern.clinicalInsight,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.75),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
