import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/phase_orb.dart';
import 'widgets/daily_prescription_card.dart';
import '../nutrition/cycle_nutrition_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final colors = ref.watch(phaseColorsProvider);
    final isComfort = ref.watch(isComfortModeProvider);

    if (profile == null || cycleState == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF120D1A),
          body: Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF9B84D4))));
    }

    final bool dataIsAssumed = profile.lastPeriodStart == null || cycleState.dayOfCycle <= 0;
    final phaseInfo = cycleState.phaseInfo;
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Background ambient blobs ─────────────────────────────────────
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.primary.withValues(alpha: 0.14),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -120,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  colors.secondary.withValues(alpha: 0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Main scroll ──────────────────────────────────────────────────
          CustomScrollView(
            slivers: [
              // Top actions row
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting ✨',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: colors.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                profile.name.replaceAll(r'\', '').trim(),
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.settings_outlined,
                              color: colors.onSurface.withValues(alpha: 0.4),
                              size: 22),
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Hero Phase Card ──────────────────────────────────────
                    if (dataIsAssumed)
                      _NoCycleHeroCard(colors: colors, userName: profile.name)
                          .animate().fadeIn(duration: 500.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic)
                    else
                      _HeroPhaseCard(
                        cycleState: cycleState,
                        colors: colors,
                        isComfort: isComfort,
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),

                    const SizedBox(height: 16),

                    // ── Comfort Banner ───────────────────────────────────────
                    if (isComfort && !dataIsAssumed) ...[
                      _ComfortBanner(colors: colors)
                          .animate().fadeIn(delay: 100.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Quick Actions ────────────────────────────────────────
                    _QuickActionsRow(colors: colors)
                        .animate().fadeIn(delay: 150.ms, duration: 400.ms),

                    const SizedBox(height: 18),

                    if (!dataIsAssumed) ...[
                      // ── What's Happening in Your Body ─────────────────────
                      _ScienceTeaser(phaseInfo: phaseInfo, colors: colors)
                          .animate().fadeIn(delay: 180.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                      // ── Today's Playbook ───────────────────────────────────
                      _TodayPlaybook(phaseInfo: phaseInfo, colors: colors)
                          .animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: 18),
                    ],

                    // ── What Should I Eat Today (Food & Craving Sync) ────────
                    _NutritionSyncBanner(colors: colors)
                        .animate().fadeIn(delay: 220.ms, duration: 400.ms),

                    const SizedBox(height: 16),

                    // ── Dynamic Daily Prescription (AI Dispatch) ─────────────
                    DailyPrescriptionCard(colors: colors)
                        .animate().fadeIn(delay: 250.ms, duration: 400.ms),

                  ]),
                ),
              ),
            ],
          ),

          // ── Floating bottom nav ──────────────────────────────────────────
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LunaBottomNav(currentIndex: 0),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── No Cycle Hero Card ───────────────────────────────────────────────────────
class _NoCycleHeroCard extends StatelessWidget {
  final PhaseColors colors;
  final String userName;
  const _NoCycleHeroCard({required this.colors, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.surface.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.35),
                      colors.surface,
                    ],
                  ),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 34)),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 5),
                          Text(
                            'LUNA READY',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No cycle logged yet',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Waiting for your period to start',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: colors.onSurface.withValues(alpha: 0.07)),
          const SizedBox(height: 16),
          Text(
            'Luna learns with you',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Once you log Day 1, Luna maps your exact hormonal phases, daily body science, and symptom forecasts.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/log'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🩸', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Log when period starts',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}

// ── Hero Phase Card ──────────────────────────────────────────────────────────
class _HeroPhaseCard extends StatelessWidget {
  final CycleState cycleState;
  final PhaseColors colors;
  final bool isComfort;
  const _HeroPhaseCard({
    required this.cycleState,
    required this.colors,
    required this.isComfort,
  });

  @override
  Widget build(BuildContext context) {
    final phaseInfo = cycleState.phaseInfo;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.surface.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: orb + day info + settings shortcut
          Row(
            children: [
              PhaseOrb(
                phase: cycleState.phase,
                dayNumber: cycleState.dayOfCycle,
                size: 80,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phase chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(phaseInfo.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            phaseInfo.name.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.accent,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Day ${cycleState.dayOfCycle}',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cycleState.daysUntilNextPeriod > 0
                          ? '${cycleState.daysUntilNextPeriod} days until next period'
                          : cycleState.daysUntilNextPeriod == 0
                              ? 'Period expected today'
                              : 'Period ${-cycleState.daysUntilNextPeriod}d late',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
                  ),
                  child: Icon(
                    Icons.edit_calendar_outlined,
                    size: 16,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Divider line
          Container(height: 1, color: colors.onSurface.withValues(alpha: 0.07)),

          const SizedBox(height: 16),

          // Tagline + vibe
          Text(
            phaseInfo.tagline,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),

          // Mood words as flowing chips
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: phaseInfo.moodWords.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                w,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: colors.accent.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 14),

          // Greeting prefix text
          Text(
            phaseInfo.greetingPrefix,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comfort Banner ───────────────────────────────────────────────────────────
class _ComfortBanner extends StatelessWidget {
  final PhaseColors colors;
  const _ComfortBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/comfort'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary.withValues(alpha: 0.28), colors.secondary.withValues(alpha: 0.15)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('🎰', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feeling rough today?',
                    style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                  Text(
                    'Spin for something that helps 💜',
                    style: GoogleFonts.dmSans(
                      fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smart Nutrition Sync Banner ──────────────────────────────────────────────
class _NutritionSyncBanner extends StatelessWidget {
  final PhaseColors colors;
  const _NutritionSyncBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => CycleNutritionSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF2B43A).withValues(alpha: 0.18),
              colors.surface.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFF2B43A).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2B43A).withValues(alpha: 0.18),
                border: Border.all(
                  color: const Color(0xFFF2B43A).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'What should I eat today?',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2B43A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AI SYNC',
                          style: GoogleFonts.dmSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF2B43A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pick your diet & craving, see what to eat & avoid',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────
class _QuickActionsRow extends ConsumerWidget {
  final PhaseColors colors;
  const _QuickActionsRow({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayLog = ref.watch(todayLogProvider);
    final isLogged = todayLog != null;

    final actions = [
      _ActionItem(
        icon: Icons.auto_awesome_rounded,
        label: 'Talk to Luna',
        sublabel: 'AI Companion',
        accentColor: colors.accent,
        isPrimary: true,
        onTap: () => context.push('/luna'),
      ),
      _ActionItem(
        icon: isLogged ? Icons.check_circle_rounded : Icons.edit_note_rounded,
        label: isLogged ? 'Logged' : 'Log Today',
        sublabel: isLogged ? 'Check-in done' : 'Daily check-in',
        accentColor: isLogged ? const Color(0xFF4CAF87) : colors.primary,
        isPrimary: false,
        onTap: () => context.push('/log'),
      ),
      _ActionItem(
        icon: Icons.menu_book_rounded,
        label: 'Explore',
        sublabel: 'Science library',
        accentColor: const Color(0xFFF2B43A),
        isPrimary: false,
        onTap: () => context.push('/knowledge'),
      ),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: a.onTap,
            child: Container(
              height: 104,
              margin: EdgeInsets.only(
                right: actions.last == a ? 0 : 10,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: a.isPrimary
                    ? colors.primary.withValues(alpha: 0.18)
                    : colors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: a.isPrimary
                      ? colors.primary.withValues(alpha: 0.35)
                      : colors.onSurface.withValues(alpha: 0.06),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: a.accentColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: a.accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(a.icon, size: 17, color: a.accentColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accentColor;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accentColor,
    this.isPrimary = false,
    required this.onTap,
  });
}

// ── Science Teaser ───────────────────────────────────────────────────────────
class _ScienceTeaser extends StatelessWidget {
  final PhaseInfo phaseInfo;
  final PhaseColors colors;
  const _ScienceTeaser({required this.phaseInfo, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/knowledge'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.accent.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, size: 14, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  'WHAT\'S HAPPENING IN YOUR BODY',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: colors.accent,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: colors.onSurface.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              phaseInfo.scienceTitle,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              phaseInfo.scienceBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Read the science →',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.accent.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's Playbook ─────────────────────────────────────────────────────────
class _TodayPlaybook extends StatefulWidget {
  final PhaseInfo phaseInfo;
  final PhaseColors colors;
  const _TodayPlaybook({required this.phaseInfo, required this.colors});

  @override
  State<_TodayPlaybook> createState() => _TodayPlaybookState();
}

class _TodayPlaybookState extends State<_TodayPlaybook> {
  int _tab = 0; // 0=Do, 1=Skip, 2=Eat

  static const _tabs = ['Do', 'Skip', 'Eat'];
  static const _tabEmojis = ['✅', '🚫', '🍽️'];
  static const _tabAccents = [
    Color(0xFF4CAF87),
    Color(0xFFE07070),
    Color(0xFFF2B43A),
  ];

  List<String> get _items {
    switch (_tab) {
      case 0:
        return widget.phaseInfo.doThis;
      case 1:
        return widget.phaseInfo.avoidThis;
      case 2:
        return widget.phaseInfo.eatThis;
      default:
        return [];
    }
  }

  // Strip verbose explanation after ': ', ' (', or ' - ' to keep it scannable
  String _shortItem(String item) {
    final colonIdx = item.indexOf(': ');
    if (colonIdx > 4) return item.substring(0, colonIdx);
    final parenIdx = item.indexOf(' (');
    if (parenIdx > 4) return item.substring(0, parenIdx);
    final dashIdx = item.indexOf(' - ');
    if (dashIdx > 0) return item.substring(0, dashIdx);
    return item;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _tabAccents[_tab];
    final phaseInfo = widget.phaseInfo;
    final colors = widget.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + phase label
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S PLAYBOOK',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phaseInfo.name,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${phaseInfo.emoji} Day ${_getDayHint(phaseInfo)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: List.generate(3, (i) {
                final sel = _tab == i;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? _tabAccents[i].withValues(alpha: 0.2)
                          : colors.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _tabAccents[i].withValues(alpha: 0.5) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_tabEmojis[i], style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          _tabs[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _tabAccents[i] : colors.onSurface.withValues(alpha: 0.5),
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

          // Items list: quick skim style
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              key: ValueKey(_tab),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._items.map((item) {
                    final short = _shortItem(item);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              short,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.78),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_tab == 2) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => CycleNutritionSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2B43A).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF2B43A).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text('🍽️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Craving something else? Ask Luna →',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF2B43A),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: const Color(0xFFF2B43A).withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayHint(PhaseInfo info) {
    switch (info.phase) {
      case CyclePhase.menstrual: return '1–5';
      case CyclePhase.follicular: return '6–13';
      case CyclePhase.ovulatory: return '14–16';
      case CyclePhase.earlyLuteal: return '17–22';
      case CyclePhase.lateLuteal: return '23–28';
    }
  }
}


