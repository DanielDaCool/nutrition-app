// Reads how the web app is running (see install_hint.dart). Picks the web
// implementation when dart:js_interop exists and a constant everywhere else,
// so Android never compiles the web code.

export 'browser_install_stub.dart'
    if (dart.library.js_interop) 'browser_install_web.dart';
