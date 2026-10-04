// "My exercises": create, edit and delete the user's exercises.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import '../widgets/exercise_dialog.dart';

/// List of the user's exercises with their muscle group.
class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LiftExercise exercise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${exercise.name}"?'),
        content: const Text(
          'It is removed from your presets and from the exercise list. '
          'Days where you already planned or logged it keep their history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('exerciseDeleteConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(liftingRepositoryProvider).deleteExercise(exercise.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(liftExercisesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('exercisesAddFab'),
        onPressed: () => showExerciseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New exercise'),
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load exercises: $e'),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No exercises yet.\n'
                  'Add the ones you do, each with its muscle group.',
                  key: Key('exercisesEmpty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            // Room for the FAB under the last row.
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: all.length,
            itemBuilder: (context, i) {
              final exercise = all[i];
              return ListTile(
                key: Key('exerciseTile_${exercise.id}'),
                title: Text(exercise.name),
                subtitle: Text(exerciseSubtitle(exercise)),
                onTap: () => showExerciseDialog(context, existing: exercise),
                trailing: IconButton(
                  key: Key('exerciseDelete_${exercise.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, ref, exercise),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
