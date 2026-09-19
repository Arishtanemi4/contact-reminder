import 'package:drift/drift.dart';

import 'database.dart';

class GroupRepository {
  GroupRepository(this._db);

  final AppDatabase _db;

  Stream<List<Group>> watchAll() => (_db.select(_db.groups)
        ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
      .watch();

  /// Appends a new group at the end.
  Future<Group> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Group name is required');
    final maxOrder = _db.groups.sortOrder.max();
    final row = await (_db.selectOnly(_db.groups)..addColumns([maxOrder]))
        .map((r) => r.read(maxOrder))
        .getSingle();
    return _db.into(_db.groups).insertReturning(
        GroupsCompanion.insert(name: trimmed, sortOrder: (row ?? -1) + 1));
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.groups)..where((g) => g.id.equals(id)))
          .write(GroupsCompanion(name: Value(name.trim())));

  /// Deleting a group deletes its contacts (cascade).
  Future<void> delete(int id) =>
      (_db.delete(_db.groups)..where((g) => g.id.equals(id))).go();

  /// Rewrites sort_order to match the given id order.
  Future<void> reorder(List<int> idsInOrder) => _db.transaction(() async {
        for (var i = 0; i < idsInOrder.length; i++) {
          await (_db.update(_db.groups)
                ..where((g) => g.id.equals(idsInOrder[i])))
              .write(GroupsCompanion(sortOrder: Value(i)));
        }
      });
}
