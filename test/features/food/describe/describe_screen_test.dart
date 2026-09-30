import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/food/food_providers.dart';
import 'package:nutrition_app/features/food/screens/add_food_screen.dart';
import 'package:nutrition_app/features/food/screens/describe_food_screen.dart';

import '../../../helpers/test_db.dart';
import '../meals_section_test.dart' show settle;

const _day = '2026-09-25';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  /// A home screen that opens AddFoodScreen for lunch.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
          foodHttpClientProvider.overrideWithValue(
            MockClient((_) => throw StateError('no network in tests')),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AddFoodScreen(dayKey: _day, meal: Meal.lunch),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('describe-button')));
    await settle(tester);
    expect(find.byType(DescribeFoodScreen), findsOneWidget);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('describe-field')), text);
    await tester.pump(describeDebounce + const Duration(milliseconds: 50));
    await tester.pump();
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<List<FoodLogEntry>> entries(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.foodLogEntries).get()))!;

  testWidgets('type, see it understood, add both items', (tester) async {
    await pumpApp(tester);
    expect(find.text('Write it like you\'d say it'), findsOneWidget);

    await type(tester, '5 spoons of cottage cheese 5% and 2 eggs');
    expect(rich('Cottage cheese 5%'), findsOneWidget);
    expect(rich('Egg'), findsOneWidget);
    expect(find.text('5 tbsp · 100 g'), findsOneWidget);
    expect(find.text('2 pcs · 100 g'), findsOneWidget);
    expect(find.text('5 tbsp × 20 g · typical values'), findsOneWidget);
    expect(find.text('238 kcal'), findsOneWidget); // 95 + 143
    expect(find.text('Add 2 items to Lunch'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);

    await tester.tap(find.byKey(const Key('describe-add')));
    await settle(tester);

    final logged = await entries(tester);
    expect(logged, hasLength(2));
    expect(logged.map((e) => e.grams), [100, 100]);
    expect(logged.map((e) => e.meal), everyElement(Meal.lunch.index));
    expect(logged[0].kcal, closeTo(95, 1e-9));
    final foods = await tester.runAsync(() => db.select(db.foods).get());
    expect(foods!.map((f) => f.source), everyElement('builtin'));
    // Both screens closed, with a confirmation.
    expect(find.byType(AddFoodScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Added 2 items to Lunch'), findsOneWidget);
    // Undo takes both back out.
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await entries(tester), isEmpty);
    await finish(tester);
  });

  testWidgets('saves to the meal that was tapped, whatever the text says', (
    tester,
  ) async {
    await pumpApp(tester);
    await type(tester, '2 eggs for breakfast');
    expect(find.text('Add 1 item to Lunch'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('learns grams per spoon when the amount is corrected', (
    tester,
  ) async {
    await pumpApp(tester);
    await type(tester, '5 spoons of cottage cheese 5%');
    await tester.tap(
      find.byKey(const Key('amount-5 spoon cottage cheese 5%#1')),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('grams-field')), '110');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('5 tbsp · 110 g'), findsOneWidget);
    expect(find.text('You set 110 g · typical values'), findsOneWidget);
    await tester.tap(find.byKey(const Key('describe-add')));
    await settle(tester);
    expect((await entries(tester)).single.grams, 110);

    // Next time the same words use his spoon.
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('describe-button')));
    await settle(tester);
    await type(tester, '3 spoons of cottage cheese 5%');
    expect(find.text('3 tbsp · 66 g'), findsOneWidget);
    expect(
      find.text('3 × your usual tbsp (22 g) · typical values'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('unknown words: pick a food, and it is remembered', (
    tester,
  ) async {
    await pumpApp(tester);
    await type(tester, 'qwzx');
    expect(find.text('Didn\'t catch "qwzx"'), findsOneWidget);
    expect(find.text('Add 0 items to Lunch'), findsOneWidget);
    await tester.tap(find.text('Pick a food'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('picker-field')), 'banana');
    await tester.pump();
    await tester.tap(find.text('Banana'));
    await settle(tester);
    expect(rich('Banana'), findsOneWidget);
    await tester.tap(find.byKey(const Key('describe-add')));
    await settle(tester);
    final kv = await tester.runAsync(() => db.select(db.keyValues).get());
    expect({
      for (final r in kv!) r.key: r.value,
    }, containsPair('describe.alias.qwzx', 'builtin:banana'));

    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('describe-button')));
    await settle(tester);
    await type(tester, 'qwzx');
    expect(rich('Banana'), findsOneWidget);
    expect(find.text('Didn\'t catch "qwzx"'), findsNothing);
    await finish(tester);
  });

  testWidgets('edits survive typing more; items can be removed', (
    tester,
  ) async {
    await pumpApp(tester);
    await type(tester, '2 eggs');
    await tester.tap(find.byKey(const Key('food-2 egg#1')));
    await settle(tester);
    await tester.tap(find.text('Fried egg'));
    await settle(tester);
    expect(rich('Fried egg'), findsOneWidget);

    await type(tester, '2 eggs, a banana');
    expect(rich('Fried egg'), findsOneWidget);
    expect(rich('Banana'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove').last);
    await tester.pump();
    expect(rich('Banana'), findsNothing);
    expect(find.text('Add 1 item to Lunch'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an item over 1000 kcal gets a check hint', (tester) async {
    await pumpApp(tester);
    const hint = 'That\'s a lot of calories for one item. Check the amount.';
    await type(tester, '1 bamba');
    expect(find.text(hint), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    // Ten bags: a confident food and a typical weight, but 1358 kcal.
    await type(tester, '10 bamba');
    expect(find.text('10 pcs · 250 g'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);

    // Grams the user typed themselves are trusted.
    await tester.tap(find.byKey(const Key('amount-10 bamba#1')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('grams-field')), '260');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text(hint), findsNothing);
    await finish(tester);
  });

  testWidgets('describe provider loads foods for the screen', (tester) async {
    // Also opens straight from a meal without AddFoodScreen.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 25, 12)),
        ],
        child: const MaterialApp(
          home: DescribeFoodScreen(dayKey: _day, meal: Meal.snack),
        ),
      ),
    );
    await settle(tester);
    await type(tester, 'hummus');
    expect(rich('Hummus (spread)'), findsOneWidget);
    expect(find.text('1 portion · 30 g'), findsOneWidget);
    await finish(tester);
  });
}
