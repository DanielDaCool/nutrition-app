// Regression test: the edit-entry bottom sheet must not overflow when the
// soft keyboard opens (simulated here via MediaQuery.viewInsets), and the
// meal chips / Delete / Save row must stay reachable (scrollable).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/data/food_repository.dart';
import 'package:nutrition_app/features/food/widgets/entry_edit_sheet.dart';

void main() {
  final item = LoggedItem(
    id: 1,
    dayKey: '2026-09-25',
    meal: Meal.breakfast,
    foodId: 1,
    foodName: 'Test food',
    brand: null,
    grams: 100,
    macros: const Macros(kcal: 200, proteinG: 10, fatG: 5, carbsG: 20),
    createdAt: DateTime(2026, 9, 25),
  );

  testWidgets(
    'entry edit sheet does not overflow when the keyboard opens',
    (tester) async {
      // A small phone-like viewport, set on the test view itself (not just
      // wrapped in a MediaQuery widget) so the modal route's own ambient
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
                  onPressed: () => showEntryEditSheet(context, item),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // No overflow with the keyboard closed.
      expect(tester.takeException(), isNull);

      // Simulate the soft keyboard opening (~300px, like a real numeric
      // keyboard), the same way Flutter itself reports it to the sheet's
      // MediaQuery.
      await tester.tap(find.byKey(const Key('grams-field')));
      await tester.pump();
      view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The meal chips and the Delete/Save row must still be visible /
      // reachable (present in the tree, not clipped off by an overflow).
      expect(find.byKey(const Key('move-breakfast')), findsOneWidget);
      expect(find.byKey(const Key('delete-entry')), findsOneWidget);
      expect(find.byKey(const Key('save-entry')), findsOneWidget);
    },
  );
}
