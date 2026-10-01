import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/recipes/recipes_screen.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpRecipes(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('shows a section per meal category', (tester) async {
    await pumpRecipes(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);

    // The catalog now has 25 recipes per category, so Dinner/Snacks sit
    // past the initial cache extent and need scrolling into view.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Dinner'),
      500,
      scrollable: scrollable,
    );
    expect(find.text('Dinner'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Snacks'),
      500,
      scrollable: scrollable,
    );
    expect(find.text('Snacks'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
