import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/activity/step_goal_logic.dart';
import 'package:nutrition_app/features/activity/step_goal_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('missing settings load as defaults', () async {
    final settings = await loadStepGoalSettings(db);
    expect(settings.stepGoal, StepGoalSettings.defaults.stepGoal);
  });

  test('saved settings round-trip', () async {
    const settings = StepGoalSettings(stepGoal: 7500);
    await saveStepGoalSettings(db, settings);
    final loaded = await loadStepGoalSettings(db);
    expect(loaded.stepGoal, 7500);
  });
}
