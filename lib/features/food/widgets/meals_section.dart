// OWNER: food agent (B). Contract stub: keep the class name and constructor.
// Today screen's meal list: per-meal entries with add, copy from another
// day, edit and swipe-to-delete (with undo), plus the day's "fully logged"
// switch.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../data/food_repository.dart';
import '../food_providers.dart';
import '../nutrition_math.dart';
import '../screens/add_food_screen.dart';
import 'error_retry.dart';
import 'food_format.dart';
import 'undo_snack.dart';

/// The meals of one day (breakfast/lunch/dinner/snacks) with add buttons and
/// the "fully logged" toggle. Shown on the Today screen.
class MealsSection extends ConsumerWidget {
  const MealsSection({super.key, required this.dayKey});

  /// Day shown (`YYYY-MM-DD`, local time).
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dayItemsProvider(dayKey));
    final intake = ref.watch(dayIntakeProvider(dayKey));
    final theme = Theme.of(context);

    final body = switch (items) {
      AsyncData(:final value) => _meals(context, ref, value),
      AsyncError(:final error, :final stackTrace) => ErrorRetry(
        error: error,
        stackTrace: stackTrace,
        message: 'Could not load your meals.',
        onRetry: () {
          ref.invalidate(dayItemsProvider(dayKey));
          ref.invalidate(dayIntakeProvider(dayKey));
        },
      ),
      _ => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    };

    final total = intake.value?.total;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text('Meals', style: theme.textTheme.titleMedium),
            trailing: total == null
                ? null
                : Text(
                    '${fmtKcal(total.kcal)} · P ${fmtNum(total.proteinG, decimals: 0)} g',
                    style: theme.textTheme.titleSmall,
                  ),
          ),
          body,
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Day fully logged'),
            subtitle: const Text('Counts toward your weekly check-in'),
            value: intake.value?.fullyLogged ?? false,
            onChanged: intake.hasValue
                ? (v) =>
                      ref.read(foodRepositoryProvider).setFullyLogged(dayKey, v)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _meals(BuildContext context, WidgetRef ref, List<LoggedItem> items) {
    // The day before, to offer "Same as yesterday" on empty meals. Errors
    // and loading just mean no suggestion.
    final previous =
        ref.watch(dayItemsProvider(addDays(dayKey, -1))).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final meal in Meal.values)
          _MealBlock(
            dayKey: dayKey,
            meal: meal,
            items: [
              for (final i in items)
                if (i.meal == meal) i,
            ],
            previousDayItems: [
              for (final i in previous)
                if (i.meal == meal) i,
            ],
          ),
      ],
    );
  }
}

/// Copies [fromMeal] of [fromDay] into [toMeal] of [toDay] and confirms with
/// an Undo snackbar ("Added 4 items to Breakfast").
Future<void> copyMealWithUndo({
  required ScaffoldMessengerState messenger,
  required FoodRepository repo,
  required String fromDay,
  required Meal fromMeal,
  required String toDay,
  required Meal toMeal,
  required String todayKey,
}) async {
  final List<int> ids;
  try {
    ids = await repo.copyMeal(
      fromDay: fromDay,
      fromMeal: fromMeal,
      toDay: toDay,
      toMeal: toMeal,
    );
  } catch (e, st) {
    showInfoSnack(messenger, 'Could not copy it. ${friendlyError(e, st)}');
    return;
  }
  if (ids.isEmpty) {
    final when = switch (otherDayLabel(fromDay, todayKey)) {
      null => 'today',
      'Yesterday' => 'yesterday',
      'Tomorrow' => 'tomorrow',
      final day => 'on $day',
    };
    showInfoSnack(messenger, 'Nothing logged in ${mealLabel(fromMeal)} $when');
    return;
  }
  showAddedSnack(
    messenger,
    repo,
    'Added ${itemsLabel(ids.length)} to ${mealLabel(toMeal)}',
    ids,
  );
}

/// Actions in a meal header's overflow menu.
enum _MealAction { copyYesterday, copyOtherDay }

/// One meal's header (tap to add, subtotal, copy menu), the "Same as
/// yesterday" chip when it's empty, and its logged items.
class _MealBlock extends ConsumerStatefulWidget {
  const _MealBlock({
    required this.dayKey,
    required this.meal,
    required this.items,
    required this.previousDayItems,
  });

  final String dayKey;
  final Meal meal;
  final List<LoggedItem> items;

  /// The same meal on the day before [dayKey].
  final List<LoggedItem> previousDayItems;

  @override
  ConsumerState<_MealBlock> createState() => _MealBlockState();
}

class _MealBlockState extends ConsumerState<_MealBlock> {
  /// Swiped-away entries, hidden at once (a dismissed Dismissible must leave
  /// the tree before the DB stream catches up).
  final _dismissed = <int>{};

  @override
  void didUpdateWidget(_MealBlock old) {
    super.didUpdateWidget(old);
    final ids = {for (final i in widget.items) i.id};
    _dismissed.retainAll(ids);
  }

  String get _todayKey => dayKeyOf(ref.read(clockProvider)());

  void _openAdd() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AddFoodScreen(dayKey: widget.dayKey, meal: widget.meal),
    ),
  );

  Future<void> _copyFrom(String fromDay) => copyMealWithUndo(
    messenger: ScaffoldMessenger.of(context),
    repo: ref.read(foodRepositoryProvider),
    fromDay: fromDay,
    fromMeal: widget.meal,
    toDay: widget.dayKey,
    toMeal: widget.meal,
    todayKey: _todayKey,
  );

  Future<void> _onMenu(_MealAction action) async {
    switch (action) {
      case _MealAction.copyYesterday:
        await _copyFrom(addDays(widget.dayKey, -1));
      case _MealAction.copyOtherDay:
        final day = startOfDay(widget.dayKey);
        final picked = await showDatePicker(
          context: context,
          helpText: 'Copy ${mealLabel(widget.meal)} from',
          initialDate: DateTime(day.year, day.month, day.day - 1),
          firstDate: DateTime(day.year - 3),
          lastDate: day,
        );
        if (picked == null || !mounted) return;
        await _copyFrom(dayKeyOf(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final meal = widget.meal;
    final items = [
      for (final i in widget.items)
        if (!_dismissed.contains(i.id)) i,
    ];
    final sub = items.fold(Macros.zero, (a, b) => a + b.macros);
    final previous = widget.previousDayItems;
    final previousKcal = previous.fold(0.0, (a, b) => a + b.macros.kcal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        // The whole header adds to this meal.
        ListTile(
          key: Key('meal-header-${meal.name}'),
          minTileHeight: 56,
          contentPadding: const EdgeInsets.only(left: 16, right: 4),
          title: Text(mealLabel(meal), style: theme.textTheme.titleMedium),
          subtitle: Text(
            items.isEmpty
                ? 'Tap to add'
                : '${fmtKcal(sub.kcal)} · '
                      'P ${fmtNum(sub.proteinG, decimals: 0)} g',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          onTap: _openAdd,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<_MealAction>(
                key: Key('meal-menu-${meal.name}'),
                tooltip: 'More for ${mealLabel(meal)}',
                onSelected: _onMenu,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _MealAction.copyYesterday,
                    child: Text('Copy from yesterday'),
                  ),
                  PopupMenuItem(
                    value: _MealAction.copyOtherDay,
                    child: Text('Copy from another day…'),
                  ),
                ],
              ),
              IconButton(
                key: Key('add-${meal.name}'),
                tooltip: 'Add to ${mealLabel(meal)}',
                icon: Icon(Icons.add_circle_outline, color: scheme.primary),
                onPressed: _openAdd,
              ),
            ],
          ),
        ),
        if (items.isEmpty && previous.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: Key('repeat-${meal.name}'),
                avatar: Icon(Icons.replay, size: 18, color: scheme.primary),
                label: Text(
                  'Same as yesterday · ${itemsLabel(previous.length)} · '
                  '${fmtKcal(previousKcal)}',
                ),
                onPressed: () => _copyFrom(addDays(widget.dayKey, -1)),
              ),
            ),
          ),
        for (final item in items)
          _ItemTile(item: item, onDismissed: () => _delete(item)),
      ],
    );
  }

  /// Deletes the entry at once and offers Undo, which re-inserts the same
  /// row (same id and snapshot).
  Future<void> _delete(LoggedItem item) async {
    setState(() => _dismissed.add(item.id));
    final repo = ref.read(foodRepositoryProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final removed = await repo.deleteEntry(item.id);
    if (removed == null || messenger == null) return;
    showUndoSnack(messenger, 'Removed ${item.foodName}', () {
      if (mounted) setState(() => _dismissed.remove(item.id));
      repo.restoreEntry(removed);
    });
  }
}

/// A logged entry: tap to change grams, swipe left to delete.
class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.onDismissed});

  final LoggedItem item;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('entry-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        title: Text(
          item.foodName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${fmtNum(item.grams)} g · ${macroLine(item.macros)}'),
        trailing: Text(fmtKcal(item.macros.kcal)),
        onTap: () => _editGrams(context, ref),
      ),
    );
  }

  Future<void> _editGrams(BuildContext context, WidgetRef ref) async {
    final grams = await showDialog<double>(
      context: context,
      builder: (_) => GramsDialog(title: item.foodName, initial: item.grams),
    );
    if (grams == null) return;
    await ref.read(foodRepositoryProvider).updateEntry(item.id, grams: grams);
  }
}

/// Asks for a new amount in grams.
class GramsDialog extends StatefulWidget {
  const GramsDialog({super.key, required this.title, required this.initial});

  final String title;
  final double initial;

  @override
  State<GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<GramsDialog> {
  late final _controller = TextEditingController(text: fmtNum(widget.initial));
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_controller.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: TextField(
        key: const Key('grams-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: 'g', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
