# Local SafeUG verification

Branding follow-up: supplied SafeUG logo copied without modification (SHA-256
matches the original). Android/iOS launcher icons and web favicon/install icons
regenerated. Admin login and mobile header visually checked at 1280 x 800 and
390 x 844. Screenshots: `output/playwright/safeug-logo-admin.png` and
`output/playwright/safeug-logo-mobile.png`. Both web builds and the 55 MB Android
APK succeeded. Full ten-test suite passed; focused six-test suite passed again
with logo-asset assertions. Analysis passed. iOS icon/launch-screen assets are
prepared but require an Xcode build; native launch screens were not device-tested.

Verified on Windows, September 28, 2026. Latest username/evidence follow-up:

- Ten Flutter tests pass, including username/password submission and photo/video
  picker-to-report payload tests for both mobile and admin forms. Media pickers
  are stubbed in these tests, not a physical-device camera certification.
- Browser checks confirm editable Username/Password fields at 1280 x 800 and
  separate Photo/Video capture/gallery controls plus Send report to admin at
  390 x 844. Screenshots: `output/playwright/admin-username-login.png` and
  `output/playwright/report-photo-video.png`. Analysis reports no issues.
- API checks reject a wrong username even with the correct password, and permit
  admin retrieval of photo and video payloads. The video test is a header fixture,
  not a playback test.

Earlier separated-app checks:

- Seven Flutter tests passed, including mobile-only layout at desktop width,
  read-only guide directory and admin sign-in screen isolation.
- API integration checks passed: authentication, admin-only mutation, ownership,
  catalog publication, private evidence retrieval, invalid file signatures,
  logout, deduplication and disabled dispatch/translation without providers.
- Current release builds: separate mobile web and admin web, plus 54 MB Android APK.
- Browser: 1440 x 960 admin overview and map; 390 x 844 mobile SOS screen.
- Browser: offline SOS saved and automatically replayed after returning online.
- Browser: emergency directory loaded all three services; no calls were placed.
- Browser: gallery image attached to a test report, synchronized and displayed
  through the authenticated evidence viewer. Native capture/video/voice and GPS
  were not tested on a physical device.
- Admin API resolved the two reports created by this QA device; both updates
  appeared in mobile Activity. Older laptop records were left unchanged.
- Browser offline phrasebook produced a result and enabled speech output while
  offline. Actual microphone capture and audio playback were not tested.
- Fixed a stale Flutter default-target web plugin registry. Rebuild the mobile
  app explicitly with `-t lib/mobile_main.dart` as documented.
- Screenshots: `output/playwright/separated-admin.png`, `separated-mobile.png`
  and `evidence-preview.png`.

Historical checks from the earlier combined prototype follow. They do not
describe the current authorization model or current number of tests.

- SQLite API integration: passed create incident, operator update, idempotent
  retry, ranger creation, input validation and cross-origin rejection.
- Flutter tests: four passing queue and widget tests.
- Desktop screenshot at 1280 x 720: green sidebar, overview counters, Uganda map
  and recent incidents rendered without overlap.
- Mobile screenshot at 390 x 844: SOS is visible immediately; bottom navigation,
  report and map controls fit within the viewport.
- Browser workflow: mobile SOS appeared in the local SQLite API and admin
  overview. Resolving it through admin updated mobile Activity to Resolved.
- Service-stop test: SOS showed Saved on device with one pending signal.
  Restarting the same SQLite service automatically delivered it as Reported and
  cleared the pending queue, without signing in.
- Flutter analysis: no issues. Browser console errors were exclusively expected
  connection-refused requests during the deliberate service-stop test.

Screenshots: `output/playwright/local-desktop.png` and
`output/playwright/local-mobile.png`.

No external emergency authority was contacted. Test SOS records remain in the
local workspace. Native phone installation and iOS signing were not tested.
