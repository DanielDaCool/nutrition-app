// Settings -> Choose features: one checkbox per feature the user may switch
// off. Switching off only hides the feature; its data and settings are kept.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/feature_choices_repository.dart';

const _order = [
  AppFeature.activity,
  AppFeature.workouts,
  AppFeature.recipes,
  AppFeature.yesterdayPrompt,
  AppFeature.dashboard,
  AppFeature.walkReminders,
  AppFeature.savedMeals,
  AppFeature.quickCalories,
  AppFeature.closeDayPrompt,
  AppFeature.targetInsights,
  AppFeature.csvExport,
];

/// Lists the features the user can switch on or off on this platform.
class ChooseFeaturesScreen extends ConsumerWidget {
  const ChooseFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWeb = ref.watch(isWebProvider);
    final features = [
      for (final f in [
        ..._order,
        ...AppFeature.values.where((f) => !_order.contains(f)),
      ])
        if (f.choosableOn(isWeb: isWeb)) f,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose features')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final f in features)
            CheckboxListTile(
              key: Key('feature-${f.storageKey}'),
              title: Text(f.label),
              subtitle: Text(f.description),
              value: ref.watch(featureEnabledProvider(f)),
              onChanged: (on) =>
                  setFeatureEnabled(ref.read(databaseProvider), f, on ?? false),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Turning a feature off only hides it; your data is kept.',
            ),
          ),
        ],
      ),
    );
  }
}
