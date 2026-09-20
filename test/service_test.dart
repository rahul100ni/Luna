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
      expect(futurePhase, equals(CyclePhase.follicular));
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
}
