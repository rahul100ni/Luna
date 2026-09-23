import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/models/log_entry.dart';
import '../../core/models/period_entry.dart';
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

class _CalendarScreenState extends ConsumerState<CalendarScreen> with WidgetsBindingObserver {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final profile = ref.watch(profileProvider);
    final logEntries = ref.watch(logEntriesProvider);
    final periodHistory = ref.watch(periodHistoryProvider);
    final isCycleLengthUnknown = ref.watch(isCycleLengthUnknownProvider);
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
                        _PhaseLegendButton(colors: colors, profile: profile),
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
                        periodHistory: periodHistory,
                        isCycleLengthUnknown: isCycleLengthUnknown,
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
                            periodHistory: periodHistory,
                            isCycleLengthUnknown: isCycleLengthUnknown,
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
  final UserProfile? profile;
  const _PhaseLegendButton({required this.colors, this.profile});

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
      builder: (_) => _LegendSheet(colors: colors, profile: profile),
    );
  }
}

class _LegendSheet extends StatelessWidget {
  final PhaseColors colors;
  final UserProfile? profile;
  const _LegendSheet({required this.colors, this.profile});

  @override
  Widget build(BuildContext context) {
    final periodLen = profile?.averagePeriodLength ?? 5;
    final folStart = periodLen + 1;
    final folEnd = 13.clamp(folStart, 16);
    final items = [
      (const Color(0xFFD94F6E), '🩸', 'Menstrual Phase', 'Days 1–$periodLen · Period flow & deep system reset'),
      (const Color(0xFF4CAF87), '🌱', 'Follicular Phase', 'Days $folStart–$folEnd · Rising estrogen & mental drive'),
      (const Color(0xFFF2B43A), '✨', 'Ovulation Peak', 'Days 14–16 · Peak energy, confidence & fertile window'),
      (const Color(0xFFE8A87C), '🍂', 'Early Luteal', 'Days 17–22 · Calming progesterone & focus'),
      (const Color(0xFF9B84D4), '🌙', 'Late Luteal (PMS)', 'Days 23–28 · Amygdala sensitivity & gentle pacing'),
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
  final List<PeriodEntry> periodHistory;
  final bool isCycleLengthUnknown;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.profile,
    required this.colors,
    required this.logEntries,
    required this.periodHistory,
    required this.isCycleLengthUnknown,
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

      final isConfirmedStart = hasAnchor && CycleEngine.isConfirmedPeriodStart(date, periodHistory);
      final phase = hasAnchor
          ? CycleEngine.phaseForDate(
              date,
              profile,
              periodHistory: periodHistory,
              isCycleLengthUnknown: isCycleLengthUnknown,
            )
          : null;
      final phaseColor = phase != null ? _phaseColor(phase) : colors.accent.withValues(alpha: 0.3);
      final dayLog = logEntries.where((e) =>
          e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).firstOrNull;
      final hasLoggedFlow = dayLog != null && (dayLog.flow != null || dayLog.periodStarted);
      final isMenstrual = hasAnchor && (phase == CyclePhase.menstrual || isConfirmedStart || hasLoggedFlow);
      final isOvulation = hasAnchor && phase == CyclePhase.ovulatory && !isConfirmedStart && !hasLoggedFlow;

      // Check if user logged on this date
      final hasLog = dayLog != null;

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
                      : isConfirmedStart
                          ? const Color(0xFFD94F6E)
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
                      : isConfirmedStart
                          ? [
                              BoxShadow(
                                color: const Color(0xFFD94F6E).withValues(alpha: 0.35),
                                blurRadius: 6,
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
                      fontWeight: isSelected || isToday || isConfirmedStart ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected || isConfirmedStart
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
                  if (hasAnchor && phase != null)
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConfirmedStart
                            ? const Color(0xFFD94F6E)
                            : phaseColor.withValues(alpha: 0.85),
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
  final List<PeriodEntry> periodHistory;
  final bool isCycleLengthUnknown;

  const _SelectedDayCard({
    required this.selectedDay,
    required this.profile,
    required this.colors,
    required this.logEntries,
    required this.periodHistory,
    required this.isCycleLengthUnknown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnchor = profile.lastPeriodStart != null;
    final state = hasAnchor
        ? CycleEngine.calculateForDate(
            profile,
            selectedDay,
            periodHistory: periodHistory,
            isCycleLengthUnknown: isCycleLengthUnknown,
          )
        : null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final isToday = target.isAtSameMomentAs(today);
    final isPast = target.isBefore(today);
    final isFuture = target.isAfter(today);
    final daysFromToday = target.difference(today).inDays;

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

    final phase = state?.phase;
    final phaseInfo = phase != null ? PhaseConstants.getPhaseInfo(phase) : null;

    Color phaseAccent;
    if (phase != null) {
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
    } else {
      phaseAccent = colors.accent;
    }
    final dayNumber = state?.dayOfCycle ?? 0;
    final dayGuidance = phase != null ? CycleDailyIntelligence.getGuidance(dayNumber, phase) : null;

    final isConfirmedStart = CycleEngine.isConfirmedPeriodStart(selectedDay, periodHistory);
    final closestAnchor = CycleEngine.findCycleStart(selectedDay, profile, periodHistory);
    final daysDiff = closestAnchor != null
        ? selectedDay.calendarDaysDifference(closestAnchor)
        : null;
    final periodLen = profile.averagePeriodLength;
    final isInPeriodDays = (daysDiff != null && daysDiff >= 0 && daysDiff < periodLen) ||
        (entry != null && (entry.flow != null || entry.periodStarted));
    final canStartNewPeriodToday = !isConfirmedStart &&
        (closestAnchor == null || daysDiff == null || daysDiff < 0 || daysDiff >= 14);
    final canMarkPastStart = !isConfirmedStart &&
        (closestAnchor == null || daysDiff == null || daysDiff <= 0 || daysDiff >= 14);
    final isExtendedCycleDay = !isFuture &&
        daysDiff != null &&
        (daysDiff + 1) > profile.averageCycleLength &&
        !isConfirmedStart;
    final isEarlyStartCandidate = daysDiff != null &&
        daysDiff >= 14 &&
        (daysDiff + 1) < (profile.averageCycleLength - 2);
    final canRecordOngoingBleed = daysDiff != null &&
        daysDiff >= 1 &&
        daysDiff <= 9 &&
        !isConfirmedStart &&
        (entry == null || entry.flow == null);

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
          // ── Row 1: Date + Phase pill (Overflow-immune) ───────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(selectedDay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      isToday
                          ? DateFormat('d MMMM yyyy').format(selectedDay)
                          : isFuture
                              ? (daysFromToday == 1 ? 'Tomorrow' : 'In $daysFromToday days')
                              : (daysFromToday == -1 ? 'Yesterday' : '${-daysFromToday} days ago'),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: (hasAnchor && phase != null ? phaseAccent : colors.accent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (hasAnchor && phase != null ? phaseAccent : colors.accent).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(phaseInfo != null ? phaseInfo.emoji : '✨', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      phaseInfo != null
                          ? (isFuture
                              ? 'Est. ${phaseInfo.name}'
                              : isExtendedCycleDay
                                  ? 'Extended · Day ${daysDiff + 1}'
                                  : '${phaseInfo.name} · Day ${state?.dayOfCycle ?? 0}')
                          : (hasAnchor ? 'Unrecorded Cycle' : 'Day View'),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasAnchor && phase != null ? phaseAccent : colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Confirmed Period Start Anchor Badge ─────────────────────────
          if (isConfirmedStart) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFD94F6E).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🩸', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Period start date',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showRemovePeriodDialog(context, colors, ref, selectedDay, periodHistory),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFFD94F6E),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else if (isInPeriodDays && !isFuture) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD94F6E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  const Text('🩸', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    daysDiff != null
                        ? (daysDiff >= 5
                            ? 'Extended bleed · Day ${daysDiff + 1}'
                            : 'Menstrual bleed · Day ${daysDiff + 1}')
                        : 'Menstrual flow recorded',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  if (daysDiff != null && daysDiff >= 1 && daysDiff <= 9) ...[
                    const Spacer(),
                    InkWell(
                      onTap: () => _showPeriodEndedDialog(context, colors, ref, selectedDay, daysDiff + 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                            const SizedBox(width: 3),
                            Text(
                              'Ended on this day',
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                color: colors.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Logged State Summary (Personal Biomarker Memory) ────────────
          if (entry != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.mood?.emoji ?? '📝', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        entry.mood?.label ?? 'Check-in recorded',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/log', extra: selectedDay),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, size: 10, color: colors.accent),
                              const SizedBox(width: 3),
                              Text(
                                'Edit',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (entry.flow != null)
                        _buildBiomarkerBadge(
                          '🩸 ${entry.flow!.name[0].toUpperCase()}${entry.flow!.name.substring(1)} flow',
                          colors.primary.withValues(alpha: 0.18),
                          colors.accent,
                        ),
                      if (entry.cramps != null && entry.cramps != CrampLevel.none)
                        _buildBiomarkerBadge(
                          '⚡ ${entry.cramps!.name[0].toUpperCase()}${entry.cramps!.name.substring(1)} cramps',
                          colors.primary.withValues(alpha: 0.14),
                          colors.onSurface.withValues(alpha: 0.85),
                        ),
                      if (entry.energyLevel != null)
                        _buildBiomarkerBadge(
                          '⚡ ${entry.energyLevel}/5 energy',
                          colors.onSurface.withValues(alpha: 0.08),
                          colors.onSurface.withValues(alpha: 0.8),
                        ),
                      if (entry.sleepQuality != null)
                        _buildBiomarkerBadge(
                          '😴 Sleep: ${entry.sleepQuality!.label}',
                          colors.onSurface.withValues(alpha: 0.08),
                          colors.onSurface.withValues(alpha: 0.8),
                        ),
                      for (final s in entry.symptoms)
                        _buildBiomarkerBadge(
                          s,
                          colors.onSurface.withValues(alpha: 0.06),
                          colors.onSurface.withValues(alpha: 0.75),
                        ),
                    ],
                  ),
                  if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${entry.notes!.trim()}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Biological Attunement / Foresight ───────────────────────────
          if (!hasAnchor || state == null || dayGuidance == null) ...[
            Text(
              'Cycle Blueprint',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hasAnchor
                  ? 'This date is before your earliest recorded cycle. Record a log or period start to track this date.'
                  : 'No cycle anchor recorded yet. Mark your period start date to unlock hormonal guidance and accurate rhythm predictions.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isFuture && isCycleLengthUnknown) ...[
            Text(
              'Upcoming Rhythm',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Future phase predictions will activate once your personal cycle baseline is calibrated from your logged periods.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              isFuture ? 'Predicted ${phaseInfo!.name} Window' : dayGuidance.dayHighlight,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              dayGuidance.biologicalContext,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.55),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),

            // Classy dual insight cards (No childish ✓ or ✗)
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
                      Padding(
                        padding: const EdgeInsets.only(top: 1.5),
                        child: Text(
                          '✦',
                          style: TextStyle(
                            color: phaseAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BEST ALIGNED',
                              style: GoogleFonts.dmSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: phaseAccent,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayGuidance.doThis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                color: colors.onSurface.withValues(alpha: 0.85),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      color: colors.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1.5),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: colors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MINDFUL CARE',
                              style: GoogleFonts.dmSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dayGuidance.avoidThis,
                              style: GoogleFonts.dmSans(
                                fontSize: 11.5,
                                color: colors.onSurface.withValues(alpha: 0.7),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Subtle extended cycle reassurance (Not in the face, but comforting)
          if (isExtendedCycleDay && !isInPeriodDays) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extended cycle: Stress, travel, or sleep changes often delay ovulation. Your cycle will recalibrate once your period arrives.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Contextual Action Buttons ───────────────────────────────────
          // On FUTURE dates: Zero buttons! Foresight information only.
          if (!isFuture) ...[
            if (isToday) ...[
              if (entry == null)
                GestureDetector(
                  onTap: () => context.push('/log', extra: selectedDay),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_calendar_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Check In for Today',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canRecordOngoingBleed)
                GestureDetector(
                  onTap: () async {
                    final entryId = entry?.id ?? 'log_${selectedDay.year}_${selectedDay.month}_${selectedDay.day}';
                    final updated = (entry ?? LogEntry(id: entryId, date: selectedDay, symptoms: const [])).copyWith(
                      flow: FlowLevel.medium,
                    );
                    await ref.read(logEntriesProvider.notifier).addEntry(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Bleeding flow recorded for Day ${daysDiff + 1} 🩸',
                            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: const Color(0xFF2A1F3D),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Still bleeding today · Day ${daysDiff + 1}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF8FA3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (canStartNewPeriodToday)
                GestureDetector(
                  onTap: () async {
                    await ref.read(periodHistoryProvider.notifier).addPeriodStart(selectedDay, source: 'calendar');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Period start recorded for today 🩸',
                            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: const Color(0xFF2A1F3D),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: entry == null ? 8 : 0),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          isEarlyStartCandidate
                              ? 'Period started early today · Day ${daysDiff + 1}'
                              : isExtendedCycleDay
                                  ? 'Period arrived today · Day ${daysDiff + 1}'
                                  : 'My period started today',
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
            ] else if (isPast) ...[
              // Past day actions
              if (entry == null && !isConfirmedStart)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/log', extra: selectedDay),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_calendar_rounded, size: 13, color: colors.accent),
                              const SizedBox(width: 5),
                              Text(
                                isInPeriodDays ? 'Record Day Flow' : 'Record Past Log',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (canRecordOngoingBleed) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final entryId = entry?.id ?? 'log_${selectedDay.year}_${selectedDay.month}_${selectedDay.day}';
                            final updated = (entry ?? LogEntry(id: entryId, date: selectedDay, symptoms: const [])).copyWith(
                              flow: FlowLevel.medium,
                            );
                            await ref.read(logEntriesProvider.notifier).addEntry(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Bleeding recorded for Day ${daysDiff + 1} 🩸',
                                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: const Color(0xFF2A1F3D),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🩸', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 5),
                                Text(
                                  'Still bleeding · Day ${daysDiff + 1}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF8FA3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (canMarkPastStart) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await ref.read(periodHistoryProvider.notifier).addPeriodStart(selectedDay, source: 'calendar');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Period start recorded: ${DateFormat('MMMM d').format(selectedDay)} 🩸',
                                    style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  backgroundColor: const Color(0xFF2A1F3D),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD94F6E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🩸', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 5),
                                Text(
                                  isEarlyStartCandidate
                                      ? 'Started early · Day ${daysDiff + 1}'
                                      : isExtendedCycleDay
                                          ? 'Started · Day ${daysDiff + 1}'
                                          : 'Period Start',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
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
                  ],
                )
              else if (!isConfirmedStart && !isInPeriodDays)
                GestureDetector(
                  onTap: () async {
                    await ref.read(periodHistoryProvider.notifier).addPeriodStart(selectedDay, source: 'calendar');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Period start recorded: ${DateFormat('MMMM d').format(selectedDay)} 🩸',
                            style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: const Color(0xFF2A1F3D),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F6E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD94F6E).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 5),
                        Text(
                          isEarlyStartCandidate
                              ? 'Period started early on this date · Day ${daysDiff + 1}'
                              : isExtendedCycleDay
                                  ? 'Period arrived on this date · Day ${daysDiff + 1}'
                                  : 'Mark as Period Start',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBiomarkerBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _showRemovePeriodDialog(
    BuildContext context,
    PhaseColors colors,
    WidgetRef ref,
    DateTime selectedDay,
    List<PeriodEntry> periodHistory,
  ) async {
    final match = periodHistory.where((p) =>
        p.startDate.year == selectedDay.year &&
        p.startDate.month == selectedDay.month &&
        p.startDate.day == selectedDay.day).firstOrNull;
    if (match != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Remove period start?',
            style: GoogleFonts.cormorantGaramond(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Remove period start record for ${DateFormat('MMMM d').format(selectedDay)}? Your cycle calculations will update.',
            style: GoogleFonts.dmSans(
              color: colors.onSurface.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: Text(
                'Remove',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFD94F6E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await ref.read(periodHistoryProvider.notifier).removePeriodEntry(match.id);
      }
    }
  }

  Future<void> _showPeriodEndedDialog(
    BuildContext context,
    PhaseColors colors,
    WidgetRef ref,
    DateTime selectedDay,
    int dayNumber,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Bleeding ended on Day $dayNumber',
          style: GoogleFonts.cormorantGaramond(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Shorter bleeds (2 to 3 days) can happen due to lighter shedding, stress, or mild hormonal variation. Luna records that bleeding ended on this day for this cycle while preserving your baseline rhythm.',
          style: GoogleFonts.dmSans(
            color: colors.onSurface.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: colors.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(
              'Confirm End',
              style: GoogleFonts.dmSans(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final allEntries = ref.read(logEntriesProvider);
      final normSelected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      for (final e in allEntries) {
        final eNorm = DateTime(e.date.year, e.date.month, e.date.day);
        if (eNorm.isAfter(normSelected) && eNorm.difference(normSelected).inDays < 14) {
          if (e.flow != null || e.periodStarted) {
            final updated = e.copyWith(flow: null, periodStarted: false);
            await ref.read(logEntriesProvider.notifier).addEntry(updated);
          }
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bleeding ended on Day $dayNumber recorded 🌸',
              style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: const Color(0xFF2A1F3D),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

