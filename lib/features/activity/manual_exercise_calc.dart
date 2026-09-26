/// MET-based calorie estimate for manually logged aerobic exercise.
///
/// No Flutter/DB imports: pure Dart so it's unit-testable on its own.
library;

/// One selectable activity with its MET (metabolic equivalent) value.
class ExerciseType {
  const ExerciseType(this.label, this.met);

  final String label;

  /// Metabolic equivalent: multiples of resting energy expenditure.
  /// Null for "Other", where the user enters calories directly.
  final double? met;
}

/// Common aerobic activities, MET values from the Compendium of Physical
/// Activities. "Other" has no MET; the user enters calories directly.
const commonExerciseTypes = [
  ExerciseType('Cycling, leisurely', 6.8),
  ExerciseType('Cycling, moderate', 8.0),
  ExerciseType('Cycling, vigorous', 10.0),
  ExerciseType('Treadmill walk', 3.5),
  ExerciseType('Treadmill walk, brisk', 4.3),
  ExerciseType('Treadmill run', 9.8),
  ExerciseType('Elliptical', 5.0),
  ExerciseType('Swimming', 6.0),
  ExerciseType('Rowing machine', 7.0),
  ExerciseType('Other', null),
];

/// Calories burned = MET x body weight (kg) x duration (hours).
///
/// The standard approximation used by consumer fitness apps (1 MET ~= 1
/// kcal per kg of body weight per hour).
double estimateExerciseKcal({
  required double met,
  required double weightKg,
  required double durationMin,
}) => met * weightKg * durationMin / 60.0;
