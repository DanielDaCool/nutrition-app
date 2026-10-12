/// Check-in history entries. Pure Dart: no Flutter, no DB.
library;

import 'dart:convert';

import '../../../domain/models.dart';
import 'engine.dart';

/// One stored target (a check-in outcome) as the history screen shows it.
class CheckInEntry {
  const CheckInEntry({
    required this.effectiveFrom,
    required this.macros,
    required this.maintenanceKcal,
    required this.method,
    required this.skipped,
    required this.explanation,
  });

  final String effectiveFrom;
  final Macros macros;
  final double maintenanceKcal;
  final TargetMethod method;

  /// True for a check-in that was skipped (the previous target was kept).
  final bool skipped;

  /// The numbers behind the target, or null when none could be read (a row
  /// from before explanations were stored, or damaged JSON).
  final Explanation? explanation;
}

Map<String, Object?>? _decodeMap(String? json) {
  if (json == null) return null;
  try {
    final v = jsonDecode(json);
    return v is Map<String, Object?> ? v : null;
  } on Object {
    return null;
  }
}

/// The explanation map behind a stored row, following the `keptFrom` marker
/// of a skip row written before skips copied the explanation forward.
/// [jsonById] maps target ids to their stored explanation JSON. Null when
/// there is none.
Map<String, Object?>? resolveExplanationMap(
  String? json,
  Map<int, String?> jsonById,
) {
  var current = json;
  // Bounded, in case of a (never expected) cycle of markers.
  for (var hops = 0; hops < 20; hops++) {
    final map = _decodeMap(current);
    if (map == null) return null;
    if (map.containsKey('formulaKcal')) return map;
    final keptFrom = map['keptFrom'];
    if (keptFrom is! int) return null;
    current = jsonById[keptFrom];
  }
  return null;
}

/// Builds an entry from the fields of a stored row. [explanationJson] is the
/// row's own JSON (used for the skipped flag) and [resolvedExplanation] the
/// map [resolveExplanationMap] found. Never throws: anything unreadable gives
/// `explanation: null`.
CheckInEntry entryFromRow({
  required String effectiveFrom,
  required Macros macros,
  required double maintenanceKcal,
  required int methodIndex,
  required String? explanationJson,
  required Map<String, Object?>? resolvedExplanation,
}) {
  Explanation? explanation;
  if (resolvedExplanation != null) {
    try {
      explanation = Explanation.fromJson(resolvedExplanation);
    } on Object {
      explanation = null;
    }
  }
  final methods = TargetMethod.values;
  return CheckInEntry(
    effectiveFrom: effectiveFrom,
    macros: macros,
    maintenanceKcal: maintenanceKcal,
    method: methodIndex >= 0 && methodIndex < methods.length
        ? methods[methodIndex]
        : TargetMethod.formula,
    skipped: _decodeMap(explanationJson)?['skipped'] == true,
    explanation: explanation,
  );
}
