import 'package:drift/drift.dart';

import 'database.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<Setting> get() => _db.select(_db.settings).getSingle();

  Stream<Setting> watch() => _db.select(_db.settings).watchSingle();

  Future<void> update({
    String? notifyTime,
    String? defaultCountryCode,
    int? leadDays,
  }) =>
      (_db.update(_db.settings)..where((s) => s.id.equals(1))).write(
        SettingsCompanion(
          notifyTime: Value.absentIfNull(notifyTime),
          defaultCountryCode: Value.absentIfNull(defaultCountryCode),
          leadDays: Value.absentIfNull(leadDays),
        ),
      );
}
