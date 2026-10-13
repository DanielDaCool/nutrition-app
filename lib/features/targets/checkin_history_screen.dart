// OWNER: engine agent (A).
// Past check-ins: every stored target with the numbers behind it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/day_key.dart';
import '../../domain/models.dart';
import '../settings/error_retry.dart';
import 'engine/explain.dart';
import 'engine/history.dart';
import 'targets_providers.dart';
import 'widgets/maintenance_confidence.dart';

/// Newest-first list of past check-ins. Each row expands to the plain-English
/// "why" that was stored with it; rows with nothing readable say so.
class CheckInHistoryScreen extends ConsumerWidget {
  const CheckInHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(checkInHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Check-in history failed: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorRetry(
                message: "Couldn't load your check-ins",
                onRetry: () => ref.invalidate(checkInHistoryProvider),
              ),
            ),
          );
        },
        data: (entries) => entries.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No check-ins yet. Your targets show up here once you '
                    'have a profile and a weigh-in.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _EntryTile(entries[i]),
              ),
      ),
    );
  }
}

String _methodLabel(TargetMethod m) => switch (m) {
  TargetMethod.formula => 'Formula estimate',
  TargetMethod.blended => 'Formula + your data',
  TargetMethod.adaptive => 'From your data',
};

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final CheckInEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry.explanation;
    final date = DateFormat('EEE d MMM y')
        .format(startOfDay(entry.effectiveFrom));
    final kcalText = kcal(entry.macros.kcal);
    final subtitle = entry.skipped
        ? 'Skipped, kept $kcalText'
        : '$kcalText · maintenance ${kcal(entry.maintenanceKcal)} · '
              '${_methodLabel(entry.method)}';
    return ExpansionTile(
      key: PageStorageKey(entry.effectiveFrom),
      title: Text(date),
      subtitle: Text(subtitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: e == null
          ? const [Text('No details saved for this check-in.')]
          : [
              if (entry.skipped)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'You skipped this check-in, so the numbers below are '
                    'from the target that was kept.',
                  ),
                ),
              for (final line in explainLines(e))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              MaintenanceConfidenceLine(explanation: e),
            ],
    );
  }
}
