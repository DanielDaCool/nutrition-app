// Add/edit weigh-in dialog and the long day label shared by weight and
// Today screens.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/day_key.dart';
import '../weight_logic.dart';
import 'weight_input.dart';

/// What the weigh-in dialog returns: the chosen day and weight in kg.
class WeighInInput {
  const WeighInInput({required this.dayKey, required this.weightKg});
  final String dayKey;
  final double weightKg;
}

/// Add/edit dialog. [today] caps the date picker; the date can't be in the
/// future. Returns null when cancelled.
///
/// In add mode [lastKg] prefills the field (selected, so typing replaces it).
/// [existing] (dayKey -> kg) lets the dialog warn when the chosen day
/// already has a weigh-in. [title] overrides the default title.
Future<WeighInInput?> showWeighInDialog(
  BuildContext context, {
  required String today,
  String? initialDayKey,
  double? initialKg,
  double? lastKg,
  Map<String, double> existing = const {},
  String? title,
}) {
  return showDialog<WeighInInput>(
    context: context,
    builder: (_) => WeighInDialog(
      today: today,
      initialDayKey: initialDayKey,
      initialKg: initialKg,
      lastKg: lastKg,
      existing: existing,
      title: title,
    ),
  );
}

/// The dialog behind [showWeighInDialog]; editing when [initialKg] is set.
class WeighInDialog extends StatefulWidget {
  const WeighInDialog({
    super.key,
    required this.today,
    this.initialDayKey,
    this.initialKg,
    this.lastKg,
    this.existing = const {},
    this.title,
  });

  /// Latest selectable day; later days are clamped to it.
  final String today;
  final String? initialDayKey;
  final double? initialKg;

  /// Prefill for add mode (usually the last weigh-in).
  final double? lastKg;

  /// All weigh-ins, to warn before replacing one.
  final Map<String, double> existing;
  final String? title;

  @override
  State<WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends State<WeighInDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kg = _initialController();
  late String _dayKey = _clamp(widget.initialDayKey ?? widget.today);

  bool get _editing => widget.initialKg != null;

  TextEditingController _initialController() {
    final kg = widget.initialKg ?? widget.lastKg;
    final text = kg == null ? '' : formatKg(kg);
    return TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
    );
  }

  String _clamp(String day) =>
      day.compareTo(widget.today) > 0 ? widget.today : day;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startOfDay(_dayKey),
      firstDate: DateTime(2000),
      lastDate: startOfDay(widget.today),
    );
    if (picked != null) setState(() => _dayKey = _clamp(dayKeyOf(picked)));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop(WeighInInput(dayKey: _dayKey, weightKg: parseWeightKg(_kg.text)!));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Warn when saving would replace a different weigh-in.
    final replaced = _editing && _dayKey == widget.initialDayKey
        ? null
        : widget.existing[_dayKey];
    return AlertDialog(
      title: Text(
        widget.title ?? (_editing ? 'Edit weigh-in' : 'Add weigh-in'),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('weighInKgField'),
                controller: _kg,
                autofocus: true,
                keyboardType: weightKeyboardType,
                inputFormatters: const [WeightInputFormatter()],
                textInputAction: TextInputAction.done,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
                validator: validateWeightKg,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(formatDayLong(_dayKey, widget.today)),
                subtitle: const Text('Tap to change the date'),
                onTap: _pickDate,
              ),
              if (replaced != null)
                Row(
                  key: const Key('weighInReplaceWarning'),
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This day already has ${formatKg(replaced)} kg. '
                        'Saving replaces it.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// "Today", "Yesterday", or e.g. "Thu, 24 Sep 2026".
String formatDayLong(String dayKey, String today) {
  if (dayKey == today) return 'Today';
  if (dayKey == addDays(today, -1)) return 'Yesterday';
  final d = startOfDay(dayKey);
  final sameYear = d.year == startOfDay(today).year;
  return DateFormat(sameYear ? 'EEE, d MMM' : 'EEE, d MMM y').format(d);
}
