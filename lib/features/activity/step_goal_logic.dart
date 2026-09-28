// OWNER: Health Connect agent (C).
// Pure settings model for the daily step goal, kept free of Flutter/DB
// imports so it's unit-testable without a database or platform channel.
library;

/// The daily step goal shown on the Today screen's activity card, stored as
/// the `hc.stepGoal` KeyValue.
class StepGoalSettings {
  const StepGoalSettings({required this.stepGoal});

  static const defaultStepGoal = 10000;

  static const defaults = StepGoalSettings(stepGoal: defaultStepGoal);

  /// Steps per day the progress bar aims for.
  final int stepGoal;

  StepGoalSettings copyWith({int? stepGoal}) =>
      StepGoalSettings(stepGoal: stepGoal ?? this.stepGoal);
}
