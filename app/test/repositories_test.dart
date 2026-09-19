import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GroupRepository groups;
  late ContactRepository contacts;
  late SettingsRepository settings;
  late int friendsId;

  ContactInput input({
    int? groupId,
    String first = 'Asha',
    List<String> phones = const ['+91 98765 43210'],
    List<EventInput> events = const [],
    String? surname,
  }) =>
      ContactInput(
        groupId: groupId ?? friendsId,
        firstName: first,
        surname: surname,
        phones: phones,
        events: events,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    groups = GroupRepository(db);
    contacts = ContactRepository(db);
    settings = SettingsRepository(db);
    friendsId = (await groups.create('Friends')).id;
  });

  tearDown(() => db.close());

  group('contacts CRUD', () {
    test('create stores phones and events in order', () async {
      final id = await contacts.create(input(
        phones: ['111', ' ', '222'],
        events: const [
          EventInput(type: EventType.birthday, month: 2, day: 29),
          EventInput(
              type: EventType.anniversary, month: 6, day: 1, year: 2010),
        ],
      ));
      final c = (await contacts.get(id))!;
      expect(c.contact.firstName, 'Asha');
      expect(c.phones.map((p) => (p.position, p.numberRaw)),
          [(1, '111'), (2, '222')]);
      expect(c.events.length, 2);
      expect(c.events.firstWhere((e) => e.type == EventType.birthday).year,
          isNull);
    });

    test('create populates numberE164 using the default region', () async {
      final id = await contacts
          .create(input(phones: ['098765 43210', 'not a number']));
      final c = (await contacts.get(id))!;
      expect(c.phones[0].numberE164, '+919876543210');
      expect(c.phones[1].numberE164, isNull);
    });

    test('update replaces phones and events', () async {
      final id = await contacts.create(input(
        events: const [EventInput(type: EventType.birthday, month: 1, day: 2)],
      ));
      await contacts.update(id, input(first: 'Asha2', phones: ['999']));
      final c = (await contacts.get(id))!;
      expect(c.contact.firstName, 'Asha2');
      expect(c.phones.single.numberRaw, '999');
      expect(c.events, isEmpty);
    });

    test('delete removes contact', () async {
      final id = await contacts.create(input());
      await contacts.delete(id);
      expect(await contacts.get(id), isNull);
    });

    test('update of missing validation keeps old data (transaction)', () async {
      final id = await contacts.create(input());
      expect(() => contacts.update(id, input(phones: [])),
          throwsA(isA<ValidationException>()));
      expect((await contacts.get(id))!.phones.length, 1);
    });
  });

  group('cascade delete', () {
    test('deleting a contact removes phones and events', () async {
      final id = await contacts.create(input(
        events: const [EventInput(type: EventType.birthday, month: 1, day: 2)],
      ));
      await contacts.delete(id);
      expect(await db.select(db.contactPhones).get(), isEmpty);
      expect(await db.select(db.contactEvents).get(), isEmpty);
    });

    test('deleting a group removes its contacts', () async {
      await contacts.create(input());
      await groups.delete(friendsId);
      expect(await db.select(db.contacts).get(), isEmpty);
      expect(await db.select(db.contactPhones).get(), isEmpty);
    });
  });

  group('validation', () {
    test('first name required', () {
      expect(() => contacts.create(input(first: '  ')),
          throwsA(isA<ValidationException>()));
    });

    test('at least one phone', () {
      expect(() => contacts.create(input(phones: ['', '  '])),
          throwsA(isA<ValidationException>()));
    });

    test('at most three phones', () {
      expect(() => contacts.create(input(phones: ['1', '2', '3', '4'])),
          throwsA(isA<ValidationException>()));
    });

    test('nothing is written when validation fails', () async {
      try {
        await contacts.create(input(first: ''));
      } on ValidationException {
        // expected
      }
      expect(await db.select(db.contacts).get(), isEmpty);
    });

    test('db rejects out-of-range month', () {
      expect(
          () => contacts.create(input(events: const [
                EventInput(type: EventType.other, month: 13, day: 1),
              ])),
          throwsA(anything));
    });
  });

  group('watch and search', () {
    test('watchByGroup is scoped to group and sorted by name', () async {
      final office = (await groups.create('Office')).id;
      await contacts.create(input(first: 'Zed'));
      await contacts.create(input(first: 'Amit'));
      await contacts.create(input(first: 'Other', groupId: office));
      final list = await contacts.watchByGroup(friendsId).first;
      expect(list.map((d) => d.contact.firstName), ['Amit', 'Zed']);
    });

    test('watchByGroup emits again after an update', () async {
      final id = await contacts.create(input(first: 'Amit'));
      final emissions = contacts
          .watchByGroup(friendsId)
          .map((l) => l.map((d) => d.contact.firstName).toList());
      final expectation = expectLater(
          emissions,
          emitsInOrder([
            ['Amit'],
            ['Bina'],
          ]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await contacts.update(id, input(first: 'Bina'));
      await expectation;
    });

    test('search by name, surname, email-less, and phone digits', () async {
      await contacts.create(input(first: 'Asha', surname: 'Patil'));
      await contacts.create(
          input(first: 'Ravi', phones: ['+44 7700 900123']));
      expect((await contacts.search('pat')).single.contact.firstName, 'Asha');
      expect((await contacts.search('ASHA')).length, 1);
      expect((await contacts.search('7700900')).single.contact.firstName,
          'Ravi');
      expect(await contacts.search('nobody'), isEmpty);
      expect((await contacts.search('')).length, 2);
    });

    test('watchByGroup query filters', () async {
      await contacts.create(input(first: 'Asha'));
      await contacts.create(input(first: 'Ravi'));
      final list = await contacts.watchByGroup(friendsId, query: 'rav').first;
      expect(list.single.contact.firstName, 'Ravi');
    });

    test('watchOne emits the contact, then null after delete', () async {
      final id = await contacts.create(input());
      final emissions =
          contacts.watchOne(id).map((d) => d?.contact.firstName);
      final expectation = expectLater(
          emissions,
          emitsInOrder([
            'Asha',
            null,
          ]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await contacts.delete(id);
      await expectation;
    });

    test('watchOne on an unknown id is null', () async {
      expect(await contacts.watchOne(999).first, isNull);
    });
  });

  group('groups', () {
    test('new groups append and reorder rewrites sort order', () async {
      final b = await groups.create('Relatives');
      final c = await groups.create('Office');
      expect((await groups.watchAll().first).map((g) => g.name),
          ['Friends', 'Relatives', 'Office']);
      await groups.reorder([c.id, friendsId, b.id]);
      expect((await groups.watchAll().first).map((g) => g.name),
          ['Office', 'Friends', 'Relatives']);
    });

    test('duplicate name rejected', () {
      expect(() => groups.create('Friends'), throwsA(anything));
    });

    test('rename', () async {
      await groups.rename(friendsId, 'Pals');
      expect((await groups.watchAll().first).single.name, 'Pals');
    });
  });

  group('settings', () {
    test('defaults are seeded', () async {
      final s = await settings.get();
      expect((s.notifyTime, s.defaultCountryCode, s.leadDays),
          ('08:00', 'IN', 0));
    });

    test('partial update', () async {
      await settings.update(notifyTime: '07:30', leadDays: 1);
      final s = await settings.get();
      expect((s.notifyTime, s.defaultCountryCode, s.leadDays),
          ('07:30', 'IN', 1));
    });
  });
}
