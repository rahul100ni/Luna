class LogEntry {
  final String id;
  final DateTime date;
  final MoodLevel mood;
  final int energyLevel; // 1-5
  final FlowLevel? flow;
  final CrampLevel? cramps;
  final List<String> symptoms;
  final String? notes;
  final bool periodStarted;

  const LogEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.energyLevel,
    this.flow,
    this.cramps,
    required this.symptoms,
    this.notes,
    this.periodStarted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood.index,
        'energyLevel': energyLevel,
        'flow': flow?.index,
        'cramps': cramps?.index,
        'symptoms': symptoms.join(','),
        'notes': notes,
        'periodStarted': periodStarted ? 1 : 0,
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        mood: MoodLevel.values[map['mood'] as int],
        energyLevel: map['energyLevel'] as int,
        flow: map['flow'] != null ? FlowLevel.values[map['flow'] as int] : null,
        cramps: map['cramps'] != null ? CrampLevel.values[map['cramps'] as int] : null,
        symptoms: (map['symptoms'] as String? ?? '').isEmpty
            ? []
            : (map['symptoms'] as String).split(','),
        notes: map['notes'] as String?,
        periodStarted: (map['periodStarted'] as int? ?? 0) == 1,
      );
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
