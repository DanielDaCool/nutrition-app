// Shared helpers for the exercise/preset library widget tests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/lifting/lifting_repository.dart';

/// Friday.
final now = DateTime(2026, 9, 25, 9);

const today = '2026-09-25';

/// [home] in a dark Material 3 app on the test database with a pinned clock.
Widget host(AppDatabase db, Widget home) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(() => now),
  ],
  child: MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: home),
);

/// A page with one "open" button that runs [open] and hands its result to
/// [onResult], for testing pickers and dialogs.
class Opener<T> extends StatelessWidget {
  const Opener({super.key, required this.open, required this.onResult});

  final Future<T?> Function(BuildContext context) open;
  final void Function(T? result) onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async => onResult(await open(context)),
          child: const Text('open'),
        ),
      ),
    );
  }
}

/// Lets drift's queries and stream updates finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500)); // route animations
}

/// Unmounts the app so its drift streams close before the database does.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

LiftingRepository repoOf(AppDatabase db) => LiftingRepository(db, () => now);

/// Runs [body] outside the fake-async zone and returns its result.
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
  late T result;
  await tester.runAsync(() async => result = await body());
  return result;
}

Future<int> addExercise(
  WidgetTester tester,
  AppDatabase db,
  String name, {
  MuscleGroup muscleGroup = MuscleGroup.chest,
  bool isBodyweight = false,
}) => real(
  tester,
  () => repoOf(db).addExercise(
    name: name,
    muscleGroup: muscleGroup,
    isBodyweight: isBodyweight,
  ),
);

Future<List<LiftExerciseRow>> exerciseRows(
  WidgetTester tester,
  AppDatabase db,
) => real(tester, () => db.select(db.liftExercises).get());

Future<List<LiftPreset>> presets(WidgetTester tester, AppDatabase db) =>
    real(tester, () => repoOf(db).watchPresets().first);
