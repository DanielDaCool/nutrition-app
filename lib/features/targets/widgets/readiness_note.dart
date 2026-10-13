// OWNER: engine agent (A).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/readiness.dart';
import '../targets_providers.dart';

/// What the engine still needs before the target adapts to the user's own
/// data. Renders nothing while loading, on error, without a profile or
/// weigh-in, and once the user's own data counts fully.
///
/// The caller gates it with `AppFeature.targetInsights`.
class ReadinessNote extends ConsumerWidget {
  const ReadinessNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(targetReadinessProvider).value;
    if (readiness == null) return const SizedBox.shrink();
    final lines = readinessLines(readiness);
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const Key('readinessNote'),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
