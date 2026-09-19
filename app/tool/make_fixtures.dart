// Generates the .xlsx fixtures under test/fixtures/, used by the
// import/export tests (Phase 4). Fixtures are committed, so re-run this only
// when the format under test needs to change:
//
//   dart run tool/make_fixtures.dart

import 'dart:io';

import 'package:contact_reminder/features/import_export/spreadsheet_service.dart';
import 'package:excel/excel.dart';

void main() {
  final dir = Directory('test/fixtures')..createSync(recursive: true);
  _write(dir, 'valid_multi_sheet.xlsx', _validMultiSheet());
  _write(dir, 'missing_required.xlsx', _missingRequired());
  _write(dir, 'bad_dates.xlsx', _badDates());
  _write(dir, 'dates_as_text.xlsx', _datesAsText());
  _write(dir, 'dates_as_date_cells.xlsx', _datesAsDateCells());
  _write(dir, 'extra_columns.xlsx', _extraColumns());
  _write(dir, 'mixed_case_headers.xlsx', _mixedCaseHeaders());
  _write(dir, 'empty_sheet.xlsx', _emptySheet());
}

void _write(Directory dir, String name, Excel excel) {
  final bytes = excel.encode()!;
  File('${dir.path}/$name').writeAsBytesSync(bytes);
  stdout.writeln('wrote ${dir.path}/$name');
}

/// A fresh workbook with [sheetNames] created (in order) and the library's
/// own default sheet removed.
Excel _workbook(List<String> sheetNames) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  for (final name in sheetNames) {
    excel[name];
  }
  if (defaultSheet != null && !sheetNames.contains(defaultSheet)) {
    excel.delete(defaultSheet);
  }
  return excel;
}

CellValue? _t(String? s) => s == null ? null : TextCellValue(s);

List<CellValue?> _headerRow([List<String> headers = kSheetHeaders]) =>
    [for (final h in headers) TextCellValue(h)];

List<CellValue?> _row({
  String? firstName,
  String? surname,
  String? phone1,
  String? phone2,
  String? phone3,
  CellValue? dob,
  CellValue? anniversary,
  String? event1Name,
  CellValue? event1Date,
  String? event2Name,
  CellValue? event2Date,
  String? event3Name,
  CellValue? event3Date,
  String? email,
  String? address,
}) =>
    [
      _t(firstName),
      _t(surname),
      _t(phone1),
      _t(phone2),
      _t(phone3),
      dob,
      anniversary,
      _t(event1Name),
      event1Date,
      _t(event2Name),
      event2Date,
      _t(event3Name),
      event3Date,
      _t(email),
      _t(address),
    ];

/// Two sheets, each with a few fully-valid rows: mixed year/no-year dates,
/// 1-3 phones, with and without events.
Excel _validMultiSheet() {
  final excel = _workbook(['Friends', 'Relatives']);
  excel.appendRow('Friends', _headerRow());
  excel.appendRow(
      'Friends',
      _row(
        firstName: 'John',
        surname: 'Doe',
        phone1: '9876543210',
        dob: DateCellValue(year: 1990, month: 8, day: 15),
        event1Name: 'Graduation',
        event1Date: TextCellValue('10-Jun-2015'),
        email: 'john@example.com',
        address: '123 Main St',
      ));
  excel.appendRow(
      'Friends',
      _row(
        firstName: 'Priya',
        surname: 'Shah',
        phone1: '+91 98765 12345',
        phone2: '9998887776',
        dob: TextCellValue('05-Mar'), // no year
        anniversary: DateCellValue(year: 2010, month: 11, day: 20),
      ));

  excel.appendRow('Relatives', _headerRow());
  excel.appendRow(
      'Relatives',
      _row(
        firstName: 'Amit',
        surname: 'Patel',
        phone1: '9123456780',
        dob: TextCellValue('01/12'), // dd/MM, no year
        anniversary: TextCellValue('14-02-2005'), // dd-MM-yyyy
        event1Name: 'Housewarming',
        event1Date: TextCellValue('2021-07-04'), // ISO
        event2Name: 'Retirement',
        event2Date: DateCellValue(year: 2023, month: 1, day: 1),
      ));
  excel.appendRow(
      'Relatives',
      _row(
        firstName: 'Sunita',
        phone1: '9988776655',
        phone3: '9112233445',
        email: 'sunita@example.com',
      ));
  return excel;
}

/// Rows missing a required field, alongside one valid control row.
Excel _missingRequired() {
  final excel = _workbook(['Bad']);
  excel.appendRow('Bad', _headerRow());
  excel.appendRow('Bad', _row(phone1: '9876500000')); // no first name
  excel.appendRow('Bad', _row(firstName: 'Ravi')); // no phone 1
  excel.appendRow(
      'Bad', _row(firstName: 'Neha', phone1: '9812345678')); // valid
  return excel;
}

/// Rows with unparsable date text.
Excel _badDates() {
  final excel = _workbook(['Dates']);
  excel.appendRow('Dates', _headerRow());
  excel.appendRow(
      'Dates',
      _row(
          firstName: 'Foo',
          phone1: '9876500001',
          dob: TextCellValue('not-a-date')));
  excel.appendRow(
      'Dates',
      _row(
          firstName: 'Bar',
          phone1: '9876500002',
          anniversary: TextCellValue('32-13-2020'))); // invalid day/month
  excel.appendRow(
      'Dates',
      _row(
          firstName: 'Baz',
          phone1: '9876500003',
          event1Name: 'Weird',
          event1Date: TextCellValue('yesterday')));
  return excel;
}

/// Dates as text, one row per accepted format.
Excel _datesAsText() {
  final excel = _workbook(['TextDates']);
  excel.appendRow('TextDates', _headerRow());
  excel.appendRow('TextDates',
      _row(firstName: 'A', phone1: '1', dob: TextCellValue('15-Aug')));
  excel.appendRow('TextDates',
      _row(firstName: 'B', phone1: '2', dob: TextCellValue('05/03')));
  excel.appendRow('TextDates',
      _row(firstName: 'C', phone1: '3', dob: TextCellValue('20-11-2010')));
  excel.appendRow('TextDates',
      _row(firstName: 'D', phone1: '4', dob: TextCellValue('2010-11-20')));
  return excel;
}

/// Dates as native Excel date cells, covering dob/anniversary/events.
Excel _datesAsDateCells() {
  final excel = _workbook(['DateCells']);
  excel.appendRow('DateCells', _headerRow());
  excel.appendRow(
      'DateCells',
      _row(
        firstName: 'Kiran',
        phone1: '9876500010',
        dob: DateCellValue(year: 1988, month: 4, day: 2),
        anniversary: DateCellValue(year: 2012, month: 9, day: 30),
        event1Name: 'Milestone',
        event1Date: DateCellValue(year: 2020, month: 1, day: 1),
      ));
  return excel;
}

/// Known columns plus unrecognised extra columns, which must be ignored.
Excel _extraColumns() {
  final excel = _workbook(['Extra']);
  final headers = [...kSheetHeaders, 'Notes', 'Nickname'];
  excel.appendRow('Extra', _headerRow(headers));
  excel.appendRow('Extra', [
    ..._row(firstName: 'Zara', phone1: '9876500020'),
    _t('some note'),
    _t('Zee'),
  ]);
  return excel;
}

/// Same headers, different case/whitespace; matching is case-insensitive
/// and trimmed.
Excel _mixedCaseHeaders() {
  final excel = _workbook(['MixedCase']);
  excel.appendRow('MixedCase', [
    _t(' first name* '),
    _t('SURNAME'),
    _t('phone 1*'),
    _t('Phone 2'),
    _t('PHONE 3'),
    _t('date of birth'),
    _t('MARRIAGE ANNIVERSARY'),
    _t('event 1 name'),
    _t('EVENT 1 DATE'),
    _t('Event 2 Name'),
    _t('event 2 date'),
    _t('EVENT 3 NAME'),
    _t('Event 3 Date'),
    _t('EMAIL'),
    _t('Address'),
  ]);
  excel.appendRow(
      'MixedCase', _row(firstName: 'Om', phone1: '9876500030'));
  return excel;
}

/// A group with only a header row and no contacts.
Excel _emptySheet() {
  final excel = _workbook(['Empty']);
  excel.appendRow('Empty', _headerRow());
  return excel;
}
