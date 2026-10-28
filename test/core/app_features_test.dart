import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/app_features.dart';

void main() {
  test('storage keys are unique and non-empty', () {
    final keys = [for (final f in AppFeature.values) f.storageKey];
    expect(keys.toSet(), hasLength(keys.length));
    expect(keys.every((k) => k.isNotEmpty), isTrue);
  });

  test('storage keys of shipped features never change', () {
    expect(AppFeature.activity.storageKey, 'activity');
    expect(AppFeature.recipes.storageKey, 'recipes');
    expect(AppFeature.yesterdayPrompt.storageKey, 'yesterdayPrompt');
    expect(AppFeature.barcodeScan.storageKey, 'barcodeScan');
    expect(AppFeature.gainGoals.storageKey, 'gainGoals');
    expect(AppFeature.backup.storageKey, 'backup');
  });

  test('the features added for Choose features are pinned', () {
    expect(AppFeature.dashboard.storageKey, 'dashboard');
    expect(AppFeature.dashboard.label, 'Dashboard');
    expect(AppFeature.dashboard.androidOnly, isFalse);
    expect(AppFeature.walkReminders.storageKey, 'walkReminders');
    expect(AppFeature.walkReminders.label, 'Walk reminder');
    expect(AppFeature.walkReminders.androidOnly, isTrue);
    expect(AppFeature.workouts.storageKey, 'workouts');
    expect(AppFeature.workouts.label, 'Workouts');
    expect(AppFeature.workouts.androidOnly, isTrue);
    // Appended after updateAvailable, so the earlier values keep their order.
    expect(AppFeature.values.skip(AppFeature.updateAvailable.index + 1).take(3), [
      AppFeature.dashboard,
      AppFeature.walkReminders,
      AppFeature.workouts,
    ]);
  });

  test('the steps feature keeps its key and is labelled Steps', () {
    expect(AppFeature.activity.label, 'Steps');
  });

  test('every feature has a label and a description', () {
    for (final f in AppFeature.values) {
      expect(f.label, isNotEmpty, reason: f.name);
      expect(f.description, isNotEmpty, reason: f.name);
    }
  });

  test('Android-only features are unavailable on web only', () {
    expect(AppFeature.activity.androidOnly, isTrue);
    expect(AppFeature.activity.availableOn(isWeb: true), isFalse);
    expect(AppFeature.activity.availableOn(isWeb: false), isTrue);
    for (final f in AppFeature.values) {
      expect(f.availableOn(isWeb: false), isTrue, reason: f.name);
      expect(f.availableOn(isWeb: true), !f.androidOnly, reason: f.name);
    }
  });

  test('exactly the agreed features are user-choosable', () {
    final choosable = {
      for (final f in AppFeature.values)
        if (f.userChoosable) f,
    };
    expect(choosable, {
      AppFeature.activity,
      AppFeature.recipes,
      AppFeature.yesterdayPrompt,
      AppFeature.dashboard,
      AppFeature.walkReminders,
      AppFeature.workouts,
      AppFeature.targetInsights,
      AppFeature.savedMeals,
      AppFeature.quickCalories,
      AppFeature.csvExport,
      AppFeature.closeDayPrompt,
      AppFeature.manualCalories,
    });
  });

  test('backups, safety banners and always-on features are not choosable', () {
    for (final f in [
      AppFeature.backup,
      AppFeature.installHint,
      AppFeature.reportProblem,
      AppFeature.updateAvailable,
      AppFeature.barcodeScan,
      AppFeature.gainGoals,
    ]) {
      expect(f.userChoosable, isFalse, reason: f.name);
      expect(f.choosableOn(isWeb: false), isFalse, reason: f.name);
    }
  });

  test('choosableOn needs both user-choosable and available here', () {
    expect(AppFeature.dashboard.choosableOn(isWeb: true), isTrue);
    expect(AppFeature.dashboard.choosableOn(isWeb: false), isTrue);
    expect(AppFeature.recipes.choosableOn(isWeb: true), isTrue);
    expect(AppFeature.walkReminders.choosableOn(isWeb: true), isFalse);
    expect(AppFeature.walkReminders.choosableOn(isWeb: false), isTrue);
    expect(AppFeature.workouts.choosableOn(isWeb: true), isFalse);
    expect(AppFeature.activity.choosableOn(isWeb: true), isFalse);
  });
}
