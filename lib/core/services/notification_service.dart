import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../services/cycle_engine.dart';
import '../constants/phase_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> schedulePhaseNotifications(CycleState state) async {
    await _plugin.cancelAll();

    final now = DateTime.now();

    // Period approaching (3 days before)
    if (state.isPeriodSoon && state.daysUntilNextPeriod == 3) {
      await _schedule(
        id: 1,
        title: 'Hey girlie 🩸',
        body:
            'Your period might be arriving in a few days. Maybe stock up on your cozy things? 🍫🛁',
        scheduledDate: DateTime(now.year, now.month, now.day, 10, 0),
      );
    }

    // Period might have started (day 1 predicted, no log)
    if (state.daysUntilNextPeriod <= 0 && !state.isPeriodOverdue) {
      await _schedule(
        id: 2,
        title: 'Just checking in 🌙',
        body: 'Is today the day? No pressure, just tap to log if your period started 💕',
        scheduledDate: DateTime(now.year, now.month, now.day, 11, 0),
      );
    }

    // Period overdue
    if (state.isPeriodOverdue) {
      await _schedule(
        id: 3,
        title: 'Hey, haven\'t heard from you! 🫂',
        body:
            'Just checking in. How are you doing? Your period hasn\'t been logged yet.',
        scheduledDate: DateTime(now.year, now.month, now.day, 12, 0),
      );
    }

    // PMS phase daily comfort
    if (state.phase == CyclePhase.lateLuteal) {
      await _schedule(
        id: 4,
        title: 'Hey, your sensitive week might be hitting 💜',
        body:
            'Whatever you\'re feeling right now is valid. Luna has some comfort waiting for you 🌸',
        scheduledDate: DateTime(now.year, now.month, now.day, 20, 0),
      );
    }

    // Ovulation celebration
    if (state.phase == CyclePhase.ovulatory) {
      await _schedule(
        id: 5,
        title: 'You are literally glowing today ✨',
        body: 'Peak energy day! Your brain is at its sharpest. What are you gonna do with all that power? 💅',
        scheduledDate: DateTime(now.year, now.month, now.day, 9, 0),
      );
    }
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(
      scheduledDate.isBefore(DateTime.now())
          ? scheduledDate.add(const Duration(days: 1))
          : scheduledDate,
      tz.local,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'luna_channel',
          'Luna Notifications',
          channelDescription: 'Your cycle companion',
          importance: Importance.high,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

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
          'luna_channel',
          'Luna Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
