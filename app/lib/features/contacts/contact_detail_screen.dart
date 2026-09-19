import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';
import 'contact_actions.dart';
import 'contact_form_screen.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final int contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(contactDetailProvider(contactId));
    return detailAsync.when(
      data: (details) => details == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Contact not found')),
            )
          : _Detail(details: details),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.details});

  final ContactWithDetails details;

  @override
  Widget build(BuildContext context) {
    final contact = details.contact;
    final name = [
      contact.firstName,
      contact.surname,
    ].whereType<String>().join(' ');
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContactFormScreen(
                  contactId: contact.id,
                  initialGroupId: contact.groupId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final phone in details.phones) _PhoneTile(phone: phone),
          for (final event in details.events) _EventTile(event: event),
          if (contact.email != null)
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(contact.email!),
            ),
          if (contact.address != null)
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(contact.address!),
            ),
        ],
      ),
    );
  }
}

class _PhoneTile extends ConsumerWidget {
  const _PhoneTile({required this.phone});

  final ContactPhone phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = phone.numberE164 ?? phone.numberRaw;
    return ListTile(
      leading: const Icon(Icons.phone),
      title: Text(phone.numberRaw),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Call',
            onPressed: () =>
                runContactAction(context, ref, 'Call', (l) => l.call(number)),
          ),
          IconButton(
            icon: const Icon(Icons.sms),
            tooltip: 'SMS',
            onPressed: () =>
                runContactAction(context, ref, 'SMS', (l) => l.sms(number)),
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'WhatsApp',
            onPressed: () => runContactAction(
              context,
              ref,
              'WhatsApp',
              (l) => l.whatsApp(number),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final ContactEvent event;

  @override
  Widget build(BuildContext context) {
    final date = '${event.day} ${_monthNames[event.month - 1]}';
    final yearsKnown = event.year != null;
    final years = yearsKnown ? DateTime.now().year - event.year! : null;
    final suffix = years == null
        ? ''
        : event.type == EventType.birthday
        ? ' · Age $years'
        : ' · $years years';
    return ListTile(
      leading: Icon(switch (event.type) {
        EventType.birthday => Icons.cake,
        EventType.anniversary => Icons.favorite,
        EventType.other => Icons.event,
      }),
      title: Text(event.label ?? _typeLabel(event.type)),
      subtitle: Text('$date$suffix'),
    );
  }

  String _typeLabel(EventType type) => switch (type) {
    EventType.birthday => 'Birthday',
    EventType.anniversary => 'Anniversary',
    EventType.other => 'Event',
  };
}
