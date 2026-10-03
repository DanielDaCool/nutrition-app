// Web version of requestPersistentStorage: the whole database lives in the
// browser (IndexedDB), so ask the browser not to evict it. Uses minimal
// dart:js_interop bindings instead of package:web (only a transitive dep).

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('navigator')
external _Navigator? get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  /// Undefined in insecure contexts and older browsers.
  external _StorageManager? get storage;
}

extension type _StorageManager._(JSObject _) implements JSObject {
  /// Read as a property so a missing `persist` shows up as null.
  @JS('persist')
  external JSAny? get persistMethod;

  external JSPromise<JSBoolean> persist();
}

/// Calls `navigator.storage.persist()` and logs the answer. Never throws.
Future<void> requestPersistentStorage() async {
  try {
    final storage = _navigator?.storage;
    if (storage == null || storage.persistMethod == null) {
      debugPrint('storage: persist() unavailable: not supported');
      return;
    }
    final granted = (await storage.persist().toDart).toDart;
    debugPrint('storage: persistent=$granted');
  } catch (e) {
    debugPrint('storage: persist() unavailable: $e');
  }
}
