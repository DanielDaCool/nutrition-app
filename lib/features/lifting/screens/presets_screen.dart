// "Presets": create, edit and delete named lists of exercises.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models.dart';
import '../lifting_providers.dart';
import '../widgets/preset_picker.dart' show presetSubtitle;
import 'preset_edit_screen.dart';

/// List of the user's presets.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  void _edit(BuildContext context, [LiftPreset? preset]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PresetEditScreen(existing: preset),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LiftPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${preset.name}"?'),
        content: const Text(
          'Days you already loaded it onto keep their exercises.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('presetDeleteConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(liftingRepositoryProvider).deletePreset(preset.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(liftPresetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Presets')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('presetsAddFab'),
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('New preset'),
      ),
      body: presets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load presets: $e'),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No presets yet.\n'
                  'A preset is a named list of exercises, like "Push day", '
                  'that you can load onto a day in one tap.',
                  key: Key('presetsEmpty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            // Room for the FAB under the last row.
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: all.length,
            itemBuilder: (context, i) {
              final preset = all[i];
              return ListTile(
                key: Key('presetTile_${preset.id}'),
                title: Text(preset.name),
                subtitle: Text(
                  presetSubtitle(preset),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _edit(context, preset),
                trailing: IconButton(
                  key: Key('presetDelete_${preset.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, ref, preset),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
