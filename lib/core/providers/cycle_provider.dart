import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import '../models/period_entry.dart';
import '../services/storage_service.dart';
import '../services/cycle_engine.dart';
import '../services/notification_service.dart';
import '../services/pattern_analysis_service.dart';
import '../services/cloud_ground_truth_service.dart';
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
    await StorageService.migrateLegacyPeriodStarts();
    state = await StorageService.getPeriodHistory();
    _isLoaded = true;

    // Ensure profile anchor matches the most recent period start in history
    final profile = _ref.read(profileProvider);
    if (state.isNotEmpty) {
      final mostRecent = state.first.startDate;
      if (profile != null && profile.lastPeriodStart != mostRecent) {
        await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);
      }
    } else if (profile?.lastPeriodStart != null) {
      // Migrate existing profile anchor into period_history if history was empty
      await addPeriodStart(profile!.lastPeriodStart!, source: 'profile');
    }
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

    // Check if there is an existing entry within 14 days
    // Biological human cycles cannot be < 14 days.
    final nearby = state.where((p) {
      final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      return (pNorm.difference(normDate).inDays.abs()) < 14;
    }).firstOrNull;

    if (nearby != null) {
      final pNorm = DateTime(nearby.startDate.year, nearby.startDate.month, nearby.startDate.day);
      final isExplicitCorrection = source == 'correction' ||
          source == 'ai_correction' ||
          source == 'settings';

      if (isExplicitCorrection) {
        await editPeriodEntry(nearby.id, normDate);
        return;
      }

      // If user marks an earlier date (e.g. correcting start date backwards from 21st to 20th)
      if (normDate.isBefore(pNorm)) {
        await editPeriodEntry(nearby.id, normDate);
        return;
      }

      // If normDate is after an existing period start within 14 days, it is consecutive bleeding / Day 2+
      // It must NEVER overwrite or push forward Day 1 of the period! (VISION Pillar Nine)
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

      // Ensure LogEntry for this date has periodStarted = true without cascading
      await _ref.read(logEntriesProvider.notifier).setPeriodStartedForDate(normDate, true);

      // If there is an immediately preceding cycle anchor, calculate and lock its actualCycleLength
      final sortedBefore = state.where((p) => p.startDate.isBefore(normDate)).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      if (sortedBefore.isNotEmpty) {
        final prev = sortedBefore.first;
        final gap = normDate.difference(DateTime(prev.startDate.year, prev.startDate.month, prev.startDate.day)).inDays;
        if (gap > 0 && prev.actualCycleLength != gap) {
          final updatedPrev = prev.copyWith(actualCycleLength: gap);
          await StorageService.savePeriodEntry(updatedPrev);
          state = await StorageService.getPeriodHistory();
        }
      }

      // Recompute average cycle length from actual gap history
      _recomputeCycleLength();

      // Background Ground-Truth Cloud Sync (non-blocking)
      CloudGroundTruthService.syncAll();
    } finally {
      _isAdding = false;
    }
  }

  /// Updates a specific period entry by ID to a new date.
  /// Works for ANY entry in history (current or past) without deleting adjacent cycles.
  Future<void> editPeriodEntry(String id, DateTime newDate) async {
    final normNew = DateTime(newDate.year, newDate.month, newDate.day);

    if (!_isLoaded && _loadFuture != null) {
      await _loadFuture;
    }

    final entry = state.where((e) => e.id == id).firstOrNull;
    if (entry == null) return;

    final oldNorm = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);

    // If date didn't change, do nothing
    if (oldNorm.year == normNew.year &&
        oldNorm.month == normNew.month &&
        oldNorm.day == normNew.day) {
      return;
    }

    // 1. Remove any other entry that already exists on normNew to avoid duplicates
    final duplicates = state.where((p) =>
        p.id != id &&
        p.startDate.year == normNew.year &&
        p.startDate.month == normNew.month &&
        p.startDate.day == normNew.day).toList();
    for (final d in duplicates) {
      await StorageService.deletePeriodEntry(d.id);
    }

    // 2. Update the entry with new date in storage
    final updated = PeriodEntry(
      id: id,
      startDate: normNew,
      source: entry.source,
    );
    await StorageService.savePeriodEntry(updated);

    // 3. Unmark old LogEntry if no flow was logged (using non-cascading method)
    await _ref.read(logEntriesProvider.notifier).setPeriodStartedForDate(oldNorm, false);

    // 4. Ensure LogEntry for normNew has periodStarted = true (using non-cascading method)
    await _ref.read(logEntriesProvider.notifier).setPeriodStartedForDate(normNew, true);

    // 5. Reload fresh history from DB
    state = await StorageService.getPeriodHistory();

    // 6. Sync profile anchor to the most recent period start in history
    final mostRecent = state.isNotEmpty ? state.first.startDate : null;
    await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);

    // 7. Recompute cycle length
    _recomputeCycleLength();
  }

  /// Explicitly updates or corrects the cycle period start date (e.g. from Settings or Calendar).
  /// - If history is empty: inserts new entry for newDate and syncs profile.
  /// - If newDate is a subsequent cycle (>= 14 days after latest anchor):
  ///   appends new cycle entry, preserving previous history.
  /// - Otherwise (correction of existing anchor):
  ///   updates the anchor without wiping older history.
  Future<void> updatePeriodStart(DateTime newDate, {DateTime? oldDate}) async {
    final normNew = DateTime(newDate.year, newDate.month, newDate.day);
    DateTime? normOld = oldDate != null ? DateTime(oldDate.year, oldDate.month, oldDate.day) : null;

    if (!_isLoaded && _loadFuture != null) {
      await _loadFuture;
    }

    // Always fetch fresh state from SQLite
    state = await StorageService.getPeriodHistory();

    if (state.isEmpty) {
      await addPeriodStart(normNew, source: 'settings');
      return;
    }

    normOld ??= state.first.startDate;

    final latestDate = DateTime(state.first.startDate.year, state.first.startDate.month, state.first.startDate.day);

    // If newDate is >= 14 days AFTER the latest date in history, it's a subsequent cycle
    if (normNew.difference(latestDate).inDays >= 14) {
      await addPeriodStart(normNew, source: 'settings');
      return;
    }

    // Find the target entry to correct
    final target = state.where((p) =>
        p.startDate.year == normOld!.year &&
        p.startDate.month == normOld.month &&
        p.startDate.day == normOld.day).firstOrNull ??
        state.where((p) {
          final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
          return (pNorm.difference(normNew).inDays.abs()) < 14;
        }).firstOrNull ??
        state.first;

    // Clean up any accidental entries strictly AFTER normNew in the same cycle
    if (target.id == state.first.id) {
      final phantomLater = state.where((p) {
        final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        return p.id != target.id && pNorm.isAfter(normNew);
      }).toList();
      for (final p in phantomLater) {
        await StorageService.deletePeriodEntry(p.id);
      }
    }

    await editPeriodEntry(target.id, normNew);
  }

  /// Recomputes average cycle length only when sufficient completed cycles exist.
  /// Clinically guarded: Requires at least 2 completed physiological cycle gaps (21 to 38 days)
  /// so that single-cycle anomalies or outlier gaps never overwrite baseline.
  void _recomputeCycleLength() {
    if (state.length < 3) return; // At least 3 anchors needed for 2 completed cycles
    final sorted = [...state]..sort((a, b) => a.startDate.compareTo(b.startDate));
    final validGaps = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final a = DateTime.utc(sorted[i].startDate.year, sorted[i].startDate.month, sorted[i].startDate.day);
      final b = DateTime.utc(sorted[i - 1].startDate.year, sorted[i - 1].startDate.month, sorted[i - 1].startDate.day);
      final gap = a.difference(b).inDays;
      // Normal physiological cycle window: 21 to 38 days (ACOG / FIGO standard)
      if (gap >= 21 && gap <= 38) {
        validGaps.add(gap);
      }
    }
    if (validGaps.length < 2) return;
    final recent = validGaps.length > 3 ? validGaps.sublist(validGaps.length - 3) : validGaps;
    final avgCycle = (recent.reduce((a, b) => a + b) / recent.length).round();
    final profile = _ref.read(profileProvider);
    if (profile != null && avgCycle != profile.averageCycleLength) {
      _ref.read(profileProvider.notifier).updateCycleLengths(cycleLength: avgCycle);
      StorageService.setCycleLengthCalibrated();
    }
  }

  /// One-tap rollback of cycle anchor changes
  Future<void> undoPeriodStartUpdate(DateTime previousAnchor) async {
    final normPrev = DateTime(previousAnchor.year, previousAnchor.month, previousAnchor.day);
    if (!_isLoaded && _loadFuture != null) {
      await _loadFuture;
    }
    await updatePeriodStart(normPrev);
  }

  /// Records the end of bleeding for the active cycle, locking its bleed duration
  /// so that future settings changes never alter this cycle's bleeding days.
  Future<void> recordPeriodStop(DateTime stopDate) async {
    final normStop = DateTime(stopDate.year, stopDate.month, stopDate.day);
    if (!_isLoaded && _loadFuture != null) {
      await _loadFuture;
    }
    state = await StorageService.getPeriodHistory();
    if (state.isEmpty) return;

    // Find the cycle entry that started on or before normStop
    final candidates = state.where((p) => !p.startDate.isAfter(normStop)).toList();
    if (candidates.isEmpty) return;
    final anchor = candidates.first;

    final anchorDate = DateTime(anchor.startDate.year, anchor.startDate.month, anchor.startDate.day);
    final days = normStop.difference(anchorDate).inDays + 1;
    final bleedDays = days.clamp(1, 14);

    final updated = anchor.copyWith(
      endDate: normStop,
      bleedDurationDays: bleedDays,
      isUserSpecifiedDuration: true,
    );

    await StorageService.savePeriodEntry(updated);
    state = await StorageService.getPeriodHistory();
    CloudGroundTruthService.syncAll();
  }

  Future<void> removePeriodEntry(String id) async {
    final entry = state.where((e) => e.id == id).firstOrNull;
    await StorageService.deletePeriodEntry(id);
    state = state.where((e) => e.id != id).toList();
    final mostRecent = state.isNotEmpty ? state.first.startDate : null;
    await _ref.read(profileProvider.notifier).syncLastPeriod(mostRecent);

    if (entry != null) {
      final normDate = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);
      await _ref.read(logEntriesProvider.notifier).setPeriodStartedForDate(normDate, false);
    }

    _recomputeCycleLength();
    CloudGroundTruthService.syncAll();
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
  final history = ref.watch(periodHistoryProvider);
  if (profile == null) return null;
  return CycleEngine.calculate(profile, periodHistory: history);
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

  /// Sets periodStarted flag for a given calendar date directly without cascading to PeriodHistoryNotifier.
  Future<void> setPeriodStartedForDate(DateTime date, bool started) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final index = state.indexWhere((e) =>
        e.date.year == normDate.year &&
        e.date.month == normDate.month &&
        e.date.day == normDate.day);

    if (index != -1) {
      final existing = state[index];
      if (!started && existing.flow != null) return; // Retain periodStarted if flow is present
      if (existing.periodStarted != started) {
        final updated = existing.copyWith(periodStarted: started);
        await StorageService.saveLogEntry(updated);
        final updatedList = [...state];
        updatedList[index] = updated;
        state = updatedList;
      }
    } else if (started) {
      final newLog = LogEntry(
        id: const Uuid().v4(),
        date: normDate,
        symptoms: [],
        periodStarted: true,
      );
      await StorageService.saveLogEntry(newLog);
      state = [newLog, ...state];
    }
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
        // If within 1 to 13 days of a recent period start, this is an active bleeding day in the same cycle.
        // It must NOT move or create a new cycle anchor.
        final sameCycle = history.where((p) {
          final diff = normDate.difference(p.startDate).inDays;
          return diff >= 0 && diff < 14;
        }).firstOrNull;

        if (sameCycle == null) {
          await _ref.read(periodHistoryProvider.notifier).addPeriodStart(
            normDate,
            source: 'log_entry',
          );
        }
      }
    } else {
      final history = _ref.read(periodHistoryProvider);
      final normDate = DateTime(finalEntry.date.year, finalEntry.date.month, finalEntry.date.day);
      final existingAnchor = history.where((p) =>
          p.startDate.year == normDate.year &&
          p.startDate.month == normDate.month &&
          p.startDate.day == normDate.day).firstOrNull;
      if (existingAnchor != null && finalEntry.flow == null) {
        await _ref.read(periodHistoryProvider.notifier).removePeriodEntry(existingAnchor.id);
      }
    }

    await _syncActiveCycleBleedDuration(finalEntry.date);
    _recomputePeriodLength();
    CloudGroundTruthService.syncAll();
  }

  Future<void> deleteEntry(String id) async {
    final entry = state.where((e) => e.id == id).firstOrNull;
    await StorageService.deleteLogEntry(id);
    state = state.where((e) => e.id != id).toList();
    if (entry != null && entry.periodStarted && entry.flow == null) {
      final history = _ref.read(periodHistoryProvider);
      final normDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final anchor = history.where((p) =>
          p.startDate.year == normDate.year &&
          p.startDate.month == normDate.month &&
          p.startDate.day == normDate.day).firstOrNull;
      if (anchor != null) {
        await _ref.read(periodHistoryProvider.notifier).removePeriodEntry(anchor.id);
      }
    }
    if (entry != null) {
      await _syncActiveCycleBleedDuration(entry.date);
    }
    _recomputePeriodLength();
    CloudGroundTruthService.syncAll();
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

    final history = _ref.read(periodHistoryProvider);
    final anchor = history.where((p) =>
        p.startDate.year == today.year &&
        p.startDate.month == today.month &&
        p.startDate.day == today.day).firstOrNull;
    if (anchor != null) {
      await _ref.read(periodHistoryProvider.notifier).removePeriodEntry(anchor.id);
    }

    await _syncActiveCycleBleedDuration(today);
    _recomputePeriodLength();
    CloudGroundTruthService.syncAll();
  }

  /// Restores a previous snapshot of LogEntry for a specific date (Universal Undo).
  Future<void> restoreSnapshot(DateTime date, LogEntry? previousEntry) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final index = state.indexWhere((e) =>
        e.date.year == normDate.year &&
        e.date.month == normDate.month &&
        e.date.day == normDate.day);

    if (previousEntry == null) {
      if (index != -1) {
        final existingId = state[index].id;
        await StorageService.deleteLogEntry(existingId);
        final updatedList = [...state]..removeAt(index);
        state = updatedList;
      }
    } else {
      await StorageService.saveLogEntry(previousEntry);
      if (index != -1) {
        final updatedList = [...state];
        updatedList[index] = previousEntry;
        state = updatedList;
      } else {
        state = [previousEntry, ...state];
      }
    }
    await _syncActiveCycleBleedDuration(normDate);
    _recomputePeriodLength();
    CloudGroundTruthService.syncAll();
  }

  /// Dynamically synchronizes active cycle bleed duration when flow is logged on extended days.
  /// If user logs flow on Day 6 (when baseline is 5), the cycle bleed duration extends to Day 6.
  /// If flow is subsequently removed, it safely resets so the cycle ends naturally at baseline.
  Future<void> _syncActiveCycleBleedDuration(DateTime date) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final history = _ref.read(periodHistoryProvider);
    final cycle = history.where((p) {
      final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
      final diff = normDate.difference(pNorm).inDays;
      return diff >= 0 && diff < 14;
    }).firstOrNull;
    if (cycle == null || cycle.endDate != null) return;

    final cycleStart = DateTime(cycle.startDate.year, cycle.startDate.month, cycle.startDate.day);
    final profile = _ref.read(profileProvider);
    final baselinePeriod = profile?.averagePeriodLength ?? 5;

    // Collect all dates with active flow within this cycle 14-day window
    final flowDays = state.where((e) {
      final eNorm = DateTime(e.date.year, e.date.month, e.date.day);
      final diff = eNorm.difference(cycleStart).inDays;
      return diff >= 0 && diff < 14 && e.flow != null;
    }).map((e) {
      final eNorm = DateTime(e.date.year, e.date.month, e.date.day);
      return eNorm.difference(cycleStart).inDays + 1;
    }).toList();

    final maxFlowDay = flowDays.isNotEmpty ? flowDays.reduce((a, b) => a > b ? a : b) : null;

    if (maxFlowDay != null && maxFlowDay > baselinePeriod) {
      if (cycle.bleedDurationDays != maxFlowDay) {
        final updated = cycle.copyWith(
          bleedDurationDays: maxFlowDay,
          isUserSpecifiedDuration: true,
        );
        await StorageService.savePeriodEntry(updated);
        await _ref.read(periodHistoryProvider.notifier).refresh();
      }
    } else if (cycle.isUserSpecifiedDuration && cycle.endDate == null) {
      final updated = cycle.copyWith(
        clearBleedDuration: true,
        isUserSpecifiedDuration: false,
      );
      await StorageService.savePeriodEntry(updated);
      await _ref.read(periodHistoryProvider.notifier).refresh();
    }
  }

  /// Clinically guarded period length calibration:
  /// 1. Excludes bleeding from the current active cycle (ongoing bleeds must NEVER shrink period length).
  /// 2. Requires at least 2 completed historical cycles before calibrating baseline.
  /// 3. Treats single 1-2 day or 9+ day bleeds as individual anomalies, protecting baseline rhythm.
  /// 4. Floor is strictly 3 days (normal physiological lower bound).
  void _recomputePeriodLength() {
    final history = _ref.read(periodHistoryProvider);
    final latestAnchor = history.isNotEmpty ? history.first.startDate : null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final completedBleedingDays = state.where((e) {
      final isBleed = e.flow != null || e.periodStarted || e.symptoms.contains('Period');
      if (!isBleed) return false;

      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (latestAnchor != null) {
        final diffFromAnchor = d.difference(latestAnchor).inDays;
        if (diffFromAnchor >= 0 && diffFromAnchor < 14) {
          // Belongs to the active ongoing cycle - bleed is not finished!
          return false;
        }
      }
      if (today.difference(d).inDays < 14) {
        // Within current 14-day window: in progress!
        return false;
      }
      return true;
    }).toList();

    if (completedBleedingDays.isEmpty) return;

    final sortedDates = completedBleedingDays
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
        currentRunLength += 1;
      } else {
        runs.add(currentRunLength);
        currentRunLength = 1;
      }
    }
    runs.add(currentRunLength);

    // Require at least 2 completed cycles to calibrate baseline
    if (runs.length < 2) return;

    // Filter out acute anomalies (normal physiological window: 3 to 8 days)
    final physiologicalRuns = runs.where((r) => r >= 3 && r <= 8).toList();
    if (physiologicalRuns.length < 2) return;

    final avgPeriod = (physiologicalRuns.reduce((a, b) => a + b) / physiologicalRuns.length).round().clamp(3, 8);
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
