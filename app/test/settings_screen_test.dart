import 'package:contact_reminder/core/notification_service.dart';
import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avoids touching the real `flutter_local_notifications` platform channel,
/// which isn't available under `flutter test`.
class _FakeNotificationService extends NotificationService {
  bool enabled = false;
  bool exactAllowed = false;
  final calls = <String>[];

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    enabled = true;
    return true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAllowed;

  @override
  Future<void> requestExactAlarmsPermission() async {
    calls.add('requestExactAlarmsPermission');
    exactAllowed = true;
  }

  @override
  Future<void> openSystemSettings() async => calls.add('openSystemSettings');

  @override
  Future<void> showNow(int id, String title, String body) async =>
      calls.add('showNow:$title:$body');
}

void main() {
  late _FakeNotificationService service;

  setUp(() => service = _FakeNotificationService());

  Widget app() => ProviderScope(
    overrides: [notificationServiceProvider.overrideWithValue(service)],
    child: const MaterialApp(home: SettingsScreen()),
  );

  testWidgets('shows Disabled and requests permission via the rationale dialog', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Disabled'), findsOneWidget);

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();

    expect(find.text('Allow notifications?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(service.calls, ['requestPermission']);
    expect(find.text('Enabled'), findsOneWidget);
  });

  testWidgets('declining the rationale dialog does not request permission', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(service.calls, isEmpty);
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('Allow requests the exact-alarm permission', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(service.calls, ['requestExactAlarmsPermission']);
    expect(find.text('Allowed'), findsOneWidget);
  });

  testWidgets('Send test notification shows a confirmation snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();

    expect(service.calls, ['showNow:Test notification:Notifications are working.']);
    expect(find.text('Test notification sent'), findsOneWidget);
  });

  testWidgets('Open notification settings delegates to the service', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open notification settings'));
    await tester.pumpAndSettle();

    expect(service.calls, ['openSystemSettings']);
  });
}
