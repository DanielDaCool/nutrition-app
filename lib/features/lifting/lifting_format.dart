// Text for lifting weights and sets. Pure Dart: no Flutter or DB imports.
import '../../domain/models.dart';

/// [weightKg] without a trailing ".0": 60 -> "60", 62.5 -> "62.5".
String formatLiftKg(double weightKg) {
  final rounded = (weightKg * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return rounded
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '');
}

/// The weight part of a set: "60 kg"; for a bodyweight exercise "BW" or,
/// with extra weight, "BW + 20 kg".
String formatLiftWeight(double weightKg, {required bool isBodyweight}) {
  if (!isBodyweight) return '${formatLiftKg(weightKg)} kg';
  if (weightKg <= 0) return 'BW';
  return 'BW + ${formatLiftKg(weightKg)} kg';
}

/// One set: "60 kg × 7", "BW × 8", "BW + 20 kg × 6".
String formatLiftSet(LiftSet set, {required bool isBodyweight}) =>
    '${formatLiftWeight(set.weightKg, isBodyweight: isBodyweight)}'
    ' × ${set.reps}';

/// Every set of a session in order, e.g. "60 kg × 7 · 60 kg × 4".
String formatLiftSets(List<LiftSet> sets, {required bool isBodyweight}) => [
  for (final s in sets) formatLiftSet(s, isBodyweight: isBodyweight),
].join(' · ');
