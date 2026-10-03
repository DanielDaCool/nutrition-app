// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
// Today tab: day navigation plus the check-in banner, calorie card, quick
// weigh-in, meals and activity for the selected day.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/app_features.dart';
import '../../core/day_key.dart';
import '../activity/widgets/activity_card.dart';
import '../dashboard/dashboard_providers.dart';
import '../food/widgets/meals_section.dart';
import '../targets/checkin_screen.dart';
import '../targets/targets_providers.dart';
import '../weight/weight_providers.dart';
import '../weight/widgets/weigh_in_dialog.dart';
import 'widgets/calorie_card.dart';
import 'widgets/quick_weigh_in.dart';
import 'widgets/yesterday_prompt.dart';

/// Today tab for the day in `selectedDayProvider`. Arrows move a day at a
/// time but never past today; the calendar icon jumps to any past day;
/// tapping the title jumps back to today.
///
/// On today without a weigh-in the quick weigh-in sits above the calorie
/// card (morning routine); once saved a compact summary row takes its place.
/// When the app resumes on a new calendar day while "today" was shown, it
/// moves to the new today.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final AppLifecycleListener _lifecycle;

  /// Today's dayKey when the screen opened or last resumed.
  late String _today;

  String _now() => dayKeyOf(ref.read(clockProvider)());

  @override
  void initState() {
    super.initState();
    _today = _now();
    _lifecycle = AppLifecycleListener(onResume: _checkDayRollover);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// If midnight passed while the app was in the background, follow it.
  void _checkDayRollover() {
    if (!mounted) return;
    final now = _now();
    if (now == _today) return;
    final wasOnToday = ref.read(selectedDayProvider) == _today;
    _today = now;
    setState(() {});
    if (wasOnToday) ref.read(selectedDayProvider.notifier).set(now);
    // These read "today" once; refresh them for the new day.
    ref.invalidate(weightTrendProvider);
    ref.invalidate(dashboardWindowProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = ref.watch(selectedDayProvider);
    final today = _now();
    final selected = ref.read(selectedDayProvider.notifier);
    final checkInDue = ref.watch(checkInDueProvider).value ?? false;
    final weighIns = ref.watch(weighInsProvider).value;
    final isToday = dayKey == today;
    final canGoForward = dayKey.compareTo(today) < 0;
    // Both are behind a feature gate (see featureEnabledProvider).
    final showActivity = ref.watch(featureEnabledProvider(AppFeature.activity));
    final showYesterdayPrompt = ref.watch(
      featureEnabledProvider(AppFeature.yesterdayPrompt),
    );

    final Widget? weight = weighIns == null
        ? null
        : weighIns.containsKey(dayKey)
        ? WeighInSummaryRow(dayKey: dayKey)
        : QuickWeighIn(key: ValueKey('quick-$dayKey'), dayKey: dayKey);

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
            key: const Key('pickDay'),
            tooltip: 'Pick a day',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _pickDay(context, selected, dayKey, today),
          ),
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
          if (!isToday) _PastDayBar(dayKey: dayKey, onBack: selected.today),
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
          if (isToday && showYesterdayPrompt) YesterdayPrompt(today: today),
          if (isToday && weight != null) weight,
          CalorieCard(dayKey: dayKey),
          if (!isToday && weight != null) weight,
          MealsSection(dayKey: dayKey),
          // Steps and workouts come from Health Connect, which web lacks;
          // the gate is off there.
          if (showActivity) ActivityCard(dayKey: dayKey),
        ],
      ),
    );
  }
}

/// Opens a date picker bounded to [today] and jumps there on pick.
Future<void> _pickDay(
  BuildContext context,
  SelectedDay selected,
  String dayKey,
  String today,
) async {
  final initial = startOfDay(dayKey);
  final picked = await showDatePicker(
    context: context,
    helpText: 'Jump to a day',
    initialDate: initial,
    firstDate: DateTime(initial.year - 3),
    lastDate: startOfDay(today),
  );
  if (picked == null) return;
  selected.set(dayKeyOf(picked));
}

/// "Viewing Wed 24 Sep · Back to today" bar shown on past days.
class _PastDayBar extends StatelessWidget {
  const _PastDayBar({required this.dayKey, required this.onBack});

  final String dayKey;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat('EEE d MMM').format(startOfDay(dayKey));
    return Card(
      key: const Key('pastDayBar'),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewing $label',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onTertiaryContainer,
                minimumSize: const Size(48, 48),
              ),
              onPressed: onBack,
              child: const Text('Back to today'),
            ),
          ],
        ),
      ),
    );
  }
}
