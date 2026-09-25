// OWNER: engine agent (A). Contract stub: keep the class name and constructor.
// Weekly check-in screen: current vs. recommended targets with the engine's
// explanation; Accept saves the recommendation, Skip keeps the current one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import 'engine/engine.dart';
import 'engine/explain.dart';
import 'targets_providers.dart';

/// Weekly check-in: shows the new recommendation and why, user accepts it.
///
/// Pops itself after either action succeeds; a save error is shown in a
/// snackbar and the screen stays open.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _saving = false;

  Future<void> _finish(Future<void> Function() action, String message) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(checkInRecommendationProvider);
    final current = ref.watch(currentTargetsProvider);
    final repo = ref.read(targetsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly check-in')),
      body: rec.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not compute targets: $e')),
        data: (r) {
          if (r == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Set up your profile in Settings and log a weigh-in to get '
                'your targets.',
              ),
            );
          }
          final cur = current.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Comparison(current: cur, next: r),
              const SizedBox(height: 16),
              Text('Why', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final line in explainLines(r.explanation))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () => _finish(
                        () => repo.saveRecommendation(r),
                        'New targets saved',
                      ),
                child: const Text('Accept'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => _finish(
                        repo.keepCurrentTarget,
                        'Keeping your current targets',
                      ),
                child: const Text('Skip'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _methodLabel(TargetMethod m) => switch (m) {
  TargetMethod.formula => 'Formula estimate',
  TargetMethod.blended => 'Formula + your data',
  TargetMethod.adaptive => 'From your data',
};

class _Comparison extends StatelessWidget {
  const _Comparison({required this.current, required this.next});

  final DailyTargets? current;
  final Recommendation next;

  @override
  Widget build(BuildContext context) {
    final c = current;
    final n = next.macros;
    TableRow row(String label, String? now, String nw, {bool bold = false}) {
      final style = bold
          ? Theme.of(context).textTheme.titleMedium
          : Theme.of(context).textTheme.bodyMedium;
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label, style: style),
          ),
          Text(now ?? '—', style: style, textAlign: TextAlign.end),
          Text(nw, style: style, textAlign: TextAlign.end),
        ],
      );
    }

    String g(double v) => '${v.round()} g';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {0: FlexColumnWidth(1.4)},
              children: [
                row('', 'Current', 'New'),
                row(
                  'Calories',
                  c == null ? null : kcal(c.macros.kcal),
                  kcal(n.kcal),
                  bold: true,
                ),
                row(
                  'Protein',
                  c == null ? null : g(c.macros.proteinG),
                  g(n.proteinG),
                ),
                row('Fat', c == null ? null : g(c.macros.fatG), g(n.fatG)),
                row(
                  'Carbs',
                  c == null ? null : g(c.macros.carbsG),
                  g(n.carbsG),
                ),
                row(
                  'Maintenance',
                  c == null ? null : kcal(c.maintenanceKcal),
                  kcal(next.maintenanceKcal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _methodLabel(next.method),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
