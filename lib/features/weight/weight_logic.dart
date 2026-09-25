/// Pure weight helpers (no Flutter/DB imports) so they are unit-testable.
library;

import '../../core/day_key.dart';
import '../../domain/models.dart';

const double kMinWeightKg = 30;
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
String formatChangeKg(double changeKg) {
  final rounded = (changeKg * 10).roundToDouble() / 10;
  if (rounded == 0) return '0.0 kg';
  final sign = rounded > 0 ? '+' : '−';
  return '$sign${rounded.abs().toStringAsFixed(1)} kg';
}
