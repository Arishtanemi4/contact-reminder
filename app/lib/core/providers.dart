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

final groupsStreamProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(groupRepositoryProvider).watchAll(),
);

/// Current text typed into the contacts search box.
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

final contactsByGroupProvider =
    StreamProvider.family<List<ContactWithDetails>, int>((ref, groupId) {
  final query = ref.watch(searchQueryProvider);
  return ref
      .watch(contactRepositoryProvider)
      .watchByGroup(groupId, query: query.isEmpty ? null : query);
});

final contactDetailProvider =
    StreamProvider.family<ContactWithDetails?, int>((ref, contactId) {
  return ref.watch(contactRepositoryProvider).watchOne(contactId);
});
