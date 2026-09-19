import 'package:contact_reminder/core/action_launcher.dart';
import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/features/contacts/contact_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See contacts_screen_test.dart for why this is needed: without it, a
/// pending drift stream-disposal Timer trips flutter_test's teardown
/// invariant. A bare pump() doesn't advance the fake test clock, so the
/// duration must be explicit.
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

/// Records calls instead of hitting the real platform (there's no url_launcher
/// implementation under `flutter test`, and we don't want tests to attempt a
/// real call/SMS/WhatsApp launch).
class _FakeActionLauncher extends ActionLauncher {
  final calls = <String>[];
  bool result = true;

  @override
  Future<bool> call(String e164Number) async {
    calls.add('call:$e164Number');
    return result;
  }

  @override
  Future<bool> sms(String e164Number, {String? body}) async {
    calls.add('sms:$e164Number');
    return result;
  }

  @override
  Future<bool> whatsApp(String e164Number, {String? text}) async {
    calls.add('whatsApp:$e164Number');
    return result;
  }
}

void main() {
  late AppDatabase db;
  late _FakeActionLauncher launcher;

  Widget app(int contactId) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      actionLauncherProvider.overrideWithValue(launcher),
    ],
    child: MaterialApp(home: ContactDetailScreen(contactId: contactId)),
  );

  setUp(() => launcher = _FakeActionLauncher());

  tearDown(() => db.close());

  testWidgets('shows phones, an event with a known year, email and address', (
    tester,
  ) async {
    db = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(db);
    final contacts = ContactRepository(db);
    final friendsId = (await groups.create('Friends')).id;
    final id = await contacts.create(
      ContactInput(
        groupId: friendsId,
        firstName: 'Asha',
        surname: 'Kulkarni',
        email: 'asha@example.com',
        address: '221B Baker Street',
        phones: const ['+91 98765 43210'],
        events: [
          EventInput(
            type: EventType.birthday,
            month: 5,
            day: 12,
            year: DateTime.now().year - 30,
          ),
        ],
      ),
    );

    await tester.pumpWidget(app(id));
    await tester.pumpAndSettle();

    expect(find.text('Asha Kulkarni'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('12 May · Age 30'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('221B Baker Street'), findsOneWidget);

    await tester.tap(find.byTooltip('Call'));
    await tester.pump();
    expect(launcher.calls, ['call:+919876543210']);
    expect(find.text('Call: no app available for this number'), findsNothing);

    launcher.result = false;
    await tester.tap(find.byTooltip('SMS'));
    await tester.pump();
    expect(launcher.calls, ['call:+919876543210', 'sms:+919876543210']);
    expect(find.text('SMS: no app available for this number'), findsOneWidget);

    await _unmountAndSettle(tester);
  });

  testWidgets(
    'hides years when the event year is unknown, and omits email/address',
    (tester) async {
      db = AppDatabase(NativeDatabase.memory());
      final groups = GroupRepository(db);
      final contacts = ContactRepository(db);
      final friendsId = (await groups.create('Friends')).id;
      final id = await contacts.create(
        ContactInput(
          groupId: friendsId,
          firstName: 'Rahul',
          phones: const ['111'],
          events: const [
            EventInput(type: EventType.anniversary, month: 3, day: 4),
          ],
        ),
      );

      await tester.pumpWidget(app(id));
      await tester.pumpAndSettle();

      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('4 Mar'), findsOneWidget);
      expect(find.textContaining('years'), findsNothing);
      expect(find.byIcon(Icons.email), findsNothing);
      expect(find.byIcon(Icons.location_on), findsNothing);

      await _unmountAndSettle(tester);
    },
  );
}
