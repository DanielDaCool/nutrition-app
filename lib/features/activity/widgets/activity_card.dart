// OWNER: Health Connect agent (C).
// The Today screen's activity card (steps and workouts for one day).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../activity_format.dart';
import '../activity_providers.dart';
import '../health_source.dart';

/// Steps and workouts for one day. Shown on the Today screen.
///
/// When Health Connect is missing or not connected it offers the fix right
/// here (Install / Connect) instead of only saying there is no data.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.dayKey});

  /// Day shown (`YYYY-MM-DD`, local time).
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(dayActivityProvider(dayKey));
    final status = ref.watch(healthStatusProvider);
    final theme = Theme.of(context);
    final setup = _setupRow(ref, status);
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
              AsyncData(:final value) => _content(
                value,
                hideEmpty: setup != null,
              ),
              AsyncError(:final error) => [_errorRow(ref, error)],
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
            ?setup,
          ],
        ),
      ),
    );
  }

  Widget _errorRow(WidgetRef ref, Object error) {
    debugPrint('ActivityCard: loading $dayKey failed: $error');
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: const Text("Couldn't load your activity"),
      trailing: TextButton(
        onPressed: () => ref.invalidate(dayActivityProvider(dayKey)),
        child: const Text('Try again'),
      ),
    );
  }

  /// A row with the button that gets Health Connect working, or null when
  /// nothing needs doing.
  Widget? _setupRow(WidgetRef ref, HealthConnectStatus status) {
    final controller = ref.read(healthSyncProvider.notifier);
    if (status.canInstall) {
      final update = status.availability == HcAvailability.updateRequired;
      return _ActionRow(
        key: const Key('activityInstall'),
        text: update
            ? 'Update Health Connect to see steps and workouts'
            : 'Install Health Connect to see steps and workouts',
        label: update ? 'Update' : 'Install',
        onPressed: controller.installHealthConnect,
      );
    }
    switch (status.kind) {
      case HealthStatusKind.unavailable:
        return const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text("Health Connect isn't available on this phone"),
        );
      case HealthStatusKind.needsPermission:
        return _ActionRow(
          key: const Key('activityConnect'),
          text: 'Connect Health Connect to see steps and workouts',
          label: 'Connect',
          onPressed: status.syncing ? null : controller.connect,
        );
      case HealthStatusKind.checking:
      case HealthStatusKind.ok:
      case HealthStatusKind.error:
        return null;
    }
  }

  List<Widget> _content(DayActivity day, {required bool hideEmpty}) {
    final steps = day.steps;
    if (steps == null && day.workouts.isEmpty) {
      if (hideEmpty) return const [];
      return const [
        ListTile(
          leading: Icon(Icons.directions_walk),
          title: Text('No activity yet'),
          subtitle: Text(
            'Steps and workouts show up here from Health Connect.',
          ),
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

/// A short line of text with one big button on the right.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.text,
    required this.label,
    required this.onPressed,
  });

  final String text;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        Icon(
          Icons.favorite_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text)),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          child: Text(label),
        ),
      ],
    ),
  );
}
