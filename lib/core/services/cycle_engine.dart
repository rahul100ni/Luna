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

class CycleEngine {
  static DateTime? _findCycleStart(
    DateTime normDate, UserProfile profile, List<PeriodEntry>? periodHistory) {
    if (periodHistory != null && periodHistory.isNotEmpty) {
      final c = periodHistory.where((p) => !p.startDate.isAfter(normDate)).toList();
      if (c.isNotEmpty) { c.sort((a, b) => b.startDate.compareTo(a.startDate)); return c.first.startDate; }
    }
    final lp = profile.lastPeriodStart;
    if (lp == null) return null;
    return DateTime(lp.year, lp.month, lp.day);
  }

  static CycleState calculate(UserProfile profile) {
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) {
      return CycleState(dayOfCycle: 0, phase: CyclePhase.follicular,
        phaseInfo: PhaseConstants.getPhaseInfo(CyclePhase.follicular),
        daysUntilNextPeriod: profile.averageCycleLength, daysUntilPhaseChange: 0, isAnchored: false);
    }
    final now = DateTime.now();
    final dayOfCycle = now.calendarDaysDifference(lastPeriod) + 1;
    final phaseDay = dayOfCycle.clamp(1, profile.averageCycleLength);
    final phase = PhaseConstants.phaseFromDay(phaseDay, profile.averageCycleLength);
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    final nextPeriodDate = lastPeriod.add(Duration(days: profile.averageCycleLength));
    final daysUntilNextPeriod = nextPeriodDate.calendarDaysDifference(now);
    int daysUntilPhaseChange = 0;
    for (int d = dayOfCycle + 1; d <= dayOfCycle + 14; d++) {
      final np = d.clamp(1, profile.averageCycleLength);
      if (PhaseConstants.phaseFromDay(np, profile.averageCycleLength) != phase) {
        daysUntilPhaseChange = d - dayOfCycle; break;
      }
    }
    return CycleState(dayOfCycle: dayOfCycle, phase: phase, phaseInfo: phaseInfo,
      nextPeriodDate: nextPeriodDate, daysUntilNextPeriod: daysUntilNextPeriod,
      daysUntilPhaseChange: daysUntilPhaseChange,
      isPeriodOverdue: daysUntilNextPeriod < -3,
      isPeriodSoon: daysUntilNextPeriod >= 0 && daysUntilNextPeriod <= 3, isAnchored: true);
  }

  static CyclePhase phaseForDate(DateTime date, UserProfile profile,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false}) {
    if (profile.lastPeriodStart == null) return CyclePhase.follicular;
    final normDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycleStart = _findCycleStart(normDate, profile, periodHistory);
    if (cycleStart == null) return CyclePhase.follicular;
    final daysSinceStart = normDate.calendarDaysDifference(cycleStart);
    if (daysSinceStart < 0) return CyclePhase.follicular;
    final cycleLength = profile.averageCycleLength;
    if (!normDate.isAfter(today)) {
      final dayOfCycle = daysSinceStart + 1;
      final phaseDay = dayOfCycle.clamp(1, cycleLength);
      return PhaseConstants.phaseFromDay(phaseDay, cycleLength);
    }
    final historyCount = periodHistory?.length ?? 1;
    if (isCycleLengthUnknown && historyCount < 2) return CyclePhase.follicular;
    final futureDay = (daysSinceStart % cycleLength) + 1;
    return PhaseConstants.phaseFromDay(futureDay, cycleLength);
  }

  static CycleState? calculateForDate(UserProfile profile, DateTime date,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false}) {
    if (profile.lastPeriodStart == null) return null;
    final normDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycleStart = _findCycleStart(normDate, profile, periodHistory);
    if (cycleStart == null) return null;
    final daysSinceStart = normDate.calendarDaysDifference(cycleStart);
    if (daysSinceStart < 0) return null;
    final cycleLength = profile.averageCycleLength;
    final historyCount = periodHistory?.length ?? 1;
    int dayOfCycle;
    DateTime nextPeriodDate;
    if (!normDate.isAfter(today)) {
      dayOfCycle = daysSinceStart + 1;
      nextPeriodDate = cycleStart.add(Duration(days: cycleLength));
    } else {
      if (isCycleLengthUnknown && historyCount < 2) {
        return CycleState(dayOfCycle: daysSinceStart + 1, phase: CyclePhase.follicular,
          phaseInfo: PhaseConstants.getPhaseInfo(CyclePhase.follicular),
          daysUntilNextPeriod: 0, daysUntilPhaseChange: 0, isAnchored: true);
      }
      dayOfCycle = (daysSinceStart % cycleLength) + 1;
      final cyclesAhead = daysSinceStart ~/ cycleLength;
      nextPeriodDate = cycleStart.add(Duration(days: (cyclesAhead + 1) * cycleLength));
    }
    final phaseDay = dayOfCycle.clamp(1, cycleLength);
    final phase = PhaseConstants.phaseFromDay(phaseDay, cycleLength);
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    return CycleState(dayOfCycle: dayOfCycle, phase: phase,
      phaseInfo: phaseInfo, nextPeriodDate: nextPeriodDate,
      daysUntilNextPeriod: nextPeriodDate.calendarDaysDifference(normDate),
      daysUntilPhaseChange: 0, isAnchored: true);
  }

  static List<DateTime> getPeriodDatesForMonth(DateTime month, UserProfile profile,
      {List<PeriodEntry>? periodHistory, bool isCycleLengthUnknown = false}) {
    final dates = <DateTime>[];
    if (profile.lastPeriodStart == null) return dates;
    final dim = DateTime(month.year, month.month + 1, 0).day;
    for (int d = 1; d <= dim; d++) {
      final dt = DateTime(month.year, month.month, d);
      if (phaseForDate(dt, profile, periodHistory: periodHistory, isCycleLengthUnknown: isCycleLengthUnknown) == CyclePhase.menstrual) dates.add(dt);
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
