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

  /// Macros the draft's source didn't give; they must be filled in here.
  List<String> get _missing => widget.existing == null && widget.draft != null
      ? widget.draft!.missingMacros
      : const [];

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

  List<TextEditingController> get _nutritionFields => [
    _kcal,
    _protein,
    _fat,
    _carbs,
  ];

  /// The per-100 g value behind each field this screen converted to per
  /// serving (when the basis was switched). Such a field follows the
  /// serving size until the user types over it, so switching the basis
  /// never changes the food's nutrition.
  final _converted = <TextEditingController, double>{};

  /// Values as entered, converted to per 100 g; null while incomplete.
  Macros? get _per100g {
    final s = _servingG;
    final perServing = _basis == LabelBasis.perServing;
    double? value(TextEditingController c, {bool optional = true}) {
      final exact = _converted[c];
      if (perServing && exact != null) return exact;
      final v = parseAmount(optional && c.text.isEmpty ? '0' : c.text);
      if (v == null || v < 0) return null;
      if (!perServing) return v;
      return s == null ? null : v * 100 / s;
    }

    final k = value(_kcal, optional: false);
    final p = value(_protein);
    final f = value(_fat);
    final c = value(_carbs);
    if ([k, p, f, c].any((v) => v == null)) return null;
    return Macros(kcal: k!, proteinG: p!, fatG: f!, carbsG: c!);
  }

  /// Switches what the nutrition fields mean, converting the numbers in them
  /// so the food stays the same. Going to per serving needs a serving size
  /// when there are numbers to convert.
  void _setBasis(LabelBasis basis) {
    if (basis == _basis) return;
    final s = _servingG;
    final hasValues = _nutritionFields.any((c) => c.text.trim().isNotEmpty);
    if (basis == LabelBasis.perServing && s == null && hasValues) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Enter the serving size first, so the values can be converted.',
            ),
          ),
        );
      return;
    }
    for (final c in _nutritionFields) {
      final typed = parseAmount(c.text);
      if (basis == LabelBasis.perServing) {
        if (typed == null) continue;
        _converted[c] = typed;
        c.text = fmtNum(typed * s! / 100, decimals: 2);
      } else {
        final per100 =
            _converted[c] ??
            (typed == null || s == null ? null : typed * 100 / s);
        if (per100 != null) c.text = fmtNum(per100, decimals: 2);
      }
    }
    if (basis == LabelBasis.per100g) _converted.clear();
    setState(() => _basis = basis);
  }

  /// A new serving size: converted per-serving numbers follow it.
  void _servingChanged() {
    final s = _servingG;
    if (_basis == LabelBasis.perServing && s != null) {
      _converted.forEach((c, per100) {
        c.text = fmtNum(per100 * s / 100, decimals: 2);
      });
    }
    setState(() {});
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
      onChanged: (_) {
        // Typed over: now it's the user's number, not a conversion.
        _converted.remove(c);
        setState(() {});
      },
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
              onSelectionChanged: (s) => _setBasis(s.first),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('serving-grams-field'),
                    controller: _servingGrams,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dec(
                      'Serving size',
                      suffix: 'g',
                      helper: perServing ? null : 'Optional',
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
                    onChanged: (_) => _servingChanged(),
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
            if (_missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                key: const Key('missing-macros'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'The source has no ${_missing.join(' or ')} for this '
                    'food. Fill in the missing values from the label.',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
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
              required: _missing.contains('protein'),
            ),
            const SizedBox(height: 12),
            numberField(
              const Key('fat-field'),
              _fat,
              'Fat $unit',
              'g',
              required: _missing.contains('fat'),
            ),
            const SizedBox(height: 12),
            numberField(
              const Key('carbs-field'),
              _carbs,
              'Carbohydrates $unit',
              'g',
              required: _missing.contains('carbs'),
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
