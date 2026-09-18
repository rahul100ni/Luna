import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/phase_constants.dart';
import '../../core/providers/cycle_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_service.dart';
import 'version_manager_screen.dart';

// Notification preference keys — imported from notification_service.dart (single source of truth)
// kNotifDailyCheckin, kNotifPeriodSoon, kNotifPhaseChange, kNotifPms,
// kNotifDailyHour, kNotifDailyMinute are top-level constants in notification_service.dart


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;

  // ── Secret version footer tap handler ───────────────────────────────────────
  void _onVersionTap(PhaseColors colors) {
    final n = _versionTapCount + 1;
    if (n >= 5) {
      setState(() => _versionTapCount = 0);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VersionManagerScreen(
          colors: colors,
          onClose: () => Navigator.of(context).pop(),
        ),
      ));
    } else {
      setState(() => _versionTapCount = n);
    }
  }

  // ── 1. Edit name bottom sheet ────────────────────────────────────────────────
  void _showEditNameSheet(PhaseColors colors, String currentName) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _BottomSheetContainer(
            colors: colors,
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetTitle(label: 'Edit Name', colors: colors),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: GoogleFonts.dmSans(
                        color: colors.onSurface,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Your name',
                        hintStyle: GoogleFonts.dmSans(
                          color: colors.onSurface.withValues(alpha: 0.35),
                        ),
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SheetSaveButton(
                      colors: colors,
                      onTap: () async {
                        final newName = controller.text.trim();
                        if (newName.isEmpty) return;
                        final profile = ref.read(profileProvider);
                        if (profile != null) {
                          await ref
                              .read(profileProvider.notifier)
                              .saveProfile(profile.copyWith(name: newName));
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── 2. Cycle length bottom sheet ─────────────────────────────────────────────
  void _showCycleLengthSheet(PhaseColors colors, int current) {
    int selected = current;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetContainer(
          colors: colors,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTitle(label: 'Cycle Length', colors: colors),
                  const SizedBox(height: 6),
                  Text(
                    'Average days between periods (21–45)',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _NumberPicker(
                    colors: colors,
                    value: selected,
                    min: 21,
                    max: 45,
                    onChanged: (v) => setSheetState(() => selected = v),
                  ),
                  const SizedBox(height: 24),
                  _SheetSaveButton(
                    colors: colors,
                    onTap: () async {
                      final profile = ref.read(profileProvider);
                      if (profile != null) {
                        await ref
                            .read(profileProvider.notifier)
                            .saveProfile(profile.copyWith(
                              averageCycleLength: selected,
                            ));
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── 3. Period length bottom sheet ────────────────────────────────────────────
  void _showPeriodLengthSheet(PhaseColors colors, int current) {
    int selected = current;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetContainer(
          colors: colors,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTitle(label: 'Period Length', colors: colors),
                  const SizedBox(height: 6),
                  Text(
                    'Average days of bleeding (2–10)',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _NumberPicker(
                    colors: colors,
                    value: selected,
                    min: 2,
                    max: 10,
                    onChanged: (v) => setSheetState(() => selected = v),
                  ),
                  const SizedBox(height: 24),
                  _SheetSaveButton(
                    colors: colors,
                    onTap: () async {
                      final profile = ref.read(profileProvider);
                      if (profile != null) {
                        await ref
                            .read(profileProvider.notifier)
                            .saveProfile(profile.copyWith(
                              averagePeriodLength: selected,
                            ));
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── 4. Log period start date ─────────────────────────────────────────────────
  Future<void> _showLogPeriodDate(PhaseColors colors) async {
    final profile = ref.read(profileProvider);
    final hasExisting = profile?.lastPeriodStart != null;

    if (hasExisting) {
      final existingDate = profile!.lastPeriodStart!;
      final existingStr = '${existingDate.day}/${existingDate.month}/${existingDate.year}';
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Period Start Date',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Currently set to $existingStr',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_calendar_rounded,
                      color: colors.accent, size: 20),
                ),
                title: Text('Change start date',
                    style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                onTap: () => Navigator.pop(ctx, 'change'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 20),
                ),
                title: Text('Clear start date (not started yet)',
                    style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent)),
                subtitle: Text(
                    'Removes current assumptions until you log your period',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4))),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            ],
          ),
        ),
      );

      if (action == 'clear') {
        await ref.read(profileProvider.notifier).updateLastPeriod(null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Period date cleared. Home screen reset.')),
          );
        }
        return;
      }
      if (action != 'change') return;
    }

    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: profile?.lastPeriodStart ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              surface: colors.surface,
              onSurface: colors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    final dateStr = '${picked.day}/${picked.month}/${picked.year}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Update Cycle Start Date 🌙',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          'This will set your cycle start date to $dateStr. Continue?',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Save',
              style: GoogleFonts.dmSans(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(profileProvider.notifier).updateLastPeriod(picked);
    }
  }

  // ── 5. Notification preferences bottom sheet ─────────────────────────────────
  void _showNotificationSheet(PhaseColors colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationSheet(colors: colors),
    );
  }

  // ── 6. Reset All Data (two-step confirmation) ────────────────────────────────
  void _showResetConfirmation(PhaseColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset everything?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete your profile, all logged check-ins, and your AI patterns.\n\nThis action cannot be undone.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 1. Cancel all scheduled notifications
              await NotificationService.cancelAll();
              // 2. Wipe all data — profile, logs, cache, API key, settings
              await StorageService.clearAllData();
              // 3. Clear chat session
              await StorageService.clearLastChatSession();
              // 4. Clear Riverpod provider state
              ref.read(profileProvider.notifier).clear();
              ref.read(logEntriesProvider.notifier).refresh();
              // 5. Navigate to onboarding
              if (mounted) context.go('/onboarding');
            },
            child: Text(
              'Reset Luna',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFD94F6E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 7. About Luna dialog ─────────────────────────────────────────────────────

  void _showAboutDialog(PhaseColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'About Luna 🌙',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          'Luna is a cycle companion built with love — to help you understand '
          'your body, honour your rhythms, and show up for yourself every '
          'single day.\n\nAll your data stays on your device.\n\nVersion 1.0.0',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.dmSans(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(phaseColorsProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: colors.onSurface.withValues(alpha: 0.6), size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card (tap to edit name) ──────────────────────────────
          GestureDetector(
            onTap: () => _showEditNameSheet(colors, profile?.name ?? ''),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile?.name.isNotEmpty == true
                            ? profile!.name[0].toUpperCase()
                            : '🌙',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Luna User',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          'Cycle: ${profile?.averageCycleLength ?? 28} days · '
                          'Period: ${profile?.averagePeriodLength ?? 5} days',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    color: colors.onSurface.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Cycle section ─────────────────────────────────────────────────
          _SectionHeader(label: 'Cycle', colors: colors),
          _SettingsTile(
            icon: Icons.calendar_today_outlined,
            label: 'Update cycle length',
            colors: colors,
            onTap: () => _showCycleLengthSheet(
              colors,
              profile?.averageCycleLength ?? 28,
            ),
          ),
          _SettingsTile(
            icon: Icons.av_timer_outlined,
            label: 'Update period length',
            colors: colors,
            onTap: () => _showPeriodLengthSheet(
              colors,
              profile?.averagePeriodLength ?? 5,
            ),
          ),
          Builder(
            builder: (context) {
              final pStart = profile?.lastPeriodStart;
              return _SettingsTile(
                icon: Icons.water_drop_outlined,
                label: pStart != null
                    ? 'Period start: ${pStart.day}/${pStart.month}/${pStart.year}'
                    : 'Period start date (Not set)',
                colors: colors,
                onTap: () => _showLogPeriodDate(colors),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Notifications section ─────────────────────────────────────────
          _SectionHeader(label: 'Notifications', colors: colors),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notification preferences',
            colors: colors,
            onTap: () => _showNotificationSheet(colors),
          ),
          const SizedBox(height: 20),

          // ── About section ─────────────────────────────────────────────────
          _SectionHeader(label: 'About', colors: colors),
          _SettingsTile(
            icon: Icons.favorite_outline,
            label: 'About Luna',
            colors: colors,
            onTap: () => _showAboutDialog(colors),
          ),
          const SizedBox(height: 20),

          // ── Data & Privacy section ─────────────────────────────────────────
          _SectionHeader(label: 'Data & Privacy', colors: colors),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            label: 'Reset all data',
            sublabel: 'Wipe profile, logs, and start fresh',
            colors: colors,
            isDestructive: true,
            onTap: () => _showResetConfirmation(colors),
          ),
          const SizedBox(height: 40),

          // ── Secret version footer (tap 5× to open version manager) ────────
          GestureDetector(
            onTap: () => _onVersionTap(colors),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(children: [
                Text(
                  'Luna v1.0.3',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.18),
                    letterSpacing: 0.3,
                  ),
                ),
                if (_versionTapCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _versionTapCount
                              ? colors.primary.withValues(alpha: 0.5)
                              : colors.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification bottom sheet (ConsumerStatefulWidget to manage prefs state & reschedule) ──────────
class _NotificationSheet extends ConsumerStatefulWidget {
  final PhaseColors colors;
  const _NotificationSheet({required this.colors});

  @override
  ConsumerState<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<_NotificationSheet> {
  bool _dailyCheckin = true;
  bool _periodSoon = true;
  bool _phaseChange = true;
  bool _pms = true;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0); // 8:00 PM

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyCheckin = prefs.getBool(kNotifDailyCheckin) ?? true;
      _periodSoon = prefs.getBool(kNotifPeriodSoon) ?? true;
      _phaseChange = prefs.getBool(kNotifPhaseChange) ?? true;
      _pms = prefs.getBool(kNotifPms) ?? true;
      final hour = prefs.getInt(kNotifDailyHour) ?? 20;
      final minute = prefs.getInt(kNotifDailyMinute) ?? 0;
      _dailyTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    final cycleState = ref.read(cycleStateProvider);
    if (cycleState != null) {
      await NotificationService.schedulePhaseNotifications(cycleState);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: widget.colors.primary,
            surface: widget.colors.surface,
            onSurface: widget.colors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dailyTime = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kNotifDailyHour, picked.hour);
      await prefs.setInt(kNotifDailyMinute, picked.minute);
      await _rescheduleNotifications();
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return _BottomSheetContainer(
      colors: colors,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetTitle(label: 'Notifications', colors: colors),
          const SizedBox(height: 16),

          // Daily check-in with time picker
          _NotifRow(
            colors: colors,
            label: 'Daily check-in reminder',
            value: _dailyCheckin,
            onChanged: (v) {
              setState(() => _dailyCheckin = v);
              _setPref(kNotifDailyCheckin, v);
            },
            trailing: _dailyCheckin
                ? GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatTime(_dailyTime),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  )
                : null,
          ),

          _NotifRow(
            colors: colors,
            label: 'Period approaching (3 days)',
            value: _periodSoon,
            onChanged: (v) {
              setState(() => _periodSoon = v);
              _setPref(kNotifPeriodSoon, v);
            },
          ),

          _NotifRow(
            colors: colors,
            label: 'Phase change updates',
            value: _phaseChange,
            onChanged: (v) {
              setState(() => _phaseChange = v);
              _setPref(kNotifPhaseChange, v);
            },
          ),

          _NotifRow(
            colors: colors,
            label: 'PMS week heads-up',
            value: _pms,
            onChanged: (v) {
              setState(() => _pms = v);
              _setPref(kNotifPms, v);
            },
          ),

          const SizedBox(height: 16),

          // Immediate test notification button
          GestureDetector(
            onTap: () async {
              final granted = await NotificationService.requestPermission();
              await NotificationService.showImmediateNotification(
                title: 'Luna is active 🌙',
                body: 'Your cycle notifications and daily reminders are working smoothly.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: colors.surface,
                    content: Text(
                      granted
                          ? 'Test notification sent to status bar 🌙'
                          : 'Notification sent (ensure notifications are enabled in Android settings)',
                      style: GoogleFonts.dmSans(color: colors.onSurface),
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Send Test Notification',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Shared bottom-sheet container ─────────────────────────────────────────────
class _BottomSheetContainer extends StatelessWidget {
  final PhaseColors colors;
  final Widget child;
  const _BottomSheetContainer({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

// ── Sheet title ───────────────────────────────────────────────────────────────
class _SheetTitle extends StatelessWidget {
  final String label;
  final PhaseColors colors;
  const _SheetTitle({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
    );
  }
}

// ── Sheet save button ─────────────────────────────────────────────────────────
class _SheetSaveButton extends StatelessWidget {
  final PhaseColors colors;
  final VoidCallback onTap;
  const _SheetSaveButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'Save',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── +/- Number picker ─────────────────────────────────────────────────────────
class _NumberPicker extends StatelessWidget {
  final PhaseColors colors;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberPicker({
    required this.colors,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PickerButton(
          colors: colors,
          icon: Icons.remove,
          enabled: value > min,
          onTap: () {
            if (value > min) onChanged(value - 1);
          },
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                height: 1,
              ),
            ),
            Text(
              'days',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        _PickerButton(
          colors: colors,
          icon: Icons.add,
          enabled: value < max,
          onTap: () {
            if (value < max) onChanged(value + 1);
          },
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  final PhaseColors colors;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PickerButton({
    required this.colors,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? colors.primary.withValues(alpha: 0.14)
              : colors.onSurface.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.25),
          size: 22,
        ),
      ),
    );
  }
}

// ── Notification toggle row ───────────────────────────────────────────────────
class _NotifRow extends StatelessWidget {
  final PhaseColors colors;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  const _NotifRow({
    required this.colors,
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 10),
          ],
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
            inactiveTrackColor: colors.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final PhaseColors colors;
  const _SectionHeader({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────
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
}
