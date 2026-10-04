// Lifting tab: the exercises planned on the selected day and their sets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../../domain/models.dart';
import '../weight/widgets/weigh_in_dialog.dart';
import 'lifting_providers.dart';
import 'screens/exercises_screen.dart';
import 'screens/presets_screen.dart';
import 'widgets/exercise_picker.dart';
import 'widgets/lift_entry_card.dart';
import 'widgets/lift_write.dart';
import 'widgets/preset_picker.dart';
import 'widgets/save_preset_dialog.dart';

/// How far ahead a day can be planned.
const int liftPlanAheadDays = 365;

enum _ScreenAction { exercises, presets, saveAsPreset }

/// The app-bar title for [dayKey]: "Today", "Tomorrow", "Yesterday" or the
/// date.
String formatLiftDay(String dayKey, String today) =>
    dayKey == addDays(today, 1) ? 'Tomorrow' : formatDayLong(dayKey, today);

/// Lifting tab for the day in `liftSelectedDayProvider`. Arrows move a day
/// at a time and the calendar icon jumps to any day, up to
/// [liftPlanAheadDays] ahead so a day can be planned in advance; tapping the
/// title jumps back to today.
///
/// When the app resumes on a new calendar day while "today" was shown, it
/// moves to the new today.
class LiftingScreen extends ConsumerStatefulWidget {
  const LiftingScreen({super.key});

  @override
  ConsumerState<LiftingScreen> createState() => _LiftingScreenState();
}

class _LiftingScreenState extends ConsumerState<LiftingScreen> {
  late final AppLifecycleListener _lifecycle;

  /// Today's dayKey when the screen opened or last resumed.
  late String _today;

  String _now() => dayKeyOf(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    _today = _now();
    _lifecycle = AppLifecycleListener(onResume: _checkDayRollover);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// If midnight passed while the app was in the background, follow it.
  void _checkDayRollover() {
    if (!mounted) return;
    final now = _now();
    if (now == _today) return;
    final wasOnToday = ref.read(liftSelectedDayProvider) == _today;
    _today = now;
    setState(() {});
    if (wasOnToday) ref.read(liftSelectedDayProvider.notifier).set(now);
  }

  Future<void> _pickDay(String dayKey, String lastDay) async {
    final selected = ref.read(liftSelectedDayProvider.notifier);
    final initial = startOfDay(dayKey);
    final picked = await showDatePicker(
      context: context,
      helpText: 'Jump to a day',
      initialDate: initial,
      firstDate: DateTime(initial.year - 3),
      lastDate: startOfDay(lastDay),
    );
    if (picked == null) return;
    selected.set(dayKeyOf(picked));
  }

  Future<void> _addExercise(String dayKey, List<LiftEntry> entries) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(liftingRepositoryProvider);
    final picked = await showExercisePicker(context);
    if (picked == null) return;
    if (entries.any((e) => e.exercise.id == picked.id)) {
      showLiftSnack(messenger, '${picked.name} is already on this day');
      return;
    }
    await guardLiftWrite(messenger, () => repo.addEntry(dayKey, picked.id));
  }

  Future<void> _loadPreset(String dayKey) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(liftingRepositoryProvider);
    final preset = await showPresetPicker(context);
    if (preset == null) return;
    final added = await guardLiftWrite(
      messenger,
      () => repo.loadPreset(preset.id, dayKey),
    );
    if (added == null) return;
    showLiftSnack(messenger, switch (added) {
      0 when preset.exercises.isEmpty => '${preset.name} has no exercises',
      0 => 'Everything in ${preset.name} is already on this day',
      1 => 'Added 1 exercise from ${preset.name}',
      _ => 'Added $added exercises from ${preset.name}',
    });
  }

  Future<void> _saveAsPreset(String dayKey) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await showSavePresetDialog(context, dayKey: dayKey);
    if (name == null) return;
    showLiftSnack(messenger, 'Saved preset $name');
  }

  void _move(List<LiftEntry> entries, int index, int by) {
    final ids = [for (final e in entries) e.id];
    final id = ids.removeAt(index);
    ids.insert(index + by, id);
    guardLiftWrite(
      ScaffoldMessenger.of(context),
      () => ref.read(liftingRepositoryProvider).reorderEntries(ids),
    );
  }

  void _onAction(_ScreenAction action, String dayKey) {
    switch (action) {
      case _ScreenAction.exercises:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ExercisesScreen()),
        );
      case _ScreenAction.presets:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PresetsScreen()));
      case _ScreenAction.saveAsPreset:
        _saveAsPreset(dayKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = ref.watch(liftSelectedDayProvider);
    final today = _now();
    final lastDay = addDays(today, liftPlanAheadDays);
    final selected = ref.read(liftSelectedDayProvider.notifier);
    final day = ref.watch(liftDayProvider(dayKey));
    final hasExercises = day.value?.isNotEmpty ?? false;
    final canGoForward = dayKey.compareTo(lastDay) < 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          key: const Key('liftPrevDay'),
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => selected.set(addDays(dayKey, -1)),
        ),
        title: TextButton(
          key: const Key('liftHeader'),
          onPressed: selected.today,
          child: Text(
            formatLiftDay(dayKey, today),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('liftPickDay'),
            tooltip: 'Pick a day',
            icon: const Icon(Icons.calendar_month_outlined),
            // A day beyond the range can't be the picker's initial date.
            onPressed: dayKey.compareTo(lastDay) <= 0
                ? () => _pickDay(dayKey, lastDay)
                : null,
          ),
          IconButton(
            key: const Key('liftNextDay'),
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward
                ? () => selected.set(addDays(dayKey, 1))
                : null,
          ),
          PopupMenuButton<_ScreenAction>(
            key: const Key('liftMenu'),
            tooltip: 'More',
            onSelected: (action) => _onAction(action, dayKey),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ScreenAction.exercises,
                child: Text('Exercises'),
              ),
              const PopupMenuItem(
                value: _ScreenAction.presets,
                child: Text('Presets'),
              ),
              PopupMenuItem(
                value: _ScreenAction.saveAsPreset,
                enabled: hasExercises,
                child: const Text('Save day as preset'),
              ),
            ],
          ),
        ],
      ),
      body: switch (day) {
        AsyncValue(:final value?) =>
          value.isEmpty
              ? _EmptyDay(
                  isFuture: dayKey.compareTo(today) > 0,
                  onAddExercise: () => _addExercise(dayKey, value),
                  onLoadPreset: () => _loadPreset(dayKey),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final (i, entry) in value.indexed)
                      LiftEntryCard(
                        key: ValueKey(entry.id),
                        entry: entry,
                        dayExerciseIds: {for (final e in value) e.exercise.id},
                        onMoveUp: i > 0 ? () => _move(value, i, -1) : null,
                        onMoveDown: i < value.length - 1
                            ? () => _move(value, i, 1)
                            : null,
                      ),
                    const SizedBox(height: 8),
                    _DayButtons(
                      onAddExercise: () => _addExercise(dayKey, value),
                      onLoadPreset: () => _loadPreset(dayKey),
                    ),
                  ],
                ),
        AsyncError() => _DayError(
          onRetry: () => ref.invalidate(liftDayProvider(dayKey)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// "Add exercise" and "Load preset", side by side.
class _DayButtons extends StatelessWidget {
  const _DayButtons({required this.onAddExercise, required this.onLoadPreset});

  final VoidCallback onAddExercise;
  final VoidCallback onLoadPreset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: const Key('liftAddExercise'),
          onPressed: onAddExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
        OutlinedButton.icon(
          key: const Key('liftLoadPreset'),
          onPressed: onLoadPreset,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Load preset'),
        ),
      ],
    );
  }
}

/// Shown for a day without exercises.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({
    required this.isFuture,
    required this.onAddExercise,
    required this.onLoadPreset,
  });

  final bool isFuture;
  final VoidCallback onAddExercise;
  final VoidCallback onLoadPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        key: const Key('liftEmptyDay'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No exercises planned', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              isFuture
                  ? 'Plan this day: add exercises or load a preset.'
                  : 'Add exercises or load a preset to get started.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _DayButtons(
              onAddExercise: onAddExercise,
              onLoadPreset: onLoadPreset,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the day couldn't be loaded.
class _DayError extends StatelessWidget {
  const _DayError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load this day's exercises."),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('liftRetry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
