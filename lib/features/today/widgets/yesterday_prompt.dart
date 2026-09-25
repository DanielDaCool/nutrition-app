// "Was yesterday complete?" prompt on Today: asks once a day to mark
// yesterday as fully logged when it has food but isn't marked yet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/day_key.dart';
import '../../food/food_providers.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(foodRepositoryProvider);
    ref.read(yesterdayPromptAnsweredProvider.notifier).answer(today);
    try {
      await repo.setFullyLogged(yesterday, true);
    } catch (e, st) {
      debugPrint('Marking yesterday complete failed: $e\n$st');
      messenger.showSnackBar(
        SnackBar(
          content: const Text("Couldn't save that."),
          persist: false,
          action: SnackBarAction(
            label: 'Try again',
            onPressed: () => repo.setFullyLogged(yesterday, true),
          ),
        ),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Yesterday marked as complete'),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.setFullyLogged(yesterday, false),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(yesterdayPromptAnsweredProvider) == today) {
      return const SizedBox.shrink();
    }
    final yesterday = addDays(today, -1);
    final intake = ref.watch(dayIntakeProvider(yesterday)).value;
    final hasFood =
        intake != null && (intake.byMeal.isNotEmpty || intake.total.kcal > 0);
    if (!hasFood || intake.fullyLogged) return const SizedBox.shrink();

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
