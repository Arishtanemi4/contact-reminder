import 'package:workmanager/workmanager.dart';

import '../data/contact_repository.dart';
import '../data/database.dart';
import '../data/settings_repository.dart';
import '../features/events/event_calculator.dart';
import 'clock.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

/// Unique id (also used as the task name) for the daily top-up job.
const _rebuildTaskName = 'rebuildReminders';

/// Registers the daily WorkManager job that re-runs [NotificationScheduler]
/// so events that fired their alarm (or whose alarm an OEM silently dropped)
/// get their next occurrence rescheduled even if the app isn't opened.
/// Call once at app start (see `main.dart`); `keep` makes repeat calls
/// no-ops rather than resetting the schedule.
Future<void> registerBackgroundRebuild() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _rebuildTaskName,
    _rebuildTaskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Entry point Android runs (in a separate background isolate) when the
/// WorkManager job is due. Must stay a top-level/static function annotated
/// `vm:entry-point` so the engine can find it without running `main()`.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _rebuildTaskName) {
      await _rebuildReminders();
    }
    return true;
  });
}

/// Opens the DB and notification plugin fresh (this isolate has neither) and
/// reschedules against current contacts/settings, same as
/// `rescheduleNotifications` does on the UI isolate.
Future<void> _rebuildReminders() async {
  final db = AppDatabase();
  try {
    final notifications = NotificationService();
    await notifications.init();
    final contacts = await ContactRepository(db).watchAll().first;
    final settings = await SettingsRepository(db).get();
    final scheduler = NotificationScheduler(
      notifications,
      const DefaultEventCalculator(),
      const SystemClock(),
    );
    await scheduler.rescheduleAll(contacts, settings);
  } finally {
    await db.close();
  }
}
