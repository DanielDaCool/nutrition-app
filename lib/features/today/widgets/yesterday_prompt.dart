// "Was yesterday complete?" prompt on Today: asks once a day to mark
// yesterday as fully logged when it has food but isn't marked yet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/day_key.dart';
import '../../dashboard/dashboard_providers.dart';
import '../../food/food_providers.dart';
import '../close_day_logic.dart';
import 'mark_day_complete.dart';

/// The day (today's dayKey) on which the prompt was last answered. Kept in
/// memory only: answering hides it for the rest of that day.
final yesterdayPromptAnsweredProvider =
    NotifierProvider<YesterdayPromptAnswered, String?>(
      YesterdayPromptAnswered.new,
    );

/// Holds the dayKey on which the yesterday prompt was answered.
class YesterdayPromptAnswered extends Notifier<String?> {
  @override
  String? build() => null;

  void answer(String todayKey) => state = todayKey;
}

/// Whether the yesterday prompt has something to ask on [today] (a dayKey):
/// not answered yet, yesterday has food and isn't complete, and the app's
/// data reaches back to yesterday. Also lets Today show one prompt at a time.
final yesterdayPromptVisibleProvider = Provider.family<bool, String>((
  ref,
  today,
) {
  if (ref.watch(yesterdayPromptAnsweredProvider) == today) return false;
  final yesterday = addDays(today, -1);
  final intake = ref.watch(dayIntakeProvider(yesterday)).value;
  if (!dayHasFood(intake) || intake!.fullyLogged) return false;
  // Nothing to ask about when the app's own usage doesn't reach back to
  // yesterday at all (e.g. right after onboarding, on the very first day).
  final earliest = ref.watch(earliestDataDayProvider).value;
  return earliest != null && earliest.compareTo(yesterday) <= 0;
});

/// One-line prompt shown on [today] when yesterday has food entries but
/// isn't marked fully logged. Hidden once answered that day.
class YesterdayPrompt extends ConsumerWidget {
  const YesterdayPrompt({super.key, required this.today});

  final String today;

  Future<void> _markComplete(
    BuildContext context,
    WidgetRef ref,
    String yesterday,
  ) async {
    ref.read(yesterdayPromptAnsweredProvider.notifier).answer(today);
    await markDayComplete(
      context,
      ref,
      dayKey: yesterday,
      message: 'Yesterday marked as complete',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(yesterdayPromptVisibleProvider(today))) {
      return const SizedBox.shrink();
    }
    final yesterday = addDays(today, -1);

    final theme = Theme.of(context);
    return Card(
      key: const Key('yesterdayPrompt'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        // One line when it fits, buttons wrap below on narrow phones.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Was yesterday complete?',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => ref
                      .read(yesterdayPromptAnsweredProvider.notifier)
                      .answer(today),
                  child: const Text('Not really'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _markComplete(context, ref, yesterday),
                  child: const Text('Yes, mark it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
