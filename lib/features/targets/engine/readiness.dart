/// What the engine still needs before a target adapts to the user's own
/// data. Pure Dart: no Flutter, no DB.
///
/// Everything here is read off an [Explanation] the engine already produced
/// (plus the weigh-ins, for the span), and every threshold comes from the
/// engine's constants, so the wording can't drift from the math.
library;

import '../../../core/day_key.dart';
import 'engine.dart';

/// Fully logged days at which the blend weight first becomes above zero.
/// The engine attempts a measurement at [kMinLoggedDays], but the weight is
/// `(n - kMinLoggedDays) / (kFullLoggedDays - kMinLoggedDays)`, which is 0 at
/// exactly [kMinLoggedDays].
const int kAdaptLoggedDays = kMinLoggedDays + 1;

/// Weigh-ins at which the blend weight first becomes above zero (see
/// [kAdaptLoggedDays]).
const int kAdaptWeighIns = kMinWeighIns + 1;

/// Where the user stands against what the engine needs.
class Readiness {
  const Readiness({
    required this.loggedDays,
    required this.weighIns,
    required this.weighInSpanDays,
    required this.needsSpan,
    required this.settlingDaysLeft,
    required this.weight,
    required this.adapting,
  });

  /// Fully logged days in the measurement window.
  final int loggedDays;

  /// Weigh-ins in the measurement window.
  final int weighIns;

  /// Days from the first to the last weigh-in in the window, or null when
  /// there are none.
  final int? weighInSpanDays;

  /// True when the engine uses a regression through the raw weigh-ins, which
  /// needs them to span [kMinSpanDays].
  final bool needsSpan;

  /// Days left of the pause after a diet change (0 when not settling).
  final int settlingDaysLeft;

  /// Blend weight of the user's own data in the maintenance estimate (0-1),
  /// as the engine computed it.
  final double weight;

  /// True when the user's own data counts at all, worked out from the counts
  /// above. Matches `weight > 0` of the engine.
  final bool adapting;

  /// True when the user's own data counts fully.
  bool get full => adapting && weight >= 1;
}

/// Works out the [Readiness] for the recommendation [e] made from [input].
Readiness readinessOf(EngineInput input, Explanation e) {
  final settling = e.measurementStart.compareTo(e.windowEnd) > 0
      ? daysBetween(e.windowEnd, e.measurementStart)
      : 0;

  final upToToday = [
    for (final k in input.weighIns.keys)
      if (k.compareTo(input.today) <= 0) k,
  ]..sort();
  final inWindow = [
    for (final k in upToToday)
      if (k.compareTo(e.measurementStart) >= 0 && k.compareTo(e.windowEnd) <= 0)
        k,
  ];
  final span = inWindow.isEmpty
      ? null
      : daysBetween(inWindow.first, inWindow.last);

  final needsSpan =
      upToToday.isNotEmpty &&
      !usesTrendDifference(upToToday.first, e.measurementStart);

  final adapting =
      settling == 0 &&
      e.loggedDays >= kAdaptLoggedDays &&
      e.weighInsInWindow >= kAdaptWeighIns &&
      (!needsSpan || (span ?? 0) >= kMinSpanDays);

  return Readiness(
    loggedDays: e.loggedDays,
    weighIns: e.weighInsInWindow,
    weighInSpanDays: span,
    needsSpan: needsSpan,
    settlingDaysLeft: settling,
    weight: e.weight,
    adapting: adapting,
  );
}

/// Plain-English lines saying what is missing. Empty when the user's own data
/// already counts fully.
///
/// The counts are over a rolling window, so they can go down as old days
/// leave it; the copy says so instead of promising steady progress. It names
/// what is missing, never a score to hit.
List<String> readinessLines(Readiness r) {
  if (r.full) return const [];
  if (r.settlingDaysLeft > 0) {
    final n = r.settlingDaysLeft;
    return [
      'Your targets are settling in after a change. Your own data starts to '
          'count in $n more day${n == 1 ? '' : 's'}.',
    ];
  }
  if (r.adapting) {
    return [
      'Your own data counts partly so far. It counts fully at '
          '$kFullLoggedDays fully logged days and $kFullWeighIns weigh-ins '
          'in the last $kWindowDays days.',
    ];
  }
  final parts = [
    '${r.loggedDays} of the $kAdaptLoggedDays fully logged days needed',
    '${r.weighIns} of $kAdaptWeighIns weigh-ins',
    if (r.needsSpan)
      'weigh-ins span ${r.weighInSpanDays ?? 0} of $kMinSpanDays days',
  ];
  return [
    'Your targets start adapting to your own data once you have '
        '$kAdaptLoggedDays fully logged days and $kAdaptWeighIns weigh-ins'
        '${r.needsSpan ? ', spread over at least $kMinSpanDays days' : ''}. '
        'So far: ${parts.join(', ')}.',
    'These counts cover the last $kWindowDays days, so they can go down as '
        'old days drop out.',
  ];
}

/// One sentence on what a maintenance estimate rests on, from stored fields
/// only. It gives no range or score, since the engine doesn't model the
/// uncertainty of the formula part.
String basisLine(Explanation e) {
  if (e.weight <= 0) {
    return 'Formula estimate: rough until your own data counts.';
  }
  final pct = (e.weight * 100).round();
  final over = e.days == null ? '' : ' over ${e.days} days';
  return 'Based on ${e.loggedDays} fully logged days and '
      '${e.weighInsInWindow} weigh-ins$over. '
      'Your own data counts $pct% (formula ${100 - pct}%).';
}
