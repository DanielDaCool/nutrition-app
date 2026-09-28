// OWNER: Health Connect agent (C).
// Settings row: slider to edit the daily step goal shown on the Today card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../step_goal_providers.dart';

/// Settings row for the daily step goal.
class StepGoalSettingsTile extends ConsumerWidget {
  const StepGoalSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(stepGoalProvider);
    final controller = ref.read(stepGoalProvider.notifier);

    return settingsAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.directions_walk),
        title: Text('Step goal'),
        trailing: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) {
        debugPrint('Loading step goal settings failed: $e');
        return const ListTile(
          leading: Icon(Icons.directions_walk),
          title: Text('Step goal'),
          subtitle: Text("Couldn't load"),
        );
      },
      data: (settings) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step goal: ${settings.stepGoal} steps/day'),
            Slider(
              key: const Key('stepGoalSlider'),
              value: settings.stepGoal.toDouble(),
              min: 3000,
              max: 20000,
              divisions: 17,
              label: '${settings.stepGoal}',
              onChanged: (v) =>
                  controller.save(settings.copyWith(stepGoal: v.round())),
            ),
          ],
        ),
      ),
    );
  }
}
