import re

with open('lib/features/settings/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_tile = """// ── Settings tile ─────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final PhaseColors colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.sublabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFD94F6E);
    final iconColor = isDestructive
        ? dangerColor.withValues(alpha: 0.8)
        : colors.onSurface.withValues(alpha: 0.6);
    final labelColor = isDestructive
        ? dangerColor
        : colors.onSurface.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive
              ? dangerColor.withValues(alpha: 0.06)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isDestructive
              ? Border.all(color: dangerColor.withValues(alpha: 0.15))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: labelColor,
                      fontWeight: isDestructive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDestructive
                            ? dangerColor.withValues(alpha: 0.55)
                            : colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDestructive
                    ? dangerColor.withValues(alpha: 0.4)
                    : colors.onSurface.withValues(alpha: 0.3),
                size: 18),
          ],
        ),
      ),
    );
  }
}"""

new_tile = """// ── Settings tile ─────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final PhaseColors colors;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.sublabel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFE57373);
    final iconColor = isDestructive
        ? dangerColor
        : colors.primary;
    final labelColor = isDestructive
        ? dangerColor
        : colors.onSurface.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDestructive
              ? dangerColor.withValues(alpha: 0.04)
              : colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: isDestructive
              ? Border.all(color: dangerColor.withValues(alpha: 0.15), width: 1)
              : Border.all(color: colors.primary.withValues(alpha: 0.08), width: 1),
          boxShadow: [
            if (!isDestructive)
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.03),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? dangerColor.withValues(alpha: 0.1)
                    : colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sublabel!,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDestructive
                            ? dangerColor.withValues(alpha: 0.7)
                            : colors.onSurface.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: isDestructive
                    ? dangerColor.withValues(alpha: 0.3)
                    : colors.onSurface.withValues(alpha: 0.2),
                size: 16),
          ],
        ),
      ),
    );
  }
}"""

if old_tile in content:
    content = content.replace(old_tile, new_tile)
    with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Settings tile replaced.")
else:
    print("Could not find old_tile.")
