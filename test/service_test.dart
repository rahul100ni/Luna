import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luna_app/core/constants/phase_constants.dart';
import 'package:luna_app/core/models/log_entry.dart';
import 'package:luna_app/core/models/user_profile.dart';
import 'package:luna_app/core/services/deepseek_service.dart';
import 'package:luna_app/core/services/storage_service.dart';
import 'package:luna_app/core/services/pattern_analysis_service.dart';
import 'package:luna_app/core/services/cycle_engine.dart';

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

  group('Cycle Engine & UX Theme Tests', () {
    test('CycleEngine.calculate returns follicular phase when no cycle anchor is set', () {
      final profile = UserProfile(
        id: 'u_no_cycle',
        name: 'NewUser',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: null,
        createdAt: DateTime.now(),
      );
      final state = CycleEngine.calculate(profile);
      expect(state.phase, equals(CyclePhase.follicular));
      expect(state.dayOfCycle, equals(0));
    });

    test('Menstrual phase uses uplifting warm coral rose colors rather than harsh red or depressing dark tones', () {
      final info = PhaseConstants.getPhaseInfo(CyclePhase.menstrual);
      expect(info.colors.primary.toARGB32(), equals(0xFFE56B85));
      expect(info.colors.background.toARGB32(), equals(0xFF1A0E13));
    });

    test('PhaseConstants provides dedicated neutralColors for no-cycle state', () {
      expect(PhaseConstants.neutralColors.primary.toARGB32(), equals(0xFF7E92C9));
      expect(PhaseConstants.neutralColors.background.toARGB32(), equals(0xFF0F1117));
    });

    test('LogEntry allows null mood when user records energy or symptoms without mood', () {
      final entry = LogEntry(
        id: 'no_mood_1',
        date: DateTime.now(),
        mood: null,
        energyLevel: 4,
        symptoms: ['Tired'],
        periodStarted: false,
      );
      expect(entry.mood, isNull);
      expect(entry.energyLevel, equals(4));

      final map = entry.toMap();
      expect(map['mood'], isNull);

      final restored = LogEntry.fromMap(map);
      expect(restored.mood, isNull);
      expect(restored.energyLevel, equals(4));
    });

    test('PhaseConstants copy contains no em dashes', () {
      for (final phase in CyclePhase.values) {
        final info = PhaseConstants.getPhaseInfo(phase);
        expect(info.scienceBody.contains('—'), isFalse);
        for (final item in info.doThis) {
          expect(item.contains('—'), isFalse);
        }
        for (final item in info.avoidThis) {
          expect(item.contains('—'), isFalse);
        }
        for (final item in info.eatThis) {
          expect(item.contains('—'), isFalse);
        }
      }
    });

    test('AI Auto-logging JSON tag parsing correctly extracts periodStarted, flow, cramps, mood, energy, symptoms and strips stray brackets', () {
      const sampleResponse =
          'I hear you so deeply. Take it slow today.\n\n[LOG:{"periodStarted":true,"flow":"heavy","cramps":"severe","mood":"struggling","energy":1,"symptoms":["Headache","Cramps"]}]';

      final logStartIdx = sampleResponse.indexOf('[LOG:');
      expect(logStartIdx != -1, isTrue);

      String cleanResponse = sampleResponse.substring(0, logStartIdx).trim();
      String rawLog = sampleResponse.substring(logStartIdx + 5).trim();
      if (rawLog.endsWith(']')) {
        rawLog = rawLog.substring(0, rawLog.length - 1).trim();
      }

      // Safety clean
      cleanResponse = cleanResponse.replaceAll(RegExp(r'\s*\[LOG:[^\]]*\]?'), '').trim();
      cleanResponse = cleanResponse.replaceAll(RegExp(r'\]+$'), '').trim();

      expect(cleanResponse, equals('I hear you so deeply. Take it slow today.'));
      expect(cleanResponse.endsWith(']'), isFalse);

      // JSON parsing test
      final parsed = jsonDecode(rawLog) as Map<String, dynamic>;
      expect(parsed['periodStarted'], isTrue);
      expect(parsed['flow'], equals('heavy'));
      expect(parsed['cramps'], equals('severe'));
      expect(parsed['mood'], equals('struggling'));
      expect(parsed['energy'], equals(1));
      expect(parsed['symptoms'], equals(['Headache', 'Cramps']));
    });
  });
}
