import 'package:contact_reminder/core/clock.dart';
import 'package:contact_reminder/core/notification_scheduler.dart';
import 'package:contact_reminder/core/notification_service.dart';
import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/features/events/event_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avoids touching the real `flutter_local_notifications` platform channel,
/// which isn't available under `flutter test`.
class _FakeNotificationService extends NotificationService {
  final scheduled = <int, DateTime>{};
  final titles = <int, String>{};
  final bodies = <int, String>{};
  final cancelled = <int>[];

  @override
  Future<void> scheduleAt(int id, String title, String body, DateTime when) async {
    scheduled[id] = when;
    titles[id] = title;
    bodies[id] = body;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

Contact _contact({int id = 1, String firstName = 'Asha', String? surname}) => Contact(
  id: id,
  groupId: 1,
  firstName: firstName,
  surname: surname,
  email: null,
  address: null,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

ContactEvent _event({
  int id = 1,
  int contactId = 1,
  EventType type = EventType.birthday,
  String? label,
  required int month,
  required int day,
  int? year,
}) => ContactEvent(
  id: id,
  contactId: contactId,
  type: type,
  label: label,
  month: month,
  day: day,
  year: year,
);

Setting _settings({String notifyTime = '08:00', int leadDays = 0}) => Setting(
  id: 1,
  notifyTime: notifyTime,
  defaultCountryCode: 'IN',
  leadDays: leadDays,
);

void main() {
  late _FakeNotificationService notifications;
  late NotificationScheduler scheduler;

  // "Now" is fixed at 10-May-2026, 06:00 (before the default 08:00 notify time).
  final now = DateTime(2026, 5, 10, 6);

  setUp(() {
    notifications = _FakeNotificationService();
    scheduler = NotificationScheduler(
      notifications,
      const DefaultEventCalculator(),
      _FixedClock(now),
    );
  });

  test('schedules a birthday today at the notify time', () async {
    final contact = _contact(firstName: 'Asha', surname: 'Rao');
    final event = _event(month: 5, day: 10, year: 1990);
    await scheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(),
    );

    expect(notifications.scheduled[1], DateTime(2026, 5, 10, 8));
    expect(notifications.cancelled, isEmpty);
  });

  test('rolls over to next year for an event later this month', () async {
    final contact = _contact();
    final event = _event(month: 4, day: 1);
    await scheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(),
    );

    expect(notifications.scheduled[1], DateTime(2027, 4, 1, 8));
  });

  test('applies leadDays before the event date', () async {
    final contact = _contact();
    final event = _event(month: 5, day: 20);
    await scheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(leadDays: 3),
    );

    expect(notifications.scheduled[1], DateTime(2026, 5, 17, 8));
  });

  test('cancels rather than firing when the notify time already passed today', () async {
    final contact = _contact();
    // Notify time (08:00) has already passed relative to "now" (14:00).
    final lateClock = _FixedClock(DateTime(2026, 5, 10, 14));
    final lateScheduler = NotificationScheduler(
      notifications,
      const DefaultEventCalculator(),
      lateClock,
    );
    final event = _event(month: 5, day: 10);
    await lateScheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(),
    );

    expect(notifications.scheduled, isEmpty);
    expect(notifications.cancelled, [1]);
  });

  test('uses the event label when set, otherwise the type', () async {
    final contact = _contact(firstName: 'Rahul');
    final event = _event(
      type: EventType.other,
      label: 'Work anniversary',
      month: 5,
      day: 10,
    );
    await scheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(),
    );

    expect(notifications.bodies[1], "Rahul's Work anniversary");
  });

  test('falls back to the event type when there is no label', () async {
    final contact = _contact(firstName: 'Asha', surname: 'Rao');
    final event = _event(type: EventType.birthday, month: 5, day: 10);
    await scheduler.rescheduleAll(
      [ContactWithDetails(contact, const [], [event])],
      _settings(),
    );

    expect(notifications.titles[1], 'Birthday reminder');
    expect(notifications.bodies[1], "Asha Rao's birthday");
  });
}
