// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
// Weight tab: trend summary, trend chart with range chips, and the list of
// weigh-ins with add, edit and delete (with undo).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../domain/models.dart';
import '../targets/targets_providers.dart';
import 'weigh_in_actions.dart';
import 'weight_logic.dart';
import 'weight_providers.dart';
import 'widgets/weigh_in_dialog.dart';
import 'widgets/weight_chart.dart';

/// Chart range choices on the Weight screen; [days] is null for all data.
enum WeightRange {
  d30('30 d', 30),
  d90('90 d', 90),
  all('All', null);

  const WeightRange(this.label, this.days);
  final String label;
  final int? days;
}

/// Selected chart range on the Weight screen (defaults to 30 days).
final weightRangeProvider = NotifierProvider<WeightRangeNotifier, WeightRange>(
  WeightRangeNotifier.new,
);

/// Holds the selected [WeightRange].
class WeightRangeNotifier extends Notifier<WeightRange> {
  @override
  WeightRange build() => WeightRange.d30;

  void set(WeightRange range) => state = range;
}

/// How many weigh-ins the history shows before "Show all".
const kWeighInHistoryPreview = 14;

/// Weight tab: trend weight, 7/30-day change, chart and weigh-in list.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  String _today(WidgetRef ref) => dayKeyOf(ref.read(clockProvider)());

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String dayKey,
    double kg,
  ) async {
    final repo = ref.read(weightRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final label = formatDayLong(dayKey, _today(ref));
    try {
      await repo.delete(dayKey);
    } catch (e, st) {
      debugPrint('Deleting weigh-in failed: $e\n$st');
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't delete that weigh-in.")),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted weigh-in for $label'),
          persist: false,
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
    final goalKg = ref.watch(profileProvider).value?.goalWeightKg;
    final today = _today(ref);
    final hasToday = weighIns.value?.containsKey(today) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Weight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openWeighInDialog(context, ref),
        icon: Icon(hasToday ? Icons.edit_outlined : Icons.add),
        label: Text(hasToday ? 'Update today' : 'Weigh-in'),
      ),
      body: switch ((weighIns.value, trend.value)) {
        (final map?, final points?) => _WeightBody(
          weighIns: map,
          trend: points,
          range: range,
          today: today,
          goalKg: goalKg,
          onRange: ref.read(weightRangeProvider.notifier).set,
          onAdd: () => openWeighInDialog(context, ref),
          onEdit: (day) => openWeighInDialog(context, ref, dayKey: day),
          onDelete: (day, kg) => _delete(context, ref, day, kg),
        ),
        _ when weighIns.hasError || trend.hasError => _LoadError(
          error: weighIns.error ?? trend.error,
          onRetry: () => ref.invalidate(weighInsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Short error message with a retry button; details go to the log.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    debugPrint('Weight screen failed to load: $error');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load your weigh-ins."),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Screen content once weigh-ins and trend have loaded.
class _WeightBody extends StatefulWidget {
  const _WeightBody({
    required this.weighIns,
    required this.trend,
    required this.range,
    required this.today,
    required this.goalKg,
    required this.onRange,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, double> weighIns;
  final List<TrendPoint> trend;
  final WeightRange range;
  final String today;
  final double? goalKg;
  final ValueChanged<WeightRange> onRange;
  final VoidCallback onAdd;
  final void Function(String dayKey) onEdit;
  final void Function(String dayKey, double kg) onDelete;

  @override
  State<_WeightBody> createState() => _WeightBodyState();
}

class _WeightBodyState extends State<_WeightBody> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = (widget.weighIns.keys.toList()..sort()).reversed.toList();
    final rangeDays = widget.range.days;
    final visible = trendSince(
      widget.trend,
      rangeDays == null ? null : addDays(widget.today, -(rangeDays - 1)),
    );
    final shown = _showAll || days.length <= kWeighInHistoryPreview
        ? days.length
        : kWeighInHistoryPreview;
    final hidden = days.length - shown;

    final header = <Widget>[
      _SummaryCard(trend: widget.trend, goalKg: widget.goalKg),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: widget.weighIns.length < 2
              ? ChartEmptyState(
                  key: const Key('weightChartEmpty'),
                  height: 200,
                  message: 'Your trend appears after a few weigh-ins',
                  action: FilledButton.tonalIcon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add weigh-in'),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final r in WeightRange.values)
                          ChoiceChip(
                            label: Text(r.label),
                            selected: r == widget.range,
                            onSelected: (_) => widget.onRange(r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WeightChart(points: visible, goalKg: widget.goalKg),
                    const SizedBox(height: 4),
                    _Legend(showGoal: widget.goalKg != null),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text('Weigh-ins', style: theme.textTheme.titleMedium),
      ),
      if (days.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('No weigh-ins yet'),
            subtitle: const Text('Weigh yourself in the morning, then add it.'),
            trailing: FilledButton.tonal(
              onPressed: widget.onAdd,
              child: const Text('Add'),
            ),
          ),
        ),
    ];

    // The history is built lazily: only rows on screen are created.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: header.length + shown + (hidden > 0 ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final index = i - header.length;
        if (index == shown) {
          return Center(
            child: TextButton(
              key: const Key('showAllWeighIns'),
              onPressed: () => setState(() => _showAll = true),
              child: Text('Show all ($hidden more)'),
            ),
          );
        }
        final day = days[index];
        return _WeighInRow(
          dayKey: day,
          kg: widget.weighIns[day]!,
          changeKg: changeVsPreviousKg(widget.weighIns, day),
          today: widget.today,
          onEdit: () => widget.onEdit(day),
          onDelete: () => widget.onDelete(day, widget.weighIns[day]!),
        );
      },
    );
  }
}

/// One weigh-in: weight, day and change vs the previous weigh-in. Tap edits.
class _WeighInRow extends StatelessWidget {
  const _WeighInRow({
    required this.dayKey,
    required this.kg,
    required this.changeKg,
    required this.today,
    required this.onEdit,
    required this.onDelete,
  });

  final String dayKey;
  final double kg;
  final double? changeKg;
  final String today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = changeKg;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('weighIn-$dayKey'),
        title: Text('${formatKg(kg)} kg'),
        subtitle: Text(formatDayLong(dayKey, today)),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (change != null)
              Text(
                formatChangeKg(change),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Current trend weight, its 7- and 30-day change and distance to the goal.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.trend, required this.goalKg});

  final List<TrendPoint> trend;
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final current = trend.isEmpty ? null : trend.last.trendKg;
    final toGoal = toGoalText(current, goalKg);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trend weight', style: theme.textTheme.labelMedium),
                      Text(
                        current == null ? '–' : '${formatKg(current)} kg',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                change('7 days', trendChangeKg(trend, 7)),
                change('30 days', trendChangeKg(trend, 30)),
              ],
            ),
            if (toGoal != null) ...[
              const SizedBox(height: 4),
              Text(
                toGoal,
                key: const Key('toGoal'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Trend weight smooths out daily ups and downs from water and '
              'food, so it shows where you are really heading.',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showGoal});

  final bool showGoal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      children: [
        _item(
          Container(width: 16, height: 3, color: scheme.primary),
          'Trend',
          style,
        ),
        _item(
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          'Weigh-in',
          style,
        ),
        if (showGoal)
          _item(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 4,
                    height: 2,
                    margin: const EdgeInsets.only(right: 2),
                    color: scheme.secondary,
                  ),
              ],
            ),
            'Goal',
            style,
          ),
      ],
    );
  }

  Widget _item(Widget swatch, String label, TextStyle? style) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 4),
      Text(label, style: style),
    ],
  );
}
