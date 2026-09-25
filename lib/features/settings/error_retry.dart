// Small shared error row: a friendly message plus a "Try again" button.
import 'package:flutter/material.dart';

/// A short friendly error line with a "Try again" button. Log the details
/// with debugPrint before showing it; never show raw exception text.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
