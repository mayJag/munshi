import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Payload emitted by reminder notifications; tapping deep-links into quick-add.
const String kQuickAddPayload = 'quick_add';

/// Wraps flutter_local_notifications for Munshi's reminders. Phase-0 Spike 2
/// proves: scheduling (hourly repeat + daily-at-time), reboot survival (via the
/// boot receiver in the manifest), and deep-link on tap.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set by the app so a notification tap can drive navigation.
  VoidCallback? onQuickAddRequested;

  bool _initialized = false;

  static const AndroidNotificationDetails _reminderDetails =
      AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Scheduled reminders to log your spending',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _reminderDetails);

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // Local zone; IST for this build. A settings-driven zone can override later.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
  }

  void _onTap(NotificationResponse response) {
    if (response.payload == kQuickAddPayload) {
      onQuickAddRequested?.call();
    }
  }

  /// If the app was launched by tapping a notification, returns its payload.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  /// Android 13+ runtime notification permission + exact-alarm permission.
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission() ?? false;
    await android.requestExactAlarmsPermission();
    return granted;
  }

  /// Fire immediately — used by the spike to confirm the channel works.
  Future<void> showTestNow() {
    return _plugin.show(
      id: 0,
      title: 'Munshi',
      body: 'Test notification — the channel works ✅',
      notificationDetails: _details,
      payload: kQuickAddPayload,
    );
  }

  /// One-shot at [seconds] from now (spike: verify scheduling + tap payload).
  Future<void> scheduleInSeconds(int seconds) {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    return _plugin.zonedSchedule(
      id: 1,
      title: 'Munshi reminder',
      body: 'Scheduled $seconds s ago — tap to log an expense',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: kQuickAddPayload,
    );
  }

  /// Repeating every hour (inexact — survives Doze; good enough for reminders).
  Future<void> scheduleHourly() {
    return _plugin.periodicallyShow(
      id: 2,
      title: 'Munshi',
      body: 'Hourly nudge — logged everything?',
      repeatInterval: RepeatInterval.hourly,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: kQuickAddPayload,
    );
  }

  /// Daily at [hour]:[minute] local time, repeating.
  Future<void> scheduleDailyAt(int hour, int minute) {
    return _plugin.zonedSchedule(
      id: 3,
      title: 'Munshi',
      body: 'Daily check-in — add today\'s spending',
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: kQuickAddPayload,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  Future<void> cancelAll() => _plugin.cancelAll();
}
