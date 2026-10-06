// Web version of readBrowserInstallInfo. Uses minimal dart:js_interop
// bindings instead of package:web (only a transitive dep), like
// persistent_storage_web.dart.

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'install_hint.dart';

@JS('navigator')
external _Navigator? get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external String get userAgent;

  /// Missing in some older browsers.
  external JSNumber? get maxTouchPoints;

  /// iOS only: true when opened from the Home Screen.
  external JSBoolean? get standalone;
}

@JS('matchMedia')
external _MediaQueryList _matchMedia(String query);

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}

/// Reads the user agent and display mode. Never throws: anything unexpected
/// reads as [BrowserInstallInfo.notApplicable], so the hint stays hidden.
BrowserInstallInfo readBrowserInstallInfo() {
  try {
    final nav = _navigator;
    if (nav == null) return BrowserInstallInfo.notApplicable;
    final isIos = isIosUserAgent(
      nav.userAgent,
      maxTouchPoints: nav.maxTouchPoints?.toDartInt ?? 0,
    );
    final standalone =
        (nav.standalone?.toDart ?? false) ||
        _matchMedia('(display-mode: standalone)').matches;
    return BrowserInstallInfo(isIos: isIos, standalone: standalone);
  } catch (e) {
    debugPrint('install hint: browser info unavailable: $e');
    return BrowserInstallInfo.notApplicable;
  }
}
