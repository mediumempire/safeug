# Android release build

This project uses Capacitor to package the SafeUG Next.js app as an Android
wrapper.

## Important

SafeUG uses Next.js server actions for AI features. Build the Android release
against a deployed production URL. A local static export will not preserve those
server features.

Google Play Console expects an Android App Bundle (`.aab`) for new apps. The APK
is useful for direct device testing.

## Build commands

Set the Android Studio JDK for this Windows machine:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME='C:\Users\Administrator\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT='C:\Users\Administrator\AppData\Local\Android\Sdk'
```

Sync the Android wrapper with the deployed SafeUG URL:

```powershell
$env:CAPACITOR_SERVER_URL='https://your-production-safeug-url.example'
npm run android:sync
```

Build the signed Play Console bundle:

```powershell
npm run android:bundle
```

Build a signed APK for testing:

```powershell
npm run android:apk
```

## Outputs

- Play Console bundle: `android/app/build/outputs/bundle/release/app-release.aab`
- Test APK: `android/app/build/outputs/apk/release/app-release.apk`

## Signing

Release signing is configured through `android/keystore.properties` and
`android/keystore/safeug-upload-key.jks`. These files are intentionally ignored
by git. Keep a backup of both files and their passwords; without them, future
updates to the same Play app may be blocked.
