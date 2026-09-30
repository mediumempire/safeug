$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'build/web/index.html')) {
    flutter build web --release -t lib/mobile_main.dart
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
}
if (-not (Test-Path 'build/admin/index.html')) {
    flutter build web --release -t lib/admin_main.dart --base-href /admin/ --output build/admin
    if ($LASTEXITCODE -ne 0) { throw 'Flutter admin build failed.' }
}
if (Test-Path 'local/.env.local') {
    node --env-file=local/.env.local local/server.mjs
} else {
    node local/server.mjs
}
