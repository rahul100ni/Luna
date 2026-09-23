import re

with open('lib/features/settings/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace the old Cloud Vault and Data & Privacy sections in the build method
old_sections_pattern = re.compile(r'          // ── Cloud Vault & Multi-Device Sync ───────────────────────────────\n          _SectionHeader\(label: \'Cloud Vault & Multi-Device Sync\', colors: colors\),\n          _SettingsTile\(\n            icon: Icons\.cloud_outlined,\n            label: \'Cloud Vault Sync ID\',\n            sublabel: _formatSyncIdSubtitle\(\),\n            colors: colors,\n            onTap: \(\) => _showCloudVaultDialog\(colors\),\n          \),\n          _SettingsTile\(\n            icon: Icons\.sync_rounded,\n            label: \'Sync Ground-Truth Now\',\n            sublabel: _formatLastSyncSubtitle\(\),\n            colors: colors,\n            onTap: \(\) => _triggerManualSync\(colors\),\n          \),\n          _SettingsTile\(\n            icon: Icons\.cloud_download_outlined,\n            label: \'Restore from Cloud Vault\',\n            sublabel: \'Switching phones\? Restore your data and continue\',\n            colors: colors,\n            onTap: \(\) => _showRestoreFromCloudDialog\(colors\),\n          \),\n          const SizedBox\(height: 20\),\n\n          // ── Data & Privacy section ─────────────────────────────────────────\n          _SectionHeader\(label: \'Data & Privacy\', colors: colors\),\n          _SettingsTile\(\n            icon: Icons\.delete_sweep_outlined,\n            label: \'Reset all data\',\n            sublabel: \'Wipe profile, logs, and start fresh\',\n            colors: colors,\n            isDestructive: true,\n            onTap: \(\) => showModalBottomSheet\(context: context, isScrollControlled: true, backgroundColor: Colors\.transparent, builder: \(ctx\) => _ResetDataSheet\(colors: colors, onWipe: _performDeviceWipe\)\),\n          \),', re.DOTALL)

new_sections = """          // ── Data & Privacy section ─────────────────────────────────────────
          _SectionHeader(label: 'Data & Privacy', colors: colors),
          _SettingsTile(
            icon: Icons.shield_outlined,
            label: 'Data & Privacy',
            sublabel: 'Cloud vault, backup, and reset options',
            colors: colors,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _DataPrivacySheet(
                  colors: colors,
                  syncIdSubtitle: _formatSyncIdSubtitle(),
                  lastSyncSubtitle: _formatLastSyncSubtitle(),
                  onTapSyncId: () {
                    Navigator.pop(ctx);
                    _showCloudVaultDialog(colors);
                  },
                  onTapSyncNow: () {
                    Navigator.pop(ctx);
                    _triggerManualSync(colors);
                  },
                  onTapRestore: () {
                    Navigator.pop(ctx);
                    _showRestoreFromCloudDialog(colors);
                  },
                  onTapReset: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (innerCtx) => _ResetDataSheet(colors: colors, onWipe: _performDeviceWipe),
                    );
                  },
                ),
              );
            },
          ),"""

content = re.sub(old_sections_pattern, new_sections, content)

# 2. Append _DataPrivacySheet class at the end
data_privacy_sheet = """
// ── Data & Privacy Sheet ─────────────────────────────────────────────────────
class _DataPrivacySheet extends StatelessWidget {
  final PhaseColors colors;
  final String? syncIdSubtitle;
  final String? lastSyncSubtitle;
  final VoidCallback onTapSyncId;
  final VoidCallback onTapSyncNow;
  final VoidCallback onTapRestore;
  final VoidCallback onTapReset;

  const _DataPrivacySheet({
    required this.colors,
    this.syncIdSubtitle,
    this.lastSyncSubtitle,
    required this.onTapSyncId,
    required this.onTapSyncNow,
    required this.onTapRestore,
    required this.onTapReset,
  });

  @override
  Widget build(BuildContext context) {
    return _BottomSheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle(label: 'Data & Privacy', colors: colors),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            label: 'Cloud Vault Sync ID',
            sublabel: syncIdSubtitle,
            colors: colors,
            onTap: onTapSyncId,
          ),
          _SettingsTile(
            icon: Icons.sync_rounded,
            label: 'Sync Ground-Truth Now',
            sublabel: lastSyncSubtitle,
            colors: colors,
            onTap: onTapSyncNow,
          ),
          _SettingsTile(
            icon: Icons.cloud_download_outlined,
            label: 'Restore from Cloud Vault',
            sublabel: 'Switching phones? Restore your data and continue',
            colors: colors,
            onTap: onTapRestore,
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            label: 'Reset all data',
            sublabel: 'Wipe profile, logs, and start fresh',
            colors: colors,
            isDestructive: true,
            onTap: onTapReset,
          ),
        ],
      ),
    );
  }
}
"""

content += "\n" + data_privacy_sheet

with open('lib/features/settings/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Settings screen updated to tuck away privacy options.")
