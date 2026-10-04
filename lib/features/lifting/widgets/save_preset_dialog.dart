// Dialog that saves a day's exercises as a new preset.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lifting_providers.dart';
import '../lifting_repository.dart';

/// Asks for a name and saves the exercises on [dayKey] as a new preset.
/// Resolves to the saved preset's name, or null when cancelled.
Future<String?> showSavePresetDialog(
  BuildContext context, {
  required String dayKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SavePresetDialog(dayKey: dayKey),
  );
}

class _SavePresetDialog extends ConsumerStatefulWidget {
  const _SavePresetDialog({required this.dayKey});

  final String dayKey;

  @override
  ConsumerState<_SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends ConsumerState<_SavePresetDialog> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(liftingRepositoryProvider)
          .savePresetFromDay(widget.dayKey, name);
      if (mounted) Navigator.of(context).pop(name);
    } on LiftNameTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'You already have a preset named "$name"';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = "Couldn't save the preset. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save day as preset'),
      content: TextField(
        key: const Key('liftPresetName'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Preset name',
          hintText: 'e.g. Push day',
          errorText: _error,
          errorMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('liftPresetSave'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
