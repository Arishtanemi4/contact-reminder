import '../../data/contact_repository.dart';
import '../../data/database.dart';
import '../../data/group_repository.dart';
import 'spreadsheet_service.dart';

/// Reads all groups/contacts from the database into the same [ParsedSheet]
/// shape [SpreadsheetService.build] writes out, so export mirrors import:
/// one sheet per group.
class ExportService {
  ExportService(AppDatabase db, {GroupRepository? groups, ContactRepository? contacts})
      : _groups = groups ?? GroupRepository(db),
        _contacts = contacts ?? ContactRepository(db);

  final GroupRepository _groups;
  final ContactRepository _contacts;

  Future<List<ParsedSheet>> export() async {
    final groups = await _groups.watchAll().first;
    final sheets = <ParsedSheet>[];
    for (final group in groups) {
      final contacts = await _contacts.watchByGroup(group.id).first;
      sheets.add(ParsedSheet(
        name: group.name,
        rows: [for (var i = 0; i < contacts.length; i++) _toRow(i + 1, contacts[i])],
      ));
    }
    return sheets;
  }

  ParsedRow _toRow(int rowNumber, ContactWithDetails details) {
    final contact = details.contact;
    ParsedDate? dateFor(EventType type) {
      for (final e in details.events) {
        if (e.type == type) return ParsedDate(month: e.month, day: e.day, year: e.year);
      }
      return null;
    }

    return ParsedRow(
      rowNumber: rowNumber,
      firstName: contact.firstName,
      surname: contact.surname,
      phones: [for (final p in details.phones) p.numberRaw],
      dob: dateFor(EventType.birthday),
      anniversary: dateFor(EventType.anniversary),
      otherEvents: [
        for (final e in details.events)
          if (e.type == EventType.other)
            ParsedEvent(
                name: e.label ?? '',
                date: ParsedDate(month: e.month, day: e.day, year: e.year)),
      ],
      email: contact.email,
      address: contact.address,
    );
  }
}
