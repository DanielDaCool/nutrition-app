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
    expect(AppFeature.lifting.storageKey, 'lifting');
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
}
