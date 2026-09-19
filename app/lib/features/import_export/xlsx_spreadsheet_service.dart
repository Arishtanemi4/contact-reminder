import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import 'date_parser.dart';
import 'spreadsheet_service.dart';

/// [SpreadsheetService] implemented with the `excel` package.
class XlsxSpreadsheetService implements SpreadsheetService {
  const XlsxSpreadsheetService(
      {this._dateParser = const FlexibleDateParser()});

  final DateParser _dateParser;

  @override
  ImportResult parse(Uint8List bytes) {
    final xl.Excel excel;
    try {
      excel = xl.Excel.decodeBytes(bytes);
    } catch (e) {
      return ImportResult(sheets: [
        ParsedSheet(name: '', rows: [
          ParsedRow(rowNumber: 0, issues: [
            RowIssue(
                rowNumber: 0,
                field: 'file',
                reason: 'could not read spreadsheet: $e'),
          ]),
        ]),
      ]);
    }
    return ImportResult(sheets: [
      for (final entry in excel.sheets.entries) _parseSheet(entry.key, entry.value),
    ]);
  }

  ParsedSheet _parseSheet(String name, xl.Sheet sheet) {
    final rows = sheet.rows;
    if (rows.isEmpty) return ParsedSheet(name: name, rows: []);

    final headerMap = <String, int>{};
    final header = rows.first;
    for (var i = 0; i < header.length; i++) {
      final text = _asText(header[i]?.value);
      if (text != null) headerMap.putIfAbsent(_normalizeHeader(text), () => i);
    }
    int? colFor(String h) => headerMap[_normalizeHeader(h)];

    final firstNameCol = colFor(kFirstNameHeader);
    final surnameCol = colFor(kSurnameHeader);
    final phone1Col = colFor(kPhone1Header);
    final phone2Col = colFor(kPhone2Header);
    final phone3Col = colFor(kPhone3Header);
    final dobCol = colFor(kDobHeader);
    final anniversaryCol = colFor(kAnniversaryHeader);
    final emailCol = colFor(kEmailHeader);
    final addressCol = colFor(kAddressHeader);

    final parsedRows = <ParsedRow>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      xl.CellValue? cell(int? col) =>
          (col != null && col < row.length) ? row[col]?.value : null;

      final rowNumber = r; // 1-based; header row excluded.
      final issues = <RowIssue>[];

      final firstName = _asText(cell(firstNameCol));
      final surname = _asText(cell(surnameCol));
      final phones = [
        ?_asText(cell(phone1Col)),
        ?_asText(cell(phone2Col)),
        ?_asText(cell(phone3Col)),
      ];
      final email = _asText(cell(emailCol));
      final address = _asText(cell(addressCol));

      final dob = _parseDateField(rowNumber, kDobHeader, cell(dobCol), issues);
      final anniversary =
          _parseDateField(rowNumber, kAnniversaryHeader, cell(anniversaryCol), issues);

      final otherEvents = <ParsedEvent>[];
      for (var i = 1; i <= 3; i++) {
        final nameHeader = 'Event $i Name';
        final dateHeader = 'Event $i Date';
        final eventName = _asText(cell(colFor(nameHeader)));
        final dateCellValue = cell(colFor(dateHeader));
        final date = _parseDateField(rowNumber, dateHeader, dateCellValue, issues);
        if (date != null) {
          otherEvents.add(ParsedEvent(name: eventName ?? nameHeader, date: date));
        } else if (eventName != null && dateCellValue == null) {
          issues.add(RowIssue(
              rowNumber: rowNumber,
              field: dateHeader,
              reason: 'event name given without a date'));
        }
      }

      if (firstName == null) {
        issues.add(RowIssue(
            rowNumber: rowNumber,
            field: kFirstNameHeader,
            reason: 'first name is required'));
      }
      if (phones.isEmpty) {
        issues.add(RowIssue(
            rowNumber: rowNumber,
            field: kPhone1Header,
            reason: 'at least one phone number is required'));
      }

      parsedRows.add(ParsedRow(
        rowNumber: rowNumber,
        firstName: firstName,
        surname: surname,
        phones: phones,
        dob: dob,
        anniversary: anniversary,
        otherEvents: otherEvents,
        email: email,
        address: address,
        issues: issues,
      ));
    }
    return ParsedSheet(name: name, rows: parsedRows);
  }

  ParsedDate? _parseDateField(
      int rowNumber, String field, xl.CellValue? cv, List<RowIssue> issues) {
    final input = _dateInput(cv);
    if (input == null) return null;
    final result = _dateParser.parse(input);
    if (!result.isOk) {
      issues.add(RowIssue(rowNumber: rowNumber, field: field, reason: result.reason!));
      return null;
    }
    return result.date;
  }

  /// Reduces a cell to whatever [DateParser.parse] accepts, or null if the
  /// cell is blank/unusable as a date.
  Object? _dateInput(xl.CellValue? cv) {
    if (cv is xl.DateCellValue) return cv.asDateTimeLocal();
    if (cv is xl.DateTimeCellValue) return cv.asDateTimeLocal();
    if (cv is xl.TextCellValue) {
      final t = cv.value.toString().trim();
      return t.isEmpty ? null : t;
    }
    if (cv is xl.IntCellValue) return cv.value;
    if (cv is xl.DoubleCellValue) return cv.value;
    return null;
  }

  /// Reduces a cell to trimmed display text, or null if blank/unusable.
  String? _asText(xl.CellValue? cv) {
    final String? s;
    if (cv is xl.TextCellValue) {
      s = cv.value.toString();
    } else if (cv is xl.IntCellValue) {
      s = cv.value.toString();
    } else if (cv is xl.DoubleCellValue) {
      s = cv.value.toString();
    } else if (cv is xl.BoolCellValue) {
      s = cv.value.toString();
    } else {
      s = null;
    }
    final trimmed = s?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Header comparison is case-insensitive and ignores surrounding
  /// whitespace and a trailing "required" marker (`*`).
  String _normalizeHeader(String h) {
    var t = h.trim();
    if (t.endsWith('*')) t = t.substring(0, t.length - 1).trim();
    return t.toLowerCase();
  }

  @override
  Uint8List build(List<ParsedSheet> sheets) {
    // Implemented in step 4.6.
    throw UnimplementedError();
  }

  @override
  Uint8List template() {
    // Implemented in step 4.6.
    throw UnimplementedError();
  }
}
