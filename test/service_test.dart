import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luna_app/core/constants/phase_constants.dart';
import 'package:luna_app/core/models/log_entry.dart';
import 'package:luna_app/core/models/user_profile.dart';
import 'package:luna_app/core/services/deepseek_service.dart';
import 'package:luna_app/core/services/storage_service.dart';
import 'package:luna_app/core/services/pattern_analysis_service.dart';
import 'package:luna_app/core/services/telemetry_service.dart';

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

    test('Fewer than 7 logs stays in calibration mode with no premature patterns', () {
      final now = DateTime.now();
      final anchor = now.subtract(const Duration(days: 28));
      final logs = <LogEntry>[
        LogEntry(
          id: 'l1',
          date: anchor.add(const Duration(days: 8)),
          mood: MoodLevel.thriving,
          energyLevel: 5,
          symptoms: [],
        ),
        LogEntry(
          id: 'l2',
          date: anchor.add(const Duration(days: 24)),
          mood: MoodLevel.struggling,
          energyLevel: 1,
          symptoms: ['Fatigue'],
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

      expect(profile.totalLogsAnalyzed, equals(2));
      expect(profile.hasSufficientData, isFalse);
      expect(profile.patterns, isEmpty);
      expect(profile.calibrationProgress, closeTo(2 / 7, 0.01));
    });

    test('Discovers late-luteal energy trough when >= 7 logs recorded across phases', () {
      final now = DateTime.now();
      final anchor = now.subtract(const Duration(days: 28));
      final logs = <LogEntry>[
        // 3 Follicular logs (high energy)
        LogEntry(
          id: 'l1',
          date: anchor.add(const Duration(days: 6)),
          mood: MoodLevel.good,
          energyLevel: 4,
          symptoms: [],
        ),
        LogEntry(
          id: 'l2',
          date: anchor.add(const Duration(days: 8)),
          mood: MoodLevel.thriving,
          energyLevel: 5,
          symptoms: [],
        ),
        LogEntry(
          id: 'l3',
          date: anchor.add(const Duration(days: 10)),
          mood: MoodLevel.good,
          energyLevel: 4,
          symptoms: [],
        ),
        // 1 Ovulatory log
        LogEntry(
          id: 'l4',
          date: anchor.add(const Duration(days: 13)),
          mood: MoodLevel.thriving,
          energyLevel: 4,
          symptoms: [],
        ),
        // 3 Late luteal logs (pronounced energy trough)
        LogEntry(
          id: 'l5',
          date: anchor.add(const Duration(days: 24)),
          mood: MoodLevel.struggling,
          energyLevel: 1,
          symptoms: ['Fatigue', 'Brain fog'],
        ),
        LogEntry(
          id: 'l6',
          date: anchor.add(const Duration(days: 25)),
          mood: MoodLevel.low,
          energyLevel: 2,
          symptoms: ['Fatigue', 'Anxious'],
        ),
        LogEntry(
          id: 'l7',
          date: anchor.add(const Duration(days: 26)),
          mood: MoodLevel.low,
          energyLevel: 2,
          symptoms: ['Fatigue'],
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

      expect(profile.totalLogsAnalyzed, equals(7));
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

  group('Remote AI Persona Config Tests', () {
    test('Default config has proper values, temperature, and negative constraints', () {
      final config = AiPersonaConfig.defaultConfig();
      expect(config.temperature, equals(0.65));
      expect(config.systemInstructions, contains('Luna'));
      expect(config.chatRules, contains('UNIFIED IDENTITY'));
      expect(config.forbiddenPhrases, contains('same well, different bucket'));
      expect(config.forbiddenPhrases, contains('privacy lecture aside'));
    });

    test('StorageService persists and retrieves AI Persona', () async {
      final initial = StorageService.getAiPersona();
      expect(initial.temperature, equals(0.65));

      const updated = AiPersonaConfig(
        systemInstructions: 'Custom test instructions',
        chatRules: 'Custom test chat rules',
        temperature: 0.72,
        forbiddenPhrases: ['test phrase'],
        version: '2.0-test',
      );

      await StorageService.saveAiPersona(updated);
      final retrieved = StorageService.getAiPersona();
      expect(retrieved.systemInstructions, equals('Custom test instructions'));
      expect(retrieved.chatRules, equals('Custom test chat rules'));
      expect(retrieved.temperature, equals(0.72));
      expect(retrieved.version, equals('2.0-test'));
      expect(retrieved.forbiddenPhrases, contains('test phrase'));
    });

    test('AiPersonaConfig serializes and deserializes correctly', () {
      final original = AiPersonaConfig.defaultConfig();
      final map = original.toMap();
      final reconstituted = AiPersonaConfig.fromMap(map);

      expect(reconstituted.systemInstructions, equals(original.systemInstructions));
      expect(reconstituted.chatRules, equals(original.chatRules));
      expect(reconstituted.temperature, equals(original.temperature));
      expect(reconstituted.forbiddenPhrases, equals(original.forbiddenPhrases));
      expect(reconstituted.version, equals(original.version));
    });
  });
}
