// Non-web version of readBrowserInstallInfo: an installed Android app has
// nothing to install.

import 'install_hint.dart';

/// Always [BrowserInstallInfo.notApplicable] off the web.
BrowserInstallInfo readBrowserInstallInfo() => BrowserInstallInfo.notApplicable;
