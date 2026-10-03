// Pushes today's "calories left" and "steps" onto the Android home-screen
// widget (see android/app/.../NutritionWidgetProvider.kt) whenever the
// relevant data changes. Mirrors the shape of activity_providers.dart's
// healthSyncProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../app/providers.dart';
import '../../core/day_key.dart';
import '../activity/activity_providers.dart';
import '../activity/step_goal_providers.dart';
import '../food/food_providers.dart';
import '../targets/targets_providers.dart';
import 'lockscreen_notification_sync.dart';
import 'widget_text_format.dart';

/// Last time the widget was refreshed (null if never). syncNow() must never
/// throw; failures go into state.
final homeWidgetSyncProvider =
    AsyncNotifierProvider<HomeWidgetSyncController, DateTime?>(
      HomeWidgetSyncController.new,
    );

class HomeWidgetSyncController extends AsyncNotifier<DateTime?> {
  Future<void>? _inFlight;

  @override
  DateTime? build() => null;

  Future<void> syncNow() =>
      _inFlight ??= _syncNow().whenComplete(() => _inFlight = null);

  Future<void> _syncNow() async {
    try {
      final dayKey = dayKeyOf(ref.read(clockProvider)());

      // currentTargetsProvider, dayIntakeProvider and dayActivityProvider are
      // streams that Riverpod 3 keeps paused without a listener, so each is
      // briefly listened to here to pull its first emitted value, then
      // released — this call doesn't need a long-lived subscription.
      final targets = await _readOnce(currentTargetsProvider);
      final intake = await _readOnce(dayIntakeProvider(dayKey));
      final activity = await _readOnce(dayActivityProvider(dayKey));
      final stepGoal = (await ref.read(stepGoalProvider.future)).stepGoal;

      final kcalText = formatKcalLeftText(
        targetKcal: targets?.macros.kcal,
        loggedKcal: intake.total.kcal,
      );
      final stepsText = formatStepsText(activity.steps);
      final goalReached = isStepGoalReached(
        steps: activity.steps,
        stepGoal: stepGoal,
      );

      try {
        await HomeWidget.saveWidgetData<String>('kcalLeftText', kcalText);
        await HomeWidget.saveWidgetData<String>('stepsText', stepsText);
        await HomeWidget.updateWidget(androidName: 'NutritionWidgetProvider');
      } catch (_) {
        // No widget pinned, or the platform channel isn't available (e.g.
        // in tests) — that's the normal case, not a sync failure.
      }

      await syncLockScreenNotification(
        steps: activity.steps,
        stepGoal: stepGoal,
        kcalLeftText: kcalText,
        goalReached: goalReached,
      );

      if (!ref.mounted) return;
      state = AsyncData(ref.read(clockProvider)());
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError(e, st);
    }
  }

  /// Reads a [StreamProvider]'s first value, keeping it un-paused for just
  /// long enough to do so.
  Future<T> _readOnce<T>(StreamProvider<T> provider) async {
    final sub = ref.listen<AsyncValue<T>>(provider, (_, _) {});
    try {
      return await ref.read(provider.future);
    } finally {
      sub.close();
    }
  }
}
