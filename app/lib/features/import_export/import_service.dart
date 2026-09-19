import 'package:drift/drift.dart';

import '../../core/phone_normalizer.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';
import 'spreadsheet_service.dart';

enum ImportMode { merge, replace }

class ImportSummary {
  const ImportSummary({
    this.added = 0,
    this.updated = 0,
    this.skipped = 0,
    this.issues = const [],
  });

  final int added;
  final int updated;

  /// Rows with a missing/invalid required field; not imported.
  final int skipped;
  final List<RowIssue> issues;
}

/// Applies a parsed spreadsheet to the database: one sheet per group.
///
/// Merge matches an existing contact on group + first name + surname +
/// phone 1 (normalised) and updates it; anything unmatched is added.
/// Replace clears all groups/contacts first, then inserts everything fresh.
/// Runs as a single transaction: any failure rolls back the whole import.
class ImportService {
  ImportService(this._db,
      {ContactRepository? contacts,
      this._phoneNormalizer = const DefaultPhoneNormalizer()})
      : _contacts = contacts ?? ContactRepository(_db);

  final AppDatabase _db;
  final ContactRepository _contacts;
  final PhoneNormalizer _phoneNormalizer;

  Future<ImportSummary> import(ImportResult result, ImportMode mode) {
    return _db.transaction(() async {
      final region =
          (await _db.select(_db.settings).getSingle()).defaultCountryCode;
      if (mode == ImportMode.replace) {
        await _db.delete(_db.groups).go();
      }

      var added = 0;
      var updated = 0;
      var skipped = 0;
      final issues = <RowIssue>[];

      for (final sheet in result.sheets) {
        // parse() reports file-level failures as a sheet named '' with no
        // real group to import into.
        final isFileError = sheet.name.isEmpty;
        final groupId = isFileError ? null : await _findOrCreateGroup(sheet.name);

        for (final row in sheet.rows) {
          issues.addAll(row.issues);
          if (isFileError || !row.isValid) {
            skipped++;
            continue;
          }

          final phone1Key =
              _phoneNormalizer.normalize(row.phones.first, region) ??
                  row.phones.first.trim();
          final existingId = mode == ImportMode.merge
              ? await _findExisting(groupId!, row.firstName!, row.surname, phone1Key)
              : null;

          final input = _toInput(groupId!, row);
          if (existingId != null) {
            await _contacts.update(existingId, input);
            updated++;
          } else {
            await _contacts.create(input);
            added++;
          }
        }
      }
      return ImportSummary(
          added: added, updated: updated, skipped: skipped, issues: issues);
    });
  }

  Future<int> _findOrCreateGroup(String name) async {
    final trimmed = name.trim();
    final existing = await (_db.select(_db.groups)
          ..where((g) => g.name.equals(trimmed)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final maxOrder = _db.groups.sortOrder.max();
    final order = await (_db.selectOnly(_db.groups)..addColumns([maxOrder]))
        .map((r) => r.read(maxOrder))
        .getSingle();
    return _db.into(_db.groups).insert(
        GroupsCompanion.insert(name: trimmed, sortOrder: (order ?? -1) + 1));
  }

  /// Merge key = group + first name + surname + phone 1 (normalised).
  Future<int?> _findExisting(
      int groupId, String firstName, String? surname, String phone1Key) async {
    final candidates = await (_db.select(_db.contacts)
          ..where((c) => c.groupId.equals(groupId) & c.firstName.equals(firstName)))
        .get();
    for (final c in candidates) {
      if ((c.surname ?? '') != (surname ?? '')) continue;
      final phone1 = await (_db.select(_db.contactPhones)
            ..where((p) => p.contactId.equals(c.id) & p.position.equals(1)))
          .getSingleOrNull();
      if (phone1 == null) continue;
      final existingKey = phone1.numberE164 ?? phone1.numberRaw.trim();
      if (existingKey == phone1Key) return c.id;
    }
    return null;
  }

  ContactInput _toInput(int groupId, ParsedRow row) => ContactInput(
        groupId: groupId,
        firstName: row.firstName!,
        surname: row.surname,
        email: row.email,
        address: row.address,
        phones: row.phones,
        events: [
          if (row.dob != null)
            EventInput(
                type: EventType.birthday,
                month: row.dob!.month,
                day: row.dob!.day,
                year: row.dob!.year),
          if (row.anniversary != null)
            EventInput(
                type: EventType.anniversary,
                month: row.anniversary!.month,
                day: row.anniversary!.day,
                year: row.anniversary!.year),
          for (final e in row.otherEvents)
            EventInput(
                type: EventType.other,
                label: e.name,
                month: e.date.month,
                day: e.date.day,
                year: e.date.year),
        ],
      );
}
