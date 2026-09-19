import 'package:flutter/services.dart';

/// Wraps the small platform channel in `MainActivity` (Phase 5.6) that checks
/// and opens battery-optimisation settings, since aggressive OEMs (Xiaomi,
/// Oppo, etc.) can delay or drop scheduled reminders in the background.
class BatteryOptimizationService {
  const BatteryOptimizationService();

  static const _channel = MethodChannel('com.example.contactreminder/battery');

  /// True if the app is already exempt from battery optimisation.
  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
      false;

  /// Opens the system dialog/settings page to exempt this app.
  Future<void> openSettings() => _channel.invokeMethod('openBatterySettings');
}
