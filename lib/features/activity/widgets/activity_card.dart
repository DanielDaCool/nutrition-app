// OWNER: Health Connect agent (C).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../activity_format.dart';
import '../activity_providers.dart';

/// Steps and workouts for one day. Shown on the Today screen.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dayActivityProvider(dayKey));
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('Activity', style: theme.textTheme.titleMedium),
            ),
            ...switch (activity) {
              AsyncData(:final value) => _content(context, value),
              AsyncError(:final error) => [
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Could not load activity'),
                  subtitle: Text('$error'),
                ),
              ],
              _ => const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, DayActivity day) {
    final steps = day.steps;
    if (steps == null && day.workouts.isEmpty) {
      return const [
        ListTile(
          leading: Icon(Icons.directions_walk),
          title: Text('No activity synced for this day'),
          subtitle: Text('Steps and workouts come from Health Connect.'),
        ),
      ];
    }
    return [
      ListTile(
        leading: const Icon(Icons.directions_walk),
        title: Text(
          steps == null ? 'No step data' : '${formatSteps(steps)} steps',
        ),
      ),
      for (final w in day.workouts)
        ListTile(
          leading: const Icon(Icons.fitness_center),
          title: Text('${w.title} · ${formatDuration(w.duration)}'),
          subtitle: _source(w),
        ),
    ];
  }

  Widget? _source(WorkoutSummary w) {
    final app = readableSourceApp(w.sourceApp);
    return app == null ? null : Text('from $app');
  }
}
