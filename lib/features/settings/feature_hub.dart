// OWNER: engine agent (A).
// Feature hub tab of Settings: one switch per AppFeature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import 'feature_flags.dart';

/// Lists every [AppFeature] with a switch to turn it on or off on this
/// device. A feature that doesn't exist on this platform is shown off and
/// disabled.
class FeatureHub extends ConsumerWidget {
  const FeatureHub({super.key});

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    AppFeature feature,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(featureFlagsProvider.notifier)
          .setEnabled(feature, enabled);
    } catch (e, s) {
      // The notifier already put the switch back.
      debugPrint('Saving feature flag failed: $e\n$s');
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that setting")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeb = ref.watch(isWebProvider);
    final flags = ref.watch(featureFlagsProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Turn parts of the app on or off. Applies to this device only.',
          ),
        ),
        for (final feature in AppFeature.values)
          if (feature.availableOn(isWeb: isWeb))
            SwitchListTile(
              key: Key('feature-${feature.storageKey}'),
              title: Text(feature.label),
              subtitle: Text(feature.description),
              value: flags[feature] ?? feature.defaultEnabled,
              onChanged: (v) => _set(context, ref, feature, v),
            )
          else
            SwitchListTile(
              key: Key('feature-${feature.storageKey}'),
              title: Text(feature.label),
              subtitle: Text(
                '${feature.description} Not available in the web app.',
              ),
              value: false,
              onChanged: null,
            ),
      ],
    );
  }
}
