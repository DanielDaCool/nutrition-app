// Add/edit weigh-in dialog and the long day label shared by weight and
// Today screens.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/day_key.dart';
import '../weight_logic.dart';

/// What the weigh-in dialog returns: the chosen day and weight in kg.
class WeighInInput {
  const WeighInInput({required this.dayKey, required this.weightKg});
  final String dayKey;
  final double weightKg;
}

/// Add/edit dialog. [today] caps the date picker; the date can't be in the
/// future. Returns null when cancelled.
Future<WeighInInput?> showWeighInDialog(
  BuildContext context, {
  required String today,
  String? initialDayKey,
  double? initialKg,
}) {
  return showDialog<WeighInInput>(
    context: context,
    builder: (_) => WeighInDialog(
      today: today,
      initialDayKey: initialDayKey,
      initialKg: initialKg,
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
  });

  /// Latest selectable day; later days are clamped to it.
  final String today;
  final String? initialDayKey;
  final double? initialKg;

  @override
  State<WeighInDialog> createState() => _WeighInDialogState();
}

class _WeighInDialogState extends State<WeighInDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kg = TextEditingController(
    text: widget.initialKg?.toStringAsFixed(1) ?? '',
  );
  late String _dayKey = _clamp(widget.initialDayKey ?? widget.today);

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
    final editing = widget.initialKg != null;
    return AlertDialog(
      title: Text(editing ? 'Edit weigh-in' : 'Add weigh-in'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('weighInKgField'),
              controller: _kg,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              subtitle: const Text('Date'),
              onTap: _pickDate,
            ),
          ],
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
