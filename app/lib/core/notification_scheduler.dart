import '../data/contact_repository.dart';
import '../data/database.dart';
import '../features/events/event_calculator.dart';
import 'clock.dart';
import 'notification_service.dart';

/// Keeps scheduled notifications in sync with each contact event's next
/// occurrence. Re-run whenever contacts or settings change (see
/// `rescheduleNotifications`); notification ids are `ContactEvent.id`, so
/// re-scheduling an event simply replaces its existing alarm.
class NotificationScheduler {
  NotificationScheduler(this._notifications, this._calculator, this._clock);

  final NotificationService _notifications;
  final EventCalculator _calculator;
  final Clock _clock;

  /// Ids scheduled by the previous call, so events that no longer exist (e.g.
  /// an edited event, which `ContactRepository.update` recreates under a new
  /// id) have their stale alarm cancelled rather than left dangling.
  Set<int> _lastScheduledIds = {};

  Future<void> rescheduleAll(
    List<ContactWithDetails> contacts,
    Setting settings,
  ) async {
    final notifyTime = _parseTime(settings.notifyTime);
    final now = _clock.now();
    final currentIds = <int>{};
    for (final c in contacts) {
      for (final e in c.events) {
        currentIds.add(e.id);
        final when = _notifyMoment(e, settings.leadDays, notifyTime, now);
        // If the notify moment for the current occurrence has already
        // passed (e.g. the app was reopened after today's notify time), skip
        // it rather than firing immediately or waiting a year; the event is
        // still visible on the Today screen.
        if (when.isAfter(now)) {
          await _notifications.scheduleAt(e.id, _title(e.type), _body(c.contact, e), when);
        } else {
          await _notifications.cancel(e.id);
        }
      }
    }
    for (final staleId in _lastScheduledIds.difference(currentIds)) {
      await _notifications.cancel(staleId);
    }
    _lastScheduledIds = currentIds;
  }

  DateTime _notifyMoment(
    ContactEvent e,
    int leadDays,
    (int hour, int minute) notifyTime,
    DateTime now,
  ) {
    final eventDate = _calculator.nextOccurrence(e.month, e.day, now);
    final notifyDate = eventDate.subtract(Duration(days: leadDays));
    return DateTime(
      notifyDate.year,
      notifyDate.month,
      notifyDate.day,
      notifyTime.$1,
      notifyTime.$2,
    );
  }

  (int hour, int minute) _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  String _title(EventType type) => switch (type) {
    EventType.birthday => 'Birthday reminder',
    EventType.anniversary => 'Anniversary reminder',
    EventType.other => 'Event reminder',
  };

  String _body(Contact c, ContactEvent e) {
    final name = [c.firstName, c.surname].whereType<String>().join(' ');
    final what =
        e.label ??
        switch (e.type) {
          EventType.birthday => 'birthday',
          EventType.anniversary => 'anniversary',
          EventType.other => 'event',
        };
    return "$name's $what";
  }
}
