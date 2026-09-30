// Regression test: the "Update today's weigh-in" dialog must not overflow
// when the soft keyboard opens (simulated via MediaQuery.viewInsets), and
// its Cancel/Save actions must stay reachable (scrollable content).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/weight/widgets/weigh_in_dialog.dart';

void main() {
  testWidgets(
    'weigh-in dialog does not overflow when the keyboard opens',
    (tester) async {
      // A small phone-like viewport, set on the test view itself (not just
      // wrapped in a MediaQuery widget) so the dialog route's own ambient
      // MediaQuery — which reads from the view, not from an ancestor inside
      // the pushed widget tree — sees it too, same as the failing tap-
      // through found on a real phone.
      final view = tester.view;
      view.physicalSize = const Size(360, 640);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showWeighInDialog(
                    context,
                    today: '2026-09-25',
                    lastKg: 82.6,
                    // A day with an existing weigh-in so the "replaces it"
                    // warning row is present, adding to the content height.
                    existing: const {'2026-09-25': 82.6},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('weighInKgField')));
      await tester.pump();

      // Simulate the soft keyboard opening (~300px), the same way Flutter
      // reports it to the dialog's MediaQuery.
      view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    },
  );
}
