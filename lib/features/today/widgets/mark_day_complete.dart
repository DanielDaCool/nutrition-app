// Shared "mark a day fully logged, with Undo" action for the Today prompts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../food/food_providers.dart';

/// Marks [dayKey] as fully logged and shows [message] with an Undo action.
/// On failure shows a "Couldn't save that." snackbar with a retry instead of
/// letting the error go unhandled; Undo failures retry the same way.
Future<void> markDayComplete(
  BuildContext context,
  WidgetRef ref, {
  required String dayKey,
  required String message,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(foodRepositoryProvider);

  Future<void> setFullyLogged(bool value, VoidCallback onRetry) async {
    try {
      await repo.setFullyLogged(dayKey, value);
    } catch (e, st) {
      debugPrint('Setting $dayKey fully-logged failed: $e\n$st');
      messenger.showSnackBar(
        SnackBar(
          content: const Text("Couldn't save that."),
          persist: false,
          action: SnackBarAction(label: 'Try again', onPressed: onRetry),
        ),
      );
    }
  }

  void undo() => setFullyLogged(false, undo);
  void markComplete() => setFullyLogged(true, markComplete);

  try {
    await repo.setFullyLogged(dayKey, true);
  } catch (e, st) {
    debugPrint('Marking $dayKey complete failed: $e\n$st');
    messenger.showSnackBar(
      SnackBar(
        content: const Text("Couldn't save that."),
        persist: false,
        action: SnackBarAction(label: 'Try again', onPressed: markComplete),
      ),
    );
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
}
