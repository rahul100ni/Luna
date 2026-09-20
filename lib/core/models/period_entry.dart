import 'package:uuid/uuid.dart';

/// A single period start record stored in the period_history table.
/// Accumulates indefinitely — never overwritten by new period logs.
class PeriodEntry {
  final String id;
  final DateTime startDate;
  final String source; // onboarding | logged | calendar | ai | insights | settings

  const PeriodEntry({
    required this.id,
    required this.startDate,
    this.source = 'logged',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    // Always store as date-only (midnight) to avoid time-of-day drift in gap calculations
    'start_date': DateTime(startDate.year, startDate.month, startDate.day).toIso8601String(),
    'source': source,
  };

  factory PeriodEntry.fromMap(Map<String, dynamic> map) => PeriodEntry(
    id: map['id'] as String,
    startDate: DateTime.parse(map['start_date'] as String),
    source: map['source'] as String? ?? 'logged',
  );

  static String newId() => const Uuid().v4();
}
