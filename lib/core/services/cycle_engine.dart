import '../constants/phase_constants.dart';
import '../models/user_profile.dart';

class CycleState {
  final int dayOfCycle;
  final CyclePhase phase;
  final PhaseInfo phaseInfo;
  final DateTime? nextPeriodDate;
  final int daysUntilNextPeriod;
  final int daysUntilPhaseChange;
  final bool isPeriodOverdue;
  final bool isPeriodSoon; // within 3 days

  const CycleState({
    required this.dayOfCycle,
    required this.phase,
    required this.phaseInfo,
    this.nextPeriodDate,
    required this.daysUntilNextPeriod,
    required this.daysUntilPhaseChange,
    this.isPeriodOverdue = false,
    this.isPeriodSoon = false,
  });
}

class CycleEngine {
  static CycleState calculate(UserProfile profile) {
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) {
      return CycleState(
        dayOfCycle: 0,
        phase: CyclePhase.menstrual,
        phaseInfo: PhaseConstants.getPhaseInfo(CyclePhase.menstrual),
        daysUntilNextPeriod: profile.averageCycleLength,
        daysUntilPhaseChange: 5,
      );
    }

    final now = DateTime.now();
    final dayOfCycle = now.difference(lastPeriod).inDays + 1;
    final phase = PhaseConstants.phaseFromDay(dayOfCycle, profile.averageCycleLength);
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);

    final nextPeriodDate = lastPeriod.add(Duration(days: profile.averageCycleLength));
    final daysUntilNextPeriod = nextPeriodDate.difference(now).inDays;

    // Days until phase changes
    int daysUntilPhaseChange = 1;
    for (int d = dayOfCycle + 1; d <= profile.averageCycleLength + 5; d++) {
      final nextPhase = PhaseConstants.phaseFromDay(d, profile.averageCycleLength);
      if (nextPhase != phase) {
        daysUntilPhaseChange = d - dayOfCycle;
        break;
      }
    }

    return CycleState(
      dayOfCycle: dayOfCycle,
      phase: phase,
      phaseInfo: phaseInfo,
      nextPeriodDate: nextPeriodDate,
      daysUntilNextPeriod: daysUntilNextPeriod,
      daysUntilPhaseChange: daysUntilPhaseChange,
      isPeriodOverdue: daysUntilNextPeriod < -3,
      isPeriodSoon: daysUntilNextPeriod >= 0 && daysUntilNextPeriod <= 3,
    );
  }

  /// Returns phase for a specific date (used by calendar)
  static CyclePhase phaseForDate(DateTime date, UserProfile profile) {
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) return CyclePhase.follicular;
    final dayOfCycle = date.difference(lastPeriod).inDays + 1;
    int adjustedDay;
    if (dayOfCycle > 0) {
      final rem = dayOfCycle % profile.averageCycleLength;
      adjustedDay = rem == 0 ? profile.averageCycleLength : rem;
    } else {
      final rem = ((-dayOfCycle) % profile.averageCycleLength);
      adjustedDay = profile.averageCycleLength - rem;
      if (adjustedDay <= 0) adjustedDay = 1;
    }
    return PhaseConstants.phaseFromDay(adjustedDay, profile.averageCycleLength);
  }

  /// Returns a full CycleState for any arbitrary date (used by calendar day cards)
  static CycleState? calculateForDate(UserProfile profile, DateTime date) {
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) return null;
    final dayOfCycle = date.difference(lastPeriod).inDays + 1;
    int effectiveDay;
    if (dayOfCycle > 0) {
      final rem = dayOfCycle % profile.averageCycleLength;
      effectiveDay = rem == 0 ? profile.averageCycleLength : rem;
    } else {
      final rem = ((-dayOfCycle) % profile.averageCycleLength);
      effectiveDay = profile.averageCycleLength - rem;
      if (effectiveDay <= 0) effectiveDay = 1;
    }
    final phase = PhaseConstants.phaseFromDay(effectiveDay, profile.averageCycleLength);
    final phaseInfo = PhaseConstants.getPhaseInfo(phase);
    final nextPeriodDate = lastPeriod.add(Duration(days: profile.averageCycleLength));
    return CycleState(
      dayOfCycle: effectiveDay,
      phase: phase,
      phaseInfo: phaseInfo,
      nextPeriodDate: nextPeriodDate,
      daysUntilNextPeriod: nextPeriodDate.difference(date).inDays,
      daysUntilPhaseChange: 1,
    );
  }

  static List<DateTime> getPeriodDatesForMonth(DateTime month, UserProfile profile) {
    final dates = <DateTime>[];
    final lastPeriod = profile.lastPeriodStart;
    if (lastPeriod == null) return dates;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final phase = phaseForDate(date, profile);
      if (phase == CyclePhase.menstrual) dates.add(date);
    }
    return dates;
  }
}

