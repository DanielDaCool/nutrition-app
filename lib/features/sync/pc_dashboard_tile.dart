// Settings entry for the PC dashboard: paste a GitHub token once, then sync
// pushes a full data export to a private gist the dashboard reads.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pc_sync_repository.dart';
import 'sync_providers.dart';

class PcDashboardTile extends ConsumerStatefulWidget {
  const PcDashboardTile({super.key});

  @override
  ConsumerState<PcDashboardTile> createState() => _PcDashboardTileState();
}

class _PcDashboardTileState extends ConsumerState<PcDashboardTile> {
  bool _busy = false;

  Future<void> _editToken() async {
    final current = await ref.read(pcSyncRepositoryProvider).readToken();
    if (!mounted) return;
    final controller = TextEditingController(text: current ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a token at github.com/settings/tokens with only the '
              '"gist" scope, then paste it here. It stays on this phone.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('githubTokenField'),
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Token'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('saveTokenButton'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await ref.read(pcSyncRepositoryProvider).saveToken(controller.text);
    ref.invalidate(syncTokenProvider);
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(pcSyncRepositoryProvider).syncNow();
      ref.invalidate(syncGistIdProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Synced. The dashboard now has your data.')),
      );
    } on PcSyncException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Sync failed: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(syncTokenProvider).value;
    final gistId = ref.watch(syncGistIdProvider).value;
    final hasToken = token != null && token.isNotEmpty;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.desktop_windows_outlined),
          title: const Text('PC dashboard'),
          subtitle: Text(
            hasToken
                ? (gistId == null
                      ? 'Token saved. Tap sync to send your data.'
                      : 'Synced. Tap sync to refresh the dashboard.')
                : 'Add a GitHub token to enable',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editToken,
        ),
        if (hasToken)
          ListTile(
            leading: const SizedBox(width: 24),
            title: const Text('Sync now'),
            trailing: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _busy ? null : _sync,
          ),
      ],
    );
  }
}
