import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/log_entry.dart';

class StorageService {
  static Database? _db;
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final dbPath = path.join(await getDatabasesPath(), 'luna.db');
      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE log_entries (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              mood INTEGER NOT NULL,
              energyLevel INTEGER NOT NULL,
              flow INTEGER,
              cramps INTEGER,
              symptoms TEXT,
              notes TEXT,
              periodStarted INTEGER DEFAULT 0
            )
          ''');
        },
      );
    } catch (_) {
      // Database factory not available (e.g. host unit testing environment)
    }
  }

  // ── User Profile ──────────────────────────────────────────────────
  static Future<void> saveProfile(UserProfile profile) async {
    await _prefs!.setString('user_profile', jsonEncode(profile.toMap()));
  }

  static UserProfile? getProfile() {
    final json = _prefs!.getString('user_profile');
    if (json == null) return null;
    return UserProfile.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  static Future<void> clearProfile() async {
    await _prefs!.remove('user_profile');
  }

  // ── Log Entries ───────────────────────────────────────────────────
  static Future<void> saveLogEntry(LogEntry entry) async {
    await _db!.insert(
      'log_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<LogEntry>> getLogEntries({int limit = 90}) async {
    final maps = await _db!.query(
      'log_entries',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map(LogEntry.fromMap).toList();
  }

  static Future<LogEntry?> getLogForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final maps = await _db!.query(
      'log_entries',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LogEntry.fromMap(maps.first);
  }

  // ── Settings ──────────────────────────────────────────────────────
  static bool get onboardingComplete =>
      _prefs!.getBool('onboarding_complete') ?? false;

  static Future<void> setOnboardingComplete() async {
    await _prefs!.setBool('onboarding_complete', true);
  }

  static int get slotMachineSpinsToday =>
      _prefs!.getInt('slot_spins_$_todayKey') ?? 0;

  static Future<void> incrementSlotSpins() async {
    final key = 'slot_spins_$_todayKey';
    await _prefs!.setInt(key, (_prefs!.getInt(key) ?? 0) + 1);
  }

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  // ── Diet Preference ────────────────────────────────────────────────
  static String get dietPreference =>
      _prefs!.getString('diet_preference') ?? 'veg';

  static Future<void> setDietPreference(String preference) async {
    await _prefs!.setString('diet_preference', preference);
  }

  // ── Daily Prescription Cache ──────────────────────────────────────
  static String? getCachedDailyPrescription(String key) {
    return _prefs!.getString('prescription_$key');
  }

  static Future<void> cacheDailyPrescription(String key, String jsonStr) async {
    await _prefs!.setString('prescription_$key', jsonStr);
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
}
