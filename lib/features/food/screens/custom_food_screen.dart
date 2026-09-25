// Form for creating or editing a user-defined food from its nutrition label.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../data/food_repository.dart';
import '../data/remote_food.dart';
import '../food_providers.dart';
import '../nutrition_math.dart';
import '../widgets/food_format.dart';

/// Whether the typed label values are per 100 g or per serving. Per-serving
/// values are converted to per 100 g before saving.
enum LabelBasis { per100g, perServing }

/// Create or edit a custom food, e.g. typed from a package label.
/// Pops with the saved [Food].
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.barcode, this.draft, this.existing});

  /// Prefilled barcode (from a scan that found nothing).
  final String? barcode;

  /// What a remote source knew (name, brand, serving), if anything.
  final RemoteFood? draft;

  /// Edit this custom food instead of creating one.
  final Food? existing;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _fat;
  late final TextEditingController _carbs;
  late final TextEditingController _servingGrams;
  late final TextEditingController _servingName;
  late final TextEditingController _barcode;
  LabelBasis _basis = LabelBasis.per100g;
  bool _saving = false;

  /// Reached from a barcode that wasn't found (changes the title only).
  bool get _isLabelFlow => widget.barcode != null && widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final d = widget.draft;
    String num(double? v) => v == null ? '' : fmtNum(v, decimals: 2);
    _name = TextEditingController(text: e?.name ?? d?.name ?? '');
    _brand = TextEditingController(text: e?.brand ?? d?.brand ?? '');
    _kcal = TextEditingController(text: num(e?.kcalPer100g ?? d?.kcalPer100g));
    _protein = TextEditingController(
      text: num(e?.proteinPer100g ?? d?.proteinPer100g),
    );
    _fat = TextEditingController(text: num(e?.fatPer100g ?? d?.fatPer100g));
    _carbs = TextEditingController(
      text: num(e?.carbsPer100g ?? d?.carbsPer100g),
    );
    _servingGrams = TextEditingController(
      text: num(e?.servingGrams ?? d?.servingGrams),
    );
    _servingName = TextEditingController(
      text: e?.servingName ?? d?.servingName ?? '',
    );
    _barcode = TextEditingController(text: e?.barcode ?? widget.barcode ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _kcal,
      _protein,
      _fat,
      _carbs,
      _servingGrams,
      _servingName,
      _barcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Serving size in grams, or null when empty, invalid or not above 0.
  double? get _servingG {
    final v = parseAmount(_servingGrams.text);
    return (v != null && v > 0) ? v : null;
  }

  /// Values as entered, converted to per 100 g; null while incomplete.
  Macros? get _per100g {
    final k = parseAmount(_kcal.text);
    final p = parseAmount(_protein.text.isEmpty ? '0' : _protein.text);
    final f = parseAmount(_fat.text.isEmpty ? '0' : _fat.text);
    final c = parseAmount(_carbs.text.isEmpty ? '0' : _carbs.text);
    if ([k, p, f, c].any((v) => v == null || v < 0)) return null;
    final entered = Macros(kcal: k!, proteinG: p!, fatG: f!, carbsG: c!);
    if (_basis == LabelBasis.per100g) return entered;
    final s = _servingG;
    return s == null ? null : per100gFromServing(entered, s);
  }

  /// Form validator for an optional (or [required]) non-negative number.
  String? _nonNegative(String? v, {bool required = false}) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return required ? 'Required' : null;
    final n = parseAmount(t);
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Can\'t be negative';
    return null;
  }

  /// Validates, creates or updates the food, and pops with it. Errors show a
  /// snackbar and keep the form open.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final per100g = _per100g;
    if (per100g == null) return;
    setState(() => _saving = true);
    final input = CustomFoodInput(
      name: _name.text,
      brand: _brand.text,
      per100g: per100g,
      servingName: _servingG == null ? null : _servingName.text,
      servingGrams: _servingG,
      barcode: _barcode.text,
    );
    final repo = ref.read(foodRepositoryProvider);
    try {
      final food = widget.existing == null
          ? await repo.createCustom(input)
          : await repo.updateCustom(widget.existing!.id, input);
      if (mounted) Navigator.of(context).pop(food);
    } catch (e, st) {
      final message = friendlyError(e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the food. $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final per100g = _per100g;
    final warning = per100g == null ? null : labelWarning(per100g);
    final perServing = _basis == LabelBasis.perServing;
    final unit = perServing ? 'per serving' : 'per 100 g';
    final theme = Theme.of(context);

    InputDecoration dec(String label, {String? suffix, String? helper}) =>
        InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          border: const OutlineInputBorder(),
        );

    Widget numberField(
      Key key,
      TextEditingController c,
      String label,
      String suffix, {
      bool required = false,
    }) => TextFormField(
      key: key,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: dec(label, suffix: suffix),
      validator: (v) => _nonNegative(v, required: required),
      onChanged: (_) => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Edit food'
              : _isLabelFlow
              ? 'Add from label'
              : 'New food',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('name-field'),
              controller: _name,
              autofocus: _name.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: dec('Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('brand-field'),
              controller: _brand,
              decoration: dec('Brand (optional)'),
            ),
            const SizedBox(height: 16),
            Text('Nutrition on the label', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<LabelBasis>(
              segments: const [
                ButtonSegment(
                  value: LabelBasis.per100g,
                  label: Text('Per 100 g'),
                ),
                ButtonSegment(
                  value: LabelBasis.perServing,
                  label: Text('Per serving'),
                ),
              ],
              selected: {_basis},
              onSelectionChanged: (s) => setState(() => _basis = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('serving-grams-field'),
                    controller: _servingGrams,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dec(
                      perServing ? 'Serving size' : 'Serving size (optional)',
                      suffix: 'g',
                    ),
                    validator: (v) {
                      final base = _nonNegative(v, required: perServing);
                      if (base != null) return base;
                      if ((v?.trim().isNotEmpty ?? false) &&
                          _servingG == null) {
                        return 'Must be above 0';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('serving-name-field'),
                    controller: _servingName,
                    decoration: dec('Serving name', helper: 'e.g. 1 cup'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            numberField(
              const Key('kcal-field'),
              _kcal,
              'Energy $unit',
              'kcal',
              required: true,
            ),
            const SizedBox(height: 12),
            numberField(
              const Key('protein-field'),
              _protein,
              'Protein $unit',
              'g',
            ),
            const SizedBox(height: 12),
            numberField(const Key('fat-field'), _fat, 'Fat $unit', 'g'),
            const SizedBox(height: 12),
            numberField(
              const Key('carbs-field'),
              _carbs,
              'Carbohydrates $unit',
              'g',
            ),
            if (perServing && per100g != null) ...[
              const SizedBox(height: 8),
              Text(
                'Per 100 g: ${fmtKcal(per100g.kcal)} · ${macroLine(per100g)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (warning != null) ...[
              const SizedBox(height: 12),
              Row(
                key: const Key('label-warning'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('barcode-field'),
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: dec('Barcode (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('save-food'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
