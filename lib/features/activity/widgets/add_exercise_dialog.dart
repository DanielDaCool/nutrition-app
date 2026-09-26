// OWNER: Health Connect agent (C).
// Dialog for manually logging aerobic exercise (e.g. a bike ride or
// treadmill walk) that Health Connect didn't capture.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../weight/weight_logic.dart' show formatKg;
import '../activity_providers.dart';
import '../manual_exercise_calc.dart';

/// Opens the "Add exercise" dialog for [dayKey] and saves the entry.
///
/// [defaultWeightKg] prefills the body-weight field; pass the caller's own
/// already-resolved latest weigh-in rather than reading it fresh here, since
/// a freshly read stream provider may not have emitted yet.
Future<void> showAddExerciseDialog(
  BuildContext context,
  WidgetRef ref, {
  required String dayKey,
  double? defaultWeightKg,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _AddExerciseDialog(
      dayKey: dayKey,
      defaultWeightKg: defaultWeightKg,
    ),
  );
}

class _AddExerciseDialog extends ConsumerStatefulWidget {
  const _AddExerciseDialog({required this.dayKey, this.defaultWeightKg});

  final String dayKey;
  final double? defaultWeightKg;

  @override
  ConsumerState<_AddExerciseDialog> createState() =>
      _AddExerciseDialogState();
}

class _AddExerciseDialogState extends ConsumerState<_AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationCtrl = TextEditingController(text: '30');
  final _weightCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _customNameCtrl = TextEditingController();

  ExerciseType _type = commonExerciseTypes.first;
  bool _kcalEdited = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl.text = widget.defaultWeightKg == null
        ? ''
        : formatKg(widget.defaultWeightKg!);
    _durationCtrl.addListener(_recompute);
    _weightCtrl.addListener(_recompute);
    _recompute();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _weightCtrl.dispose();
    _kcalCtrl.dispose();
    _customNameCtrl.dispose();
    super.dispose();
  }

  double? get _durationMin => double.tryParse(_durationCtrl.text.trim());
  double? get _weightKg => double.tryParse(_weightCtrl.text.trim());

  void _recompute() {
    if (_kcalEdited || _type.met == null) return;
    final duration = _durationMin;
    final weight = _weightKg;
    if (duration == null || duration <= 0 || weight == null || weight <= 0) {
      return;
    }
    final kcal = estimateExerciseKcal(
      met: _type.met!,
      weightKg: weight,
      durationMin: duration,
    );
    _kcalCtrl.text = kcal.round().toString();
  }

  void _selectType(ExerciseType? type) {
    if (type == null) return;
    setState(() {
      _type = type;
      _kcalEdited = false;
      _recompute();
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final duration = _durationMin!;
    final kcal = double.parse(_kcalCtrl.text.trim());
    final name = _type.met == null
        ? _customNameCtrl.text.trim()
        : _type.label;
    try {
      await addManualExerciseEntry(
        ref,
        dayKey: widget.dayKey,
        activityName: name,
        durationMin: duration,
        kcal: kcal,
        metValue: _kcalEdited ? null : _type.met,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Saving manual exercise failed: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that exercise.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add exercise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ExerciseType>(
                key: const Key('exerciseTypeField'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Activity'),
                items: [
                  for (final t in commonExerciseTypes)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: _selectType,
              ),
              if (_type.met == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('exerciseCustomNameField'),
                  controller: _customNameCtrl,
                  decoration: const InputDecoration(labelText: 'What did you do?'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('exerciseDurationField'),
                controller: _durationCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'min',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n <= 0) ? 'Enter minutes' : null;
                },
              ),
              if (_type.met != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('exerciseWeightField'),
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Body weight (used for the estimate)',
                    suffixText: 'kg',
                  ),
                  validator: (v) {
                    if (_kcalEdited) return null; // not used once overridden
                    final n = double.tryParse((v ?? '').trim());
                    return (n == null || n <= 0) ? 'Enter weight' : null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('exerciseKcalField'),
                controller: _kcalCtrl,
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: InputDecoration(
                  labelText: 'Calories burned',
                  suffixText: 'kcal',
                  helperText: _type.met == null
                      ? null
                      : (_kcalEdited ? null : 'Estimated - edit to override'),
                ),
                onChanged: (_) => setState(() => _kcalEdited = true),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  return (n == null || n < 0) ? 'Enter calories' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
