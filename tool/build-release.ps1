param(
    [string]$FlutterRoot = 'C:\flutter',
    [switch]$IncludeAndroid
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$dart = Join-Path $FlutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = Join-Path $FlutterRoot 'bin/cache/flutter_tools.snapshot'
if ($IncludeAndroid -and !(Test-Path 'android/keystore.properties')) {
    throw 'Configure your production release key in android/keystore.properties first. Never distribute a debug-signed APK.'
}
function Invoke-Flutter {
    & $dart $flutterTool @args
    if ($LASTEXITCODE -ne 0) { throw "Flutter command failed: $args" }
}
Invoke-Flutter pub get
Invoke-Flutter build web --release --no-pub --no-wasm-dry-run -t lib/mobile_main.dart
Invoke-Flutter build web --release --no-pub --no-wasm-dry-run -t lib/admin_main.dart --base-href /admin/ --output build/admin
if ($IncludeAndroid) {
    Invoke-Flutter build apk --release --no-pub -t lib/mobile_main.dart --dart-define=SAFEUG_API_URL=https://www.safeug.online --dart-define=SAFEUG_ALLOW_SERVER_OVERRIDE=false
    python tool/package_release.py --apk build/app/outputs/flutter-apk/app-release.apk
} else {
    python tool/package_release.py
}
if ($LASTEXITCODE -ne 0) { throw 'Release packaging failed' }
