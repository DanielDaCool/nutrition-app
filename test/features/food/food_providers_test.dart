import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/food_providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<T> next<T>(StreamProvider<T> p, bool Function(T) until) async {
    final sub = container.listen(p, (_, _) {});
    try {
      for (var i = 0; i < 50; i++) {
        final v = container.read(p);
        if (v.hasValue && until(v.value as T)) return v.value as T;
        await pumpEventQueue();
      }
      fail('provider never reached the expected value: ${container.read(p)}');
    } finally {
      sub.close();
    }
  }

  test('dayIntakeProvider is reactive', () async {
    final repo = container.read(foodRepositoryProvider);
    final sub = container.listen(dayIntakeProvider('2026-09-25'), (_, _) {});
    final empty = await next(dayIntakeProvider('2026-09-25'), (d) => true);
    expect(empty.total.kcal, 0);
    expect(empty.fullyLogged, isFalse);

    final food = await repo.createCustom(
      const CustomFoodInput(
        name: 'Rice',
        per100g: Macros(kcal: 130, proteinG: 2.7, fatG: 0.3, carbsG: 28),
      ),
    );
    await repo.logFood(
      dayKey: '2026-09-25',
      meal: Meal.dinner,
      foodId: food.id,
      grams: 200,
    );
    await repo.setFullyLogged('2026-09-25', true);

    final d = await next(
      dayIntakeProvider('2026-09-25'),
      (d) => d.fullyLogged && d.total.kcal > 0,
    );
    expect(d.total.kcal, closeTo(260, 1e-9));
    expect(d.byMeal[Meal.dinner]!.proteinG, closeTo(5.4, 1e-9));
    sub.close();
  });

  test(
    'intakeRangeProvider returns each day oldest first with zeros',
    () async {
      final repo = container.read(foodRepositoryProvider);
      final food = await repo.createCustom(
        const CustomFoodInput(
          name: 'Egg',
          per100g: Macros(kcal: 143, proteinG: 12.6, fatG: 9.5, carbsG: 0.7),
        ),
      );
      await repo.logFood(
        dayKey: '2026-09-20',
        meal: Meal.breakfast,
        foodId: food.id,
        grams: 100,
      );

      final days = await next(
        intakeRangeProvider(('2026-09-19', '2026-09-21')),
        (d) => d.isNotEmpty,
      );
      expect(days.map((d) => d.dayKey), [
        '2026-09-19',
        '2026-09-20',
        '2026-09-21',
      ]);
      expect(days.map((d) => d.total.kcal), [0, 143, 0]);
    },
  );

  test('logging stamps lastUsedAt with the pinned clock', () async {
    final repo = container.read(foodRepositoryProvider);
    final food = await repo.createCustom(
      const CustomFoodInput(
        name: 'Tahini',
        per100g: Macros(kcal: 640, proteinG: 24, fatG: 57, carbsG: 11),
      ),
    );
    await repo.logFood(
      dayKey: '2026-09-25',
      meal: Meal.lunch,
      foodId: food.id,
      grams: 15,
    );
    final recent = await next(recentFoodsProvider, (l) => l.isNotEmpty);
    expect(recent.single.lastUsedAt, DateTime(2026, 9, 25, 12));
  });
}
