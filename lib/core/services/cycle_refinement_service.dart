import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';

/// Called every time a period is logged.
/// If cycle length was marked unknown OR actual gap differs from stored by >2 days,
/// silently update to rolling average. After 2 refinements, return a gentle message.
class CycleRefinementService {
  static const _refinementCountKey = 'cycle_refinement_count';
  static const _lastRefinedKey = 'last_refined_cycle_length';

  /// Returns a message to show the user if Luna has learned something new, or null if silent.
  static Future<String?> checkAndRefine({
    required UserProfile profile,
    required List<LogEntry> allEntries,
    required Future<void> Function(int newCycleLength) onUpdateCycle,
    required Future<void> Function(int newPeriodLength) onUpdatePeriod,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Find all period start entries, sorted by date
    final periodStarts = allEntries
        .where((e) => e.periodStarted == true)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (periodStarts.length < 2) return null; // not enough data

    // Calculate gaps between consecutive period starts
    final gaps = <int>[];
    for (int i = 1; i < periodStarts.length; i++) {
      final gap = periodStarts[i].date.difference(periodStarts[i - 1].date).inDays;
      if (gap >= 14 && gap <= 60) gaps.add(gap); // sanity check
    }

    if (gaps.isEmpty) return null;

    // Rolling average of last 3 gaps
    final recent = gaps.length > 3 ? gaps.sublist(gaps.length - 3) : gaps;
    final avgCycle = (recent.reduce((a, b) => a + b) / recent.length).round();

    final currentCycle = profile.averageCycleLength;
    final diff = (avgCycle - currentCycle).abs();

    if (diff <= 2) return null; // close enough, no update needed

    // Update silently
    await onUpdateCycle(avgCycle);

    final count = (prefs.getInt(_refinementCountKey) ?? 0) + 1;
    await prefs.setInt(_refinementCountKey, count);
    await prefs.setInt(_lastRefinedKey, avgCycle);

    // Only tell her after 2nd refinement
    if (count >= 2) {
      return 'Luna noticed your cycle is about $avgCycle days 🌙 Updated your rhythm.';
    }
    return null;
  }
}
