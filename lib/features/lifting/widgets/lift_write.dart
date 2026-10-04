// Snackbar helpers for the lifting screens' database writes.
import 'package:flutter/material.dart';

/// Shows [text], replacing any snackbar still showing.
void showLiftSnack(ScaffoldMessengerState messenger, String text) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

/// Runs [write]; when it throws, shows a snackbar instead of crashing.
/// Returns its value, or null when it failed.
Future<T?> guardLiftWrite<T>(
  ScaffoldMessengerState messenger,
  Future<T> Function() write,
) async {
  try {
    return await write();
  } catch (_) {
    showLiftSnack(messenger, "Couldn't save that. Try again.");
    return null;
  }
}
