// "Describe what you ate": type a meal in plain words, see it understood
// live as item cards (food, grams, kcal and why), fix anything with a tap,
// then add it all at once. Works offline; corrections are remembered.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../data/describe_foods.dart';
import '../data/remote_food.dart';
import '../describe/builtin_foods.dart';
import '../describe/describe_engine.dart';
import '../describe/describe_memory.dart';
import '../describe/food_matcher.dart';
import '../describe/meal_text_parser.dart';
import '../describe/unit_weights.dart';
import '../food_providers.dart';
import '../nutrition_math.dart';
import '../widgets/food_format.dart';
import '../widgets/food_search_panel.dart';
import 'custom_food_screen.dart';

/// How long typing must pause before the text is parsed again.
const describeDebounce = Duration(milliseconds: 300);

const _examples = [
  '5 spoons of cottage cheese 5% and 2 eggs',
  '2 eggs and a slice of bread with hummus',
  'chicken breast 200g, 1 cup rice',
  'coffee with milk and a banana for breakfast',
];

/// Type what you ate and add it to [meal] of [dayKey] (the text can switch
/// the meal, e.g. "for dinner"). Pops with `true` after adding.
class DescribeFoodScreen extends ConsumerStatefulWidget {
  const DescribeFoodScreen({
    super.key,
    required this.dayKey,
    required this.meal,
  });

  final String dayKey;
  final Meal meal;

  @override
  ConsumerState<DescribeFoodScreen> createState() => _DescribeFoodScreenState();
}

/// Changes the user made to one item. Kept by item key, so they survive
/// re-parsing while the rest of the text changes.
class _Edit {
  FoodCandidate? food;
  double? quantity;
  MeasureUnit? unit;
  bool unitSet = false;

  /// Grams typed by the user (overrides the estimate).
  double? grams;
  bool removed = false;

  bool get changesAmount => quantity != null || unitSet;
}

/// An item as shown: the parse plus the user's edits.
class _Row {
  const _Row({
    required this.item,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.estimate,
    required this.grams,
    required this.gramsTyped,
    required this.foodPicked,
  });

  final ParsedItem item;
  final FoodCandidate? food;
  final double quantity;
  final MeasureUnit? unit;
  final GramsEstimate? estimate;
  final double? grams;
  final bool gramsTyped;
  final bool foodPicked;

  bool get canAdd => food != null && grams != null && grams! > 0;

  Macros? get macros => canAdd ? macrosForGrams(food!.per100g, grams!) : null;

  /// Why this row deserves a look, or null when it looks right.
  String? get checkHint {
    if (food == null) return null;
    if (!foodPicked && !(item.match?.isConfident ?? false)) {
      return 'Best guess for the food. Tap it to change.';
    }
    if (!gramsTyped && estimate?.confidence == WeightConfidence.guess) {
      return 'The amount is a rough guess. Tap it to adjust.';
    }
    return null;
  }
}

class _DescribeFoodScreenState extends ConsumerState<DescribeFoodScreen> {
  final _text = TextEditingController();
  Timer? _debounce;

  /// The text that was last parsed (lags [_text] by [describeDebounce]).
  String _parsedText = '';
  final _edits = <String, _Edit>{};
  Meal? _pickedMeal;
  bool _saving = false;

  // Parse cache: re-parse only when the text or the engine changes.
  DescribeEngine? _engineUsed;
  String? _textUsed;
  ParseResult _result = ParseResult.empty;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _parsedText = '');
      return;
    }
    _debounce = Timer(describeDebounce, () {
      if (mounted) setState(() => _parsedText = text);
    });
  }

  void _useExample(String text) {
    _text.text = text;
    _text.selection = TextSelection.collapsed(offset: text.length);
    _debounce?.cancel();
    setState(() => _parsedText = text);
  }

  ParseResult _parse(DescribeEngine engine) {
    if (!identical(engine, _engineUsed) || _textUsed != _parsedText) {
      _engineUsed = engine;
      _textUsed = _parsedText;
      _result = engine.parse(_parsedText);
    }
    return _result;
  }

  _Edit _editOf(ParsedItem item) => _edits.putIfAbsent(item.key, _Edit.new);

  List<_Row> _rows(DescribeEngine engine, ParseResult result) {
    final rows = <_Row>[];
    for (final item in result.items) {
      final e = _edits[item.key];
      if (e?.removed ?? false) continue;
      final food = e?.food ?? item.match?.candidate;
      final quantity = e?.quantity ?? item.quantity;
      final unit = (e?.unitSet ?? false) ? e!.unit : item.unit;
      final estimate = food == null
          ? null
          : (e?.food == null && !(e?.changesAmount ?? false))
          ? item.estimate
          : engine.gramsFor(food, quantity, unit);
      rows.add(
        _Row(
          item: item,
          food: food,
          quantity: quantity,
          unit: unit,
          estimate: estimate,
          grams: e?.grams ?? estimate?.grams,
          gramsTyped: e?.grams != null,
          foodPicked: e?.food != null,
        ),
      );
    }
    return rows;
  }

  Meal _meal(ParseResult result) =>
      _pickedMeal ?? result.suggestedMeal ?? widget.meal;

  // ------------------------------------------------------------- actions

  void _remove(_Row row) => setState(() => _editOf(row.item).removed = true);

  Future<void> _pickFood(DescribeEngine engine, _Row row) async {
    final choice = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FoodPickerSheet(
        engine: engine,
        phrase: row.item.foodPhrase,
        current: row.food,
      ),
    );
    if (choice == null || !mounted) return;
    final FoodCandidate? picked = switch (choice) {
      _Picked(:final food) => food,
      _SearchOnline(:final query) => await _searchOnline(query),
      _CreateFood(:final name) => await _createFood(name),
    };
    if (picked == null || !mounted) return;
    setState(() {
      final e = _editOf(row.item);
      e.food = picked;
      e.grams = null;
    });
  }

  Future<FoodCandidate?> _searchOnline(String query) async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(builder: (_) => _OnlineSearchPage(query: query)),
    );
    return food == null ? null : candidateOf(food);
  }

  Future<FoodCandidate?> _createFood(String name) async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => CustomFoodScreen(
          draft: RemoteFood(
            source: FoodSource.custom,
            externalId: '',
            name: _capitalize(name),
          ),
        ),
      ),
    );
    return food == null ? null : candidateOf(food);
  }

  Future<void> _editAmount(DescribeEngine engine, _Row row) async {
    final food = row.food;
    if (food == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AmountSheet(
        engine: engine,
        food: food,
        quantity: row.quantity,
        unit: row.unit,
        grams: row.grams ?? 0,
        gramsTyped: row.gramsTyped,
        onChanged: (quantity, unit, typedGrams) {
          if (!mounted) return;
          setState(() {
            final e = _editOf(row.item);
            e.quantity = quantity;
            e.unit = unit;
            e.unitSet = true;
            e.grams = typedGrams;
          });
        },
      ),
    );
  }

  /// Saves built-in foods that aren't saved yet, logs every row in one go
  /// with what to remember, then pops with `true`.
  Future<void> _add(List<_Row> rows, Meal meal) async {
    final addable = rows.where((r) => r.canAdd).toList();
    if (addable.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(foodRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final items = <({int foodId, double grams})>[];
      final remember = <String, String>{};
      for (final r in addable) {
        final food = r.food!;
        final foodId =
            food.foodId ??
            (await repo.saveBuiltin(builtinByKey(food.builtinKey!)!)).id;
        items.add((foodId: foodId, grams: r.grams!));
        if (r.foodPicked) {
          final a = DescribeMemory.aliasEntry(r.item.foodPhrase, food.key);
          if (a != null) remember[a.key] = a.value;
        }
        if (r.gramsTyped && r.quantity > 0) {
          final g = DescribeMemory.gramsEntry(
            food.key,
            r.unit,
            r.grams! / r.quantity,
          );
          if (g != null) remember[g.key] = g.value;
        }
      }
      await repo.logMany(
        dayKey: widget.dayKey,
        meal: meal,
        items: items,
        remember: remember,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${_itemsLabel(items.length)} to ${mealLabel(meal)}',
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not add: $e')));
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final engineValue = ref.watch(describeEngineProvider);
    final engine = engineValue.value;
    final result = engine == null ? ParseResult.empty : _parse(engine);
    final rows = engine == null ? const <_Row>[] : _rows(engine, result);
    final meal = _meal(result);

    return Scaffold(
      appBar: AppBar(title: const Text('Describe what you ate')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('describe-field'),
              controller: _text,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. ${_examples.first}',
                border: const OutlineInputBorder(),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _text.clear();
                          _onTextChanged('');
                        },
                      ),
              ),
              onChanged: _onTextChanged,
            ),
          ),
          _MealChips(
            selected: meal,
            fromText: _pickedMeal == null && result.suggestedMeal != null,
            onSelected: (m) => setState(() => _pickedMeal = m),
          ),
          if (engineValue.isLoading && engine == null)
            const LinearProgressIndicator(),
          Expanded(child: _body(engineValue, engine, result, rows)),
          if (rows.isNotEmpty)
            _BottomBar(
              rows: rows,
              meal: meal,
              saving: _saving,
              onAdd: () => _add(rows, meal),
            ),
        ],
      ),
    );
  }

  Widget _body(
    AsyncValue<DescribeEngine> engineValue,
    DescribeEngine? engine,
    ParseResult result,
    List<_Row> rows,
  ) {
    if (engine == null) {
      if (engineValue.hasError) {
        return _Message('Could not load your foods: ${engineValue.error}');
      }
      return const SizedBox.shrink();
    }
    if (_parsedText.trim().isEmpty) {
      return _EmptyHelp(onExample: _useExample);
    }
    if (rows.isEmpty && result.unrecognized.isEmpty) {
      return const _Message(
        'Nothing to add yet. Name a food, e.g. "2 eggs" or "a banana".',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        for (final row in rows)
          row.food == null
              ? _UnmatchedCard(
                  key: ValueKey('unmatched-${row.item.key}'),
                  row: row,
                  onPick: () => _pickFood(engine, row),
                  onSearch: () async {
                    final picked = await _searchOnline(row.item.foodPhrase);
                    if (picked != null && mounted) {
                      setState(() => _editOf(row.item).food = picked);
                    }
                  },
                  onRemove: () => _remove(row),
                )
              : Dismissible(
                  key: ValueKey('item-${row.item.key}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _remove(row),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  child: _ItemCard(
                    row: row,
                    onPickFood: () => _pickFood(engine, row),
                    onEditAmount: () => _editAmount(engine, row),
                    onRemove: () => _remove(row),
                  ),
                ),
        for (final part in result.unrecognized)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              '"$part" of what? Add the food\'s name.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ small parts

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _itemsLabel(int n) => n == 1 ? '1 item' : '$n items';

/// "5 tbsp", "2 eggs" style amount; "portion" when nothing was said.
String _amountLabel(double quantity, MeasureUnit? unit) {
  if (unit == null) return '1 portion';
  if (unit == MeasureUnit.gram) return '${fmtNum(quantity)} g';
  if (unit == MeasureUnit.piece) {
    return '${fmtNum(quantity, decimals: 2)} ${quantity == 1 ? 'pc' : 'pcs'}';
  }
  return '${fmtNum(quantity, decimals: 2)} ${unit.label(quantity)}';
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// Shown before anything is typed: how to write it, with tappable examples.
class _EmptyHelp extends StatelessWidget {
  const _EmptyHelp({required this.onExample});

  final void Function(String) onExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Write it like you\'d say it', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Amounts in spoons, cups, slices, pieces or grams. Separate foods '
          'with commas or "and". Everything is worked out on your phone, and '
          'when you fix a food or an amount it\'s remembered for next time.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Try', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _examples)
              ActionChip(label: Text(e), onPressed: () => onExample(e)),
          ],
        ),
      ],
    );
  }
}

class _MealChips extends StatelessWidget {
  const _MealChips({
    required this.selected,
    required this.fromText,
    required this.onSelected,
  });

  final Meal selected;

  /// The meal was picked up from the text ("for breakfast").
  final bool fromText;
  final void Function(Meal) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final m in Meal.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('meal-${m.name}'),
                label: Text(mealLabel(m)),
                selected: m == selected,
                avatar: m == selected && fromText
                    ? const Icon(Icons.auto_awesome, size: 16)
                    : null,
                tooltip: m == selected && fromText ? 'From your text' : null,
                onSelected: (_) => onSelected(m),
              ),
            ),
        ],
      ),
    );
  }
}

/// One understood item: what was said, the food, amount, kcal and why.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.row,
    required this.onPickFood,
    required this.onEditAmount,
    required this.onRemove,
  });

  final _Row row;
  final VoidCallback onPickFood;
  final VoidCallback onEditAmount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final food = row.food!;
    final macros = row.macros;
    final hint = row.checkHint;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final why = [
      if (row.gramsTyped)
        'You set ${fmtNum(row.grams!)} g'
      else if (row.estimate?.explanation != null)
        row.estimate!.explanation!,
      if (food.isBuiltin) 'typical values',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: hint == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.tertiary),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '"${row.item.originalText}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    key: Key('food-${row.item.key}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: onPickFood,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: food.name),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  child: Text(
                    macros == null ? '' : fmtKcal(macros.kcal),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ActionChip(
                  key: Key('amount-${row.item.key}'),
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    row.unit == MeasureUnit.gram
                        ? '${fmtNum(row.grams ?? 0)} g'
                        : '${_amountLabel(row.quantity, row.unit)} · '
                              '${fmtNum(row.grams ?? 0)} g',
                  ),
                  onPressed: onEditAmount,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (why.isNotEmpty) Text(why, style: muted),
            if (macros != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(macroLine(macros), style: muted),
              ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 16, color: scheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A phrase with no food that fits: offers to pick or search.
class _UnmatchedCard extends StatelessWidget {
  const _UnmatchedCard({
    super.key,
    required this.row,
    required this.onPick,
    required this.onSearch,
    required this.onRemove,
  });

  final _Row row;
  final VoidCallback onPick;
  final VoidCallback onSearch;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search_off,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Didn\'t catch "${row.item.foodPhrase}"',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.list),
                  label: const Text('Pick a food'),
                ),
                TextButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Search online'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky totals and the add button.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.rows,
    required this.meal,
    required this.saving,
    required this.onAdd,
  });

  final List<_Row> rows;
  final Meal meal;
  final bool saving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addable = rows.where((r) => r.canAdd).toList();
    final total = addable.fold(Macros.zero, (a, r) => a + r.macros!);
    final skipped = rows.length - addable.length;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmtKcal(total.kcal),
                      key: const Key('describe-total'),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(macroLine(total), style: theme.textTheme.bodySmall),
                    if (skipped > 0)
                      Text(
                        '$skipped not understood, skipped',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FilledButton(
                  key: const Key('describe-add'),
                  onPressed: addable.isEmpty || saving ? null : onAdd,
                  child: Text(
                    'Add ${_itemsLabel(addable.length)} to ${mealLabel(meal)}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ food picker

sealed class _PickResult {
  const _PickResult();
}

class _Picked extends _PickResult {
  const _Picked(this.food);
  final FoodCandidate food;
}

class _SearchOnline extends _PickResult {
  const _SearchOnline(this.query);
  final String query;
}

class _CreateFood extends _PickResult {
  const _CreateFood(this.name);
  final String name;
}

/// Other matches for a phrase, a filter over all foods, "Search online" and
/// "Create food".
class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet({
    required this.engine,
    required this.phrase,
    required this.current,
  });

  final DescribeEngine engine;
  final String phrase;
  final FoodCandidate? current;

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  late final _query = TextEditingController(text: widget.phrase);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.text.trim();
    final matches = widget.engine.search(q.isEmpty ? widget.phrase : q);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Which food is "${widget.phrase}"?',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('picker-field'),
                controller: _query,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Type to find a food',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const _Message(
                      'No saved or built-in food fits. Search online or '
                      'create it.',
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final c = matches[i].candidate;
                        final selected = c.key == widget.current?.key;
                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text(_candidateSubtitle(c)),
                          trailing: selected ? const Icon(Icons.check) : null,
                          selected: selected,
                          onTap: () => Navigator.of(context).pop(_Picked(c)),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pop(_SearchOnline(q.isEmpty ? widget.phrase : q)),
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Search online'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(_CreateFood(q.isEmpty ? widget.phrase : q)),
                      icon: const Icon(Icons.add),
                      label: const Text('Create food'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _candidateSubtitle(FoodCandidate c) => [
  if (c.brand != null) c.brand!,
  '${c.per100g.kcal.round()} kcal/100 g',
  if (c.isBuiltin)
    'typical values'
  else if (c.isOwn)
    'my food'
  else if (c.isFavorite)
    'favorite',
].join(' · ');

/// The Search tab's online search, for one phrase; pops with the saved food.
class _OnlineSearchPage extends ConsumerWidget {
  const _OnlineSearchPage({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> pick(RemoteFood remote) async {
      final navigator = Navigator.of(context);
      final Food? food;
      if (remote.isComplete) {
        food = await ref.read(foodRepositoryProvider).upsertRemote(remote);
      } else {
        food = await navigator.push<Food>(
          MaterialPageRoute(builder: (_) => CustomFoodScreen(draft: remote)),
        );
      }
      if (food != null) navigator.pop(food);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Search online')),
      body: FoodSearchPanel(initialQuery: query, onPick: pick),
    );
  }
}

// ---------------------------------------------------------- amount editor

/// Quantity stepper, unit and grams for one item; reports every change so
/// the card behind updates live.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.engine,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.gramsTyped,
    required this.onChanged,
  });

  final DescribeEngine engine;
  final FoodCandidate food;
  final double quantity;
  final MeasureUnit? unit;
  final double grams;
  final bool gramsTyped;

  /// (quantity, unit, typed grams or null)
  final void Function(double, MeasureUnit?, double?) onChanged;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late double _quantity = widget.quantity;
  late MeasureUnit _unit = widget.unit ?? MeasureUnit.serving;
  late double? _typed = widget.gramsTyped ? widget.grams : null;
  late final _gramsField = TextEditingController(text: fmtNum(widget.grams));

  @override
  void dispose() {
    _gramsField.dispose();
    super.dispose();
  }

  double get _estimate =>
      widget.engine.gramsFor(widget.food, _quantity, _unit).grams;

  double get _grams => _typed ?? _estimate;

  double get _step =>
      _unit == MeasureUnit.gram ? 10 : (_quantity < 2 ? 0.5 : 1);

  void _changed({bool keepField = false}) {
    if (!keepField) _gramsField.text = fmtNum(_grams);
    widget.onChanged(_quantity, _unit, _typed);
    setState(() {});
  }

  void _setQuantity(double q) {
    if (q <= 0) return;
    _quantity = q;
    _typed = null;
    _changed();
  }

  void _setUnit(MeasureUnit u) {
    if (u == _unit) return;
    if (u == MeasureUnit.gram) {
      _quantity = _grams.roundToDouble();
    } else if (_unit == MeasureUnit.gram) {
      _quantity = 1;
    }
    _unit = u;
    _typed = null;
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = sensibleUnits(widget.food.weightInfo, current: _unit);
    final macros = macrosForGrams(widget.food.per100g, _grams);
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
          Text(widget.food.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Less',
                onPressed: _quantity - _step > 0
                    ? () => _setQuantity(_quantity - _step)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  fmtNum(_quantity, decimals: 2),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'More',
                onPressed: () => _setQuantity(_quantity + _step),
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<MeasureUnit>(
                  key: const Key('unit-dropdown'),
                  initialValue: _unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final u in units)
                      DropdownMenuItem(value: u, child: Text(_unitName(u))),
                  ],
                  onChanged: (u) => u == null ? null : _setUnit(u),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('grams-field'),
            controller: _gramsField,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Grams',
              suffixText: 'g',
              border: const OutlineInputBorder(),
              helperText: _typed == null
                  ? widget.engine
                        .gramsFor(widget.food, _quantity, _unit)
                        .explanation
                  : 'Remembered for next time you say it this way',
            ),
            onChanged: (text) {
              final v = parseAmount(text);
              _typed = v != null && v > 0 ? v : null;
              _changed(keepField: true);
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${fmtKcal(macros.kcal)} · ${macroLine(macros)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

String _unitName(MeasureUnit u) => switch (u) {
  MeasureUnit.gram => 'grams',
  MeasureUnit.kilogram => 'kg',
  MeasureUnit.milliliter => 'ml',
  MeasureUnit.liter => 'liters',
  MeasureUnit.tablespoon => 'tablespoons',
  MeasureUnit.teaspoon => 'teaspoons',
  MeasureUnit.serving => 'servings',
  _ => u.label(2),
};
