// Weigh-in flows shared by the Weight, Today and Dashboard screens: open the
// right dialog for a day, save, and offer Undo (or Try again on failure).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import 'weight_logic.dart';
import 'weight_providers.dart';
import 'widgets/weigh_in_dialog.dart';

/// Opens the weigh-in dialog for [dayKey] (default today) and saves it.
///
/// Edits the day's weigh-in when it has one ("Update today's weigh-in" for
/// today) instead of silently replacing it; otherwise adds a new one,
/// prefilled with the last weight.
Future<void> openWeighInDialog(
  BuildContext context,
  WidgetRef ref, {
  String? dayKey,
}) async {
  final today = dayKeyOf(ref.read(clockProvider)());
  final day = dayKey ?? today;
  // Wait for the real snapshot rather than falling back to {} while the
  // initial DB read is still in flight: an empty fallback would open in
  // "add" mode with no replace-warning and silently overwrite an existing
  // weigh-in, and Undo would then delete the day instead of restoring it.
  final weighIns = await ref.read(weighInsProvider.future);
  if (!context.mounted) return;
  final existingKg = weighIns[day];
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(weightRepositoryProvider);

  final input = await showWeighInDialog(
    context,
    today: today,
    initialDayKey: day,
    initialKg: existingKg,
    lastKg: latestWeighInKg(weighIns),
    existing: weighIns,
    title: existingKg != null && day == today
        ? "Update today's weigh-in"
        : null,
  );
  if (input == null) return;
  await saveWeighInWithUndo(
    messenger: messenger,
    repo: repo,
    before: weighIns,
    dayKey: input.dayKey,
    weightKg: input.weightKg,
    oldDayKey: existingKg != null ? day : null,
  );
}

/// Saves [weightKg] on [dayKey] (moving it from [oldDayKey] when editing)
/// and shows "Saved 82.4 kg" with Undo, which restores [before].
///
/// On failure logs the details and shows a short message with Try again.
/// Returns whether the save worked.
Future<bool> saveWeighInWithUndo({
  required ScaffoldMessengerState messenger,
  required WeightRepository repo,
  required Map<String, double> before,
  required String dayKey,
  required double weightKg,
  String? oldDayKey,
}) async {
  final previousOnDay = before[dayKey];
  final previousOld = oldDayKey == null || oldDayKey == dayKey
      ? null
      : before[oldDayKey];
  try {
    if (oldDayKey != null) {
      await repo.replace(oldDayKey, dayKey, weightKg);
    } else {
      await repo.upsert(dayKey, weightKg);
    }
  } catch (e, st) {
    debugPrint('Saving weigh-in failed: $e\n$st');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text("Couldn't save your weigh-in."),
          persist: false,
          action: SnackBarAction(
            label: 'Try again',
            onPressed: () => saveWeighInWithUndo(
              messenger: messenger,
              repo: repo,
              before: before,
              dayKey: dayKey,
              weightKg: weightKg,
              oldDayKey: oldDayKey,
            ),
          ),
        ),
      );
    return false;
  }

  Future<void> undo() async {
    try {
      // One atomic write: no delete-then-insert flicker, and it can't fail
      // halfway between removing the new value and restoring the old one.
      await repo.restore(
        dayKey: dayKey,
        weightKg: previousOnDay,
        oldDayKey: oldDayKey,
        oldWeightKg: previousOld,
      );
    } catch (e, st) {
      debugPrint('Undoing weigh-in failed: $e\n$st');
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't undo that. Please try again.")),
      );
    }
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Saved ${formatKg(weightKg)} kg'),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
  return true;
}
