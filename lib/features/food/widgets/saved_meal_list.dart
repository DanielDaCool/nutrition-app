// The Saved tab of the add-food screen: saved meals, each logged into the
// current meal with one tap (with Undo), plus rename and delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../data/food_repository.dart';
import '../food_providers.dart';
import 'error_retry.dart';
import 'food_format.dart';
import 'undo_snack.dart';

/// Asks for a meal name. Returns the trimmed name, or null when cancelled.
Future<String?> askMealName(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirmLabel,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _NameDialog(title: title, initial: initial, confirmLabel: confirmLabel),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _name.text.trim();
    if (v.isNotEmpty) Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('saved-meal-name'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saved-meal-name-ok'),
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Saved meals for the Saved tab. Tapping one logs it into [meal] of
/// [dayKey]; the trailing menu renames or deletes it.
class SavedMealList extends ConsumerWidget {
  const SavedMealList({super.key, required this.dayKey, required this.meal});

  final String dayKey;
  final Meal meal;

  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    SavedMealView m,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(foodRepositoryProvider);
    try {
      final batch = await repo.logSavedMeal(
        dayKey: dayKey,
        meal: meal,
        savedMealId: m.id,
      );
      if (batch.entryIds.isEmpty) {
        showInfoSnack(messenger, '${m.name} has nothing in it');
        return;
      }
      showUndoSnack(
        messenger,
        'Added ${m.name} · ${itemsLabel(batch.entryIds.length)} · '
        '${fmtKcal(m.total.kcal)} to ${mealLabel(meal)}',
        () => repo.undoLogMany(batch),
      );
    } catch (e, st) {
      showInfoSnack(messenger, 'Could not add it. ${friendlyError(e, st)}');
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SavedMealView m,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(foodRepositoryProvider);
    final name = await askMealName(
      context,
      title: 'Rename meal',
      initial: m.name,
      confirmLabel: 'Rename',
    );
    if (name == null || name == m.name) return;
    try {
      await repo.renameSavedMeal(m.id, name);
    } catch (e, st) {
      showInfoSnack(messenger, 'Could not rename it. ${friendlyError(e, st)}');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedMealView m,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(foodRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${m.name}?'),
        content: const Text(
          'Meals you already logged from it stay in your log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('saved-meal-delete-ok'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteSavedMeal(m.id);
    } catch (e, st) {
      showInfoSnack(messenger, 'Could not delete it. ${friendlyError(e, st)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(savedMealsProvider)) {
      AsyncData(:final value) when value.isEmpty => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Save a meal from its ⋮ menu on Today.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) {
          final m = value[i];
          return ListTile(
            key: Key('saved-meal-${m.id}'),
            minTileHeight: 56,
            title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${itemsLabel(m.items.length)} · ${fmtKcal(m.total.kcal)}',
            ),
            trailing: PopupMenuButton<String>(
              key: Key('saved-meal-menu-${m.id}'),
              tooltip: 'More for ${m.name}',
              onSelected: (a) => a == 'rename'
                  ? _rename(context, ref, m)
                  : _delete(context, ref, m),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _log(context, ref, m),
          );
        },
      ),
      AsyncError(:final error, :final stackTrace) => ErrorRetry(
        error: error,
        stackTrace: stackTrace,
        message: 'Could not load your saved meals.',
        onRetry: () => ref.invalidate(savedMealsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
