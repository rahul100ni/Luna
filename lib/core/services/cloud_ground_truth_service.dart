import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import '../models/period_entry.dart';
import '../models/luna_memory_entry.dart';
import 'storage_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final DateTime? timestamp;

  const SyncResult({
    required this.success,
    required this.message,
    this.timestamp,
  });
}

class RestoreResult {
  final bool success;
  final String message;
  final int cyclesRestored;
  final int logsRestored;
  final int memoriesRestored;
  final UserProfile? restoredProfile;

  const RestoreResult({
    required this.success,
    required this.message,
    this.cyclesRestored = 0,
    this.logsRestored = 0,
    this.memoriesRestored = 0,
    this.restoredProfile,
  });
}

/// Two-Tier Cloud Ground-Truth and Full Companion State Synchronization
///
/// Tier 1: absolute_ground_truth (sacred user-entered period dates, bleed durations,
/// manual baseline inputs, logged symptoms/biomarkers, audit trail; never touched by AI guesses).
///
/// Tier 2: full_companion_snapshot (complete companion state, memories, pattern intelligence,
/// user profile) allowing seamless device switching so a user can continue on another device.
class CloudGroundTruthService {
  static const String _firebaseBaseUrl =
      'https://luna-8ce40-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Sanitizes user ID, email, or sync key for safe Firebase Realtime Database path usage.
  /// Firebase paths forbid: ., $, #, [, ], /
  static String sanitizeAccountKey(String rawInput) {
    final trimmed = rawInput.trim().toLowerCase();
    if (trimmed.isEmpty) return 'anonymous_vault';
    return trimmed
        .replaceAll('@', '_at_')
        .replaceAll('.', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  /// Gets or generates the active sync ID for this device
  static String getOrCreateSyncId() {
    final stored = StorageService.getCloudSyncId();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final profile = StorageService.getProfile();
    final generated = profile != null && profile.id.isNotEmpty
        ? 'luna_${profile.id}'
        : 'luna_${const Uuid().v4().substring(0, 8)}';
    StorageService.setCloudSyncId(generated);
    return generated;
  }

  /// Pushes both Tier 1 Ground-Truth and Tier 2 Full Companion Snapshot to Firebase.
  /// Non-blocking, safe against offline states or server errors.
  static Future<SyncResult> syncAll({String? explicitSyncId}) async {
    try {
      final syncId = explicitSyncId ?? getOrCreateSyncId();
      final sanitizedKey = sanitizeAccountKey(syncId);
      final profile = StorageService.getProfile();
      final periodHistory = await StorageService.getPeriodHistory();
      final logEntries = await StorageService.getLogEntries(limit: 365);
      final memories = await StorageService.getMemories(limit: 100);
      final now = DateTime.now();

      // Tier 1: Absolute Ground Truth (strictly user-entered / verified data)
      final absoluteGroundTruth = {
        'period_history': periodHistory.map((p) => p.toMap()).toList(),
        'log_entries': logEntries.map((l) => l.toMap()).toList(),
        'baseline': {
          'average_cycle_length': profile?.averageCycleLength ?? 28,
          'average_period_length': profile?.averagePeriodLength ?? 5,
          'is_cycle_length_unknown': StorageService.isCycleLengthUnknown(),
          'is_period_length_unknown': StorageService.isPeriodLengthUnknown(),
          'diet_preference': StorageService.dietPreference,
        },
        'audit_trail': [
          {
            'timestamp': now.toIso8601String(),
            'event': 'cloud_sync',
            'periods_count': periodHistory.length,
            'logs_count': logEntries.length,
          }
        ],
        'last_synced_at': now.toIso8601String(),
      };

      // Tier 2: Full Companion Snapshot (complete state for multi-device switching)
      final fullCompanionSnapshot = {
        'profile': profile?.toMap(),
        'memories': memories.map((m) => m.toMap()).toList(),
        'settings': {
          'onboarding_complete': StorageService.onboardingComplete,
          'diet_preference': StorageService.dietPreference,
        },
        'chat_session': StorageService.getLastChatSession(),
        'snapshot_at': now.toIso8601String(),
      };

      final payload = {
        'account_key': sanitizedKey,
        'display_id': syncId,
        'updated_at': now.toIso8601String(),
        'schema_version': 5,
        'absolute_ground_truth': absoluteGroundTruth,
        'full_companion_snapshot': fullCompanionSnapshot,
      };

      final url = Uri.parse('$_firebaseBaseUrl/luna/users/$sanitizedKey.json');
      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await StorageService.setCloudSyncId(syncId);
        await StorageService.setLastCloudSyncTime(now);
        return SyncResult(
          success: true,
          message: 'Saved securely to Cloud Vault',
          timestamp: now,
        );
      } else {
        return SyncResult(
          success: false,
          message: 'Cloud sync failed with code ${response.statusCode}',
        );
      }
    } catch (e) {
      return const SyncResult(
        success: false,
        message: 'Cloud sync unavailable (offline)',
      );
    }
  }

  /// Restores ground-truth and companion snapshot from Cloud Vault.
  /// Populates SQLite tables and SharedPreferences.
  static Future<RestoreResult> restoreFromCloud(String rawSyncId) async {
    try {
      final sanitizedKey = sanitizeAccountKey(rawSyncId);
      final url = Uri.parse('$_firebaseBaseUrl/luna/users/$sanitizedKey.json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RestoreResult(
          success: false,
          message: 'Could not fetch cloud vault (Status ${response.statusCode})',
        );
      }

      if (response.body.isEmpty || response.body == 'null') {
        return const RestoreResult(
          success: false,
          message: 'No cloud vault found for this ID or email.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final absolute = data['absolute_ground_truth'] as Map<String, dynamic>?;
      final snapshot = data['full_companion_snapshot'] as Map<String, dynamic>?;

      int cyclesRestored = 0;
      int logsRestored = 0;
      int memoriesRestored = 0;
      UserProfile? restoredProfile;

      // 1. Restore Profile from snapshot or fallback
      if (snapshot != null && snapshot['profile'] != null) {
        try {
          final profileMap = Map<String, dynamic>.from(snapshot['profile'] as Map);
          restoredProfile = UserProfile.fromMap(profileMap);
          await StorageService.saveProfile(restoredProfile);
        } catch (_) {}
      }

      // 2. Restore Period History (Tier 1)
      if (absolute != null && absolute['period_history'] is List) {
        final periodList = absolute['period_history'] as List<dynamic>;
        for (final item in periodList) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            final entry = PeriodEntry.fromMap(map);
            await StorageService.savePeriodEntry(entry);
            cyclesRestored++;
          } catch (_) {}
        }
      }

      // 3. Restore Log Entries (Tier 1)
      if (absolute != null && absolute['log_entries'] is List) {
        final logList = absolute['log_entries'] as List<dynamic>;
        for (final item in logList) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            final entry = LogEntry.fromMap(map);
            await StorageService.saveLogEntry(entry);
            logsRestored++;
          } catch (_) {}
        }
      }

      // 4. Restore Memories (Tier 2)
      if (snapshot != null && snapshot['memories'] is List) {
        final memList = snapshot['memories'] as List<dynamic>;
        for (final item in memList) {
          try {
            final map = Map<String, dynamic>.from(item as Map);
            final memory = LunaMemoryEntry.fromMap(map);
            await StorageService.saveMemory(memory);
            memoriesRestored++;
          } catch (_) {}
        }
      }

      // 5. Restore Settings
      if (snapshot != null && snapshot['settings'] is Map) {
        final settings = snapshot['settings'] as Map<String, dynamic>;
        if (settings['onboarding_complete'] == true) {
          await StorageService.setOnboardingComplete();
        }
        if (settings['diet_preference'] is String) {
          await StorageService.setDietPreference(settings['diet_preference'] as String);
        }
      }

      // 6. Restore Chat Session
      if (snapshot != null && snapshot['chat_session'] is List) {
        final chatList = (snapshot['chat_session'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await StorageService.saveLastChatSession(chatList);
      }

      // 7. Store confirmed sync ID and update last sync timestamp
      await StorageService.setCloudSyncId(rawSyncId);
      await StorageService.setLastCloudSyncTime(DateTime.now());

      return RestoreResult(
        success: true,
        message: 'Successfully restored all data from Cloud Vault',
        cyclesRestored: cyclesRestored,
        logsRestored: logsRestored,
        memoriesRestored: memoriesRestored,
        restoredProfile: restoredProfile,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'Error during cloud restoration: $e',
      );
    }
  }

  /// Irreversibly wipes the user's cloud vault from Firebase Realtime Database
  static Future<bool> wipeCloudData(String rawSyncId) async {
    try {
      final sanitizedKey = sanitizeAccountKey(rawSyncId);
      final url = Uri.parse('$_firebaseBaseUrl/luna/users/$sanitizedKey.json');
      final response = await http.delete(url).timeout(const Duration(seconds: 10));
      await StorageService.clearCloudSyncId();
      await StorageService.clearLastCloudSyncTime();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
