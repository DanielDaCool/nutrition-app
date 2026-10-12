// OWNER: engine agent (A).
// Reads the tables and turns them into the CSV files of "Export as CSV".
// Read-only: it writes nothing.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/db/database.dart';
import '../../domain/models.dart';
import 'csv_export.dart';

/// The log entries with their foods, oldest first: one row per entry, with
/// the day's fully-logged flag. Recipe entries are in servings and quick adds
/// are labelled as such (see [foodLogCsvRow]).
Future<String> foodLogCsv(AppDatabase db) async {
  final rows =
      await (db.select(db.foodLogEntries).join([
            innerJoin(
              db.foods,
              db.foods.id.equalsExp(db.foodLogEntries.foodId),
            ),
            leftOuterJoin(
              db.dayStatuses,
              db.dayStatuses.dayKey.equalsExp(db.foodLogEntries.dayKey),
            ),
          ])..orderBy([
            OrderingTerm.asc(db.foodLogEntries.dayKey),
            OrderingTerm.asc(db.foodLogEntries.meal),
            OrderingTerm.asc(db.foodLogEntries.createdAt),
            OrderingTerm.asc(db.foodLogEntries.id),
          ]))
          .get();
  return toCsv(foodLogCsvHeader, [
    for (final row in rows)
      () {
        final e = row.readTable(db.foodLogEntries);
        final f = row.readTable(db.foods);
        final status = row.readTableOrNull(db.dayStatuses);
        return foodLogCsvRow(
          dayKey: e.dayKey,
          meal: _mealName(e.meal),
          food: f.name,
          brand: f.brand,
          source: f.source,
          grams: e.grams,
          kcal: e.kcal,
          proteinG: e.proteinG,
          fatG: e.fatG,
          carbsG: e.carbsG,
          dayFullyLogged: status?.fullyLogged ?? false,
        );
      }(),
  ]);
}

/// Every weigh-in, oldest first.
Future<String> weighInsCsv(AppDatabase db) async {
  final rows = await (db.select(
    db.weighIns,
  )..orderBy([(w) => OrderingTerm.asc(w.dayKey)])).get();
  return toCsv(weighInsCsvHeader, [
    for (final w in rows) [w.dayKey, w.weightKg],
  ]);
}

/// Every target the engine set, oldest first. `skipped` is true for a
/// check-in that kept the previous target; a row whose explanation is missing
/// or unreadable counts as not skipped.
Future<String> targetsCsv(AppDatabase db) async {
  final rows =
      await (db.select(db.targetHistory)..orderBy([
            (t) => OrderingTerm.asc(t.effectiveFrom),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .get();
  return toCsv(targetsCsvHeader, [
    for (final t in rows)
      [
        t.effectiveFrom,
        t.kcal,
        t.proteinG,
        t.fatG,
        t.carbsG,
        t.maintenanceKcal,
        _methodName(t.method),
        _isSkipped(t.explanationJson),
      ],
  ]);
}

String _mealName(int index) =>
    (index >= 0 && index < Meal.values.length ? Meal.values[index] : Meal.snack)
        .name;

String _methodName(int index) =>
    (index >= 0 && index < TargetMethod.values.length
            ? TargetMethod.values[index]
            : TargetMethod.formula)
        .name;

bool _isSkipped(String? explanationJson) {
  if (explanationJson == null) return false;
  try {
    final decoded = jsonDecode(explanationJson);
    return decoded is Map && decoded['skipped'] == true;
  } on FormatException {
    return false;
  }
}
