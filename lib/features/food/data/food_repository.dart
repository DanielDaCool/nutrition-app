// Drift access for the food feature: foods, log entries, day statuses and
// the per-day intake totals other features read.

import 'package:drift/drift.dart';

import '../../../core/day_key.dart';
import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../describe/builtin_foods.dart';
import '../describe/describe_memory.dart';
import '../nutrition_math.dart';
import 'barcode_format.dart';
import 'remote_food.dart';

/// One logged portion joined with its food, for the meals list.
class LoggedItem {
  const LoggedItem({
    required this.id,
    required this.dayKey,
    required this.meal,
    required this.foodId,
    required this.foodName,
    required this.brand,
    required this.grams,
    required this.macros,
    required this.createdAt,
    this.source = '',
  });

  final int id;

  /// Day it was logged on (`YYYY-MM-DD`, local time).
  final String dayKey;
  final Meal meal;
  final int foodId;
  final String foodName;
  final String? brand;

  /// Amount eaten, in grams.
  final double grams;

  /// Nutrition snapshot copied at log time for [grams]; later edits to the
  /// food don't change it.
  final Macros macros;
  final DateTime createdAt;

  /// `Foods.source` of the food ([FoodSource.recipe] entries are counted in
  /// servings of 100 pseudo-grams rather than grams).
  final String source;

  /// Logged with "Quick add calories" rather than from a food.
  bool get isQuick => FoodSource.isQuick(source);

  /// A quick add where protein, fat or carbs were left blank, so [macros]
  /// undercounts them.
  bool get macrosIncomplete => source == FoodSource.quickKcal;
}

/// One food and amount in a [SavedMealView], with the food's current values.
class SavedMealItemView {
  const SavedMealItemView({
    required this.foodId,
    required this.foodName,
    required this.source,
    required this.grams,
    required this.macros,
  });

  final int foodId;
  final String foodName;
  final String source;
  final double grams;

  /// Nutrition of [grams] at the food's current per-100 g values.
  final Macros macros;
}

/// A saved meal with its items and their total at current food values.
class SavedMealView {
  const SavedMealView({
    required this.id,
    required this.name,
    required this.items,
  });

  final int id;
  final String name;
  final List<SavedMealItemView> items;

  Macros get total => items.fold(Macros.zero, (a, b) => a + b.macros);
}

/// What [FoodRepository.logMany] wrote: the new entries, and the value each
/// remembered `describe.*` row had before (null when it didn't exist).
class LoggedBatch {
  const LoggedBatch({required this.entryIds, this.previousMemory = const {}});

  final List<int> entryIds;
  final Map<String, String?> previousMemory;
}

/// What the user typed for a custom food, already converted to per 100 g.
class CustomFoodInput {
  const CustomFoodInput({
    required this.name,
    this.brand,
    required this.per100g,
    this.servingName,
    this.servingGrams,
    this.barcode,
  });

  final String name;
  final String? brand;
  final Macros per100g;
  final String? servingName;

  /// Grams in one serving, or null when the food has no serving size.
  final double? servingGrams;
  final String? barcode;
}

/// The per-100 g nutrition stored on a [Food] row, as [Macros].
Macros per100gOf(Food f) => Macros(
  kcal: f.kcalPer100g,
  proteinG: f.proteinPer100g,
  fatG: f.fatPer100g,
  carbsG: f.carbsPer100g,
);

/// Pseudo-grams in one serving of a recipe food ([FoodSource.recipe]).
const double recipeServingGrams = 100;

/// All reads and writes of the food feature's tables (Foods, FoodLogEntries,
/// SavedMeals, SavedMealItems, DayStatuses) and its `describe.*` KeyValues rows.
class FoodRepository {
  FoodRepository(this._db, this._now);

  final AppDatabase _db;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- foods

  /// The food with [id]; throws if it doesn't exist.
  Future<Food> foodById(int id) =>
      (_db.select(_db.foods)..where((f) => f.id.equals(id))).getSingle();

  /// The food with [id], re-emitted whenever its row changes.
  Stream<Food> watchFood(int id) =>
      (_db.select(_db.foods)..where((f) => f.id.equals(id))).watchSingle();

  /// Saves a food from OFF/USDA, updating the stored copy if the source
  /// already has one. Favorite flag and last-used time are kept.
  Future<Food> upsertRemote(RemoteFood r) {
    if (!r.isComplete) {
      throw ArgumentError('Food "${r.name}" is missing nutrition values');
    }
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.foods)..where(
                (f) =>
                    f.source.equals(r.source) &
                    f.externalId.equals(r.externalId),
              ))
              .getSingleOrNull();
      final values = FoodsCompanion(
        name: Value(r.name),
        brand: Value(r.brand),
        kcalPer100g: Value(r.kcalPer100g!),
        proteinPer100g: Value(r.proteinPer100g ?? 0),
        fatPer100g: Value(r.fatPer100g ?? 0),
        carbsPer100g: Value(r.carbsPer100g ?? 0),
        servingName: Value(r.servingName),
        servingGrams: Value(r.servingGrams),
      );
      if (existing != null) {
        await (_db.update(
          _db.foods,
        )..where((f) => f.id.equals(existing.id))).write(values);
        return foodById(existing.id);
      }
      final id = await _db
          .into(_db.foods)
          .insert(
            values.copyWith(
              source: Value(r.source),
              externalId: Value(r.externalId),
              createdAt: Value(_now()),
            ),
          );
      return foodById(id);
    });
  }

  /// Saves a built-in food (or refreshes its saved copy) so it can be
  /// logged and shows up under Recent.
  Future<Food> saveBuiltin(BuiltinFood b) => upsertRemote(
    RemoteFood(
      source: FoodSource.builtin,
      externalId: b.key,
      name: b.name,
      kcalPer100g: b.kcal,
      proteinPer100g: b.proteinG,
      fatPer100g: b.fatG,
      carbsPer100g: b.carbsG,
      servingName: b.servingName,
      servingGrams: b.servingGrams,
    ),
  );

  /// Inserts a user-created food. Blank brand, barcode and serving name are
  /// stored as null.
  Future<Food> createCustom(CustomFoodInput input) async {
    final id = await _db
        .into(_db.foods)
        .insert(
          FoodsCompanion.insert(
            source: FoodSource.custom,
            name: input.name.trim(),
            brand: Value(_blankToNull(input.brand)),
            barcode: Value(_normalizedBarcode(input.barcode)),
            kcalPer100g: input.per100g.kcal,
            proteinPer100g: input.per100g.proteinG,
            fatPer100g: input.per100g.fatG,
            carbsPer100g: input.per100g.carbsG,
            servingName: Value(_blankToNull(input.servingName)),
            servingGrams: Value(input.servingGrams),
            createdAt: _now(),
          ),
        );
    return foodById(id);
  }

  /// Edits a custom food. Past log entries keep their snapshot.
  Future<Food> updateCustom(int foodId, CustomFoodInput input) async {
    await (_db.update(_db.foods)..where((f) => f.id.equals(foodId))).write(
      FoodsCompanion(
        name: Value(input.name.trim()),
        brand: Value(_blankToNull(input.brand)),
        barcode: Value(_normalizedBarcode(input.barcode)),
        kcalPer100g: Value(input.per100g.kcal),
        proteinPer100g: Value(input.per100g.proteinG),
        fatPer100g: Value(input.per100g.fatG),
        carbsPer100g: Value(input.per100g.carbsG),
        servingName: Value(_blankToNull(input.servingName)),
        servingGrams: Value(input.servingGrams),
      ),
    );
    return foodById(foodId);
  }

  /// Stars or unstars a food (shown in the Favorites tab).
  Future<void> setFavorite(int foodId, bool favorite) =>
      (_db.update(_db.foods)..where((f) => f.id.equals(foodId))).write(
        FoodsCompanion(isFavorite: Value(favorite)),
      );

  /// A food saved locally for [barcode]: the user's own food first (entered
  /// from the label on purpose), then a cached Open Food Facts product.
  /// Matches whichever equivalent form (UPC-A or EAN-13) the barcode was
  /// saved under, since a scan of the same physical barcode doesn't always
  /// decode to the same digit string.
  Future<Food?> findByBarcode(String barcode) async {
    final candidates = barcodeVariants(normalizeBarcode(barcode)).toList();
    final custom =
        await (_db.select(_db.foods)
              ..where(
                (f) =>
                    f.source.equals(FoodSource.custom) &
                    f.barcode.isIn(candidates),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.id)])
              ..limit(1))
            .getSingleOrNull();
    if (custom != null) return custom;
    return (_db.select(_db.foods)..where(
          (f) =>
              f.source.equals(FoodSource.off) & f.externalId.isIn(candidates),
        ))
        .getSingleOrNull();
  }

  /// Saves a recipe as a hidden food (see [FoodSource.recipe]) or refreshes
  /// the stored copy when the catalog numbers changed. Log entries keep
  /// their own snapshot, so history doesn't move.
  Future<Food> upsertRecipeFood(Recipe r) => upsertRemote(
    RemoteFood(
      source: FoodSource.recipe,
      externalId: r.id,
      name: r.name,
      kcalPer100g: r.perServing.kcal,
      proteinPer100g: r.perServing.proteinG,
      fatPer100g: r.perServing.fatG,
      carbsPer100g: r.perServing.carbsG,
      servingName: '1 serving',
      servingGrams: recipeServingGrams,
    ),
  );

  /// Most recently logged foods, newest first.
  Stream<List<Food>> watchRecent({int limit = 50}) =>
      (_db.select(_db.foods)
            ..where((f) => f.lastUsedAt.isNotNull() & _notQuick(f))
            ..orderBy([(f) => OrderingTerm.desc(f.lastUsedAt)])
            ..limit(limit))
          .watch();

  /// Favorites, most recently used first, then by name.
  Stream<List<Food>> watchFavorites() =>
      (_db.select(_db.foods)
            ..where((f) => f.isFavorite.equals(true) & _notQuick(f))
            ..orderBy([
              (f) => OrderingTerm(
                expression: f.lastUsedAt,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
              (f) => OrderingTerm.asc(f.name),
            ]))
          .watch();

  /// Every saved food (for matching described meals), by id. Recipe and
  /// quick-add foods are left out so describing a meal behaves as it did
  /// before they could be logged.
  Stream<List<Food>> watchAllFoods() =>
      (_db.select(_db.foods)
            ..where(
              (f) => f.source.equals(FoodSource.recipe).not() & _notQuick(f),
            )
            ..orderBy([(f) => OrderingTerm.asc(f.id)]))
          .watch();

  /// The user's own foods, alphabetically.
  Stream<List<Food>> watchCustom() =>
      (_db.select(_db.foods)
            ..where((f) => f.source.equals(FoodSource.custom))
            ..orderBy([
              (f) => OrderingTerm.asc(f.name.collate(Collate.noCase)),
            ]))
          .watch();

  // ------------------------------------------------------------- log entries

  /// Logs [grams] of a food with a nutrition snapshot and marks the food as
  /// recently used. Returns the entry id.
  Future<int> logFood({
    required String dayKey,
    required Meal meal,
    required int foodId,
    required double grams,
  }) {
    _checkGrams(grams);
    return _db.transaction(() => _insertEntry(dayKey, meal, foodId, grams));
  }

  /// Logs several foods into one meal at once (a described meal): all of
  /// them or none. [remember] rows (from [DescribeMemory]) are saved in the
  /// same transaction. Returns the entry ids in order and what the
  /// remembered rows held before, so [undoLogMany] can take it all back.
  Future<LoggedBatch> logMany({
    required String dayKey,
    required Meal meal,
    required List<({int foodId, double grams})> items,
    Map<String, String> remember = const {},
  }) {
    for (final i in items) {
      _checkGrams(i.grams);
    }
    for (final k in remember.keys) {
      if (!k.startsWith(DescribeMemory.keyPrefix)) {
        throw ArgumentError.value(k, 'remember', 'not a describe key');
      }
    }
    return _db.transaction(() async {
      final ids = [
        for (final i in items)
          await _insertEntry(dayKey, meal, i.foodId, i.grams),
      ];
      final previous = <String, String?>{};
      for (final e in remember.entries) {
        final old = await (_db.select(
          _db.keyValues,
        )..where((t) => t.key.equals(e.key))).getSingleOrNull();
        previous[e.key] = old?.value;
        await _db
            .into(_db.keyValues)
            .insertOnConflictUpdate(
              KeyValuesCompanion.insert(key: e.key, value: e.value),
            );
      }
      return LoggedBatch(entryIds: ids, previousMemory: previous);
    });
  }

  /// Logs [servings] of [recipe] (one serving = 100 pseudo-grams of its
  /// hidden food) with a snapshot of `perServing × servings`. Returns the
  /// entry id.
  Future<int> logRecipe({
    required String dayKey,
    required Meal meal,
    required Recipe recipe,
    required double servings,
  }) {
    final grams = servings * recipeServingGrams;
    _checkGrams(grams);
    return _db.transaction(() async {
      final food = await upsertRecipeFood(recipe);
      return _insertEntry(dayKey, meal, food.id, grams);
    });
  }

  /// Logs a calorie amount without a food: a hidden food named [label] (or
  /// "Quick add") whose per-100 g values are the typed ones, logged as
  /// 100 g so the entry shows exactly what was typed. A blank macro is
  /// stored as 0 and makes the food [FoodSource.quickKcal]. An identical
  /// earlier quick food is reused. Returns the entry id.
  Future<int> logQuickCalories({
    required String dayKey,
    required Meal meal,
    required double kcal,
    double? proteinG,
    double? fatG,
    double? carbsG,
    String? label,
  }) {
    for (final v in [kcal, ?proteinG, ?fatG, ?carbsG]) {
      if (v.isNaN || v.isInfinite || v < 0) {
        throw ArgumentError.value(v, 'macros', 'must be >= 0');
      }
    }
    _checkGrams(kcal);
    final name = _blankToNull(label) ?? 'Quick add';
    final source = (proteinG == null || fatG == null || carbsG == null)
        ? FoodSource.quickKcal
        : FoodSource.quick;
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.foods)
                ..where(
                  (f) =>
                      f.source.equals(source) &
                      f.name.equals(name) &
                      f.kcalPer100g.equals(kcal) &
                      f.proteinPer100g.equals(proteinG ?? 0) &
                      f.fatPer100g.equals(fatG ?? 0) &
                      f.carbsPer100g.equals(carbsG ?? 0),
                )
                ..orderBy([(f) => OrderingTerm.asc(f.id)])
                ..limit(1))
              .getSingleOrNull();
      final foodId =
          existing?.id ??
          await _db
              .into(_db.foods)
              .insert(
                FoodsCompanion.insert(
                  source: source,
                  name: name,
                  kcalPer100g: kcal,
                  proteinPer100g: proteinG ?? 0,
                  fatPer100g: fatG ?? 0,
                  carbsPer100g: carbsG ?? 0,
                  servingGrams: const Value(100),
                  createdAt: _now(),
                ),
              );
      return _insertEntry(dayKey, meal, foodId, 100);
    });
  }

  // ------------------------------------------------------------ saved meals

  /// Saves [items] as a named meal, all in one transaction. A saved meal
  /// points at foods by id; foods are never deleted, so the reference stays
  /// valid. Returns the meal id.
  Future<int> createSavedMeal(
    String name,
    List<({int foodId, double grams})> items,
  ) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    for (final i in items) {
      _checkGrams(i.grams);
    }
    return _db.transaction(() async {
      final id = await _db
          .into(_db.savedMeals)
          .insert(SavedMealsCompanion.insert(name: trimmed, createdAt: _now()));
      for (final i in items) {
        await _db
            .into(_db.savedMealItems)
            .insert(
              SavedMealItemsCompanion.insert(
                savedMealId: id,
                foodId: i.foodId,
                grams: i.grams,
              ),
            );
      }
      return id;
    });
  }

  /// Saved meals by name, each with its items at the foods' current values.
  /// Re-emits when meals, their items or the foods change.
  Stream<List<SavedMealView>> watchSavedMeals() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.savedMeals, _db.savedMealItems, _db.foods},
      )
      .watch()
      .asyncMap((_) => savedMeals());

  /// One-shot version of [watchSavedMeals].
  Future<List<SavedMealView>> savedMeals() => _db.transaction(() async {
    final meals =
        await (_db.select(_db.savedMeals)..orderBy([
              (m) => OrderingTerm.asc(m.name.collate(Collate.noCase)),
              (m) => OrderingTerm.asc(m.id),
            ]))
            .get();
    final rows = await (_db.select(_db.savedMealItems).join([
      innerJoin(_db.foods, _db.foods.id.equalsExp(_db.savedMealItems.foodId)),
    ])..orderBy([OrderingTerm.asc(_db.savedMealItems.id)])).get();
    final byMeal = <int, List<SavedMealItemView>>{};
    for (final row in rows) {
      final item = row.readTable(_db.savedMealItems);
      final food = row.readTable(_db.foods);
      byMeal
          .putIfAbsent(item.savedMealId, () => [])
          .add(
            SavedMealItemView(
              foodId: food.id,
              foodName: food.name,
              source: food.source,
              grams: item.grams,
              macros: macrosForGrams(per100gOf(food), item.grams),
            ),
          );
    }
    return [
      for (final m in meals)
        SavedMealView(id: m.id, name: m.name, items: byMeal[m.id] ?? const []),
    ];
  });

  /// Renames a saved meal.
  Future<void> renameSavedMeal(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return (_db.update(_db.savedMeals)..where((m) => m.id.equals(id))).write(
      SavedMealsCompanion(name: Value(trimmed)),
    );
  }

  /// Deletes a saved meal and its items. Entries already logged from it
  /// stay.
  Future<void> deleteSavedMeal(int id) =>
      (_db.delete(_db.savedMeals)..where((m) => m.id.equals(id))).go();

  /// Logs every item of a saved meal into [meal] of [dayKey] with fresh
  /// snapshots, in one batch that [undoLogMany] can take back. Returns an
  /// empty batch when the meal is gone or has no items.
  Future<LoggedBatch> logSavedMeal({
    required String dayKey,
    required Meal meal,
    required int savedMealId,
  }) async {
    final items =
        await (_db.select(_db.savedMealItems)
              ..where((i) => i.savedMealId.equals(savedMealId))
              ..orderBy([(i) => OrderingTerm.asc(i.id)]))
            .get();
    if (items.isEmpty) return const LoggedBatch(entryIds: []);
    return logMany(
      dayKey: dayKey,
      meal: meal,
      items: [for (final i in items) (foodId: i.foodId, grams: i.grams)],
    );
  }

  /// Undoes [logMany]: deletes its entries and puts the remembered rows
  /// back as they were (deleting the ones that were new).
  Future<void> undoLogMany(LoggedBatch batch) => _db.transaction(() async {
    await deleteEntries(batch.entryIds);
    for (final e in batch.previousMemory.entries) {
      final old = e.value;
      if (old == null) {
        await (_db.delete(
          _db.keyValues,
        )..where((t) => t.key.equals(e.key))).go();
      } else {
        await _db
            .into(_db.keyValues)
            .insertOnConflictUpdate(
              KeyValuesCompanion.insert(key: e.key, value: old),
            );
      }
    }
  });

  /// Inserts one entry with its nutrition snapshot and marks the food as
  /// used. Call inside a transaction.
  Future<int> _insertEntry(
    String dayKey,
    Meal meal,
    int foodId,
    double grams,
  ) async {
    final food = await foodById(foodId);
    final m = macrosForGrams(per100gOf(food), grams);
    final now = _now();
    final id = await _db
        .into(_db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            dayKey: dayKey,
            meal: meal.index,
            foodId: foodId,
            grams: grams,
            kcal: m.kcal,
            proteinG: m.proteinG,
            fatG: m.fatG,
            carbsG: m.carbsG,
            createdAt: now,
          ),
        );
    await (_db.update(_db.foods)..where((f) => f.id.equals(foodId))).write(
      FoodsCompanion(lastUsedAt: Value(now)),
    );
    return id;
  }

  /// Changes the amount (and optionally the meal) of an entry. The snapshot
  /// is scaled, so later edits to the food don't change history.
  Future<void> updateEntry(int entryId, {required double grams, Meal? meal}) {
    _checkGrams(grams);
    return _db.transaction(() async {
      final e = await (_db.select(
        _db.foodLogEntries,
      )..where((t) => t.id.equals(entryId))).getSingle();
      final m = rescaleSnapshot(
        Macros(
          kcal: e.kcal,
          proteinG: e.proteinG,
          fatG: e.fatG,
          carbsG: e.carbsG,
        ),
        e.grams,
        grams,
      );
      await (_db.update(
        _db.foodLogEntries,
      )..where((t) => t.id.equals(entryId))).write(
        FoodLogEntriesCompanion(
          grams: Value(grams),
          kcal: Value(m.kcal),
          proteinG: Value(m.proteinG),
          fatG: Value(m.fatG),
          carbsG: Value(m.carbsG),
          meal: meal == null ? const Value.absent() : Value(meal.index),
        ),
      );
    });
  }

  /// Deletes an entry and returns it (for undo), or null if it was gone.
  Future<FoodLogEntry?> deleteEntry(int entryId) => _db.transaction(() async {
    final e = await (_db.select(
      _db.foodLogEntries,
    )..where((t) => t.id.equals(entryId))).getSingleOrNull();
    if (e == null) return null;
    await (_db.delete(
      _db.foodLogEntries,
    )..where((t) => t.id.equals(entryId))).go();
    return e;
  });

  /// Deletes several entries at once (undo of an add or a copied meal).
  Future<void> deleteEntries(List<int> entryIds) =>
      (_db.delete(_db.foodLogEntries)..where((t) => t.id.isIn(entryIds))).go();

  /// Copies what was logged in [fromMeal] of [fromDay] into [toMeal] of
  /// [toDay] (same foods and grams, fresh nutrition snapshots). Returns the
  /// new entry ids, empty when there was nothing to copy.
  Future<List<int>> copyMeal({
    required String fromDay,
    required Meal fromMeal,
    required String toDay,
    required Meal toMeal,
  }) async {
    final source =
        await (_db.select(_db.foodLogEntries)
              ..where(
                (t) => t.dayKey.equals(fromDay) & t.meal.equals(fromMeal.index),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (source.isEmpty) return const [];
    final batch = await logMany(
      dayKey: toDay,
      meal: toMeal,
      items: [for (final e in source) (foodId: e.foodId, grams: e.grams)],
    );
    return batch.entryIds;
  }

  /// Copies everything logged on [fromDay] into [toDay] (same foods, grams
  /// and meal categories; fresh nutrition snapshots). Returns the new entry
  /// ids in source order, empty when there was nothing to copy.
  Future<List<int>> copyDay({
    required String fromDay,
    required String toDay,
  }) async {
    final source =
        await (_db.select(_db.foodLogEntries)
              ..where((t) => t.dayKey.equals(fromDay))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (source.isEmpty) return const [];
    return _db.transaction(
      () async => [
        for (final e in source)
          await _insertEntry(toDay, _mealOf(e.meal), e.foodId, e.grams),
      ],
    );
  }

  /// Grams of the most recent log entry of [foodId], or null if it was never
  /// logged (or every entry was deleted).
  Future<double?> lastGrams(int foodId) async {
    final e =
        await (_db.select(_db.foodLogEntries)
              ..where((t) => t.foodId.equals(foodId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return e?.grams;
  }

  /// Last logged grams per food id, for every food that has an entry.
  /// Re-emits when entries change.
  Stream<Map<int, double>> watchLastGrams() {
    final e = _db.foodLogEntries;
    // Newest first: the first row seen per food is its latest entry.
    final q = _db.selectOnly(e)
      ..addColumns([e.foodId, e.grams])
      ..orderBy([OrderingTerm.desc(e.createdAt), OrderingTerm.desc(e.id)]);
    return q.watch().map((rows) {
      final out = <int, double>{};
      for (final r in rows) {
        out.putIfAbsent(r.read(e.foodId)!, () => r.read(e.grams)!);
      }
      return out;
    });
  }

  /// Puts back an entry removed with [deleteEntry].
  Future<void> restoreEntry(FoodLogEntry e) =>
      _db.into(_db.foodLogEntries).insertOnConflictUpdate(e);

  /// Entries of [dayKey] joined with their foods, in the order they were
  /// logged.
  Stream<List<LoggedItem>> watchDayItems(String dayKey) {
    final q =
        _db.select(_db.foodLogEntries).join([
            innerJoin(
              _db.foods,
              _db.foods.id.equalsExp(_db.foodLogEntries.foodId),
            ),
          ])
          ..where(_db.foodLogEntries.dayKey.equals(dayKey))
          ..orderBy([
            OrderingTerm.asc(_db.foodLogEntries.createdAt),
            OrderingTerm.asc(_db.foodLogEntries.id),
          ]);
    return q.watch().map(
      (rows) => [
        for (final row in rows)
          _item(row.readTable(_db.foodLogEntries), row.readTable(_db.foods)),
      ],
    );
  }

  LoggedItem _item(FoodLogEntry e, Food f) => LoggedItem(
    id: e.id,
    dayKey: e.dayKey,
    meal: _mealOf(e.meal),
    foodId: f.id,
    foodName: f.name,
    brand: f.brand,
    grams: e.grams,
    macros: Macros(
      kcal: e.kcal,
      proteinG: e.proteinG,
      fatG: e.fatG,
      carbsG: e.carbsG,
    ),
    createdAt: e.createdAt,
    source: f.source,
  );

  // ------------------------------------------------------ describe memory

  /// What the describe screen has learned (KeyValues rows `describe.*`).
  Stream<DescribeMemory> watchDescribeMemory() =>
      (_db.select(
        _db.keyValues,
      )..where((k) => k.key.like('${DescribeMemory.keyPrefix}%'))).watch().map(
        (rows) => DescribeMemory.fromKeyValues({
          for (final r in rows) r.key: r.value,
        }),
      );

  // --------------------------------------------------------------- day status

  /// Marks [dayKey] as completely logged (or not). Only fully logged days
  /// feed the calorie engine's intake estimate.
  Future<void> setFullyLogged(String dayKey, bool fullyLogged) => _db
      .into(_db.dayStatuses)
      .insertOnConflictUpdate(
        DayStatusesCompanion.insert(
          dayKey: dayKey,
          fullyLogged: Value(fullyLogged),
        ),
      );

  // ------------------------------------------------------------------ intake

  /// Intake for every day in [from, to] (inclusive, oldest first), with zero
  /// totals for days with nothing logged. Re-emits when entries or day
  /// statuses change.
  Stream<List<DayIntake>> watchIntakeRange(String from, String to) {
    final trigger = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.foodLogEntries, _db.dayStatuses},
        )
        .watch();
    return trigger.asyncMap((_) => intakeRange(from, to));
  }

  /// One-shot version of [watchIntakeRange]. Returns an empty list when
  /// [to] is before [from].
  Future<List<DayIntake>> intakeRange(String from, String to) async {
    final days = daysBetween(from, to);
    if (days < 0) return const [];
    final e = _db.foodLogEntries;
    final kcal = e.kcal.sum();
    final protein = e.proteinG.sum();
    final fat = e.fatG.sum();
    final carbs = e.carbsG.sum();

    return _db.transaction(() async {
      final sums =
          await (_db.selectOnly(e)
                ..addColumns([e.dayKey, e.meal, kcal, protein, fat, carbs])
                ..where(e.dayKey.isBetweenValues(from, to))
                ..groupBy([e.dayKey, e.meal]))
              .get();
      final statuses = await (_db.select(
        _db.dayStatuses,
      )..where((s) => s.dayKey.isBetweenValues(from, to))).get();

      final byDay = <String, Map<Meal, Macros>>{};
      for (final row in sums) {
        final meal = _mealOf(row.read(e.meal)!);
        final m = Macros(
          kcal: row.read(kcal) ?? 0,
          proteinG: row.read(protein) ?? 0,
          fatG: row.read(fat) ?? 0,
          carbsG: row.read(carbs) ?? 0,
        );
        final meals = byDay.putIfAbsent(row.read(e.dayKey)!, () => {});
        meals[meal] = (meals[meal] ?? Macros.zero) + m;
      }
      final fully = {for (final s in statuses) s.dayKey: s.fullyLogged};

      return [
        for (var i = 0; i <= days; i++) _intake(addDays(from, i), byDay, fully),
      ];
    });
  }

  DayIntake _intake(
    String dayKey,
    Map<String, Map<Meal, Macros>> byDay,
    Map<String, bool> fully,
  ) {
    final meals = byDay[dayKey] ?? const {};
    final byMeal = {for (final m in Meal.values) m: meals[m] ?? Macros.zero};
    return DayIntake(
      dayKey: dayKey,
      total: byMeal.values.fold(Macros.zero, (a, b) => a + b),
      byMeal: byMeal,
      fullyLogged: fully[dayKey] ?? false,
    );
  }

  // ----------------------------------------------------------------- helpers

  /// Excludes the hidden quick-add foods.
  static Expression<bool> _notQuick(Foods f) =>
      f.source.isIn([FoodSource.quick, FoodSource.quickKcal]).not();

  /// Maps a stored meal index back to [Meal]; unknown values fall back to
  /// snack rather than throwing.
  static Meal _mealOf(int index) => (index >= 0 && index < Meal.values.length)
      ? Meal.values[index]
      : Meal.snack;

  /// Rejects zero, negative, NaN and infinite amounts with [ArgumentError].
  static void _checkGrams(double grams) {
    if (grams.isNaN || grams <= 0 || grams.isInfinite) {
      throw ArgumentError.value(grams, 'grams', 'must be > 0');
    }
  }

  static String? _blankToNull(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// [_blankToNull], then widened to the canonical UPC-A/EAN-13 form so a
  /// barcode typed or prefilled from a scan matches a later scan of the
  /// same physical barcode even if it decodes differently next time.
  static String? _normalizedBarcode(String? s) {
    final t = _blankToNull(s);
    return t == null ? null : normalizeBarcode(t);
  }
}
