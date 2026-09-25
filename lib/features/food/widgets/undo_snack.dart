// Confirmation snackbars with Undo for the food screens.

import 'package:flutter/material.dart';

import '../data/food_repository.dart';

/// Shows [text] with an Undo button that runs [onUndo]. Replaces any snackbar
/// still showing and hides itself after a few seconds.
void showUndoSnack(
  ScaffoldMessengerState messenger,
  String text,
  VoidCallback onUndo,
) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
}

/// "Added …" with an Undo that deletes the new [entryIds] again.
void showAddedSnack(
  ScaffoldMessengerState messenger,
  FoodRepository repo,
  String text,
  List<int> entryIds,
) => showUndoSnack(messenger, text, () => repo.deleteEntries(entryIds));

/// A plain message (no action), replacing any snackbar still showing.
void showInfoSnack(ScaffoldMessengerState messenger, String text) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
