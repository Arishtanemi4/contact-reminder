import 'package:drift/drift.dart';

import 'database.dart';

class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

class EventInput {
  const EventInput({
    required this.type,
    this.label,
    required this.month,
    required this.day,
    this.year,
  });

  final EventType type;
  final String? label;
  final int month;
  final int day;
  final int? year;
}

class ContactInput {
  const ContactInput({
    required this.groupId,
    required this.firstName,
    this.surname,
    this.email,
    this.address,
    required this.phones,
    this.events = const [],
  });

  final int groupId;
  final String firstName;
  final String? surname;
  final String? email;
  final String? address;

  /// Raw numbers in order; blank entries are dropped, position = index + 1.
  final List<String> phones;
  final List<EventInput> events;
}

class ContactWithDetails {
  const ContactWithDetails(this.contact, this.phones, this.events);

  final Contact contact;
  final List<ContactPhone> phones;
  final List<ContactEvent> events;
}

class ContactRepository {
  ContactRepository(this._db);

  final AppDatabase _db;

  Future<int> create(ContactInput input) {
    final phones = _validate(input);
    return _db.transaction(() async {
      final now = DateTime.now();
      final id = await _db.into(_db.contacts).insert(ContactsCompanion.insert(
            groupId: input.groupId,
            firstName: input.firstName.trim(),
            surname: Value(_blankToNull(input.surname)),
            email: Value(_blankToNull(input.email)),
            address: Value(_blankToNull(input.address)),
            createdAt: now,
            updatedAt: now,
          ));
      await _insertChildren(id, phones, input.events);
      return id;
    });
  }

  /// Replaces phones and events; always touches the contacts row so watchers fire.
  Future<void> update(int id, ContactInput input) {
    final phones = _validate(input);
    return _db.transaction(() async {
      await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
        ContactsCompanion(
          groupId: Value(input.groupId),
          firstName: Value(input.firstName.trim()),
          surname: Value(_blankToNull(input.surname)),
          email: Value(_blankToNull(input.email)),
          address: Value(_blankToNull(input.address)),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.delete(_db.contactPhones)
            ..where((p) => p.contactId.equals(id)))
          .go();
      await (_db.delete(_db.contactEvents)
            ..where((e) => e.contactId.equals(id)))
          .go();
      await _insertChildren(id, phones, input.events);
    });
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.contacts)..where((c) => c.id.equals(id))).go();

  Future<ContactWithDetails?> get(int id) async {
    final contact = await (_db.select(_db.contacts)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (contact == null) return null;
    return (await _withDetails([contact])).first;
  }

  /// A single contact with its phones/events, updating as it (or its
  /// children) change.
  Stream<ContactWithDetails?> watchOne(int id) {
    final q = _db.select(_db.contacts)..where((c) => c.id.equals(id));
    return q.watchSingleOrNull().asyncMap((contact) async {
      if (contact == null) return null;
      return (await _withDetails([contact])).first;
    });
  }

  /// Contacts of one group ordered by name; optional [query] matches name, email or phone.
  Stream<List<ContactWithDetails>> watchByGroup(int groupId, {String? query}) {
    final q = _db.select(_db.contacts)
      ..where((c) => c.groupId.equals(groupId))
      ..orderBy([
        (c) => OrderingTerm.asc(c.firstName),
        (c) => OrderingTerm.asc(c.surname),
      ]);
    return q.watch().asyncMap((contacts) async {
      final all = await _withDetails(contacts);
      return _filter(all, query);
    });
  }

  /// Search across all groups.
  Future<List<ContactWithDetails>> search(String query) async {
    final contacts = await (_db.select(_db.contacts)
          ..orderBy([(c) => OrderingTerm.asc(c.firstName)]))
        .get();
    return _filter(await _withDetails(contacts), query);
  }

  List<ContactWithDetails> _filter(
      List<ContactWithDetails> all, String? query) {
    final q = query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return all;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return all.where((d) {
      final c = d.contact;
      final text = '${c.firstName} ${c.surname ?? ''} ${c.email ?? ''}'
          .toLowerCase();
      if (text.contains(q)) return true;
      return digits.isNotEmpty &&
          d.phones.any((p) =>
              p.numberRaw.replaceAll(RegExp(r'\D'), '').contains(digits));
    }).toList();
  }

  Future<List<ContactWithDetails>> _withDetails(List<Contact> contacts) async {
    if (contacts.isEmpty) return [];
    final ids = contacts.map((c) => c.id).toList();
    final phones = await (_db.select(_db.contactPhones)
          ..where((p) => p.contactId.isIn(ids))
          ..orderBy([(p) => OrderingTerm.asc(p.position)]))
        .get();
    final events = await (_db.select(_db.contactEvents)
          ..where((e) => e.contactId.isIn(ids)))
        .get();
    return [
      for (final c in contacts)
        ContactWithDetails(
          c,
          phones.where((p) => p.contactId == c.id).toList(),
          events.where((e) => e.contactId == c.id).toList(),
        ),
    ];
  }

  Future<void> _insertChildren(
      int contactId, List<String> phones, List<EventInput> events) async {
    for (var i = 0; i < phones.length; i++) {
      await _db.into(_db.contactPhones).insert(ContactPhonesCompanion.insert(
            contactId: contactId,
            position: i + 1,
            numberRaw: phones[i],
          ));
    }
    for (final e in events) {
      await _db.into(_db.contactEvents).insert(ContactEventsCompanion.insert(
            contactId: contactId,
            type: e.type,
            label: Value(_blankToNull(e.label)),
            month: e.month,
            day: e.day,
            year: Value(e.year),
          ));
    }
  }

  /// Returns trimmed non-blank phones or throws.
  List<String> _validate(ContactInput input) {
    if (input.firstName.trim().isEmpty) {
      throw ValidationException('First name is required');
    }
    final phones =
        input.phones.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (phones.isEmpty) throw ValidationException('At least one phone is required');
    if (phones.length > 3) throw ValidationException('At most 3 phones allowed');
    return phones;
  }

  String? _blankToNull(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
