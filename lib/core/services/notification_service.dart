import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../services/cycle_engine.dart';
import '../constants/phase_constants.dart';

// Preference keys matching settings
const _kNotifDailyCheckin = 'notif_daily_checkin';
const _kNotifPeriodSoon = 'notif_period_soon';
const _kNotifPhaseChange = 'notif_phase_change';
const _kNotifPms = 'notif_pms';
const _kNotifDailyHour = 'notif_daily_hour';
const _kNotifDailyMinute = 'notif_daily_minute';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'luna_channel';
  static const String channelName = 'Luna Notifications';
  static const String channelDescription =
      'Daily cycle intelligence, period reminders, and comfort updates';

  static const Color brandColor = Color(0xFFD94F6E);

  /// Initializes timezone data, notification channels, and Android settings
  static Future<void> init() async {
    // 1. Initialize Timezone database and align with local device offset
    tz.initializeTimeZones();
    _configureLocalTimezone();

    // 2. Android Initialization Settings with dedicated custom silhouette icon
    const androidInit =
        AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // App opened from notification
      },
    );

    // 3. Create high-importance notification channel for Android 8.0+ (API 26+)
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Sets the timezone location matching the device's current UTC offset
  static void _configureLocalTimezone() {
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (_) {
      // Graceful fallback to UTC if offset matching fails
    }
  }

  /// Explicitly requests notification permission on Android 13+ (API 33+)
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Determines the safest schedule mode supported by the device
  static Future<AndroidScheduleMode> _getSafeScheduleMode() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (canExact) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // In case of unsupported API
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Schedules all phase-aware and daily reminder notifications respecting user preferences
  static Future<void> schedulePhaseNotifications(CycleState state) async {
    await _plugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final dailyCheckinEnabled = prefs.getBool(_kNotifDailyCheckin) ?? true;
    final periodSoonEnabled = prefs.getBool(_kNotifPeriodSoon) ?? true;
    final phaseChangeEnabled = prefs.getBool(_kNotifPhaseChange) ?? true;
    final pmsEnabled = prefs.getBool(_kNotifPms) ?? true;
    final dailyHour = prefs.getInt(_kNotifDailyHour) ?? 20;
    final dailyMinute = prefs.getInt(_kNotifDailyMinute) ?? 0;

    final safeScheduleMode = await _getSafeScheduleMode();

    // ── 1. Daily Check-in Reminder (Recurring daily at configured time) ─────────
    if (dailyCheckinEnabled) {
      await _scheduleDailyCheckin(
        hour: dailyHour,
        minute: dailyMinute,
        scheduleMode: safeScheduleMode,
      );
    }

    final now = DateTime.now();

    // ── 2. Period Approaching (3 days before predicted start date) ────────────
    if (periodSoonEnabled && state.isPeriodSoon && state.daysUntilNextPeriod == 3) {
      final targetDate = DateTime(now.year, now.month, now.day, 10, 0);
      await _scheduleZoned(
        id: 20,
        title: 'Hey gentle check-in 🩸',
        body: 'Your cycle reset is expected in ~3 days. Stock up on warm comforts, magnesium, and hydration. 🍫🛁',
        scheduledDate: targetDate,
        scheduleMode: safeScheduleMode,
      );
    }

    // ── 3. Period Start Expected Today (Day 1 predicted, no log yet) ──────────
    if (periodSoonEnabled && state.daysUntilNextPeriod <= 0 && !state.isPeriodOverdue) {
      final targetDate = DateTime(now.year, now.month, now.day, 11, 0);
      await _scheduleZoned(
        id: 21,
        title: 'Checking in on you 🌙',
        body: 'Is today Day 1? Tap to log your bleed and align your daily guidance. 💕',
        scheduledDate: targetDate,
        scheduleMode: safeScheduleMode,
      );
    }

    // ── 4. Period Overdue (Unlogged cycle variance) ───────────────────────────
    if (periodSoonEnabled && state.isPeriodOverdue) {
      final targetDate = DateTime(now.year, now.month, now.day, 12, 0);
      await _scheduleZoned(
        id: 22,
        title: 'Thinking of you 🫂',
        body: 'Cycle variation is completely normal. Tap to update your rhythm or check in today.',
        scheduledDate: targetDate,
        scheduleMode: safeScheduleMode,
      );
    }

    // ── 5. PMS Phase Daily Comfort ───────────────────────────────────────────
    if (pmsEnabled && state.phase == CyclePhase.lateLuteal) {
      final targetDate = DateTime(now.year, now.month, now.day, 19, 30);
      await _scheduleZoned(
        id: 30,
        title: 'Sensitive week reminder 💜',
        body: 'Hormonal reset is in motion. Be radically gentle with your energy tonight. 🌸',
        scheduledDate: targetDate,
        scheduleMode: safeScheduleMode,
      );
    }

    // ── 6. Ovulation Window Celebration ──────────────────────────────────────
    if (phaseChangeEnabled && state.phase == CyclePhase.ovulatory) {
      final targetDate = DateTime(now.year, now.month, now.day, 9, 30);
      await _scheduleZoned(
        id: 40,
        title: 'Peak energy window ✨',
        body: 'Estrogen and LH are surging. Your verbal clarity and stamina are at their peak today! 💅',
        scheduledDate: targetDate,
        scheduleMode: safeScheduleMode,
      );
    }
  }

  /// Schedules a daily repeating check-in notification
  static Future<void> _scheduleDailyCheckin({
    required int hour,
    required int minute,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      10,
      'Time for your evening check-in 🌙',
      'Take 30 seconds to log your mood, energy, and physical state today.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: brandColor,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules a specific one-off zoned notification
  static Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final now = DateTime.now();
    final target = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    final tzTarget = tz.TZDateTime.from(target, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTarget,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: brandColor,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Displays an immediate test notification to verify icons, sound, and channel on device
  static Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      99,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          color: brandColor,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }
}
