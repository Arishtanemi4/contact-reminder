import 'package:flutter/material.dart';

void main() {
  runApp(const ContactReminderApp());
}

class ContactReminderApp extends StatelessWidget {
  const ContactReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Reminder',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Contact Reminder'))),
    );
  }
}
