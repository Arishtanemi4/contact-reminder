import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: const [_NotificationsSection()]),
    );
  }
}

/// Permission status + a manual test button. Other settings (notify time,
/// lead days, default country code, theme) are added in 7.1.
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
          onTap: () => ref.read(notificationServiceProvider).openSystemSettings(),
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
