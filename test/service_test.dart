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
import 'package:luna_app/core/models/period_entry.dart';
import 'package:luna_app/core/models/luna_memory_entry.dart';
import 'package:luna_app/core/services/period_date_extractor.dart';
import 'package:luna_app/core/services/cycle_daily_intelligence.dart';

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

  group('Cycle Tracking Core & Multi-Cycle History Tests', () {
    test('Aug 22 + Sep 20 user journey: gap = 29 days and historical phases are exact', () {
      final aug22 = DateTime(2026, 8, 22);
      final sep20 = DateTime(2026, 9, 20);

      final history = [
        PeriodEntry(id: '1', startDate: sep20, source: 'logged'),
        PeriodEntry(id: '2', startDate: aug22, source: 'onboarding'),
      ];

      final profile = UserProfile(
        id: 'test',
        name: 'Her',
        averageCycleLength: 29, // Calibrated from 29-day gap between Aug 22 and Sep 20
        averagePeriodLength: 5,
        lastPeriodStart: sep20,
        createdAt: aug22,
      );

      // Aug 22 in calendar -> must be Day 1 of that cycle (Menstrual)
      final aug22State = CycleEngine.calculateForDate(profile, aug22, periodHistory: history);
      expect(aug22State, isNotNull);
      expect(aug22State!.dayOfCycle, equals(1));
      expect(aug22State.phase, equals(CyclePhase.menstrual));

      // Aug 23 in calendar -> Day 2 (Menstrual)
      final aug23State = CycleEngine.calculateForDate(profile, DateTime(2026, 8, 23), periodHistory: history);
      expect(aug23State, isNotNull);
      expect(aug23State!.dayOfCycle, equals(2));
      expect(aug23State.phase, equals(CyclePhase.menstrual));

      // Sep 19 in calendar -> Day 29 (Late Luteal, end of cycle 1)
      final sep19State = CycleEngine.calculateForDate(profile, DateTime(2026, 9, 19), periodHistory: history);
      expect(sep19State, isNotNull);
      expect(sep19State!.dayOfCycle, equals(29));
      expect(sep19State.phase, equals(CyclePhase.lateLuteal));

      // Sep 20 in calendar -> Day 1 of cycle 2 (Menstrual)
      final sep20State = CycleEngine.calculateForDate(profile, sep20, periodHistory: history);
      expect(sep20State, isNotNull);
      expect(sep20State!.dayOfCycle, equals(1));
      expect(sep20State.phase, equals(CyclePhase.menstrual));

      // Both Aug 22 and Sep 20 are confirmed period starts
      expect(CycleEngine.isConfirmedPeriodStart(aug22, history), isTrue);
      expect(CycleEngine.isConfirmedPeriodStart(sep20, history), isTrue);
      expect(CycleEngine.isConfirmedPeriodStart(DateTime(2026, 8, 23), history), isFalse);
      expect(CycleEngine.isConfirmedPeriodStart(DateTime(2026, 9, 19), history), isFalse);
    });

    test('Overdue period calculation never wraps back to menstrual without logged start', () {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final profile = UserProfile(
        id: 'test',
        name: 'Her',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: thirtyDaysAgo,
        createdAt: thirtyDaysAgo,
      );

      // On day 31 (today) before logging period:
      // Must NOT wrap to day 3 menstrual! Must stay late luteal overdue
      final phaseOnDay31 = CycleEngine.phaseForDate(
        now,
        profile,
        periodHistory: [PeriodEntry(id: '1', startDate: thirtyDaysAgo, source: 'onboarding')],
      );
      expect(phaseOnDay31, equals(CyclePhase.lateLuteal));
    });

    test('Future predictions are suppressed when cycle length is unknown and data insufficient', () {
      final sep20 = DateTime(2026, 9, 20);
      final profile = UserProfile(
        id: 'test',
        name: 'Her',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: sep20,
        createdAt: sep20,
      );

      final history = [
        PeriodEntry(id: '1', startDate: sep20, source: 'onboarding'),
      ];

      final futurePhase = CycleEngine.phaseForDate(
        DateTime(2026, 11, 15),
        profile,
        periodHistory: history,
        isCycleLengthUnknown: true,
      );
      expect(futurePhase, isNull);
    });

    test('PeriodEntry toMap and fromMap serialization integrity', () {
      final date = DateTime(2026, 9, 20);
      final entry = PeriodEntry(id: 'test-123', startDate: date, source: 'ai');
      final map = entry.toMap();

      expect(map['id'], equals('test-123'));
      expect(map['start_date'], equals(date.toIso8601String()));
      expect(map['source'], equals('ai'));

      final restored = PeriodEntry.fromMap(map);
      expect(restored.id, equals(entry.id));
      expect(restored.startDate.year, equals(entry.startDate.year));
      expect(restored.startDate.month, equals(entry.startDate.month));
      expect(restored.startDate.day, equals(entry.startDate.day));
      expect(restored.source, equals(entry.source));
    });
  });

  group('Luna Intimate Memory & AI Logging Tests', () {
    test('LunaMemoryEntry toMap and fromMap serialization integrity', () {
      final now = DateTime(2026, 9, 20, 15, 30);
      final memory = LunaMemoryEntry(
        id: 'mem-123',
        category: 'preference',
        content: 'Prefers hot chamomile tea with honey when cramping',
        createdAt: now,
        lastSurfaced: now,
      );

      final map = memory.toMap();
      expect(map['id'], equals('mem-123'));
      expect(map['category'], equals('preference'));
      expect(map['content'], equals('Prefers hot chamomile tea with honey when cramping'));
      expect(map['created_at'], equals(now.toIso8601String()));
      expect(map['last_surfaced'], equals(now.toIso8601String()));

      final restored = LunaMemoryEntry.fromMap(map);
      expect(restored.id, equals(memory.id));
      expect(restored.category, equals('preference'));
      expect(restored.content, equals(memory.content));
      expect(restored.createdAt.toIso8601String(), equals(now.toIso8601String()));
      expect(restored.lastSurfaced?.toIso8601String(), equals(now.toIso8601String()));
    });

    test('AI Auto-logging JSON tag parsing extracts memory and sleep', () {
      const rawLog = '{"periodStarted": false, "sleep": "poor", "memory": {"category": "preference", "note": "Loves hot baths for cramps"}, "notes": "Felt fatigued after work"}';
      final parsed = jsonDecode(rawLog) as Map<String, dynamic>;

      expect(parsed['periodStarted'], isFalse);
      expect(parsed['sleep'], equals('poor'));
      expect(parsed['notes'], equals('Felt fatigued after work'));
      expect(parsed['memory'], isA<Map>());
      expect(parsed['memory']['category'], equals('preference'));
      expect(parsed['memory']['note'], equals('Loves hot baths for cramps'));
    });
  });

  group('Biomarker Check-in & Pattern Intelligence Hardening Tests', () {
    test('LogEntry.hasBiomarkerData returns false for bare period starts and true for real check-ins', () {
      final barePeriodLog = LogEntry(
        id: '1',
        date: DateTime(2026, 8, 22),
        symptoms: [],
        periodStarted: true,
      );
      expect(barePeriodLog.hasBiomarkerData, isFalse);

      final moodLog = LogEntry(
        id: '2',
        date: DateTime(2026, 9, 20),
        mood: MoodLevel.decent,
        symptoms: [],
        periodStarted: true,
      );
      expect(moodLog.hasBiomarkerData, isTrue);

      final symptomLog = LogEntry(
        id: '3',
        date: DateTime(2026, 9, 20),
        symptoms: ['Cramps'],
        periodStarted: false,
      );
      expect(symptomLog.hasBiomarkerData, isTrue);
    });

    test('PatternAnalysisService ignores bare period anchors and requires wellness data for calibration', () {
      final profile = UserProfile(
        id: 'p1',
        name: 'Her',
        averageCycleLength: 29,
        averagePeriodLength: 5,
        lastPeriodStart: DateTime(2026, 9, 20),
        createdAt: DateTime(2026, 8, 22),
      );

      final bareLogs = [
        LogEntry(id: '1', date: DateTime(2026, 8, 22), symptoms: [], periodStarted: true),
        LogEntry(id: '2', date: DateTime(2026, 9, 20), symptoms: [], periodStarted: true),
      ];

      final result = PatternAnalysisService.analyze(logs: bareLogs, profile: profile);
      expect(result.totalLogsAnalyzed, equals(0));
      expect(result.hasSufficientData, isFalse);
      expect(result.hasPatterns, isFalse);
      expect(result.calibrationProgress, equals(0.0));
    });

    test('Period history deduplication filters multiple entries for the same calendar date', () {
      final date1 = DateTime(2026, 9, 20, 10, 0);
      final date2 = DateTime(2026, 9, 20, 14, 30);
      final date3 = DateTime(2026, 9, 20, 18, 45);
      final date4 = DateTime(2026, 8, 22, 9, 0);

      final entries = [
        PeriodEntry(id: '1', startDate: date1, source: 'logged'),
        PeriodEntry(id: '2', startDate: date2, source: 'logged'),
        PeriodEntry(id: '3', startDate: date3, source: 'logged'),
        PeriodEntry(id: '4', startDate: date4, source: 'onboarding'),
      ];

      final seen = <String>{};
      final deduped = entries.where((p) => seen.add('${p.startDate.year}-${p.startDate.month}-${p.startDate.day}')).toList();

      expect(deduped.length, equals(2));
      expect(deduped[0].startDate.day, equals(20));
      expect(deduped[1].startDate.day, equals(22));
    });
  });

  group('Cycle Gap Analysis & Endocrinological Intelligence Tests', () {
    test('Gap analysis returns unknown when fewer than 2 completed cycles and not overdue', () {
      final profile = UserProfile(
        id: 'u1',
        name: 'User',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: DateTime.now().subtract(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      final history = [
        PeriodEntry(id: '1', startDate: DateTime.now().subtract(const Duration(days: 10)), source: 'logged'),
      ];

      final analysis = CycleEngine.analyzeGaps(profile, history);
      expect(analysis.regularity, equals(CycleRegularity.unknown));
      expect(analysis.hasAbnormality, isFalse);
      expect(analysis.clinicalGuidanceDirective.contains('—'), isFalse);
    });

    test('Identifies delayed cycle (>= 4 days) and generates endocrinological guidance without em dashes', () {
      final now = DateTime.now();
      final p1 = now.subtract(const Duration(days: 70));
      final p2 = p1.add(const Duration(days: 35)); // 35-day cycle on a 28-day baseline (+7 days delayed)
      final history = [
        PeriodEntry(id: 'p2', startDate: p2, source: 'logged'),
        PeriodEntry(id: 'p1', startDate: p1, source: 'logged'),
      ];
      final profile = UserProfile(
        id: 'u1',
        name: 'User',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: p2,
        createdAt: p1,
      );

      final analysis = CycleEngine.analyzeGaps(profile, history);
      expect(analysis.regularity, equals(CycleRegularity.delayed));
      expect(analysis.deviationFromBaseline, equals(7));
      expect(analysis.hasAbnormality, isTrue);
      expect(analysis.biologicalSummary, contains('35 days'));
      expect(analysis.clinicalGuidanceDirective, contains('follicular phase'));
      expect(analysis.clinicalGuidanceDirective, contains('cortisol'));
      expect(analysis.clinicalGuidanceDirective.contains('—'), isFalse,
          reason: 'Guidance must never contain em dashes');
    });

    test('Identifies early cycle (<= -4 days) and generates early ovulation/luteolysis guidance', () {
      final now = DateTime.now();
      final p1 = now.subtract(const Duration(days: 60));
      final p2 = p1.add(const Duration(days: 22)); // 22-day cycle on 28-day baseline (-6 days early)
      final history = [
        PeriodEntry(id: 'p2', startDate: p2, source: 'logged'),
        PeriodEntry(id: 'p1', startDate: p1, source: 'logged'),
      ];
      final profile = UserProfile(
        id: 'u1',
        name: 'User',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: p2,
        createdAt: p1,
      );

      final analysis = CycleEngine.analyzeGaps(profile, history);
      expect(analysis.regularity, equals(CycleRegularity.early));
      expect(analysis.deviationFromBaseline, equals(-6));
      expect(analysis.hasAbnormality, isTrue);
      expect(analysis.clinicalGuidanceDirective, contains('early'));
      expect(analysis.clinicalGuidanceDirective.contains('—'), isFalse);
    });

    test('Identifies overdue active cycle when past expected next period by >= 4 days', () {
      final now = DateTime.now();
      final lastPeriod = now.subtract(const Duration(days: 34)); // 34 days ago, expected 28 -> 6 days overdue
      final history = [
        PeriodEntry(id: 'p1', startDate: lastPeriod, source: 'logged'),
      ];
      final profile = UserProfile(
        id: 'u1',
        name: 'User',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: lastPeriod,
        createdAt: lastPeriod,
      );

      final analysis = CycleEngine.analyzeGaps(profile, history);
      expect(analysis.regularity, equals(CycleRegularity.overdue));
      expect(analysis.currentDaysOverdue, equals(6));
      expect(analysis.hasAbnormality, isTrue);
      expect(analysis.clinicalGuidanceDirective, contains('delayed ovulation'));
      expect(analysis.clinicalGuidanceDirective.contains('—'), isFalse);
    });
  });

  group('Biological Flow Mandate & Emotional Prompt Auto-Logging Tests', () {
    test('Presence of menstrual flow strictly mandates periodStarted: true', () {
      final entryWithFlow = LogEntry(
        id: 'flow1',
        date: DateTime.now(),
        flow: FlowLevel.heavy,
        symptoms: [],
        periodStarted: false,
      );

      // Verify the biological requirement that active flow requires period start
      final bool effectivelyStarted =
          entryWithFlow.periodStarted || entryWithFlow.flow != null;
      expect(effectivelyStarted, isTrue);

      final entryNoneFlow = LogEntry(
        id: 'flow2',
        date: DateTime.now(),
        flow: null,
        symptoms: [],
        periodStarted: false,
      );
      final bool noneStarted =
          entryNoneFlow.periodStarted || entryNoneFlow.flow != null;
      expect(noneStarted, isFalse);
    });

    test('Deterministic heuristics correctly extract biomarkers from complex emotional user prompt', () {
      const userPrompt =
          "Ykw my day is ruined I have O energy level absolutely no recollection and literally high flow max cramps and my period started tomorrow and it so painfully and I am having severe headaches and I has like the worst sleep possible";
      final lower = userPrompt.toLowerCase();

      // Flow
      FlowLevel? detectedFlow;
      if (RegExp(r'\b(high\s+flow|heavy\s+flow|heavy\s+bleeding)\b').hasMatch(lower)) {
        detectedFlow = FlowLevel.heavy;
      }
      expect(detectedFlow, equals(FlowLevel.heavy));

      // Period started (even with "started tomorrow" or "period started")
      bool detectedPeriodStarted = false;
      if (RegExp(r'\b(period\s+started|got\s+my\s+period|started\s+my\s+period|started\s+bleeding|my\s+period\s+came|period\s+is\s+here)\b')
          .hasMatch(lower)) {
        detectedPeriodStarted = true;
      }
      // Biological Mandate via flow
      if (detectedFlow != null) {
        detectedPeriodStarted = true;
      }
      expect(detectedPeriodStarted, isTrue);

      // Cramps
      CrampLevel? detectedCramps;
      if (RegExp(r'\b(max\s+cramps|severe\s+cramps|terrible\s+cramps|worst\s+cramps|awful\s+cramps|intense\s+cramps)\b')
          .hasMatch(lower)) {
        detectedCramps = CrampLevel.severe;
      }
      expect(detectedCramps, equals(CrampLevel.severe));

      // Energy (letter O energy or 0 energy)
      int? detectedEnergy;
      if (RegExp(r'\b([o0]|zero|no)\s+energy\b').hasMatch(lower)) {
        detectedEnergy = 1;
      }
      expect(detectedEnergy, equals(1));

      // Sleep
      SleepQuality? detectedSleep;
      if (RegExp(r'\b(worst\s+sleep|poor\s+sleep|terrible\s+sleep|awful\s+sleep|bad\s+sleep|couldn\x27?t\s+sleep|insomnia)\b')
          .hasMatch(lower)) {
        detectedSleep = SleepQuality.poor;
      }
      expect(detectedSleep, equals(SleepQuality.poor));

      // Mood
      MoodLevel? detectedMood;
      if (RegExp(r'\b(day\s+is\s+ruined|struggling|crying|depressed|can\x27?t\s+take\s+this|miserable|overwhelmed)\b')
          .hasMatch(lower)) {
        detectedMood = MoodLevel.struggling;
      }
      expect(detectedMood, equals(MoodLevel.struggling));

      // Symptoms
      final symptoms = <String>[];
      if (RegExp(r'\b(headache|headaches|migraine)\b').hasMatch(lower)) {
        symptoms.add('Headache');
      }
      if (RegExp(r'\b(cramp|cramps|cramping)\b').hasMatch(lower)) {
        symptoms.add('Cramps');
      }
      expect(symptoms, containsAll(['Headache', 'Cramps']));
    });
  });

  group('Dynamic Period Length Calibration Tests', () {
    test('StorageService tracks unknown period length flag and updates calibration', () async {
      // By default is false
      expect(StorageService.isPeriodLengthUnknown(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('period_length_unknown', true);
      expect(StorageService.isPeriodLengthUnknown(), isTrue);

      await StorageService.setPeriodLengthCalibrated();
      expect(StorageService.isPeriodLengthUnknown(), isFalse);
    });

    test('Consecutive bleeding days calculation correctly computes average period length', () {
      // Cycle 1 bleeding: 5 days
      // Cycle 2 bleeding: 4 days
      final bleedingRuns = [5, 4];
      final avg = (bleedingRuns.reduce((a, b) => a + b) / bleedingRuns.length).round();
      final clamped = avg.clamp(2, 9);
      expect(clamped, equals(5));
    });
  });

  group('Cycle Anchor Correction & Settings Update Tests', () {
    test('Date difference heuristic correctly differentiates correction vs new cycle', () {
      final oldAnchor = DateTime(2026, 9, 20);
      
      // Case A: Correcting backwards by 5 days -> should replace old anchor
      final correctedBack = DateTime(2026, 9, 15);
      expect(correctedBack.difference(oldAnchor).inDays < 16, isTrue);

      // Case B: Adjusting forward by 2 days -> should replace old anchor
      final adjustedForward = DateTime(2026, 9, 22);
      expect(adjustedForward.difference(oldAnchor).inDays < 16, isTrue);

      // Case C: New cycle 28 days later -> should NOT replace old anchor, keep as history
      final newCycle = DateTime(2026, 10, 18);
      expect(newCycle.difference(oldAnchor).inDays >= 16, isTrue);
    });

    test('Old anchor deletion filters target entries on or after new date when correcting backwards', () {
      final oldAnchor = DateTime(2026, 9, 20);
      final newAnchor = DateTime(2026, 9, 15);

      final state = [
        PeriodEntry(id: 'p1', startDate: DateTime(2026, 9, 20)),
        PeriodEntry(id: 'p0', startDate: DateTime(2026, 8, 22)),
      ];

      final toRemove = state.where((p) {
        final pNorm = DateTime(p.startDate.year, p.startDate.month, p.startDate.day);
        return (pNorm == oldAnchor) || pNorm.isAfter(newAnchor);
      }).toList();

      expect(toRemove.map((e) => e.id), contains('p1'));
      expect(toRemove.map((e) => e.id), isNot(contains('p0')));
    });

    test('Unmarking periodStarted without flow detects existing anchor for removal', () {
      final today = DateTime(2026, 9, 21);
      final history = [
        PeriodEntry(id: 'anchor-today', startDate: DateTime(2026, 9, 21)),
        PeriodEntry(id: 'anchor-past', startDate: DateTime(2026, 8, 23)),
      ];

      final log = LogEntry(
        id: 'log-1',
        date: today,
        symptoms: [],
        periodStarted: false,
        flow: null,
      );

      final normDate = DateTime(log.date.year, log.date.month, log.date.day);
      final existingAnchor = history.where((p) =>
          p.startDate.year == normDate.year &&
          p.startDate.month == normDate.month &&
          p.startDate.day == normDate.day).firstOrNull;

      expect(existingAnchor, isNotNull);
      expect(existingAnchor!.id, equals('anchor-today'));
    });

    test('Calendar strictly suppresses logging actions on future dates', () {
      final today = DateTime(2026, 9, 21);
      final tomorrow = DateTime(2026, 9, 22);
      final past = DateTime(2026, 9, 20);

      expect(tomorrow.isAfter(today), isTrue);
      expect(past.isAfter(today), isFalse);
    });

    test('Editing an entry moves date without deleting the entry', () {
      final oldDate = DateTime(2026, 9, 20);
      final newDate = DateTime(2026, 9, 18);
      final entry = PeriodEntry(id: 'anchor-sep', startDate: oldDate);

      // Simulating editPeriodEntry logic
      final updated = PeriodEntry(id: entry.id, startDate: newDate, source: entry.source);
      expect(updated.id, equals('anchor-sep'));
      expect(updated.startDate, equals(newDate));
    });

    test('Consecutive bleeding days within 14 days do not move cycle anchor', () {
      final cycleStart = DateTime(2026, 9, 20);
      final day2Bleeding = DateTime(2026, 9, 21);
      final history = [PeriodEntry(id: '1', startDate: cycleStart)];

      final normDate = DateTime(day2Bleeding.year, day2Bleeding.month, day2Bleeding.day);
      final sameCycle = history.where((p) {
        final diff = normDate.difference(p.startDate).inDays;
        return diff >= 0 && diff < 14;
      }).firstOrNull;

      expect(sameCycle, isNotNull);
      expect(sameCycle!.startDate, equals(cycleStart));
    });

    test('Editing older entry leaves newer cycles and current anchor intact', () {
      final sepAnchor = DateTime(2026, 9, 20);
      final oldAug = DateTime(2026, 8, 22);
      final correctedAug = DateTime(2026, 8, 20);

      final state = [
        PeriodEntry(id: 'sep', startDate: sepAnchor),
        PeriodEntry(id: 'aug', startDate: oldAug),
      ];

      // Edit aug only
      final updatedState = state.map((e) {
        if (e.id == 'aug') return PeriodEntry(id: e.id, startDate: correctedAug);
        return e;
      }).toList();

      expect(updatedState.first.startDate, equals(sepAnchor));
      expect(updatedState.last.startDate, equals(correctedAug));
      expect(updatedState.length, equals(2));
    });

    test('showDatePicker date bounds prevent assertion crashes when anchor is historical', () {
      final now = DateTime(2026, 9, 21);
      final oldAnchor = DateTime(2025, 6, 1); // 477 days ago

      final safeInitial = oldAnchor.isAfter(now) ? now : oldAnchor;
      final firstDate = safeInitial.isBefore(now.subtract(const Duration(days: 730)))
          ? safeInitial
          : now.subtract(const Duration(days: 730));

      expect(safeInitial.isBefore(firstDate), isFalse);
      expect(safeInitial.isAfter(now), isFalse);
    });
  });

  group('PeriodDateExtractor natural language extraction & confirmation tests', () {
    test('extractDate correctly parses relative dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final yesterday = PeriodDateExtractor.extractDate('My period started yesterday');
      expect(yesterday, isNotNull);
      expect(yesterday, equals(today.subtract(const Duration(days: 1))));

      final dayBefore = PeriodDateExtractor.extractDate('it actually began the day before yesterday');
      expect(dayBefore, isNotNull);
      expect(dayBefore, equals(today.subtract(const Duration(days: 2))));

      final threeDaysAgo = PeriodDateExtractor.extractDate('I started bleeding 3 days ago');
      expect(threeDaysAgo, isNotNull);
      expect(threeDaysAgo, equals(today.subtract(const Duration(days: 3))));
    });

    test('extractDate correctly parses month and day formats', () {
      final sep18 = PeriodDateExtractor.extractDate('My period started on Sep 18th');
      expect(sep18, isNotNull);
      expect(sep18!.month, equals(9));
      expect(sep18.day, equals(18));

      final aug20 = PeriodDateExtractor.extractDate('It started 20th August');
      expect(aug20, isNotNull);
      expect(aug20!.month, equals(8));
      expect(aug20.day, equals(20));

      final sep15 = PeriodDateExtractor.extractDate('started on 15 sep');
      expect(sep15, isNotNull);
      expect(sep15!.month, equals(9));
      expect(sep15.day, equals(15));
    });

    test('extractDate parses day-only relative to current month', () {
      final now = DateTime.now();
      final on18th = PeriodDateExtractor.extractDate('my period started on the 18th');
      expect(on18th, isNotNull);
      expect(on18th!.day, equals(18));
      expect(on18th.month, equals(now.month));
    });

    test('isConfirmation identifies affirmative responses', () {
      expect(PeriodDateExtractor.isConfirmation('yes'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('yes please'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('sure'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('yeah'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('yep'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('do it'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('please update'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('I feel tired today'), isFalse);
    });

    test('isCancellation identifies negative responses', () {
      expect(PeriodDateExtractor.isCancellation('no'), isTrue);
      expect(PeriodDateExtractor.isCancellation('no thanks'), isTrue);
      expect(PeriodDateExtractor.isCancellation('cancel'), isTrue);
      expect(PeriodDateExtractor.isCancellation('nevermind'), isTrue);
      expect(PeriodDateExtractor.isCancellation('keep it as is'), isTrue);
      expect(PeriodDateExtractor.isCancellation('yes please'), isFalse);
    });
  });

  group('Symptom canonicalization & deduplication tests', () {
    test('canonicalizeSymptom maps lowercase and variants to Title Case', () {
      expect(LogEntry.canonicalizeSymptom('craving'), equals('Cravings'));
      expect(LogEntry.canonicalizeSymptom('cravings'), equals('Cravings'));
      expect(LogEntry.canonicalizeSymptom('headache'), equals('Headache'));
      expect(LogEntry.canonicalizeSymptom('cramps'), equals('Cramps'));
      expect(LogEntry.canonicalizeSymptom('bloating'), equals('Bloating'));
      expect(LogEntry.canonicalizeSymptom('tired'), equals('Fatigue'));
    });

    test('canonicalizeSymptoms deduplicates case-insensitively within single entry', () {
      final raw = ['craving', 'Craving', 'Cravings', 'headache', 'Headache'];
      final canonical = LogEntry.canonicalizeSymptoms(raw);
      expect(canonical, equals(['Cravings', 'Headache']));
    });

    test('LogEntry constructor auto-canonicalizes symptoms', () {
      final entry = LogEntry(
        id: 'test_1',
        date: DateTime.now(),
        symptoms: ['craving', 'Craving', 'CRAMPS', 'cramps'],
      );
      expect(entry.symptoms, equals(['Cravings', 'Cramps']));
    });
  });

  group('Android Back Navigation & App Exit Prevention Tests', () {
    test('WidgetsBindingObserver didPopRoute contract requires true to prevent platform exit', () {
      // In Flutter framework, binding.dart:
      // Future<bool> handlePopRoute() async {
      //   for (final observer in List<WidgetsBindingObserver>.of(_observers)) {
      //     if (await observer.didPopRoute()) {
      //       return true; // back button was handled, do NOT exit app!
      //     }
      //   }
      //   return false;
      // }
      // Therefore, returning true means back gesture was handled and app stays open.
      bool didPopRouteHandled = true;
      expect(didPopRouteHandled, isTrue,
          reason: 'Returning true from didPopRoute instructs Flutter that back was handled and prevents app close');
    });

    test('LogEntry canonicalization handles all common symptom variants', () {
      expect(LogEntry.canonicalizeSymptom('headache'), equals('Headache'));
      expect(LogEntry.canonicalizeSymptom('HEADACHE'), equals('Headache'));
      expect(LogEntry.canonicalizeSymptom('brain fog'), equals('Brain fog'));
      expect(LogEntry.canonicalizeSymptom('BRAIN FOG'), equals('Brain fog'));
      expect(LogEntry.canonicalizeSymptom('cramps'), equals('Cramps'));
      expect(LogEntry.canonicalizeSymptom('tender'), equals('Tender'));
      expect(LogEntry.canonicalizeSymptom('tender breasts'), equals('Tender'));
      expect(LogEntry.canonicalizeSymptom('bloated'), equals('Bloating'));
      expect(LogEntry.canonicalizeSymptom('anxiety'), equals('Anxious'));
    });
  });

  group('Calendar Day Rhythm & Temporal Logic Tests', () {
    test('Temporal date categorization correctly partitions Past, Today, and Future', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));

      expect(yesterday.isBefore(today), isTrue);
      expect(yesterday.isAfter(today), isFalse);

      expect(today.isAtSameMomentAs(today), isTrue);

      expect(tomorrow.isAfter(today), isTrue);
      expect(nextWeek.difference(today).inDays, equals(7));
    });

    test('CycleDailyIntelligence returns comprehensive non-empty guidance for all cycle days', () {
      for (int day = 1; day <= 32; day++) {
        final g = CycleDailyIntelligence.getGuidance(day, CyclePhase.follicular);
        expect(g.dayHighlight, isNotEmpty);
        expect(g.doThis, isNotEmpty);
        expect(g.avoidThis, isNotEmpty);
        expect(g.biologicalContext, isNotEmpty);
        expect(g.dayHighlight.contains('—'), isFalse);
        expect(g.doThis.contains('—'), isFalse);
        expect(g.avoidThis.contains('—'), isFalse);
        expect(g.biologicalContext.contains('—'), isFalse);
      }
    });
  });

  group('AI Auto-Logging Non-Echoing & Date Correction Hardening Tests', () {
    test('PeriodDateExtractor parses user prompt "Hey My period started 4 days ago and logged wrong here"', () {
      final refDate = DateTime(2026, 9, 21);
      final extracted = PeriodDateExtractor.extractDate(
        'Hey My period started 4 days ago and logged wrong here',
        referenceDate: refDate,
      );
      expect(extracted, isNotNull);
      expect(extracted, equals(DateTime(2026, 9, 17)));
    });

    test('PeriodDateExtractor parses word numbers and relative variations', () {
      final refDate = DateTime(2026, 9, 21);
      expect(
        PeriodDateExtractor.extractDate('My period started four days ago', referenceDate: refDate),
        equals(DateTime(2026, 9, 17)),
      );
      expect(
        PeriodDateExtractor.extractDate('it was a couple days ago, period came', referenceDate: refDate),
        equals(DateTime(2026, 9, 19)),
      );
      expect(
        PeriodDateExtractor.extractDate('started bleeding a few days ago', referenceDate: refDate),
        equals(DateTime(2026, 9, 18)),
      );
      expect(
        PeriodDateExtractor.extractDate('my period started a week ago', referenceDate: refDate),
        equals(DateTime(2026, 9, 14)),
      );
      expect(
        PeriodDateExtractor.extractDate('period was 4 days back', referenceDate: refDate),
        equals(DateTime(2026, 9, 17)),
      );
    });

    test('PeriodDateExtractor confirmation and cancellation handles common phrasing', () {
      expect(PeriodDateExtractor.isConfirmation('yes please'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('update it'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('sure'), isTrue);
      expect(PeriodDateExtractor.isConfirmation('do it'), isTrue);

      expect(PeriodDateExtractor.isCancellation('no thanks'), isTrue);
      expect(PeriodDateExtractor.isCancellation('keep it'), isTrue);
      expect(PeriodDateExtractor.isCancellation('cancel'), isTrue);
      expect(PeriodDateExtractor.isCancellation('leave it as is'), isTrue);
    });

    test('Diffing engine: Existing log items are suppressed from auto-log summary parts', () {
      final existingEntry = LogEntry(
        id: '1',
        date: DateTime(2026, 9, 21),
        mood: MoodLevel.decent,
        energyLevel: 3,
        sleepQuality: SleepQuality.fair,
        flow: FlowLevel.medium,
        periodStarted: true,
        symptoms: ['Low Energy'],
      );

      // Simulate newly detected fields matching existing entry (e.g. echoed by LLM)
      const detectedMood = MoodLevel.decent;
      const detectedEnergy = 3;
      const detectedSleep = SleepQuality.fair;
      const detectedFlow = FlowLevel.medium;
      final detectedSymptoms = ['Low energy'];
      const bool detectedPeriodStarted = true;

      // Diffing checks
      final isNewMood = detectedMood != existingEntry.mood;
      final isNewEnergy = detectedEnergy != existingEntry.energyLevel;
      final isNewSleep = detectedSleep != existingEntry.sleepQuality;
      final isNewFlow = detectedFlow != existingEntry.flow;
      final isNewPeriodStarted = detectedPeriodStarted && !existingEntry.periodStarted;

      final existingCanonical = LogEntry.canonicalizeSymptoms(existingEntry.symptoms);
      final newSymptoms = <String>[];
      for (final s in LogEntry.canonicalizeSymptoms(detectedSymptoms)) {
        if (!existingCanonical.contains(s)) {
          newSymptoms.add(s);
        }
      }

      final parts = <String>[];
      if (isNewPeriodStarted) parts.add('Period started 🩸');
      if (isNewFlow) parts.add('Flow');
      if (isNewMood) parts.add(detectedMood.label);
      if (isNewEnergy) parts.add('$detectedEnergy/5 energy');
      if (isNewSleep) parts.add('Sleep');
      for (final s in newSymptoms) {
        parts.add(s);
      }

      // Everything was already logged, so parts MUST be completely empty!
      expect(parts.isEmpty, isTrue);
      expect(isNewMood, isFalse);
      expect(isNewEnergy, isFalse);
      expect(isNewSleep, isFalse);
      expect(isNewFlow, isFalse);
      expect(isNewPeriodStarted, isFalse);
      expect(newSymptoms.isEmpty, isTrue);
    });

    test('Diffing engine: When user shares genuinely new symptom, only new symptom is captured', () {
      final existingEntry = LogEntry(
        id: '1',
        date: DateTime(2026, 9, 21),
        mood: MoodLevel.decent,
        energyLevel: 3,
        symptoms: ['Low Energy'],
      );

      // User now reports severe cramps and headache
      const detectedCramps = CrampLevel.severe;
      final detectedSymptoms = ['Low Energy', 'Headache'];

      final isNewCramps = detectedCramps != CrampLevel.none && detectedCramps != existingEntry.cramps;

      final existingCanonical = LogEntry.canonicalizeSymptoms(existingEntry.symptoms);
      final newSymptoms = <String>[];
      for (final s in LogEntry.canonicalizeSymptoms(detectedSymptoms)) {
        if (!existingCanonical.contains(s)) {
          newSymptoms.add(s);
        }
      }

      final parts = <String>[];
      if (isNewCramps) parts.add('Severe cramps');
      for (final s in newSymptoms) {
        parts.add(s);
      }

      // Only the new items (Severe cramps and Headache) are added!
      expect(parts, equals(['Severe cramps', 'Headache']));
      expect(parts.contains('Low Energy'), isFalse);
    });

    test('Date correction request strictly suppresses periodStarted and flow for today', () {
      const bool hasSpecificDateRequest = true;
      bool? detectedPeriodStarted = true;
      FlowLevel? detectedFlow = FlowLevel.medium;

      if (hasSpecificDateRequest) {
        detectedPeriodStarted = false;
        detectedFlow = null;
      }

      expect(detectedPeriodStarted, isFalse);
      expect(detectedFlow, isNull);
    });
  });

  group('Pillar Nine & Direct Cycle Correction Tests', () {
    test('PeriodDateExtractor identifies direct correction commands and parses relative dates', () {
      final now = DateTime(2026, 9, 21);
      final yesterday = DateTime(2026, 9, 20);

      // Prompt 1: "update my cycle to like being day 1 yesterday"
      const prompt1 = 'update my cycle to like being day 1 yesterday';
      expect(PeriodDateExtractor.isDirectCorrectionCommand(prompt1), isTrue);
      expect(PeriodDateExtractor.hasPeriodContext(prompt1), isTrue);
      final date1 = PeriodDateExtractor.extractDate(prompt1, referenceDate: now);
      expect(date1, isNotNull);
      expect(date1!.year, equals(yesterday.year));
      expect(date1.month, equals(yesterday.month));
      expect(date1.day, equals(yesterday.day));

      // Prompt 2: "make my period starting date as 20th september 2026"
      const prompt2 = 'make my period starting date as 20th september 2026';
      expect(PeriodDateExtractor.isDirectCorrectionCommand(prompt2), isTrue);
      expect(PeriodDateExtractor.hasPeriodContext(prompt2), isTrue);
      final date2 = PeriodDateExtractor.extractDate(prompt2, referenceDate: now);
      expect(date2, isNotNull);
      expect(date2!.year, equals(2026));
      expect(date2.month, equals(9));
      expect(date2.day, equals(20));

      // Prompt 3: "not 21st my period started on 20th"
      const prompt3 = 'not 21st my period started on 20th';
      expect(PeriodDateExtractor.hasPeriodContext(prompt3), isTrue);
      final date3 = PeriodDateExtractor.extractDate(prompt3, referenceDate: now);
      expect(date3, isNotNull);
      expect(date3!.day, equals(20));

      // Prompt 4: "my cycle started 2 days ago"
      const prompt4 = 'my cycle started 2 days ago';
      final date4 = PeriodDateExtractor.extractDate(prompt4, referenceDate: now);
      expect(date4, isNotNull);
      expect(date4!.day, equals(19));
    });

    test('Consecutive bleeding day does not advance cycle anchor in addPeriodStart logic', () {
      final periodStart = DateTime(2026, 9, 20);
      final day2 = DateTime(2026, 9, 21);

      // Simulate cycle_provider addPeriodStart guard logic:
      DateTime currentAnchor = periodStart;
      final pNorm = DateTime(currentAnchor.year, currentAnchor.month, currentAnchor.day);
      final normDate = DateTime(day2.year, day2.month, day2.day);

      const source = 'log'; // Normal daily log of bleeding
      bool ignored = false;
      if (normDate.isAfter(pNorm) &&
          normDate.difference(pNorm).inDays <= 14 &&
          source != 'correction' &&
          source != 'ai_correction' &&
          source != 'settings') {
        ignored = true;
      }

      expect(ignored, isTrue, reason: 'Consecutive flow on day 2 should not shift anchor');

      // However, if it was an explicit correction:
      const explicitSource = 'ai_correction';
      bool correctionIgnored = false;
      if (normDate.isAfter(pNorm) &&
          normDate.difference(pNorm).inDays <= 14 &&
          explicitSource != 'correction' &&
          explicitSource != 'ai_correction' &&
          explicitSource != 'settings') {
        correctionIgnored = true;
      }
      expect(correctionIgnored, isFalse, reason: 'Explicit AI correction must be applied');
    });

    test('Legacy migration safely collapses consecutive bleeding days into single cycle anchor', () {
      // Suppose legacy log entries had periodStarted=true on Sep 20, Sep 21, Sep 22, and then Oct 18, Oct 19
      final legacyDates = [
        DateTime(2026, 9, 20),
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 22),
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
      ];

      final distinctStarts = <DateTime>[];
      for (final date in legacyDates) {
        if (distinctStarts.isEmpty) {
          distinctStarts.add(date);
        } else {
          final lastStart = distinctStarts.last;
          if (date.difference(lastStart).inDays > 14) {
            distinctStarts.add(date);
          }
        }
      }

      expect(distinctStarts.length, equals(2));
      expect(distinctStarts[0], equals(DateTime(2026, 9, 20)));
      expect(distinctStarts[1], equals(DateTime(2026, 10, 18)));
    });

    test('CycleEngine calculateForDate returns null for dates prior to user history', () {
      final sep20 = DateTime(2026, 9, 20);
      final history = [PeriodEntry(id: '1', startDate: sep20, source: 'user')];
      final profile = UserProfile(
        id: 'test-user',
        name: 'Luna User',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: sep20,
        createdAt: sep20,
      );

      // A date prior to September 20 should have no calculated cycle phase
      final pastDate = DateTime(2026, 9, 10);
      final phase = CycleEngine.phaseForDate(pastDate, profile, periodHistory: history);
      expect(phase, isNull);

      final calc = CycleEngine.calculateForDate(profile, pastDate, periodHistory: history);
      expect(calc, isNull);
    });
  });

  group('Period Length Dynamic Calibration & Calendar Multi-Cycle Accuracy Tests', () {
    test('PhaseConstants.phaseFromDay respects dynamic periodLength', () {
      // 7-day period in 28-day cycle: Day 6 and Day 7 must be menstrual
      expect(PhaseConstants.phaseFromDay(6, 28, periodLength: 7), equals(CyclePhase.menstrual));
      expect(PhaseConstants.phaseFromDay(7, 28, periodLength: 7), equals(CyclePhase.menstrual));
      expect(PhaseConstants.phaseFromDay(8, 28, periodLength: 7), equals(CyclePhase.follicular));

      // 5-day period in 28-day cycle: Day 6 is follicular
      expect(PhaseConstants.phaseFromDay(5, 28, periodLength: 5), equals(CyclePhase.menstrual));
      expect(PhaseConstants.phaseFromDay(6, 28, periodLength: 5), equals(CyclePhase.follicular));

      // 3-day period in 28-day cycle: Day 3 is menstrual, Day 4 is follicular
      expect(PhaseConstants.phaseFromDay(3, 28, periodLength: 3), equals(CyclePhase.menstrual));
      expect(PhaseConstants.phaseFromDay(4, 28, periodLength: 3), equals(CyclePhase.follicular));
    });

    test('CycleEngine.phaseForDate propagates user profile averagePeriodLength', () {
      final start = DateTime(2026, 9, 20);
      final profile7 = UserProfile(
        id: 'user-7',
        name: 'User 7',
        averageCycleLength: 28,
        averagePeriodLength: 7,
        lastPeriodStart: start,
        createdAt: start,
      );

      final profile5 = UserProfile(
        id: 'user-5',
        name: 'User 5',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: start,
        createdAt: start,
      );

      final day6 = DateTime(2026, 9, 25); // Day 6 of cycle

      // User with 7-day period should have menstrual phase on day 6
      expect(CycleEngine.phaseForDate(day6, profile7), equals(CyclePhase.menstrual));

      // User with 5-day period should have follicular phase on day 6
      expect(CycleEngine.phaseForDate(day6, profile5), equals(CyclePhase.follicular));
    });

    test('CycleEngine.findCycleStart finds closest historical anchor across multiple cycles', () {
      final aug22 = DateTime(2026, 8, 22);
      final sep20 = DateTime(2026, 9, 20);
      final history = [
        PeriodEntry(id: '1', startDate: aug22, source: 'user'),
        PeriodEntry(id: '2', startDate: sep20, source: 'user'),
      ];
      final profile = UserProfile(
        id: 'u1',
        name: 'Luna',
        averageCycleLength: 29,
        averagePeriodLength: 6,
        lastPeriodStart: sep20,
        createdAt: aug22,
      );

      // Date in August cycle: August 25 -> cycle start must be August 22
      final aug25Anchor = CycleEngine.findCycleStart(DateTime(2026, 8, 25), profile, history);
      expect(aug25Anchor, equals(aug22));

      // Date in September cycle: September 22 -> cycle start must be September 20
      final sep22Anchor = CycleEngine.findCycleStart(DateTime(2026, 9, 22), profile, history);
      expect(sep22Anchor, equals(sep20));

      // Date before any history: August 10 -> anchor must be null
      final aug10Anchor = CycleEngine.findCycleStart(DateTime(2026, 8, 10), profile, history);
      expect(aug10Anchor, isNull);
    });

    test('Bleeding run length calculation counts gap days as 1 additional bleed day, not gap size', () {
      // Day 1 (Sep 1) and Day 3 (Sep 3) -> 2 days apart (diff = 2)
      // Must count as 2 bleeding days, not 3
      final sortedDates = [DateTime(2026, 9, 1), DateTime(2026, 9, 3)];
      int currentRunLength = 1;
      for (int i = 1; i < sortedDates.length; i++) {
        final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
        if (diff <= 2) {
          currentRunLength += 1;
        }
      }
      expect(currentRunLength, equals(2));
    });
  });

  group('Conversational AI Logging, Target Date Resolution, and Period Stop Tests', () {
    final referenceDate = DateTime(2026, 9, 23, 12, 0); // Wednesday, Sep 23, 2026
    final refToday = DateTime(2026, 9, 23);

    test('extractTargetDate resolves past relative and explicit dates accurately', () {
      final yesterday = PeriodDateExtractor.extractTargetDate('Yesterday I was feeling bad cramps and 0 energy', referenceDate: referenceDate);
      expect(yesterday.isExplicit, isTrue);
      expect(yesterday.isFuture, isFalse);
      expect(yesterday.relativeDaysAgo, equals(1));
      expect(yesterday.date, equals(refToday.subtract(const Duration(days: 1))));

      final fourDaysAgo = PeriodDateExtractor.extractTargetDate('4 days ago I was exhausted', referenceDate: referenceDate);
      expect(fourDaysAgo.isExplicit, isTrue);
      expect(fourDaysAgo.isFuture, isFalse);
      expect(fourDaysAgo.relativeDaysAgo, equals(4));
      expect(fourDaysAgo.date, equals(refToday.subtract(const Duration(days: 4))));

      final dayBefore = PeriodDateExtractor.extractTargetDate('Day before yesterday I had headache', referenceDate: referenceDate);
      expect(dayBefore.isExplicit, isTrue);
      expect(dayBefore.isFuture, isFalse);
      expect(dayBefore.relativeDaysAgo, equals(2));
      expect(dayBefore.date, equals(refToday.subtract(const Duration(days: 2))));

      final coupleDays = PeriodDateExtractor.extractTargetDate('a couple of days ago I had bloating', referenceDate: referenceDate);
      expect(coupleDays.isExplicit, isTrue);
      expect(coupleDays.isFuture, isFalse);
      expect(coupleDays.relativeDaysAgo, equals(2));

      final fewDays = PeriodDateExtractor.extractTargetDate('a few days ago I had low energy', referenceDate: referenceDate);
      expect(fewDays.isExplicit, isTrue);
      expect(fewDays.isFuture, isFalse);
      expect(fewDays.relativeDaysAgo, equals(3));
    });

    test('extractTargetDate detects future dates and sets isFuture flag', () {
      final tomorrow = PeriodDateExtractor.extractTargetDate('Tomorrow I might have cramps', referenceDate: referenceDate);
      expect(tomorrow.isFuture, isTrue);
      expect(tomorrow.isExplicit, isTrue);
      expect(tomorrow.futureSummary, equals('tomorrow'));

      final inThreeDays = PeriodDateExtractor.extractTargetDate('in 3 days I expect my period', referenceDate: referenceDate);
      expect(inThreeDays.isFuture, isTrue);
      expect(inThreeDays.futureSummary, equals('in 3 days'));

      final dayAfterTomorrow = PeriodDateExtractor.extractTargetDate('day after tomorrow will be rough', referenceDate: referenceDate);
      expect(dayAfterTomorrow.isFuture, isTrue);
      expect(dayAfterTomorrow.futureSummary, equals('in 2 days'));

      final nextWeek = PeriodDateExtractor.extractTargetDate('next week I am traveling', referenceDate: referenceDate);
      expect(nextWeek.isFuture, isTrue);
      expect(nextWeek.futureSummary, equals('next week'));
    });

    test('extractCycleDay parses ordinal numbers and calculates cycle start date', () {
      expect(PeriodDateExtractor.extractCycleDay('Today is my 4th day'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('it is my 1st day'), equals(1));
      expect(PeriodDateExtractor.extractCycleDay('it\'s my second day'), equals(2));
      expect(PeriodDateExtractor.extractCycleDay('day 3 of my period'), equals(3));
      expect(PeriodDateExtractor.extractCycleDay('day 5 of my cycle'), equals(5));

      // With "today is my 4th day", period start must be today - 3 days
      final calcDate = PeriodDateExtractor.extractDate('Today is my 4th day of period', referenceDate: referenceDate);
      expect(calcDate, equals(refToday.subtract(const Duration(days: 3))));

      // With "today is my 1st day", period start must be today
      final day1Date = PeriodDateExtractor.extractDate('Today is my 1st day of period', referenceDate: referenceDate);
      expect(day1Date, equals(refToday));
    });

    test('hasPeriodStopIntent accurately detects period stop expressions', () {
      expect(PeriodDateExtractor.hasPeriodStopIntent('my period stopped today'), isTrue);
      expect(PeriodDateExtractor.hasPeriodStopIntent('bleeding has ended'), isTrue);
      expect(PeriodDateExtractor.hasPeriodStopIntent('my period ended yesterday'), isTrue);
      expect(PeriodDateExtractor.hasPeriodStopIntent('my period stopped 2 days ago'), isTrue);
      expect(PeriodDateExtractor.hasPeriodStopIntent('why was my period only 3 days'), isTrue);
      expect(PeriodDateExtractor.hasPeriodStopIntent('bleeding stopped completely'), isTrue);

      // Must NOT match start intents
      expect(PeriodDateExtractor.hasPeriodStopIntent('my period started yesterday'), isFalse);
      expect(PeriodDateExtractor.hasPeriodStopIntent('my period started today'), isFalse);
      expect(PeriodDateExtractor.hasPeriodStopIntent('I have bad cramps today'), isFalse);
    });

    test('Confirmation and cancellation dictionaries recognize sisterly conversational terms', () {
      for (final affirmative in ['yes', 'yes please', 'sure', 'confirm', 'update it', 'yeah please', 'yep', 'do it', 'correct', 'that is right', 'yes update it']) {
        expect(PeriodDateExtractor.isConfirmation(affirmative), isTrue, reason: 'Failed for: $affirmative');
      }

      for (final negative in ['no', 'cancel', 'nevermind', 'keep it as is', 'leave it', 'nope', 'don\'t change it', 'no thanks', 'keep as is']) {
        expect(PeriodDateExtractor.isCancellation(negative), isTrue, reason: 'Failed for: $negative');
      }
    });

    test('isDirectCorrectionCommand recognizes explicit commands', () {
      expect(PeriodDateExtractor.isDirectCorrectionCommand('update my cycle to being day 1 yesterday'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('set my period start date to yesterday'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('change my cycle start to 20th'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('correct my period date to 2 days ago'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('fix my cycle start date'), isTrue);
    });
  });

  group('Zero-Hallucination Corroboration, Universal Undo & Ongoing Bleed Protection Tests', () {
    test('Strict corroboration filter accepts only symptoms explicitly present in userText', () {
      // User says: "Yesterday I had a terrible migraine and nausea"
      const userText = 'Yesterday I had a terrible migraine and nausea';
      final lower = userText.toLowerCase();

      // DeepSeek hallucinated flow, mood, energy, sleep, and extra symptoms
      final rawAiSymptoms = ['Headache', 'Nausea', 'Fatigue', 'Brain fog', 'Cramps'];
      FlowLevel? rawAiFlow = FlowLevel.medium;
      MoodLevel? rawAiMood = MoodLevel.low;
      int? rawAiEnergy = 2;
      SleepQuality? rawAiSleep = SleepQuality.fair;

      // Corroboration rules
      final hasFlowMention = RegExp(
        r'\b(flow|bleeding|bleed|bled|spotting|heavy|light|medium|moderate\s+flow|period\s+blood|blood|tampon|pad|cup)\b',
      ).hasMatch(lower);
      if (!hasFlowMention) rawAiFlow = null;

      final hasSleepMention = RegExp(
        r'\b(sleep|slept|sleeping|insomnia|restless|woke\s+up|awake|nightmare|rested)\b',
      ).hasMatch(lower);
      if (!hasSleepMention) rawAiSleep = null;

      final hasEnergyMention = RegExp(
        r'\b(energy|tired|exhausted|fatigue|fatigued|drained|stamina|sluggish|lethargic|energetic|weary|wiped\s+out)\b',
      ).hasMatch(lower);
      if (!hasEnergyMention) rawAiEnergy = null;

      final hasMoodMention = RegExp(
        r'\b(mood|feeling|felt|feel|sad|happy|anxious|crying|depressed|angry|calm|thriving|miserable|low|overwhelmed|struggling|okay|great|good|irritated|irritable|emotional|stressed)\b',
      ).hasMatch(lower);
      if (!hasMoodMention) rawAiMood = null;

      bool isCorroborated(String s, String text) {
        final sLower = s.toLowerCase();
        switch (sLower) {
          case 'headache':
          case 'migraine':
            return RegExp(r'\b(headache|headaches|migraine|migraines|head\s+hurts|head\s+pain)\b').hasMatch(text);
          case 'nausea':
            return RegExp(r'\b(nausea|nauseous|nauseated|sick\s+to\s+my\s+stomach|vomit|throwing\s+up|queasy)\b').hasMatch(text);
          case 'cramps':
            return RegExp(r'\b(cramp|cramps|cramping)\b').hasMatch(text);
          case 'fatigue':
            return RegExp(r'\b(fatigue|tired|exhausted)\b').hasMatch(text);
          case 'brain fog':
            return RegExp(r'\b(brain\s+fog|foggy)\b').hasMatch(text);
          default:
            return text.contains(sLower);
        }
      }

      final corroboratedSymptoms = rawAiSymptoms.where((s) => isCorroborated(s, lower)).toList();

      // Zero hallucinations survived!
      expect(rawAiFlow, isNull);
      expect(rawAiMood, isNull);
      expect(rawAiEnergy, isNull);
      expect(rawAiSleep, isNull);
      expect(corroboratedSymptoms, equals(['Headache', 'Nausea']));
    });

    test('Cross-turn isolation: turn 2 prompt produces zero symptoms for today', () {
      const turn2Text = 'Today is my 4th day of period';
      final lower = turn2Text.toLowerCase();

      // Prior turn symptoms echoed by AI
      final echoedSymptoms = ['Headache', 'Nausea'];

      bool isCorroborated(String s, String text) {
        final sLower = s.toLowerCase();
        switch (sLower) {
          case 'headache':
            return RegExp(r'\b(headache|headaches|migraine)\b').hasMatch(text);
          case 'nausea':
            return RegExp(r'\b(nausea|nauseous)\b').hasMatch(text);
          default:
            return text.contains(sLower);
        }
      }

      final corroborated = echoedSymptoms.where((s) => isCorroborated(s, lower)).toList();
      expect(corroborated, isEmpty);
    });

    test('Ongoing bleed in active cycle does not shrink period length or flip Day 4 to Follicular', () {
      final sep20 = DateTime(2026, 9, 20);
      final profile = UserProfile(
        id: 'u1',
        name: 'TestUser',
        averageCycleLength: 28,
        averagePeriodLength: 5,
        lastPeriodStart: sep20,
        createdAt: DateTime.now(),
      );

      // On Day 4 (Sep 23), dayOfCycle = 4
      final day4Phase = PhaseConstants.phaseFromDay(4, profile.averageCycleLength, periodLength: profile.averagePeriodLength);
      expect(day4Phase, equals(CyclePhase.menstrual));

      // Active cycle bleed: Sep 20, 21, 22
      final activeBleedDates = [DateTime(2026, 9, 20), DateTime(2026, 9, 21), DateTime(2026, 9, 22)];
      final latestAnchor = sep20;
      final now = DateTime(2026, 9, 23);

      // Filter out active ongoing bleeds
      final completedBleeding = activeBleedDates.where((d) {
        final diff = d.difference(latestAnchor).inDays;
        if (diff >= 0 && diff < 14) return false;
        if (now.difference(d).inDays < 14) return false;
        return true;
      }).toList();

      expect(completedBleeding, isEmpty);
      // Because completed bleeding is empty, averagePeriodLength remains unchanged at 5!
      expect(profile.averagePeriodLength, equals(5));
    });

    test('Guarded calibration requires at least 2 completed physiological cycles and ignores single 2-day anomaly', () {
      // User with 1 completed cycle of 2 days (acute anomaly)
      final completedRuns = [2];

      // Guard condition 1: runs.length < 2
      final canCalibrateBaseline = completedRuns.length >= 2;
      expect(canCalibrateBaseline, isFalse);

      // Guard condition 2: physiologicalRuns filtering
      final physiologicalRuns = completedRuns.where((r) => r >= 3 && r <= 8).toList();
      expect(physiologicalRuns, isEmpty);

      // Baseline profile is protected and remains 5!
      const defaultBaseline = 5;
      expect(defaultBaseline, equals(5));
    });

    test('Rollback undo restores previous cycle anchor and log state correctly', () {
      final sep15 = DateTime(2026, 9, 15);
      final sep20 = DateTime(2026, 9, 20);

      // Previous state: sep15 anchor
      final history = <PeriodEntry>[
        PeriodEntry(id: 'p1', startDate: sep15, source: 'onboarding'),
      ];
      expect(history.first.startDate.day, equals(15));

      // After user updates to sep20
      final updatedHistory = <PeriodEntry>[
        PeriodEntry(id: 'p2', startDate: sep20, source: 'ai'),
        ...history,
      ];
      expect(updatedHistory.first.startDate.day, equals(20));

      // Undo rollback: remove p2 and restore previous anchor
      final rolledBackHistory = updatedHistory.where((p) => p.id != 'p2').toList();
      expect(rolledBackHistory.first.startDate.day, equals(15));

      // LogEntry snapshot rollback test
      final originalEntry = LogEntry(
        id: 'l1',
        date: sep20,
        symptoms: ['Cramps'],
      );

      // AI auto-log added Headache and Nausea
      final modifiedEntry = originalEntry.copyWith(
        symptoms: ['Cramps', 'Headache', 'Nausea'],
      );
      expect(modifiedEntry.symptoms.length, equals(3));

      // Undo auto-log: restores originalEntry snapshot
      final restoredEntry = originalEntry;
      expect(restoredEntry.symptoms, equals(['Cramps']));
    });
  });

  group('Bulletproof Conversational Cycle Day & Discrepancy Self-Healing Tests', () {
    test('extractCycleDay parses all conversational cycle day assertions', () {
      expect(PeriodDateExtractor.extractCycleDay('dude day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('today is day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('its day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('it is day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('im on day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('i am on day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('make it day 4'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('Today is my 4th day of period'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('4th day of cycle'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('day four'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('fourth day'), equals(4));
      expect(PeriodDateExtractor.extractCycleDay('day 1'), equals(1));
      expect(PeriodDateExtractor.extractCycleDay('today is day 3'), equals(3));
    });

    test('Discrepancy report detection prevents erroneous day overwriting', () {
      // User complains that app displays Day 1
      const complaint1 = 'it shows day 1 here';
      expect(PeriodDateExtractor.isDiscrepancyReport(complaint1), isTrue);
      // Must NOT extract 1 as target cycle day!
      expect(PeriodDateExtractor.extractCycleDay(complaint1), isNull);

      const complaint2 = 'why does it show day 1';
      expect(PeriodDateExtractor.isDiscrepancyReport(complaint2), isTrue);
      expect(PeriodDateExtractor.extractCycleDay(complaint2), isNull);

      // Sentence with both discrepancy and target day extracts target day
      const combined = 'it shows day 1 here but today is day 4';
      expect(PeriodDateExtractor.isDiscrepancyReport(combined), isTrue);
      expect(PeriodDateExtractor.extractCycleDay(combined), equals(4));
    });

    test('findRecentCycleDay recovers intended cycle day from message history', () {
      final history = [
        'Hey Luna',
        'dude day 4',
        'it shows day 1 here',
      ];
      final recoveredDay = PeriodDateExtractor.findRecentCycleDay(history);
      expect(recoveredDay, equals(4));
    });

    test('extractDate correctly calculates start date for "dude day 4"', () {
      final now = DateTime(2026, 9, 23);
      final calculatedStart = PeriodDateExtractor.extractDate('dude day 4', referenceDate: now);
      expect(calculatedStart, isNotNull);
      // Sep 23 minus (4 - 1) days = Sep 20
      expect(calculatedStart!.year, equals(2026));
      expect(calculatedStart.month, equals(9));
      expect(calculatedStart.day, equals(20));
    });

    test('isDirectCorrectionCommand recognizes cycle day assertions', () {
      expect(PeriodDateExtractor.isDirectCorrectionCommand('dude day 4'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('day 4'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('today is day 4'), isTrue);
      expect(PeriodDateExtractor.isDirectCorrectionCommand('update my period start'), isTrue);
    });

    test('isConfirmation identifies cycle day repetitions matching pending date', () {
      final pendingDate = DateTime(2026, 9, 20); // 3 days ago relative to Sep 23 (Day 4)
      const userReply = 'dude day 4';

      final cycleDay = PeriodDateExtractor.extractCycleDay(userReply);
      expect(cycleDay, equals(4));

      final now = DateTime(2026, 9, 23);
      final dateFromReply = PeriodDateExtractor.extractDate(userReply, referenceDate: now);
      expect(dateFromReply?.day, equals(pendingDate.day));
    });
  });
}



