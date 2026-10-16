# Distributing through Google Play (closed testing)

Friends install from the Play Store, so Samsung's Auto Blocker never gets in
the way. A `v*` tag builds a signed app bundle and uploads it to the closed
testing track (`alpha`). Without the secrets below, CI skips the upload and
still attaches the APK to the GitHub release.

## One-time setup (needs the account owner)
1. Create a Play Console personal developer account (one-time fee, identity check).
2. Create the app with package name `com.danieldacool.nutrition_app` and finish
   the app setup (privacy policy, data safety, content rating). Keep Play App
   Signing on.
3. Create a Google Group and let friends join it (a link or invite).
4. Testing > Closed testing: use the default track (`alpha`), add the Google
   Group as testers, and copy the opt-in link for friends.
5. Upload the **first** bundle by hand (`flutter build appbundle --release`
   with the release key): the API cannot create the first release of a new app.
6. Google Cloud: create a service account, enable the Google Play Android
   Developer API, make a JSON key. In Play Console > Users and permissions,
   invite the service account and grant release access to this app.
7. GitHub repo secrets: `PLAY_SERVICE_ACCOUNT_JSON` (the whole JSON key) and
   the existing `ANDROID_KEYSTORE_*` secrets.

## Releasing
Bump `version:` in `pubspec.yaml` (the build number after `+` must rise on every
upload), merge, then push the matching `vX.Y` tag.

## Switching friends over from the GitHub APK
Play and the GitHub APK may use different signing keys (Play App Signing
re-signs with its own key), so they cannot update each other. Friends must
export a backup, uninstall the APK, then install from Play and restore.
