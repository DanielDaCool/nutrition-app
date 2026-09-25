// Drift table-change stream helper used by the weight and dashboard
// providers.
import 'dart:async';

import 'package:drift/drift.dart';

/// Emits [fetch]() now and again after every write to one of [tables].
///
/// Like drift's `.watch()`, but cancelling doesn't leave drift's zero-duration
/// "keep the cache a moment longer" timer behind, which otherwise fails widget
/// tests that unmount the app ("A Timer is still pending") and blocks
/// `db.close()` in their tear-down.
///
/// Refreshes never overlap: a change during a fetch triggers one more fetch
/// afterwards. Fetch errors are emitted as stream errors.
Stream<T> watchTables<T>(
  DatabaseConnectionUser db,
  Iterable<ResultSetImplementation> tables,
  Future<T> Function() fetch,
) {
  late final StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? updates;
  var running = false;
  var again = false;
  var cancelled = false;

  Future<void> refresh() async {
    if (running) {
      again = true;
      return;
    }
    running = true;
    do {
      again = false;
      try {
        final value = await fetch();
        if (!cancelled) controller.add(value);
      } catch (e, st) {
        if (!cancelled) controller.addError(e, st);
      }
    } while (again && !cancelled);
    running = false;
  }

  controller = StreamController<T>(
    onListen: () {
      updates = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => refresh());
      refresh();
    },
    onCancel: () {
      cancelled = true;
      updates?.cancel();
    },
  );
  return controller.stream;
}
