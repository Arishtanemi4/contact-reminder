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

void main() {
  late AppDatabase db;

  Widget app(int contactId) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: ContactDetailScreen(contactId: contactId)),
      );

  tearDown(() => db.close());

  testWidgets('shows phones, an event with a known year, email and address',
      (tester) async {
    db = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(db);
    final contacts = ContactRepository(db);
    final friendsId = (await groups.create('Friends')).id;
    final id = await contacts.create(ContactInput(
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
            year: DateTime.now().year - 30),
      ],
    ));

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
    expect(find.text('Call: coming soon'), findsOneWidget);

    await _unmountAndSettle(tester);
  });

  testWidgets(
      'hides years when the event year is unknown, and omits email/address',
      (tester) async {
    db = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(db);
    final contacts = ContactRepository(db);
    final friendsId = (await groups.create('Friends')).id;
    final id = await contacts.create(ContactInput(
      groupId: friendsId,
      firstName: 'Rahul',
      phones: const ['111'],
      events: const [
        EventInput(type: EventType.anniversary, month: 3, day: 4),
      ],
    ));

    await tester.pumpWidget(app(id));
    await tester.pumpAndSettle();

    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('4 Mar'), findsOneWidget);
    expect(find.textContaining('years'), findsNothing);
    expect(find.byIcon(Icons.email), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);

    await _unmountAndSettle(tester);
  });
}
