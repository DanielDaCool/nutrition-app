// Dialog to create or edit one of the user's exercises: name, muscle group
// and the bodyweight flag.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import '../lifting_repository.dart';

/// "Chest" or "Chest · Bodyweight": the one-line description of [exercise]
/// used under its name in lists.
String exerciseSubtitle(LiftExercise exercise) => exercise.isBodyweight
    ? '${exercise.muscleGroup.label} · Bodyweight'
    : exercise.muscleGroup.label;

/// Opens the create/edit exercise dialog and saves the result.
///
/// With [existing] the dialog edits that exercise; otherwise it creates one,
/// with the name field prefilled with [initialName]. Resolves to the saved
/// exercise, or null when cancelled.
Future<LiftExercise?> showExerciseDialog(
  BuildContext context, {
  LiftExercise? existing,
  String? initialName,
}) {
  return showDialog<LiftExercise>(
    context: context,
    builder: (context) =>
        _ExerciseDialog(existing: existing, initialName: initialName),
  );
}

class _ExerciseDialog extends ConsumerStatefulWidget {
  const _ExerciseDialog({this.existing, this.initialName});

  final LiftExercise? existing;
  final String? initialName;

  @override
  ConsumerState<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends ConsumerState<_ExerciseDialog> {
  late final TextEditingController _name;
  MuscleGroup? _muscleGroup;
  late bool _isBodyweight;
  String? _nameError;
  bool _groupMissing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(
      text: existing?.name ?? widget.initialName?.trim() ?? '',
    );
    _muscleGroup = existing?.muscleGroup;
    _isBodyweight = existing?.isBodyweight ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final group = _muscleGroup;
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name' : null;
      _groupMissing = group == null;
    });
    if (name.isEmpty || group == null) return;

    setState(() => _saving = true);
    final repo = ref.read(liftingRepositoryProvider);
    final existing = widget.existing;
    try {
      final int id;
      if (existing == null) {
        id = await repo.addExercise(
          name: name,
          muscleGroup: group,
          isBodyweight: _isBodyweight,
        );
      } else {
        id = existing.id;
        await repo.updateExercise(
          id,
          name: name,
          muscleGroup: group,
          isBodyweight: _isBodyweight,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        LiftExercise(
          id: id,
          name: name,
          muscleGroup: group,
          isBodyweight: _isBodyweight,
        ),
      );
    } on LiftNameTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = 'You already have an exercise with this name';
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
    return AlertDialog(
      scrollable: true,
      title: Text(widget.existing == null ? 'New exercise' : 'Edit exercise'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('exerciseNameField'),
              controller: _name,
              autofocus: widget.existing == null && _name.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Incline barbell press',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 16),
            Text('Muscle group', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final group in MuscleGroup.values)
                  ChoiceChip(
                    key: Key('exerciseMuscleGroup_${group.name}'),
                    label: Text(group.label),
                    selected: _muscleGroup == group,
                    onSelected: (_) => setState(() {
                      _muscleGroup = group;
                      _groupMissing = false;
                    }),
                  ),
              ],
            ),
            if (_groupMissing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pick a muscle group',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('exerciseBodyweightSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Bodyweight exercise'),
              subtitle: const Text('Log only the extra weight you add'),
              value: _isBodyweight,
              onChanged: (v) => setState(() => _isBodyweight = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('exerciseDialogCancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('exerciseDialogSave'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
