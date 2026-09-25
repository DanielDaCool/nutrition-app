import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day_key.dart';
import '../data/db/database.dart';

/// The app database. Overridden in main() (real file) and in tests (in-memory).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Current time source; override in tests to pin "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The day shown on the Today screen (defaults to today; user can browse back).
final selectedDayProvider =
    NotifierProvider<SelectedDay, String>(SelectedDay.new);

class SelectedDay extends Notifier<String> {
  @override
  String build() => dayKeyOf(ref.read(clockProvider)());

  void set(String dayKey) => state = dayKey;

  void today() => state = dayKeyOf(ref.read(clockProvider)());
}
