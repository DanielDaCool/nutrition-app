// One exercise on a day: what was done last time, the tracked sets, and the
// actions to add sets or change the plan.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../lifting_format.dart';
import '../lifting_providers.dart';
import 'exercise_picker.dart';
import 'lift_set_dialog.dart';
import 'lift_write.dart';

enum _EntryAction { swap, moveUp, moveDown, remove }

/// "Last (28 Sep): 60 kg × 7 · 60 kg × 4": every set of [session], which
/// was done before [dayKey]. The year is added when it differs.
String formatLastSession(
  LiftSession session,
  String dayKey, {
  required bool isBodyweight,
}) {
  final day = startOfDay(session.dayKey);
  final sameYear = day.year == startOfDay(dayKey).year;
  final date = DateFormat(sameYear ? 'd MMM' : 'd MMM y').format(day);
  final sets = formatLiftSets(session.sets, isBodyweight: isBodyweight);
  return 'Last ($date): $sets';
}

/// Card for [entry]: name, muscle group, the last session's sets, this
/// day's sets (tap to edit), "Add set" and a menu to swap, move or remove.
///
/// [onMoveUp] / [onMoveDown] are null when the entry is first / last.
/// [dayExerciseIds] are the exercises already on the day, which a swap
/// can't pick again.
class LiftEntryCard extends ConsumerWidget {
  const LiftEntryCard({
    super.key,
    required this.entry,
    required this.dayExerciseIds,
    this.onMoveUp,
    this.onMoveDown,
  });

  final LiftEntry entry;
  final Set<int> dayExerciseIds;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  LiftExercise get _exercise => entry.exercise;

  Future<void> _addSet(
    BuildContext context,
    WidgetRef ref,
    LiftSession? last,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Start from the previous set, or from last time's first set.
    final previous = entry.sets.isNotEmpty
        ? entry.sets.last
        : last?.sets.firstOrNull;
    final result = await showLiftSetDialog(
      context,
      exercise: _exercise,
      setNumber: entry.sets.length + 1,
      initialReps: previous?.reps,
      initialWeightKg: previous?.weightKg,
    );
    if (result is! LiftSetSaved) return;
    await guardLiftWrite(
      messenger,
      () => ref
          .read(liftingRepositoryProvider)
          .addSet(entry.id, reps: result.reps, weightKg: result.weightKg),
    );
  }

  Future<void> _editSet(
    BuildContext context,
    WidgetRef ref,
    LiftSet set,
    int setNumber,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(liftingRepositoryProvider);
    final result = await showLiftSetDialog(
      context,
      exercise: _exercise,
      setNumber: setNumber,
      initialReps: set.reps,
      initialWeightKg: set.weightKg,
      canDelete: true,
    );
    switch (result) {
      case LiftSetSaved():
        await guardLiftWrite(
          messenger,
          () => repo.updateSet(
            set.id,
            reps: result.reps,
            weightKg: result.weightKg,
          ),
        );
      case LiftSetDeleted():
        await guardLiftWrite(messenger, () => repo.deleteSet(set.id));
      case null:
        break;
    }
  }

  Future<void> _swap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showExercisePicker(context, title: 'Swap exercise');
    if (picked == null || picked.id == _exercise.id) return;
    if (dayExerciseIds.contains(picked.id)) {
      showLiftSnack(messenger, '${picked.name} is already on this day');
      return;
    }
    await guardLiftWrite(
      messenger,
      () => ref
          .read(liftingRepositoryProvider)
          .changeEntryExercise(entry.id, picked.id),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(liftingRepositoryProvider);
    if (entry.sets.isNotEmpty) {
      final count = entry.sets.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove ${_exercise.name}?'),
          content: Text(
            count == 1
                ? 'Its tracked set on this day is deleted too.'
                : 'Its $count tracked sets on this day are deleted too.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('liftConfirmRemove'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await guardLiftWrite(messenger, () => repo.removeEntry(entry.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isBodyweight = _exercise.isBodyweight;
    final lastAsync = ref.watch(
      liftLastSessionProvider((_exercise.id, entry.dayKey)),
    );
    final last = lastAsync.value;
    final isDone = entry.sets.isNotEmpty;

    return Card(
      key: ValueKey('liftEntry-${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _exercise.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBodyweight
                              ? '${_exercise.muscleGroup.label} · Bodyweight'
                              : _exercise.muscleGroup.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _StatusLabel(setCount: entry.sets.length),
                ),
                PopupMenuButton<_EntryAction>(
                  key: ValueKey('liftEntryMenu-${entry.id}'),
                  tooltip: 'Exercise options',
                  onSelected: (action) {
                    switch (action) {
                      case _EntryAction.swap:
                        _swap(context, ref);
                      case _EntryAction.moveUp:
                        onMoveUp?.call();
                      case _EntryAction.moveDown:
                        onMoveDown?.call();
                      case _EntryAction.remove:
                        _remove(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _EntryAction.swap,
                      child: Text('Swap exercise'),
                    ),
                    PopupMenuItem(
                      value: _EntryAction.moveUp,
                      enabled: onMoveUp != null,
                      child: const Text('Move up'),
                    ),
                    PopupMenuItem(
                      value: _EntryAction.moveDown,
                      enabled: onMoveDown != null,
                      child: const Text('Move down'),
                    ),
                    const PopupMenuItem(
                      value: _EntryAction.remove,
                      child: Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
            // Nothing while loading, so the line doesn't flash "First time".
            if (lastAsync.hasValue)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Text(
                  last == null
                      ? 'First time'
                      : formatLastSession(
                          last,
                          entry.dayKey,
                          isBodyweight: isBodyweight,
                        ),
                  key: ValueKey('liftLast-${entry.id}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ),
            if (isDone) const SizedBox(height: 4),
            for (final (i, set) in entry.sets.indexed)
              _SetRow(
                key: ValueKey('liftSet-${set.id}'),
                setNumber: i + 1,
                text: formatLiftSet(set, isBodyweight: isBodyweight),
                onTap: () => _editSet(context, ref, set, i + 1),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('liftAddSet-${entry.id}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _addSet(context, ref, last),
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Planned" before any set is tracked, "3 sets" with a check afterwards.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.setCount});

  final int setCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = setCount > 0;
    final color = isDone
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.schedule,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          !isDone
              ? 'Planned'
              : setCount == 1
              ? '1 set'
              : '$setCount sets',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// "Set 1   60 kg × 7"; tap to edit or delete.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.setNumber,
    required this.text,
    required this.onTap,
  });

  final int setNumber;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  'Set $setNumber',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
              Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
              Icon(Icons.edit_outlined, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
