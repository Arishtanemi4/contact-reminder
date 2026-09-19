import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/features/contacts/contacts_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drift's stream disposal (on ProviderScope unmount) schedules a
/// zero-duration Timer; without an explicit unmount + pump inside the test,
/// it fires during flutter_test's own teardown and trips its
/// no-pending-timers invariant. Unmounting here, ourselves, first avoids that.
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // A bare pump() doesn't advance the fake test clock, so the disposal
  // timer above never actually fires; Duration.zero does.
  await tester.pump(Duration.zero);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final groups = GroupRepository(db);
    final contacts = ContactRepository(db);
    final friendsId = (await groups.create('Friends')).id;
    final officeId = (await groups.create('Office')).id;
    await contacts.create(ContactInput(
      groupId: friendsId,
      firstName: 'Asha',
      phones: const ['111'],
    ));
    await contacts.create(ContactInput(
      groupId: friendsId,
      firstName: 'Rahul',
      phones: const ['222'],
    ));
    await contacts.create(ContactInput(
      groupId: officeId,
      firstName: 'Priya',
      phones: const ['333'],
    ));
  });

  tearDown(() => db.close());

  Widget app() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ContactsScreen()),
      );

  testWidgets('shows a tab per group and that group\'s contacts',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);

    await tester.tap(find.text('Office'));
    await tester.pumpAndSettle();
    expect(find.text('Priya'), findsOneWidget);

    await _unmountAndSettle(tester);
  });

  testWidgets('search filters the contact list', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rahul');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Rahul'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);

    await _unmountAndSettle(tester);
  });

  group('empty database', () {
    late AppDatabase emptyDb;

    setUp(() => emptyDb = AppDatabase(NativeDatabase.memory()));
    tearDown(() => emptyDb.close());

    testWidgets('shows the empty state', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(emptyDb)],
        child: const MaterialApp(home: ContactsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Import a file or add a contact.'), findsOneWidget);

      await _unmountAndSettle(tester);
    });
  });
}
