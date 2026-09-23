import 'package:uuid/uuid.dart';

/// A single period start record stored in the period_history table.
/// Accumulates indefinitely: never overwritten by new period logs.
class PeriodEntry {
  final String id;
  final DateTime startDate;
  final String source; // onboarding | logged | calendar | ai | insights | settings
  final DateTime? endDate;
  final int? bleedDurationDays;
  final bool isUserSpecifiedDuration;
  final int? actualCycleLength;

  const PeriodEntry({
    required this.id,
    required this.startDate,
    this.source = 'logged',
    this.endDate,
    this.bleedDurationDays,
    this.isUserSpecifiedDuration = false,
    this.actualCycleLength,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    // Always store as date-only (midnight) to avoid time-of-day drift in gap calculations
    'start_date': DateTime(startDate.year, startDate.month, startDate.day).toIso8601String(),
    'source': source,
    'end_date': endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day).toIso8601String()
        : null,
    'bleed_duration_days': bleedDurationDays,
    'is_user_specified_duration': isUserSpecifiedDuration ? 1 : 0,
    'actual_cycle_length': actualCycleLength,
  };

  factory PeriodEntry.fromMap(Map<String, dynamic> map) => PeriodEntry(
    id: map['id'] as String,
    startDate: DateTime.parse(map['start_date'] as String),
    source: map['source'] as String? ?? 'logged',
    endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
    bleedDurationDays: map['bleed_duration_days'] as int?,
    isUserSpecifiedDuration: (map['is_user_specified_duration'] as int? ?? 0) == 1,
    actualCycleLength: map['actual_cycle_length'] as int?,
  );

  PeriodEntry copyWith({
    String? id,
    DateTime? startDate,
    String? source,
    DateTime? endDate,
    bool clearEndDate = false,
    int? bleedDurationDays,
    bool clearBleedDuration = false,
    bool? isUserSpecifiedDuration,
    int? actualCycleLength,
    bool clearActualCycleLength = false,
  }) {
    return PeriodEntry(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      source: source ?? this.source,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      bleedDurationDays: clearBleedDuration ? null : (bleedDurationDays ?? this.bleedDurationDays),
      isUserSpecifiedDuration: isUserSpecifiedDuration ?? this.isUserSpecifiedDuration,
      actualCycleLength: clearActualCycleLength ? null : (actualCycleLength ?? this.actualCycleLength),
    );
  }

  static String newId() => const Uuid().v4();
}
