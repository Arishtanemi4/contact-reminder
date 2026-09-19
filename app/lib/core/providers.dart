import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contact_repository.dart';
import '../data/database.dart';
import '../data/group_repository.dart';
import '../data/settings_repository.dart';
import '../features/events/event_calculator.dart';
import '../features/events/today_tomorrow.dart';
import '../features/import_export/export_service.dart';
import '../features/import_export/import_service.dart';
import '../features/import_export/spreadsheet_service.dart';
import '../features/import_export/xlsx_spreadsheet_service.dart';
import 'action_launcher.dart';
import 'clock.dart';
import 'notification_service.dart';

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

final actionLauncherProvider =
    Provider<ActionLauncher>((ref) => const ActionLauncher());

/// Overridden with an already-`init()`-ed instance in `main.dart`.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Re-checked with `ref.invalidate` after the user acts on a permission button.
final notificationsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(notificationServiceProvider).notificationsEnabled(),
);

final exactAlarmsAllowedProvider = FutureProvider<bool>(
  (ref) => ref.watch(notificationServiceProvider).canScheduleExactAlarms(),
);

final spreadsheetServiceProvider =
    Provider<SpreadsheetService>((ref) => const XlsxSpreadsheetService());

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(databaseProvider)),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(databaseProvider)),
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

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final eventCalculatorProvider =
    Provider<EventCalculator>((ref) => const DefaultEventCalculator());

final contactsAllProvider = StreamProvider<List<ContactWithDetails>>(
  (ref) => ref.watch(contactRepositoryProvider).watchAll(),
);

/// Today's and tomorrow's events across all contacts.
final todayTomorrowProvider = Provider<AsyncValue<TodayTomorrow>>((ref) {
  final calc = ref.watch(eventCalculatorProvider);
  final today = ref.watch(clockProvider).now();
  return ref
      .watch(contactsAllProvider)
      .whenData((contacts) => TodayTomorrow.build(contacts, today, calc));
});
