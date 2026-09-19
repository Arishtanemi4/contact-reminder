import 'package:contact_reminder/core/phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const normalizer = DefaultPhoneNormalizer();

  // (description, raw, defaultRegion, expected E.164 or null if rejected)
  const cases = [
    ('plain national number', '98765 43210', 'IN', '+919876543210'),
    ('leading zero (trunk prefix)', '09876543210', 'IN', '+919876543210'),
    ('spaces and dashes', '+91 98765-43210', 'IN', '+919876543210'),
    ('dashes only, no plus', '98765-43210', 'IN', '+919876543210'),
    ('already E.164', '+919876543210', 'IN', '+919876543210'),
    ('plus with spaces', '+91 98765 43210', 'IN', '+919876543210'),
    ('US number with parens/dashes', '(202) 555-0143', 'US', '+12025550143'),
    ('US number with country code', '+1 202-555-0143', 'US', '+12025550143'),
    ('UK number with leading zero', '02079460958', 'GB', '+442079460958'),
    ('UK number with country code', '+44 20 7946 0958', 'GB', '+442079460958'),
    ('+ overrides default region', '+442079460958', 'IN', '+442079460958'),
    ('blank string', '', 'IN', null),
    ('whitespace only', '   ', 'IN', null),
    ('garbage text', 'garbage', 'IN', null),
    ('too short to be valid', '12345', 'IN', null),
    ('too long to be valid', '9876543210123456', 'IN', null),
  ];

  group('DefaultPhoneNormalizer.normalize', () {
    for (final (description, raw, region, expected) in cases) {
      test(description, () {
        expect(normalizer.normalize(raw, region), expected);
      });
    }
  });
}
