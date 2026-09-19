/// Pure date arithmetic for birthdays/anniversaries/other events.
///
/// Wrapped behind an interface so a Rust implementation (Phase 6) can replace
/// it later without touching callers. Date-only: callers should not rely on
/// time-of-day, and all comparisons ignore it.
abstract interface class EventCalculator {
  /// The next date on or after [from] (inclusive) that (month, day) occurs.
  /// Feb 29 is observed on Feb 28 in years that aren't leap years.
  DateTime nextOccurrence(int month, int day, DateTime from);

  /// True if an event with this month/day falls on [date] (same Feb 29 →
  /// Feb 28 rule as [nextOccurrence]).
  bool eventsOn(int month, int day, DateTime date);

  /// Age (birthday) or years elapsed (anniversary/other) as of [asOf], or
  /// null if [year] is unknown.
  int? ageOrYears(int? year, DateTime asOf);
}

class DefaultEventCalculator implements EventCalculator {
  const DefaultEventCalculator();

  @override
  DateTime nextOccurrence(int month, int day, DateTime from) {
    final today = _dateOnly(from);
    var candidate = _observed(today.year, month, day);
    if (candidate.isBefore(today)) {
      candidate = _observed(today.year + 1, month, day);
    }
    return candidate;
  }

  @override
  bool eventsOn(int month, int day, DateTime date) =>
      _observed(date.year, month, day) == _dateOnly(date);

  @override
  int? ageOrYears(int? year, DateTime asOf) => year == null ? null : asOf.year - year;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// (month, day) as actually observed in [year] (Feb 29 → Feb 28 when
  /// [year] isn't a leap year).
  DateTime _observed(int year, int month, int day) {
    final observedDay = (month == 2 && day == 29 && !_isLeapYear(year)) ? 28 : day;
    return DateTime(year, month, observedDay);
  }

  bool _isLeapYear(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
