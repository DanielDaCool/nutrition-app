import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/data/db/database.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/settings/csv_data.dart';
import 'package:nutrition_app/features/settings/csv_export.dart';

import '../../helpers/test_db.dart';

/// Header-and-rows text without the BOM, as a list of lines.
List<String> lines(String csv) {
  expect(csv.startsWith(csvBom), isTrue);
  final body = csv.substring(1);
  expect(body.endsWith('\r\n'), isTrue);
  return body.substring(0, body.length - 2).split('\r\n');
}

void main() {
  group('toCsv', () {
    test('header only for no rows, with BOM and CRLF', () {
      expect(toCsv(['a', 'b'], const []), '﻿a,b\r\n');
    });

    test('plain cells, nulls, bools and numbers', () {
      final csv = toCsv(
        ['t', 'n', 'x', 'b'],
        [
          ['food', 12.5, null, true],
          ['x', 3, '', false],
        ],
      );
      expect(lines(csv), ['t,n,x,b', 'food,12.5,,true', 'x,3,,false']);
    });

    test('quotes commas, quotes and embedded newlines', () {
      final csv = toCsv(
        ['name'],
        [
          ['Oil, olive'],
          ['The "best" bread'],
          ['two\nlines'],
          ['cr\rlf'],
        ],
      );
      expect(
        csv,
        '﻿name\r\n"Oil, olive"\r\n"The ""best"" bread"\r\n'
        '"two\nlines"\r\n"cr\rlf"\r\n',
      );
    });

    test('keeps Hebrew text and puts the BOM first', () {
      final csv = toCsv(
        ['food'],
        [
          ['חומוס'],
          ['גבינה, לבנה'],
        ],
      );
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(lines(csv), ['food', 'חומוס', '"גבינה, לבנה"']);
    });

    test('neutralises formulas in text but not in numbers', () {
      final csv = toCsv(
        ['t', 'n'],
        [
          ['=SUM(A1)', -3.5],
          ['+1', 1],
          ['-cmd', 2],
          ['@x', 3],
          ['a=b', 4],
          ['\tTab', 5],
        ],
      );
      expect(lines(csv), [
        't,n',
        "'=SUM(A1),-3.5",
        "'+1,1",
        "'-cmd,2",
        "'@x,3",
        'a=b,4',
        "'\tTab,5",
      ]);
    });

    test('neutralised text that also needs quoting gets both', () {
      expect(
        lines(
          toCsv(
            ['t'],
            [
              ['=a,b'],
            ],
          ),
        ),
        ['t', '"\'=a,b"'],
      );
    });

    test('numbers: dot decimals, no exponent, no grouping, trimmed', () {
      expect(csvNumber(1234567.0), '1234567');
      expect(csvNumber(0.1 + 0.2), '0.3');
      expect(csvNumber(14.862), '14.862');
      expect(csvNumber(14.8624), '14.862');
      expect(csvNumber(1e-9), '0');
      expect(csvNumber(-1e-9), '0');
      expect(csvNumber(double.nan), '');
      expect(csvNumber(100), '100');
    });
  });

  group('foodLogCsvRow', () {
    List<Object?> row(String source, {double grams = 150}) => foodLogCsvRow(
      dayKey: '2026-09-25',
      meal: 'lunch',
      food: 'X',
      brand: null,
      source: source,
      grams: grams,
      kcal: 200,
      proteinG: 10,
      fatG: 5,
      carbsG: 30,
      dayFullyLogged: true,
    );

    test('a normal food has grams and no servings', () {
      final r = row('custom');
      expect(r[4], 'custom');
      expect(r[5], 150);
      expect(r[6], isNull);
      expect(r[11], false);
    });

    test('a recipe has servings, not grams', () {
      final r = row('recipe', grams: 150);
      expect(r[4], 'recipe');
      expect(r[5], isNull);
      expect(r[6], 1.5);
    });

    test('quick adds are labelled quick, with no amount', () {
      final complete = row('quick', grams: 100);
      expect(complete[4], 'quick');
      expect(complete[5], isNull);
      expect(complete[6], isNull);
      expect(complete[11], false);
      final partial = row('quickKcal', grams: 100);
      expect(partial[4], 'quick');
      expect(partial[11], true);
    });
  });

  group('tables to CSV', () {
    late AppDatabase db;
    final t = DateTime(2026, 9, 25, 12);

    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    Future<int> food(
      String name,
      String source, {
      String? brand,
      double kcal = 100,
    }) => db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            source: source,
            name: name,
            brand: Value(brand),
            kcalPer100g: kcal,
            proteinPer100g: 1,
            fatPer100g: 2,
            carbsPer100g: 3,
            createdAt: t,
          ),
        );

    Future<void> entry(
      String day,
      Meal meal,
      int foodId,
      double grams,
      double kcal, {
      DateTime? at,
    }) => db
        .into(db.foodLogEntries)
        .insert(
          FoodLogEntriesCompanion.insert(
            dayKey: day,
            meal: meal.index,
            foodId: foodId,
            grams: grams,
            kcal: kcal,
            proteinG: 1,
            fatG: 2,
            carbsG: 3,
            createdAt: at ?? t,
          ),
        );

    test('empty tables give a header only', () async {
      expect(await foodLogCsv(db), toCsv(foodLogCsvHeader, const []));
      expect(await weighInsCsv(db), toCsv(weighInsCsvHeader, const []));
      expect(await targetsCsv(db), toCsv(targetsCsvHeader, const []));
      expect(lines(await foodLogCsv(db)).single, startsWith('dayKey,meal,'));
    });

    test('food log: rows ordered, labelled, with the day flag', () async {
      final rice = await food('Rice, white', 'custom', brand: 'Acme');
      final lasagne = await food('Lasagne', 'recipe');
      final quick = await food('Quick add', 'quickKcal');
      final hummus = await food('חומוס', 'off');
      await entry('2026-09-25', Meal.dinner, lasagne, 150, 450);
      await entry('2026-09-25', Meal.lunch, rice, 200, 260);
      await entry('2026-09-24', Meal.snack, quick, 100, 300);
      await entry(
        '2026-09-25',
        Meal.lunch,
        hummus,
        50,
        120,
        at: t.add(const Duration(minutes: 1)),
      );
      await db
          .into(db.dayStatuses)
          .insert(
            DayStatusesCompanion.insert(
              dayKey: '2026-09-25',
              fullyLogged: const Value(true),
            ),
          );

      expect(lines(await foodLogCsv(db)), [
        foodLogCsvHeader.join(','),
        '2026-09-24,snack,Quick add,,quick,,,300,1,2,3,true,false',
        '2026-09-25,lunch,"Rice, white",Acme,custom,200,,260,1,2,3,false,true',
        '2026-09-25,lunch,חומוס,,off,50,,120,1,2,3,false,true',
        '2026-09-25,dinner,Lasagne,,recipe,,1.5,450,1,2,3,false,true',
      ]);
    });

    test('weigh-ins oldest first', () async {
      for (final w in [('2026-09-25', 81.25), ('2026-09-23', 82.0)]) {
        await db
            .into(db.weighIns)
            .insert(
              WeighInsCompanion.insert(
                dayKey: w.$1,
                weightKg: w.$2,
                createdAt: t,
              ),
            );
      }
      expect(lines(await weighInsCsv(db)), [
        'dayKey,weightKg',
        '2026-09-23,82',
        '2026-09-25,81.25',
      ]);
    });

    test('targets: methods, skipped flag, legacy and bad JSON rows', () async {
      Future<void> target(String from, TargetMethod method, String? json) => db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: from,
              kcal: 2000,
              proteinG: 150,
              fatG: 60,
              carbsG: 200,
              maintenanceKcal: 2400.5,
              method: method.index,
              explanationJson: Value(json),
              createdAt: t,
            ),
          );
      await target('2026-09-01', TargetMethod.formula, null);
      await target('2026-09-08', TargetMethod.blended, '{"formulaKcal":1}');
      await target('2026-09-15', TargetMethod.adaptive, '{"skipped":true}');
      await target('2026-09-22', TargetMethod.adaptive, 'not json');
      await db
          .into(db.targetHistory)
          .insert(
            TargetHistoryCompanion.insert(
              effectiveFrom: '2026-09-29',
              kcal: 1900,
              proteinG: 150,
              fatG: 60,
              carbsG: 200,
              maintenanceKcal: 2400,
              method: 99,
              createdAt: t,
            ),
          );
      expect(lines(await targetsCsv(db)), [
        targetsCsvHeader.join(','),
        '2026-09-01,2000,150,60,200,2400.5,formula,false',
        '2026-09-08,2000,150,60,200,2400.5,blended,false',
        '2026-09-15,2000,150,60,200,2400.5,adaptive,true',
        '2026-09-22,2000,150,60,200,2400.5,adaptive,false',
        '2026-09-29,1900,150,60,200,2400,formula,false',
      ]);
    });
  });
}
