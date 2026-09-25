import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/app.dart';
import 'package:nutrition_app/app/providers.dart';

import '../helpers/test_db.dart';

void main() {
  testWidgets('app starts and switches tabs', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const NutritionApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    // Dark only, even when the phone is in light mode (the test default).
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    for (final label in ['Weight', 'Dashboard', 'Settings', 'Today']) {
      await tester.tap(find.text(label).last);
      await tester.pump();
    }
    // Let pending timers/streams settle before the DB closes.
    await tester.pumpWidget(const SizedBox());
  });
}
