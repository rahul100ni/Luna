import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/phase_orb.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100, right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [colors.primary.withValues(alpha: 0.13), Colors.transparent]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Know Your Body',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28, fontWeight: FontWeight.w700, color: colors.onSurface),
                      ),
                      Text(
                        'Everything you should have been taught.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Custom tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.zero,
                      dividerColor: Colors.transparent,
                      labelColor: colors.accent,
                      unselectedLabelColor: colors.onSurface.withValues(alpha: 0.4),
                      labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400),
                      tabs: const [
                        Tab(text: 'Your Phase'),
                        Tab(text: 'The Science'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _PhaseDeepDive(colors: colors),
                      _AllPhasesView(colors: colors),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Positioned(
            bottom: 0, left: 0, right: 0,
            child: LunaBottomNav(currentIndex: 3),
          ),
        ],
      ),
    );
  }
}

class _PhaseDeepDive extends ConsumerStatefulWidget {
  final PhaseColors colors;
  const _PhaseDeepDive({required this.colors});

  @override
  ConsumerState<_PhaseDeepDive> createState() => _PhaseDeepDiveState();
}

class _PhaseDeepDiveState extends ConsumerState<_PhaseDeepDive> {
  CyclePhase? _overridePhase;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final cycleState = ref.watch(cycleStateProvider);
    final hasPeriod = profile?.lastPeriodStart != null;

    final activePhase = (hasPeriod && cycleState != null)
        ? cycleState.phase
        : CyclePhase.ovulatory;

    final selectedPhase = _overridePhase ?? activePhase;
    final phaseInfo = PhaseConstants.getPhaseInfo(selectedPhase);
    final isLiveActivePhase = hasPeriod && cycleState != null && selectedPhase == cycleState.phase;

    final allPhases = [
      CyclePhase.menstrual,
      CyclePhase.follicular,
      CyclePhase.ovulatory,
      CyclePhase.earlyLuteal,
      CyclePhase.lateLuteal,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        // ── Phase Selector Chips ───────────────────────────────────────
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allPhases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final p = allPhases[index];
              final pInfo = PhaseConstants.getPhaseInfo(p);
              final isSelected = p == selectedPhase;
              final isCurrent = hasPeriod && cycleState != null && p == cycleState.phase;

              return GestureDetector(
                onTap: () => setState(() => _overridePhase = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? pInfo.colors.primary.withValues(alpha: 0.25)
                        : widget.colors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? pInfo.colors.accent.withValues(alpha: 0.8)
                          : widget.colors.onSurface.withValues(alpha: 0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pInfo.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        pInfo.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : widget.colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF80E8B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ── Balanced Luxury Phase Hero Card ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                phaseInfo.colors.surface,
                phaseInfo.colors.background,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: phaseInfo.colors.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: phaseInfo.colors.primary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Details on Left, Glowing Orb on Right!
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: phaseInfo.colors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: phaseInfo.colors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(phaseInfo.emoji, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Text(
                                isLiveActivePhase
                                    ? 'CURRENT PHASE · DAYS ${_getDayRange(phaseInfo.phase)}'
                                    : 'PHASE ${_getPhaseNumber(phaseInfo.phase)} · DAYS ${_getDayRange(phaseInfo.phase)}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: phaseInfo.colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          phaseInfo.name,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          phaseInfo.tagline,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  PhaseOrb(
                    phase: phaseInfo.phase,
                    dayNumber: isLiveActivePhase ? cycleState.dayOfCycle : 0,
                    size: 80,
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 14),

              // Vibe row
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: phaseInfo.colors.accent),
                  const SizedBox(width: 8),
                  Text(
                    phaseInfo.vibe,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: phaseInfo.colors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Mood chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: phaseInfo.moodWords.map((w) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: phaseInfo.colors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: phaseInfo.colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    w,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 16),

        // Science card
        _KnowledgeCard(
          icon: Icons.science_outlined,
          title: phaseInfo.scienceTitle,
          body: phaseInfo.scienceBody,
          color: phaseInfo.colors.accent,
          surface: widget.colors.surface,
          onSurface: widget.colors.onSurface,
        ).animate(delay: 80.ms).fadeIn(),

        const SizedBox(height: 12),

        _ListCard(
          title: 'What helps right now',
          items: phaseInfo.doThis,
          color: const Color(0xFF4CAF87),
          colors: widget.colors,
        ).animate(delay: 150.ms).fadeIn(),

        const SizedBox(height: 12),

        _ListCard(
          title: 'What makes it worse',
          items: phaseInfo.avoidThis,
          color: const Color(0xFFE07070),
          colors: widget.colors,
        ).animate(delay: 200.ms).fadeIn(),

        const SizedBox(height: 12),

        _ListCard(
          title: 'Nourish yourself',
          items: phaseInfo.eatThis,
          color: const Color(0xFFF2B43A),
          colors: widget.colors,
        ).animate(delay: 250.ms).fadeIn(),
      ],
    );
  }

  String _getPhaseNumber(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return '1 OF 5';
      case CyclePhase.follicular: return '2 OF 5';
      case CyclePhase.ovulatory: return '3 OF 5';
      case CyclePhase.earlyLuteal: return '4 OF 5';
      case CyclePhase.lateLuteal: return '5 OF 5';
    }
  }

  String _getDayRange(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return '1–5';
      case CyclePhase.follicular: return '6–13';
      case CyclePhase.ovulatory: return '14–16';
      case CyclePhase.earlyLuteal: return '17–22';
      case CyclePhase.lateLuteal: return '23–28';
    }
  }
}

class _AllPhasesView extends StatelessWidget {
  final PhaseColors colors;
  const _AllPhasesView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        Text(
          'The science, simplified',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        const SizedBox(height: 16),
        ...PhaseConstants.knowledgeCards.asMap().entries.map((entry) {
          final card = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExpandableKnowledgeCard(
              emoji: card['emoji']!,
              title: card['title']!,
              body: card['body']!,
              tag: card['tag']!,
              colors: colors,
            ).animate(delay: Duration(milliseconds: entry.key * 60)).fadeIn(),
          );
        }),
      ],
    );
  }
}

class _ExpandableKnowledgeCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String body;
  final String tag;
  final PhaseColors colors;

  const _ExpandableKnowledgeCard({
    required this.emoji, required this.title, required this.body,
    required this.tag, required this.colors,
  });

  @override
  State<_ExpandableKnowledgeCard> createState() => _ExpandableKnowledgeCardState();
}

class _ExpandableKnowledgeCardState extends State<_ExpandableKnowledgeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: widget.colors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _expanded ? widget.colors.primary.withValues(alpha: 0.2) : widget.colors.onSurface.withValues(alpha: 0.04),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w600, color: widget.colors.onSurface)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.tag,
                      style: GoogleFonts.dmSans(
                          fontSize: 10, color: widget.colors.accent, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Icon(
              _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: widget.colors.onSurface.withValues(alpha: 0.35),
              size: 20,
            ),
          ]),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: widget.colors.onSurface.withValues(alpha: 0.07)),
            const SizedBox(height: 14),
            Text(widget.body,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: widget.colors.onSurface.withValues(alpha: 0.78), height: 1.7)),
          ],
        ]),
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Color surface;
  final Color onSurface;

  const _KnowledgeCard({
    required this.icon, required this.title, required this.body,
    required this.color, required this.surface, required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text('THE SCIENCE',
              style: GoogleFonts.dmSans(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        Text(title,
            style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w700, color: onSurface)),
        const SizedBox(height: 10),
        Text(body,
            style: GoogleFonts.dmSans(fontSize: 13, color: onSurface.withValues(alpha: 0.78), height: 1.7)),
      ]),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final PhaseColors colors;

  const _ListCard({required this.title, required this.items, required this.color, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(item,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, color: colors.onSurface.withValues(alpha: 0.78), height: 1.5)),
                ),
              ]),
            )),
      ]),
    );
  }
}
