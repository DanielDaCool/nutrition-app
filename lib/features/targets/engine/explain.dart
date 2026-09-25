/// Plain-English "why" for a recommendation. Pure Dart.
library;

import 'package:intl/intl.dart';

import 'engine.dart';

final _int = NumberFormat.decimalPattern('en_US');

String kcal(num v) => '${_int.format(v.round())} kcal';

String _kg(double v) => '${v.abs().toStringAsFixed(1)} kg';

/// Sentences explaining [e], most important first.
List<String> explainLines(Explanation e) {
  final lines = <String>[];
  final maint = kcal(e.maintenanceKcal);

  if (e.measuredKcal != null && e.weight > 0) {
    final delta = e.trendDeltaKg!;
    final move = delta.abs() < 0.05
        ? 'your trend stayed flat'
        : delta < 0
        ? 'your trend dropped ${_kg(delta)}'
        : 'your trend rose ${_kg(delta)}';
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
        'a maintenance of about $measured. With ${e.loggedDays} logged days '
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
    final reason = e.measuredMissingReason;
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

  if (e.maintenanceMode) {
    lines.add(
      'Your trend weight (${e.trendKg.toStringAsFixed(1)} kg) is at or '
      'below your goal, so your target is maintenance.',
    );
  } else if (e.floorApplied) {
    lines.add(
      'A ${kcal(e.deficitKcal)} deficit would go below the minimum of '
      '${kcal(e.floorKcal)}, so your target is held at that minimum.',
    );
  } else {
    lines.add(
      'Your target is maintenance minus a ${kcal(e.deficitKcal)} '
      'daily deficit for your chosen weekly loss rate.',
    );
  }
  return lines;
}
