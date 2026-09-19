import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/cycle_engine.dart';
import '../../core/services/cycle_daily_intelligence.dart';
import '../../shared/widgets/bottom_nav.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final profile = ref.watch(profileProvider);
    final logEntries = ref.watch(logEntriesProvider);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final isViewingCurrentMonth =
        _focusedMonth.year == today.year && _focusedMonth.month == today.month;
    final isSelectedToday =
        _selectedDay.year == today.year && _selectedDay.month == today.month && _selectedDay.day == today.day;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Ambient luxury glow circles
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [colors.primary.withValues(alpha: 0.14), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [colors.accent.withValues(alpha: 0.08), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                children: [
                  // ── Header Row ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 20, 0),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cycle Rhythm',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              profile?.lastPeriodStart != null
                                  ? '${profile!.averageCycleLength}-day rhythm · Predictions synced'
                                  : 'Cycle Blueprint · Tap date to log',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                color: colors.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),

                        // Quick Jump to Today (if not on today)
                        if (!isSelectedToday || !isViewingCurrentMonth)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _focusedMonth = DateTime(today.year, today.month);
                                _selectedDay = today;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.today_rounded, size: 12, color: colors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Today',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Phase Guide Pill
                        _PhaseLegendButton(colors: colors),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Month Navigator Glass Capsule ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded,
                                color: colors.onSurface.withValues(alpha: 0.65), size: 22),
                            onPressed: () => setState(() => _focusedMonth =
                                DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  DateFormat('MMMM yyyy').format(_focusedMonth),
                                  key: ValueKey(_focusedMonth),
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right_rounded,
                                color: colors.onSurface.withValues(alpha: 0.65), size: 22),
                            onPressed: () => setState(() => _focusedMonth =
                                DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Weekday Headers ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((d) {
                        final isWeekend = d == 'SUN' || d == 'SAT';
                        return SizedBox(
                          width: 38,
                          child: Center(
                            child: Text(
                              d,
                              style: GoogleFonts.dmSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isWeekend
                                    ? colors.primary.withValues(alpha: 0.5)
                                    : colors.onSurface.withValues(alpha: 0.3),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Calendar Grid ─────────────────────────────────────────────
                  if (profile != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _CalendarGrid(
                        focusedMonth: _focusedMonth,
                        selectedDay: _selectedDay,
                        profile: profile,
                        colors: colors,
                        logEntries: logEntries,
                        onDayTap: (d) => setState(() => _selectedDay = d),
                      ),
                    )
                  else
                    const SizedBox(height: 240),

                  const SizedBox(height: 14),

                  // ── Selected Day Interactive Detail Card ──────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: profile != null
                        ? _SelectedDayCard(
                            selectedDay: _selectedDay,
                            profile: profile,
                            colors: colors,
                            logEntries: logEntries,
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // Floating bottom nav
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LunaBottomNav(currentIndex: 1),
          ),
        ],
      ),
    );
  }
}

// ── Phase Legend Button & Modal ────────────────────────────────────────────────
class _PhaseLegendButton extends StatelessWidget {
  final PhaseColors colors;
  const _PhaseLegendButton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLegend(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFD94F6E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF87),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFF2B43A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.help_outline_rounded,
                size: 13, color: colors.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegendSheet(colors: colors),
    );
  }
}

class _LegendSheet extends StatelessWidget {
  final PhaseColors colors;
  const _LegendSheet({required this.colors});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Color(0xFFD94F6E), '🩸', 'Menstrual Phase', 'Days 1–5 · Period flow & deep system reset'),
      (Color(0xFF4CAF87), '🌱', 'Follicular Phase', 'Days 6–13 · Rising estrogen & mental drive'),
      (Color(0xFFF2B43A), '✨', 'Ovulation Peak', 'Days 14–16 · Peak energy, confidence & fertile window'),
      (Color(0xFFE8A87C), '🍂', 'Early Luteal', 'Days 17–22 · Calming progesterone & focus'),
      (Color(0xFF9B84D4), '🌙', 'Late Luteal (PMS)', 'Days 23–28 · Amygdala sensitivity & gentle pacing'),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Phase Navigation Guide',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.onSurface.withValues(alpha: 0.4), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: item.$1, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Text(item.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$3,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            item.$4,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Calendar Grid ─────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final UserProfile profile;
  final PhaseColors colors;
  final List<LogEntry> logEntries;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.profile,
    required this.colors,
    required this.logEntries,
    required this.onDayTap,
  });

  Color _phaseColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return const Color(0xFFD94F6E);
      case CyclePhase.follicular:
        return const Color(0xFF4CAF87);
      case CyclePhase.ovulatory:
        return const Color(0xFFF2B43A);
      case CyclePhase.earlyLuteal:
        return const Color(0xFFE8A87C);
      case CyclePhase.lateLuteal:
        return const Color(0xFF9B84D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sun=0
    final today = DateTime.now();

    final cells = <Widget>[];

    // Leading empty padding
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    final hasAnchor = profile.lastPeriodStart != null;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isSelected =
          date.year == selectedDay.year && date.month == selectedDay.month && date.day == selectedDay.day;

      final phase = hasAnchor ? CycleEngine.phaseForDate(date, profile) : CyclePhase.follicular;
      final phaseColor = _phaseColor(phase);
      final isMenstrual = hasAnchor && phase == CyclePhase.menstrual;
      final isOvulation = hasAnchor && phase == CyclePhase.ovulatory;

      // Check if user logged on this date
      final hasLog = logEntries.any((e) =>
          e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);

      cells.add(
        GestureDetector(
          onTap: () => onDayTap(date),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Day number circle with optional luxury period band highlight
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colors.primary
                      : isMenstrual
                          ? const Color(0xFFD94F6E).withValues(alpha: 0.18)
                          : isToday
                              ? colors.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                  border: isSelected
                      ? null
                      : isToday
                          ? Border.all(color: colors.accent, width: 1.5)
                          : isOvulation
                              ? Border.all(
                                  color: const Color(0xFFF2B43A).withValues(alpha: 0.4),
                                  width: 1.2,
                                )
                              : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isMenstrual
                              ? const Color(0xFFFF8FA3)
                              : colors.onSurface.withValues(alpha: isToday ? 1.0 : 0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),

              // Bottom status dot (Phase dot or Log indicator)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasAnchor)
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: phaseColor.withValues(alpha: 0.85),
                      ),
                    ),
                  if (hasLog) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      children: cells,
    );
  }
}

// ── Selected Day Info Card ───────────────────────────────────────────────────
class _SelectedDayCard extends ConsumerWidget {
  final DateTime selectedDay;
  final UserProfile profile;
  final PhaseColors colors;
  final List<LogEntry> logEntries;

  const _SelectedDayCard({
    required this.selectedDay,
    required this.profile,
    required this.colors,
    required this.logEntries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnchor = profile.lastPeriodStart != null;
    final state = hasAnchor ? CycleEngine.calculateForDate(profile, selectedDay) : null;

    final isToday = selectedDay.year == DateTime.now().year &&
        selectedDay.month == DateTime.now().month &&
        selectedDay.day == DateTime.now().day;

    // Check if user logged on this selected date
    LogEntry? entry;
    for (final e in logEntries) {
      if (e.date.year == selectedDay.year &&
          e.date.month == selectedDay.month &&
          e.date.day == selectedDay.day) {
        entry = e;
        break;
      }
    }

    final phase = state?.phase ?? CyclePhase.follicular;
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);

    Color phaseAccent;
    switch (phase) {
      case CyclePhase.menstrual:
        phaseAccent = const Color(0xFFD94F6E);
        break;
      case CyclePhase.follicular:
        phaseAccent = const Color(0xFF4CAF87);
        break;
      case CyclePhase.ovulatory:
        phaseAccent = const Color(0xFFF2B43A);
        break;
      case CyclePhase.earlyLuteal:
        phaseAccent = const Color(0xFFE8A87C);
        break;
      case CyclePhase.lateLuteal:
        phaseAccent = const Color(0xFF9B84D4);
        break;
    }
    final dayNumber = state?.dayOfCycle ?? 0;
    final dayGuidance = CycleDailyIntelligence.getGuidance(dayNumber, phase);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: phaseAccent.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: Date + Phase pill
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(selectedDay),
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (isToday)
                    Text(
                      DateFormat('d MMMM yyyy').format(selectedDay),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: (hasAnchor ? phaseAccent : colors.accent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (hasAnchor ? phaseAccent : colors.accent).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hasAnchor ? phaseInfo.emoji : '✨', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      hasAnchor ? '${phaseInfo.name} · Day ${state!.dayOfCycle}' : 'Day View',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasAnchor ? phaseAccent : colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // If a log exists for this date, display it compactly
          if (entry != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Text(entry.mood?.emoji ?? '📝', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.mood?.label ?? 'Check-in recorded',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          [
                            if (entry.sleepQuality != null)
                              'Sleep ${entry.sleepQuality!.label}',
                            if (entry.symptoms.isNotEmpty)
                              entry.symptoms.take(2).join(', '),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            color: colors.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/log'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (!hasAnchor) ...[
            Text(
              'Daily Attunement',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No cycle anchor recorded yet. Mark your period start date or log daily wellness to unlock hormonal guidance.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              dayGuidance.dayHighlight,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayGuidance.biologicalContext,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // Unified sleek guidance container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✓',
                          style: TextStyle(
                              color: phaseAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dayGuidance.doThis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: colors.onSurface.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✗',
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dayGuidance.avoidThis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Action Buttons ──────────────────────────────────────────
          Consumer(builder: (ctx, ref, _) {
            final profile = ref.watch(profileProvider);
            final anchor = profile?.lastPeriodStart;
            final isSameDay = anchor != null &&
                anchor.year == selectedDay.year &&
                anchor.month == selectedDay.month &&
                anchor.day == selectedDay.day;

            final daysDiff = anchor != null
                ? selectedDay.calendarDaysDifference(anchor)
                : null;
            final periodLen = profile?.averagePeriodLength ?? 5;
            final isInPeriodDays = daysDiff != null && daysDiff > 0 && daysDiff < periodLen;

            if (isSameDay) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          'Period start date for this cycle ✓',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLogDayButton(context, colors, entry),
                ],
              );
            }

            if (isInPeriodDays) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          'Period · Day ${daysDiff + 1} of cycle',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLogDayButton(context, colors, entry),
                ],
              );
            }

            // Balanced side-by-side action buttons
            return Row(
              children: [
                Expanded(
                  child: _buildLogDayButton(context, colors, entry),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await ref
                          .read(profileProvider.notifier)
                          .updateLastPeriod(selectedDay);
                      final toSave = entry != null
                          ? entry.copyWith(periodStarted: true)
                          : LogEntry(
                              id: const Uuid().v4(),
                              date: selectedDay,
                              mood: null,
                              energyLevel: null,
                              symptoms: [],
                              periodStarted: true,
                            );
                      await ref.read(logEntriesProvider.notifier).addEntry(toSave);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🩸', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            'Period Start',
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
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogDayButton(BuildContext context, PhaseColors colors, LogEntry? entry) {
    return GestureDetector(
      onTap: () => context.push('/log'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_calendar_rounded, size: 14, color: colors.accent),
            const SizedBox(width: 6),
            Text(
              entry == null ? 'Log Day' : 'View Log',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

