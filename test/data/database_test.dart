import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('weigh-in upsert keeps one row per day', () async {
    final now = DateTime(2026, 9, 25, 8);
    Future<void> put(double kg) => db.into(db.weighIns).insertOnConflictUpdate(
          WeighInsCompanion.insert(
            dayKey: '2026-09-25',
            weightKg: kg,
            createdAt: now,
          ),
        );
    await put(90.0);
    await put(89.6);
    final rows = await db.select(db.weighIns).get();
    expect(rows.single.weightKg, 89.6);
  });

  test('foods are unique per source and external id', () async {
    FoodsCompanion food(String name) => FoodsCompanion.insert(
          source: 'off',
          externalId: const Value('7290000000001'),
          name: name,
          kcalPer100g: 100,
          proteinPer100g: 1,
          fatPer100g: 1,
          carbsPer100g: 1,
          createdAt: DateTime(2026, 9, 25),
        );
    await db.into(db.foods).insert(food('A'));
    expect(
      () => db.into(db.foods).insert(food('B')),
      throwsA(isA<Exception>()),
    );
  });
}
