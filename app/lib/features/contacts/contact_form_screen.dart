import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/contact_repository.dart';
import '../../data/database.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// One birthday/anniversary/other-event row being edited. Month+day are
/// always required; the year is optional ("no year" toggle), matching the
/// data model where only month/day are mandatory.
class _EventField {
  _EventField({this.label = '', this.month = 1, this.day = 1, this.year});

  String label;
  int month;
  int day;
  int? year;

  factory _EventField.fromEvent(ContactEvent e) => _EventField(
      label: e.label ?? '', month: e.month, day: e.day, year: e.year);

  EventInput toInput(EventType type) => EventInput(
      type: type,
      label: label.trim().isEmpty ? null : label.trim(),
      month: month,
      day: day,
      year: year);
}

_EventField? _firstOfType(List<ContactEvent> events, EventType type) {
  for (final e in events) {
    if (e.type == type) return _EventField.fromEvent(e);
  }
  return null;
}

/// Add (contactId == null) or edit an existing contact.
class ContactFormScreen extends ConsumerWidget {
  const ContactFormScreen({super.key, this.contactId, required this.initialGroupId});

  final int? contactId;
  final int initialGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (contactId == null) {
      return _ContactForm(initialGroupId: initialGroupId);
    }
    final detailAsync = ref.watch(contactDetailProvider(contactId!));
    return detailAsync.when(
      data: (details) => details == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Contact not found')),
            )
          : _ContactForm(
              key: ValueKey(contactId),
              contactId: contactId,
              initial: details,
              initialGroupId: details.contact.groupId,
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({
    super.key,
    this.contactId,
    this.initial,
    required this.initialGroupId,
  });

  final int? contactId;
  final ContactWithDetails? initial;
  final int initialGroupId;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _surname;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final List<TextEditingController> _phones;
  late int _groupId;
  _EventField? _birthday;
  _EventField? _anniversary;
  late List<_EventField> _others;

  @override
  void initState() {
    super.initState();
    final contact = widget.initial?.contact;
    _firstName = TextEditingController(text: contact?.firstName ?? '');
    _surname = TextEditingController(text: contact?.surname ?? '');
    _email = TextEditingController(text: contact?.email ?? '');
    _address = TextEditingController(text: contact?.address ?? '');
    final existingPhones =
        widget.initial?.phones.map((p) => p.numberRaw).toList() ?? [];
    _phones = [
      for (final p in existingPhones.isEmpty ? [''] : existingPhones)
        TextEditingController(text: p),
    ];
    _groupId = widget.initialGroupId;
    final events = widget.initial?.events ?? [];
    _birthday = _firstOfType(events, EventType.birthday);
    _anniversary = _firstOfType(events, EventType.anniversary);
    _others = events
        .where((e) => e.type == EventType.other)
        .map(_EventField.fromEvent)
        .take(3)
        .toList();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _email.dispose();
    _address.dispose();
    for (final c in _phones) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactId == null ? 'Add contact' : 'Edit contact'),
        actions: [
          if (widget.contactId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'First name is required' : null,
            ),
            TextFormField(
              controller: _surname,
              decoration: const InputDecoration(labelText: 'Surname'),
            ),
            const SizedBox(height: 16),
            groupsAsync.when(
              data: (groups) => _groupPicker(groups),
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            const Text('Phone numbers', style: TextStyle(fontWeight: FontWeight.bold)),
            for (var i = 0; i < _phones.length; i++) _phoneRow(i),
            if (_phones.length < 3)
              TextButton.icon(
                onPressed: () => setState(() => _phones.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Add phone number'),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Events', style: TextStyle(fontWeight: FontWeight.bold)),
            _singleEventSection(
              title: 'Birthday',
              field: _birthday,
              onAdd: () => setState(() => _birthday = _EventField()),
              onRemove: () => setState(() => _birthday = null),
            ),
            _singleEventSection(
              title: 'Anniversary',
              field: _anniversary,
              onAdd: () => setState(() => _anniversary = _EventField()),
              onRemove: () => setState(() => _anniversary = null),
            ),
            for (var i = 0; i < _others.length; i++)
              _eventEditor(
                _others[i],
                includeLabel: true,
                onRemove: () => setState(() => _others.removeAt(i)),
              ),
            if (_others.length < 3)
              TextButton.icon(
                onPressed: () => setState(() => _others.add(_EventField())),
                icon: const Icon(Icons.add),
                label: const Text('Add other event'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _groupPicker(List<Group> groups) {
    return DropdownButtonFormField<int>(
      initialValue: _groupId,
      decoration: const InputDecoration(labelText: 'Group'),
      items: [
        for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name)),
        const DropdownMenuItem(value: -1, child: Text('+ New group')),
      ],
      onChanged: (value) async {
        if (value == -1) {
          final newId = await _createGroup();
          if (newId != null) setState(() => _groupId = newId);
        } else if (value != null) {
          setState(() => _groupId = value);
        }
      },
    );
  }

  Future<int?> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return null;
    final group = await ref.read(groupRepositoryProvider).create(name);
    return group.id;
  }

  Widget _phoneRow(int index) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _phones[index],
            decoration: InputDecoration(labelText: 'Phone ${index + 1}'),
            keyboardType: TextInputType.phone,
            validator: index == 0
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'At least one phone is required'
                    : null
                : null,
          ),
        ),
        if (_phones.length > 1)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              final c = _phones.removeAt(index);
              c.dispose();
            }),
          ),
      ],
    );
  }

  Widget _singleEventSection({
    required String title,
    required _EventField? field,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    if (field == null) {
      return TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text('Add $title'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
            IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
          ],
        ),
        _eventEditor(field, includeLabel: false, onRemove: null),
      ],
    );
  }

  Widget _eventEditor(
    _EventField field, {
    required bool includeLabel,
    required VoidCallback? onRemove,
  }) {
    final yearKnown = field.year != null;
    return Padding(
      key: ValueKey(field),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeLabel)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: field.label,
                    decoration: const InputDecoration(labelText: 'Event name'),
                    onChanged: (v) => field.label = v,
                  ),
                ),
                if (onRemove != null)
                  IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
              ],
            ),
          Row(
            children: [
              DropdownButton<int>(
                value: field.month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
                ],
                onChanged: (v) => setState(() => field.month = v!),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: field.day,
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setState(() => field.day = v!),
              ),
              const SizedBox(width: 16),
              const Text('Year known'),
              Switch(
                value: yearKnown,
                onChanged: (v) => setState(
                    () => field.year = v ? DateTime.now().year : null),
              ),
            ],
          ),
          if (yearKnown)
            SizedBox(
              width: 120,
              child: TextFormField(
                key: ValueKey('${field.hashCode}-year'),
                initialValue: field.year.toString(),
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                onChanged: (v) => field.year = int.tryParse(v) ?? field.year,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final input = ContactInput(
      groupId: _groupId,
      firstName: _firstName.text,
      surname: _surname.text,
      email: _email.text,
      address: _address.text,
      phones: [for (final c in _phones) c.text],
      events: [
        if (_birthday != null) _birthday!.toInput(EventType.birthday),
        if (_anniversary != null) _anniversary!.toInput(EventType.anniversary),
        for (final o in _others) o.toInput(EventType.other),
      ],
    );
    final repo = ref.read(contactRepositoryProvider);
    try {
      if (widget.contactId == null) {
        await repo.create(input);
      } else {
        await repo.update(widget.contactId!, input);
      }
      if (mounted) Navigator.of(context).pop();
    } on ValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(contactRepositoryProvider).delete(widget.contactId!);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}
