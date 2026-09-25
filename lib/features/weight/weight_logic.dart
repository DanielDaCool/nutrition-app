/// Pure weight helpers (no Flutter/DB imports) so they are unit-testable.
library;

import '../../core/day_key.dart';
import '../../domain/models.dart';

/// Lowest weight (kg) accepted from user input.
const double kMinWeightKg = 30;

/// Highest weight (kg) accepted from user input.
const double kMaxWeightKg = 300;

/// Parses user input like "82.4" or "82,4" into kg rounded to one decimal.
/// Returns null when it isn't a number or is outside [kMinWeightKg, kMaxWeightKg].
double? parseWeightKg(String input) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return null;
  final rounded = (value * 10).roundToDouble() / 10;
  if (rounded < kMinWeightKg || rounded > kMaxWeightKg) return null;
  return rounded;
}

/// Validator message for a weight text field, or null when valid.
String? validateWeightKg(String? input) {
  if (input == null || input.trim().isEmpty) return 'Enter a weight';
  if (parseWeightKg(input) == null) {
    return 'Enter a weight between ${kMinWeightKg.round()} and '
        '${kMaxWeightKg.round()} kg';
  }
  return null;
}

/// Change of the trend over the last [days] days: latest trend minus the trend
/// [days] days before the latest point. Null when the trend doesn't reach back
/// that far.
double? trendChangeKg(List<TrendPoint> trend, int days) {
  if (trend.isEmpty) return null;
  final last = trend.last;
  final targetDay = addDays(last.dayKey, -days);
  // Points are one per calendar day, so index arithmetic is exact.
  final offset = daysBetween(trend.first.dayKey, targetDay);
  if (offset < 0 || offset >= trend.length) return null;
  return last.trendKg - trend[offset].trendKg;
}

/// Trend points on or after [fromDay] (null = all).
List<TrendPoint> trendSince(List<TrendPoint> trend, String? fromDay) {
  if (fromDay == null) return trend;
  return [
    for (final p in trend)
      if (p.dayKey.compareTo(fromDay) >= 0) p,
  ];
}

/// Formats a signed change, e.g. "-0.8 kg", "+0.3 kg", "0.0 kg".
String formatChangeKg(double changeKg) => '${formatChange(changeKg)} kg';

/// Signed change without a unit: "−0.8", "+0.3", "0.0".
String formatChange(double changeKg) {
  final rounded = (changeKg * 10).roundToDouble() / 10;
  if (rounded == 0) return '0.0';
  final sign = rounded > 0 ? '+' : '−';
  return '$sign${rounded.abs().toStringAsFixed(1)}';
}

/// One decimal, e.g. "82.4".
String formatKg(double kg) => kg.toStringAsFixed(1);

/// The most recent weigh-in (by day), or null when there are none.
double? latestWeighInKg(Map<String, double> weighIns) {
  if (weighIns.isEmpty) return null;
  final last = weighIns.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  return weighIns[last];
}

/// Change of the weigh-in on [dayKey] vs the one before it, or null when
/// [dayKey] has no weigh-in or is the first one.
double? changeVsPreviousKg(Map<String, double> weighIns, String dayKey) {
  final kg = weighIns[dayKey];
  if (kg == null) return null;
  String? previous;
  for (final d in weighIns.keys) {
    if (d.compareTo(dayKey) < 0 &&
        (previous == null || d.compareTo(previous) > 0)) {
      previous = d;
    }
  }
  return previous == null ? null : kg - weighIns[previous]!;
}

/// The compact line shown on Today once [dayKey] has a weigh-in, e.g.
/// "82.4 kg · trend 83.1 · −0.3 this week". Null without a weigh-in.
String? weighInSummaryLine(
  Map<String, double> weighIns,
  List<TrendPoint> trend,
  String dayKey,
) {
  final kg = weighIns[dayKey];
  if (kg == null) return null;
  final parts = ['${formatKg(kg)} kg'];
  final upTo = [
    for (final p in trend)
      if (p.dayKey.compareTo(dayKey) <= 0) p,
  ];
  if (upTo.isNotEmpty && upTo.last.dayKey == dayKey) {
    parts.add('trend ${formatKg(upTo.last.trendKg)}');
    final week = trendChangeKg(upTo, 7);
    if (week != null) parts.add('${formatChange(week)} this week');
  }
  return parts.join(' · ');
}

/// "3.1 kg to goal", or "At your goal" within 0.1 kg. Null without a trend.
String? toGoalText(double? trendKg, double? goalKg) {
  if (trendKg == null || goalKg == null) return null;
  final left = ((trendKg - goalKg).abs() * 10).roundToDouble() / 10;
  if (left < 0.1) return 'At your goal';
  return '${formatKg(left)} kg to goal';
}

/// Goal weight label for the chart, e.g. "Goal 78 kg" or "Goal 78.5 kg".
String goalLabel(double goalKg) {
  final rounded = (goalKg * 10).roundToDouble() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  return 'Goal $text kg';
}
