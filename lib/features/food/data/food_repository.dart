// Drift access for the food feature: foods, log entries, day statuses and
// the per-day intake totals other features read.

import 'package:drift/drift.dart';

import '../../../core/day_key.dart';
import '../../../data/db/database.dart';
import '../../../domain/models.dart';
import '../describe/builtin_foods.dart';
import '../describe/describe_memory.dart';
import '../nutrition_math.dart';
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

/// All reads and writes of the food feature's tables (Foods, FoodLogEntries,
/// DayStatuses) and its `describe.*` KeyValues rows.
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
            barcode: Value(_blankToNull(input.barcode)),
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
        barcode: Value(_blankToNull(input.barcode)),
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
  Future<Food?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    final custom =
        await (_db.select(_db.foods)
              ..where(
                (f) =>
                    f.source.equals(FoodSource.custom) & f.barcode.equals(code),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.id)])
              ..limit(1))
            .getSingleOrNull();
    if (custom != null) return custom;
    return (_db.select(_db.foods)..where(
          (f) => f.source.equals(FoodSource.off) & f.externalId.equals(code),
        ))
        .getSingleOrNull();
  }

  /// Most recently logged foods, newest first.
  Stream<List<Food>> watchRecent({int limit = 50}) =>
      (_db.select(_db.foods)
            ..where((f) => f.lastUsedAt.isNotNull())
            ..orderBy([(f) => OrderingTerm.desc(f.lastUsedAt)])
            ..limit(limit))
          .watch();

  /// Favorites, most recently used first, then by name.
  Stream<List<Food>> watchFavorites() =>
      (_db.select(_db.foods)
            ..where((f) => f.isFavorite.equals(true))
            ..orderBy([
              (f) => OrderingTerm(
                expression: f.lastUsedAt,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
              (f) => OrderingTerm.asc(f.name),
            ]))
          .watch();

  /// Every saved food (for matching described meals), by id.
  Stream<List<Food>> watchAllFoods() =>
      (_db.select(_db.foods)..orderBy([(f) => OrderingTerm.asc(f.id)])).watch();

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
  /// same transaction. Returns the entry ids in order.
  Future<List<int>> logMany({
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
      for (final e in remember.entries) {
        await _db
            .into(_db.keyValues)
            .insertOnConflictUpdate(
              KeyValuesCompanion.insert(key: e.key, value: e.value),
            );
      }
      return ids;
    });
  }

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
}
