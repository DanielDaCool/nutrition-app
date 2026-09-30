// OWNER: engine agent (A). Contract stub: keep the class name and constructor.
// Weekly check-in screen: current vs. recommended targets with the engine's
// explanation; Accept saves the recommendation, Skip keeps the current one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../settings/error_retry.dart';
import '../settings/setup_screen.dart';
import 'engine/engine.dart';
import 'engine/explain.dart';
import 'targets_providers.dart';
import 'targets_repository.dart';

/// Weekly check-in: shows the new recommendation and why, user accepts it.
///
/// Pops itself after either action succeeds; a save error is shown in a
/// snackbar and the screen stays open. Skip only shows when there is a
/// current target to keep.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _saving = false;

  /// Runs [action]; on success shows the message it returns and closes the
  /// screen. A null message means the action handled the outcome itself and
  /// the screen stays open.
  Future<void> _finish(Future<String?> Function() action) async {
    setState(() => _saving = true);
    try {
      final message = await action();
      if (!mounted || message == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).maybePop();
    } catch (e, s) {
      debugPrint('Check-in save failed: $e\n$s');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Couldn't save, nothing changed"),
          action: SnackBarAction(
            label: 'Try again',
            onPressed: () {
              if (mounted) _finish(action);
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Saves [shown], the recommendation on screen. If the day has rolled over
  /// since it was worked out (opened before midnight, accepted after), it is
  /// worked out again for today: saved straight away when the numbers are
  /// unchanged, otherwise the screen refreshes so the new numbers can be
  /// reviewed first. Returns the success message, or null when refreshed.
  Future<String?> _accept(Recommendation shown, TargetsRepository repo) async {
    var rec = shown;
    if (rec.effectiveFrom != repo.today) {
      final fresh = await repo.recommendToday();
      if (fresh == null) throw StateError('No recommendation for today');
      if (!_sameNumbers(shown, fresh)) {
        ref.invalidate(checkInRecommendationProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "It's a new day, so your targets were worked out again. "
                'Check them and tap Accept.',
              ),
            ),
          );
        }
        return null;
      }
      rec = fresh;
    }
    await repo.saveRecommendation(rec);
    return 'New target: ${kcal(rec.macros.kcal)}';
  }

  static bool _sameNumbers(Recommendation a, Recommendation b) =>
      a.macros.kcal == b.macros.kcal &&
      a.macros.proteinG == b.macros.proteinG &&
      a.macros.fatG == b.macros.fatG &&
      a.macros.carbsG == b.macros.carbsG &&
      a.maintenanceKcal.round() == b.maintenanceKcal.round() &&
      a.method == b.method;

  @override
  Widget build(BuildContext context) {
    final rec = ref.watch(checkInRecommendationProvider);
    final current = ref.watch(currentTargetsProvider);
    final repo = ref.read(targetsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly check-in')),
      body: rec.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Check-in recommendation failed: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorRetry(
                message: "Couldn't work out your new targets",
                onRetry: () => ref.invalidate(checkInRecommendationProvider),
              ),
            ),
          );
        },
        data: (r) => r == null
            ? const _NothingToReview()
            : _body(context, r, current.value, repo),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    Recommendation r,
    DailyTargets? cur,
    TargetsRepository repo,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Comparison(current: cur, next: r),
        const SizedBox(height: 16),
        Text('Why', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final line in explainLines(r.explanation))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _saving ? null : () => _finish(() => _accept(r, repo)),
          child: const Text('Accept'),
        ),
        if (cur != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving
                ? null
                : () => _finish(() async {
                    await repo.keepCurrentTarget();
                    return 'Keeping ${kcal(cur.macros.kcal)}';
                  }),
            child: const Text('Skip, keep my current targets'),
          ),
        ],
      ],
    );
  }
}

/// No recommendation possible: says what is missing and offers the fix.
class _NothingToReview extends ConsumerWidget {
  const _NothingToReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfile = ref.watch(profileProvider).value != null;
    final big = const Size.fromHeight(48);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasProfile
                ? 'Log a weigh-in on Today and your targets show up here.'
                : 'Set up your profile and log your weight to get your '
                      'targets.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (!hasProfile)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: big),
              onPressed: () => openSetup(context),
              child: const Text('Set up'),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: big),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }
}

String _methodLabel(TargetMethod m) => switch (m) {
  TargetMethod.formula => 'Formula estimate',
  TargetMethod.blended => 'Formula + your data',
  TargetMethod.adaptive => 'From your data',
};

final _thousands = NumberFormat.decimalPattern('en_US');

/// The change from [nowValue] to [newValue] in whole units: "+120 kcal",
/// "−80 g" (true minus sign) or "same"; the sign is null when unchanged.
({String text, int sign}) formatChange(
  double nowValue,
  double newValue,
  String unit,
) {
  final d = newValue.round() - nowValue.round();
  if (d == 0) return (text: 'same', sign: 0);
  final sign = d > 0 ? '+' : '−';
  return (text: '$sign${_thousands.format(d.abs())} $unit', sign: d.sign);
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.current, required this.next});

  final DailyTargets? current;
  final Recommendation next;

  @override
  Widget build(BuildContext context) {
    final c = current;
    final n = next.macros;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget change(double? nowValue, double newValue, String unit) {
      if (nowValue == null) return const SizedBox.shrink();
      final ch = formatChange(nowValue, newValue, unit);
      return Text(
        ch.text,
        textAlign: TextAlign.end,
        style: theme.textTheme.bodySmall?.copyWith(
          color: switch (ch.sign) {
            0 => scheme.onSurfaceVariant,
            > 0 => scheme.primary,
            _ => scheme.tertiary,
          },
          fontWeight: FontWeight.w600,
        ),
      );
    }

    TableRow row(
      String label,
      double? nowValue,
      double newValue,
      String Function(double) fmt,
      String unit, {
      bool bold = false,
    }) {
      final style = bold
          ? theme.textTheme.titleMedium
          : theme.textTheme.bodyMedium;
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(label, style: style),
          ),
          Text(
            nowValue == null ? '—' : fmt(nowValue),
            style: style,
            textAlign: TextAlign.end,
          ),
          Text(fmt(newValue), style: style, textAlign: TextAlign.end),
          change(nowValue, newValue, unit),
        ],
      );
    }

    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    String g(double v) => '${v.round()} g';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {0: FlexColumnWidth(1.3)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    for (final t in ['Current', 'New', if (c != null) 'Change'])
                      Text(t, style: headerStyle, textAlign: TextAlign.end),
                    if (c == null) const SizedBox.shrink(),
                  ],
                ),
                row(
                  'Calories',
                  c?.macros.kcal,
                  n.kcal,
                  kcal,
                  'kcal',
                  bold: true,
                ),
                row('Protein', c?.macros.proteinG, n.proteinG, g, 'g'),
                row('Fat', c?.macros.fatG, n.fatG, g, 'g'),
                row('Carbs', c?.macros.carbsG, n.carbsG, g, 'g'),
                row(
                  'Maintenance',
                  c?.maintenanceKcal,
                  next.maintenanceKcal,
                  kcal,
                  'kcal',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_methodLabel(next.method), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
