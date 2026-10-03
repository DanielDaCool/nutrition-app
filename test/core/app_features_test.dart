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
  });

  test('every feature has a label and a description', () {
    for (final f in AppFeature.values) {
      expect(f.label, isNotEmpty, reason: f.name);
      expect(f.description, isNotEmpty, reason: f.name);
    }
  });

  test('baseline features start on; later ones only in a normal build', () {
    expect(defaultEnabledFor(baseline: true, optIn: false), isTrue);
    expect(defaultEnabledFor(baseline: true, optIn: true), isTrue);
    expect(defaultEnabledFor(baseline: false, optIn: false), isTrue);
    expect(defaultEnabledFor(baseline: false, optIn: true), isFalse);
  });

  test('the four initial features are baseline and start on', () {
    // Tests run without NEW_FEATURES_OPT_IN.
    expect(newFeaturesOptIn, isFalse);
    for (final f in [
      AppFeature.activity,
      AppFeature.recipes,
      AppFeature.yesterdayPrompt,
      AppFeature.barcodeScan,
    ]) {
      expect(f.baseline, isTrue, reason: f.name);
      expect(f.defaultEnabled, isTrue, reason: f.name);
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
