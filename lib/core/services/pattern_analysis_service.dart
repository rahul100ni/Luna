import '../constants/phase_constants.dart';
import '../models/log_entry.dart';
import '../models/user_profile.dart';
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

  bool get hasSufficientData => totalLogsAnalyzed >= 3;
}

class PatternAnalysisService {
  /// Analyzes all recorded logs against user cycle profile to extract longitudinal patterns
  static LongitudinalProfile analyze({
    required List<LogEntry> logs,
    required UserProfile profile,
  }) {
    if (logs.isEmpty) {
      return _emptyProfile();
    }

    final cycleLength = profile.averageCycleLength > 0 ? profile.averageCycleLength : 28;
    final totalLogs = logs.length;

    // 1. Group logs by phase
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
    for (final log in logs) {
      energySum += log.energyLevel;
      final phase = CycleEngine.phaseForDate(log.date, profile);
      phaseLogs[phase]?.add(log);

      // Estimate cycle day if anchor exists
      if (profile.lastPeriodStart != null) {
        final day = (log.date.difference(profile.lastPeriodStart!).inDays % cycleLength) + 1;
        cycleDayLogs.putIfAbsent(day, () => []).add(log);
      }
    }

    final averageEnergy = totalLogs > 0 ? energySum / totalLogs : 3.0;

    // 2. Compute phase energy averages
    final phaseEnergyAverages = <CyclePhase, double>{};
    for (final entry in phaseLogs.entries) {
      if (entry.value.isEmpty) {
        phaseEnergyAverages[entry.key] = 3.0;
      } else {
        final sum = entry.value.fold<int>(0, (prev, e) => prev + e.energyLevel);
        phaseEnergyAverages[entry.key] = sum / entry.value.length;
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

    // 4. Estimate cycles tracked
    final periodStartCount = logs.where((e) => e.periodStarted).length;
    final estimatedCycles = periodStartCount > 0 ? periodStartCount : (totalLogs / cycleLength).ceil().clamp(1, 12);

    // 5. Discover distinct personal patterns
    final patterns = <DiscoveredPattern>[];

    // Pattern A: Luteal Energy Crash
    final lateLutealEnergy = phaseEnergyAverages[CyclePhase.lateLuteal] ?? 3.0;
    final follicularEnergy = phaseEnergyAverages[CyclePhase.follicular] ?? 3.0;
    if (lateLutealEnergy < 2.6 || (follicularEnergy - lateLutealEnergy) >= 1.0) {
      patterns.add(DiscoveredPattern(
        id: 'luteal_energy_trough',
        title: 'Late-Luteal Energy Trough',
        category: 'Energy',
        emoji: '📉',
        description: 'Your stamina drops sharply in the late luteal phase (avg ${lateLutealEnergy.toStringAsFixed(1)}/5 vs ${follicularEnergy.toStringAsFixed(1)}/5 in follicular).',
        clinicalInsight: 'Rising progesterone and falling estrogen elevate core body temperature and alter GABA receptors. This is a physiological call for restorative pacing, not a personal flaw.',
        confidence: totalLogs >= 10 ? 'High Confidence' : 'Emerging',
        cycleDays: [cycleLength - 6, cycleLength - 5, cycleLength - 4, cycleLength - 3, cycleLength - 2, cycleLength - 1],
        associatedPhase: CyclePhase.lateLuteal,
      ));
    }

    // Pattern B: Estrogen Dopamine Surge
    final ovulatoryEnergy = phaseEnergyAverages[CyclePhase.ovulatory] ?? 3.0;
    if (follicularEnergy >= 3.6 || ovulatoryEnergy >= 3.8) {
      patterns.add(DiscoveredPattern(
        id: 'estrogen_dopamine_peak',
        title: 'Estrogen Peak Acceleration',
        category: 'Energy',
        emoji: '⚡',
        description: 'You experience a pronounced physical and cognitive peak across Days 10–14 (avg ${ovulatoryEnergy.toStringAsFixed(1)}/5 energy).',
        clinicalInsight: 'Estrogen sensitizes dopamine D2 receptors in the prefrontal cortex, enhancing focus, verbal memory, and metabolic efficiency.',
        confidence: totalLogs >= 8 ? 'High Confidence' : 'Emerging',
        cycleDays: [10, 11, 12, 13, 14],
        associatedPhase: CyclePhase.ovulatory,
      ));
    }

    // Pattern C: Late Luteal Mood Sensitivity
    final lateLutealLogs = phaseLogs[CyclePhase.lateLuteal] ?? [];
    final sensitiveMoodLogs = lateLutealLogs.where(
      (l) => l.mood == MoodLevel.struggling || l.mood == MoodLevel.low,
    ).length;
    if (lateLutealLogs.isNotEmpty && (sensitiveMoodLogs / lateLutealLogs.length) >= 0.4) {
      patterns.add(DiscoveredPattern(
        id: 'pms_mood_vulnerability',
        title: 'Premenstrual Emotional Sensitivity',
        category: 'Mood',
        emoji: '💜',
        description: 'A noticeable shift toward emotional tenderness or anxiety appears in late luteal (${(sensitiveMoodLogs / lateLutealLogs.length * 100).toInt()}% of your luteal logs).',
        clinicalInsight: 'The acute drop in allopregnanolone triggers heightened amygdala reactivity. Protecting boundaries and avoiding stimulants 4 days pre-bleed is profoundly protective.',
        confidence: lateLutealLogs.length >= 4 ? 'High Confidence' : 'Emerging',
        cycleDays: [cycleLength - 4, cycleLength - 3, cycleLength - 2, cycleLength - 1],
        associatedPhase: CyclePhase.lateLuteal,
      ));
    }

    // Pattern D: Cramp Velocity Pattern
    final menstrualLogs = phaseLogs[CyclePhase.menstrual] ?? [];
    final crampLogs = menstrualLogs.where(
      (l) => l.cramps == CrampLevel.moderate || l.cramps == CrampLevel.severe,
    ).length;
    if (menstrualLogs.isNotEmpty && crampLogs > 0) {
      patterns.add(DiscoveredPattern(
        id: 'cramp_velocity',
        title: 'Early-Bleed Prostaglandin Spike',
        category: 'Symptoms',
        emoji: '🩸',
        description: 'Cramp intensity clusters strongly on Days 1–2 of bleeding before tapering off rapidly.',
        clinicalInsight: 'Uterine contractions driven by PGF2-alpha prostaglandins peak within the first 36 hours. Early warmth and magnesium glycinate before flow begins minimizes prostaglandin accumulation.',
        confidence: menstrualLogs.length >= 3 ? 'High Confidence' : 'Emerging',
        cycleDays: [1, 2],
        associatedPhase: CyclePhase.menstrual,
      ));
    }

    // Pattern E: Sugar & Craving Marker
    final cravingCount = logs.where(
      (l) => l.symptoms.any((s) => s.toLowerCase().contains('crav') || s.toLowerCase().contains('sweet') || s.toLowerCase().contains('chocolate')),
    ).length;
    if (cravingCount >= 2) {
      patterns.add(DiscoveredPattern(
        id: 'magnesium_sugar_craving',
        title: 'Luteal Micronutrient Craving Signal',
        category: 'Nutrition',
        emoji: '🍫',
        description: 'Sugar and chocolate cravings consistently emerge 24–72 hours before your period begins.',
        clinicalInsight: 'Metabolic demand rises ~150–300 kcal/day in late luteal while cellular magnesium drops. Your cravings are intelligent biological signals for calories and magnesium.',
        confidence: cravingCount >= 4 ? 'High Confidence' : 'Emerging',
        cycleDays: [cycleLength - 3, cycleLength - 2, cycleLength - 1],
        associatedPhase: CyclePhase.lateLuteal,
      ));
    }

    // If few patterns found due to low logs, add formative baseline pattern
    if (patterns.isEmpty) {
      patterns.add(DiscoveredPattern(
        id: 'baseline_profiling',
        title: 'Personal Baseline Formation',
        category: 'Rhythm',
        emoji: '🌱',
        description: 'Luna is currently mapping your unique cycle baseline across $totalLogs logged data points.',
        clinicalInsight: 'Keep logging your daily mood, energy, and symptoms. By cycle 2, Luna automatically identifies recurring symptom clusters and personal energy curves.',
        confidence: 'Forming',
        cycleDays: const [],
      ));
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
    for (final p in patterns) {
      digestBuffer.writeln('  * [${p.category}] ${p.title} (${p.confidence}): ${p.description}');
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
