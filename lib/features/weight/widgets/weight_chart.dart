// Weight trend line chart, shared with the dashboard, plus small chart
// helpers ([shortDateLabel], [ChartEmptyState]).
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../weight_logic.dart';

/// Trend line with optional raw weigh-ins as dots and an optional dashed goal
/// line. x = days since first point.
class WeightChart extends StatelessWidget {
  const WeightChart({
    super.key,
    required this.points,
    this.showWeighIns = true,
    this.height = 220,
    this.goalKg,
  });

  final List<TrendPoint> points;

  /// Draw the raw scale weights as dots next to the trend line.
  final bool showWeighIns;
  final double height;

  /// Goal weight drawn as a dashed, labelled line (null = none).
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (points.isEmpty) {
      return ChartEmptyState(
        height: height,
        message: 'No weigh-ins in this range yet',
      );
    }
    final first = points.first.dayKey;
    final trendSpots = <FlSpot>[];
    final scaleSpots = <FlSpot>[];
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final p in points) {
      final x = daysBetween(first, p.dayKey).toDouble();
      trendSpots.add(FlSpot(x, p.trendKg));
      minY = math.min(minY, p.trendKg);
      maxY = math.max(maxY, p.trendKg);
      final s = p.scaleKg;
      if (showWeighIns && s != null) {
        scaleSpots.add(FlSpot(x, s));
        minY = math.min(minY, s);
        maxY = math.max(maxY, s);
      }
    }
    final goal = goalKg;
    if (goal != null) {
      minY = math.min(minY, goal);
      maxY = math.max(maxY, goal);
    }
    minY = (minY - 0.5).floorToDouble();
    maxY = (maxY + 0.5).ceilToDouble();
    final maxX = math.max(1.0, trendSpots.last.x);
    final xInterval = math.max(1.0, (maxX / 4).ceilToDouble());
    final yInterval = _niceInterval(maxY - minY);

    final labelStyle = textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 8),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: scheme.outlineVariant, strokeWidth: 1),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (goal != null)
                  HorizontalLine(
                    y: goal,
                    color: scheme.secondary,
                    strokeWidth: 1.5,
                    dashArray: const [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.secondary,
                      ),
                      labelResolver: (_) => goalLabel(goal),
                    ),
                  ),
              ],
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                axisNameWidget: Text('kg', style: labelStyle),
                axisNameSize: 18,
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toStringAsFixed(yInterval < 1 ? 1 : 0),
                      style: labelStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: xInterval,
                  // The last date label would sit on the edge and get clipped.
                  maxIncluded: false,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      shortDateLabel(addDays(first, value.round())),
                      style: labelStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? 'Trend' : 'Scale'} '
                      '${s.y.toStringAsFixed(1)} kg\n'
                      '${shortDateLabel(addDays(first, s.x.round()))}',
                      TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: trendSpots,
                color: scheme.primary,
                barWidth: 3,
                isCurved: false,
                dotData: const FlDotData(show: false),
              ),
              if (scaleSpots.isNotEmpty)
                LineChartBarData(
                  spots: scaleSpots,
                  color: Colors.transparent,
                  barWidth: 0,
                  dotData: FlDotData(
                    getDotPainter: (spot, xPct, bar, index) =>
                        FlDotCirclePainter(
                          radius: 4.5,
                          color: scheme.tertiary,
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

/// Y grid step (kg) that gives a handful of lines for a [span] kg range.
double _niceInterval(double span) {
  if (span <= 2) return 0.5;
  if (span <= 5) return 1;
  if (span <= 12) return 2;
  if (span <= 30) return 5;
  return 10;
}

/// "25 Sep".
String shortDateLabel(String dayKey) =>
    DateFormat('d MMM').format(startOfDay(dayKey));

/// Placeholder shown instead of a chart that has no data, with an optional
/// button that fixes it.
class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({
    super.key,
    required this.message,
    this.height = 160,
    this.icon = Icons.show_chart,
    this.action,
  });

  final String message;
  final double height;
  final IconData icon;

  /// E.g. a button that adds the missing data.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: scheme.onSurfaceVariant, size: 32),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
