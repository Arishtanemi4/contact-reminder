import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

enum EventType { birthday, anniversary, other }

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get sortOrder => integer()();
}

class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get firstName => text()();
  TextColumn get surname => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class ContactPhones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer().customConstraint('NOT NULL CHECK (position BETWEEN 1 AND 3)')();
  TextColumn get numberRaw => text()();
  TextColumn get numberE164 => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {contactId, position},
      ];
}

class ContactEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contactId =>
      integer().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<EventType>()();
  TextColumn get label => text().nullable()();
  IntColumn get month => integer().customConstraint('NOT NULL CHECK (month BETWEEN 1 AND 12)')();
  IntColumn get day => integer().customConstraint('NOT NULL CHECK (day BETWEEN 1 AND 31)')();
  IntColumn get year => integer().nullable()();
}

/// Single-row table (id is always 1).
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1)).customConstraint('NOT NULL DEFAULT 1 CHECK (id = 1)')();
  TextColumn get notifyTime => text().withDefault(const Constant('08:00'))();
  TextColumn get defaultCountryCode =>
      text().withDefault(const Constant('IN'))();
  IntColumn get leadDays => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Groups, Contacts, ContactPhones, ContactEvents, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'contact_reminder'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(settings).insert(SettingsCompanion.insert());
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
