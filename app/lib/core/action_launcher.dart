import 'package:url_launcher/url_launcher.dart';

/// Percent-encodes query parameters for schemes other than http/https, where
/// [Uri]'s `queryParameters` turns spaces into `+` instead of `%20`
/// (https://github.com/dart-lang/sdk/issues/43838).
String _encodeQuery(Map<String, String> params) => params.entries
    .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');

/// Builds the call/SMS/WhatsApp URIs. Pure and side-effect free, so testable
/// without a device.
class ActionUris {
  const ActionUris._();

  static Uri call(String e164Number) => Uri(scheme: 'tel', path: e164Number);

  static Uri sms(String e164Number, {String? body}) => Uri(
        scheme: 'sms',
        path: e164Number,
        query: (body == null || body.isEmpty) ? null : _encodeQuery({'body': body}),
      );

  static Uri whatsApp(String e164Number, {String? text}) => Uri(
        scheme: 'https',
        host: 'wa.me',
        path: '/${e164Number.replaceFirst('+', '')}',
        query: (text == null || text.isEmpty) ? null : _encodeQuery({'text': text}),
      );
}

/// Launches call/SMS/WhatsApp intents. Returns false (instead of throwing) if
/// no app can handle the request, so callers can show a message.
class ActionLauncher {
  const ActionLauncher();

  Future<bool> call(String e164Number) => _launch(ActionUris.call(e164Number));

  Future<bool> sms(String e164Number, {String? body}) =>
      _launch(ActionUris.sms(e164Number, body: body));

  Future<bool> whatsApp(String e164Number, {String? text}) => _launch(
        ActionUris.whatsApp(e164Number, text: text),
        mode: LaunchMode.externalApplication,
      );

  Future<bool> _launch(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
