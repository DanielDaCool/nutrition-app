// Non-web version of requestPersistentStorage: there is no browser storage to
// protect on Android, so it does nothing.

/// No-op off the web.
Future<void> requestPersistentStorage() async {}
