// OWNER: Health Connect agent (C).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/day_key.dart';
import '../activity_providers.dart';
import '../health_source.dart';

/// Settings row: Health Connect status, grant permissions, sync now.
class HealthConnectSettingsTile extends ConsumerWidget {
  const HealthConnectSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(healthStatusProvider);
    final lastSync = ref.watch(healthSyncProvider).value;
    final controller = ref.read(healthSyncProvider.notifier);
    final now = ref.read(clockProvider)();

    final buttons = <Widget>[
      if (status.canInstall)
        FilledButton.icon(
          onPressed: controller.installHealthConnect,
          icon: const Icon(Icons.download),
          label: Text(
            status.availability == HcAvailability.updateRequired
                ? 'Update Health Connect'
                : 'Install Health Connect',
          ),
        ),
      if (status.kind == HealthStatusKind.needsPermission ||
          status.kind == HealthStatusKind.error)
        FilledButton(
          onPressed: status.syncing ? null : controller.connect,
          child: const Text('Connect'),
        ),
      if (status.kind == HealthStatusKind.ok &&
          status.historyAvailable &&
          !status.historyAuthorized)
        OutlinedButton(
          onPressed: status.syncing ? null : controller.connect,
          child: const Text('Allow full history'),
        ),
      if (status.kind == HealthStatusKind.ok ||
          status.kind == HealthStatusKind.error)
        OutlinedButton.icon(
          onPressed: status.syncing ? null : controller.syncNow,
          icon: status.syncing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Sync now'),
        ),
    ];

    return ListTile(
      leading: const Icon(Icons.favorite_outline),
      title: const Text('Health Connect'),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusLine(status)),
          Text(
            lastSync == null
                ? 'Never synced'
                : 'Last sync: ${_formatTime(lastSync, now)}',
          ),
          if (buttons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
            ),
        ],
      ),
    );
  }

  static String _statusLine(HealthConnectStatus s) {
    switch (s.kind) {
      case HealthStatusKind.checking:
        return s.syncing ? 'Syncing…' : 'Checking…';
      case HealthStatusKind.unavailable:
        return switch (s.availability) {
          HcAvailability.notInstalled => 'Health Connect is not installed.',
          HcAvailability.updateRequired => 'Health Connect needs an update.',
          _ => 'Health Connect is not available on this device.',
        };
      case HealthStatusKind.needsPermission:
        return 'Not connected. Allow access to steps and workouts.';
      case HealthStatusKind.ok:
        final history = s.historyAuthorized ? '' : ' · reads the last 30 days';
        return (s.syncing ? 'Connected · syncing…' : 'Connected') + history;
      case HealthStatusKind.error:
        return 'Sync failed: ${s.message ?? 'unknown error'}';
    }
  }

  static String _formatTime(DateTime t, DateTime now) {
    final time = DateFormat.Hm().format(t);
    if (dayKeyOf(t) == dayKeyOf(now)) return 'today $time';
    return '${DateFormat.MMMd().format(t)}, $time';
  }
}
