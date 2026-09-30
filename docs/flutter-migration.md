# Flutter migration handoff

## What changed

The application root is now a Flutter project. The Android and iOS runners
use `com.safeug.app`, matching the Play Console package name. The previous
Capacitor Android wrapper is retained in `android-capacitor-legacy/` as a
recoverable reference.

The Flutter app maps the existing product areas to native screens:

| Existing feature | Flutter implementation |
| --- | --- |
| Landing page and auth | `lib/screens/landing_screen.dart`, `lib/screens/auth_screen.dart` |
| Dashboard and role mode | `lib/screens/dashboard_screen.dart` |
| SOS and live location history | `SosButton` and `FirestoreService` |
| Emergency services and contacts | `lib/screens/emergency_screen.dart` |
| Guides | `lib/screens/guides_screen.dart` |
| Safety alerts | `lib/screens/safety_screen.dart` |
| SMART community reports | `lib/screens/report_screen.dart` |
| Location sharing | `lib/screens/tracking_screen.dart` |
| Translation | `lib/screens/translate_screen.dart` |

## Important release work

1. Sign in with the Firebase project owner and run `flutterfire configure`.
   The current workspace account cannot see `studio-4293160039-89d0f`, so the
   native Firebase registrations could not be created automatically here.
2. Confirm `com.safeug.app` is registered as both the Android package and iOS
   bundle ID in the same Firebase project.
3. Configure a release signing key and increment the Android version code from
   the current `4` for the next Play upload.
4. Run `flutter build ios --release` on macOS with Xcode and configure the Apple
   signing team, bundle ID, and App Store provisioning.
5. Connect `SAFEUG_AI_ENDPOINT` to a server-side AI gateway. Do not put the
   Gemini API key in Flutter source or `--dart-define` values shipped to users.

The local Android SDK can compile a debug APK, but its NDK is missing
`llvm-strip`, so Flutter reports a native-symbol stripping failure during
release verification. The generated local AAB is archive-integrity checked
and signed with the preserved SafeUG upload key; run the release build again
on a complete Android SDK/NDK before uploading it to Play Console.

## Web deployment

`firebase.json` now points Firebase Hosting at `build/web`. Build the Flutter
web target and deploy from an account that has access to the SafeUG Firebase
project. The existing SafeUG URL is `https://studio-4293160039-89d0f.web.app`;
the example `studio-2610581681-db14c.web.app` belongs to a different Firebase
project and should not be overwritten.
