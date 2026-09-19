import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../core/providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        key: const Key('settingsList'),
        children: const [
          _GeneralSection(),
          _NotificationsSection(),
          _BatterySection(),
        ],
      ),
    );
  }
}

/// Notify time, lead days, default country code, theme.
class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final settings = settingsAsync.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('General', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          title: const Text('Reminder time'),
          subtitle: Text(settings?.notifyTime ?? '…'),
          trailing: const Icon(Icons.edit),
          onTap: settings == null
              ? null
              : () => _pickTime(context, ref, settings.notifyTime),
        ),
        ListTile(
          title: const Text('Remind me'),
          trailing: settings == null
              ? null
              : DropdownButton<int>(
                  value: settings.leadDays,
                  items: [
                    for (final d in const [0, 1, 2, 3, 5, 7])
                      DropdownMenuItem(
                        value: d,
                        child: Text(_leadDaysLabel(d)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(settingsRepositoryProvider)
                          .update(leadDays: value);
                    }
                  },
                ),
        ),
        ListTile(
          title: const Text('Default country'),
          trailing: settings == null
              ? null
              : DropdownMenu<String>(
                  initialSelection: settings.defaultCountryCode,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  menuHeight: 300,
                  dropdownMenuEntries: [
                    for (final code in IsoCode.values)
                      DropdownMenuEntry(value: code.name, label: code.name),
                  ],
                  onSelected: (value) {
                    if (value != null) {
                      ref
                          .read(settingsRepositoryProvider)
                          .update(defaultCountryCode: value);
                    }
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              const Text('Theme'),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('System')),
                    ButtonSegment(value: 'light', label: Text('Light')),
                    ButtonSegment(value: 'dark', label: Text('Dark')),
                  ],
                  selected: {settings?.themeMode ?? 'system'},
                  onSelectionChanged: settings == null
                      ? null
                      : (selection) => ref
                            .read(settingsRepositoryProvider)
                            .update(themeMode: selection.first),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _leadDaysLabel(int days) => days == 0
      ? 'Same day'
      : days == 1
      ? '1 day before'
      : '$days days before';

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await ref.read(settingsRepositoryProvider).update(notifyTime: formatted);
  }
}

/// Permission status + a manual test button.
class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(notificationsEnabledProvider);
    final exactAsync = ref.watch(exactAlarmsAllowedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          title: const Text('Notification permission'),
          subtitle: Text(
            enabledAsync.when(
              data: (enabled) => enabled ? 'Enabled' : 'Disabled',
              loading: () => 'Checking…',
              error: (_, _) => 'Unknown',
            ),
          ),
          trailing: enabledAsync.value == false
              ? TextButton(
                  onPressed: () => _requestNotificationPermission(context, ref),
                  child: const Text('Enable'),
                )
              : null,
        ),
        ListTile(
          title: const Text('Exact alarms'),
          subtitle: Text(
            exactAsync.when(
              data: (allowed) => allowed
                  ? 'Allowed'
                  : 'Not allowed (reminders may drift by a few minutes)',
              loading: () => 'Checking…',
              error: (_, _) => 'Unknown',
            ),
          ),
          trailing: exactAsync.value == false
              ? TextButton(
                  onPressed: () async {
                    await ref
                        .read(notificationServiceProvider)
                        .requestExactAlarmsPermission();
                    ref.invalidate(exactAlarmsAllowedProvider);
                  },
                  child: const Text('Allow'),
                )
              : null,
        ),
        ListTile(
          title: const Text('Open notification settings'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () =>
              ref.read(notificationServiceProvider).openSystemSettings(),
        ),
        ListTile(
          title: const Text('Send test notification'),
          trailing: const Icon(Icons.notifications_active),
          onTap: () => _sendTest(context, ref),
        ),
      ],
    );
  }

  Future<void> _requestNotificationPermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow notifications?'),
        content: const Text(
          'Contact Reminder needs notification permission to remind you '
          "about birthdays, anniversaries and other events you've added.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true) return;
    await ref.read(notificationServiceProvider).requestPermission();
    ref.invalidate(notificationsEnabledProvider);
  }

  Future<void> _sendTest(BuildContext context, WidgetRef ref) async {
    await ref
        .read(notificationServiceProvider)
        .showNow(0, 'Test notification', 'Notifications are working.');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test notification sent')));
    }
  }
}

/// Explains that some manufacturers (Xiaomi, Oppo, etc.) kill background
/// apps aggressively, which can delay or drop reminders, and links to the
/// settings that fix it.
class _BatterySection extends ConsumerWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ignoredAsync = ref.watch(batteryOptimizationIgnoredProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Background reminders',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Some phone manufacturers restrict background apps to save '
            'battery, which can delay or block reminders. Exempt this app '
            'from battery optimisation to keep reminders reliable.',
          ),
        ),
        ListTile(
          title: const Text('Battery optimisation'),
          subtitle: Text(
            ignoredAsync.when(
              data: (ignored) => ignored ? 'Not restricted' : 'Restricted',
              loading: () => 'Checking…',
              error: (_, _) => 'Unknown',
            ),
          ),
          trailing: TextButton(
            onPressed: () => _openBatterySettings(ref),
            child: const Text('Open battery settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _openBatterySettings(WidgetRef ref) async {
    await ref.read(batteryOptimizationServiceProvider).openSettings();
    ref.invalidate(batteryOptimizationIgnoredProvider);
  }
}
