import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/engine/engine.dart';
import 'package:nutrition_app/features/targets/targets_repository.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 9, 27, 9);

String explanationJson() {
  final r = recommend(
    EngineInput(
      today: '2026-09-20',
      profile: EngineProfile(
        sex: Sex.male,
        birthDate: DateTime(1996, 9, 25),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate,
        goalWeightKg: 80,
        weeklyRatePct: 0.5,
        proteinPerKg: 2.0,
        goalDirection: GoalDirection.lose,
      ),
      weighIns: const {'2026-09-20': 90},
      intake: const {},
    ),
  );
  return jsonEncode(r.explanation.toJson());
}

Future<int> addRow(
  AppDatabase db,
  String day, {
  String? json,
  int kcal = 2100,
  int method = 0,
}) => db
    .into(db.targetHistory)
    .insert(
      TargetHistoryCompanion.insert(
        effectiveFrom: day,
        kcal: kcal.toDouble(),
        proteinG: 160,
        fatG: 70,
        carbsG: 200,
        maintenanceKcal: 2450,
        method: method,
        explanationJson: Value(json),
        createdAt: now,
      ),
    );

void main() {
  late AppDatabase db;
  late TargetsRepository repo;
  setUp(() {
    db = openTestDatabase();
    repo = TargetsRepository(db, () => now);
  });
  tearDown(() => db.close());

  test('empty table gives an empty list', () async {
    expect(await repo.loadHistory(), isEmpty);
  });

  test('accepted row decodes with its explanation, newest first', () async {
    await addRow(db, '2026-09-13', json: explanationJson(), kcal: 2000);
    await addRow(
      db,
      '2026-09-20',
      json: explanationJson(),
      kcal: 2100,
      method: TargetMethod.blended.index,
    );
    final h = await repo.loadHistory();
    expect(h.map((e) => e.effectiveFrom), ['2026-09-20', '2026-09-13']);
    expect(h.first.macros.kcal, 2100);
    expect(h.first.method, TargetMethod.blended);
    expect(h.first.skipped, isFalse);
    expect(h.first.explanation, isNotNull);
    expect(h.first.explanation!.formulaKcal, greaterThan(0));
  });

  test('skip row with a copied explanation keeps it and is skipped', () async {
    final copied = {
      ...jsonDecode(explanationJson()) as Map<String, Object?>,
      'skipped': true,
      'keptFrom': 1,
    };
    await addRow(db, '2026-09-20', json: jsonEncode(copied));
    final h = await repo.loadHistory();
    expect(h.single.skipped, isTrue);
    expect(h.single.explanation, isNotNull);
  });

  test('legacy marker-only skip follows keptFrom back', () async {
    final id = await addRow(db, '2026-09-13', json: explanationJson());
    await addRow(
      db,
      '2026-09-20',
      json: jsonEncode({'skipped': true, 'keptFrom': id}),
    );
    final h = await repo.loadHistory();
    expect(h.first.skipped, isTrue);
    expect(h.first.explanation, isNotNull);
    expect(h.last.skipped, isFalse);
  });

  test('marker pointing nowhere, or at itself, gives no explanation', () async {
    await addRow(
      db,
      '2026-09-13',
      json: jsonEncode({'skipped': true, 'keptFrom': 999}),
    );
    final loop = await addRow(db, '2026-09-20');
    await (db.update(db.targetHistory)..where((t) => t.id.equals(loop))).write(
      TargetHistoryCompanion(
        explanationJson: Value(jsonEncode({'skipped': true, 'keptFrom': loop})),
      ),
    );
    final h = await repo.loadHistory();
    expect(h, hasLength(2));
    expect(h.every((e) => e.explanation == null), isTrue);
    expect(h.every((e) => e.skipped), isTrue);
  });

  test('null, malformed and non-object JSON never throw', () async {
    await addRow(db, '2026-09-10');
    await addRow(db, '2026-09-11', json: '{not json');
    await addRow(db, '2026-09-12', json: '[1,2]');
    await addRow(db, '2026-09-13', json: '{"formulaKcal": "oops"}');
    await addRow(db, '2026-09-14', json: '{"skipped":true}');
    final h = await repo.loadHistory();
    expect(h, hasLength(5));
    expect(h.every((e) => e.explanation == null), isTrue);
    expect(
      h.firstWhere((e) => e.effectiveFrom == '2026-09-14').skipped,
      isTrue,
    );
    expect(
      h.firstWhere((e) => e.effectiveFrom == '2026-09-10').skipped,
      isFalse,
    );
  });

  test('an unknown method index falls back to formula', () async {
    await addRow(db, '2026-09-20', method: 9);
    expect((await repo.loadHistory()).single.method, TargetMethod.formula);
  });
}
