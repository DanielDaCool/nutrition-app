// A banner on iPhone Safari suggesting the user add Nutrition to their Home
// Screen, where its storage survives longer than a plain browser tab's. See
// lib/core/install_hint.dart for when it shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// The "Add to Home Screen" banner. Only rendered while
/// [showInstallHintProvider] is true; callers check that first so hiding it
/// removes it from the layout entirely rather than collapsing to zero size.
class InstallHintBanner extends ConsumerWidget {
  const InstallHintBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.ios_share, color: onContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add Nutrition to your Home Screen to keep your data safe.',
                style: TextStyle(color: onContainer),
              ),
            ),
            TextButton(
              key: const Key('installHintHow'),
              onPressed: () => _showHowDialog(context),
              child: const Text('How?'),
            ),
            TextButton(
              key: const Key('installHintNotNow'),
              onPressed: () =>
                  ref.read(installHintDismissedAtProvider.notifier).dismiss(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Home Screen'),
        content: const Text(
          '1. Tap the Share button in Safari\'s toolbar.\n'
          '2. Choose "Add to Home Screen".\n'
          '3. From now on, open Nutrition from that icon instead of Safari.\n'
          '\n'
          'The Home Screen app has its own storage, separate from Safari. '
          'If you already have data here, export it from Settings first, '
          'then import it in the installed app.',
        ),
        actions: [
          TextButton(
            key: const Key('installHintHowOk'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
