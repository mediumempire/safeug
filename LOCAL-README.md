# SafeUG laptop workspace (updated)

The applications are now separate:
- Mobile: http://127.0.0.1:8099/
- Admin: http://127.0.0.1:8099/admin/
- APK: `build/app/outputs/flutter-apk/app-release.apk`

Admin username is `admin`. The first server start generates a password in
`local/data/admin-bootstrap.txt`. Keep this file private. See
`docs/LOCAL-SYSTEM.md` for the current setup, capabilities and limitations.

Start from PowerShell with `.\start-local.ps1`. For rebuild commands, physical
phone connection instructions and remaining provider dependencies, use the
current guide linked above. This is a local prototype, not an operational
emergency-dispatch service.
