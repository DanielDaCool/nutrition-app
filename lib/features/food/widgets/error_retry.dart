// A short error message with a "Try again" button, for food screens whose
// data failed to load.

import 'package:flutter/material.dart';

import 'food_format.dart';

/// Shows [message] plus a friendly hint for [error], and "Try again".
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.error,
    this.stackTrace,
    required this.onRetry,
    this.message = 'Could not load this.',
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  /// What failed, in a few words, e.g. "Could not load your meals."
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = friendlyError(error, stackTrace);
    // The generic message adds nothing next to "Could not load ...".
    final generic = detail.startsWith('Something went wrong');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              generic ? message : '$message $detail',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('try-again'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
