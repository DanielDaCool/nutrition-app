// Bottom sheet for "Quick add calories": a calorie number with optional
// protein, fat, carbs and a name, for meals eaten without a food to look up.

import 'package:flutter/material.dart';

import '../nutrition_math.dart';
import '../quick_calories.dart';

/// What the user entered in [QuickCaloriesSheet]. A null macro was left
/// blank.
class QuickCaloriesInput {
  const QuickCaloriesInput({
    required this.kcal,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.label,
  });

  final double kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final String? label;
}

/// Opens [QuickCaloriesSheet]; null when dismissed.
Future<QuickCaloriesInput?> showQuickCaloriesSheet(BuildContext context) =>
    showModalBottomSheet<QuickCaloriesInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const QuickCaloriesSheet(),
    );

/// Calories (required), optional protein, fat and carbs, and an optional
/// name. Macros that add up to clearly more than the calories get a warning
/// but are not blocked.
class QuickCaloriesSheet extends StatefulWidget {
  const QuickCaloriesSheet({super.key});

  @override
  State<QuickCaloriesSheet> createState() => _QuickCaloriesSheetState();
}

class _QuickCaloriesSheetState extends State<QuickCaloriesSheet> {
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  final _name = TextEditingController();
  String? _kcalError;
  String? _macroError;

  @override
  void dispose() {
    for (final c in [_kcal, _protein, _fat, _carbs, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  /// A blank macro field is null; anything unreadable or negative is
  /// [double.nan] so the form can flag it.
  static double? _macro(TextEditingController c) {
    if (c.text.trim().isEmpty) return null;
    final v = parseAmount(c.text);
    return v == null || v < 0 ? double.nan : v;
  }

  double? get _kcalValue {
    final v = parseAmount(_kcal.text);
    return v == null || v <= 0 ? null : v;
  }

  String? get _warning {
    final k = _kcalValue;
    final p = _macro(_protein), f = _macro(_fat), c = _macro(_carbs);
    if (k == null || [p, f, c].any((v) => v != null && v.isNaN)) return null;
    if (!macrosExceedKcal(k, proteinG: p, fatG: f, carbsG: c)) return null;
    final implied = macroKcal(proteinG: p, fatG: f, carbsG: c).round();
    return 'Those macros add up to about $implied kcal, more than the '
        '${k.round()} kcal entered. Check the numbers, or add anyway.';
  }

  void _add() {
    final k = _kcalValue;
    final p = _macro(_protein), f = _macro(_fat), c = _macro(_carbs);
    final badMacro = [p, f, c].any((v) => v != null && v.isNaN);
    setState(() {
      _kcalError = k == null ? 'Enter calories above 0' : null;
      _macroError = badMacro ? 'Use numbers of 0 or more' : null;
    });
    if (k == null || badMacro) return;
    Navigator.of(context).pop(
      QuickCaloriesInput(
        kcal: k,
        proteinG: p,
        fatG: f,
        carbsG: c,
        label: _name.text.trim().isEmpty ? null : _name.text.trim(),
      ),
    );
  }

  Widget _macroField(String key, String label, TextEditingController c) =>
      Expanded(
        child: TextField(
          key: Key(key),
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: 'g',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _macroError = null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = _warning;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quick add calories', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Protein, fat and carbs are optional. Leave them blank if you '
              "don't know them.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('quick-kcal'),
              controller: _kcal,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Calories',
                suffixText: 'kcal',
                border: const OutlineInputBorder(),
                errorText: _kcalError,
              ),
              onChanged: (_) => setState(() => _kcalError = null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _macroField('quick-protein', 'Protein', _protein),
                const SizedBox(width: 8),
                _macroField('quick-fat', 'Fat', _fat),
                const SizedBox(width: 8),
                _macroField('quick-carbs', 'Carbs', _carbs),
              ],
            ),
            if (_macroError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _macroError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (warning != null)
              Padding(
                key: const Key('quick-warning'),
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  warning,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quick-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Quick add',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('quick-add-submit'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _add,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
