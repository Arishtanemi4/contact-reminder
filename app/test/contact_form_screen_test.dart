import 'package:contact_reminder/core/providers.dart';
import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/features/contacts/contact_form_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See contacts_screen_test.dart: flushes drift's stream-disposal Timer
/// before flutter_test's own teardown checks for pending timers. A bare
/// pump() doesn't advance the fake test clock, so Duration.zero is needed.
Future<void> _unmountAndSettle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late ContactRepository contacts;
  late int friendsId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    groups = GroupRepository(db);
    contacts = ContactRepository(db);
    friendsId = (await groups.create('Friends')).id;
  });

  tearDown(() => db.close());

  // Pushed on top of a placeholder screen so a successful save/delete
  // (which pops) is observable as the placeholder reappearing.
  Widget wrap(Widget child) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => child)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openForm(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(wrap(form));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The form is a scrolling ListView taller than the test viewport, so
  // widgets further down (e.g. "Add Birthday") need scrolling into view
  // before they can be tapped.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('missing first name and phone show validation errors',
      (tester) async {
    await openForm(tester, ContactFormScreen(initialGroupId: friendsId));

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('At least one phone is required'), findsOneWidget);
    expect(await contacts.search(''), isEmpty);

    await _unmountAndSettle(tester);
  });

  testWidgets('saves a new contact with a birthday of unknown year',
      (tester) async {
    await openForm(tester, ContactFormScreen(initialGroupId: friendsId));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'), 'Asha');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone 1'), '111');
    await tapVisible(tester, find.widgetWithText(TextButton, 'Add Birthday'));

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    final list = await contacts.search('');
    expect(list.single.contact.firstName, 'Asha');
    expect(list.single.events.single.year, isNull);

    await _unmountAndSettle(tester);
  });

  testWidgets('saves a birthday with a known year when the switch is on',
      (tester) async {
    await openForm(tester, ContactFormScreen(initialGroupId: friendsId));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'), 'Asha');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone 1'), '111');
    await tapVisible(tester, find.widgetWithText(TextButton, 'Add Birthday'));
    await tapVisible(tester, find.byType(Switch));

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final list = await contacts.search('');
    expect(list.single.events.single.year, DateTime.now().year);

    await _unmountAndSettle(tester);
  });

  testWidgets('editing prefills fields and updates on save', (tester) async {
    final id = await contacts.create(ContactInput(
      groupId: friendsId,
      firstName: 'Asha',
      phones: const ['111'],
    ));

    await openForm(
        tester, ContactFormScreen(contactId: id, initialGroupId: friendsId));

    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('111'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'First name'), 'Asha2');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    final updated = await contacts.get(id);
    expect(updated!.contact.firstName, 'Asha2');

    await _unmountAndSettle(tester);
  });

  testWidgets('delete asks for confirmation, then removes the contact',
      (tester) async {
    final id = await contacts.create(ContactInput(
      groupId: friendsId,
      firstName: 'Asha',
      phones: const ['111'],
    ));

    await openForm(
        tester, ContactFormScreen(contactId: id, initialGroupId: friendsId));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete contact?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(await contacts.get(id), isNull);

    await _unmountAndSettle(tester);
  });
}
