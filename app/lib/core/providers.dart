import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contact_repository.dart';
import '../data/database.dart';
import '../data/group_repository.dart';
import '../data/settings_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.watch(databaseProvider)),
);

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => ContactRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
