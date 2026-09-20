import '../constants/phase_constants.dart';
import '../models/log_entry.dart';
import '../models/user_profile.dart';
import '../models/period_entry.dart';
import 'cycle_engine.dart';

/// Represents a single biomarker pattern discovered from historical logs
class DiscoveredPattern {
  final String id;
  final String title;
  final String category; // 'Energy', 'Mood', 'Symptoms', 'Nutrition', 'Rhythm'
  final String emoji;
  final String description;
  final String clinicalInsight;
  final String confidence; // 'Emerging', 'Confirmed', 'High Confidence'
  final List<int> cycleDays;
  final CyclePhase? associatedPhase;

  const DiscoveredPattern({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.description,
    required this.clinicalInsight,
    required this.confidence,
    this.cycleDays = const [],
    this.associatedPhase,
  });
}

/// Comprehensive longitudinal intelligence profile built from user logs
class LongitudinalProfile {
  final int totalLogsAnalyzed;
  final int estimatedCyclesTracked;
  final double averageEnergy;
  final Map<CyclePhase, double> phaseEnergyAverages;
  final Map<CyclePhase, List<String>> dominantPhaseSymptoms;
  final List<DiscoveredPattern> patterns;
  final String aiContextDigest;

  const LongitudinalProfile({
    required this.totalLogsAnalyzed,
    required this.estimatedCyclesTracked,
    required this.averageEnergy,
    required this.phaseEnergyAverages,
    required this.dominantPhaseSymptoms,
    required this.patterns,
    required this.aiContextDigest,
  });

  bool get hasSufficientData => totalLogsAnalyzed >= 7;
  bool get hasPatterns => patterns.isNotEmpty;
  int get calibrationTarget => 7;
  double get calibrationProgress => (totalLogsAnalyzed / 7).clamp(0.0, 1.0);
}

class PatternAnalysisService {
  /// Analyzes all recorded logs against user cycle profile to extract longitudinal patterns
  static LongitudinalProfile analyze({
    required List<LogEntry> logs,
    required UserProfile profile,
    List<PeriodEntry>? periodHistory,
  }) {
    // Only analyze logs that contain actual biomarker observations (mood, energy, sleep, flow, cramps, symptoms, notes).
    // Bare period anchor records (with only periodStarted = true) do NOT count as health check-ins.
    final biomarkerLogs = logs.where((e) => e.hasBiomarkerData).toList();
    if (biomarkerLogs.isEmpty) {
      return _emptyProfile();
    }

    final cycleLength = profile.averageCycleLength > 0 ? profile.averageCycleLength : 28;
    final totalLogs = biomarkerLogs.length;

    // 1. Group biomarker logs by phase
    final phaseLogs = <CyclePhase, List<LogEntry>>{
      CyclePhase.menstrual: [],
      CyclePhase.follicular: [],
      CyclePhase.ovulatory: [],
      CyclePhase.earlyLuteal: [],
      CyclePhase.lateLuteal: [],
    };

    // Day of cycle mapping (1-indexed) -> logs
    final cycleDayLogs = <int, List<LogEntry>>{};

    double energySum = 0;
    int energyCount = 0;
    for (final log in biomarkerLogs) {
      if (log.energyLevel != null) {
        energySum += log.energyLevel!;
        energyCount++;
      }
      final phase = CycleEngine.phaseForDate(log.date, profile, periodHistory: periodHistory);
      phaseLogs[phase]?.add(log);

      // Estimate cycle day if anchor exists
      if (profile.lastPeriodStart != null) {
        final inDays =
            log.date.calendarDaysDifference(profile.lastPeriodStart!);
        // Bug 8 fix: skip logs that predate the anchor — they have no valid
        // cycle day. Also use a Dart-safe positive modulo so day is always
        // in range [1..cycleLength], regardless of Dart's signed % behavior.
        if (inDays < 0) continue;
        final day =
            ((inDays % cycleLength) + cycleLength) % cycleLength + 1;
        cycleDayLogs.putIfAbsent(day, () => []).add(log);
      }
    }

    final averageEnergy = energyCount > 0 ? energySum / energyCount : 3.0;

    // 2. Compute phase energy averages
    final phaseEnergyAverages = <CyclePhase, double>{};
    for (final entry in phaseLogs.entries) {
      if (entry.value.isEmpty) {
        phaseEnergyAverages[entry.key] = 3.0;
      } else {
        final energyLogs = entry.value.where((e) => e.energyLevel != null).toList();
        if (energyLogs.isEmpty) {
          phaseEnergyAverages[entry.key] = 3.0;
        } else {
          final sum = energyLogs.fold<int>(0, (prev, e) => prev + e.energyLevel!);
          phaseEnergyAverages[entry.key] = sum / energyLogs.length;
        }
      }
    }

    // 3. Compute dominant symptoms per phase
    final dominantPhaseSymptoms = <CyclePhase, List<String>>{};
    for (final entry in phaseLogs.entries) {
      final symptomCounts = <String, int>{};
      for (final log in entry.value) {
        for (final s in log.symptoms) {
          final trimmed = s.trim();
          if (trimmed.isNotEmpty) {
            symptomCounts[trimmed] = (symptomCounts[trimmed] ?? 0) + 1;
          }
        }
      }
      final sorted = symptomCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      dominantPhaseSymptoms[entry.key] = sorted.take(3).map((e) => e.key).toList();
    }

    // 4. Estimate cycles tracked accurately from period history gaps
    int estimatedCycles = 1;
    if (periodHistory != null && periodHistory.length >= 2) {
      final sortedPeriods = [...periodHistory]..sort((a, b) => a.startDate.compareTo(b.startDate));
      int validCycles = 0;
      for (int i = 1; i < sortedPeriods.length; i++) {
        final a = DateTime.utc(sortedPeriods[i].startDate.year, sortedPeriods[i].startDate.month, sortedPeriods[i].startDate.day);
        final b = DateTime.utc(sortedPeriods[i - 1].startDate.year, sortedPeriods[i - 1].startDate.month, sortedPeriods[i - 1].startDate.day);
        final gap = a.difference(b).inDays;
        if (gap >= 14 && gap <= 60) validCycles++;
      }
      estimatedCycles = (validCycles + 1).clamp(1, 12);
    }

    // 5. Discover distinct personal patterns
    final patterns = <DiscoveredPattern>[];

    final lateLutealLogs = phaseLogs[CyclePhase.lateLuteal] ?? [];
    final follicularLogs = phaseLogs[CyclePhase.follicular] ?? [];
    final ovulatoryLogs = phaseLogs[CyclePhase.ovulatory] ?? [];
    final menstrualLogs = phaseLogs[CyclePhase.menstrual] ?? [];

    final distinctPhasesWithData = phaseLogs.values.where((l) => l.isNotEmpty).length;

    // Enforce rigorous threshold: Luna requires at least 7 biomarker logs across the cycle
    // spanning at least 2 distinct phases before declaring personal patterns.
    if (totalLogs >= 7 && distinctPhasesWithData >= 2) {
      final lateLutealEnergyLogs = lateLutealLogs.where((e) => e.energyLevel != null).toList();
      final follicularEnergyLogs = follicularLogs.where((e) => e.energyLevel != null).toList();
      final ovulatoryEnergyLogs = ovulatoryLogs.where((e) => e.energyLevel != null).toList();
      final lateLutealEnergy = phaseEnergyAverages[CyclePhase.lateLuteal] ?? 3.0;
      final follicularEnergy = phaseEnergyAverages[CyclePhase.follicular] ?? 3.0;
      final ovulatoryEnergy = phaseEnergyAverages[CyclePhase.ovulatory] ?? 3.0;

      // Pattern A: Luteal Energy Crash (requires >= 3 late luteal & >= 2 follicular logs)
      if (lateLutealEnergyLogs.length >= 3 && follicularEnergyLogs.length >= 2) {
        if (lateLutealEnergy <= 2.4 || (follicularEnergy - lateLutealEnergy) >= 1.0) {
          patterns.add(DiscoveredPattern(
            id: 'luteal_energy_trough',
            title: 'Late-Luteal Energy Trough',
            category: 'Energy',
            emoji: '📉',
            description: 'Your stamina drops in the late luteal phase (avg ${lateLutealEnergy.toStringAsFixed(1)}/5 vs ${follicularEnergy.toStringAsFixed(1)}/5 in follicular).',
            clinicalInsight: 'Rising progesterone and falling estrogen elevate basal body temperature and alter GABA receptors. This physiological shift calls for restorative pacing rather than pushing through.',
            confidence: lateLutealEnergyLogs.length >= 5 || estimatedCycles >= 2 ? 'Confirmed' : 'Emerging',
            cycleDays: [cycleLength - 5, cycleLength - 4, cycleLength - 3, cycleLength - 2, cycleLength - 1],
            associatedPhase: CyclePhase.lateLuteal,
          ));
        }
      }

      // Pattern B: Estrogen Dopamine Surge (requires >= 2 follicular & >= 2 ovulatory logs)
      if (follicularEnergyLogs.length >= 2 && ovulatoryEnergyLogs.length >= 2) {
        if (follicularEnergy >= 3.8 || ovulatoryEnergy >= 3.8) {
          patterns.add(DiscoveredPattern(
            id: 'estrogen_dopamine_peak',
            title: 'Estrogen Peak Acceleration',
            category: 'Energy',
            emoji: '⚡',
            description: 'Pronounced stamina and focus across Days 10–14 (avg ${ovulatoryEnergy.toStringAsFixed(1)}/5 energy).',
            clinicalInsight: 'Estrogen sensitizes dopamine D2 receptors in the prefrontal cortex, enhancing focus, verbal memory, and metabolic efficiency.',
            confidence: (follicularEnergyLogs.length + ovulatoryEnergyLogs.length) >= 6 ? 'Confirmed' : 'Emerging',
            cycleDays: [10, 11, 12, 13, 14],
            associatedPhase: CyclePhase.ovulatory,
          ));
        }
      }

      // Pattern C: Late Luteal Mood Sensitivity (requires >= 3 late luteal logs & >= 2 sensitive logs)
      final sensitiveMoodLogs = lateLutealLogs.where(
        (l) => l.mood == MoodLevel.struggling || l.mood == MoodLevel.low,
      ).length;
      if (lateLutealLogs.length >= 3 && sensitiveMoodLogs >= 2 && (sensitiveMoodLogs / lateLutealLogs.length) >= 0.5) {
        patterns.add(DiscoveredPattern(
          id: 'pms_mood_vulnerability',
          title: 'Premenstrual Emotional Sensitivity',
          category: 'Mood',
          emoji: '💜',
          description: 'A recurring shift toward emotional tenderness in late luteal ($sensitiveMoodLogs of ${lateLutealLogs.length} late luteal check-ins).',
          clinicalInsight: 'The acute drop in allopregnanolone alters GABA-A receptor plasticity, heightening emotional processing. Protecting boundaries and avoiding stimulants 4 days pre-bleed is profoundly protective.',
          confidence: lateLutealLogs.length >= 5 ? 'Confirmed' : 'Emerging',
          cycleDays: [cycleLength - 4, cycleLength - 3, cycleLength - 2, cycleLength - 1],
          associatedPhase: CyclePhase.lateLuteal,
        ));
      }

      // Pattern D: Cramp Velocity Pattern (requires >= 3 menstrual logs & >= 2 cramp logs)
      final crampLogs = menstrualLogs.where(
        (l) => l.cramps == CrampLevel.moderate || l.cramps == CrampLevel.severe,
      ).length;
      if (menstrualLogs.length >= 3 && crampLogs >= 2) {
        patterns.add(DiscoveredPattern(
          id: 'cramp_velocity',
          title: 'Early-Bleed Prostaglandin Spike',
          category: 'Symptoms',
          emoji: '🩸',
          description: 'Uterine cramping clusters predictably during Days 1–2 of bleeding before tapering off.',
          clinicalInsight: 'Uterine contractions driven by PGF2-alpha prostaglandins peak within the first 36 hours. Early warmth and magnesium glycinate before flow begins minimizes prostaglandin accumulation.',
          confidence: menstrualLogs.length >= 5 ? 'Confirmed' : 'Emerging',
          cycleDays: [1, 2],
          associatedPhase: CyclePhase.menstrual,
        ));
      }

      // Pattern E: Sugar & Craving Marker (requires >= 10 total logs & >= 2 luteal cravings)
      final lutealCravingLogs = lateLutealLogs.where(
        (l) => l.symptoms.any((s) => s.toLowerCase().contains('crav') || s.toLowerCase().contains('sweet') || s.toLowerCase().contains('choc')),
      ).length;
      if (totalLogs >= 10 && lutealCravingLogs >= 2) {
        patterns.add(DiscoveredPattern(
          id: 'magnesium_sugar_craving',
          title: 'Luteal Micronutrient Craving Signal',
          category: 'Nutrition',
          emoji: '🍫',
          description: 'Carbohydrate and chocolate cravings consistently emerge 24–72 hours prior to your period.',
          clinicalInsight: 'Metabolic demand rises ~150–300 kcal/day in late luteal while cellular magnesium drops. Your cravings are intelligent biological signals for calories and magnesium.',
          confidence: lutealCravingLogs >= 4 ? 'Confirmed' : 'Emerging',
          cycleDays: [cycleLength - 3, cycleLength - 2, cycleLength - 1],
          associatedPhase: CyclePhase.lateLuteal,
        ));
      }
    }

    // 6. Build AI Context Digest for DeepSeek System Prompt
    final digestBuffer = StringBuffer();
    digestBuffer.writeln('LONGITUDINAL BIOMARKER DISCOVERIES & PERSONALIZED PATTERNS:');
    digestBuffer.writeln('- Total Health Logs Analyzed: $totalLogs across ~$estimatedCycles cycle(s)');
    digestBuffer.writeln('- Overall Energy Baseline: ${averageEnergy.toStringAsFixed(1)}/5');
    digestBuffer.writeln('- Energy By Phase: Follicular: ${phaseEnergyAverages[CyclePhase.follicular]?.toStringAsFixed(1)}/5 | Ovulation: ${phaseEnergyAverages[CyclePhase.ovulatory]?.toStringAsFixed(1)}/5 | Luteal: ${phaseEnergyAverages[CyclePhase.lateLuteal]?.toStringAsFixed(1)}/5 | Menstrual: ${phaseEnergyAverages[CyclePhase.menstrual]?.toStringAsFixed(1)}/5');

    if (dominantPhaseSymptoms.isNotEmpty) {
      digestBuffer.writeln('- Frequently Recurring Symptoms by Phase:');
      for (final entry in dominantPhaseSymptoms.entries) {
        if (entry.value.isNotEmpty) {
          digestBuffer.writeln('  * ${entry.key.name}: ${entry.value.join(', ')}');
        }
      }
    }

    digestBuffer.writeln('- Verified Personal Behavioral & Physiological Patterns:');
    if (patterns.isEmpty) {
      digestBuffer.writeln('  * Baseline calibration in progress ($totalLogs/7 check-ins). No recurring hormonal deviations confirmed yet. Provide observant, supportive guidance without assuming unverified patterns.');
    } else {
      for (final p in patterns) {
        digestBuffer.writeln('  * [${p.category}] ${p.title} (${p.confidence}): ${p.description}');
      }
    }

    digestBuffer.writeln();
    digestBuffer.writeln('EXECUTIVE PERSONALIZATION MANDATE FOR LUNA:');
    digestBuffer.writeln('1. Speak with intimate memory of her documented history. You are NOT a textbook; you are HER personal companion who has tracked her for $totalLogs days.');
    digestBuffer.writeln('2. Directly cite her known tendencies whenever relevant (e.g., "Looking back at your past cycles, Day $cycleLength is consistently when your energy dips like this..." or "Your pattern shows high estrogen sensitivity...").');
    digestBuffer.writeln('3. Contrast her current feeling with her personal average. If she is struggling today, remind her that this is a recognized milestone in her rhythm and tell her exactly when her surge usually returns.');
    digestBuffer.writeln('4. NEVER offer cookie-cutter or robotic generic advice.');

    return LongitudinalProfile(
      totalLogsAnalyzed: totalLogs,
      estimatedCyclesTracked: estimatedCycles,
      averageEnergy: averageEnergy,
      phaseEnergyAverages: phaseEnergyAverages,
      dominantPhaseSymptoms: dominantPhaseSymptoms,
      patterns: patterns,
      aiContextDigest: digestBuffer.toString(),
    );
  }

  static LongitudinalProfile _emptyProfile() {
    return const LongitudinalProfile(
      totalLogsAnalyzed: 0,
      estimatedCyclesTracked: 0,
      averageEnergy: 3.0,
      phaseEnergyAverages: {},
      dominantPhaseSymptoms: {},
      patterns: [],
      aiContextDigest: 'No historical health logs recorded yet. This is her initial check-in session.',
    );
  }
}
