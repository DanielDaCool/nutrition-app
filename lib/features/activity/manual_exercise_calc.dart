/// Calorie estimates for manually logged aerobic exercise.
///
/// No Flutter/DB imports: pure Dart so it's unit-testable on its own.
library;

/// How a walk or run is estimated (ACSM metabolic equations).
enum Gait { walk, run }

/// One selectable activity.
///
/// Walks and runs ([gait] set) are estimated from speed and incline; the
/// rest from a fixed [met]. "Other" has neither: the user types calories.
class ExerciseType {
  const ExerciseType(this.label, {this.met, this.gait});

  final String label;

  /// Metabolic equivalent: multiples of resting energy expenditure.
  final double? met;
  final Gait? gait;

  bool get isOther => met == null && gait == null;
}

/// MET values from the Compendium of Physical Activities.
const commonExerciseTypes = [
  ExerciseType('Treadmill walk', gait: Gait.walk),
  ExerciseType('Walk', gait: Gait.walk),
  ExerciseType('Treadmill run', gait: Gait.run),
  ExerciseType('Run', gait: Gait.run),
  ExerciseType('Cycling, leisurely', met: 6.8),
  ExerciseType('Cycling, moderate', met: 8.0),
  ExerciseType('Cycling, vigorous', met: 10.0),
  ExerciseType('Elliptical', met: 5.0),
  ExerciseType('Swimming', met: 6.0),
  ExerciseType('Rowing machine', met: 7.0),
  ExerciseType('Other'),
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

/// Calories for a walk or run from speed and incline, using the ACSM
/// metabolic equations (gross, like the MET estimate):
///   walk: VO2 = 3.5 + 0.1 S + 1.8 S G
///   run:  VO2 = 3.5 + 0.2 S + 0.9 S G
/// with VO2 in ml/kg/min, S in m/min and G the grade as a fraction, and
/// ~5 kcal per litre of oxygen.
double estimateGaitKcal({
  required Gait gait,
  required double speedKmh,
  required double inclinePct,
  required double weightKg,
  required double durationMin,
}) {
  final metersPerMin = speedKmh * 1000 / 60;
  final grade = inclinePct / 100;
  final vo2 = switch (gait) {
    Gait.walk => 3.5 + 0.1 * metersPerMin + 1.8 * metersPerMin * grade,
    Gait.run => 3.5 + 0.2 * metersPerMin + 0.9 * metersPerMin * grade,
  };
  return vo2 * weightKg / 1000 * 5 * durationMin;
}

/// Speed in km/h from [distanceKm] over [durationMin].
double speedFromDistance(double distanceKm, double durationMin) =>
    distanceKm / (durationMin / 60);

/// Distance in km at [speedKmh] for [durationMin].
double distanceFromSpeed(double speedKmh, double durationMin) =>
    speedKmh * durationMin / 60;
