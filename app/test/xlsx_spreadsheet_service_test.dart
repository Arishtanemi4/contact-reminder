import 'dart:io';
import 'dart:typed_data';

import 'package:contact_reminder/features/import_export/spreadsheet_service.dart';
import 'package:contact_reminder/features/import_export/xlsx_spreadsheet_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

/// Finds a sheet by name, failing the test if it isn't present.
ParsedSheet _sheet(ImportResult result, String name) =>
    result.sheets.firstWhere((s) => s.name == name,
        orElse: () => throw StateError('no sheet "$name" in ${result.sheets.map((s) => s.name)}'));

void main() {
  const service = XlsxSpreadsheetService();

  test('valid multi-sheet: rows imported with no issues', () {
    final result = service.parse(_fixture('valid_multi_sheet.xlsx'));
    expect(result.sheets.map((s) => s.name), ['Friends', 'Relatives']);
    expect(result.issues, isEmpty);

    final friends = _sheet(result, 'Friends');
    expect(friends.rows, hasLength(2));

    final john = friends.rows[0];
    expect(john.firstName, 'John');
    expect(john.surname, 'Doe');
    expect(john.phones, ['9876543210']);
    expect(john.dob, const ParsedDate(month: 8, day: 15, year: 1990));
    expect(john.anniversary, isNull);
    expect(john.otherEvents, [
      const ParsedEvent(name: 'Graduation', date: ParsedDate(month: 6, day: 10, year: 2015)),
    ]);
    expect(john.email, 'john@example.com');
    expect(john.address, '123 Main St');
    expect(john.isValid, isTrue);

    final priya = friends.rows[1];
    expect(priya.firstName, 'Priya');
    expect(priya.phones, ['+91 98765 12345', '9998887776']);
    expect(priya.dob, const ParsedDate(month: 3, day: 5));
    expect(priya.anniversary, const ParsedDate(month: 11, day: 20, year: 2010));
    expect(priya.otherEvents, isEmpty);

    final relatives = _sheet(result, 'Relatives');
    expect(relatives.rows, hasLength(2));

    final amit = relatives.rows[0];
    expect(amit.dob, const ParsedDate(month: 12, day: 1)); // dd/MM, no year
    expect(amit.anniversary, const ParsedDate(month: 2, day: 14, year: 2005)); // dd-MM-yyyy
    expect(amit.otherEvents, [
      const ParsedEvent(name: 'Housewarming', date: ParsedDate(month: 7, day: 4, year: 2021)), // ISO
      const ParsedEvent(name: 'Retirement', date: ParsedDate(month: 1, day: 1, year: 2023)),
    ]);

    final sunita = relatives.rows[1];
    expect(sunita.firstName, 'Sunita');
    expect(sunita.surname, isNull);
    expect(sunita.phones, ['9988776655', '9112233445']); // phone 2 blank, dropped
    expect(sunita.email, 'sunita@example.com');
  });

  test('missing required fields reported, never dropped', () {
    final result = service.parse(_fixture('missing_required.xlsx'));
    final rows = _sheet(result, 'Bad').rows;
    expect(rows, hasLength(3));

    expect(rows[0].isValid, isFalse);
    expect(rows[0].issues, [
      const RowIssue(rowNumber: 1, field: kFirstNameHeader, reason: 'first name is required'),
    ]);

    expect(rows[1].isValid, isFalse);
    expect(rows[1].issues, [
      const RowIssue(
          rowNumber: 2, field: kPhone1Header, reason: 'at least one phone number is required'),
    ]);

    expect(rows[2].isValid, isTrue);
    expect(rows[2].issues, isEmpty);
  });

  test('bad dates reported per field, row otherwise imported', () {
    final result = service.parse(_fixture('bad_dates.xlsx'));
    final rows = _sheet(result, 'Dates').rows;
    expect(rows, hasLength(3));

    expect(rows[0].isValid, isTrue);
    expect(rows[0].dob, isNull);
    expect(rows[0].issues, hasLength(1));
    expect(rows[0].issues.single.field, kDobHeader);

    expect(rows[1].anniversary, isNull);
    expect(rows[1].issues, hasLength(1));
    expect(rows[1].issues.single.field, kAnniversaryHeader);

    expect(rows[2].otherEvents, isEmpty);
    expect(rows[2].issues, hasLength(1));
    expect(rows[2].issues.single.field, 'Event 1 Date');
  });

  test('dates as text: all four accepted formats parse', () {
    final result = service.parse(_fixture('dates_as_text.xlsx'));
    final rows = _sheet(result, 'TextDates').rows;
    expect(rows.map((r) => r.issues), everyElement(isEmpty));
    expect(rows[0].dob, const ParsedDate(month: 8, day: 15)); // dd-MMM
    expect(rows[1].dob, const ParsedDate(month: 3, day: 5)); // dd/MM
    expect(rows[2].dob, const ParsedDate(month: 11, day: 20, year: 2010)); // dd-MM-yyyy
    expect(rows[3].dob, const ParsedDate(month: 11, day: 20, year: 2010)); // ISO
  });

  test('dates as native date cells parse', () {
    final result = service.parse(_fixture('dates_as_date_cells.xlsx'));
    final row = _sheet(result, 'DateCells').rows.single;
    expect(row.issues, isEmpty);
    expect(row.dob, const ParsedDate(month: 4, day: 2, year: 1988));
    expect(row.anniversary, const ParsedDate(month: 9, day: 30, year: 2012));
    expect(row.otherEvents, [
      const ParsedEvent(name: 'Milestone', date: ParsedDate(month: 1, day: 1, year: 2020)),
    ]);
  });

  test('extra unrecognised columns are ignored', () {
    final result = service.parse(_fixture('extra_columns.xlsx'));
    final row = _sheet(result, 'Extra').rows.single;
    expect(row.issues, isEmpty);
    expect(row.firstName, 'Zara');
    expect(row.phones, ['9876500020']);
  });

  test('mixed-case / whitespace headers still match', () {
    final result = service.parse(_fixture('mixed_case_headers.xlsx'));
    final row = _sheet(result, 'MixedCase').rows.single;
    expect(row.issues, isEmpty);
    expect(row.firstName, 'Om');
    expect(row.phones, ['9876500030']);
  });

  test('sheet with only a header row imports as an empty group', () {
    final result = service.parse(_fixture('empty_sheet.xlsx'));
    expect(_sheet(result, 'Empty').rows, isEmpty);
  });

  test('unreadable bytes reported as an issue, not thrown', () {
    expect(() => service.parse(Uint8List.fromList([1, 2, 3])), returnsNormally);
    final result = service.parse(Uint8List.fromList([1, 2, 3]));
    expect(result.issues, hasLength(1));
    expect(result.issues.single.field, 'file');
  });

  test('round-trip: import, build, re-import gives back the same data', () {
    final original = service.parse(_fixture('valid_multi_sheet.xlsx'));
    final reimported = service.parse(service.build(original.sheets));

    expect(reimported.sheets.map((s) => s.name), original.sheets.map((s) => s.name));
    expect(reimported.issues, isEmpty);
    for (var i = 0; i < original.sheets.length; i++) {
      final origRows = original.sheets[i].rows;
      final newRows = reimported.sheets[i].rows;
      expect(newRows, hasLength(origRows.length));
      for (var r = 0; r < origRows.length; r++) {
        expect(newRows[r].firstName, origRows[r].firstName);
        expect(newRows[r].surname, origRows[r].surname);
        expect(newRows[r].phones, origRows[r].phones);
        expect(newRows[r].dob, origRows[r].dob);
        expect(newRows[r].anniversary, origRows[r].anniversary);
        expect(newRows[r].otherEvents, origRows[r].otherEvents);
        expect(newRows[r].email, origRows[r].email);
        expect(newRows[r].address, origRows[r].address);
      }
    }
  });

  test('template: header row only, no data rows', () {
    final result = service.parse(service.template());
    expect(result.issues, isEmpty);
    expect(result.sheets, hasLength(1));
    expect(result.sheets.single.rows, isEmpty);
  });
}
