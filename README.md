# SafeUG

SafeUG is a Flutter safety app for Android, iOS and web, with a separate admin portal and an authenticated Node.js/SQLite backend.

- Mobile web: https://www.safeug.online/
- Administration: https://www.safeug.online/admin/
- Native apps use the same HTTPS backend.

These are the intended deployment URLs; see deployment status before assuming a release is live.

## Deploy to Apache / Virtualmin

Follow [the VPS deployment guide](docs/VPS-DEPLOYMENT.md). It includes DNS, SSL, systemd, private data migration, backups, signing and rollback. The supplied scripts target a single Linux VPS and keep SQLite data outside code releases.

On Windows, build a web/backend release with:

```powershell
.\tool\build-release.ps1
# Once a release keystore is configured:
.\tool\build-release.ps1 -IncludeAndroid
```

The output bundle is under `output/releases/`. It excludes the database, credentials and private signing keys. Do not upload the whole workspace to public_html.

## Development

Requirements: Flutter 3.44.0 / Dart 3.12, Node.js 24 LTS. The backend has no npm dependencies.

```bash
flutter pub get
node local/server.mjs
flutter run -t lib/mobile_main.dart --dart-define=SAFEUG_API_URL=http://10.0.2.2:8099 --dart-define=SAFEUG_ALLOW_SERVER_OVERRIDE=true
```

The URL above is only for an Android emulator during development. Release apps default to the public HTTPS service and hide the server override. Web builds use their current origin. To build the two web clients locally:

```bash
flutter build web --release --no-wasm-dry-run -t lib/mobile_main.dart
flutter build web --release --no-wasm-dry-run -t lib/admin_main.dart --base-href /admin/ --output build/admin
```

Open `http://127.0.0.1:8099/` and `/admin/`. Local first-start credentials are stored privately in `local/data/admin-bootstrap.txt`. Production creates its environment outside the repository instead.

## Validation

```bash
flutter analyze
flutter test
node --test local/*.test.mjs
```

GitHub Actions runs validation and packages deployable web/backend artifacts. It does not automatically change the VPS.

## Features

SOS with live admin updates, incident photo/video and device location, private emergency contacts and location sharing, light/dark themes, tour-guide ratings and WhatsApp contact links. Published records and incident statuses synchronize through the shared backend.

OS notifications currently need the client running/connected. Closed-app push and external agency dispatch require separate provider setup. iOS signing needs a Mac/Xcode and Apple Developer access. The single-server deployment has not been load-tested for a viral traffic surge.

Implementation details: [system notes](docs/LOCAL-SYSTEM.md). Earlier Firebase implementation notes are preserved in [legacy documentation](docs/FIREBASE-LEGACY.md); that is not the active VPS backend.
