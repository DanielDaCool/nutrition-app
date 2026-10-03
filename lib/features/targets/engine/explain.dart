/// Plain-English "why" for a recommendation. Pure Dart.
library;

import 'package:intl/intl.dart';

import '../../../domain/models.dart';
import 'engine.dart';

final _int = NumberFormat.decimalPattern('en_US');

/// Formats [v] as a rounded, grouped calorie amount, e.g. "2,150 kcal".
String kcal(num v) => '${_int.format(v.round())} kcal';

String _kg(double v) => '${v.abs().toStringAsFixed(1)} kg';

/// What limited the measured estimate's blend weight: "N fully logged
/// days", "K weigh-ins" or both, matching the min() in the engine's blend.
String _limitedBy(Explanation e) {
  final logged =
      ((e.loggedDays - kMinLoggedDays) / (kFullLoggedDays - kMinLoggedDays))
          .clamp(0.0, 1.0);
  final weighIns =
      ((e.weighInsInWindow - kMinWeighIns) / (kFullWeighIns - kMinWeighIns))
          .clamp(0.0, 1.0);
  final days = '${e.loggedDays} fully logged days';
  final weighs = '${e.weighInsInWindow} weigh-ins';
  if (logged < weighIns) return days;
  if (weighIns < logged) return weighs;
  return '$days and $weighs';
}

/// Sentences explaining [e], most important first.
List<String> explainLines(Explanation e) {
  final lines = <String>[];
  final maint = kcal(e.maintenanceKcal);

  if (e.measuredKcal != null && e.weight > 0) {
    final delta = e.trendDeltaKg!;
    final move = delta.abs() < 0.05
        ? 'your weight held steady'
        : delta < 0
        ? 'your weight went down ${_kg(delta)}'
        : 'your weight went up ${_kg(delta)}';
    final measured = kcal(e.measuredKcal!);
    if (e.weight >= 1) {
      lines.add(
        'You averaged ${kcal(e.avgIntakeKcal!)} on ${e.loggedDays} '
        'fully logged days and $move in ${e.days} days, so your '
        'maintenance is about $measured.',
      );
    } else {
      final pct = (e.weight * 100).round();
      lines.add(
        'You averaged ${kcal(e.avgIntakeKcal!)} on ${e.loggedDays} '
        'fully logged days and $move in ${e.days} days, which points to '
        'a maintenance of about $measured. With ${_limitedBy(e)} '
        'that counts $pct%; the rest comes from the formula estimate '
        '(${kcal(e.formulaKcal)}), giving '
        '${kcal(e.unlimitedMaintenanceKcal)}.',
      );
    }
    if (e.measuredClamped) {
      lines.add(
        'The measured value looked unrealistic, so it was limited to '
        '60–160% of the formula estimate. Check that logged days are complete.',
      );
    }
  } else {
    // No measured value (the engine says why), or one that got no weight in
    // the blend yet (just at the minimum logged days or weigh-ins).
    final reason =
        e.measuredMissingReason ??
        (e.measuredKcal != null
            ? 'only ${_limitedBy(e)} so far, not yet enough for your own '
                  'data to count'
            : null);
    lines.add(
      'Your maintenance of about ${kcal(e.formulaKcal)} is estimated '
      'from your body stats and activity level'
      '${reason == null ? '' : ' ($reason)'}. Log complete days and weigh in '
      'regularly so it can adapt to your real results.',
    );
  }

  if (e.changeLimited) {
    lines.add(
      'To keep changes gradual, maintenance moves at most 150 kcal per '
      'week: it is set to $maint (was ${kcal(e.previousMaintenanceKcal!)}).',
    );
  }

  final isGain = e.goalDirection == GoalDirection.gain;
  final atOrPast = isGain ? 'at or above' : 'at or below';

  if (e.maintenanceMode && e.floorApplied) {
    lines.add(
      'Your trend weight (${e.trendKg.toStringAsFixed(1)} kg) is $atOrPast '
      'your goal, so your target is maintenance, held at the minimum '
      'of ${kcal(e.floorKcal)}. Check that logged days are complete.',
    );
  } else if (e.maintenanceMode) {
    lines.add(
      'Your trend weight (${e.trendKg.toStringAsFixed(1)} kg) is $atOrPast '
      'your goal, so your target is maintenance.',
    );
  } else if (e.floorApplied) {
    lines.add(
      isGain
          ? 'A ${kcal(e.deficitKcal)} surplus would still land below the '
                'minimum of ${kcal(e.floorKcal)}, so your target is held at '
                'that minimum.'
          : 'A ${kcal(e.deficitKcal)} deficit would go below the minimum of '
                '${kcal(e.floorKcal)}, so your target is held at that minimum.',
    );
  } else {
    lines.add(
      isGain
          ? 'Your target is maintenance plus a ${kcal(e.deficitKcal)} '
                'daily surplus for your chosen weekly gain rate.'
          : 'Your target is maintenance minus a ${kcal(e.deficitKcal)} '
                'daily deficit for your chosen weekly loss rate.',
    );
  }
  return lines;
}
