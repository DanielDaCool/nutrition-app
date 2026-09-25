// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../activity/widgets/activity_card.dart';
import '../food/widgets/meals_section.dart';
import '../targets/checkin_screen.dart';
import '../targets/targets_providers.dart';
import '../weight/weight_providers.dart';
import '../weight/widgets/weigh_in_dialog.dart';
import 'widgets/calorie_card.dart';
import 'widgets/quick_weigh_in.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayKey = ref.watch(selectedDayProvider);
    final today = dayKeyOf(ref.read(clockProvider)());
    final selected = ref.read(selectedDayProvider.notifier);
    final checkInDue = ref.watch(checkInDueProvider).value ?? false;
    final weighIns = ref.watch(weighInsProvider).value;
    final canGoForward = dayKey.compareTo(today) < 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => selected.set(addDays(dayKey, -1)),
        ),
        title: TextButton(
          key: const Key('todayHeader'),
          onPressed: selected.today,
          child: Text(
            formatDayLong(dayKey, today),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward
                ? () {
                    final next = addDays(dayKey, 1);
                    selected.set(next.compareTo(today) > 0 ? today : next);
                  }
                : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (checkInDue) ...[
            Card(
              key: const Key('checkInBanner'),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Weekly check-in is ready'),
                subtitle: const Text('Review your new calorie targets'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckInScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          CalorieCard(dayKey: dayKey),
          if (weighIns != null && !weighIns.containsKey(dayKey))
            QuickWeighIn(key: ValueKey('quick-$dayKey'), dayKey: dayKey),
          MealsSection(dayKey: dayKey),
          ActivityCard(dayKey: dayKey),
        ],
      ),
    );
  }
}
