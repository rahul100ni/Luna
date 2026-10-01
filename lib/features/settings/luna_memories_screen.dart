import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/models/luna_memory_entry.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/cloud_ground_truth_service.dart';

// -- Category metadata: icons, labels, and accent colours per memory type --
class _CategoryMeta {
  final IconData icon;
  final String label;
  final String emoji;
  final Color accent;
  const _CategoryMeta({required this.icon, required this.label, required this.emoji, required this.accent});
}

const Map<String, _CategoryMeta> _categoryMeta = {
  'preference': _CategoryMeta(
    icon: Icons.favorite_outline_rounded,
    label: 'Preferences',
    emoji: '💜',
    accent: Color(0xFF9B84D4),
  ),
  'person': _CategoryMeta(
    icon: Icons.people_outline_rounded,
    label: 'People',
    emoji: '🫂',
    accent: Color(0xFFE07070),
  ),
  'life_context': _CategoryMeta(
    icon: Icons.auto_stories_outlined,
    label: 'Life Context',
    emoji: '🌿',
    accent: Color(0xFF4CAF87),
  ),
  'vulnerability': _CategoryMeta(
    icon: Icons.spa_outlined,
    label: 'Moments',
    emoji: '🌙',
    accent: Color(0xFFD4895A),
  ),
  'body_pattern': _CategoryMeta(
    icon: Icons.insights_rounded,
    label: 'Body Patterns',
    emoji: '🩺',
    accent: Color(0xFFF2B43A),
  ),
  'communication_meta': _CategoryMeta(
    icon: Icons.chat_bubble_outline_rounded,
    label: 'Communication',
    emoji: '💬',
    accent: Color(0xFF6BA3BE),
  ),
};

_CategoryMeta _metaFor(String category) =>
    _categoryMeta[category] ??
    const _CategoryMeta(
      icon: Icons.note_outlined,
      label: 'Notes',
      emoji: '📝',
      accent: Color(0xFF888888),
    );

class LunaMemoriesScreen extends ConsumerStatefulWidget {
  const LunaMemoriesScreen({super.key});

  @override
  ConsumerState<LunaMemoriesScreen> createState() => _LunaMemoriesScreenState();
}

class _LunaMemoriesScreenState extends ConsumerState<LunaMemoriesScreen>
    with TickerProviderStateMixin {
  List<LunaMemoryEntry> _memories = [];
  bool _loading = true;
  String? _filterCategory; // null = all
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadMemories();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    setState(() => _loading = true);
    final all = await StorageService.getMemories(limit: 500);
    if (mounted) {
      setState(() {
        _memories = all;
        _loading = false;
      });
    }
  }

  List<LunaMemoryEntry> get _filtered {
    var list = _memories;
    if (_filterCategory != null) {
      list = list.where((m) => m.category == _filterCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((m) => m.content.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return list;
  }

  // Category counts for the filter pills
  Map<String, int> get _categoryCounts {
    final counts = <String, int>{};
    for (final m in _memories) {
      counts[m.category] = (counts[m.category] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _deleteMemory(LunaMemoryEntry memory, PhaseColors colors) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => _DeleteConfirmDialog(memory: memory, colors: colors),
    );
    if (confirmed == true) {
      await StorageService.deleteMemory(memory.id);
      // Sync to cloud immediately after delete -- her data sovereignty matters
      unawaited(CloudGroundTruthService.syncAll());
      _loadMemories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Memory removed',
              style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _editMemory(LunaMemoryEntry memory, PhaseColors colors) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditMemorySheet(memory: memory, colors: colors),
    );
    if (result != null && result.trim().isNotEmpty && result != memory.content) {
      final updated = LunaMemoryEntry(
        id: memory.id,
        category: memory.category,
        content: result.trim(),
        createdAt: memory.createdAt,
        lastSurfaced: memory.lastSurfaced,
      );
      await StorageService.saveMemory(updated);
      unawaited(CloudGroundTruthService.syncAll());
      _loadMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(colors: colors, onBack: () => Navigator.of(context).pop()),
            _QuoteBar(colors: colors, totalMemories: _memories.length),
            const SizedBox(height: 12),
            _SearchBar(controller: _searchController, colors: colors),
            const SizedBox(height: 12),
            _CategoryFilterRow(
              categoryCounts: _categoryCounts,
              selectedCategory: _filterCategory,
              colors: colors,
              onSelect: (cat) => setState(() => _filterCategory = cat == _filterCategory ? null : cat),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? _LoadingShimmer(colors: colors)
                  : _filtered.isEmpty
                      ? _EmptyState(colors: colors, hasFilter: _filterCategory != null || _searchQuery.isNotEmpty)
                      : _MemoryList(
                          memories: _filtered,
                          colors: colors,
                          onDelete: (m) => _deleteMemory(m, colors),
                          onEdit: (m) => _editMemory(m, colors),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Header --
class _Header extends StatelessWidget {
  final PhaseColors colors;
  final VoidCallback onBack;
  const _Header({required this.colors, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_rounded, color: colors.onSurface, size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What Luna Knows',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Everything she has quietly held for you',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.45),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Quote Bar: a soft, personal summary line --
class _QuoteBar extends StatelessWidget {
  final PhaseColors colors;
  final int totalMemories;
  const _QuoteBar({required this.colors, required this.totalMemories});

  @override
  Widget build(BuildContext context) {
    String line;
    if (totalMemories == 0) {
      line = 'Start talking to Luna and she will start remembering you.';
    } else if (totalMemories < 5) {
      line = 'Luna is just beginning to know you. Keep going.';
    } else if (totalMemories < 20) {
      line = 'Luna is building a picture of your world, piece by piece.';
    } else {
      line = 'Luna has been paying close attention. All of this is yours.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15), width: 0.6),
      ),
      child: Row(
        children: [
          const Text('💜', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (totalMemories > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalMemories',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -- Search bar --
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final PhaseColors colors;
  const _SearchBar({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.06), width: 0.5),
        ),
        child: TextField(
          controller: controller,
          style: GoogleFonts.dmSans(fontSize: 13.5, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: 'Search memories...',
            hintStyle: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: colors.onSurface.withValues(alpha: 0.35), size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

// -- Category filter row --
class _CategoryFilterRow extends StatelessWidget {
  final Map<String, int> categoryCounts;
  final String? selectedCategory;
  final PhaseColors colors;
  final void Function(String) onSelect;
  const _CategoryFilterRow({
    required this.categoryCounts,
    required this.selectedCategory,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Only show categories that have at least 1 memory, exclude communication_meta (internal)
    final categories = categoryCounts.keys
        .where((c) => c != 'communication_meta' && categoryCounts[c]! > 0)
        .toList();
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final meta = _metaFor(cat);
          final isSelected = selectedCategory == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? meta.accent.withValues(alpha: 0.18)
                    : colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? meta.accent.withValues(alpha: 0.5)
                      : colors.onSurface.withValues(alpha: 0.1),
                  width: isSelected ? 1.0 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(meta.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    '${meta.label} (${categoryCounts[cat]})',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? meta.accent
                          : colors.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -- The memory list --
class _MemoryList extends StatelessWidget {
  final List<LunaMemoryEntry> memories;
  final PhaseColors colors;
  final void Function(LunaMemoryEntry) onDelete;
  final void Function(LunaMemoryEntry) onEdit;
  const _MemoryList({required this.memories, required this.colors, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: memories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MemoryCard(
        memory: memories[i],
        colors: colors,
        onDelete: onDelete,
        onEdit: onEdit,
      ).animate().fadeIn(delay: Duration(milliseconds: i * 30), duration: 300.ms),
    );
  }
}

// -- Individual memory card with swipe-to-dismiss and long-press menu --
class _MemoryCard extends StatelessWidget {
  final LunaMemoryEntry memory;
  final PhaseColors colors;
  final void Function(LunaMemoryEntry) onDelete;
  final void Function(LunaMemoryEntry) onEdit;
  const _MemoryCard({
    required this.memory,
    required this.colors,
    required this.onDelete,
    required this.onEdit,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(memory.category);
    // Don't show internal communication_meta cards
    if (memory.category == 'communication_meta') return const SizedBox.shrink();

    return Dismissible(
      key: ValueKey(memory.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(memory),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE57373).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 20),
            SizedBox(height: 2),
            Text('Remove', style: TextStyle(color: Color(0xFFE57373), fontSize: 10)),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => _MemoryActionSheet(
              memory: memory,
              colors: colors,
              onEdit: () => onEdit(memory),
              onDelete: () => onDelete(memory),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: meta.accent.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dot + emoji
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: meta.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(meta.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category label and time
                    Row(
                      children: [
                        Text(
                          meta.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: meta.accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _relativeTime(memory.createdAt),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Memory content
                    Text(
                      memory.content,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: colors.onSurface.withValues(alpha: 0.85),
                        height: 1.45,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Subtle edit hint
              GestureDetector(
                onTap: () => onEdit(memory),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: colors.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Long-press action sheet --
class _MemoryActionSheet extends StatelessWidget {
  final LunaMemoryEntry memory;
  final PhaseColors colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MemoryActionSheet({
    required this.memory,
    required this.colors,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(memory.category);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(meta.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      meta.label,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  memory.content,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: colors.onSurface.withValues(alpha: 0.06), height: 1),
          _ActionRow(
            icon: Icons.edit_outlined,
            label: 'Edit memory',
            color: colors.onSurface.withValues(alpha: 0.8),
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          Divider(color: colors.onSurface.withValues(alpha: 0.06), height: 1),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: 'Remove from memory',
            color: const Color(0xFFE57373),
            colors: colors,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final PhaseColors colors;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// -- Delete confirmation dialog --
class _DeleteConfirmDialog extends StatelessWidget {
  final LunaMemoryEntry memory;
  final PhaseColors colors;
  const _DeleteConfirmDialog({required this.memory, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Remove this memory?',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
      content: Text(
        'Luna will stop referencing this. It cannot be recovered.',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: colors.onSurface.withValues(alpha: 0.55),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Keep it',
            style: GoogleFonts.dmSans(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Remove',
            style: GoogleFonts.dmSans(
              color: const Color(0xFFE57373),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Edit memory bottom sheet --
class _EditMemorySheet extends StatefulWidget {
  final LunaMemoryEntry memory;
  final PhaseColors colors;
  const _EditMemorySheet({required this.memory, required this.colors});

  @override
  State<_EditMemorySheet> createState() => _EditMemorySheetState();
}

class _EditMemorySheetState extends State<_EditMemorySheet> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.memory.content);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correct what Luna remembers',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'She will update her understanding accordingly.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 2,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: colors.onSurface,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, _ctrl.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Update memory',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// -- Empty state --
class _EmptyState extends StatelessWidget {
  final PhaseColors colors;
  final bool hasFilter;
  const _EmptyState({required this.colors, required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💜', style: TextStyle(fontSize: 40))
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No memories here yet' : 'Nothing stored yet',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try a different filter or search'
                : 'Start talking to Luna and she will\nquietly remember what matters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.35),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Shimmer loading placeholder --
class _LoadingShimmer extends StatelessWidget {
  final PhaseColors colors;
  const _LoadingShimmer({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: colors.primary.withValues(alpha: 0.06)),
    );
  }
}
