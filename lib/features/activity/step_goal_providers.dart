// OWNER: Health Connect agent (C).
// Riverpod provider for the step goal setting.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'step_goal_logic.dart';
import 'step_goal_repository.dart';

export 'step_goal_logic.dart' show StepGoalSettings;

/// The step goal setting, loaded from KeyValues.
final stepGoalProvider =
    AsyncNotifierProvider<StepGoalController, StepGoalSettings>(
      StepGoalController.new,
    );

/// Holds the step goal setting; [save] persists it.
class StepGoalController extends AsyncNotifier<StepGoalSettings> {
  @override
  FutureOr<StepGoalSettings> build() =>
      loadStepGoalSettings(ref.watch(databaseProvider));

  /// Persists [settings].
  Future<void> save(StepGoalSettings settings) async {
    await saveStepGoalSettings(ref.read(databaseProvider), settings);
    state = AsyncData(settings);
  }
}
