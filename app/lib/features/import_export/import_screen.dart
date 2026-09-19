import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'import_service.dart';
import 'spreadsheet_service.dart';

/// Pick a .xlsx file, preview what it would do, then apply it (Merge or
/// Replace all).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportResult? _result;
  ImportMode _mode = ImportMode.merge;
  ImportSummary? _summary;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import contacts')),
      body: switch ((_summary, _result)) {
        (final summary?, _) => _SummaryView(summary: summary),
        (_, final result?) => _PreviewView(
            result: result,
            mode: _mode,
            busy: _busy,
            onModeChanged: (m) => setState(() => _mode = m),
            onConfirm: _confirm,
            onCancel: () => setState(() => _result = null),
          ),
        _ => _PickView(busy: _busy, error: _error, onPick: _pickFile),
      },
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null) {
        setState(() => _busy = false);
        return; // user cancelled the picker
      }
      final bytes = await picked.readAsBytes();
      final result = ref.read(spreadsheetServiceProvider).parse(bytes);
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not read file: $e';
        _busy = false;
      });
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final summary =
        await ref.read(importServiceProvider).import(_result!, _mode);
    setState(() {
      _summary = summary;
      _busy = false;
    });
  }
}

class _PickView extends StatelessWidget {
  const _PickView({required this.busy, required this.error, required this.onPick});

  final bool busy;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick a .xlsx file. Each sheet becomes a contact group.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onPick,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_open),
              label: const Text('Choose file'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.result,
    required this.mode,
    required this.busy,
    required this.onModeChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final ImportResult result;
  final ImportMode mode;
  final bool busy;
  final ValueChanged<ImportMode> onModeChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final issues = result.issues;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final sheet in result.sheets)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(sheet.name.isEmpty ? '(could not read file)' : sheet.name),
                  subtitle: Text(sheet.name.isEmpty
                      ? sheet.issues.first.reason
                      : '${sheet.rows.where((r) => r.isValid).length} contact(s)'
                          '${sheet.issues.isEmpty ? '' : ', ${sheet.issues.length} issue(s)'}'),
                ),
              if (issues.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Issues', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final issue in issues)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber, size: 20),
                    title: Text(issue.reason),
                    subtitle: Text('Row ${issue.rowNumber} · ${issue.field}'),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Wrapped in SafeArea so the buttons aren't obscured by a 3-button
        // system navigation bar.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ImportMode>(
                  segments: const [
                    ButtonSegment(value: ImportMode.merge, label: Text('Merge')),
                    ButtonSegment(value: ImportMode.replace, label: Text('Replace all')),
                  ],
                  selected: {mode},
                  onSelectionChanged:
                      busy ? null : (selection) => onModeChanged(selection.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onConfirm,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Import'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'Added ${summary.added}, updated ${summary.updated}, '
              'skipped ${summary.skipped}.',
              textAlign: TextAlign.center,
            ),
            if (summary.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${summary.issues.length} issue(s) — see the previous screen for details.',
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
