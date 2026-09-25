// Weight trend smoothing (exponential moving average over daily weigh-ins).
// Pure Dart: shared by the weight screens and the calorie engine.

import '../core/day_key.dart';
import 'models.dart';

/// Smoothing factor for the weight trend (exponential moving average).
/// 0.1 is the classic "Hacker's Diet" value: about a 10-day smoothing window.
const double kTrendAlpha = 0.1;

/// Builds a daily weight trend from raw weigh-ins.
///
/// [weighIns] maps day key -> scale weight (kg). Returns one point per calendar
/// day from the first weigh-in to [until] (defaults to the last weigh-in).
/// Days without a weigh-in carry the previous trend forward unchanged.
List<TrendPoint> computeTrend(
  Map<String, double> weighIns, {
  String? until,
  double alpha = kTrendAlpha,
}) {
  if (weighIns.isEmpty) return const [];
  final days = weighIns.keys.toList()..sort();
  final first = days.first;
  var last = days.last;
  if (until != null && until.compareTo(last) > 0) last = until;

  final points = <TrendPoint>[];
  double? trend;
  for (var day = first; day.compareTo(last) <= 0; day = addDays(day, 1)) {
    final scale = weighIns[day];
    if (scale != null) {
      trend = trend == null ? scale : trend + alpha * (scale - trend);
    }
    points.add(TrendPoint(dayKey: day, trendKg: trend!, scaleKg: scale));
  }
  return points;
}
