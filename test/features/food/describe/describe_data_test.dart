import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/describe_foods.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';
import 'package:nutrition_app/features/food/describe/builtin_foods.dart';
import 'package:nutrition_app/features/food/describe/describe_engine.dart';
import 'package:nutrition_app/features/food/describe/describe_memory.dart';
import 'package:nutrition_app/features/food/describe/food_matcher.dart';
import 'package:nutrition_app/features/food/describe/meal_text_parser.dart';
import 'package:nutrition_app/features/food/food_providers.dart';

import '../../../helpers/test_db.dart';

const _day = '2026-09-25';

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = FoodRepository(db, () => DateTime(2026, 9, 25, 8));
  });
  tearDown(() => db.close());

  group('built-in foods', () {
    test('saveBuiltin stores it once with source builtin', () async {
      final cottage = builtinByKey('cottage_5')!;
      final a = await repo.saveBuiltin(cottage);
      final b = await repo.saveBuiltin(cottage);
      expect(b.id, a.id);
      expect(a.source, FoodSource.builtin);
      expect(a.externalId, 'cottage_5');
      expect(a.name, 'Cottage cheese 5%');
      expect(a.kcalPer100g, 95);
      expect(a.servingGrams, 250);
      expect(await db.select(db.foods).get(), hasLength(1));
      // Not one of "my foods", and not found by barcode.
      expect(await repo.watchCustom().first, isEmpty);
      expect(await repo.findByBarcode('cottage_5'), isNull);
    });

    test(
      'a saved built-in food keeps its key and names as candidate',
      () async {
        final saved = await repo.saveBuiltin(builtinByKey('egg')!);
        await repo.logFood(
          dayKey: _day,
          meal: Meal.lunch,
          foodId: saved.id,
          grams: 50,
        );
        final foods = await repo.watchAllFoods().first;
        final candidates = describeCandidates(foods);
        final eggs = candidates.where((c) => c.builtinKey == 'egg').toList();
        expect(eggs, hasLength(1));
        expect(eggs.single.foodId, saved.id);
        expect(eggs.single.key, builtinCandidateKey('egg'));
        expect(eggs.single.aliases, contains('boiled egg'));
        expect(eggs.single.lastUsedAt, isNotNull);
        expect(candidates, hasLength(builtinFoods.length));
      },
    );
  });

  group('logMany', () {
    test('logs every item into the meal with snapshots', () async {
      final egg = await repo.saveBuiltin(builtinByKey('egg')!);
      final bread = await repo.saveBuiltin(builtinByKey('white_bread')!);
      final batch = await repo.logMany(
        dayKey: _day,
        meal: Meal.breakfast,
        items: [(foodId: egg.id, grams: 100), (foodId: bread.id, grams: 30)],
      );
      expect(batch.entryIds, hasLength(2));
      expect(batch.previousMemory, isEmpty);
      final entries = await db.select(db.foodLogEntries).get();
      expect(entries.map((e) => e.meal), everyElement(Meal.breakfast.index));
      expect(entries[0].kcal, closeTo(143, 1e-9));
      expect(entries[1].kcal, closeTo(265 * 0.3, 1e-9));
      final recent = await repo.watchRecent().first;
      expect(recent.map((f) => f.id), containsAll([egg.id, bread.id]));
    });

    test('all or nothing, and memory is saved with it', () async {
      final egg = await repo.saveBuiltin(builtinByKey('egg')!);
      await expectLater(
        repo.logMany(
          dayKey: _day,
          meal: Meal.lunch,
          items: [(foodId: egg.id, grams: 50), (foodId: 999, grams: 50)],
          remember: {'describe.alias.egg': 'builtin:egg'},
        ),
        throwsA(anything),
      );
      expect(await db.select(db.foodLogEntries).get(), isEmpty);
      expect(await db.select(db.keyValues).get(), isEmpty);

      expect(
        () => repo.logMany(
          dayKey: _day,
          meal: Meal.lunch,
          items: [(foodId: egg.id, grams: 0)],
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.logMany(
          dayKey: _day,
          meal: Meal.lunch,
          items: const [],
          remember: {'hc.lastSync': 'x'},
        ),
        throwsArgumentError,
      );
    });
  });

  group('undoLogMany', () {
    Future<Map<String, String>> kv() async => {
      for (final r in await db.select(db.keyValues).get()) r.key: r.value,
    };

    test('deletes the entries and what was learned with them', () async {
      final egg = await repo.saveBuiltin(builtinByKey('egg')!);
      final batch = await repo.logMany(
        dayKey: _day,
        meal: Meal.lunch,
        items: [(foodId: egg.id, grams: 50)],
        remember: {
          'describe.alias.qwzx': 'builtin:egg',
          'describe.grams.builtin:egg.piece': '55',
        },
      );
      expect(batch.previousMemory, {
        'describe.alias.qwzx': null,
        'describe.grams.builtin:egg.piece': null,
      });
      await db
          .into(db.keyValues)
          .insert(KeyValuesCompanion.insert(key: 'hc.other', value: 'x'));
      await repo.undoLogMany(batch);
      expect(await db.select(db.foodLogEntries).get(), isEmpty);
      // Only the rows this add wrote are gone.
      expect(await kv(), {'hc.other': 'x'});
    });

    test('puts back what was remembered before', () async {
      final egg = await repo.saveBuiltin(builtinByKey('egg')!);
      final banana = await repo.saveBuiltin(builtinByKey('banana')!);
      await repo.logMany(
        dayKey: _day,
        meal: Meal.lunch,
        items: [(foodId: banana.id, grams: 120)],
        remember: {'describe.alias.qwzx': 'builtin:banana'},
      );
      // The wrong food picked next time, then undone.
      final wrong = await repo.logMany(
        dayKey: _day,
        meal: Meal.dinner,
        items: [(foodId: egg.id, grams: 50)],
        remember: {'describe.alias.qwzx': 'builtin:egg'},
      );
      expect(wrong.previousMemory, {'describe.alias.qwzx': 'builtin:banana'});
      expect((await kv())['describe.alias.qwzx'], 'builtin:egg');
      await repo.undoLogMany(wrong);
      expect((await kv())['describe.alias.qwzx'], 'builtin:banana');
      final left = await db.select(db.foodLogEntries).get();
      expect(left.single.foodId, banana.id);
      final memory = await repo.watchDescribeMemory().first;
      expect(memory.foodFor('qwzx'), 'builtin:banana');
    });
  });

  group('describe memory', () {
    test('learns a name and a spoon size, used next time', () async {
      final cottage = await repo.saveBuiltin(builtinByKey('cottage_3')!);
      final key = builtinCandidateKey('cottage_3');
      final alias = DescribeMemory.aliasEntry('Cottage', key)!;
      final grams = DescribeMemory.gramsEntry(key, MeasureUnit.tablespoon, 22)!;
      await repo.logMany(
        dayKey: _day,
        meal: Meal.snack,
        items: [(foodId: cottage.id, grams: 110)],
        remember: Map.fromEntries([alias, grams]),
      );
      final memory = await repo.watchDescribeMemory().first;
      expect(memory.foodFor('cottage'), key);
      expect(memory.gramsPerUnit(key, MeasureUnit.tablespoon), 22);

      final engine = DescribeEngine(
        describeCandidates(await repo.watchAllFoods().first),
        memory,
      );
      final item = engine.parse('5 spoons of cottage').items.single;
      expect(item.match!.candidate.foodId, cottage.id);
      expect(item.grams, 110);
    });

    test('measured units and bad amounts are not learned', () {
      expect(DescribeMemory.gramsEntry('food:1', MeasureUnit.gram, 5), isNull);
      expect(
        DescribeMemory.gramsEntry('food:1', MeasureUnit.milliliter, 5),
        isNull,
      );
      expect(DescribeMemory.gramsEntry('food:1', MeasureUnit.cup, 0), isNull);
      expect(DescribeMemory.aliasEntry('  of ', 'food:1'), isNull);
      // No amount said is stored as a serving.
      final e = DescribeMemory.gramsEntry('food:1', null, 40)!;
      final m = DescribeMemory.fromKeyValues({e.key: e.value, 'hc.x': 'y'});
      expect(m.gramsPerUnit('food:1', null), 40);
      expect(m.gramsPerUnit('food:1', MeasureUnit.serving), 40);
      expect(m.aliases, isEmpty);
    });
  });

  test('describeEngineProvider builds from foods and memory', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 8)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(describeEngineProvider, (_, _) {});
    addTearDown(sub.close);
    for (
      var i = 0;
      i < 20 && !container.read(describeEngineProvider).hasValue;
      i++
    ) {
      await pumpEventQueue();
    }
    final engine = container.read(describeEngineProvider).value!;
    expect(engine.parse('2 eggs').items.single.grams, 100);
  });
}
