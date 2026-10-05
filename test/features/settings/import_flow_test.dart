import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/features/settings/data_export.dart';
import 'package:nutrition_app/features/settings/import_flow.dart';
import 'package:nutrition_app/features/settings/settings_screen.dart';
import 'package:nutrition_app/features/settings/setup_screen.dart';

import '../../helpers/test_db.dart';

final now = DateTime(2026, 10, 6, 9);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> addWeighIn(AppDatabase db, String dayKey, double kg) => db
    .into(db.weighIns)
    .insert(
      WeighInsCompanion.insert(dayKey: dayKey, weightKg: kg, createdAt: now),
    );

/// Export text of a device with one weigh-in on 2026-10-01.
Future<String> backupText() async {
  final other = openTestDatabase();
  try {
    await addWeighIn(other, '2026-10-01', 81.4);
    return jsonEncode(await exportAllTables(other, now: now));
  } finally {
    await other.close();
  }
}

Future<List<String>> weighInDays(AppDatabase db) async => [
  for (final w in await db.select(db.weighIns).get()) w.dayKey,
];

Widget app(AppDatabase db, String? picked, {required Widget home}) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        pickBackupTextProvider.overrideWithValue(() async => picked),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapImport(WidgetTester tester, String? picked) async {
    tallScreen(tester);
    await tester.pumpWidget(app(db, picked, home: const SettingsScreen()));
    await settle(tester);
    await tester.tap(find.byType(ImportDataTile));
    await settle(tester);
  }

  testWidgets('confirming replaces the data with the backup', (tester) async {
    await tester.runAsync(() => addWeighIn(db, '2026-01-01', 99));
    final text = (await tester.runAsync(backupText))!;
    await tapImport(tester, text);

    expect(find.text('Replace your data?'), findsOneWidget);
    expect(
      find.textContaining('1 weigh-ins and 0 logged foods'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirmImport')));
    await settle(tester);

    expect(find.text('Backup restored'), findsOneWidget);
    expect(await tester.runAsync(() => weighInDays(db)), ['2026-10-01']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelling leaves the data alone', (tester) async {
    await tester.runAsync(() => addWeighIn(db, '2026-01-01', 99));
    final text = (await tester.runAsync(backupText))!;
    await tapImport(tester, text);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Backup restored'), findsNothing);
    expect(await tester.runAsync(() => weighInDays(db)), ['2026-01-01']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a file that is not a backup is explained', (tester) async {
    await tapImport(tester, '{"hello": 1}');

    expect(find.text('Replace your data?'), findsNothing);
    expect(find.text("That file isn't a Nutrition backup."), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing the picker does nothing', (tester) async {
    await tapImport(tester, null);

    expect(find.text('Replace your data?'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('setup can restore a backup instead, then closes', (
    tester,
  ) async {
    tallScreen(tester);
    final text = (await tester.runAsync(backupText))!;
    await tester.pumpWidget(
      app(
        db,
        text,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openSetup(context),
            child: const Text('open setup'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open setup'));
    await settle(tester);
    expect(find.byType(SetupScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('setupRestore')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmImport')));
    await settle(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsNothing);
    expect(await tester.runAsync(() => weighInDays(db)), ['2026-10-01']);
    await tester.pumpWidget(const SizedBox());
  });
}
