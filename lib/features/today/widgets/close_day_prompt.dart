// "Done eating today?" prompt on Today: in the evening, offers to mark today
// as fully logged when it has food but isn't marked yet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/app_features.dart';
import '../../targets/engine/readiness.dart';
import '../../targets/targets_providers.dart';
import 'mark_day_complete.dart';

/// The day (dayKey) on which the close-the-day prompt was last dismissed or
/// answered. Kept in memory only, like the yesterday prompt's: it hides the
/// card for the rest of that day and comes back after an app restart.
final closeDayDismissedProvider = NotifierProvider<CloseDayDismissed, String?>(
  CloseDayDismissed.new,
);

/// Holds the dayKey on which the close-the-day prompt was dismissed.
class CloseDayDismissed extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String todayKey) => state = todayKey;
}

/// The card itself. The caller decides when to show it (see `showCloseDay`)
/// and gates it with `AppFeature.closeDayPrompt`.
class CloseDayPrompt extends ConsumerWidget {
  const CloseDayPrompt({super.key, required this.today});

  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onSecondaryContainer;
    final dismissed = ref.read(closeDayDismissedProvider.notifier);
    return Card(
      key: const Key('closeDayPrompt'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Done eating today?',
              style: theme.textTheme.titleSmall?.copyWith(color: onColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Mark it complete only if everything you ate is logged.',
              style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            if (ref.watch(featureEnabledProvider(AppFeature.targetInsights)))
              _ReadinessLine(color: onColor),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => dismissed.dismiss(today),
                    child: const Text('Not yet'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      dismissed.dismiss(today);
                      markDayComplete(
                        context,
                        ref,
                        dayKey: today,
                        message: 'Today marked as complete',
                      );
                    },
                    child: const Text('Mark complete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First line of what the targets still need (the same wording as the
/// check-in's readiness note). Renders nothing while loading or once the
/// user's own data counts fully.
class _ReadinessLine extends ConsumerWidget {
  const _ReadinessLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(targetReadinessProvider).value;
    if (readiness == null) return const SizedBox.shrink();
    final lines = readinessLines(readiness);
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        lines.first,
        key: const Key('closeDayReadiness'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
