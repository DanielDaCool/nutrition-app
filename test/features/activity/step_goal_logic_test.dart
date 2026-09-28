import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/activity/step_goal_logic.dart';

void main() {
  test('defaults use the default step goal', () {
    expect(StepGoalSettings.defaults.stepGoal, StepGoalSettings.defaultStepGoal);
    expect(StepGoalSettings.defaultStepGoal, 10000);
  });

  test('copyWith overrides only the given field', () {
    const settings = StepGoalSettings(stepGoal: 8000);
    final same = settings.copyWith();
    expect(same.stepGoal, 8000);

    final changed = settings.copyWith(stepGoal: 12000);
    expect(changed.stepGoal, 12000);
  });
}
