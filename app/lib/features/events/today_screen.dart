import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
import '../contacts/contact_actions.dart';
import 'today_tomorrow.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayTomorrowProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Today & Tomorrow')),
      body: async.when(
        data: (data) => data.today.isEmpty && data.tomorrow.isEmpty
            ? const _EmptyState()
            : ListView(
                children: [
                  if (data.today.isNotEmpty)
                    _Section(title: 'Today', occurrences: data.today),
                  if (data.tomorrow.isNotEmpty)
                    _Section(title: 'Tomorrow', occurrences: data.tomorrow),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.occurrences});

  final String title;
  final List<EventOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final occurrence in occurrences)
          _OccurrenceTile(occurrence: occurrence),
      ],
    );
  }
}

class _OccurrenceTile extends ConsumerWidget {
  const _OccurrenceTile({required this.occurrence});

  final EventOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = [occurrence.contact.firstName, occurrence.contact.surname]
        .whereType<String>()
        .join(' ');
    final years = ref
        .read(eventCalculatorProvider)
        .ageOrYears(occurrence.event.year, occurrence.date);
    final subtitle = years == null
        ? null
        : occurrence.event.type == EventType.birthday
        ? 'Turns $years'
        : '$years years';
    return ListTile(
      leading: Icon(switch (occurrence.event.type) {
        EventType.birthday => Icons.cake,
        EventType.anniversary => Icons.favorite,
        EventType.other => Icons.event,
      }),
      title: Text(name),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: occurrence.phones.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.card_giftcard),
              tooltip: 'Send wishes',
              onPressed: () => _sendWishes(context, ref, occurrence),
            ),
    );
  }
}

/// Bottom sheet offering SMS/WhatsApp with the greeting prefilled.
void _sendWishes(BuildContext context, WidgetRef ref, EventOccurrence occ) {
  final phone = occ.phones.first;
  final number = phone.numberE164 ?? phone.numberRaw;
  final text = _wishText(occ);
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('SMS'),
            onTap: () {
              Navigator.pop(sheetContext);
              runContactAction(
                context,
                ref,
                'SMS',
                (l) => l.sms(number, body: text),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('WhatsApp'),
            onTap: () {
              Navigator.pop(sheetContext);
              runContactAction(
                context,
                ref,
                'WhatsApp',
                (l) => l.whatsApp(number, text: text),
              );
            },
          ),
        ],
      ),
    ),
  );
}

String _wishText(EventOccurrence occ) {
  final name = occ.contact.firstName;
  return switch (occ.event.type) {
    EventType.birthday => 'Happy Birthday, $name!',
    EventType.anniversary => 'Happy Anniversary, $name!',
    EventType.other => 'Happy ${occ.event.label ?? 'special day'}, $name!',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No birthdays or anniversaries today or tomorrow.'),
    );
  }
}
