import 'package:drift/drift.dart';

// Day-based rows use `dayKey` (YYYY-MM-DD, local time) — see lib/core/day_key.dart.
// Enum columns store the enum's index; never reorder the enums in
// lib/domain/models.dart, only append.

/// Single-row table (id = 1) with the user's profile and goal settings.
class Profiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get sex => integer()(); // Sex.index
  DateTimeColumn get birthDate => dateTime()();
  RealColumn get heightCm => real()();
  IntColumn get activityLevel => integer()(); // ActivityLevel.index
  RealColumn get goalWeightKg => real()();

  /// Desired loss per week as % of body weight (e.g. 0.5).
  RealColumn get weeklyRatePct => real().withDefault(const Constant(0.5))();
  RealColumn get proteinPerKg => real().withDefault(const Constant(2.0))();

  /// DateTime.weekday of the weekly check-in (7 = Sunday).
  IntColumn get checkInWeekday => integer().withDefault(const Constant(7))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Food definitions: from Open Food Facts, USDA, or created by the user.
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 'off', 'usda' or 'custom'.
  TextColumn get source => text()();

  /// Barcode (off), fdcId (usda), null for custom.
  TextColumn get externalId => text().nullable()();

  /// Barcode for custom foods entered from a label (so a later scan finds it).
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get kcalPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get fatPer100g => real()();
  RealColumn get carbsPer100g => real()();

  /// Optional default serving, e.g. "1 slice" = 30 g.
  TextColumn get servingName => text().nullable()();
  RealColumn get servingGrams => real().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {source, externalId},
      ];
}

/// One logged portion of a food. Nutrition is copied at log time so editing a
/// food later doesn't rewrite history.
@TableIndex(name: 'food_log_day_idx', columns: {#dayKey})
class FoodLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dayKey => text()();
  IntColumn get meal => integer()(); // Meal.index
  IntColumn get foodId => integer().references(Foods, #id)();
  RealColumn get grams => real()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real()();
  RealColumn get fatG => real()();
  RealColumn get carbsG => real()();
  DateTimeColumn get createdAt => dateTime()();
}

class SavedMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class SavedMealItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get savedMealId =>
      integer().references(SavedMeals, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodId => integer().references(Foods, #id)();
  RealColumn get grams => real()();
}

/// One weigh-in per day (latest entry for a day replaces the previous one).
class WeighIns extends Table {
  TextColumn get dayKey => text()();
  RealColumn get weightKg => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {dayKey};
}

/// Per-day flags. A missing row means "not fully logged".
@DataClassName('DayStatus')
class DayStatuses extends Table {
  TextColumn get dayKey => text()();
  BoolColumn get fullyLogged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {dayKey};
}

/// Daily step totals copied from Health Connect.
class DailySteps extends Table {
  TextColumn get dayKey => text()();
  IntColumn get steps => integer()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {dayKey};
}

/// Workout sessions copied from Health Connect (e.g. written by Hevy).
@TableIndex(name: 'workouts_day_idx', columns: {#dayKey})
class Workouts extends Table {
  /// Health Connect record id (stable across syncs).
  TextColumn get id => text()();
  TextColumn get dayKey => text()();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();

  /// Health Connect exercise type name, e.g. 'STRENGTH_TRAINING'.
  TextColumn get activityType => text().nullable()();
  TextColumn get sourceApp => text().nullable()();
  RealColumn get kcal => real().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Targets accepted by the user; the newest effectiveFrom <= today applies.
@DataClassName('TargetRecord')
class TargetHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get effectiveFrom => text()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real()();
  RealColumn get fatG => real()();
  RealColumn get carbsG => real()();
  RealColumn get maintenanceKcal => real()();
  IntColumn get method => integer()(); // TargetMethod.index

  /// JSON with the numbers behind the recommendation (shown on check-in).
  TextColumn get explanationJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Small key/value store for sync cursors and app state.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
