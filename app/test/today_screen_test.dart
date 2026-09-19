import 'package:contact_reminder/core/action_launcher.dart';
import 'package:contact_reminder/core/clock.dart';
import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/features/events/today_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See contacts_screen_test.dart for why disposal needs an explicit unmount.
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

class _FakeActionLauncher extends ActionLauncher {
  final calls = <String>[];

  @override
  Future<bool> call(String e164Number) async {
    calls.add('call:$e164Number');
    return true;
  }

  @override
  Future<bool> sms(String e164Number, {String? body}) async {
    calls.add('sms:$e164Number:$body');
    return true;
  }

  @override
  Future<bool> whatsApp(String e164Number, {String? text}) async {
    calls.add('whatsApp:$e164Number:$text');
    return true;
  }
}

void main() {
  late AppDatabase db;

  // "Today" is fixed at 10-May-2026, so:
  // - Asha's birthday (10-May) is today.
  // - Rahul's anniversary (11-May) is tomorrow.
  // - Priya's birthday (1-Jan) is neither.
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(db);
    final contacts = ContactRepository(db);
    final friendsId = (await groups.create('Friends')).id;
    await contacts.create(
      ContactInput(
        groupId: friendsId,
        firstName: 'Asha',
        phones: const ['+919876543210'],
        events: const [
          EventInput(type: EventType.birthday, month: 5, day: 10, year: 1990),
        ],
      ),
    );
    await contacts.create(
      ContactInput(
        groupId: friendsId,
        firstName: 'Rahul',
        phones: const ['+919876543211'],
        events: const [
          EventInput(type: EventType.anniversary, month: 5, day: 11),
        ],
      ),
    );
    await contacts.create(
      ContactInput(
        groupId: friendsId,
        firstName: 'Priya',
        phones: const ['+919876543212'],
        events: const [
          EventInput(type: EventType.birthday, month: 1, day: 1),
        ],
      ),
    );
  });

  tearDown(() => db.close());

  Widget app({ActionLauncher? launcher}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(_FixedClock(DateTime(2026, 5, 10))),
      if (launcher != null) actionLauncherProvider.overrideWithValue(launcher),
    ],
    child: const MaterialApp(home: TodayScreen()),
  );

  testWidgets('groups events into Today and Tomorrow', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Turns 36'), findsOneWidget);

    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);

    expect(find.text('Priya'), findsNothing);

    await _unmountAndSettle(tester);
  });

  testWidgets('Send wishes sends a prefilled WhatsApp message', (
    tester,
  ) async {
    final launcher = _FakeActionLauncher();
    await tester.pumpWidget(app(launcher: launcher));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.card_giftcard).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(launcher.calls.single, 'whatsApp:+919876543210:Happy Birthday, Asha!');

    await _unmountAndSettle(tester);
  });

  testWidgets('empty state when nothing is due', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(
            _FixedClock(DateTime(2026, 7, 1)),
          ),
        ],
        child: const MaterialApp(home: TodayScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No birthdays or anniversaries today or tomorrow.'),
      findsOneWidget,
    );

    await _unmountAndSettle(tester);
  });
}
