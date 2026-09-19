import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/action_launcher.dart';
import '../../core/providers.dart';

/// Runs a call/SMS/WhatsApp [action] and shows a snackbar if no app could
/// handle it (e.g. WhatsApp not installed).
Future<void> runContactAction(
  BuildContext context,
  WidgetRef ref,
  String actionLabel,
  Future<bool> Function(ActionLauncher launcher) action,
) async {
  final ok = await action(ref.read(actionLauncherProvider));
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$actionLabel: no app available for this number')),
    );
  }
}
