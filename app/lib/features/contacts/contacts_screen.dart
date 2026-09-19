import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    return groupsAsync.when(
      data: (groups) => groups.isEmpty
          ? Scaffold(
              appBar: AppBar(
                title: const Text('Contacts'),
                actions: const [_SeedButton()],
              ),
              body: const _EmptyState(),
            )
          : _GroupTabs(groups: groups),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

/// Tab bar built from [groups], one contact list per tab.
class _GroupTabs extends ConsumerWidget {
  const _GroupTabs({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: groups.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contacts'),
          actions: const [_SeedButton()],
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final g in groups) Tab(text: g.name)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search contacts',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    ref.read(searchQueryProvider.notifier).set(value),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final g in groups) _GroupContactList(groupId: g.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupContactList extends ConsumerWidget {
  const _GroupContactList({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsByGroupProvider(groupId));
    return contactsAsync.when(
      data: (contacts) => contacts.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final details = contacts[index];
                final name = [details.contact.firstName, details.contact.surname]
                    .whereType<String>()
                    .join(' ');
                return ListTile(
                  title: Text(name),
                  subtitle: details.phones.isEmpty
                      ? null
                      : Text(details.phones.first.numberRaw),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Import a file or add a contact.'));
  }
}

/// Debug-only button to populate the (otherwise empty) database with sample
/// groups/contacts, so the UI can be checked without an xlsx import.
class _SeedButton extends ConsumerWidget {
  const _SeedButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.science_outlined),
      tooltip: 'Seed demo data (debug)',
      onPressed: () => _seed(context, ref),
    );
  }

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupRepositoryProvider);
    final existing = await groups.watchAll().first;
    if (existing.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo data already present')),
        );
      }
      return;
    }
    final contacts = ref.read(contactRepositoryProvider);
    final friends = await groups.create('Friends');
    final office = await groups.create('Office');
    await contacts.create(ContactInput(
      groupId: friends.id,
      firstName: 'Asha',
      surname: 'Kulkarni',
      phones: const ['+91 98765 43210'],
      events: const [EventInput(type: EventType.birthday, month: 5, day: 12)],
    ));
    await contacts.create(ContactInput(
      groupId: office.id,
      firstName: 'Rahul',
      phones: const ['+91 91234 56789'],
    ));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Demo data added')));
    }
  }
}