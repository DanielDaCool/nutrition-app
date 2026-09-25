// Today screen's calorie card: kcal remaining against the current target and
// protein/fat/carb progress bars.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/day_key.dart';
import '../../../domain/models.dart';
import '../../food/food_providers.dart';
import '../../settings/setup_screen.dart';
import '../../targets/targets_providers.dart';
import '../../weight/weight_providers.dart';
import '../../weight/widgets/weigh_in_dialog.dart';

final _kcalFormat = NumberFormat.decimalPattern('en_US');

/// Formats kcal rounded to a whole number with thousands separators.
String formatKcal(double kcal) => _kcalFormat.format(kcal.round());

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
    final targetsAsync = ref.watch(currentTargetsProvider);
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
        onAction: () => ref.invalidate(currentTargetsProvider),
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
    if (targets == null) return const _NoTargetsCard();
    final eaten = intake?.total ?? Macros.zero;
    return _TargetsCard(target: targets.macros, eaten: eaten);
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
      // Profile and weigh-in exist: the first target is being worked out.
      return const _LoadingCard();
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
