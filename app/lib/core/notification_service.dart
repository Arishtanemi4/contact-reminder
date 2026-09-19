import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications`: channel setup, permission checks, and
/// showing notifications. One shared instance backs both the manual "test
/// notification" button (Settings) and the reminder scheduler (Phase 5.4).
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const channelId = 'reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Birthday, anniversary and other event reminders';

  /// Creates the notification channel and sets the local timezone (needed by
  /// `scheduleAt`). Call once before any other method (done at app start in
  /// `main.dart`).
  Future<void> init() async {
    tz_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
    await _android()?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? _android() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// True if the user has granted notification permission.
  Future<bool> notificationsEnabled() async =>
      await _android()?.areNotificationsEnabled() ?? false;

  /// Prompts for the `POST_NOTIFICATIONS` permission (Android 13+; a no-op,
  /// already-granted result on older versions).
  Future<bool> requestPermission() async =>
      await _android()?.requestNotificationsPermission() ?? true;

  /// True if the app can schedule exact alarms (Android 12+).
  Future<bool> canScheduleExactAlarms() async =>
      await _android()?.canScheduleExactNotifications() ?? true;

  /// Opens the system dialog to grant the exact-alarm permission.
  Future<void> requestExactAlarmsPermission() async =>
      _android()?.requestExactAlarmsPermission();

  /// Opens this app's notification settings page.
  Future<void> openSystemSettings() async => _android()?.openAppNotificationSettings();

  Future<void> showNow(int id, String title, String body) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
      ),
    ),
  );

  /// Schedules (replacing any existing alarm with the same [id]) a
  /// notification for [when]. Uses an exact alarm when the permission has
  /// been granted, otherwise falls back to an inexact one.
  Future<void> scheduleAt(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    final exact = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels a previously scheduled notification, if any.
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
