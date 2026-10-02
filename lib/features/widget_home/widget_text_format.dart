/// Pure formatting helpers for the home-screen widget's text (no Flutter/DB
/// imports), so they're unit-testable in isolation.
library;

import 'package:intl/intl.dart';

final _thousands = NumberFormat.decimalPattern('en_US');

/// "1,450 kcal left" when there's calorie budget remaining, or
/// "320 kcal over" once logged intake has passed the target. Null
/// [targetKcal] (no profile set up yet) or null [loggedKcal] (nothing synced
/// yet) produces a friendly placeholder instead of a number.
String formatKcalLeftText({required double? targetKcal, required double? loggedKcal}) {
  if (targetKcal == null) return 'Set up your targets';
  final logged = loggedKcal ?? 0;
  final remaining = targetKcal - logged;
  if (remaining >= 0) {
    return '${_thousands.format(remaining.round())} kcal left';
  }
  return '${_thousands.format((-remaining).round())} kcal over';
}

/// "8,200 steps" (or "0 steps" / "No step data" when nothing has synced yet).
String formatStepsText(int? steps) {
  if (steps == null) return 'No step data';
  return '${_thousands.format(steps)} steps';
}
