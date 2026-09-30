# SafeUG Flutter app

## Current laptop-only version

The active app now starts without Firebase. Run `.\start-local.ps1` and open
http://127.0.0.1:8099 for mobile or http://127.0.0.1:8099/admin/ for the
administrator-only website. Separate apps share a protected local SQLite API.
Use `lib/mobile_main.dart` for mobile builds and `lib/admin_main.dart` for admin.
See [LOCAL-README.md](LOCAL-README.md) for current features, testing and APK setup.
The Firebase instructions below describe the preserved earlier implementation.

SafeUG is now implemented as a native Flutter application targeting Android,
iOS, and Flutter web. The app keeps the existing Firebase data model and
supports:

- Firebase email/password and anonymous sign-in
- SOS incident creation, location history, and response status updates
- Persistent local SOS queue with manual retry when Firebase delivery is unavailable
- Emergency contacts and location-sharing controls
- Emergency service calling
- Local guide discovery
- Safety guidance, translation, and SMART community reports
- Authority role detection and active incident monitoring

## Run locally

```bash
flutter pub get
flutter run
```

Android uses the existing Play package ID `com.safeug.app`. Debug builds use
`com.safeug.app.debug` so they can be installed beside the Play-signed app.

## Firebase setup

The source project is `studio-4293160039-89d0f`. The checked-in
`lib/firebase_options.dart` keeps the existing registered Web app as a
development fallback. Before publishing the mobile app, sign in to the
Firebase account that owns that project and run:

```bash
flutterfire configure \
  --project=studio-4293160039-89d0f \
  --platforms=android,ios,web \
  --android-package-name=com.safeug.app \
  --ios-bundle-id=com.safeug.app
```

Enable Email/Password and Anonymous providers in Firebase Authentication and
deploy the rules from `firestore.rules` if the project has not already done
so.

## AI gateway

Mobile builds never embed a Gemini key. To connect live AI responses, provide
an HTTPS gateway implementing `POST /safety-alerts`, `POST /translate`, and
`POST /community-report`, then build with:

```bash
flutter build apk --dart-define=SAFEUG_AI_ENDPOINT=https://your-gateway.example/
```

Without the gateway, the app uses clearly-labelled built-in safety guidance
and translation/report fallbacks.

## Prototype builds

```bash
flutter build appbundle --release
flutter build ios --release --no-codesign
flutter build web --release
firebase deploy --only hosting
```

The Flutter web build is configured to use the Firebase default hosting domain
for the selected Firebase project, e.g. `https://<project-id>.web.app`.

This workspace produces an installable prototype APK at
`build/app/outputs/flutter-apk/app-release.apk`. When no private release
keystore is present, the release variant intentionally falls back to the
standard debug key for prototype testing. Configure a private upload keystore
before publishing to Google Play or distributing a production iOS build.

## Offline SOS behavior

SafeUG first attempts the normal Firebase incident flow. When that delivery
fails, it stores the SOS timestamp, available GPS coordinates, and emergency
contact IDs locally. The dashboard then exposes a retry action; successful
retries use the same Firestore incident payload as an online SOS.

This is store-and-forward resilience, not a physical mesh, SMS, satellite, or
radio transport. Those genuinely off-grid transports require a chosen carrier
or hardware integration and backend dispatch agreement.

The old Capacitor wrapper is preserved in `android-capacitor-legacy/` until
the Flutter release has been accepted in Play Console.
