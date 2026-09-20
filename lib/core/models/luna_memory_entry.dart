import "package:uuid/uuid.dart";

/// Represents a persistent memory item captured by Luna across interactions.
/// Aligned with VISION.md Pillar One: Memory.
class LunaMemoryEntry {
  final String id;
  final String category; // 'preference' | 'person' | 'life_context' | 'vulnerability' | 'body_pattern'
  final String content;
  final DateTime createdAt;
  final DateTime? lastSurfaced;

  const LunaMemoryEntry({
    required this.id,
    required this.category,
    required this.content,
    required this.createdAt,
    this.lastSurfaced,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "category": category,
    "content": content,
    "created_at": createdAt.toIso8601String(),
    "last_surfaced": lastSurfaced?.toIso8601String(),
  };

  factory LunaMemoryEntry.fromMap(Map<String, dynamic> map) => LunaMemoryEntry(
    id: map["id"] as String,
    category: map["category"] as String? ?? "preference",
    content: map["content"] as String? ?? "",
    createdAt: map["created_at"] != null
        ? DateTime.parse(map["created_at"] as String)
        : DateTime.now(),
    lastSurfaced: map["last_surfaced"] != null
        ? DateTime.parse(map["last_surfaced"] as String)
        : null,
  );

  static String newId() => const Uuid().v4();
}
