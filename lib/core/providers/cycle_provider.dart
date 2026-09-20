import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import '../models/period_entry.dart';
import '../services/storage_service.dart';
import '../services/cycle_engine.dart';
import '../services/notification_service.dart';
import '../services/pattern_analysis_service.dart';
import '../constants/phase_constants.dart';

// -- Profile Provider -----------------------------------------------------------
final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>((_) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(null) {
    _load();
  }

  void _load() {
    state = StorageService.getProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await StorageService.saveProfile(profile);
    state = profile;
    final cycleState = CycleEngine.calculate(profile);
    NotificationService.schedulePhaseNotifications(cycleState);
  }

  /// Syncs profile.lastPeriodStart. Internal use only.
  /// External callers must use PeriodHistoryNotifier.addPeriodStart().
  Future<void> syncLastPeriod(DateTime? date) async {
    if (state == null) return;
    final updated = date == null
        ? state!.copyWith(clearLastPeriod: true)
        : state!.copyWith(lastPeriodStart: date);
    await StorageService.saveProfile(updated);
    state = updated;
    final cycleState = CycleEngine.calculate(updated);
    NotificationService.schedulePhaseNotifications(cycleState);
  }

  Future<void> updateCycleLengths({int? cycleLength, int? periodLength}) async {
    if (state == null) return;
    final updated = state!.copyWith(
      averageCycleLength: cycleLength,
      averagePeriodLength: periodLength,
    );
    await StorageService.saveProfile(updated);
    state = updated;
  }

  Future<void> clear() async {
    await StorageService.clearProfile();
    state = null;
  }
}

// -- Period History Provider ----------------------------------------------------
final periodHistoryProvider =
    StateNotifierProvider<PeriodHistoryNotifier, List<PeriodEntry>>((ref) {
  return PeriodHistoryNotifier(ref);
});

class PeriodHistoryNotifier extends StateNotifier<List<PeriodEntry>> {
  final Ref _ref;
  bool _isLoaded = false;
  Future<void>? _loadFuture;
  bool _isAdding = false;

  PeriodHistoryNotifier(this._ref) : super([]) {
    _loadFuture = _load();
  }

  Future<void> _load() async {
    state = await StorageService.getPeriodHistory();
    _isLoaded = true;
  }

  /// The single correct entry point for recording a period start anywhere in the app.
  /// Idempotent: safe to call multiple times for the same date.
  Future<void> addPeriodStart(DateTime date, {String source = 'logged'}) async {
    // Normalise to midnight to eliminate time-of-day drift in gap calculations
    final normDate = DateTime(date.year, date.month, date.day);

    if (!_isLoaded && _loadFuture != null) {
      await _loadFuture;
    }

    // Fast idempotency check: skip if we already have this exact date
    final alreadyExists = state.any((p) =>
        p.startDate.year == normDate.year &&
        p.startDate.month == normDate.month &&
        p.startDate.day == normDate.day);

    if (alreadyExists) {
      final mostRecent = state.isNotEmpty ? state.first.startDate : normDate;
      await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);
      return;
    }

    if (_isAdding) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (state.any((p) =>
          p.startDate.year == normDate.year &&
          p.startDate.month == normDate.month &&
          p.startDate.day == normDate.day)) {
        return;
      }
    }

    _isAdding = true;
    try {
      final entry = PeriodEntry(
        id: PeriodEntry.newId(),
        startDate: normDate,
        source: source,
      );
      await StorageService.savePeriodEntry(entry);
      // Reload fresh list to guarantee perfect deduplication from DB
      state = await StorageService.getPeriodHistory();

      // Sync profile anchor to the most recent known period start
      final mostRecent = state.isNotEmpty ? state.first.startDate : normDate;
      await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);

      // Ensure a LogEntry exists for this date with periodStarted = true
      final logEntries = _ref.read(logEntriesProvider);
      final logsForDate = logEntries.where((e) =>
          e.date.year == normDate.year &&
          e.date.month == normDate.month &&
          e.date.day == normDate.day);

      if (logsForDate.isEmpty) {
        final newLog = LogEntry(
          id: const Uuid().v4(),
          date: normDate,
          symptoms: [],
          periodStarted: true,
        );
        await _ref.read(logEntriesProvider.notifier).addEntry(newLog);
      } else if (!logsForDate.first.periodStarted) {
        final updated = logsForDate.first.copyWith(periodStarted: true);
        await _ref.read(logEntriesProvider.notifier).addEntry(updated);
      }

      // Recompute average cycle length from actual gap history
      _recomputeCycleLength();
    } finally {
      _isAdding = false;
    }
  }

  void _recomputeCycleLength() {
    if (state.length < 2) return;
    final sorted = [...state]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final gaps = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final a = DateTime.utc(sorted[i].startDate.year, sorted[i].startDate.month, sorted[i].startDate.day);
      final b = DateTime.utc(sorted[i - 1].startDate.year, sorted[i - 1].startDate.month, sorted[i - 1].startDate.day);
      final gap = a.difference(b).inDays;
      if (gap >= 14 && gap <= 60) gaps.add(gap);
    }
    if (gaps.isEmpty) return;
    final recent = gaps.length > 3 ? gaps.sublist(gaps.length - 3) : gaps;
    final avgCycle = (recent.reduce((a, b) => a + b) / recent.length).round();
    final profile = _ref.read(profileProvider);
    if (profile != null && avgCycle != profile.averageCycleLength) {
      _ref.read(profileProvider.notifier).updateCycleLengths(cycleLength: avgCycle);
      StorageService.setCycleLengthCalibrated();
    }
  }

  Future<void> removePeriodEntry(String id) async {
    final entry = state.where((e) => e.id == id).firstOrNull;
    await StorageService.deletePeriodEntry(id);
    state = state.where((e) => e.id != id).toList();
    final mostRecent = state.isNotEmpty ? state.first.startDate : null;
    await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);

    if (entry != null) {
      final normDate = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);
      final logs = _ref.read(logEntriesProvider);
      final matching = logs.where((e) =>
          e.date.year == normDate.year &&
          e.date.month == normDate.month &&
          e.date.day == normDate.day).firstOrNull;
      if (matching != null && matching.periodStarted) {
        final updated = matching.copyWith(periodStarted: false);
        await _ref.read(logEntriesProvider.notifier).addEntry(updated);
      }
    }

    _recomputeCycleLength();
  }

  Future<void> clearAll() async {
    await StorageService.clearPeriodHistory();
    state = [];
    await _ref.read(profileProvider.notifier).syncLastPeriod(null);
  }

  Future<void> refresh() async {
    state = await StorageService.getPeriodHistory();
  }
}

// -- Cycle State Provider -------------------------------------------------------
final cycleStateProvider = Provider<CycleState?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  return CycleEngine.calculate(profile);
});

// -- Cycle Anchor Presence Provider ---------------------------------------------
final hasCycleAnchorProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileProvider);
  return profile?.lastPeriodStart != null;
});

// -- Unknown Cycle Length State Provider ----------------------------------------
final isCycleLengthUnknownProvider = Provider<bool>((ref) {
  final history = ref.watch(periodHistoryProvider);
  if (history.length >= 2) {
    final sorted = [...history]..sort((a, b) => a.startDate.compareTo(b.startDate));
    bool hasValidGap = false;
    for (int i = 1; i < sorted.length; i++) {
      final a = DateTime.utc(sorted[i].startDate.year, sorted[i].startDate.month, sorted[i].startDate.day);
      final b = DateTime.utc(sorted[i - 1].startDate.year, sorted[i - 1].startDate.month, sorted[i - 1].startDate.day);
      final gap = a.difference(b).inDays;
      if (gap >= 14 && gap <= 60) {
        hasValidGap = true;
        break;
      }
    }
    if (hasValidGap) return false;
  }
  return StorageService.isCycleLengthUnknown();
});

// -- Current Phase Provider -----------------------------------------------------
final currentPhaseProvider = Provider<CyclePhase>((ref) {
  final hasCycle = ref.watch(hasCycleAnchorProvider);
  if (!hasCycle) return CyclePhase.follicular;
  final cycleState = ref.watch(cycleStateProvider);
  return cycleState?.phase ?? CyclePhase.follicular;
});

// -- Cycle Gap Analysis & Abnormality Provider ------------------------------
final cycleGapAnalysisProvider = Provider<CycleGapAnalysis>((ref) {
  final profile = ref.watch(profileProvider);
  final history = ref.watch(periodHistoryProvider);
  if (profile == null) return CycleGapAnalysis.unknown;
  return CycleEngine.analyzeGaps(profile, history);
});

// -- Unknown Period Length State Provider ---------------------------------------
final isPeriodLengthUnknownProvider = Provider<bool>((ref) {
  return StorageService.isPeriodLengthUnknown();
});

// -- Log Entries Provider -------------------------------------------------------
final logEntriesProvider =
    StateNotifierProvider<LogEntriesNotifier, List<LogEntry>>((ref) {
  return LogEntriesNotifier(ref);
});

class LogEntriesNotifier extends StateNotifier<List<LogEntry>> {
  final Ref _ref;
  LogEntriesNotifier(this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.getLogEntries();
    _recomputePeriodLength();
  }

  Future<void> addEntry(LogEntry entry) async {
    // Biological rule: active menstrual flow strictly implies period started
    LogEntry finalEntry = entry;
    if (entry.flow != null && !entry.periodStarted) {
      finalEntry = entry.copyWith(periodStarted: true);
    }

    await StorageService.saveLogEntry(finalEntry);
    state = [finalEntry, ...state.where((e) => e.id != finalEntry.id)];

    if (finalEntry.periodStarted) {
      final history = _ref.read(periodHistoryProvider);
      final normDate = DateTime(finalEntry.date.year, finalEntry.date.month, finalEntry.date.day);
      final alreadyAnchored = history.any((p) =>
          p.startDate.year == normDate.year &&
          p.startDate.month == normDate.month &&
          p.startDate.day == normDate.day);
      if (!alreadyAnchored) {
        await _ref.read(periodHistoryProvider.notifier).addPeriodStart(
          normDate,
          source: 'log_entry',
        );
      }
    }

    _recomputePeriodLength();
  }

  Future<void> deleteEntry(String id) async {
    await StorageService.deleteLogEntry(id);
    state = state.where((e) => e.id != id).toList();
    _recomputePeriodLength();
  }

  Future<void> deleteTodayEntry() async {
    final today = DateTime.now();
    final toRemove = state
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .toList();
    for (final entry in toRemove) {
      await StorageService.deleteLogEntry(entry.id);
    }
    state = state
        .where((e) => !(e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day))
        .toList();
    _recomputePeriodLength();
  }

  void _recomputePeriodLength() {
    final bleedingDays = state.where((e) =>
      e.flow != null ||
      e.periodStarted ||
      e.symptoms.contains('Period')
    ).toList();
    if (bleedingDays.isEmpty) return;

    final sortedDates = bleedingDays
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();

    if (sortedDates.isEmpty) return;

    final runs = <int>[];
    int currentRunLength = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff <= 2) {
        currentRunLength += diff;
      } else {
        if (currentRunLength >= 2 && currentRunLength <= 10) {
          runs.add(currentRunLength);
        }
        currentRunLength = 1;
      }
    }
    if (currentRunLength >= 2 && currentRunLength <= 10) {
      runs.add(currentRunLength);
    }

    if (runs.isEmpty) return;

    final avgPeriod = (runs.reduce((a, b) => a + b) / runs.length).round().clamp(2, 9);
    final profile = _ref.read(profileProvider);
    if (profile != null) {
      if (profile.averagePeriodLength != avgPeriod) {
        _ref.read(profileProvider.notifier).updateCycleLengths(periodLength: avgPeriod);
      }
      StorageService.setPeriodLengthCalibrated();
    }
  }

  Future<void> refresh() async {
    state = await StorageService.getLogEntries();
  }

  LogEntry? get todayEntry {
    final today = DateTime.now();
    try {
      return state.firstWhere(
        (e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day,
      );
    } catch (_) {
      return null;
    }
  }
}

// -- Today Log Provider ---------------------------------------------------------
final todayLogProvider = Provider<LogEntry?>((ref) {
  final entries = ref.watch(logEntriesProvider);
  final today = DateTime.now();
  try {
    return entries.firstWhere(
      (e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day,
    );
  } catch (_) {
    return null;
  }
});

// -- Longitudinal Pattern Intelligence Provider ---------------------------------
final patternProfileProvider = Provider<LongitudinalProfile>((ref) {
  final logs = ref.watch(logEntriesProvider);
  final profile = ref.watch(profileProvider);
  final history = ref.watch(periodHistoryProvider);
  if (profile == null) {
    return PatternAnalysisService.analyze(
      logs: logs,
      profile: UserProfile(
        id: 'default',
        name: 'You',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        createdAt: DateTime.now(),
      ),
      periodHistory: history,
    );
  }
  return PatternAnalysisService.analyze(
    logs: logs,
    profile: profile,
    periodHistory: history,
  );
});
