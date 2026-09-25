import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/barcode_lookup.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/data/off_client.dart';
import 'package:nutrition_app/features/food/data/remote_food.dart';

import '../../helpers/test_db.dart';
import 'fixture.dart';

const _oats = RemoteFood(
  source: 'usda',
  externalId: '173904',
  name: 'Oats',
  kcalPer100g: 389,
  proteinPer100g: 16.9,
  fatPer100g: 6.9,
  carbsPer100g: 66.3,
);

void main() {
  late AppDatabase db;
  late FoodRepository repo;
  late DateTime now;

  setUp(() {
    db = openTestDatabase();
    now = DateTime(2026, 9, 25, 8);
    repo = FoodRepository(db, () => now);
  });
  tearDown(() => db.close());

  CustomFoodInput custom(String name, {String? barcode}) => CustomFoodInput(
    name: name,
    per100g: const Macros(kcal: 100, proteinG: 10, fatG: 2, carbsG: 10),
    barcode: barcode,
  );

  group('foods', () {
    test(
      'upsertRemote inserts once per source+externalId and keeps flags',
      () async {
        final a = await repo.upsertRemote(_oats);
        await repo.setFavorite(a.id, true);
        final b = await repo.upsertRemote(
          const RemoteFood(
            source: 'usda',
            externalId: '173904',
            name: 'Oats, rolled',
            kcalPer100g: 379,
            proteinPer100g: 13,
            fatPer100g: 6.5,
            carbsPer100g: 68,
          ),
        );
        expect(b.id, a.id);
        expect(b.name, 'Oats, rolled');
        expect(b.kcalPer100g, 379);
        expect(b.proteinPer100g, 13);
        expect(b.isFavorite, isTrue);
        expect(await db.select(db.foods).get(), hasLength(1));
      },
    );

    test('upsertRemote refuses foods without energy or macros', () {
      expect(
        () => repo.upsertRemote(
          const RemoteFood(source: 'off', externalId: '1234567', name: 'X'),
        ),
        throwsArgumentError,
      );
      // Energy but no macros: not saved as 0 g protein/fat/carbs.
      expect(
        () => repo.upsertRemote(
          const RemoteFood(
            source: 'off',
            externalId: '7654321',
            name: 'Y',
            kcalPer100g: 250,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('custom foods: create, edit, several without barcode', () async {
      final a = await repo.createCustom(custom('  Pita  ', barcode: ' '));
      expect(a.source, 'custom');
      expect(a.name, 'Pita');
      expect(a.barcode, isNull);
      expect(a.externalId, isNull);
      await repo.createCustom(custom('Labneh'));
      final edited = await repo.updateCustom(
        a.id,
        custom('Pita bread', barcode: '7290000000031'),
      );
      expect(edited.name, 'Pita bread');
      expect(edited.barcode, '7290000000031');
      final mine = await repo.watchCustom().first;
      expect(mine.map((f) => f.name), ['Labneh', 'Pita bread']);
    });

    test(
      'findByBarcode: custom barcode first, then cached OFF product',
      () async {
        await repo.upsertRemote(
          const RemoteFood(
            source: 'off',
            externalId: '7290000066318',
            name: 'Hummus (OFF)',
            kcalPer100g: 282,
            proteinPer100g: 7,
            fatPer100g: 22,
            carbsPer100g: 12,
          ),
        );
        expect(
          (await repo.findByBarcode('7290000066318'))!.name,
          'Hummus (OFF)',
        );
        await repo.createCustom(
          custom('Hummus (mine)', barcode: '7290000066318'),
        );
        expect(
          (await repo.findByBarcode('7290000066318'))!.name,
          'Hummus (mine)',
        );
        expect(await repo.findByBarcode('7290000000000'), isNull);
      },
    );

    test(
      'recent is ordered by lastUsedAt, favorites by use then name',
      () async {
        final oats = await repo.upsertRemote(_oats);
        final pita = await repo.createCustom(custom('Pita'));
        final apple = await repo.createCustom(custom('Apple'));
        final zucchini = await repo.createCustom(custom('Zucchini'));

        expect(await repo.watchRecent().first, isEmpty);
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.breakfast,
          foodId: oats.id,
          grams: 50,
        );
        now = now.add(const Duration(hours: 4));
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.lunch,
          foodId: pita.id,
          grams: 80,
        );
        now = now.add(const Duration(hours: 1));
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.lunch,
          foodId: oats.id,
          grams: 30,
        );

        final recent = await repo.watchRecent().first;
        expect(recent.map((f) => f.name), ['Oats', 'Pita']);

        for (final f in [zucchini, apple, pita]) {
          await repo.setFavorite(f.id, true);
        }
        final favs = await repo.watchFavorites().first;
        // Pita was used; Apple and Zucchini never, so alphabetical after it.
        expect(favs.map((f) => f.name), ['Pita', 'Apple', 'Zucchini']);
        await repo.setFavorite(pita.id, false);
        expect((await repo.watchFavorites().first).map((f) => f.name), [
          'Apple',
          'Zucchini',
        ]);
      },
    );
  });

  group('log entries', () {
    test('snapshot is computed from grams and survives food edits', () async {
      final food = await repo.createCustom(
        CustomFoodInput(
          name: 'Granola',
          per100g: const Macros(kcal: 450, proteinG: 10, fatG: 15, carbsG: 65),
        ),
      );
      final id = await repo.logFood(
        dayKey: '2026-09-25',
        meal: Meal.breakfast,
        foodId: food.id,
        grams: 40,
      );
      final e = await (db.select(
        db.foodLogEntries,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(e.kcal, closeTo(180, 1e-9));
      expect(e.proteinG, closeTo(4, 1e-9));
      expect(e.fatG, closeTo(6, 1e-9));
      expect(e.carbsG, closeTo(26, 1e-9));
      expect(e.meal, Meal.breakfast.index);

      await repo.updateCustom(
        food.id,
        CustomFoodInput(
          name: 'Granola',
          per100g: const Macros(kcal: 999, proteinG: 1, fatG: 1, carbsG: 1),
        ),
      );
      // Changing the amount rescales the original snapshot.
      await repo.updateEntry(id, grams: 60, meal: Meal.snack);
      final items = await repo.watchDayItems('2026-09-25').first;
      expect(items.single.grams, 60);
      expect(items.single.meal, Meal.snack);
      expect(items.single.macros.kcal, closeTo(270, 1e-9));
      expect(items.single.macros.carbsG, closeTo(39, 1e-9));
      expect(items.single.foodName, 'Granola');
    });

    test('rejects zero or negative grams', () async {
      final food = await repo.upsertRemote(_oats);
      expect(
        () => repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.lunch,
          foodId: food.id,
          grams: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.lunch,
          foodId: food.id,
          grams: -5,
        ),
        throwsArgumentError,
      );
    });

    test('delete and restore (undo)', () async {
      final food = await repo.upsertRemote(_oats);
      final id = await repo.logFood(
        dayKey: '2026-09-25',
        meal: Meal.lunch,
        foodId: food.id,
        grams: 50,
      );
      final removed = await repo.deleteEntry(id);
      expect(removed!.id, id);
      expect(await repo.watchDayItems('2026-09-25').first, isEmpty);
      expect(await repo.deleteEntry(id), isNull);
      await repo.restoreEntry(removed);
      final items = await repo.watchDayItems('2026-09-25').first;
      expect(items.single.id, id);
      expect(items.single.macros.kcal, closeTo(194.5, 1e-9));
    });
  });

  group('repeat and remember', () {
    test(
      'copyMeal copies foods and grams in order; deleteEntries undoes',
      () async {
        final a = await repo.createCustom(custom('A'));
        final b = await repo.createCustom(custom('B'));
        await repo.logFood(
          dayKey: '2026-09-24',
          meal: Meal.breakfast,
          foodId: a.id,
          grams: 50,
        );
        await repo.logFood(
          dayKey: '2026-09-24',
          meal: Meal.breakfast,
          foodId: b.id,
          grams: 120,
        );
        await repo.logFood(
          dayKey: '2026-09-24',
          meal: Meal.lunch,
          foodId: b.id,
          grams: 300,
        );

        final ids = await repo.copyMeal(
          fromDay: '2026-09-24',
          fromMeal: Meal.breakfast,
          toDay: '2026-09-25',
          toMeal: Meal.breakfast,
        );
        expect(ids, hasLength(2));
        final copied = await (db.select(
          db.foodLogEntries,
        )..where((t) => t.dayKey.equals('2026-09-25'))).get();
        expect(copied.map((e) => (e.foodId, e.grams)), [
          (a.id, 50.0),
          (b.id, 120.0),
        ]);
        expect(copied.map((e) => e.kcal), [50.0, 120.0]);

        expect(
          await repo.copyMeal(
            fromDay: '2026-09-24',
            fromMeal: Meal.dinner,
            toDay: '2026-09-25',
            toMeal: Meal.dinner,
          ),
          isEmpty,
        );

        await repo.deleteEntries(ids);
        expect(await db.select(db.foodLogEntries).get(), hasLength(3));
      },
    );

    test(
      'lastGrams and watchLastGrams return the newest entry per food',
      () async {
        final a = await repo.createCustom(custom('A'));
        final b = await repo.createCustom(custom('B'));
        expect(await repo.lastGrams(a.id), isNull);
        await repo.logFood(
          dayKey: '2026-09-20',
          meal: Meal.lunch,
          foodId: a.id,
          grams: 80,
        );
        now = now.add(const Duration(hours: 1));
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.lunch,
          foodId: a.id,
          grams: 150,
        );
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.snack,
          foodId: b.id,
          grams: 30,
        );
        expect(await repo.lastGrams(a.id), 150);
        expect(await repo.watchLastGrams().first, {a.id: 150.0, b.id: 30.0});
      },
    );
  });

  group('intake', () {
    test(
      'range covers every day, zeros for empty days, oldest first',
      () async {
        final food = await repo.upsertRemote(_oats); // 389 kcal/100 g
        await repo.logFood(
          dayKey: '2026-09-23',
          meal: Meal.breakfast,
          foodId: food.id,
          grams: 100,
        );
        await repo.logFood(
          dayKey: '2026-09-23',
          meal: Meal.dinner,
          foodId: food.id,
          grams: 50,
        );
        await repo.logFood(
          dayKey: '2026-09-25',
          meal: Meal.breakfast,
          foodId: food.id,
          grams: 10,
        );
        await repo.logFood(
          dayKey: '2026-09-26',
          meal: Meal.breakfast,
          foodId: food.id,
          grams: 10,
        );
        await repo.setFullyLogged('2026-09-23', true);

        final days = await repo.intakeRange('2026-09-22', '2026-09-25');
        expect(days.map((d) => d.dayKey), [
          '2026-09-22',
          '2026-09-23',
          '2026-09-24',
          '2026-09-25',
        ]);
        expect(days[0].total.kcal, 0);
        expect(days[0].byMeal.keys, Meal.values);
        expect(days[1].total.kcal, closeTo(583.5, 1e-9));
        expect(days[1].byMeal[Meal.breakfast]!.kcal, closeTo(389, 1e-9));
        expect(days[1].byMeal[Meal.dinner]!.kcal, closeTo(194.5, 1e-9));
        expect(days[1].byMeal[Meal.lunch]!.kcal, 0);
        expect(days[1].total.proteinG, closeTo(25.35, 1e-9));
        expect(days[1].fullyLogged, isTrue);
        expect(days[3].total.kcal, closeTo(38.9, 1e-9));
        expect(days[3].fullyLogged, isFalse);

        expect(await repo.intakeRange('2026-09-25', '2026-09-24'), isEmpty);
      },
    );

    test('range crosses month boundary and DST', () async {
      final days = await repo.intakeRange('2026-10-24', '2026-11-02');
      expect(days, hasLength(10));
      expect(days.last.dayKey, '2026-11-02');
    });

    test('setFullyLogged toggles one row per day', () async {
      await repo.setFullyLogged('2026-09-25', true);
      await repo.setFullyLogged('2026-09-25', false);
      final rows = await db.select(db.dayStatuses).get();
      expect(rows.single.fullyLogged, isFalse);
    });

    test('watchIntakeRange re-emits on entries and status changes', () async {
      final food = await repo.upsertRemote(_oats);
      final stream = repo.watchIntakeRange('2026-09-25', '2026-09-25');
      final seen = <DayIntake>[];
      final sub = stream.listen((d) => seen.add(d.single));
      await pumpEventQueue();
      expect(seen.last.total.kcal, 0);

      await repo.logFood(
        dayKey: '2026-09-25',
        meal: Meal.lunch,
        foodId: food.id,
        grams: 100,
      );
      await pumpEventQueue();
      expect(seen.last.total.kcal, closeTo(389, 1e-9));

      await repo.setFullyLogged('2026-09-25', true);
      await pumpEventQueue();
      expect(seen.last.fullyLogged, isTrue);
      await sub.cancel();
    });
  });

  group('barcode lookup', () {
    OffClient off(int status, String body, {void Function()? onCall}) =>
        OffClient(
          MockClient((_) async {
            onCall?.call();
            return http.Response.bytes(
              utf8.encode(body),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );

    test('local food first, no network', () async {
      var calls = 0;
      await repo.createCustom(custom('Mine', barcode: '7290000066318'));
      final r = await BarcodeLookup(
        repo,
        off(200, '{}', onCall: () => calls++),
      ).lookup('7290000066318');
      expect(r, isA<BarcodeFound>());
      expect((r as BarcodeFound).food.name, 'Mine');
      expect(r.fromCache, isTrue);
      expect(calls, 0);
    });

    test(
      'OFF hit is saved locally; the next scan is served from the DB',
      () async {
        var calls = 0;
        final lookup = BarcodeLookup(
          repo,
          off(
            200,
            fixtureText('off_product_hummus.json'),
            onCall: () => calls++,
          ),
        );
        final r1 = await lookup.lookup('7290000066318') as BarcodeFound;
        expect(r1.fromCache, isFalse);
        expect(r1.food.source, 'off');
        expect(r1.food.externalId, '7290000066318');
        expect(r1.food.servingGrams, 50);
        final r2 = await lookup.lookup('7290000066318') as BarcodeFound;
        expect(r2.fromCache, isTrue);
        expect(r2.food.id, r1.food.id);
        expect(calls, 1);
      },
    );

    test(
      'not found / no nutrition / network error -> add from label',
      () async {
        final notFound = await BarcodeLookup(
          repo,
          off(404, fixtureText('off_product_not_found.json')),
        ).lookup('7290000000017');
        expect(notFound, isA<BarcodeNeedsLabel>());
        expect(notFound.barcode, '7290000000017');

        final noNutrition = await BarcodeLookup(
          repo,
          off(200, fixtureText('off_product_no_nutrition.json')),
        ).lookup('7290104720064') as BarcodeNeedsLabel;
        expect(noNutrition.draft!.name, 'Cottage Cheese 5%');
        expect(noNutrition.message, contains('no calories'));

        final failed = await BarcodeLookup(
          repo,
          OffClient(MockClient((_) => throw http.ClientException('offline'))),
        ).lookup('7290000066318') as BarcodeNeedsLabel;
        expect(failed.message, contains('Could not reach'));
        expect(await db.select(db.foods).get(), isEmpty);
      },
    );
  });
}
