import 'spreadsheet_service.dart';

/// Outcome of parsing one date cell.
class DateParseResult {
  const DateParseResult.ok(this.date) : reason = null;
  const DateParseResult.error(this.reason) : date = null;

  final ParsedDate? date;
  final String? reason;
  bool get isOk => date != null;
}

/// Parses one spreadsheet date cell into (month, day, year?).
///
/// Wrapped behind an interface so a Rust implementation (Phase 6) can
/// replace it later without touching callers.
abstract interface class DateParser {
  /// Accepts a [DateTime] (native Excel date cell, already resolved by the
  /// `excel` package), a numeric Excel day-serial, or text in one of
  /// `dd-MMM[-yyyy]`, `dd/MM[/yyyy]`, `dd-MM-yyyy`, ISO `yyyy-MM-dd`.
  DateParseResult parse(Object value);
}

/// Default [DateParser]. Day/month are validated against the calendar
/// (leap years only checked when a year is known); Feb 29 is accepted even
/// without a year, since birthdays/anniversaries recur on it regardless
/// (see `EventCalculator`, Phase 5).
class FlexibleDateParser implements DateParser {
  const FlexibleDateParser();

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // Excel's day-0 epoch.
  static final _excelEpoch = DateTime(1899, 12, 30);

  static final _iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final _dMonY =
      RegExp(r'^(\d{1,2})-([A-Za-z]{3})[A-Za-z]*(?:-(\d{4}))?$');
  static final _dmy = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');
  static final _dSlashM = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{4}))?$');

  @override
  DateParseResult parse(Object value) {
    if (value is DateTime) {
      return _validated(value.month, value.day, value.year);
    }
    if (value is num) {
      final dt = _excelEpoch.add(Duration(days: value.floor()));
      return _validated(dt.month, dt.day, dt.year);
    }
    if (value is! String) {
      return const DateParseResult.error('unsupported value type');
    }
    final text = value.trim();
    if (text.isEmpty) return const DateParseResult.error('empty date');

    var m = _iso.firstMatch(text);
    if (m != null) {
      return _validated(
          int.parse(m.group(2)!), int.parse(m.group(3)!), int.parse(m.group(1)!));
    }
    m = _dMonY.firstMatch(text);
    if (m != null) {
      final month = _months[m.group(2)!.toLowerCase()];
      if (month == null) {
        return DateParseResult.error('unrecognised month "${m.group(2)}"');
      }
      final year = m.group(3) != null ? int.parse(m.group(3)!) : null;
      return _validated(month, int.parse(m.group(1)!), year);
    }
    m = _dmy.firstMatch(text);
    if (m != null) {
      return _validated(
          int.parse(m.group(2)!), int.parse(m.group(1)!), int.parse(m.group(3)!));
    }
    m = _dSlashM.firstMatch(text);
    if (m != null) {
      final year = m.group(3) != null ? int.parse(m.group(3)!) : null;
      return _validated(int.parse(m.group(2)!), int.parse(m.group(1)!), year);
    }
    return DateParseResult.error('unrecognised date format: "$text"');
  }

  DateParseResult _validated(int month, int day, int? year) {
    if (month < 1 || month > 12) {
      return DateParseResult.error('month $month out of range');
    }
    final maxDay = _daysInMonth(month, year);
    if (day < 1 || day > maxDay) {
      return DateParseResult.error('day $day out of range for month $month');
    }
    return DateParseResult.ok(ParsedDate(month: month, day: day, year: year));
  }

  int _daysInMonth(int month, int? year) {
    const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]; // Feb generic = 29
    if (month == 2 && year != null && !_isLeap(year)) return 28;
    return days[month - 1];
  }

  bool _isLeap(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
