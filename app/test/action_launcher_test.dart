import 'package:contact_reminder/core/action_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActionUris.call', () {
    test('builds a tel: uri', () {
      expect(ActionUris.call('+919876543210').toString(), 'tel:+919876543210');
    });
  });

  group('ActionUris.sms', () {
    test('builds a sms: uri with no body', () {
      expect(ActionUris.sms('+919876543210').toString(), 'sms:+919876543210');
    });

    test('omits the body when it is empty', () {
      expect(
          ActionUris.sms('+919876543210', body: '').toString(),
          'sms:+919876543210');
    });

    test('encodes a body with spaces as %20, not +', () {
      final uri = ActionUris.sms('+919876543210', body: 'Happy Birthday');
      expect(uri.toString(), 'sms:+919876543210?body=Happy%20Birthday');
    });

    test('encodes special characters in the body', () {
      final uri = ActionUris.sms('+919876543210', body: 'Hi! & congrats?');
      expect(uri.query, 'body=Hi!%20%26%20congrats%3F');
    });
  });

  group('ActionUris.whatsApp', () {
    test('strips the leading + and builds a wa.me link with no text', () {
      final uri = ActionUris.whatsApp('+919876543210');
      expect(uri.toString(), 'https://wa.me/919876543210');
    });

    test('omits the text parameter when it is empty', () {
      final uri = ActionUris.whatsApp('+919876543210', text: '');
      expect(uri.toString(), 'https://wa.me/919876543210');
    });

    test('encodes text with spaces (as %20, not +) and special characters', () {
      final uri =
          ActionUris.whatsApp('+919876543210', text: 'Happy Birthday!');
      expect(uri.toString(),
          'https://wa.me/919876543210?text=Happy%20Birthday!');
    });
  });
}
