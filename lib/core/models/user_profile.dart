class UserProfile {
  final String id;
  final String name;
  final int averageCycleLength;
  final int averagePeriodLength;
  final DateTime? lastPeriodStart;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    this.lastPeriodStart,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? name,
    int? averageCycleLength,
    int? averagePeriodLength,
    DateTime? lastPeriodStart,
    bool clearLastPeriod = false,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        averageCycleLength: averageCycleLength ?? this.averageCycleLength,
        averagePeriodLength: averagePeriodLength ?? this.averagePeriodLength,
        lastPeriodStart:
            clearLastPeriod ? null : (lastPeriodStart ?? this.lastPeriodStart),
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'averageCycleLength': averageCycleLength,
        'averagePeriodLength': averagePeriodLength,
        'lastPeriodStart': lastPeriodStart?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        averageCycleLength: map['averageCycleLength'] as int? ?? 28,
        averagePeriodLength: map['averagePeriodLength'] as int? ?? 5,
        lastPeriodStart: map['lastPeriodStart'] != null
            ? DateTime.parse(map['lastPeriodStart'] as String)
            : null,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
