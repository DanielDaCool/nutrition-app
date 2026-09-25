// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
// Dashboard tab: weight trend, weekly intake vs. target, steps, workouts per
// week and maintenance estimate over the selected range.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day_key.dart';
import '../activity/activity_providers.dart';
import '../food/food_providers.dart';
import '../weight/weight_logic.dart';
import '../weight/weight_providers.dart';
import '../weight/widgets/weight_chart.dart';
import 'dashboard_logic.dart';
import 'dashboard_providers.dart';

/// Range chips plus one chart card per section for [dashboardWindowProvider].
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardRangeProvider);
    final window = ref.watch(dashboardWindowProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final r in DashboardRange.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: r == range,
                  onSelected: (_) =>
                      ref.read(dashboardRangeProvider.notifier).set(r),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...switch (window.value) {
            final w? => [
              _WeightSection(window: w),
              _IntakeSection(window: w),
              _StepsSection(window: w),
              _WorkoutsSection(window: w),
              _MaintenanceSection(window: w),
            ],
            null when window.hasError => [_ErrorText(window.error!)],
            null => const [
              SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ],
      ),
    );
  }
}

/// Inclusive (from, to) day keys.
typedef _Window = (String from, String to);

/// Card with a title, optional subtitle, chart and optional legend.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.legend,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            child,
            if (legend != null) ...[const SizedBox(height: 4), legend!],
          ],
        ),
      ),
    );
  }
}

/// Renders loading / error for [value], or [builder] once data exists.
Widget _async<T>(AsyncValue<T> value, Widget Function(T data) builder) {
  final data = value.value;
  if (data != null) return builder(data);
  if (value.hasError) return _ErrorText(value.error!);
  return const SizedBox(
    height: 160,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(
      child: Text(
        'Could not load data: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

class _WeightSection extends ConsumerWidget {
  const _WeightSection({required this.window});
  final _Window window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(weightTrendProvider);
    return _Section(
      title: 'Weight trend',
      child: _async(
        trend,
        (points) => WeightChart(
          points: trendSince(points, window.$1),
          showWeighIns: false,
          height: 200,
        ),
      ),
    );
  }
}

class _IntakeSection extends ConsumerWidget {
  const _IntakeSection({required this.window});
  final _Window window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final intake = ref.watch(intakeRangeProvider(window));
    final targets = ref.watch(targetHistoryProvider);
    return _Section(
      title: 'Average intake per week',
      subtitle: 'Fully logged days only, vs. the target that week',
      legend: _Legend(
        items: [('Intake', scheme.primary), ('Target', scheme.outline)],
      ),
      child: _async(intake, (days) {
        return _async(targets, (targetPoints) {
          final weeks = weeklyIntake(days, targetPoints);
          if (weeks.every((w) => w.avgKcal == null)) {
            return const ChartEmptyState(
              icon: Icons.restaurant_outlined,
              message:
                  'No fully logged days in this range.\n'
                  'Mark a day as fully logged to see it here.',
            );
          }
          return _WeekBars(
            weekStarts: [for (final w in weeks) w.weekStart],
            series: [
              [for (final w in weeks) w.avgKcal],
              [for (final w in weeks) w.targetKcal],
            ],
            colors: [scheme.primary, scheme.outline],
            unit: 'kcal/day',
            tooltip: (week, series, value) =>
                '${series == 0 ? 'Intake' : 'Target'} ${value.round()} kcal'
                '${series == 0 ? '\n${weeks[week].loggedDays} logged days' : ''}',
          );
        });
      }),
    );
  }
}

class _StepsSection extends ConsumerWidget {
  const _StepsSection({required this.window});
  final _Window window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activity = ref.watch(activityRangeProvider(window));
    return _Section(
      title: 'Steps per day',
      legend: _Legend(
        items: [
          ('Steps', scheme.primary.withValues(alpha: 0.5)),
          ('7-day average', scheme.tertiary),
        ],
      ),
      child: _async(activity, (days) {
        if (!hasAnySteps(days)) {
          return const ChartEmptyState(
            icon: Icons.directions_walk,
            message:
                'No step data in this range.\n'
                'Connect Health Connect in Settings.',
          );
        }
        return _StepsChart(days: stepsWithAverage(days));
      }),
    );
  }
}

/// Daily step bars with the 7-day average line; x = day index in [days].
class _StepsChart extends StatelessWidget {
  const _StepsChart({required this.days});
  final List<StepsDay> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = _labelStyle(context);
    final first = days.first.dayKey;
    var maxSteps = 0.0;
    for (final d in days) {
      maxSteps = math.max(maxSteps, (d.steps ?? 0).toDouble());
    }
    final maxY = _niceMax(maxSteps);
    final n = days.length;
    return SizedBox(
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Bars are drawn as thick vertical line segments, so they can share
          // one LineChart with the average line (fl_chart can't mix chart types).
          final plotWidth = math.max(1.0, constraints.maxWidth - 60);
          final barWidth = (plotWidth / n * 0.7).clamp(1.0, 14.0);
          return Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: LineChart(
              LineChartData(
                minX: -0.5,
                maxX: n - 0.5,
                minY: 0,
                maxY: maxY,
                lineTouchData: const LineTouchData(enabled: false),
                borderData: FlBorderData(show: false),
                gridData: _grid(scheme, maxY / 4),
                titlesData: _titles(
                  labelStyle: labelStyle,
                  unit: 'steps',
                  yInterval: maxY / 4,
                  yLabel: (v) => v >= 1000
                      ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
                      : v.round().toString(),
                  xInterval: math.max(1.0, (n / 4).ceilToDouble()),
                  xLabel: (v) {
                    final i = v.round();
                    if (i < 0 || i >= n || (v - i).abs() > 0.01) return '';
                    return shortDateLabel(addDays(first, i));
                  },
                ),
                lineBarsData: [
                  for (var i = 0; i < n; i++)
                    if ((days[i].steps ?? 0) > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(i.toDouble(), 0),
                          FlSpot(i.toDouble(), days[i].steps!.toDouble()),
                        ],
                        color: scheme.primary.withValues(alpha: 0.5),
                        barWidth: barWidth,
                        dotData: const FlDotData(show: false),
                      ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < n; i++)
                        if (days[i].avg7 != null)
                          FlSpot(i.toDouble(), days[i].avg7!)
                        else
                          FlSpot.nullSpot,
                    ],
                    color: scheme.tertiary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorkoutsSection extends ConsumerWidget {
  const _WorkoutsSection({required this.window});
  final _Window window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activity = ref.watch(activityRangeProvider(window));
    return _Section(
      title: 'Workouts per week',
      child: _async(activity, (days) {
        final weeks = workoutsPerWeek(days);
        if (weeks.every((w) => w.count == 0)) {
          return const ChartEmptyState(
            icon: Icons.fitness_center,
            message: 'No workouts in this range',
          );
        }
        return _WeekBars(
          weekStarts: [for (final w in weeks) w.weekStart],
          series: [
            [for (final w in weeks) w.count.toDouble()],
          ],
          colors: [scheme.secondary],
          unit: 'workouts',
          integerAxis: true,
          tooltip: (week, series, value) =>
              '${value.round()} workout${value.round() == 1 ? '' : 's'}',
        );
      }),
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  const _MaintenanceSection({required this.window});
  final _Window window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetHistoryProvider);
    return _Section(
      title: 'Maintenance estimate',
      subtitle: 'Calories to keep your weight stable, from each check-in',
      child: _async(targets, (points) {
        final series = maintenanceSeries(points, window.$1, window.$2);
        if (series.isEmpty) {
          return const ChartEmptyState(
            icon: Icons.local_fire_department_outlined,
            message:
                'No maintenance estimate yet.\n'
                'It appears once your targets are set up.',
          );
        }
        return _MaintenanceChart(series: series, from: window.$1);
      }),
    );
  }
}

/// Step line of maintenance kcal; x = days since [from].
class _MaintenanceChart extends StatelessWidget {
  const _MaintenanceChart({required this.series, required this.from});
  final List<MaintenancePoint> series;
  final String from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = _labelStyle(context);
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in series) {
      minY = math.min(minY, p.kcal);
      maxY = math.max(maxY, p.kcal);
    }
    minY = ((minY - 100) / 100).floorToDouble() * 100;
    maxY = ((maxY + 100) / 100).ceilToDouble() * 100;
    final yInterval = _niceMax(maxY - minY) / 4;
    final maxX = math.max(
      1.0,
      daysBetween(from, series.last.dayKey).toDouble(),
    );
    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 8),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: _grid(scheme, yInterval),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.y.round()} kcal\n'
                      '${shortDateLabel(addDays(from, s.x.round()))}',
                      TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                    ),
                ],
              ),
            ),
            titlesData: _titles(
              labelStyle: labelStyle,
              unit: 'kcal/day',
              yInterval: yInterval,
              yLabel: (v) => v.round().toString(),
              xInterval: math.max(1.0, (maxX / 4).ceilToDouble()),
              xLabel: (v) => shortDateLabel(addDays(from, v.round())),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final p in series)
                    FlSpot(daysBetween(from, p.dayKey).toDouble(), p.kcal),
                ],
                isStepLineChart: true,
                lineChartStepData: const LineChartStepData(
                  stepDirection: LineChartStepData.stepDirectionForward,
                ),
                color: scheme.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped bars per week; [series] values may be null (no bar).
class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.weekStarts,
    required this.series,
    required this.colors,
    required this.unit,
    required this.tooltip,
    this.integerAxis = false,
  });

  final List<String> weekStarts;
  final List<List<double?>> series;
  final List<Color> colors;
  final String unit;
  /// Tooltip text for a bar (week index, series index, value).
  final String Function(int week, int series, double value) tooltip;
  /// Use whole-number y steps (for counts).
  final bool integerAxis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = _labelStyle(context);
    final n = weekStarts.length;
    var maxV = 0.0;
    for (final s in series) {
      for (final v in s) {
        if (v != null) maxV = math.max(maxV, v);
      }
    }
    final maxY = integerAxis
        ? math.max(4.0, maxV.ceilToDouble())
        : _niceMax(maxV);
    final yInterval = integerAxis
        ? math.max(1.0, (maxY / 4).ceilToDouble())
        : maxY / 4;
    final labelEvery = math.max(1, (n / 6).ceil());
    return SizedBox(
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = math.max(1.0, constraints.maxWidth - 60);
          final rodWidth = (plotWidth / n / series.length * 0.6).clamp(
            2.0,
            16.0,
          );
          return Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: _grid(scheme, yInterval),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final v = series[rodIndex][groupIndex];
                      if (v == null) return null;
                      return BarTooltipItem(
                        '${shortDateLabel(weekStarts[groupIndex])}\n'
                        '${tooltip(groupIndex, rodIndex, v)}',
                        TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: _titles(
                  labelStyle: labelStyle,
                  unit: unit,
                  yInterval: yInterval,
                  yLabel: (v) => v.round().toString(),
                  xLabel: (v) {
                    final i = v.round();
                    if (i < 0 || i >= n || i % labelEvery != 0) return '';
                    return shortDateLabel(weekStarts[i]);
                  },
                  bottomName: 'week of',
                ),
                barGroups: [
                  for (var i = 0; i < n; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 2,
                      barRods: [
                        for (var s = 0; s < series.length; s++)
                          BarChartRodData(
                            toY: series[s][i] ?? 0,
                            color: series[s][i] == null
                                ? Colors.transparent
                                : colors[s],
                            width: rodWidth,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}

TextStyle? _labelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

FlGridData _grid(ColorScheme scheme, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval > 0 ? interval : null,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
);

/// Shared axis titles: [unit] on the left axis, [xLabel] along the bottom.
FlTitlesData _titles({
  required TextStyle? labelStyle,
  required String unit,
  required double yInterval,
  required String Function(double) yLabel,
  required String Function(double) xLabel,
  double? xInterval,
  String? bottomName,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      axisNameWidget: Text(unit, style: labelStyle),
      axisNameSize: 18,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: yInterval > 0 ? yInterval : null,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            yLabel(value),
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      axisNameWidget: bottomName == null
          ? null
          : Text(bottomName, style: labelStyle),
      axisNameSize: bottomName == null ? 0 : 16,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: xInterval,
        // The last date label would sit on the right edge and get clipped.
        maxIncluded: false,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(
            xLabel(value),
            style: labelStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    ),
  );
}

/// Rounds [v] up to a value that divides nicely into 4 grid steps.
double _niceMax(double v) {
  if (v <= 0) return 4;
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in [1.0, 2.0, 2.5, 4.0, 5.0, 8.0, 10.0]) {
    if (m * magnitude >= v) return m * magnitude;
  }
  return 10 * magnitude;
}
