// Picker for one of the user's presets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import '../screens/presets_screen.dart';

/// "Incline press · Pec deck · Dips": the exercises of [preset] in order, or
/// "No exercises" when it is empty.
String presetSubtitle(LiftPreset preset) => preset.exercises.isEmpty
    ? 'No exercises'
    : preset.exercises.map((e) => e.name).join(' · ');

/// Lets the user pick one of their presets. Resolves to null when dismissed.
Future<LiftPreset?> showPresetPicker(BuildContext context) {
  return showModalBottomSheet<LiftPreset>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _PresetPickerSheet(),
  );
}

class _PresetPickerSheet extends ConsumerWidget {
  const _PresetPickerSheet();

  void _openPresets(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const PresetsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presets = ref.watch(liftPresetsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Load preset', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  key: const Key('presetPickerManage'),
                  onPressed: () => _openPresets(context),
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),
          Flexible(
            child: presets.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load presets: $e'),
              ),
              data: (all) => all.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: all.length,
                      itemBuilder: (context, i) {
                        final preset = all[i];
                        return ListTile(
                          key: Key('presetPickerItem_${preset.id}'),
                          title: Text(preset.name),
                          subtitle: Text(
                            presetSubtitle(preset),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(preset),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No presets yet',
            key: Key('presetPickerEmpty'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'A preset is a named list of exercises, like "Push day", that '
            'you can load onto a day in one tap.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('presetPickerCreate'),
            onPressed: () => _openPresets(context),
            icon: const Icon(Icons.add),
            label: const Text('Create a preset'),
          ),
        ],
      ),
    );
  }
}
