// Today screen's calorie card: kcal remaining against the target that was in
// effect on the shown day, and protein/fat/carb progress bars.
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../../food/food_providers.dart';
import '../../settings/setup_screen.dart';
import '../../targets/targets_providers.dart';
import '../../weight/table_watch.dart';
import '../../weight/weight_providers.dart';
import '../../weight/widgets/weigh_in_dialog.dart';

final _kcalFormat = NumberFormat.decimalPattern('en_US');

/// Formats kcal rounded to a whole number with thousands separators.
String formatKcal(double kcal) => _kcalFormat.format(kcal.round());

/// All accepted target rows (with macros), oldest `effectiveFrom` first.
///
/// Separate from `dashboard`'s `targetHistoryProvider` because that one
/// drops the macro breakdown this card needs; both read the same table.
final _targetHistoryProvider = StreamProvider<List<DailyTargets>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.targetHistory)
    ..orderBy([
      (t) => OrderingTerm.asc(t.effectiveFrom),
      (t) => OrderingTerm.asc(t.id),
    ]);
  return watchTables(db, [db.targetHistory], () async {
    final rows = await query.get();
    return [
      for (final r in rows)
        DailyTargets(
          effectiveFrom: r.effectiveFrom,
          macros: Macros(
            kcal: r.kcal,
            proteinG: r.proteinG,
            fatG: r.fatG,
            carbsG: r.carbsG,
          ),
          maintenanceKcal: r.maintenanceKcal,
          method: TargetMethod.values[r.method],
        ),
    ];
  });
});

/// The target in effect on [dayKey] ([targets] sorted by `effectiveFrom`
/// ascending; later entries win ties). Null if none applies yet.
DailyTargets? _targetOn(List<DailyTargets> targets, String dayKey) {
  DailyTargets? result;
  for (final t in targets) {
    if (t.effectiveFrom.compareTo(dayKey) <= 0) {
      result = t;
    } else {
      break;
    }
  }
  return result;
}

/// Targets in effect on [dayKey]: today's live target (which may still be
/// creating itself) for today, or a lookup into target history for a past
/// day.
final _targetsForDayProvider = Provider.family<AsyncValue<DailyTargets?>, String>(
  (ref, dayKey) {
    final today = dayKeyOf(ref.watch(clockProvider)());
    if (dayKey == today) return ref.watch(currentTargetsProvider);
    return ref.watch(_targetHistoryProvider).whenData(
      (targets) => _targetOn(targets, dayKey),
    );
  },
);

/// Target minus intake for [dayKey], with macro progress bars.
///
/// Before there are targets it says what is missing and offers the fix:
/// "Set up" (opens the setup screen) without a profile, "Log weigh-in"
/// without a weigh-in. Load errors show a short message and "Try again".
class CalorieCard extends ConsumerWidget {
  const CalorieCard({super.key, required this.dayKey});

  /// Day shown (`YYYY-MM-DD`, local time).
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayKeyOf(ref.read(clockProvider)());
    final isToday = dayKey == today;
    final targetsAsync = ref.watch(_targetsForDayProvider(dayKey));
    final intakeAsync = ref.watch(dayIntakeProvider(dayKey));
    final targets = targetsAsync.value;
    final intake = intakeAsync.value;

    if (targetsAsync.hasError && targets == null) {
      debugPrint('CalorieCard: targets failed: ${targetsAsync.error}');
      return _MessageCard(
        key: const Key('calorieCardError'),
        icon: Icons.error_outline,
        text: "Couldn't load your targets",
        actionLabel: 'Try again',
        onAction: () => isToday
            ? ref.invalidate(currentTargetsProvider)
            : ref.invalidate(_targetHistoryProvider),
      );
    }
    if (intakeAsync.hasError && intake == null) {
      debugPrint('CalorieCard: food log failed: ${intakeAsync.error}');
      return _MessageCard(
        key: const Key('calorieCardError'),
        icon: Icons.error_outline,
        text: "Couldn't load what you ate",
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(dayIntakeProvider(dayKey)),
      );
    }
    if (!targetsAsync.hasValue) return const _LoadingCard();
    if (targets == null) {
      // Today: guide the user through whatever setup is missing. A past
      // day just never had a target in effect yet (e.g. before the profile
      // was set up) — nothing to fix, so say so plainly.
      return isToday
          ? const _NoTargetsCard()
          : const _MessageCard(
              key: Key('noTargetForDayCard'),
              icon: Icons.info_outline,
              text: 'No target was set for this day',
            );
    }
    // Intake still loading: show the loading state rather than treating it
    // as "0 eaten", which would flash a wrong "full target remaining".
    if (!intakeAsync.hasValue) return const _LoadingCard();
    return _TargetsCard(target: targets.macros, eaten: intake!.total);
  }
}

/// No targets yet: tells the user the one thing that is missing.
class _NoTargetsCard extends ConsumerWidget {
  const _NoTargetsCard();

  Future<void> _logWeighIn(BuildContext context, WidgetRef ref) async {
    final today = dayKeyOf(ref.read(clockProvider)());
    final input = await showWeighInDialog(context, today: today);
    if (input == null) return;
    try {
      await ref
          .read(weightRepositoryProvider)
          .upsert(input.dayKey, input.weightKg);
    } catch (e, s) {
      debugPrint('CalorieCard: saving weigh-in failed: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save your weigh-in")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final weighIns = ref.watch(weighInsProvider);
    if (profile.hasError) {
      debugPrint('CalorieCard: profile failed: ${profile.error}');
      return _MessageCard(
        key: const Key('calorieCardError'),
        icon: Icons.error_outline,
        text: "Couldn't load your targets",
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(profileProvider),
      );
    }
    if (!profile.hasValue) return const _LoadingCard();
    if (profile.value == null) {
      return _MessageCard(
        key: const Key('noTargetsCard'),
        icon: Icons.flag_outlined,
        text: 'Get your daily calorie target',
        subtitle: 'Takes about a minute.',
        actionLabel: 'Set up',
        onAction: () => openSetup(context),
      );
    }
    if (weighIns.value?.isNotEmpty ?? false) {
      // currentTargetsProvider already resolved to null with a profile and
      // a weigh-in in place, so this is a real terminal state — e.g. every
      // target is dated in the future, or every weigh-in is dated after
      // today (say, after a timezone change) — not still being worked out.
      // Showing a spinner here would never resolve.
      return _MessageCard(
        key: const Key('noCurrentTargetCard'),
        icon: Icons.error_outline,
        text: 'No target is active for today',
        subtitle: "Check your weigh-in and target dates, or try again.",
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(currentTargetsProvider),
      );
    }
    return _MessageCard(
      key: const Key('noWeighInCard'),
      icon: Icons.monitor_weight_outlined,
      text: 'Log your first weigh-in to get your targets',
      subtitle: 'Use the weigh-in box below, or tap the button.',
      actionLabel: 'Log weigh-in',
      onAction: () => _logWeighIn(context, ref),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

/// Remaining (or over) kcal, target vs. eaten, and macro bars.
class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.target, required this.eaten});

  final Macros target;
  final Macros eaten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remaining = target.kcal - eaten.kcal;
    final over = remaining.round() < 0;
    return Card(
      key: const Key('calorieCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatKcal(remaining.abs()),
                        key: const Key('kcalRemaining'),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: over ? scheme.error : scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        over ? 'kcal over target' : 'kcal remaining',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target ${formatKcal(target.kcal)} kcal',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Eaten ${formatKcal(eaten.kcal)} kcal',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MacroBar(
              label: 'Protein',
              eatenG: eaten.proteinG,
              targetG: target.proteinG,
              color: scheme.primary,
            ),
            _MacroBar(
              label: 'Fat',
              eatenG: eaten.fatG,
              targetG: target.fatG,
              color: scheme.tertiary,
            ),
            _MacroBar(
              label: 'Carbs',
              eatenG: eaten.carbsG,
              targetG: target.carbsG,
              color: scheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One macro in grams against its target; turns the error colour when over.
class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.eatenG,
    required this.targetG,
    required this.color,
  });

  final String label;
  final double eatenG;
  final double targetG;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = targetG <= 0 ? 0.0 : (eatenG / targetG).clamp(0.0, 1.0);
    final over = targetG > 0 && eatenG > targetG;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
              Text(
                '${eatenG.round()} / ${targetG.round()} g',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: over ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction,
            color: over ? theme.colorScheme.error : color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

/// A card with an icon, a short message and an optional action button.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.text,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
