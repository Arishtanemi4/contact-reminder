import 'package:contact_reminder/core/battery_optimization_service.dart';
import 'package:contact_reminder/core/notification_service.dart';
import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/features/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See contacts_screen_test.dart for why disposal needs an explicit unmount.
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

/// Scrolls the settings list down so items below the General section (added
/// in 7.1) are on screen. `scrollUntilVisible` can't auto-detect the right
/// `Scrollable` once the country `DropdownMenu` is in the tree, so this
/// drags the list directly instead.
Future<void> _scrollSettingsDown(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('settingsList')),
    const Offset(0, -400),
  );
  await tester.pumpAndSettle();
}

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

/// Avoids touching the real platform channel in MainActivity, which isn't
/// available under `flutter test`.
class _FakeBatteryOptimizationService extends BatteryOptimizationService {
  bool ignored = false;
  final calls = <String>[];

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignored;

  @override
  Future<void> openSettings() async {
    calls.add('openSettings');
    ignored = true;
  }
}

void main() {
  late _FakeNotificationService service;
  late _FakeBatteryOptimizationService batteryService;
  late AppDatabase db;

  setUp(() {
    service = _FakeNotificationService();
    batteryService = _FakeBatteryOptimizationService();
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      notificationServiceProvider.overrideWithValue(service),
      batteryOptimizationServiceProvider.overrideWithValue(batteryService),
      databaseProvider.overrideWithValue(db),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );

  testWidgets(
    'shows Disabled and requests permission via the rationale dialog',
    (tester) async {
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
      await _unmountAndSettle(tester);
    },
  );

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
    await _unmountAndSettle(tester);
  });

  testWidgets('Allow requests the exact-alarm permission', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(service.calls, ['requestExactAlarmsPermission']);
    expect(find.text('Allowed'), findsOneWidget);
    await _unmountAndSettle(tester);
  });

  testWidgets('Send test notification shows a confirmation snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await _scrollSettingsDown(tester);
    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();

    expect(service.calls, [
      'showNow:Test notification:Notifications are working.',
    ]);
    expect(find.text('Test notification sent'), findsOneWidget);
    await _unmountAndSettle(tester);
  });

  testWidgets('Open notification settings delegates to the service', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open notification settings'));
    await tester.pumpAndSettle();

    expect(service.calls, ['openSystemSettings']);
    await _unmountAndSettle(tester);
  });

  testWidgets(
    'Open battery settings delegates to the service and refreshes status',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _scrollSettingsDown(tester);

      expect(find.text('Restricted'), findsOneWidget);

      await tester.tap(find.text('Open battery settings'));
      await tester.pumpAndSettle();

      expect(batteryService.calls, ['openSettings']);
      expect(find.text('Not restricted'), findsOneWidget);
      await _unmountAndSettle(tester);
    },
  );

  testWidgets('shows default reminder time, lead days, country and theme', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Same day'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'IN'), findsOneWidget);
    await _unmountAndSettle(tester);
  });

  testWidgets('changing lead days updates the stored setting', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 day before').last);
    await tester.pumpAndSettle();

    expect((await db.select(db.settings).getSingle()).leadDays, 1);
    await _unmountAndSettle(tester);
  });

  testWidgets('changing theme updates the stored setting', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect((await db.select(db.settings).getSingle()).themeMode, 'dark');
    await _unmountAndSettle(tester);
  });
}
