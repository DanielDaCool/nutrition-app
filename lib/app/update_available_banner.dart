// A banner telling the user a newer release is out, with a link to the
// latest release's APK. See lib/core/update_check.dart for the version
// comparison and lib/app/providers.dart for when it shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';

const _downloadUrl =
    'https://github.com/DanielDaCool/nutrition-app/releases/latest/download/nutrition.apk';

/// The "Update available" banner. Only rendered while
/// [updateAvailableTagProvider] is non-null; callers check that first so
/// hiding it removes it from the layout entirely rather than collapsing to
/// zero size.
class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = ref.watch(updateAvailableTagProvider);
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onSecondaryContainer;
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, color: onContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nutrition $tag is available to download.',
                style: TextStyle(color: onContainer),
              ),
            ),
            TextButton(
              key: const Key('updateBannerUpdate'),
              onPressed: () => launchUrl(
                Uri.parse(_downloadUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Update'),
            ),
            TextButton(
              key: const Key('updateBannerNotNow'),
              onPressed: () =>
                  ref.read(updateDismissedTagProvider.notifier).dismiss(tag!),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
