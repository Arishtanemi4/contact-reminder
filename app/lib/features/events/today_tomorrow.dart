import '../../data/contact_repository.dart';
import '../../data/database.dart';
import 'event_calculator.dart';

/// One contact's event, falling on [date] (today or tomorrow).
class EventOccurrence {
  const EventOccurrence({
    required this.contact,
    required this.phones,
    required this.event,
    required this.date,
  });

  final Contact contact;
  final List<ContactPhone> phones;
  final ContactEvent event;
  final DateTime date;
}

/// Every contact's events split into today's and tomorrow's, sorted by name.
class TodayTomorrow {
  const TodayTomorrow({required this.today, required this.tomorrow});

  final List<EventOccurrence> today;
  final List<EventOccurrence> tomorrow;

  factory TodayTomorrow.build(
    List<ContactWithDetails> contacts,
    DateTime today,
    EventCalculator calc,
  ) {
    final tomorrow = today.add(const Duration(days: 1));
    final todayList = <EventOccurrence>[];
    final tomorrowList = <EventOccurrence>[];
    for (final c in contacts) {
      for (final e in c.events) {
        if (calc.eventsOn(e.month, e.day, today)) {
          todayList.add(EventOccurrence(
            contact: c.contact,
            phones: c.phones,
            event: e,
            date: today,
          ));
        } else if (calc.eventsOn(e.month, e.day, tomorrow)) {
          tomorrowList.add(EventOccurrence(
            contact: c.contact,
            phones: c.phones,
            event: e,
            date: tomorrow,
          ));
        }
      }
    }
    int byName(EventOccurrence a, EventOccurrence b) =>
        a.contact.firstName.compareTo(b.contact.firstName);
    todayList.sort(byName);
    tomorrowList.sort(byName);
    return TodayTomorrow(today: todayList, tomorrow: tomorrowList);
  }
}
