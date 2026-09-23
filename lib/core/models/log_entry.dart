class LogEntry {
  final String id;
  final DateTime date;
  final MoodLevel? mood; // nullable: mood is optional (can log energy/symptoms/flow without mood)
  final int? energyLevel; // nullable: only stored when user explicitly sets it
  final SleepQuality? sleepQuality; // NEW: replaces the 5-bolt energy UI
  final FlowLevel? flow;
  final CrampLevel? cramps;
  final List<String> symptoms;
  final String? notes;
  final bool periodStarted;

  /// Canonicalizes a symptom name to its official Title Case dictionary representation.
  static String canonicalizeSymptom(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();

    const canonicalMap = {
      'craving': 'Cravings',
      'cravings': 'Cravings',
      'headache': 'Headache',
      'headaches': 'Headache',
      'migraine': 'Headache',
      'cramp': 'Cramps',
      'cramps': 'Cramps',
      'cramping': 'Cramps',
      'bloat': 'Bloating',
      'bloated': 'Bloating',
      'bloating': 'Bloating',
      'fatigue': 'Fatigue',
      'fatigued': 'Fatigue',
      'tired': 'Fatigue',
      'exhausted': 'Fatigue',
      'brain fog': 'Brain fog',
      'foggy': 'Brain fog',
      'anxious': 'Anxious',
      'anxiety': 'Anxious',
      'panic': 'Anxious',
      'irritable': 'Irritable',
      'irritated': 'Irritable',
      'angry': 'Irritable',
      'moody': 'Irritable',
      'backache': 'Backache',
      'back pain': 'Backache',
      'tender': 'Tender',
      'tender breasts': 'Tender',
      'breast pain': 'Tender',
      'nausea': 'Nausea',
      'nauseous': 'Nausea',
      'hot flash': 'Hot flashes',
      'hot flashes': 'Hot flashes',
      'insomnia': 'Insomnia',
      'poor sleep': 'Insomnia',
      'acne': 'Acne',
      'breakout': 'Acne',
      'breakouts': 'Acne',
      'feeling good': 'Feeling good',
      'energetic': 'High Energy',
      'high energy': 'High Energy',
      'mental clarity': 'Mental Clarity',
      'clear skin': 'Clear Skin',
      'calm focus': 'Calm Focus',
      'mood sensitivity': 'Mood Sensitivity',
    };

    if (canonicalMap.containsKey(lower)) {
      return canonicalMap[lower]!;
    }

    // Default: Clean Title Case
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Deduplicates and canonicalizes a collection of symptoms case-insensitively.
  static List<String> canonicalizeSymptoms(Iterable<String> rawSymptoms) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawSymptoms) {
      final canonical = canonicalizeSymptom(raw);
      if (canonical.isNotEmpty && seen.add(canonical.toLowerCase())) {
        result.add(canonical);
      }
    }
    return result;
  }

  LogEntry({
    required this.id,
    required this.date,
    this.mood,
    this.energyLevel,
    this.sleepQuality,
    this.flow,
    this.cramps,
    required List<String> symptoms,
    this.notes,
    this.periodStarted = false,
  }) : symptoms = canonicalizeSymptoms(symptoms);

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood?.index,
        'energyLevel': energyLevel,
        'sleepQuality': sleepQuality?.index,
        'flow': flow?.index,
        'cramps': cramps?.index,
        'symptoms': symptoms.join(','),
        'notes': notes,
        'periodStarted': periodStarted ? 1 : 0,
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        mood: map['mood'] != null ? MoodLevel.values[map['mood'] as int] : null,
        // Backward-compatible: old rows with `energyLevel = 3` (default) are
        // treated as "no explicit log" (null), since 3 was the silent default.
        // New rows that are explicitly set will persist as their actual value.
        energyLevel: map['energyLevel'] != null ? map['energyLevel'] as int : null,
        sleepQuality: map['sleepQuality'] != null
            ? SleepQuality.values[map['sleepQuality'] as int]
            : null,
        flow: map['flow'] != null ? FlowLevel.values[map['flow'] as int] : null,
        cramps: map['cramps'] != null ? CrampLevel.values[map['cramps'] as int] : null,
        symptoms: (map['symptoms'] as String? ?? '')
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        notes: map['notes'] as String?,
        periodStarted: (map['periodStarted'] as int? ?? 0) == 1,
      );

  LogEntry copyWith({
    String? id,
    DateTime? date,
    MoodLevel? mood,
    int? energyLevel,
    SleepQuality? sleepQuality,
    FlowLevel? flow,
    CrampLevel? cramps,
    List<String>? symptoms,
    String? notes,
    bool? periodStarted,
    bool clearMood = false,
    bool clearEnergy = false,
    bool clearSleep = false,
    bool clearFlow = false,
    bool clearCramps = false,
  }) =>
      LogEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        mood: clearMood ? null : (mood ?? this.mood),
        energyLevel: clearEnergy ? null : (energyLevel ?? this.energyLevel),
        sleepQuality: clearSleep ? null : (sleepQuality ?? this.sleepQuality),
        flow: clearFlow ? null : (flow ?? this.flow),
        cramps: clearCramps ? null : (cramps ?? this.cramps),
        symptoms: symptoms ?? this.symptoms,
        notes: notes ?? this.notes,
        periodStarted: periodStarted ?? this.periodStarted,
      );

  /// Returns true if this entry contains actual wellness / biomarker observations
  /// (mood, energy, sleep, flow, cramps, symptoms, or personal notes).
  /// A bare period anchor (with only periodStarted = true) does not qualify.
  bool get hasBiomarkerData =>
      mood != null ||
      energyLevel != null ||
      sleepQuality != null ||
      flow != null ||
      (cramps != null && cramps != CrampLevel.none) ||
      symptoms.isNotEmpty ||
      (notes != null && notes!.trim().isNotEmpty);
}

enum MoodLevel {
  struggling, // 😭
  low, // 😔
  meh, // 😐
  decent, // 🙂
  good, // 😊
  thriving, // 🤩
}

enum FlowLevel { spotting, light, medium, heavy }

enum CrampLevel { none, mild, moderate, severe }

/// Sleep quality logged by user: replaces the blunt 1-5 energy score
enum SleepQuality { poor, fair, good, great }

extension SleepQualityExt on SleepQuality {
  String get label {
    switch (this) {
      case SleepQuality.poor:
        return 'Poor';
      case SleepQuality.fair:
        return 'Fair';
      case SleepQuality.good:
        return 'Good';
      case SleepQuality.great:
        return 'Great';
    }
  }
}

extension MoodLevelExt on MoodLevel {
  String get emoji {
    switch (this) {
      case MoodLevel.struggling:
        return '😭';
      case MoodLevel.low:
        return '😔';
      case MoodLevel.meh:
        return '😐';
      case MoodLevel.decent:
        return '🙂';
      case MoodLevel.good:
        return '😊';
      case MoodLevel.thriving:
        return '🤩';
    }
  }

  String get label {
    switch (this) {
      case MoodLevel.struggling:
        return 'Really struggling';
      case MoodLevel.low:
        return 'A bit low';
      case MoodLevel.meh:
        return 'Meh, okay';
      case MoodLevel.decent:
        return 'Decent actually';
      case MoodLevel.good:
        return 'Pretty good';
      case MoodLevel.thriving:
        return 'I\'m thriving!';
    }
  }
}
