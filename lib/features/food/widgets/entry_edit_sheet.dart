// Bottom sheet for one logged entry: change the grams, move it to another
// meal, or delete it.

import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../data/food_repository.dart';
import '../nutrition_math.dart';
import 'food_format.dart';

/// What the user chose in [EntryEditSheet].
sealed class EntryEdit {
  const EntryEdit();
}

/// Save [grams] in [meal] (the same meal when not moved).
class EntrySave extends EntryEdit {
  const EntrySave(this.grams, this.meal);
  final double grams;
  final Meal meal;
}

/// Delete the entry.
class EntryDelete extends EntryEdit {
  const EntryDelete();
}

/// Opens [EntryEditSheet] for [item]; null when dismissed.
Future<EntryEdit?> showEntryEditSheet(BuildContext context, LoggedItem item) =>
    showModalBottomSheet<EntryEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => EntryEditSheet(item: item),
    );

/// Grams (preselected so typing replaces them), meal chips, Delete and Save.
class EntryEditSheet extends StatefulWidget {
  const EntryEditSheet({super.key, required this.item});

  final LoggedItem item;

  @override
  State<EntryEditSheet> createState() => _EntryEditSheetState();
}

class _EntryEditSheetState extends State<EntryEditSheet> {
  /// The grams as first shown (rounded to 0.1 g).
  late final _shownGrams = fmtNum(widget.item.grams);
  late final _grams = TextEditingController(
    text: _shownGrams,
  )..selection = TextSelection(baseOffset: 0, extentOffset: _shownGrams.length);
  late Meal _meal = widget.item.meal;
  String? _error;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double? get _value {
    // Untouched: keep the exact grams, not the rounded text, so moving an
    // entry to another meal doesn't nudge 14.86 g to 14.9 g.
    if (_grams.text.trim() == _shownGrams) return widget.item.grams;
    final v = parseAmount(_grams.text);
    return v == null || v <= 0 ? null : v;
  }

  void _save() {
    final v = _value;
    if (v == null) {
      setState(() => _error = 'Enter an amount above 0');
      return;
    }
    Navigator.of(context).pop(EntrySave(v, _meal));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final v = _value;
    final kcal = v == null ? null : item.macros.kcal * v / item.grams;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.foodName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('grams-field'),
            controller: _grams,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: 'g',
              border: const OutlineInputBorder(),
              errorText: _error,
              helperText: kcal == null ? null : fmtKcal(kcal),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text('Meal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Meal.values)
                ChoiceChip(
                  key: Key('move-${m.name}'),
                  label: Text(mealLabel(m)),
                  selected: m == _meal,
                  onSelected: (_) => setState(() => _meal = m),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton.icon(
                key: const Key('delete-entry'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.of(context).pop(const EntryDelete()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('save-entry'),
                style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A logged entry: tap to edit, swipe left to delete.
class LoggedItemTile extends StatelessWidget {
  const LoggedItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  final LoggedItem item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('entry-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
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
        onTap: onTap,
      ),
    );
  }
}
