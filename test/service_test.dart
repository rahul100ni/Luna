import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luna_app/core/constants/phase_constants.dart';
import 'package:luna_app/core/models/log_entry.dart';
import 'package:luna_app/core/services/deepseek_service.dart';
import 'package:luna_app/core/services/storage_service.dart';

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
}
