import 'package:contact_reminder/features/import_export/date_parser.dart';
import 'package:contact_reminder/features/import_export/spreadsheet_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FlexibleDateParser();

  // (description, input, expected ParsedDate or null if it should be rejected)
  final cases = <(String, Object, ParsedDate?)>[
    // dd-MMM, no year
    ('dd-MMM no year', '15-Aug', const ParsedDate(month: 8, day: 15)),
    ('dd-MMM lowercase', '5-mar', const ParsedDate(month: 3, day: 5)),
    ('dd-MMM with year', '10-Jun-2015', const ParsedDate(month: 6, day: 10, year: 2015)),
    ('dd-MMM full month name', '1-January-2020', const ParsedDate(month: 1, day: 1, year: 2020)),

    // dd/MM, with and without year
    ('dd/MM no year', '05/03', const ParsedDate(month: 3, day: 5)),
    ('dd/MM with year', '01/12/1999', const ParsedDate(month: 12, day: 1, year: 1999)),
    ('dd/MM single digits', '1/2', const ParsedDate(month: 2, day: 1)),

    // dd-MM-yyyy
    ('dd-MM-yyyy', '20-11-2010', const ParsedDate(month: 11, day: 20, year: 2010)),
    ('dd-MM-yyyy single digit day/month', '1-2-2010', const ParsedDate(month: 2, day: 1, year: 2010)),

    // ISO
    ('ISO yyyy-MM-dd', '2010-11-20', const ParsedDate(month: 11, day: 20, year: 2010)),
    ('ISO single digit month/day', '2010-1-5', const ParsedDate(month: 1, day: 5, year: 2010)),

    // Feb 29
    ('Feb 29, no year, allowed', '29-Feb', const ParsedDate(month: 2, day: 29)),
    ('Feb 29, leap year, allowed', '29-Feb-2000', const ParsedDate(month: 2, day: 29, year: 2000)),
    ('Feb 29, non-leap year, rejected', '29-Feb-1990', null),
    ('Feb 29, century non-leap year, rejected', '29-Feb-1900', null),
    ('Feb 29, 400-year leap, allowed', '29-2-2000', const ParsedDate(month: 2, day: 29, year: 2000)),

    // Out-of-range day/month
    ('day 0 rejected', '0-Jan', null),
    ('day 30 in Feb rejected', '30-Feb', null),
    ('day 31 in Apr rejected', '31/04', null),
    ('month 13 rejected', '32-13-2020', null),
    ('day 32 rejected', '32-01-2020', null),

    // Garbage
    ('plain garbage', 'not-a-date', null),
    ('word', 'yesterday', null),
    ('empty string', '', null),
    ('whitespace only', '   ', null),
    ('unknown month name', '15-Xyz-2020', null),

    // DateTime input (native Excel date cell, already resolved)
    ('DateTime input', DateTime(1990, 8, 15), const ParsedDate(month: 8, day: 15, year: 1990)),

    // Numeric Excel serial (days since 1899-12-30)
    ('Excel serial for 2015-06-10', 42165, const ParsedDate(month: 6, day: 10, year: 2015)),
    ('Excel serial as double', 42165.0, const ParsedDate(month: 6, day: 10, year: 2015)),

    // Unsupported type
    ('unsupported type', true, null),
  ];

  group('FlexibleDateParser.parse', () {
    for (final (description, input, expected) in cases) {
      test(description, () {
        final result = parser.parse(input);
        if (expected == null) {
          expect(result.isOk, isFalse, reason: 'expected rejection, got ${result.date}');
          expect(result.reason, isNotNull);
        } else {
          expect(result.isOk, isTrue, reason: 'expected $expected, got error: ${result.reason}');
          expect(result.date, expected);
        }
      });
    }
  });
}
