import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Turns a raw, user-typed phone number into E.164 form (e.g. `+919876543210`).
///
/// Wrapped behind an interface so a Rust implementation (Phase 6) can replace
/// it later without touching callers.
abstract interface class PhoneNormalizer {
  /// Returns the E.164 form of [raw], or null if it can't be parsed as a
  /// valid number. [defaultRegion] is the ISO-3166 alpha-2 code (e.g. `IN`)
  /// used to resolve numbers without a leading `+`.
  String? normalize(String raw, String defaultRegion);
}

class DefaultPhoneNormalizer implements PhoneNormalizer {
  const DefaultPhoneNormalizer();

  @override
  String? normalize(String raw, String defaultRegion) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final region = IsoCode.values.byName(defaultRegion);
      final phone = PhoneNumber.parse(trimmed, callerCountry: region);
      return phone.isValid() ? phone.international : null;
    } catch (_) {
      return null;
    }
  }
}
