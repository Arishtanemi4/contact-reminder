import 'package:contact_reminder/features/events/event_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = DefaultEventCalculator();

  group('nextOccurrence', () {
    // (description, month, day, from, expected)
    final cases = <(String, int, int, DateTime, DateTime)>[
      ('same day is returned as-is', 5, 1, DateTime(2026, 5, 1), DateTime(2026, 5, 1)),
      ('later this year', 12, 25, DateTime(2026, 1, 1), DateTime(2026, 12, 25)),
      ('year rollover: already passed this year', 1, 1, DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
      ('year rollover: day after occurrence', 3, 10, DateTime(2026, 3, 11), DateTime(2027, 3, 10)),
      ('leap day, from before it in a leap year', 2, 29, DateTime(2024, 1, 1), DateTime(2024, 2, 29)),
      ('leap day, from a non-leap year observed on 28th', 2, 29, DateTime(2023, 1, 1), DateTime(2023, 2, 28)),
      ('leap day, next occurrence after a leap year rolls to non-leap 28th', 2, 29, DateTime(2024, 3, 1), DateTime(2025, 2, 28)),
      ('leap day, century non-leap year observed on 28th', 2, 29, DateTime(1900, 1, 1), DateTime(1900, 2, 28)),
      ('leap day, 400-year leap', 2, 29, DateTime(2000, 1, 1), DateTime(2000, 2, 29)),
      ('time-of-day is ignored (DST/timezone-insensitive)', 5, 1, DateTime(2026, 5, 1, 23, 59, 59), DateTime(2026, 5, 1)),
    ];

    for (final (desc, month, day, from, expected) in cases) {
      test(desc, () {
        expect(calc.nextOccurrence(month, day, from), expected);
      });
    }
  });

  group('eventsOn', () {
    test('true on the exact day', () {
      expect(calc.eventsOn(5, 1, DateTime(2026, 5, 1)), isTrue);
    });

    test('false on a different day', () {
      expect(calc.eventsOn(5, 1, DateTime(2026, 5, 2)), isFalse);
    });

    test('Feb 29 observed on Feb 28 in a non-leap year', () {
      expect(calc.eventsOn(2, 29, DateTime(2023, 2, 28)), isTrue);
      expect(calc.eventsOn(2, 29, DateTime(2023, 3, 1)), isFalse);
    });

    test('Feb 29 event does not fire on Feb 28 of a leap year', () {
      expect(calc.eventsOn(2, 29, DateTime(2024, 2, 28)), isFalse);
      expect(calc.eventsOn(2, 29, DateTime(2024, 2, 29)), isTrue);
    });

    test('time-of-day is ignored', () {
      expect(calc.eventsOn(5, 1, DateTime(2026, 5, 1, 8, 30)), isTrue);
    });
  });

  group('ageOrYears', () {
    test('no year known returns null', () {
      expect(calc.ageOrYears(null, DateTime(2026, 5, 1)), isNull);
    });

    test('computes elapsed years as of the given date', () {
      expect(calc.ageOrYears(1990, DateTime(2026, 5, 1)), 36);
    });
  });
}
