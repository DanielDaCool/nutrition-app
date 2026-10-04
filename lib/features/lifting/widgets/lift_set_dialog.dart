// Dialog to add or edit one tracked set: reps and weight.
import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../lifting_format.dart';
import 'lift_set_input.dart';

/// What the user chose in the set dialog.
sealed class LiftSetDialogResult {
  const LiftSetDialogResult();
}

/// Save the set with these values.
class LiftSetSaved extends LiftSetDialogResult {
  const LiftSetSaved({required this.reps, required this.weightKg});

  final int reps;

  /// For a bodyweight exercise the extra weight added (0 for none).
  final double weightKg;
}

/// Delete the set being edited.
class LiftSetDeleted extends LiftSetDialogResult {
  const LiftSetDeleted();
}

/// Asks for the reps and weight of set number [setNumber] of [exercise].
///
/// [initialReps] / [initialWeightKg] pre-fill the fields. With [canDelete]
/// (editing an existing set) a Delete button is offered. Resolves to null
/// when cancelled.
Future<LiftSetDialogResult?> showLiftSetDialog(
  BuildContext context, {
  required LiftExercise exercise,
  required int setNumber,
  int? initialReps,
  double? initialWeightKg,
  bool canDelete = false,
}) {
  return showDialog<LiftSetDialogResult>(
    context: context,
    builder: (_) => _LiftSetDialog(
      exercise: exercise,
      setNumber: setNumber,
      initialReps: initialReps,
      initialWeightKg: initialWeightKg,
      canDelete: canDelete,
    ),
  );
}

class _LiftSetDialog extends StatefulWidget {
  const _LiftSetDialog({
    required this.exercise,
    required this.setNumber,
    required this.initialReps,
    required this.initialWeightKg,
    required this.canDelete,
  });

  final LiftExercise exercise;
  final int setNumber;
  final int? initialReps;
  final double? initialWeightKg;
  final bool canDelete;

  @override
  State<_LiftSetDialog> createState() => _LiftSetDialogState();
}

class _LiftSetDialogState extends State<_LiftSetDialog> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  String? _weightError;
  String? _repsError;

  bool get _isBodyweight => widget.exercise.isBodyweight;

  @override
  void initState() {
    super.initState();
    final weightKg = widget.initialWeightKg;
    _weight = TextEditingController(
      // A bodyweight set without extra weight shows as an empty field.
      text: weightKg == null || (_isBodyweight && weightKg <= 0)
          ? ''
          : formatLiftKg(weightKg),
    );
    _reps = TextEditingController(text: widget.initialReps?.toString() ?? '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _save() {
    final weightKg = parseLiftWeightKg(
      _weight.text,
      emptyIsZero: _isBodyweight,
    );
    final reps = parseLiftReps(_reps.text);
    setState(() {
      _weightError = weightKg != null
          ? null
          : _weight.text.trim().isEmpty
          ? 'Enter the weight'
          : 'Enter a weight of 0 kg or more';
      _repsError = reps != null
          ? null
          : _reps.text.trim().isEmpty
          ? 'Enter the reps'
          : 'Enter a whole number above 0';
    });
    if (weightKg == null || reps == null) return;
    Navigator.of(context).pop(LiftSetSaved(reps: reps, weightKg: weightKg));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Set ${widget.setNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exercise.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('liftSetWeight'),
              controller: _weight,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _isBodyweight ? 'Extra weight (kg)' : 'Weight (kg)',
                helperText: _isBodyweight
                    ? 'Leave empty for bodyweight only'
                    : null,
                errorText: _weightError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('liftSetReps'),
              controller: _reps,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Reps',
                errorText: _repsError,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            key: const Key('liftSetDelete'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(const LiftSetDeleted()),
            child: const Text('Delete'),
          ),
        TextButton(
          key: const Key('liftSetCancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('liftSetSave'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
