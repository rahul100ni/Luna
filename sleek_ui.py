import re

with open('lib/features/settings/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _SettingsTile
old_settings_tile_pattern = re.compile(r'// ── Settings tile ─────────────────────────────────────────────────────────────\nclass _SettingsTile extends StatelessWidget \{.*?\}\n\}', re.DOTALL)

new_settings_tile = """// ── Settings tile ─────────────────────────────────────────────────────────────
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
        : colors.onSurface.withValues(alpha: 0.8);
    final labelColor = isDestructive
        ? dangerColor
        : colors.onSurface.withValues(alpha: 0.9);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? dangerColor.withValues(alpha: 0.03)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? dangerColor.withValues(alpha: 0.1)
                : colors.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: labelColor,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDestructive
                            ? dangerColor.withValues(alpha: 0.6)
                            : colors.onSurface.withValues(alpha: 0.4),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: isDestructive
                    ? dangerColor.withValues(alpha: 0.2)
                    : colors.onSurface.withValues(alpha: 0.15),
                size: 14),
          ],
        ),
      ),
    );
  }
}"""

content = re.sub(old_settings_tile_pattern, new_settings_tile, content)


# Replace _ResetOptionTile
old_reset_option_tile_pattern = re.compile(r'class _ResetOptionTile extends StatelessWidget \{.*?\}\n\}\n', re.DOTALL)

new_reset_option_tile = """class _ResetOptionTile extends StatelessWidget {
  final PhaseColors colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ResetOptionTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDestructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFE57373);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive 
              ? dangerColor.withValues(alpha: 0.03)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive 
                ? dangerColor.withValues(alpha: 0.1)
                : colors.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon, 
                color: isDestructive ? dangerColor : colors.onSurface.withValues(alpha: 0.8), 
                size: 18
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? dangerColor : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.4),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"""

content = re.sub(old_reset_option_tile_pattern, new_reset_option_tile, content)

with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Sleek UI replaced.")
