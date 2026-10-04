// Picker for one of the user's exercises, with "create new" inside it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import 'exercise_dialog.dart';

/// Lets the user pick one of their exercises (or create a new one, which is
/// then returned). Resolves to null when dismissed.
Future<LiftExercise?> showExercisePicker(
  BuildContext context, {
  String title = 'Add exercise',
}) {
  return showModalBottomSheet<LiftExercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _ExercisePickerSheet(title: title),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet({required this.title});

  final String title;

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens the exercise dialog and, once one is created, closes the sheet
  /// with it.
  Future<void> _create() async {
    final created = await showExerciseDialog(
      context,
      initialName: _query.isEmpty ? null : _query,
    );
    if (created == null || !mounted) return;
    Navigator.of(context).pop(created);
  }

  bool _matches(LiftExercise e) {
    final q = _query.toLowerCase();
    return e.name.toLowerCase().contains(q) ||
        e.muscleGroup.label.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final exercises = ref.watch(liftExercisesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('exercisePickerSearch'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search your exercises',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              key: const Key('exercisePickerNew'),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.add),
              ),
              title: const Text('New exercise'),
              onTap: _create,
            ),
            const Divider(height: 1),
            Expanded(
              child: exercises.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load exercises: $e'),
                  ),
                ),
                data: (all) => _list(context, all),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<LiftExercise> all) {
    final theme = Theme.of(context);
    if (all.isEmpty && _query.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You have no exercises yet. Create your first one above.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final shown = _query.isEmpty ? all : all.where(_matches).toList();
    if (shown.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No exercise matches "$_query".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('exercisePickerCreate'),
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text('Create "$_query"'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final exercise = shown[i];
        return ListTile(
          key: Key('exercisePickerItem_${exercise.id}'),
          title: Text(exercise.name),
          subtitle: Text(exerciseSubtitle(exercise)),
          onTap: () => Navigator.of(context).pop(exercise),
        );
      },
    );
  }
}
