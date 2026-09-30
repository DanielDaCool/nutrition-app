// OWNER: Health Connect agent (C).
// Dialog for manually logging aerobic exercise (e.g. a bike ride or
// treadmill walk) that Health Connect didn't capture.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../weight/weight_logic.dart' show formatKg;
import '../activity_format.dart';
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
    builder: (_) =>
        _AddExerciseDialog(dayKey: dayKey, defaultWeightKg: defaultWeightKg),
  );
}

/// Parses "5.5" or "5,5"; null when empty or not a number.
double? _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class _AddExerciseDialog extends ConsumerStatefulWidget {
  const _AddExerciseDialog({required this.dayKey, this.defaultWeightKg});

  final String dayKey;
  final double? defaultWeightKg;

  @override
  ConsumerState<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends ConsumerState<_AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationCtrl = TextEditingController(text: '30');
  final _distanceCtrl = TextEditingController();
  final _speedCtrl = TextEditingController();
  final _inclineCtrl = TextEditingController(text: '0');
  final _weightCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _customNameCtrl = TextEditingController();

  ExerciseType _type = commonExerciseTypes.first;
  bool _kcalEdited = false;

  /// Which of speed and distance the user typed last; the other one is
  /// derived from it and the duration.
  bool _speedTyped = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final kg = widget.defaultWeightKg;
    _weightCtrl.text = kg == null ? '' : formatKg(kg);
    _recompute();
  }

  @override
  void dispose() {
    for (final c in [
      _durationCtrl,
      _distanceCtrl,
      _speedCtrl,
      _inclineCtrl,
      _weightCtrl,
      _kcalCtrl,
      _customNameCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _durationMin {
    final v = _parse(_durationCtrl.text);
    return v != null && v > 0 ? v : null;
  }

  double? get _speedKmh {
    final v = _parse(_speedCtrl.text);
    return v != null && v > 0 ? v : null;
  }

  double get _inclinePct => _parse(_inclineCtrl.text) ?? 0;

  /// Distance for saving: exact from speed x time when speed was typed.
  double? get _distanceKm {
    final duration = _durationMin;
    final speed = _speedKmh;
    if (_speedTyped && duration != null && speed != null) {
      return distanceFromSpeed(speed, duration);
    }
    final v = _parse(_distanceCtrl.text);
    return v != null && v > 0 ? v : null;
  }

  /// Fills in whichever of distance/speed the user didn't type.
  void _syncDistanceSpeed() {
    final duration = _durationMin;
    if (_type.gait == null || duration == null) return;
    if (_speedTyped) {
      final speed = _speedKmh;
      _distanceCtrl.text = speed == null
          ? ''
          : formatDecimal(distanceFromSpeed(speed, duration), 2);
    } else {
      final v = _parse(_distanceCtrl.text);
      _speedCtrl.text = v == null || v <= 0
          ? ''
          : formatDecimal(speedFromDistance(v, duration), 1);
    }
  }

  /// Refreshes the calorie estimate unless the user typed their own number.
  void _recompute() {
    if (_kcalEdited || _type.isOther) return;
    final duration = _durationMin;
    final weight = _parse(_weightCtrl.text);
    if (duration == null || weight == null || weight <= 0) {
      _kcalCtrl.text = '';
      return;
    }
    final gait = _type.gait;
    double? kcal;
    if (gait != null) {
      final speed = _speedKmh;
      if (speed != null) {
        kcal = estimateGaitKcal(
          gait: gait,
          speedKmh: speed,
          inclinePct: _inclinePct,
          weightKg: weight,
          durationMin: duration,
        );
      }
    } else {
      kcal = estimateExerciseKcal(
        met: _type.met!,
        weightKg: weight,
        durationMin: duration,
      );
    }
    _kcalCtrl.text = kcal == null ? '' : kcal.round().toString();
  }

  void _changed({bool? speedTyped}) {
    setState(() {
      if (speedTyped != null) _speedTyped = speedTyped;
      _syncDistanceSpeed();
      _recompute();
    });
  }

  void _selectType(ExerciseType? type) {
    if (type == null) return;
    setState(() {
      _type = type;
      _kcalEdited = false;
      _syncDistanceSpeed();
      _recompute();
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final isGait = _type.gait != null;
    try {
      await addManualExerciseEntry(
        ref,
        dayKey: widget.dayKey,
        activityName: _type.isOther ? _customNameCtrl.text.trim() : _type.label,
        durationMin: _durationMin!,
        kcal: _parse(_kcalCtrl.text)!,
        metValue: _kcalEdited ? null : _type.met,
        distanceKm: isGait ? _distanceKm : null,
        inclinePct: isGait ? _inclinePct : null,
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

  static const _decimal = TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    final isGait = _type.gait != null;
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
              if (_type.isOther) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('exerciseCustomNameField'),
                  controller: _customNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What did you do?',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('exerciseDurationField'),
                controller: _durationCtrl,
                keyboardType: _decimal,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  suffixText: 'min',
                ),
                onChanged: (_) => _changed(),
                validator: (_) => _durationMin == null ? 'Enter minutes' : null,
              ),
              if (isGait) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('exerciseDistanceField'),
                        controller: _distanceCtrl,
                        keyboardType: _decimal,
                        decoration: const InputDecoration(
                          labelText: 'Distance',
                          suffixText: 'km',
                        ),
                        onChanged: (_) => _changed(speedTyped: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('exerciseSpeedField'),
                        controller: _speedCtrl,
                        keyboardType: _decimal,
                        decoration: const InputDecoration(
                          labelText: 'Speed',
                          suffixText: 'km/h',
                        ),
                        onChanged: (_) => _changed(speedTyped: true),
                        validator: (_) {
                          final speed = _speedKmh;
                          if (speed == null) {
                            return _kcalEdited
                                ? null
                                : 'Enter distance or speed';
                          }
                          // The ACSM walking formula (estimateGaitKcal) is
                          // only valid up to a brisk walking pace; past that
                          // it roughly halves the true calorie burn, so
                          // "Walk" is capped here and "Run" should be used
                          // above it.
                          final max = _type.gait == Gait.walk ? 8.0 : 30.0;
                          if (speed > max) {
                            return _type.gait == Gait.walk
                                ? 'Too fast for a walk - use Run'
                                : 'Too fast';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('exerciseInclineField'),
                  controller: _inclineCtrl,
                  keyboardType: _decimal,
                  decoration: const InputDecoration(
                    labelText: 'Incline',
                    suffixText: '%',
                  ),
                  onChanged: (_) => _changed(),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final n = _parse(v!);
                    return (n == null || n < 0 || n > 40) ? '0 to 40' : null;
                  },
                ),
              ],
              if (!_type.isOther) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('exerciseWeightField'),
                  controller: _weightCtrl,
                  keyboardType: _decimal,
                  decoration: const InputDecoration(
                    labelText: 'Body weight (used for the estimate)',
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => _changed(),
                  validator: (v) {
                    if (_kcalEdited) return null; // not used once overridden
                    final n = _parse(v ?? '');
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
                  helperText: _type.isOther || _kcalEdited
                      ? null
                      : 'Estimated - edit to override',
                ),
                onChanged: (_) => setState(() => _kcalEdited = true),
                validator: (v) {
                  final n = _parse(v ?? '');
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
