// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../domain/models.dart';
import 'weight_logic.dart';
import 'weight_providers.dart';
import 'widgets/weigh_in_dialog.dart';
import 'widgets/weight_chart.dart';

enum WeightRange {
  d30('30 d', 30),
  d90('90 d', 90),
  all('All', null);

  const WeightRange(this.label, this.days);
  final String label;
  final int? days;
}

final weightRangeProvider = NotifierProvider<WeightRangeNotifier, WeightRange>(
  WeightRangeNotifier.new,
);

class WeightRangeNotifier extends Notifier<WeightRange> {
  @override
  WeightRange build() => WeightRange.d30;

  void set(WeightRange range) => state = range;
}

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  String _today(WidgetRef ref) => dayKeyOf(ref.read(clockProvider)());

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final input = await showWeighInDialog(context, today: _today(ref));
    if (input == null) return;
    await ref
        .read(weightRepositoryProvider)
        .upsert(input.dayKey, input.weightKg);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    String dayKey,
    double kg,
  ) async {
    final input = await showWeighInDialog(
      context,
      today: _today(ref),
      initialDayKey: dayKey,
      initialKg: kg,
    );
    if (input == null) return;
    await ref
        .read(weightRepositoryProvider)
        .replace(dayKey, input.dayKey, input.weightKg);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String dayKey,
    double kg,
  ) async {
    final repo = ref.read(weightRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final label = formatDayLong(dayKey, _today(ref));
    await repo.delete(dayKey);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted weigh-in for $label'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.upsert(dayKey, kg),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weighIns = ref.watch(weighInsProvider);
    final trend = ref.watch(weightTrendProvider);
    final range = ref.watch(weightRangeProvider);
    final today = _today(ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Weight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Weigh-in'),
      ),
      body: switch ((weighIns.value, trend.value)) {
        (final map?, final points?) => _WeightBody(
          weighIns: map,
          trend: points,
          range: range,
          today: today,
          onRange: ref.read(weightRangeProvider.notifier).set,
          onEdit: (day, kg) => _edit(context, ref, day, kg),
          onDelete: (day, kg) => _delete(context, ref, day, kg),
        ),
        _ when weighIns.hasError || trend.hasError => Center(
          child: Text(
            'Could not load weigh-ins: ${weighIns.error ?? trend.error}',
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _WeightBody extends StatelessWidget {
  const _WeightBody({
    required this.weighIns,
    required this.trend,
    required this.range,
    required this.today,
    required this.onRange,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, double> weighIns;
  final List<TrendPoint> trend;
  final WeightRange range;
  final String today;
  final ValueChanged<WeightRange> onRange;
  final void Function(String dayKey, double kg) onEdit;
  final void Function(String dayKey, double kg) onDelete;

  @override
  Widget build(BuildContext context) {
    final entries = weighIns.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final days = range.days;
    final visible = trendSince(
      trend,
      days == null ? null : addDays(today, -(days - 1)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        _SummaryCard(trend: trend),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in WeightRange.values)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: r == range,
                        onSelected: (_) => onRange(r),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                WeightChart(points: visible),
                const SizedBox(height: 4),
                const _Legend(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Weigh-ins',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (entries.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.monitor_weight_outlined),
              title: Text('No weigh-ins yet'),
              subtitle: Text('Tap "Weigh-in" to add your first one.'),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final e in entries)
                  ListTile(
                    key: ValueKey('weighIn-${e.key}'),
                    title: Text('${e.value.toStringAsFixed(1)} kg'),
                    subtitle: Text(formatDayLong(e.key, today)),
                    onTap: () => onEdit(e.key, e.value),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => onEdit(e.key, e.value),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDelete(e.key, e.value),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.trend});

  final List<TrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = trend.isEmpty ? null : trend.last.trendKg;
    Widget change(String label, double? kg) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            kg == null ? '–' : formatChangeKg(kg),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trend weight', style: theme.textTheme.labelMedium),
                  Text(
                    current == null ? '–' : '${current.toStringAsFixed(1)} kg',
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            change('7 days', trendChangeKg(trend, 7)),
            change('30 days', trendChangeKg(trend, 30)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 16, height: 3, color: scheme.primary),
        const SizedBox(width: 4),
        Text('Trend', style: style),
        const SizedBox(width: 16),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scheme.tertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Weigh-in', style: style),
      ],
    );
  }
}
