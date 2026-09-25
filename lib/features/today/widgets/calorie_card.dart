import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models.dart';
import '../../food/food_providers.dart';
import '../../targets/targets_providers.dart';

final _kcalFormat = NumberFormat.decimalPattern('en_US');

/// Formats kcal rounded to a whole number with thousands separators.
String formatKcal(double kcal) => _kcalFormat.format(kcal.round());

/// Target minus intake for [dayKey], with macro progress bars. When no
/// targets exist yet it shows a hint to set up the profile.
class CalorieCard extends ConsumerWidget {
  const CalorieCard({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(currentTargetsProvider);
    final intakeAsync = ref.watch(dayIntakeProvider(dayKey));
    final targets = targetsAsync.value;
    final intake = intakeAsync.value;

    if (targetsAsync.hasError && targets == null) {
      return _MessageCard(
        icon: Icons.error_outline,
        text: 'Could not load targets: ${targetsAsync.error}',
      );
    }
    if (intakeAsync.hasError && intake == null) {
      return _MessageCard(
        icon: Icons.error_outline,
        text: 'Could not load food log: ${intakeAsync.error}',
      );
    }
    if (!targetsAsync.hasValue) {
      return const Card(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (targets == null) {
      return const _MessageCard(
        key: Key('noTargetsCard'),
        icon: Icons.person_outline,
        text: 'Set up your profile in Settings to get calorie targets',
      );
    }
    final eaten = intake?.total ?? Macros.zero;
    return _TargetsCard(target: targets.macros, eaten: eaten);
  }
}

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

class _MessageCard extends StatelessWidget {
  const _MessageCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
  }
}
