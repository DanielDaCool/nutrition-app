// Asks the browser to keep the app's storage (web only). Picks the web
// implementation when dart:js_interop exists and a no-op everywhere else, so
// Android never compiles the web code.

export 'persistent_storage_stub.dart'
    if (dart.library.js_interop) 'persistent_storage_web.dart';
