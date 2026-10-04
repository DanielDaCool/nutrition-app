// Create or edit one preset: its name and its ordered list of exercises.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import '../lifting_repository.dart';
import '../widgets/exercise_dialog.dart' show exerciseSubtitle;
import '../widgets/exercise_picker.dart';

/// Editor for a preset; creates a new one when [existing] is null. Pops
/// when saved.
class PresetEditScreen extends ConsumerStatefulWidget {
  const PresetEditScreen({super.key, this.existing});

  final LiftPreset? existing;

  @override
  ConsumerState<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends ConsumerState<PresetEditScreen> {
  late final TextEditingController _name;
  late final List<LiftExercise> _exercises;
  String? _nameError;
  bool _listEmptyError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _exercises = [...?widget.existing?.exercises];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final picked = await showExercisePicker(context);
    if (picked == null || !mounted) return;
    if (_exercises.any((e) => e.id == picked.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${picked.name}" is already in this preset')),
      );
      return;
    }
    setState(() {
      _exercises.add(picked);
      _listEmptyError = false;
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _exercises.length) return;
    setState(() => _exercises.insert(target, _exercises.removeAt(index)));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name' : null;
      _listEmptyError = _exercises.isEmpty;
    });
    if (name.isEmpty || _exercises.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(liftingRepositoryProvider);
    final ids = [for (final e in _exercises) e.id];
    final existing = widget.existing;
    try {
      if (existing == null) {
        await repo.createPreset(name, ids);
      } else {
        await repo.updatePreset(existing.id, name, ids);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on LiftNameTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = 'You already have a preset with this name';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New preset' : 'Edit preset'),
        actions: [
          TextButton(
            key: const Key('presetSave'),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('presetNameField'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Push day',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Exercises', style: theme.textTheme.titleMedium),
          ),
          if (_exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _listEmptyError
                    ? 'Add at least one exercise'
                    : 'Add the exercises of this preset in the order you '
                          'do them.',
                key: const Key('presetExercisesHint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _listEmptyError ? theme.colorScheme.error : null,
                ),
              ),
            ),
          for (final (i, exercise) in _exercises.indexed)
            ListTile(
              key: Key('presetItem_${exercise.id}'),
              contentPadding: const EdgeInsets.only(left: 16, right: 4),
              leading: Text('${i + 1}', style: theme.textTheme.titleMedium),
              title: Text(exercise.name),
              subtitle: Text(exerciseSubtitle(exercise)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('presetItemUp_${exercise.id}'),
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Move up',
                    visualDensity: VisualDensity.compact,
                    onPressed: i == 0 ? null : () => _move(i, -1),
                  ),
                  IconButton(
                    key: Key('presetItemDown_${exercise.id}'),
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: 'Move down',
                    visualDensity: VisualDensity.compact,
                    onPressed: i == _exercises.length - 1
                        ? null
                        : () => _move(i, 1),
                  ),
                  IconButton(
                    key: Key('presetItemRemove_${exercise.id}'),
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _exercises.removeAt(i)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('presetAddExercise'),
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
