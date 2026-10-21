// The one-time-per-start popup telling the user a newer release is out. Its
// "Not now" dismisses the release, which also hides the banner
// (update_available_banner.dart); closing it any other way leaves the banner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';
import 'update_available_banner.dart';

Future<void> showUpdateAvailableDialog(
  BuildContext context,
  WidgetRef ref,
  String tag,
) async {
  final choice = await showDialog<_UpdateChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update available'),
      content: Text('Nutrition $tag is available to download.'),
      actions: [
        TextButton(
          key: const Key('updateDialogNotNow'),
          onPressed: () => Navigator.pop(context, _UpdateChoice.notNow),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const Key('updateDialogUpdate'),
          onPressed: () => Navigator.pop(context, _UpdateChoice.update),
          child: const Text('Update'),
        ),
      ],
    ),
  );
  switch (choice) {
    case _UpdateChoice.notNow:
      await ref.read(updateDismissedTagProvider.notifier).dismiss(tag);
    case _UpdateChoice.update:
      await launchUrl(
        Uri.parse(updateDownloadUrl),
        mode: LaunchMode.externalApplication,
      );
    case null:
      break;
  }
}

enum _UpdateChoice { notNow, update }
