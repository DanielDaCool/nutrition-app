// Weight trend smoothing (time-based exponential moving average of weigh-ins).
// Pure Dart: shared by the weight screens and the calorie engine.

import 'dart:math' as math;

import '../core/day_key.dart';
import 'models.dart';

/// Smoothing factor per day for the weight trend (exponential moving average).
/// 0.1 is the classic "Hacker's Diet" value: about a 10-day smoothing window.
/// A weigh-in after a gap of d days moves the trend by `1 - (1 - alpha)^d`, so
/// the smoothing window is measured in days, not in readings: weighing 2-3
/// times a week tracks the same trend as weighing daily, just from fewer points.
const double kTrendAlpha = 0.1;

/// Builds a daily weight trend from raw weigh-ins.
///
/// [weighIns] maps day key -> scale weight (kg). Returns one point per calendar
/// day from the first weigh-in to [until] (defaults to the last weigh-in).
/// Days without a weigh-in carry the previous trend forward unchanged, and the
/// next weigh-in is weighted by the days since the previous one (see
/// [kTrendAlpha]); with a weigh-in every day this is the plain EMA.
List<TrendPoint> computeTrend(
  Map<String, double> weighIns, {
  String? until,
  double alpha = kTrendAlpha,
}) {
  // Weigh-ins after [until] are out of range: don't let a future-dated
  // weigh-in (e.g. a day-key mistake, or travel across the date line) move
  // the trend's end point past what the caller asked for.
  final inRange = until == null
      ? weighIns
      : {
          for (final e in weighIns.entries)
            if (e.key.compareTo(until) <= 0) e.key: e.value,
        };
  if (inRange.isEmpty) return const [];
  final days = inRange.keys.toList()..sort();
  final first = days.first;
  var last = days.last;
  if (until != null && until.compareTo(last) > 0) last = until;

  final points = <TrendPoint>[];
  double? trend;
  var daysSinceWeighIn = 0;
  for (var day = first; day.compareTo(last) <= 0; day = addDays(day, 1)) {
    final scale = inRange[day];
    daysSinceWeighIn++;
    if (scale != null) {
      if (trend == null) {
        trend = scale;
      } else {
        final weight = 1 - math.pow(1 - alpha, daysSinceWeighIn);
        trend = trend + weight * (scale - trend);
      }
      daysSinceWeighIn = 0;
    }
    points.add(TrendPoint(dayKey: day, trendKg: trend!, scaleKg: scale));
  }
  return points;
}
