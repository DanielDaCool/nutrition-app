// OWNER: Health Connect agent (C).
// Reads and writes the step goal's `hc.stepGoal` KeyValue.
import '../../data/db/database.dart';
import 'step_goal_logic.dart';

const _stepGoalKey = 'hc.stepGoal';

/// Loads the step goal settings, falling back to [StepGoalSettings.defaults]
/// when nothing is stored yet.
Future<StepGoalSettings> loadStepGoalSettings(AppDatabase db) async {
  final row = await (db.select(
    db.keyValues,
  )..where((t) => t.key.equals(_stepGoalKey))).getSingleOrNull();
  final stepGoal =
      int.tryParse(row?.value ?? '') ?? StepGoalSettings.defaults.stepGoal;
  return StepGoalSettings(stepGoal: stepGoal);
}

/// Persists [settings].
Future<void> saveStepGoalSettings(
  AppDatabase db,
  StepGoalSettings settings,
) => db
    .into(db.keyValues)
    .insertOnConflictUpdate(
      KeyValuesCompanion.insert(
        key: _stepGoalKey,
        value: '${settings.stepGoal}',
      ),
    );
