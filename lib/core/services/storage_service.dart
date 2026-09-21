import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';
import '../models/period_entry.dart';
import '../models/luna_memory_entry.dart';

class StorageService {
  static Database? _db;
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final dbPath = path.join(await getDatabasesPath(), 'luna.db');
      _db = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE log_entries (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              mood INTEGER,
              energyLevel INTEGER,
              sleepQuality INTEGER,
              flow INTEGER,
              cramps INTEGER,
              symptoms TEXT,
              notes TEXT,
              periodStarted INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE period_history (
              id TEXT PRIMARY KEY,
              start_date TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT 'logged'
            )
          ''');
          await db.execute('''
            CREATE TABLE luna_memories (
              id TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at TEXT NOT NULL,
              last_surfaced TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE log_entries ADD COLUMN sleepQuality INTEGER',
            );
          }
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS period_history (
                id TEXT PRIMARY KEY,
                start_date TEXT NOT NULL,
                source TEXT NOT NULL DEFAULT 'logged'
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS luna_memories (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                last_surfaced TEXT
              )
            ''');
          }
        },
      );
      if (_db != null) {
        // Automatic cleanup of any duplicate period entries stored on the same date
        try {
          await _db!.execute('''
            DELETE FROM period_history WHERE rowid NOT IN (
              SELECT min(rowid) FROM period_history GROUP BY substr(start_date, 1, 10)
            )
          ''');
        } catch (_) {}
      }
    } catch (e) {
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
    try {
      await _db!.insert(
        'log_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
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

  static Future<void> deleteLogEntry(String id) async {
    if (_db == null) return;
    try {
      await _db!.delete(
        'log_entries',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  // ── Clear All Data (full reset to factory) ─────────────────────────
  static Future<void> clearAllData() async {
    // 1. Wipe SQLite tables
    if (_db != null) {
      try {
        await _db!.delete('log_entries');
        await _db!.delete('period_history');
        await _db!.delete('luna_memories');
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

  // ── Period History ─────────────────────────────────────────────────
  /// Saves a period start entry. Idempotent by calendar day: if another entry
  /// already exists for this date (YYYY-MM-DD), it deletes the duplicate and replaces
  /// this entry with its normalized start date.
  static Future<void> savePeriodEntry(PeriodEntry entry) async {
    if (_db == null) return;
    try {
      final normDate = DateTime(entry.startDate.year, entry.startDate.month, entry.startDate.day);
      final datePrefix = '${normDate.year.toString().padLeft(4, '0')}-${normDate.month.toString().padLeft(2, '0')}-${normDate.day.toString().padLeft(2, '0')}';

      // Remove any conflicting entry for this same calendar day with a different ID
      await _db!.delete(
        'period_history',
        where: 'id != ? AND start_date LIKE ?',
        whereArgs: [entry.id, '$datePrefix%'],
      );

      // Save/update this entry with primary key ID
      await _db!.insert(
        'period_history',
        {
          'id': entry.id,
          'start_date': normDate.toIso8601String(),
          'source': entry.source,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Returns all period history entries sorted newest first, deduplicated by calendar day.
  static Future<List<PeriodEntry>> getPeriodHistory() async {
    if (_db == null) return [];
    try {
      final maps = await _db!.query('period_history', orderBy: 'start_date DESC');
      final seenDates = <String>{};
      final uniqueEntries = <PeriodEntry>[];
      for (final map in maps) {
        final entry = PeriodEntry.fromMap(map);
        final dateKey = '${entry.startDate.year}-${entry.startDate.month}-${entry.startDate.day}';
        if (seenDates.add(dateKey)) {
          uniqueEntries.add(entry);
        }
      }
      uniqueEntries.sort((a, b) => b.startDate.compareTo(a.startDate));
      return uniqueEntries;
    } catch (_) {
      return [];
    }
  }

  static Future<void> deletePeriodEntry(String id) async {
    if (_db == null) return;
    try {
      await _db!.delete('period_history', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<void> clearPeriodHistory() async {
    if (_db == null) return;
    try {
      await _db!.delete('period_history');
    } catch (_) {}
  }

  // ── Cycle Calibration State ─────────────────────────────────────────
  static bool isCycleLengthUnknown() {
    return _prefs?.getBool('cycle_length_unknown') ?? false;
  }

  static Future<void> setCycleLengthCalibrated() async {
    await _prefs?.setBool('cycle_length_unknown', false);
  }

  static bool isPeriodLengthUnknown() {
    return _prefs?.getBool('period_length_unknown') ?? false;
  }

  static Future<void> setPeriodLengthCalibrated() async {
    await _prefs?.setBool('period_length_unknown', false);
  }

  // ── Luna Intimate Memory (VISION Pillar One) ───────────────────────
  static Future<void> saveMemory(LunaMemoryEntry memory) async {
    if (_db == null) return;
    try {
      await _db!.insert(
        'luna_memories',
        memory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<List<LunaMemoryEntry>> getMemories({int limit = 40}) async {
    if (_db == null) return [];
    try {
      final maps = await _db!.query(
        'luna_memories',
        orderBy: 'created_at DESC',
        limit: limit,
      );
      return maps.map(LunaMemoryEntry.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteMemory(String id) async {
    if (_db == null) return;
    try {
      await _db!.delete('luna_memories', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<void> clearMemories() async {
    if (_db == null) return;
    try {
      await _db!.delete('luna_memories');
    } catch (_) {}
  }
}
