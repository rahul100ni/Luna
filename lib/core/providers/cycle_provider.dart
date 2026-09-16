import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import '../services/storage_service.dart';
import '../services/cycle_engine.dart';
import '../services/notification_service.dart';
import '../services/pattern_analysis_service.dart';
import '../constants/phase_constants.dart';

// ── Profile Provider ─────────────────────────────────────────────────────────
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

  Future<void> updateLastPeriod(DateTime? date) async {
    if (state == null) return;
    final updated = date == null
        ? state!.copyWith(clearLastPeriod: true)
        : state!.copyWith(lastPeriodStart: date);
    await StorageService.saveProfile(updated);
    state = updated;
    final cycleState = CycleEngine.calculate(updated);
    NotificationService.schedulePhaseNotifications(cycleState);
  }

  Future<void> clear() async {
    await StorageService.clearProfile();
    state = null;
  }
}

// ── Cycle State Provider ──────────────────────────────────────────────────────
final cycleStateProvider = Provider<CycleState?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  return CycleEngine.calculate(profile);
});

// ── Current Phase Provider ────────────────────────────────────────────────────
final currentPhaseProvider = Provider<CyclePhase>((ref) {
  final cycleState = ref.watch(cycleStateProvider);
  return cycleState?.phase ?? CyclePhase.follicular;
});

// ── Log Entries Provider ──────────────────────────────────────────────────────
final logEntriesProvider =
    StateNotifierProvider<LogEntriesNotifier, List<LogEntry>>((_) {
  return LogEntriesNotifier();
});

class LogEntriesNotifier extends StateNotifier<List<LogEntry>> {
  LogEntriesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await StorageService.getLogEntries();
  }

  Future<void> addEntry(LogEntry entry) async {
    await StorageService.saveLogEntry(entry);
    state = [entry, ...state.where((e) => e.id != entry.id)];
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

// ── Today Log Provider — drives home screen badge ─────────────────────────────
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

// ── Longitudinal Pattern Intelligence Provider ────────────────────────────────
final patternProfileProvider = Provider<LongitudinalProfile>((ref) {
  final logs = ref.watch(logEntriesProvider);
  final profile = ref.watch(profileProvider);
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
    );
  }
  return PatternAnalysisService.analyze(logs: logs, profile: profile);
});
