// Math for the Dashboard's "Lifting progress" chart: one exercise, one value
// per trained day. Pure Dart: no Flutter, DB or Riverpod imports.
import 'dart:math' as math;

import '../../domain/models.dart';
import 'lifting_format.dart';

/// What the progress chart plots for each trained day.
enum LiftMetric {
  /// The heaviest weight of the day's sets (kg; for a bodyweight exercise
  /// the extra weight).
  topWeight('Top weight', 'kg'),

  /// The most reps done in a single set that day.
  bestReps('Best set reps', 'reps');

  const LiftMetric(this.label, this.unit);

  /// Name on the metric chip.
  final String label;

  /// Unit on the chart's y axis.
  final String unit;
}

/// One trained day on the progress chart.
class LiftProgressPoint {
  const LiftProgressPoint({
    required this.dayKey,
    required this.value,
    required this.session,
  });

  final String dayKey;

  /// Kg for [LiftMetric.topWeight], reps for [LiftMetric.bestReps].
  final double value;

  /// All sets of that day (for the tooltip).
  final LiftSession session;
}

/// One point per session, in the order given (oldest first): the day's
/// heaviest weight or its most reps in a single set. Sessions without sets
/// are skipped.
List<LiftProgressPoint> liftProgressPoints(
  List<LiftSession> sessions,
  LiftMetric metric,
) {
  final points = <LiftProgressPoint>[];
  for (final session in sessions) {
    if (session.sets.isEmpty) continue;
    var best = -double.infinity;
    for (final set in session.sets) {
      final v = switch (metric) {
        LiftMetric.topWeight => set.weightKg,
        LiftMetric.bestReps => set.reps.toDouble(),
      };
      best = math.max(best, v);
    }
    points.add(
      LiftProgressPoint(dayKey: session.dayKey, value: best, session: session),
    );
  }
  return points;
}

/// The metric to show when the user hasn't picked one: top weight, except
/// best reps when no set has any weight (a bodyweight exercise done without
/// extra weight, where the weight line would be flat at 0).
LiftMetric defaultLiftMetric(List<LiftSession> sessions) {
  var anySet = false;
  for (final session in sessions) {
    for (final set in session.sets) {
      anySet = true;
      if (set.weightKg > 0) return LiftMetric.topWeight;
    }
  }
  return anySet ? LiftMetric.bestReps : LiftMetric.topWeight;
}

/// The exercise the chart shows: the one with [selectedId], or the first of
/// [exercises] when that is null or no longer among them. Null when
/// [exercises] is empty.
LiftExercise? resolveLiftExercise(List<LiftExercise> exercises, int? selectedId) {
  if (exercises.isEmpty) return null;
  for (final e in exercises) {
    if (e.id == selectedId) return e;
  }
  return exercises.first;
}

/// First vs. last point of the window: "60 kg → 65 kg (+5 kg)",
/// "8 → 10 reps (+2)", "BW → BW + 20 kg (+20 kg)"; with a single point just
/// "60 kg" / "8 reps". Null when there are no points.
String? liftProgressHeadline(
  List<LiftProgressPoint> points,
  LiftMetric metric, {
  required bool isBodyweight,
}) {
  if (points.isEmpty) return null;
  final first = points.first.value;
  final last = points.last.value;
  switch (metric) {
    case LiftMetric.topWeight:
      String weight(double kg) =>
          formatLiftWeight(kg, isBodyweight: isBodyweight);
      if (points.length == 1) return weight(last);
      final delta = _signed(formatLiftKg((last - first).abs()), last - first);
      return '${weight(first)} → ${weight(last)} '
          '(${delta == null ? 'no change' : '$delta kg'})';
    case LiftMetric.bestReps:
      if (points.length == 1) return '${last.round()} reps';
      final diff = last.round() - first.round();
      final delta = _signed('${diff.abs()}', diff);
      return '${first.round()} → ${last.round()} reps '
          '(${delta ?? 'no change'})';
  }
}

/// "+5" / "-5" for a non-zero [diff] whose size is already formatted as
/// [magnitude]; null when the formatted size is zero.
String? _signed(String magnitude, num diff) {
  if (diff == 0 || magnitude == '0') return null;
  return '${diff > 0 ? '+' : '-'}$magnitude';
}

/// Y-axis range for the progress chart.
typedef LiftAxis = ({double min, double max, double interval});

/// A y axis around [values] with some room above and below. Weights don't
/// start at 0 (a 60 -> 65 kg change should be visible) and use steps like
/// 2.5 or 5 kg; reps use whole-number steps. Never goes below 0.
LiftAxis liftProgressAxis(Iterable<double> values, LiftMetric metric) {
  var lo = double.infinity;
  var hi = -double.infinity;
  for (final v in values) {
    lo = math.min(lo, v);
    hi = math.max(hi, v);
  }
  if (lo > hi) {
    lo = 0;
    hi = 0;
  }
  final span = hi - lo;
  final double step;
  switch (metric) {
    case LiftMetric.topWeight:
      step = _weightStep(span / 3);
    case LiftMetric.bestReps:
      step = math.max(1.0, (span / 3).ceilToDouble());
  }
  // Half a step of room on each side, then out to the next grid line.
  var min = ((lo - step / 2) / step).floorToDouble() * step;
  final max = ((hi + step / 2) / step).ceilToDouble() * step;
  if (min < 0) min = 0;
  return (min: min, max: max, interval: step);
}

/// The smallest plate-friendly step that is at least [raw] kg.
double _weightStep(double raw) {
  const steps = [2.5, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0, 200.0, 250.0, 500.0];
  for (final s in steps) {
    if (s >= raw) return s;
  }
  return steps.last;
}

/// Breaks a "60 kg × 7 · 60 kg × 4 · …" sets text into lines of at most
/// about [maxChars] characters, splitting only between sets.
String wrapLiftSets(String setsText, {int maxChars = 26}) {
  const separator = ' · ';
  final lines = <String>[];
  var line = '';
  for (final part in setsText.split(separator)) {
    if (line.isEmpty) {
      line = part;
    } else if (line.length + separator.length + part.length <= maxChars) {
      line = '$line$separator$part';
    } else {
      lines.add(line);
      line = part;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n');
}
