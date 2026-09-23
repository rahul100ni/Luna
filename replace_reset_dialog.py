import re

with open('lib/features/settings/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _showResetConfirmation method call
content = content.replace(
    "onTap: () => _showResetConfirmation(colors),",
    "onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _ResetDataSheet(colors: colors, onWipe: _performDeviceWipe)),"
)

# Remove the old _showResetConfirmation method definition using regex
pattern = re.compile(r'  // ── 7\. Reset All Data \(Two-tier choice: Device Only vs Device \+ Cloud\) ─────\n  void _showResetConfirmation\(PhaseColors colors\) \{.*?\}\n\n  Future<void> _performDeviceWipe', re.DOTALL)
replacement = r'  // ── 7. Reset All Data ─────────────────────────────────────────────────────────────\n  Future<void> _performDeviceWipe'

content = re.sub(pattern, replacement, content)

# Add the new _ResetDataSheet widget at the end of the file
new_sheet_code = """
// ── Reset Data Sheet ─────────────────────────────────────────────────────────
class _ResetDataSheet extends StatelessWidget {
  final PhaseColors colors;
  final Future<void> Function({required bool wipeCloud}) onWipe;

  const _ResetDataSheet({required this.colors, required this.onWipe});

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFE57373);
    
    return _BottomSheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reset Luna',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: dangerColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This action is irreversible. Choose how thoroughly you want to erase your footprint.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          _ResetOptionTile(
            colors: colors,
            icon: Icons.phone_android_rounded,
            title: 'Wipe Device Only',
            subtitle: 'Clears this phone. Your Cloud Vault remains safe for restore or multi-device use.',
            isDestructive: false,
            onTap: () {
              Navigator.of(context).pop();
              onWipe(wipeCloud: false);
            },
          ),
          const SizedBox(height: 12),
          
          _ResetOptionTile(
            colors: colors,
            icon: Icons.delete_forever_rounded,
            title: 'Wipe Everything (Device + Cloud)',
            subtitle: 'Irreversibly destroys both local storage and your private cloud vault.',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              onWipe(wipeCloud: true);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ResetOptionTile extends StatelessWidget {
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
    final baseColor = isDestructive ? dangerColor : colors.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDestructive 
              ? dangerColor.withValues(alpha: 0.05)
              : colors.background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive 
                ? dangerColor.withValues(alpha: 0.2)
                : colors.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: baseColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? dangerColor : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.5),
                      height: 1.4,
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

content = content + "\n" + new_sheet_code

with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Reset dialog replaced.")
