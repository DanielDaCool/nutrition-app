// Today screen's inline weigh-in: a big field for a day without a weigh-in,
// and a compact summary row once there is one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../weight/weigh_in_actions.dart';
import '../../weight/weight_logic.dart';
import '../../weight/weight_providers.dart';
import '../../weight/widgets/weight_input.dart';

/// Inline weigh-in entry for a day that has none yet. The hint shows the
/// last weight; Save (or Done on the keyboard) saves with an Undo snackbar.
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
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await saveWeighInWithUndo(
      messenger: ScaffoldMessenger.of(context),
      repo: ref.read(weightRepositoryProvider),
      before: ref.read(weighInsProvider).value ?? const {},
      dayKey: widget.dayKey,
      weightKg: parseWeightKg(_kg.text)!,
    );
    if (!mounted) return;
    if (ok) _kg.clear();
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastKg = latestWeighInKg(
      ref.watch(weighInsProvider).value ?? const {},
    );
    return Card(
      key: const Key('quickWeighInCard'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 12),
                child: Icon(
                  Icons.monitor_weight_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: TextFormField(
                  key: const Key('quickWeighInField'),
                  controller: _kg,
                  keyboardType: weightKeyboardType,
                  inputFormatters: const [WeightInputFormatter()],
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    labelText: 'Morning weigh-in',
                    hintText: lastKg == null
                        ? 'e.g. 82.4'
                        : 'Last: ${formatKg(lastKg)}',
                    suffixText: 'kg',
                  ),
                  validator: validateWeightKg,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                  ),
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

/// One-line summary once [dayKey] has a weigh-in, e.g.
/// "82.4 kg · trend 83.1 · −0.3 this week". Tap to edit.
class WeighInSummaryRow extends ConsumerWidget {
  const WeighInSummaryRow({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weighIns = ref.watch(weighInsProvider).value ?? const {};
    final trend = ref.watch(weightTrendProvider).value ?? const [];
    final line = weighInSummaryLine(weighIns, trend, dayKey);
    if (line == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const Key('weighInSummaryRow'),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.monitor_weight_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(line),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => openWeighInDialog(context, ref, dayKey: dayKey),
      ),
    );
  }
}
