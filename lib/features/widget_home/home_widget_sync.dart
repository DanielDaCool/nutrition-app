// Pushes today's "calories left" and "steps" onto the Android home-screen
// widget (see android/app/.../NutritionWidgetProvider.kt) whenever the
// relevant data changes. Mirrors the shape of activity_providers.dart's
// healthSyncProvider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // TODO(widget-home worker): read today's remaining kcal (via
    // currentTargetsProvider + dayIntakeProvider) and today's steps (via
    // dayActivityProvider), format them, push with
    // HomeWidget.saveWidgetData<String> and HomeWidget.updateWidget(
    // androidName: 'NutritionWidgetProvider'), then set state.
    state = AsyncData(DateTime.now());
  }
}
