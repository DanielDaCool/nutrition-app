import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/features/activity/step_goal_logic.dart';
import 'package:nutrition_app/features/activity/step_goal_repository.dart';
import 'package:nutrition_app/features/activity/widgets/step_goal_tile.dart';

import '../../helpers/test_db.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('shows the default goal', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(body: StepGoalSettingsTile()),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Step goal: 10000 steps/day'), findsOneWidget);
    expect(find.byKey(const Key('stepGoalSlider')), findsOneWidget);
  });

  testWidgets('dragging the slider saves the new value', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(body: StepGoalSettingsTile()),
        ),
      ),
    );
    await settle(tester);

    final slider = find.byKey(const Key('stepGoalSlider'));
    expect(slider, findsOneWidget);
    await tester.drag(slider, const Offset(200, 0));
    await settle(tester);

    final settings = await tester.runAsync(() => loadStepGoalSettings(db));
    expect(settings!.stepGoal, isNot(StepGoalSettings.defaultStepGoal));
  });
}
