/// Cross-feature contract types. Features exchange these, not DB rows, so a
/// feature can change its queries without breaking the screens that use it.
library;

/// Meal slot of a food log entry. Stored by `.index`: only append values.
enum Meal { breakfast, lunch, dinner, snack }

/// Biological sex for the BMR formula. Stored by `.index`: only append values.
enum Sex { male, female }

/// Multipliers applied to BMR (Mifflin-St Jeor) for the starting estimate.
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725);

  const ActivityLevel(this.factor);
  /// Multiplier applied to BMR to get the formula maintenance (kcal/day).
  final double factor;
}

/// How a calorie target was produced.
enum TargetMethod {
  /// Formula only (not enough logged data yet).
  formula,

  /// Formula blended with the measured maintenance estimate.
  blended,

  /// Measured maintenance estimate only.
  adaptive,
}

/// Calories plus protein/fat/carbs, in kcal and grams. Used both for amounts
/// eaten and for targets; add with `+`.
class Macros {
  const Macros({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  /// All zero; handy as the starting value when summing.
  static const zero = Macros(kcal: 0, proteinG: 0, fatG: 0, carbsG: 0);

  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  Macros operator +(Macros o) => Macros(
        kcal: kcal + o.kcal,
        proteinG: proteinG + o.proteinG,
        fatG: fatG + o.fatG,
        carbsG: carbsG + o.carbsG,
      );

  @override
  String toString() =>
      'Macros(kcal: $kcal, P: $proteinG, F: $fatG, C: $carbsG)';
}

/// The daily targets currently in effect.
class DailyTargets {
  const DailyTargets({
    required this.effectiveFrom,
    required this.macros,
    required this.maintenanceKcal,
    required this.method,
  });

  /// Day key (YYYY-MM-DD) from which these targets apply.
  final String effectiveFrom;
  final Macros macros;
  final double maintenanceKcal;
  final TargetMethod method;
}

/// What was eaten on one day.
class DayIntake {
  const DayIntake({
    required this.dayKey,
    required this.total,
    required this.byMeal,
    required this.fullyLogged,
  });

  final String dayKey;
  final Macros total;
  final Map<Meal, Macros> byMeal;

  /// True when the user marked the day as completely logged. Only these days
  /// feed the adaptive maintenance estimate.
  final bool fullyLogged;
}

/// One workout session as synced from Health Connect.
class WorkoutSummary {
  const WorkoutSummary({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.sourceApp,
    this.kcal,
    this.isManual = false,
    this.distanceKm,
    this.inclinePct,
  });

  /// Health Connect record id, or `manual-<id>` for a manually logged entry.
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  /// Package or name of the app that wrote the workout, if known.
  final String? sourceApp;
  /// Calories burned, if known (measured, synced, or a MET-based estimate).
  final double? kcal;
  /// True when this was typed in by the user rather than synced from Health
  /// Connect.
  final bool isManual;
  /// Manually logged walks and runs only.
  final double? distanceKm;
  final double? inclinePct;

  Duration get duration => end.difference(start);
}

/// Steps and workouts for one day, as last synced from Health Connect.
class DayActivity {
  const DayActivity({
    required this.dayKey,
    required this.steps,
    required this.workouts,
  });

  final String dayKey;

  /// Null when no step data was synced for this day.
  final int? steps;
  final List<WorkoutSummary> workouts;
}

// PLACEHOLDER: added by the recipes UI agent to unblock itself while the
// calorie-engine/food-agent sibling task that owns the real Recipe type and
// `recipeCatalog`/`rankRecipesByFit` lands separately. Keep the shape below
// in sync with that task; the orchestrator resolves any conflict on merge.
/// A recipe: ingredients and steps for one dish, with its per-serving macros.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.servings,
    required this.perServing,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String name;
  final Meal category;
  final int servings;
  final Macros perServing;
  final List<String> ingredients;
  final List<String> steps;
}

/// One point of the smoothed weight trend.
class TrendPoint {
  const TrendPoint({
    required this.dayKey,
    required this.trendKg,
    this.scaleKg,
  });

  final String dayKey;
  final double trendKg;

  /// The actual weigh-in on this day, if there was one.
  final double? scaleKg;
}
