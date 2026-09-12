class UserProfile {
  final String id;
  final String name;
  final int averageCycleLength;
  final int averagePeriodLength;
  final DateTime? lastPeriodStart;
  final DateTime createdAt;
  final bool isFirebaseUser;
  final String? email;

  const UserProfile({
    required this.id,
    required this.name,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    this.lastPeriodStart,
    required this.createdAt,
    this.isFirebaseUser = false,
    this.email,
  });

  UserProfile copyWith({
    String? name,
    int? averageCycleLength,
    int? averagePeriodLength,
    DateTime? lastPeriodStart,
    bool clearLastPeriod = false,
    bool? isFirebaseUser,
    String? email,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        averageCycleLength: averageCycleLength ?? this.averageCycleLength,
        averagePeriodLength: averagePeriodLength ?? this.averagePeriodLength,
        lastPeriodStart: clearLastPeriod ? null : (lastPeriodStart ?? this.lastPeriodStart),
        createdAt: createdAt,
        isFirebaseUser: isFirebaseUser ?? this.isFirebaseUser,
        email: email ?? this.email,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'averageCycleLength': averageCycleLength,
        'averagePeriodLength': averagePeriodLength,
        'lastPeriodStart': lastPeriodStart?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'isFirebaseUser': isFirebaseUser,
        'email': email,
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
        isFirebaseUser: map['isFirebaseUser'] as bool? ?? false,
        email: map['email'] as String?,
      );
}
