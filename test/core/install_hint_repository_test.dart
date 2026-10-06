import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/core/install_hint_repository.dart';
import 'package:nutrition_app/data/db/database.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('never dismissed loads as null', () async {
    expect(await loadInstallHintDismissedAt(db), isNull);
  });

  test('dismissal round-trips in UTC', () async {
    final now = DateTime(2026, 10, 6, 12);
    await saveInstallHintDismissedAt(db, now);
    final loaded = await loadInstallHintDismissedAt(db);
    expect(loaded, now.toUtc());
  });
}
