import "../constants/phase_constants.dart";
import "../models/user_profile.dart";
import "../models/period_entry.dart";

extension CalendarDays on DateTime {
  int calendarDaysDifference(DateTime other) {
    final a = DateTime.utc(year, month, day);
    final b = DateTime.utc(other.year, other.month, other.day);
    return a.difference(b).inDays;
  }
}

class CycleState {
  final int dayOfCycle;
  final CyclePhase phase;
  final PhaseInfo phaseInfo;
  final DateTime? nextPeriodDate;
  final int daysUntilNextPeriod;
  final int daysUntilPhaseChange;
  final bool isPeriodOverdue;
  final bool isPeriodSoon;
  final bool isAnchored;

  const CycleState({
    required this.dayOfCycle,
    required this.phase,
    required this.phaseInfo,
    this.nextPeriodDate,
    required this.daysUntilNextPeriod,
    required this.daysUntilPhaseChange,
    this.isPeriodOverdue = false,
    this.isPeriodSoon = false,
    this.isAnchored = true,
  });
}

enum CycleRegularity {
  normal,
  delayed,
  early,
  overdue,
  unknown,
}

class CycleGapAnalysis {
  final int? lastCycleGap;
  final int? deviationFromBaseline;
  final int currentDaysOverdue;
  final CycleRegularity regularity;
  final String biologicalSummary;
  final String clinicalGuidanceDirective;

  const CycleGapAnalysis({
    this.lastCycleGap,
    this.deviationFromBaseline,
    this.currentDaysOverdue = 0,
    required this.regularity,
    required this.biologicalSummary,
    required this.clinicalGuidanceDirective,
  });

  bool get hasAbnormality =>
      regularity == CycleRegularity.delayed ||
      regularity == CycleRegularity.early ||
      regularity == CycleRegularity.overdue;

  static const unknown = CycleGapAnalysis(
    regularity: CycleRegularity.unknown,
    biologicalSummary: 'Baseline rhythm calibrating.',
    clinicalGuidanceDirective: '',
  );
}

class CycleContext {
  final PeriodEntry? entry;
  final DateTime cycleStart;
  final DateTime? nextCycleStart;
  final bool isClosed;
  final int cycleLength;
  final int periodLength;

  const CycleContext({
    this.entry,
    required this.cycleStart,
    this.nextCycleStart,
    required this.isClosed,
    required this.cycleLength,
    required this.periodLength,
  });
}

class CycleEngine {
  static CycleContext? findCycleContext(
    DateTime normDate,
    UserProfile profile,
    List<PeriodEntry>? periodHistory, {
    int? periodLength,
  }) {
    if (periodHistory != null && periodHistory.isNotEmpty) {
      final sorted = [...periodHistory]..sort((a, b) => a.startDate.compareTo(b.startDate));
      final candidates = sorted.where((p) => !p.startDate.isAfter(normDate)).toList();
      if (candidates.isEmpty) {
        return null;
      }
      final current = candidates.last;
      final currentIndex = sorted.indexOf(current);
      final hasNext = currentIndex != -1 && currentIndex + 1 < sorted.length;
      final nextEntry = hasNext ? sorted[currentIndex + 1] : null;

      int bleedLength = current.bleedDurationDays ??
          (current.endDate != null
              ? current.endDate!.calendarDaysDifference(current.startDate) + 1
              : (periodLength ?? profile.averagePeriodLength));

      if (nextEntry == null && current.endDate == null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysSinceStart = today.calendarDaysDifference(current.startDate) + 1;
        if (daysSinceStart > bleedLength && daysSinceStart <= 10) {
          bleedLength = daysSinceStart;
        }
      }

      if (nextEntry != null) {
        // Closed historical cycle: calendar gap is absolute truth
        final actualGap = nextEntry.startDate.calendarDaysDifference(current.startDate);
        final cycleLength = actualGap > 0
            ? actualGap
            : (current.actualCycleLength ?? profile.averageCycleLength);
        return CycleContext(
          entry: current,
          cycleStart: current.startDate,
          nextCycleStart: nextEntry.startDate,
          isClosed: true,
          cycleLength: cycleLength,
          periodLength: bleedLength,
        );
      } else {
        // Active ongoing cycle or future dates
        return CycleContext(
          entry: current,
          cycleStart: current.startDate,
          nextCycleStart: null,
          isClosed: false,
          cycleLength: profile.averageCycleLength,
          periodLength: bleedLength,
        );
      }
    }

    final lp = profile.lastPeriodStart;
    if (lp == null) return null;
    final lpDate = DateTime(lp.year, lp.month, lp.day);
    if (lpDate.isAfter(normDate)) return null;

    int fallbackBleedLength = periodLength ?? profile.averagePeriodLength;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceLp = today.calendarDaysDifference(lpDate) + 1;
    if (daysSinceLp > fallbackBleedLength && daysSinceLp <= 10) {
      fallbackBleedLength = daysSinceLp;
    }

    return CycleContext(
      entry: null,
      cycleStart: lpDate,
      nextCycleStart: null,
      isClosed: false,
      cycleLength: profile.averageCycleLength,
      periodLength: fallbackBleedLength,
    );
  }

  static DateTime? findCycleStart(
    DateTime normDate, UserProfile profile, List<PeriodEntry>? periodHistory) {
    final ctx = findCycleContext(normDate, profile, periodHistory);
    return ctx?.cycleStart;
  }

  static CycleState calculate(UserProfile profile, {List<PeriodEntry>? periodHistory, int? periodLength}) {
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) {
      return CycleState(dayOfCycle: 0, phase: CyclePhase.follicular,
        phaseInfo: PhaseConstants.getPhaseInfo(CyclePhase.follicular),
        daysUntilNextPeriod: profile.averageCycleLength, daysUntilPhaseChange: 0, isAnchored: false);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ctx = findCycleContext(today, profile, periodHistory, periodLength: periodLength);
    final cycleLen = ctx?.cycleLength ?? profile.averageCycleLength;
    final periodLen = ctx?.periodLength ?? (periodLength ?? profile.averagePeriodLength);
    final anchor = ctx?.cycleStart ?? lastPeriod;

    final dayOfCycle = today.calendarDaysDifference(anchor) + 1;
    final phaseDay = dayOfCycle.clamp(1, cycleLen);
    final phase = PhaseConstants.phaseFromDay(
      phaseDay,
      cycleLen,
      periodLength: periodLen,
    );
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    final nextPeriodDate = anchor.add(Duration(days: cycleLen));
    final daysUntilNextPeriod = nextPeriodDate.calendarDaysDifference(today);
    int daysUntilPhaseChange = 0;
    for (int d = dayOfCycle + 1; d <= dayOfCycle + 14; d++) {
      final np = d.clamp(1, cycleLen);
      if (PhaseConstants.phaseFromDay(np, cycleLen, periodLength: periodLen) != phase) {
        daysUntilPhaseChange = d - dayOfCycle; break;
      }
    }
    return CycleState(dayOfCycle: dayOfCycle, phase: phase, phaseInfo: phaseInfo,
      nextPeriodDate: nextPeriodDate, daysUntilNextPeriod: daysUntilNextPeriod,
      daysUntilPhaseChange: daysUntilPhaseChange,
      isPeriodOverdue: daysUntilNextPeriod < -3,
      isPeriodSoon: daysUntilNextPeriod >= 0 && daysUntilNextPeriod <= 3, isAnchored: true);
  }

  static CyclePhase? phaseForDate(DateTime date, UserProfile profile,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false, int? periodLength}) {
    if (profile.lastPeriodStart == null && (periodHistory == null || periodHistory.isEmpty)) return null;
    final normDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ctx = findCycleContext(normDate, profile, periodHistory, periodLength: periodLength);
    if (ctx == null) return null;

    final daysSinceStart = normDate.calendarDaysDifference(ctx.cycleStart);
    if (daysSinceStart < 0) return null;

    if (!normDate.isAfter(today)) {
      final dayOfCycle = daysSinceStart + 1;
      final phaseDay = dayOfCycle.clamp(1, ctx.cycleLength);
      return PhaseConstants.phaseFromDay(phaseDay, ctx.cycleLength, periodLength: ctx.periodLength);
    }
    final historyCount = periodHistory?.length ?? 1;
    if (isCycleLengthUnknown && historyCount < 2) return null;
    final futureDay = (daysSinceStart % ctx.cycleLength) + 1;
    return PhaseConstants.phaseFromDay(futureDay, ctx.cycleLength, periodLength: ctx.periodLength);
  }

  static CycleState? calculateForDate(UserProfile profile, DateTime date,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false, int? periodLength}) {
    if (profile.lastPeriodStart == null && (periodHistory == null || periodHistory.isEmpty)) return null;
    final normDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ctx = findCycleContext(normDate, profile, periodHistory, periodLength: periodLength);
    if (ctx == null) return null;

    final daysSinceStart = normDate.calendarDaysDifference(ctx.cycleStart);
    if (daysSinceStart < 0) return null;

    final historyCount = periodHistory?.length ?? 1;
    int dayOfCycle;
    DateTime nextPeriodDate;

    if (ctx.isClosed && ctx.nextCycleStart != null) {
      dayOfCycle = daysSinceStart + 1;
      nextPeriodDate = ctx.nextCycleStart!;
    } else if (!normDate.isAfter(today)) {
      dayOfCycle = daysSinceStart + 1;
      nextPeriodDate = ctx.cycleStart.add(Duration(days: ctx.cycleLength));
    } else {
      if (isCycleLengthUnknown && historyCount < 2) {
        return null;
      }
      dayOfCycle = (daysSinceStart % ctx.cycleLength) + 1;
      final cyclesAhead = daysSinceStart ~/ ctx.cycleLength;
      nextPeriodDate = ctx.cycleStart.add(Duration(days: (cyclesAhead + 1) * ctx.cycleLength));
    }

    final phaseDay = dayOfCycle.clamp(1, ctx.cycleLength);
    final phase = PhaseConstants.phaseFromDay(phaseDay, ctx.cycleLength, periodLength: ctx.periodLength);
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    return CycleState(dayOfCycle: dayOfCycle, phase: phase,
      phaseInfo: phaseInfo, nextPeriodDate: nextPeriodDate,
      daysUntilNextPeriod: nextPeriodDate.calendarDaysDifference(normDate),
      daysUntilPhaseChange: 0, isAnchored: true);
  }

  static List<DateTime> getPeriodDatesForMonth(DateTime month, UserProfile profile,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false, int? periodLength}) {
    final dates = <DateTime>[];
    if (profile.lastPeriodStart == null) return dates;
    final dim = DateTime(month.year, month.month + 1, 0).day;
    for (int d = 1; d <= dim; d++) {
      final dt = DateTime(month.year, month.month, d);
      if (phaseForDate(dt, profile, periodHistory: periodHistory, isCycleLengthUnknown: isCycleLengthUnknown, periodLength: periodLength) == CyclePhase.menstrual) dates.add(dt);
    }
    return dates;
  }

  static bool isConfirmedPeriodStart(DateTime date, List<PeriodEntry> history) {
    final n = DateTime(date.year, date.month, date.day);
    return history.any((p) => p.startDate.year == n.year &&
        p.startDate.month == n.month && p.startDate.day == n.day);
  }

  static CycleGapAnalysis analyzeGaps(UserProfile profile, List<PeriodEntry>? periodHistory) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseline = profile.averageCycleLength;

    final lp = profile.lastPeriodStart;
    int overdueDays = 0;
    if (lp != null) {
      final daysSinceStart = today.calendarDaysDifference(DateTime(lp.year, lp.month, lp.day));
      overdueDays = daysSinceStart - baseline;
    }

    if (periodHistory == null || periodHistory.length < 2) {
      if (overdueDays >= 4) {
        return CycleGapAnalysis(
          currentDaysOverdue: overdueDays,
          regularity: CycleRegularity.overdue,
          biologicalSummary: 'Current cycle is Day ${overdueDays + baseline + 1}, delayed by $overdueDays days past expected date.',
          clinicalGuidanceDirective: 'Her period is currently $overdueDays days delayed past expected date. Explain endocrinology of delayed ovulation (stress, cortisol, sleep or metabolic shift) rather than generic dos and donts.',
        );
      }
      return CycleGapAnalysis.unknown;
    }

    final sorted = [...periodHistory]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final gaps = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final a = DateTime.utc(sorted[i].startDate.year, sorted[i].startDate.month, sorted[i].startDate.day);
      final b = DateTime.utc(sorted[i - 1].startDate.year, sorted[i - 1].startDate.month, sorted[i - 1].startDate.day);
      final gap = a.difference(b).inDays;
      if (gap >= 14 && gap <= 60) gaps.add(gap);
    }

    if (gaps.isEmpty) {
      if (overdueDays >= 4) {
        return CycleGapAnalysis(
          currentDaysOverdue: overdueDays,
          regularity: CycleRegularity.overdue,
          biologicalSummary: 'Current cycle is Day ${overdueDays + baseline + 1}, delayed by $overdueDays days.',
          clinicalGuidanceDirective: 'Her period is currently $overdueDays days delayed. Address with biological empathy on delayed follicular phase.',
        );
      }
      return CycleGapAnalysis.unknown;
    }

    final latestGap = gaps.last;
    final deviation = latestGap - baseline;

    if (deviation >= 4) {
      return CycleGapAnalysis(
        lastCycleGap: latestGap,
        deviationFromBaseline: deviation,
        regularity: CycleRegularity.delayed,
        biologicalSummary: 'Last cycle was $latestGap days ($deviation days longer than her $baseline-day baseline).',
        clinicalGuidanceDirective: 'Her cycle was delayed by $deviation days. Address this variation with deep endocrinological empathy: explain that the follicular phase stretched due to delayed ovulation (often caused by cortisol, psychological stress, circadian shift, travel, metabolic strain, or illness), while the luteal phase remains biologically fixed at 12-14 days. Reassure her that this is a healthy, protective nervous system response, not a failure of her body. Do not offer generic dos and donts.',
      );
    } else if (deviation <= -4) {
      return CycleGapAnalysis(
        lastCycleGap: latestGap,
        deviationFromBaseline: deviation,
        regularity: CycleRegularity.early,
        biologicalSummary: 'Last cycle was $latestGap days (${-deviation} days shorter than her $baseline-day baseline).',
        clinicalGuidanceDirective: 'Her cycle arrived ${-deviation} days early. Explain the biology: early follicular recruitment, anovulatory cycle, or a shorter luteal phase due to lower progesterone synthesis. Guide her with nourishing foods that support progesterone and nervous system grounding, without sounding clinical or giving generic clichés.',
      );
    } else if (overdueDays >= 4) {
      return CycleGapAnalysis(
        lastCycleGap: latestGap,
        deviationFromBaseline: deviation,
        currentDaysOverdue: overdueDays,
        regularity: CycleRegularity.overdue,
        biologicalSummary: 'Current cycle is Day ${overdueDays + baseline + 1} ($overdueDays days overdue), previous gap was $latestGap days.',
        clinicalGuidanceDirective: 'Her period is currently $overdueDays days delayed past expected date. Explain endocrinology of delayed ovulation (stress, cortisol, sleep or metabolic shift) rather than generic dos and donts.',
      );
    } else {
      return CycleGapAnalysis(
        lastCycleGap: latestGap,
        deviationFromBaseline: deviation,
        regularity: CycleRegularity.normal,
        biologicalSummary: 'Cycle gap is $latestGap days (consistent with her $baseline-day rhythm).',
        clinicalGuidanceDirective: 'Cycle rhythm is consistent with baseline.',
      );
    }
  }
}
