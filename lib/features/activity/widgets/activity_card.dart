// OWNER: Health Connect agent (C).
// The Today screen's activity card (steps and workouts for one day).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../../weight/weight_logic.dart';
import '../../weight/weight_providers.dart';
import '../activity_format.dart';
import '../activity_providers.dart';
import '../health_source.dart';
import '../step_goal_providers.dart';
import 'add_exercise_dialog.dart';

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
    final defaultWeightKg = latestWeighInKg(
      ref.watch(weighInsProvider).value ?? const {},
    );
    final activeCalories = ref.watch(todayActiveCaloriesProvider(dayKey)).value;
    final stepGoal =
        ref.watch(stepGoalProvider).value?.stepGoal ??
        StepGoalSettings.defaultStepGoal;
    final theme = Theme.of(context);
    final setup = _setupRow(ref, status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Activity', style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    key: const Key('addExerciseButton'),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add exercise',
                    onPressed: () => showAddExerciseDialog(
                      context,
                      ref,
                      dayKey: dayKey,
                      defaultWeightKg: defaultWeightKg,
                    ),
                  ),
                ],
              ),
            ),
            ...switch (activity) {
              AsyncData(:final value) => _content(
                context,
                ref,
                value,
                hideEmpty: setup != null,
                activeCalories: activeCalories,
                stepGoal: stepGoal,
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

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    DayActivity day, {
    required bool hideEmpty,
    required double? activeCalories,
    required int stepGoal,
  }) {
    final steps = day.steps;
    // Only fall back to the "no activity" empty state when Health Connect
    // isn't connected and there's truly nothing to show. Otherwise (even a
    // day with 0 synced steps) the goal section below is always worth
    // showing.
    if (steps == null && day.workouts.isEmpty && hideEmpty) {
      return const [];
    }
    return [
      _stepsSection(context, steps ?? 0, stepGoal, activeCalories),
      for (final w in day.workouts)
        ListTile(
          leading: Icon(
            w.isManual ? Icons.edit_calendar : Icons.fitness_center,
          ),
          title: Text('${w.title} · ${formatDuration(w.duration)}'),
          subtitle: _subtitle(w),
          trailing: w.isManual
              ? IconButton(
                  key: Key('deleteExercise-${w.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () => deleteManualExerciseEntry(ref, w.id),
                )
              : null,
        ),
    ];
  }

  /// A prominent steps count with an active-calories readout and a progress
  /// bar toward the daily step goal, Samsung-Health-style.
  Widget _stepsSection(
    BuildContext context,
    int steps,
    int stepGoal,
    double? activeCalories,
  ) {
    final theme = Theme.of(context);
    final progress = stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.directions_walk,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(formatSteps(steps), style: theme.textTheme.headlineMedium),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('steps', style: theme.textTheme.bodyMedium),
              ),
              if (activeCalories != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${activeCalories.round()} kcal',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('stepGoalProgress'),
              value: progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Goal: ${formatSteps(stepGoal)} steps',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget? _subtitle(WorkoutSummary w) {
    if (w.isManual) {
      final parts = [
        ?formatWalkDetails(
          distanceKm: w.distanceKm,
          inclinePct: w.inclinePct,
          duration: w.duration,
        ),
        if (w.kcal != null) '${w.kcal!.round()} kcal',
        'manual',
      ];
      return Text(parts.join(' · '));
    }
    final app = readableSourceApp(w.sourceApp);
    final parts = [
      if (app != null) 'from $app',
      if (w.kcal != null) '${w.kcal!.round()} kcal',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
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
