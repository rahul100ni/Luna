import 'dart:convert';
import 'package:http/http.dart' as http;

class TokenMetrics {
  final int todayTokens;
  final int weekTokens;
  final int totalTokens;
  final int todayRequests;
  final int totalRequests;
  final double estimatedCostUsd;

  const TokenMetrics({
    required this.todayTokens,
    required this.weekTokens,
    required this.totalTokens,
    required this.todayRequests,
    required this.totalRequests,
    required this.estimatedCostUsd,
  });

  factory TokenMetrics.empty() => const TokenMetrics(
        todayTokens: 0,
        weekTokens: 0,
        totalTokens: 0,
        todayRequests: 0,
        totalRequests: 0,
        estimatedCostUsd: 0.0,
      );
}

class TelemetryService {
  static const String _rtdbBase =
      'https://luna-8ce40-default-rtdb.asia-southeast1.firebasedatabase.app/luna';

  static String get _todayStr {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Discreetly reports token usage for an AI interaction to Firebase Realtime Database.
  /// Runs asynchronously in fire-and-forget mode so it never blocks or interrupts the user.
  static void reportTokenUsage({
    required int tokens,
    int promptTokens = 0,
    int completionTokens = 0,
    String feature = 'ai',
  }) {
    if (tokens <= 0) return;

    // Fire and forget — never awaits on UI thread
    () async {
      try {
        final now = DateTime.now();
        final body = jsonEncode({
          'date': _todayStr,
          'timestamp': now.millisecondsSinceEpoch,
          'tokens': tokens,
          'promptTokens': promptTokens,
          'completionTokens': completionTokens,
          'feature': feature,
        });

        await http
            .post(
              Uri.parse('$_rtdbBase/telemetry/events.json'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Silently ignore telemetry network glitches — never disturb the user
      }
    }();
  }

  /// Fetches aggregate token telemetry across all devices for the Admin Dashboard.
  static Future<TokenMetrics> fetchTokenMetrics() async {
    try {
      final res = await http
          .get(Uri.parse('$_rtdbBase/telemetry/events.json'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') {
        return TokenMetrics.empty();
      }

      final data = jsonDecode(res.body);
      if (data is! Map) return TokenMetrics.empty();

      final now = DateTime.now();
      final todayKey = _todayStr;
      final weekAgoMs = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

      int todayTokens = 0;
      int weekTokens = 0;
      int totalTokens = 0;
      int todayRequests = 0;
      int totalRequests = 0;

      data.forEach((_, value) {
        if (value is Map) {
          final tokens = (value['tokens'] as num?)?.toInt() ?? 0;
          final date = value['date'] as String? ?? '';
          final ts = (value['timestamp'] as num?)?.toInt() ?? 0;

          totalTokens += tokens;
          totalRequests++;

          if (date == todayKey) {
            todayTokens += tokens;
            todayRequests++;
          }

          if (ts >= weekAgoMs) {
            weekTokens += tokens;
          }
        }
      });

      // DeepSeek V3 blended rate: ~$0.20 per 1M tokens ($0.14 prompt + $0.28 completion)
      final estimatedCost = (totalTokens / 1000000.0) * 0.20;

      return TokenMetrics(
        todayTokens: todayTokens,
        weekTokens: weekTokens,
        totalTokens: totalTokens,
        todayRequests: todayRequests,
        totalRequests: totalRequests,
        estimatedCostUsd: estimatedCost,
      );
    } catch (_) {
      return TokenMetrics.empty();
    }
  }

  /// Updates the remote DeepSeek API key stored in Firebase Realtime Database
  /// so all distributed devices automatically receive and use it.
  static Future<bool> updateRemoteApiKey(String newKey) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_rtdbBase/config/apiKey.json'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(newKey.trim()),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the remote DeepSeek API key from Firebase Realtime Database.
  static Future<String?> fetchRemoteApiKey() async {
    try {
      final res = await http
          .get(Uri.parse('$_rtdbBase/config/apiKey.json'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final key = jsonDecode(res.body);
        if (key is String && key.trim().isNotEmpty) {
          return key.trim();
        }
      }
    } catch (_) {
      // Offline / network failure
    }
    return null;
  }
}
