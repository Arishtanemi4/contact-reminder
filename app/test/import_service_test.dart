import 'package:contact_reminder/data/contact_repository.dart';
import 'package:contact_reminder/data/database.dart';
import 'package:contact_reminder/data/group_repository.dart';
import 'package:contact_reminder/features/import_export/import_service.dart';
import 'package:contact_reminder/features/import_export/spreadsheet_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ImportService importService;
  late ContactRepository contacts;
  late GroupRepository groups;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    importService = ImportService(db);
    contacts = ContactRepository(db);
    groups = GroupRepository(db);
  });

  tearDown(() => db.close());

  ParsedRow validRow({
    String firstName = 'Asha',
    String? surname,
    List<String> phones = const ['9876543210'],
    ParsedDate? dob,
  }) =>
      ParsedRow(
          rowNumber: 1,
          firstName: firstName,
          surname: surname,
          phones: phones,
          dob: dob);

  ImportResult oneSheet(String groupName, List<ParsedRow> rows) =>
      ImportResult(sheets: [ParsedSheet(name: groupName, rows: rows)]);

  test('merge: new rows are added, group created', () async {
    final summary = await importService.import(
      oneSheet('Friends', [
        validRow(firstName: 'Asha'),
        validRow(firstName: 'Ravi', phones: const ['1234567890']),
      ]),
      ImportMode.merge,
    );
    expect(summary.added, 2);
    expect(summary.updated, 0);
    expect(summary.skipped, 0);
    expect((await groups.watchAll().first).map((g) => g.name), ['Friends']);
  });

  test('merge: invalid rows are skipped, not imported, and reported', () async {
    const badRow = ParsedRow(rowNumber: 5, phones: [], issues: [
      RowIssue(rowNumber: 5, field: kFirstNameHeader, reason: 'first name is required'),
    ]);
    final summary =
        await importService.import(oneSheet('Friends', [badRow]), ImportMode.merge);
    expect(summary.added, 0);
    expect(summary.skipped, 1);
    expect(summary.issues, [badRow.issues.single]);
  });

  test('merge run twice is idempotent (matches group + name + phone 1)', () async {
    final result = oneSheet('Friends', [
      validRow(
          firstName: 'Asha',
          surname: 'Verma',
          phones: const ['9876543210', '1112223333']),
    ]);

    final first = await importService.import(result, ImportMode.merge);
    expect(first.added, 1);
    expect(first.updated, 0);

    final second = await importService.import(result, ImportMode.merge);
    expect(second.added, 0);
    expect(second.updated, 1);

    final groupId = (await groups.watchAll().first).single.id;
    expect(await contacts.watchByGroup(groupId).first, hasLength(1));
  });

  test('merge updates the matched contact\'s fields', () async {
    final groupId = (await groups.create('Friends')).id;
    await contacts.create(ContactInput(
        groupId: groupId, firstName: 'Asha', phones: const ['9876543210']));

    final result = oneSheet('Friends', [
      validRow(
          firstName: 'Asha',
          phones: const ['9876543210'],
          dob: const ParsedDate(month: 5, day: 1, year: 1995)),
    ]);
    final summary = await importService.import(result, ImportMode.merge);
    expect(summary.updated, 1);
    expect(summary.added, 0);

    final updated = (await contacts.watchByGroup(groupId).first).single;
    expect(updated.events, hasLength(1));
    expect(updated.events.single.month, 5);
    expect(updated.events.single.year, 1995);
  });

  test('merge treats a different phone 1 as a different contact', () async {
    await importService.import(
        oneSheet('Friends', [validRow(firstName: 'Asha', phones: const ['1111111111'])]),
        ImportMode.merge);
    final summary = await importService.import(
        oneSheet('Friends', [validRow(firstName: 'Asha', phones: const ['2222222222'])]),
        ImportMode.merge);

    expect(summary.added, 1);
    expect(summary.updated, 0);
    final groupId = (await groups.watchAll().first).single.id;
    expect(await contacts.watchByGroup(groupId).first, hasLength(2));
  });

  test('replace clears existing groups/contacts before inserting', () async {
    final oldGroupId = (await groups.create('Old')).id;
    await contacts.create(ContactInput(
        groupId: oldGroupId, firstName: 'Leftover', phones: const ['0000000000']));

    final summary = await importService.import(
        oneSheet('Friends', [validRow(firstName: 'Asha')]), ImportMode.replace);
    expect(summary.added, 1);

    final allGroups = await groups.watchAll().first;
    expect(allGroups.map((g) => g.name), ['Friends']);
  });

  test('a failure partway through rolls back the whole import', () async {
    // Four phones passes ParsedRow.isValid but fails ContactRepository's own
    // validation (max 3), so it fails only once actually applying to the DB.
    final tooManyPhones =
        validRow(firstName: 'Bad', phones: const ['1', '2', '3', '4']);
    final result =
        oneSheet('Friends', [validRow(firstName: 'Good'), tooManyPhones]);

    await expectLater(
        importService.import(result, ImportMode.merge), throwsA(anything));

    // Nothing from this import persisted, including the group itself.
    expect(await groups.watchAll().first, isEmpty);
  });
}
