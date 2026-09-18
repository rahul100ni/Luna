import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import 'telemetry_service.dart';

class StorageService {
  static Database? _db;
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final dbPath = path.join(await getDatabasesPath(), 'luna.db');
      _db = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE log_entries (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              mood INTEGER NOT NULL,
              energyLevel INTEGER,
              sleepQuality INTEGER,
              flow INTEGER,
              cramps INTEGER,
              symptoms TEXT,
              notes TEXT,
              periodStarted INTEGER DEFAULT 0
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE log_entries ADD COLUMN sleepQuality INTEGER',
            );
          }
        },
      );
    } catch (e) {
      // DB unavailable — app degrades gracefully to offline/prefs-only mode
      _db = null;
    }
  }

  // ── User Profile ──────────────────────────────────────────────────
  static Future<void> saveProfile(UserProfile profile) async {
    await _prefs?.setString('user_profile', jsonEncode(profile.toMap()));
  }

  static UserProfile? getProfile() {
    final json = _prefs?.getString('user_profile');
    if (json == null) return null;
    try {
      return UserProfile.fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    await _prefs?.remove('user_profile');
  }

  // ── Log Entries ───────────────────────────────────────────────────
  static Future<void> saveLogEntry(LogEntry entry) async {
    if (_db == null) return; // graceful degradation — no crash
    await _db!.insert(
      'log_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<LogEntry>> getLogEntries({int limit = 90}) async {
    if (_db == null) return []; // graceful degradation
    try {
      final maps = await _db!.query(
        'log_entries',
        orderBy: 'date DESC',
        limit: limit,
      );
      return maps.map(LogEntry.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<LogEntry?> getLogForDate(DateTime date) async {
    if (_db == null) return null;
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final maps = await _db!.query(
        'log_entries',
        where: 'date LIKE ?',
        whereArgs: ['$dateStr%'],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return LogEntry.fromMap(maps.first);
    } catch (_) {
      return null;
    }
  }

  // ── Clear All Data (full reset to factory) ─────────────────────────
  static Future<void> clearAllData() async {
    // 1. Wipe SQLite log entries
    if (_db != null) {
      try {
        await _db!.delete('log_entries');
      } catch (_) {}
    }
    // 2. Wipe all SharedPreferences (profile, settings, cache, API key, etc.)
    await _prefs?.clear();
  }

  // ── Settings ──────────────────────────────────────────────────────
  static bool get onboardingComplete =>
      _prefs?.getBool('onboarding_complete') ?? false;

  static Future<void> setOnboardingComplete() async {
    await _prefs?.setBool('onboarding_complete', true);
  }

  static int get slotMachineSpinsToday =>
      _prefs?.getInt('slot_spins_$_todayKey') ?? 0;

  static Future<void> incrementSlotSpins() async {
    final key = 'slot_spins_$_todayKey';
    await _prefs?.setInt(key, (_prefs?.getInt(key) ?? 0) + 1);
  }

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  // ── Diet Preference ────────────────────────────────────────────────
  static String get dietPreference =>
      _prefs?.getString('diet_preference') ?? 'veg';

  static Future<void> setDietPreference(String preference) async {
    await _prefs?.setString('diet_preference', preference);
  }

  // ── Daily Prescription Cache ──────────────────────────────────────
  static String? getCachedDailyPrescription(String key) {
    return _prefs?.getString('prescription_$key');
  }

  static Future<void> cacheDailyPrescription(String key, String jsonStr) async {
    await _prefs?.setString('prescription_$key', jsonStr);
  }

  // ── AI API Key & Budget Protection ────────────────────────────────
  static const int maxDailyAiRequests = 25;

  static String? getDeepSeekApiKey() {
    return _prefs?.getString('deepseek_api_key');
  }

  static Future<void> setDeepSeekApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _prefs?.remove('deepseek_api_key');
    } else {
      await _prefs?.setString('deepseek_api_key', trimmed);
    }
  }

  static int get dailyAiRequestCount {
    final key = 'ai_req_count_$_todayKey';
    return _prefs?.getInt(key) ?? 0;
  }

  static bool get canMakeAiRequest {
    return dailyAiRequestCount < maxDailyAiRequests;
  }

  static Future<void> incrementAiRequestCount() async {
    final key = 'ai_req_count_$_todayKey';
    final current = _prefs?.getInt(key) ?? 0;
    await _prefs?.setInt(key, current + 1);
  }

  // ── Generic AI Response Cache ──────────────────────────────────────
  static String? getCachedAiResponse(String cacheKey) {
    return _prefs?.getString('ai_cache_${_todayKey}_$cacheKey');
  }

  static Future<void> cacheAiResponse(String cacheKey, String response) async {
    await _prefs?.setString('ai_cache_${_todayKey}_$cacheKey', response);
  }

  // ── Chat Session Persistence (Bug 10) ─────────────────────────────
  /// Saves the last Luna AI chat session (up to last 30 messages) so
  /// the conversation survives navigation away and app restarts.
  static Future<void> saveLastChatSession(
      List<Map<String, dynamic>> messages) async {
    final trimmed = messages.length > 30
        ? messages.sublist(messages.length - 30)
        : messages;
    await _prefs?.setString('last_chat_session', jsonEncode(trimmed));
  }

  static List<Map<String, dynamic>> getLastChatSession() {
    final json = _prefs?.getString('last_chat_session');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearLastChatSession() async {
    await _prefs?.remove('last_chat_session');
  }

  // ── Remote AI Persona Cache ───────────────────────────────────────
  static Future<void> saveAiPersona(AiPersonaConfig config) async {
    await _prefs?.setString('cached_ai_persona', jsonEncode(config.toMap()));
  }

  static AiPersonaConfig getAiPersona() {
    final jsonStr = _prefs?.getString('cached_ai_persona');
    if (jsonStr == null) return AiPersonaConfig.defaultConfig();
    try {
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        return AiPersonaConfig.fromMap(map);
      } else if (map is Map) {
        return AiPersonaConfig.fromMap(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return AiPersonaConfig.defaultConfig();
  }
}
