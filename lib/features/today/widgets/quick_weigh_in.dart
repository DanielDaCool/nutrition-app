// Today screen's inline weigh-in field.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../weight/weight_logic.dart';
import '../../weight/weight_providers.dart';

/// Inline weigh-in entry for a day that has none yet.
///
/// Saves through [WeightRepository.upsert]; errors show in a snack bar.
class QuickWeighIn extends ConsumerStatefulWidget {
  const QuickWeighIn({super.key, required this.dayKey});

  final String dayKey;

  @override
  ConsumerState<QuickWeighIn> createState() => _QuickWeighInState();
}

class _QuickWeighInState extends ConsumerState<QuickWeighIn> {
  final _formKey = GlobalKey<FormState>();
  final _kg = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(weightRepositoryProvider)
          .upsert(widget.dayKey, parseWeightKg(_kg.text)!);
      _kg.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save weigh-in: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12, right: 12),
                child: Icon(Icons.monitor_weight_outlined),
              ),
              Expanded(
                child: TextFormField(
                  key: const Key('quickWeighInField'),
                  controller: _kg,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Weigh-in',
                    hintText: 'e.g. 82.4',
                    suffixText: 'kg',
                    isDense: true,
                  ),
                  validator: validateWeightKg,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton.tonal(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
