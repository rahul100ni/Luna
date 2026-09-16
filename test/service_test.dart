import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luna_app/core/constants/phase_constants.dart';
import 'package:luna_app/core/models/log_entry.dart';
import 'package:luna_app/core/models/user_profile.dart';
import 'package:luna_app/core/services/deepseek_service.dart';
import 'package:luna_app/core/services/storage_service.dart';
import 'package:luna_app/core/services/pattern_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('DeepSeekService offline fallback & security tests', () {
    test('Default state has no API key', () {
      expect(DeepSeekService.hasApiKey, isFalse);
      expect(DeepSeekService.apiKey, isEmpty);
    });

    test('getMoodResponse returns smart fallback when no API key is set', () async {
      final response = await DeepSeekService.getMoodResponse(
        userName: 'TestUser',
        hasCycleAnchor: true,
        phase: CyclePhase.follicular,
        dayOfCycle: 8,
        cycleLength: 28,
        mood: MoodLevel.good,
      );

      expect(response.isError, isFalse);
      expect(response.validation, isNotEmpty);
      expect(response.actions, isNotEmpty);
      expect(response.science, isNotEmpty);
    });

    test('getDailyPrescription returns smart fallback when no API key is set', () async {
      final prescription = await DeepSeekService.getDailyPrescription(
        userName: 'TestUser',
        hasCycleAnchor: true,
        phase: CyclePhase.menstrual,
        dayOfCycle: 2,
        cycleLength: 28,
      );

      expect(prescription.isFallback, isTrue);
      expect(prescription.headline, isNotEmpty);
      expect(prescription.biologicalBrief, isNotEmpty);
      expect(prescription.somaticReset, isNotEmpty);
    });

    test('getCycleNutritionAdvice returns smart fallback when no API key is set', () async {
      final diet = await DeepSeekService.getCycleNutritionAdvice(
        userName: 'TestUser',
        dietType: 'veg',
        cravingVibe: 'sweet_treat',
        phase: CyclePhase.lateLuteal,
        hasCycleAnchor: true,
        dayOfCycle: 26,
        cycleLength: 28,
      );

      expect(diet.isFallback, isTrue);
      expect(diet.phaseContext, isNotEmpty);
      expect(diet.beneficial, isNotEmpty);
      expect(diet.mustAvoid, isNotEmpty);
    });

    test('setApiKey persists and retrieves properly', () {
      DeepSeekService.setApiKey('sk-test-custom-key-12345');
      expect(DeepSeekService.hasApiKey, isTrue);
      expect(DeepSeekService.apiKey, equals('sk-test-custom-key-12345'));

      // Remove key
      DeepSeekService.setApiKey('');
      expect(DeepSeekService.hasApiKey, isFalse);
      expect(DeepSeekService.apiKey, isEmpty);
    });
  });

  group('Longitudinal Pattern Intelligence Tests', () {
    test('Empty logs return baseline empty profile', () {
      final profile = PatternAnalysisService.analyze(
        logs: [],
        profile: UserProfile(
          id: 'u1',
          name: 'LunaUser',
          averageCycleLength: 28,
          averagePeriodLength: 5,
          createdAt: DateTime.now(),
        ),
      );

      expect(profile.totalLogsAnalyzed, equals(0));
      expect(profile.hasSufficientData, isFalse);
      expect(profile.patterns, isEmpty);
    });

    test('Discovers late-luteal energy trough from historical data', () {
      final now = DateTime.now();
      final anchor = now.subtract(const Duration(days: 28));
      final logs = <LogEntry>[
        // Follicular logs (high energy)
        LogEntry(
          id: 'l1',
          date: anchor.add(const Duration(days: 8)),
          mood: MoodLevel.thriving,
          energyLevel: 5,
          symptoms: [],
        ),
        LogEntry(
          id: 'l2',
          date: anchor.add(const Duration(days: 10)),
          mood: MoodLevel.good,
          energyLevel: 4,
          symptoms: [],
        ),
        // Late luteal logs (low energy trough)
        LogEntry(
          id: 'l3',
          date: anchor.add(const Duration(days: 24)),
          mood: MoodLevel.struggling,
          energyLevel: 1,
          symptoms: ['Fatigue', 'Brain fog'],
        ),
        LogEntry(
          id: 'l4',
          date: anchor.add(const Duration(days: 25)),
          mood: MoodLevel.low,
          energyLevel: 2,
          symptoms: ['Fatigue', 'Anxious'],
        ),
      ];

      final profile = PatternAnalysisService.analyze(
        logs: logs,
        profile: UserProfile(
          id: 'u1',
          name: 'LunaUser',
          averageCycleLength: 28,
          averagePeriodLength: 5,
          lastPeriodStart: anchor,
          createdAt: anchor,
        ),
      );

      expect(profile.totalLogsAnalyzed, equals(4));
      expect(profile.hasSufficientData, isTrue);
      expect(profile.patterns.any((p) => p.id == 'luteal_energy_trough'), isTrue);
      expect(profile.aiContextDigest, contains('Late-Luteal Energy Trough'));
    });
  });

  group('Quota & Rate Limiting Tests', () {
    test('StorageService correctly increments and tracks daily AI quota', () async {
      expect(StorageService.canMakeAiRequest, isTrue);
      expect(StorageService.dailyAiRequestCount, equals(0));

      await StorageService.incrementAiRequestCount();
      expect(StorageService.dailyAiRequestCount, equals(1));
    });

    test('Response caching works as expected', () async {
      const cacheKey = 'test_cache_key';
      expect(StorageService.getCachedAiResponse(cacheKey), isNull);

      await StorageService.cacheAiResponse(cacheKey, '{"status":"cached"}');
      expect(StorageService.getCachedAiResponse(cacheKey), equals('{"status":"cached"}'));
    });
  });
}
