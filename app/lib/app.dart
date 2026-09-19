import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/events/today_screen.dart';
import 'features/settings/settings_screen.dart';

class ContactReminderApp extends StatelessWidget {
  const ContactReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Reminder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeShell(),
    );
  }
}

/// Bottom-nav shell holding the three top-level tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _screens = [
    ContactsScreen(),
    TodayScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Reschedules notifications whenever contacts or settings change (see
    // rescheduleNotifications); ref.listen (not watch) so it fires on every
    // change for the app's lifetime, independent of this widget's own rebuilds.
    ref.listen(contactsAllProvider, (_, _) => rescheduleNotifications(ref));
    ref.listen(settingsStreamProvider, (_, _) => rescheduleNotifications(ref));
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.contacts), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
