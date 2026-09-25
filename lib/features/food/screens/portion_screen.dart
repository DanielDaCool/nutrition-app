import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../data/food_repository.dart';
import '../food_providers.dart';
import '../nutrition_math.dart';
import '../widgets/food_format.dart';

enum _Unit { grams, servings }

/// Choose how much of a food to log. Pops with `true` after adding.
class PortionScreen extends ConsumerStatefulWidget {
  const PortionScreen({
    super.key,
    required this.food,
    required this.dayKey,
    required this.meal,
  });

  final Food food;
  final String dayKey;
  final Meal meal;

  @override
  ConsumerState<PortionScreen> createState() => _PortionScreenState();
}

class _PortionScreenState extends ConsumerState<PortionScreen> {
  late _Unit _unit = widget.food.servingGrams != null
      ? _Unit.servings
      : _Unit.grams;
  late final _amount = TextEditingController(
    text: _unit == _Unit.servings ? '1' : '100',
  );
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? _grams(Food food) {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) return null;
    if (_unit == _Unit.servings) {
      final s = food.servingGrams;
      return s == null ? null : v * s;
    }
    return v;
  }

  void _switchUnit(_Unit unit, Food food) {
    if (unit == _unit) return;
    final grams = _grams(food);
    setState(() {
      _unit = unit;
      final s = food.servingGrams;
      if (grams != null && s != null && s > 0) {
        _amount.text = fmtNum(
          unit == _Unit.grams ? grams : grams / s,
          decimals: 2,
        );
      }
    });
  }

  Future<void> _add(Food food) async {
    final grams = _grams(food);
    if (grams == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(foodRepositoryProvider)
          .logFood(
            dayKey: widget.dayKey,
            meal: widget.meal,
            foodId: food.id,
            grams: grams,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live copy so the favorite star reflects the DB.
    final food = ref.watch(foodProvider(widget.food.id)).value ?? widget.food;
    final grams = _grams(food);
    final preview = grams == null
        ? null
        : macrosForGrams(per100gOf(food), grams);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${mealLabel(widget.meal)}'),
        actions: [
          IconButton(
            key: const Key('favorite-toggle'),
            tooltip: food.isFavorite ? 'Remove from favorites' : 'Favorite',
            icon: Icon(food.isFavorite ? Icons.star : Icons.star_border),
            onPressed: () => ref
                .read(foodRepositoryProvider)
                .setFavorite(food.id, !food.isFavorite),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(food.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${sourceLabel(food.source)} · ${foodSubtitle(food)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (food.servingGrams != null) ...[
            SegmentedButton<_Unit>(
              segments: [
                const ButtonSegment(value: _Unit.grams, label: Text('Grams')),
                ButtonSegment(
                  value: _Unit.servings,
                  label: Text(
                    'Servings (${fmtNum(food.servingGrams!)} g)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => _switchUnit(s.first, food),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('amount-field'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _unit == _Unit.grams ? 'Amount' : 'Servings',
              suffixText: _unit == _Unit.grams ? 'g' : '× serving',
              border: const OutlineInputBorder(),
              errorText: grams == null && _amount.text.isNotEmpty
                  ? 'Enter an amount above 0'
                  : null,
              helperText: _unit == _Unit.servings && grams != null
                  ? '= ${fmtNum(grams)} g'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _add(food),
          ),
          const SizedBox(height: 24),
          if (preview != null) _Preview(macros: preview),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('add-button'),
            onPressed: grams == null || _saving ? null : () => _add(food),
            icon: const Icon(Icons.check),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.macros});

  final Macros macros;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            cell('kcal', '${macros.kcal.round()}'),
            cell('protein', '${fmtNum(macros.proteinG)} g'),
            cell('fat', '${fmtNum(macros.fatG)} g'),
            cell('carbs', '${fmtNum(macros.carbsG)} g'),
          ],
        ),
      ),
    );
  }
}
