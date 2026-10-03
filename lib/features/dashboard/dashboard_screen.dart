// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
// Dashboard tab: weight trend, weekly intake vs. target, steps, workouts per
// week and maintenance estimate over the selected range.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/day_key.dart';
import '../activity/activity_providers.dart';
import '../food/food_providers.dart';
import '../settings/settings_screen.dart';
import '../targets/targets_providers.dart';
import '../weight/weigh_in_actions.dart';
import '../weight/weight_logic.dart';
import '../weight/weight_providers.dart';
import '../weight/widgets/weight_chart.dart';
import 'dashboard_logic.dart';
import 'dashboard_providers.dart';

/// Range chips plus one chart card per section for [dashboardWindowProvider].
///
/// Until the profile and a first weigh-in exist, a "Finish setup" card sits
/// on top and sections without data are left out. Pull down to refresh
/// (also syncs Health Connect).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(earliestDataDayProvider);
    ref.invalidate(dashboardWindowProvider);
    ref.invalidate(weightTrendProvider);
    // No Health Connect on web.
    if (ref.read(isWebProvider)) return;
    try {
      await ref.read(healthSyncProvider.notifier).syncNow();
    } catch (e) {
      debugPrint('Dashboard refresh sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardRangeProvider);
    final window = ref.watch(dashboardWindowProvider);
    final profile = ref.watch(profileProvider);
    final weighIns = ref.watch(weighInsProvider);
    final needsProfile = profile.hasValue && profile.value == null;
    final needsWeighIn = weighIns.hasValue && weighIns.value!.isEmpty;
    final setupIncomplete = needsProfile || needsWeighIn;
    // Steps and workouts come from Health Connect (and the Today activity
    // card, which web also hides), so web has no data for these charts: the
    // feature gate is off there.
    final showActivity = ref.watch(featureEnabledProvider(AppFeature.activity));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            if (setupIncomplete)
              _FinishSetupCard(
                needsProfile: needsProfile,
                needsWeighIn: needsWeighIn,
              ),
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
                _WeightSection(window: w, hideWhenEmpty: setupIncomplete),
                _IntakeSection(window: w, hideWhenEmpty: setupIncomplete),
                if (showActivity) ...[
                  _StepsSection(window: w, hideWhenEmpty: setupIncomplete),
                  _WorkoutsSection(window: w, hideWhenEmpty: setupIncomplete),
                ],
                _MaintenanceSection(window: w, hideWhenEmpty: setupIncomplete),
              ],
              null when window.hasError => [
                _ErrorText(
                  window.error!,
                  onRetry: () => ref.invalidate(dashboardWindowProvider),
                ),
              ],
              null => const [
                SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// Inclusive (from, to) day keys.
typedef _Window = (String from, String to);

void _openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// What's missing before the charts can show anything useful.
class _FinishSetupCard extends ConsumerWidget {
  const _FinishSetupCard({
    required this.needsProfile,
    required this.needsWeighIn,
  });

  final bool needsProfile;
  final bool needsWeighIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget step({
      required bool done,
      required String title,
      required String subtitle,
      required String button,
      required VoidCallback onPressed,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: done
          ? null
          : FilledButton(onPressed: onPressed, child: Text(button)),
    );

    return Card(
      key: const Key('finishSetupCard'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finish setup', style: theme.textTheme.titleLarge),
            Text(
              'Two quick steps and your charts fill in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            step(
              done: !needsProfile,
              title: 'Set up your profile',
              subtitle: 'Height, goal weight and activity',
              button: 'Open',
              onPressed: () => _openSettings(context),
            ),
            step(
              done: !needsWeighIn,
              title: 'Add your first weigh-in',
              subtitle: 'Morning, before breakfast',
              button: 'Add',
              onPressed: () => openWeighInDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a title, optional headline number, subtitle, chart and legend.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.headline,
    this.subtitle,
    this.legend,
  });

  final String title;
  final String? headline;
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
            if (headline != null)
              Text(
                headline!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

/// Loading / error placeholder for a section whose data isn't ready.
Widget? _pending(AsyncValue<Object?> value, VoidCallback onRetry) {
  if (value.hasValue) return null;
  if (value.hasError) return _ErrorText(value.error!, onRetry: onRetry);
  return const SizedBox(
    height: 160,
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Short friendly error with Try again; the details go to the log.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error, {required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    debugPrint('Dashboard failed to load: $error');
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load this chart.",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightSection extends ConsumerWidget {
  const _WeightSection({required this.window, required this.hideWhenEmpty});
  final _Window window;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(weightTrendProvider);
    final goalKg = ref.watch(profileProvider).value?.goalWeightKg;
    final count = ref.watch(weighInsProvider).value?.length ?? 0;
    final pending = _pending(trend, () => ref.invalidate(weighInsProvider));
    if (pending != null) return _Section(title: 'Weight', child: pending);

    final points = trendSince(trend.value!, window.$1);
    if (points.isEmpty && hideWhenEmpty) return const SizedBox.shrink();
    final addButton = FilledButton.tonalIcon(
      onPressed: () => openWeighInDialog(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Add weigh-in'),
    );
    return _Section(
      title: 'Weight',
      headline: weightHeadline(points),
      child: count < 2
          ? ChartEmptyState(
              message: 'Your trend appears after a few weigh-ins',
              action: addButton,
            )
          : points.isEmpty
          ? ChartEmptyState(
              message: 'No weigh-ins in this range yet',
              action: addButton,
            )
          : WeightChart(
              points: points,
              showWeighIns: false,
              height: 200,
              goalKg: goalKg,
            ),
    );
  }
}

class _IntakeSection extends ConsumerWidget {
  const _IntakeSection({required this.window, required this.hideWhenEmpty});
  final _Window window;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final intake = ref.watch(intakeRangeProvider(window));
    final targets = ref.watch(targetHistoryProvider);
    const title = 'Average intake per week';
    final pending =
        _pending(intake, () => ref.invalidate(intakeRangeProvider(window))) ??
        _pending(targets, () => ref.invalidate(targetHistoryProvider));
    if (pending != null) return _Section(title: title, child: pending);

    final days = intake.value!;
    final targetPoints = targets.value!;
    final weeks = weeklyIntake(days, targetPoints);
    final empty = weeks.every((w) => w.avgKcal == null);
    if (empty && hideWhenEmpty) return const SizedBox.shrink();
    return _Section(
      title: title,
      headline: intakeHeadline(days, targetPoints),
      subtitle: 'Fully logged days only, vs. the target that week',
      legend: empty
          ? null
          : _Legend(
              items: [('Intake', scheme.primary), ('Target', scheme.tertiary)],
            ),
      child: empty
          ? const ChartEmptyState(
              icon: Icons.restaurant_outlined,
              message:
                  'No fully logged days in this range.\n'
                  'Mark a day as complete on Today to see it here.',
            )
          : _WeekBars(
              weekStarts: [for (final w in weeks) w.weekStart],
              series: [
                [for (final w in weeks) w.avgKcal],
                [for (final w in weeks) w.targetKcal],
              ],
              colors: [scheme.primary, scheme.tertiary],
              unit: 'kcal/day',
              tooltip: (week, series, value) =>
                  '${series == 0 ? 'Intake' : 'Target'} ${value.round()} kcal'
                  '${series == 0 ? '\n${weeks[week].loggedDays} logged days' : ''}',
            ),
    );
  }
}

class _StepsSection extends ConsumerWidget {
  const _StepsSection({required this.window, required this.hideWhenEmpty});
  final _Window window;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activity = ref.watch(activityRangeProvider(window));
    // A week of lead-in data so the trailing 7-day average is real even on
    // the first day shown; the headline below still uses the narrower
    // `activity` window.
    final avgWindow = (addDays(window.$1, -6), window.$2);
    final avgActivity = ref.watch(activityRangeProvider(avgWindow));
    const title = 'Steps per day';
    final pending =
        _pending(activity, () => ref.invalidate(activityRangeProvider(window))) ??
        _pending(
          avgActivity,
          () => ref.invalidate(activityRangeProvider(avgWindow)),
        );
    if (pending != null) return _Section(title: title, child: pending);

    final days = activity.value!;
    final empty = !hasAnySteps(days);
    if (empty && hideWhenEmpty) return const SizedBox.shrink();
    final connected = ref.watch(healthStatusProvider).kind == HealthStatusKind.ok;
    return _Section(
      title: title,
      headline: stepsHeadline(days),
      legend: empty
          ? null
          : _Legend(
              items: [
                ('Steps', scheme.primary),
                ('7-day average', scheme.tertiary),
              ],
            ),
      child: empty
          ? (connected
                ? const ChartEmptyState(
                    icon: Icons.directions_walk,
                    message: 'No step data in this range yet.',
                  )
                : ChartEmptyState(
                    icon: Icons.directions_walk,
                    message: 'No step data in this range yet.',
                    action: FilledButton.tonalIcon(
                      key: const Key('connectHealthConnect'),
                      onPressed: () =>
                          ref.read(healthSyncProvider.notifier).connect(),
                      icon: const Icon(Icons.favorite_outline),
                      label: const Text('Connect Health Connect'),
                    ),
                  ))
          : _StepsChart(
              days: stepsWithAverage(avgActivity.value!, from: window.$1),
            ),
    );
  }
}

final _stepsFormat = NumberFormat.decimalPattern('en_US');

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
    // Bars drawn so far, in order; the average line comes last.
    final barDays = [
      for (var i = 0; i < n; i++)
        if ((days[i].steps ?? 0) > 0) i,
    ];
    return SizedBox(
      height: 200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Bars are drawn as thick vertical line segments, so they can share
          // one LineChart with the average line (fl_chart can't mix chart types).
          final plotWidth = math.max(1.0, constraints.maxWidth - 60);
          final slot = plotWidth / n;
          final barWidth = (slot * 0.7).clamp(1.0, 14.0);
          return Padding(
            padding: const EdgeInsets.only(right: 12, top: 8),
            child: LineChart(
              LineChartData(
                minX: -0.5,
                maxX: n - 0.5,
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  // Match by x only, so touching anywhere on a bar works.
                  distanceCalculator: (touch, spot) => (touch - spot).dx.abs(),
                  touchSpotThreshold: math.max(4.0, slot / 2),
                  getTouchedSpotIndicator: (bar, indexes) => [
                    for (final _ in indexes)
                      TouchedSpotIndicatorData(
                        FlLine(color: scheme.outline, strokeWidth: 1),
                        const FlDotData(show: false),
                      ),
                  ],
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItems: (spots) {
                      final style = TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 12,
                      );
                      var dayShown = false;
                      return [
                        for (final s in spots)
                          () {
                            final i = s.x.round();
                            if (i < 0 || i >= n) return null;
                            final isAverage = s.barIndex == barDays.length;
                            final lines = <String>[];
                            if (!dayShown) {
                              dayShown = true;
                              lines.add(shortDateLabel(addDays(first, i)));
                              final steps = days[i].steps;
                              if (steps != null) {
                                lines.add(
                                  '${_stepsFormat.format(steps)} steps',
                                );
                              }
                            }
                            if (isAverage) {
                              lines.add(
                                'Avg ${_stepsFormat.format(s.y.round())}',
                              );
                            }
                            if (lines.isEmpty) return null;
                            return LineTooltipItem(lines.join('\n'), style);
                          }(),
                      ];
                    },
                  ),
                ),
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
                  for (final i in barDays)
                    LineChartBarData(
                      spots: [
                        FlSpot(i.toDouble(), 0),
                        FlSpot(i.toDouble(), days[i].steps!.toDouble()),
                      ],
                      color: scheme.primary,
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
                    barWidth: 3,
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
  const _WorkoutsSection({required this.window, required this.hideWhenEmpty});
  final _Window window;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activity = ref.watch(activityRangeProvider(window));
    // Chart buckets need every week to be a full 7 days, so fetch from the
    // Monday on/before `from` (the headline below still uses the narrower
    // `activity` window, whose day count matches the selected range).
    final chartWindow = (weekStartOf(window.$1), window.$2);
    final chartActivity = ref.watch(activityRangeProvider(chartWindow));
    const title = 'Workouts per week';
    final pending =
        _pending(activity, () => ref.invalidate(activityRangeProvider(window))) ??
        _pending(
          chartActivity,
          () => ref.invalidate(activityRangeProvider(chartWindow)),
        );
    if (pending != null) return _Section(title: title, child: pending);

    final days = activity.value!;
    final weeks = workoutsPerWeek(chartActivity.value!);
    final empty = weeks.every((w) => w.count == 0);
    if (empty && hideWhenEmpty) return const SizedBox.shrink();
    return _Section(
      title: title,
      headline: workoutsHeadline(days),
      child: empty
          ? const ChartEmptyState(
              icon: Icons.fitness_center,
              message:
                  'No workouts in this range.\n'
                  'Workouts from Health Connect show up here.',
            )
          : _WeekBars(
              weekStarts: [for (final w in weeks) w.weekStart],
              series: [
                [for (final w in weeks) w.count.toDouble()],
              ],
              colors: [scheme.primary],
              unit: 'workouts',
              integerAxis: true,
              tooltip: (week, series, value) =>
                  '${value.round()} workout${value.round() == 1 ? '' : 's'}',
            ),
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  const _MaintenanceSection({
    required this.window,
    required this.hideWhenEmpty,
  });
  final _Window window;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetHistoryProvider);
    const title = 'Maintenance estimate';
    const subtitle = 'Calories to keep your weight stable, from each check-in';
    final pending = _pending(
      targets,
      () => ref.invalidate(targetHistoryProvider),
    );
    if (pending != null) {
      return _Section(title: title, subtitle: subtitle, child: pending);
    }
    final series = maintenanceSeries(targets.value!, window.$1, window.$2);
    if (series.isEmpty && hideWhenEmpty) return const SizedBox.shrink();
    return _Section(
      title: title,
      headline: maintenanceHeadline(series),
      subtitle: subtitle,
      child: series.isEmpty
          ? ChartEmptyState(
              icon: Icons.local_fire_department_outlined,
              message:
                  'No maintenance estimate yet.\n'
                  'It appears once your profile is set up.',
              action: FilledButton.tonal(
                onPressed: () => _openSettings(context),
                child: const Text('Open settings'),
              ),
            )
          : _MaintenanceChart(series: series, from: window.$1),
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
                barWidth: 3,
                dotData: FlDotData(
                  getDotPainter: (spot, xPct, bar, index) => FlDotCirclePainter(
                    radius: 4,
                    color: scheme.primary,
                    strokeWidth: 1.5,
                    strokeColor: scheme.surface,
                  ),
                ),
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
    final style = Theme.of(context).textTheme.labelMedium;
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
    Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

FlGridData _grid(ColorScheme scheme, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval > 0 ? interval : null,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
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
      axisNameSize: 20,
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
      axisNameSize: bottomName == null ? 0 : 18,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
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
