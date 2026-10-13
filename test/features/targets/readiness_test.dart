import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/day_key.dart';
import 'package:nutrition_app/domain/models.dart';
import 'package:nutrition_app/features/targets/engine/engine.dart';
import 'package:nutrition_app/features/targets/engine/readiness.dart';

const today = '2026-09-25';

EngineProfile profile() => EngineProfile(
  sex: Sex.male,
  birthDate: DateTime(1996, 9, 25),
  heightCm: 180,
  activityLevel: ActivityLevel.moderate,
  goalWeightKg: 80,
  weeklyRatePct: 0.5,
  proteinPerKg: 2.0,
  goalDirection: GoalDirection.lose,
);

/// Weigh-ins on the given day offsets from [today] (negative = past), with
/// a steady slow loss, and fully logged days on [loggedOffsets].
EngineInput input({
  required Iterable<int> weighOffsets,
  required Iterable<int> loggedOffsets,
  String? previousPhaseStart,
}) => EngineInput(
  today: today,
  profile: profile(),
  weighIns: {for (final o in weighOffsets) addDays(today, o): 90.0 + o * 0.05},
  intake: {
    for (final o in loggedOffsets)
      addDays(today, o): const DayLog(kcal: 2200, fullyLogged: true),
  },
  previousPhaseStartDayKey: previousPhaseStart,
);

Readiness readiness(EngineInput i) => readinessOf(i, recommend(i).explanation);

List<int> range(int from, int to) => [for (var i = from; i <= to; i++) i];

void main() {
  test('thresholds come from the engine constants', () {
    expect(kAdaptLoggedDays, kMinLoggedDays + 1);
    expect(kAdaptWeighIns, kMinWeighIns + 1);
  });

  test('exactly the minimum logged days: not adapting yet (weight is 0)', () {
    final i = input(
      weighOffsets: range(-40, -1),
      loggedOffsets: range(-kMinLoggedDays, -1),
    );
    final e = recommend(i).explanation;
    final r = readinessOf(i, e);
    expect(r.loggedDays, kMinLoggedDays);
    expect(e.weight, 0);
    expect(r.adapting, isFalse);
    expect(readinessLines(r).first, contains('8 fully logged days'));
    expect(readinessLines(r).first, contains('7 weigh-ins'));
    expect(readinessLines(r).first, contains('7 of the 8'));
  });

  test('one more logged day: adapting, but not yet full', () {
    final i = input(
      weighOffsets: range(-40, -1),
      loggedOffsets: range(-kAdaptLoggedDays, -1),
    );
    final r = readiness(i);
    expect(r.loggedDays, kAdaptLoggedDays);
    expect(r.adapting, isTrue);
    expect(r.weight, greaterThan(0));
    expect(r.weight, lessThan(1));
    expect(r.full, isFalse);
    expect(readinessLines(r).single, contains('counts fully at 18'));
  });

  test('weigh-in count: 6 is not enough, 7 is (spread over the window)', () {
    List<int> spread(int k) => [for (var j = 0; j < k; j++) -28 + 4 * j];
    final logged = range(-20, -1);
    final six = readiness(
      input(weighOffsets: spread(6), loggedOffsets: logged),
    );
    final seven = readiness(
      input(weighOffsets: spread(7), loggedOffsets: logged),
    );
    expect(six.weighIns, 6);
    expect(six.adapting, isFalse);
    expect(seven.weighIns, 7);
    expect(seven.adapting, isTrue);
  });

  test('span is only needed (and shown) when raw weigh-ins are used', () {
    // Seven daily weigh-ins in the window, but the first ever weigh-in is
    // inside it: regression mode, spanning 6 of 14 days.
    final tight = readiness(
      input(weighOffsets: range(-28, -22), loggedOffsets: range(-20, -1)),
    );
    expect(tight.needsSpan, isTrue);
    expect(tight.weighInSpanDays, 6);
    expect(tight.adapting, isFalse);
    expect(readinessLines(tight).first, contains('span 6 of 14 days'));

    // Weigh-ins from 60 days back: the trend is used, no span needed.
    final trend = readiness(
      input(weighOffsets: range(-60, -1), loggedOffsets: range(-20, -1)),
    );
    expect(trend.needsSpan, isFalse);
    expect(trend.adapting, isTrue);
    expect(readinessLines(trend).join(' '), isNot(contains('span')));
  });

  test('settling after a diet change counts the days left', () {
    // A phase that started 5 days ago skips 14 days from then: 10 to go.
    final r = readiness(
      input(
        weighOffsets: range(-40, -1),
        loggedOffsets: range(-20, -1),
        previousPhaseStart: addDays(today, -5),
      ),
    );
    expect(r.settlingDaysLeft, 10);
    expect(r.adapting, isFalse);
    expect(readinessLines(r).single, contains('10 more days'));
  });

  test('full data: nothing missing, no lines', () {
    final r = readiness(
      input(weighOffsets: range(-60, -1), loggedOffsets: range(-27, -1)),
    );
    expect(r.full, isTrue);
    expect(readinessLines(r), isEmpty);
  });

  test('counts line warns that they can go down', () {
    final r = readiness(
      input(weighOffsets: range(-40, -1), loggedOffsets: range(-3, -1)),
    );
    expect(readinessLines(r).last, contains('can go down'));
  });

  test('adapting always matches the engine weight over many histories', () {
    var checked = 0;
    for (final firstWeigh in [-60, -45, -35, -28, -20, -10]) {
      for (final weighStep in [1, 2, 4, 7]) {
        for (final loggedCount in [0, 3, 7, 8, 12, 18, 27]) {
          for (final phase in [null, -3, -12, -20]) {
            final weigh = [for (var o = firstWeigh; o <= -1; o += weighStep) o];
            final i = input(
              weighOffsets: weigh,
              loggedOffsets: range(-loggedCount, -1).where((o) => o != 0),
              previousPhaseStart: phase == null ? null : addDays(today, phase),
            );
            final e = recommend(i).explanation;
            final r = readinessOf(i, e);
            expect(
              r.adapting,
              e.weight > 0,
              reason:
                  'firstWeigh=$firstWeigh step=$weighStep '
                  'logged=$loggedCount phase=$phase weight=${e.weight} '
                  'n=${e.loggedDays} k=${e.weighInsInWindow} '
                  'span=${r.weighInSpanDays} needsSpan=${r.needsSpan} '
                  'settling=${r.settlingDaysLeft}',
            );
            checked++;
          }
        }
      }
    }
    expect(checked, greaterThan(400));
  });

  group('basisLine', () {
    test('formula only: says it is rough', () {
      final e = recommend(input(weighOffsets: [-1], loggedOffsets: const []))
          .explanation;
      expect(basisLine(e), contains('Formula estimate'));
      expect(basisLine(e), contains('rough'));
    });

    test('full data: counts, span and split, with no range', () {
      final e = recommend(
        input(weighOffsets: range(-60, -1), loggedOffsets: range(-27, -1)),
      ).explanation;
      final line = basisLine(e);
      expect(line, contains('Based on ${e.loggedDays} fully logged days'));
      expect(line, contains('${e.weighInsInWindow} weigh-ins over'));
      expect(line, contains('counts 100% (formula 0%)'));
      expect(line, isNot(contains('±')));
      expect(line, isNot(contains('give or take')));
    });

    test('partial data: percentages add up to 100', () {
      final e = recommend(
        input(weighOffsets: range(-60, -1), loggedOffsets: range(-12, -1)),
      ).explanation;
      final m = RegExp(r'counts (\d+)% \(formula (\d+)%\)')
          .firstMatch(basisLine(e))!;
      expect(int.parse(m[1]!) + int.parse(m[2]!), 100);
    });
  });
}
