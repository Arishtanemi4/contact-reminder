import 'dart:typed_data';

/// A month/day, with optional year, parsed from a spreadsheet cell.
class ParsedDate {
  const ParsedDate({required this.month, required this.day, this.year});

  final int month;
  final int day;
  final int? year;

  @override
  bool operator ==(Object other) =>
      other is ParsedDate &&
      other.month == month &&
      other.day == day &&
      other.year == year;

  @override
  int get hashCode => Object.hash(month, day, year);

  @override
  String toString() =>
      'ParsedDate($month/$day${year != null ? '/$year' : ''})';
}

/// One of the up-to-3 "other event" name+date pairs.
class ParsedEvent {
  const ParsedEvent({required this.name, required this.date});

  final String name;
  final ParsedDate date;

  @override
  bool operator ==(Object other) =>
      other is ParsedEvent && other.name == name && other.date == date;

  @override
  int get hashCode => Object.hash(name, date);
}

/// Why one field of one row couldn't be used, for the per-row report shown
/// to the user. Rows are never dropped silently.
class RowIssue {
  const RowIssue({
    required this.rowNumber,
    required this.field,
    required this.reason,
  });

  /// 1-based, matching the spreadsheet row (header row excluded).
  final int rowNumber;

  /// Column the issue applies to, e.g. "Phone 1", "Date of Birth".
  final String field;
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is RowIssue &&
      other.rowNumber == rowNumber &&
      other.field == field &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(rowNumber, field, reason);

  @override
  String toString() => 'Row $rowNumber, $field: $reason';
}

/// One data row from a sheet, already matched against the known columns.
///
/// A row with a missing/invalid required field (first name, phone 1) has
/// [isValid] false and is skipped on import; its [issues] still surface in
/// the report. A valid row may still carry issues on optional fields (e.g.
/// an unparsable date), which are simply left unset.
class ParsedRow {
  const ParsedRow({
    required this.rowNumber,
    this.firstName,
    this.surname,
    this.phones = const [],
    this.dob,
    this.anniversary,
    this.otherEvents = const [],
    this.email,
    this.address,
    this.issues = const [],
  });

  final int rowNumber;
  final String? firstName;
  final String? surname;

  /// Up to 3, in column order, blanks dropped.
  final List<String> phones;
  final ParsedDate? dob;
  final ParsedDate? anniversary;

  /// Up to 3.
  final List<ParsedEvent> otherEvents;
  final String? email;
  final String? address;
  final List<RowIssue> issues;

  bool get isValid =>
      firstName != null && firstName!.isNotEmpty && phones.isNotEmpty;
}

/// One sheet, i.e. one contact group.
class ParsedSheet {
  const ParsedSheet({required this.name, required this.rows});

  final String name;
  final List<ParsedRow> rows;

  List<RowIssue> get issues => [for (final r in rows) ...r.issues];
}

class ImportResult {
  const ImportResult({required this.sheets});

  final List<ParsedSheet> sheets;

  List<RowIssue> get issues => [for (final s in sheets) ...s.issues];
}

/// Column headers, in file order. Required columns carry a trailing `*` for
/// the human reader; header matching trims and strips it.
const kFirstNameHeader = 'First Name*';
const kSurnameHeader = 'Surname';
const kPhone1Header = 'Phone 1*';
const kPhone2Header = 'Phone 2';
const kPhone3Header = 'Phone 3';
const kDobHeader = 'Date of Birth';
const kAnniversaryHeader = 'Marriage Anniversary';
const kEvent1NameHeader = 'Event 1 Name';
const kEvent1DateHeader = 'Event 1 Date';
const kEvent2NameHeader = 'Event 2 Name';
const kEvent2DateHeader = 'Event 2 Date';
const kEvent3NameHeader = 'Event 3 Name';
const kEvent3DateHeader = 'Event 3 Date';
const kEmailHeader = 'Email';
const kAddressHeader = 'Address';

const kSheetHeaders = [
  kFirstNameHeader,
  kSurnameHeader,
  kPhone1Header,
  kPhone2Header,
  kPhone3Header,
  kDobHeader,
  kAnniversaryHeader,
  kEvent1NameHeader,
  kEvent1DateHeader,
  kEvent2NameHeader,
  kEvent2DateHeader,
  kEvent3NameHeader,
  kEvent3DateHeader,
  kEmailHeader,
  kAddressHeader,
];

/// Parses/builds the .xlsx import/export format. Behind an interface so a
/// Rust implementation (Phase 6) can replace it later without touching
/// callers.
abstract interface class SpreadsheetService {
  /// Parses an .xlsx file; one sheet per group. Never throws on bad data —
  /// problems are collected as [RowIssue]s.
  ImportResult parse(Uint8List bytes);

  /// Writes [sheets] back out in the same column layout, one sheet per
  /// group, so the file round-trips with [parse].
  Uint8List build(List<ParsedSheet> sheets);

  /// A blank file with just the header row, for the user to fill in.
  Uint8List template();
}
