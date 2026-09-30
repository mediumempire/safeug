# SafeUG separated laptop prototype

Run `./start-local.ps1` from the project directory. No Firebase account is needed.

Mobile web: http://127.0.0.1:8099/. Admin: http://127.0.0.1:8099/admin/.
The mobile app never switches into the dashboard, even on a large screen.
The admin site requires sign-in. First start generates a password in
`local/data/admin-bootstrap.txt`; username is `admin`. Sessions last eight hours.
The login form accepts both username and password; use the existing `admin`
username. This does not create additional administrator accounts.
Device tokens cannot edit guides, tips, services or other devices' reports.

## Connected workflows

- Mobile and admin now share the benchmark's SMART report categories:
  Suspicious Activity, Animal Sighting, Safety Hazard, Human-Wildlife Conflict,
  Illegal Encroachment and Other, alongside operational emergency categories.
  Reports carry severity, occurrence time, description, landmark or device GPS,
  capture time/accuracy, optional reporter/contact details and photo/video evidence.
  Administrators see the same fields, attachments and response history.
- Both applications have a Light/Dark toggle in the header; each remembers its
  own preference and otherwise follows the device theme. Mobile has no Activity
  feed or operational incident list. Reporting is a dedicated navigation action.
- SOS saves on-device before delivery. Retry every five seconds while open,
  prioritizing SOS/ranger-down before poaching/backup and ordinary reports.
  The button changes to ACTIVE immediately after durable local storage. Current
  GPS is requested separately so permission failures never prevent the alert.
  Incident IDs prevent duplicates after retries. ACTIVE survives navigation and
  restart. Tapping ACTIVE asks whether the user is safe; stand-down remains pending
  until the server receives it, then closes the alert with an audit entry.
  A location update and stand-down request also survive offline restarts.
- SOS notifications follow actual server records: saved locally, received,
  acknowledged, dispatched, en route and resolved. Admin's **Record security
  response** supplies the contacted agency and confirmed instructions. These are
  explicitly attributed to admin. The reference guest app's timed authority
  notifications are not treated as proof of responder contact.
- Admin monitors SQLite data and changes response status. It publishes guides,
  tips, emergency services and parks. `Inactive` withdraws a published entry.
- Reports attach camera/gallery photos or short videos: four files totaling
  8 MB native or 2 MB web. Storage failures are shown, not called delivered.
  Only the reporting device and admin can open uploaded evidence.
  Photo and Video controls are available on both mobile and admin report forms.
  On mobile, select `Send report to admin`; queued attachments travel with the
  report after reconnection. Admin opens attachments from the incident details.
- Device GPS buttons replace manual latitude/longitude inputs in admin records
  and reporting. Coordinates remain available in incident details/maps. Location
  permission denial, disabled services and timeouts show a landmark fallback.
  Browser camera controls open a webcam preview and support photo capture or
  up to 15 seconds of video; gallery uploads remain separate. Camera tracks are
  released on completion/cancel. Browser hardware features need HTTPS or localhost.
- Emergency numbers open the dialer; they do not automatically dispatch help.
  Admins should verify local coverage and keep contacts current.
- Foreground device location refreshes every 30 seconds while the app is open.
  Selected personal contacts can view it through revocable links; opening a
  different screen does not stop updates. Suspension stops refreshes and links
  reject positions older than two minutes. Operators must check timestamps.
- Ranger check-ins include name, area, duty and health notes. Ranger-down and
  backup requests are incident categories. Automated nearest-unit routing,
  scheduled missed-check-in escalations and remote push delivery are not built.
- Voice translator uses device speech recognition/output. Three offline phrases
  cover five languages. Arbitrary text needs a LibreTranslate-compatible engine,
  installed/configured separately. Voice availability depends on installed
  language packs and permissions. Review translations before operational use.
- Maps have OpenStreetMap basemaps, requiring internet. Offline map downloads
  and phone-to-phone mesh transmission are not implemented.

## Provider provisions

SMS, radio, satellite and EarthRanger are disconnected pending UWA requirements,
as requested. Admin Settings lists connection requirements. The generic HTTPS
dispatch adapter is disabled by default; submission is not responder acceptance.
See `UWA-INTEGRATIONS.md`. No real responder is contacted in the default setup.
Create private `local/.env.local` using `local/provider-settings.example` names.
The startup script loads it; never put secrets in Flutter source or builds.

## Android and iOS

APK: `build/app/outputs/flutter-apk/app-release.apk`, prototype signing.
Emulator default: `http://10.0.2.2:8099`. For a USB-connected phone, run
`adb reverse tcp:8099 tcp:8099`, then More > Connection settings >
`http://127.0.0.1:8099`. This keeps the laptop service private.

For a trusted LAN, explicitly set `$env:SAFEUG_HOST='0.0.0.0'` before starting,
then configure the app with the laptop LAN address. No firewall rules are changed.
Do not expose this HTTP prototype publicly; use HTTPS for real deployments and
browser camera/location beyond localhost. Native permissions still apply.

iOS sources and permissions are included. IPA build/sign/install requires macOS,
Xcode and Apple provisioning and has not been performed on this Windows laptop.
Physical camera/microphone, installed APK and field tests remain outstanding.

## Data and scope

SQLite records/evidence: `local/data/safeug.sqlite`. Back up while stopped.
Device credentials use secure storage. Offline reports/cache use local app
storage; SQLite is not encrypted by this prototype. Use device encryption and
restrict laptop access. Production security, retention and life-safety acceptance
remain separate work. A fresh browser launch needs the laptop service; native
launch works offline. Keep the app open for retries.

Legacy Firebase code remains as reference; current entrypoints do not initialize
Firebase. Existing records are retained; records without device ownership are
admin-only. The former unauthenticated mobile cache is no longer used.

Benchmark review used the guest login at
https://studio-4293160039-89d0f.web.app on 30 September 2026. It covered the SOS
ACTIVE/standby flow, notifications, theme toggle, SMART report categories and
required location/description, tracking, guides and emergency services. The
local applications use the existing shared SQLite API; this change does not
connect or deploy them to the hosted reference's Firebase data.

## Rebuild

### Live synchronization and system alerts (1.0.5+8)

The mobile home screen no longer shows the technical response card, raw GPS
accuracy, placeholder agency notices or manual response refresh controls. It
shows a short status only for the current active SOS. Closed alerts disappear
from Home; details and audit history stay in the admin portal.

After each SQLite commit, authenticated `/api/changes` listeners are released
immediately. Clients fetch their authoritative `/api/state`, then listen again.
Revisions include a server epoch for restart recovery and are scoped by role and
device ownership. The admin sees all authorized records; devices only see their
own private records and published content. The five-second timer is now an
offline/reconnection fallback, not the normal update path. Changes queued while
a refresh is in progress run as soon as it completes. Stale overlapping snapshots
cannot overwrite a newer save receipt.

All admin screens show an urgent Review SOS banner until an SOS is acknowledged.
Use the bell button once to grant notification permission. Android uses a native
high-importance notification channel; browsers use the Notifications API and a
dedicated click-handling service worker (HTTPS or localhost required). An iOS
UNUserNotificationCenter bridge is included but requires an Xcode/device build.
Notifications follow saved SOS delivery, response/agency confirmations and closure;
GPS updates and repeated refreshes do not produce duplicates. Notification receipts
are deduplicated across restarts.

These OS notifications work while the client is connected/running. Fully closed
or OS-suspended clients need remote push delivery. That is not configured: this
workspace lacks native Firebase registrations (`google-services.json` and iOS
configuration), APNs credentials and a server push credential. The reference web
Firebase app ID is not a valid substitute for native registrations. No claim is
made that the current local notifications can wake a terminated app.

API tests verify immediate SOS/admin wake-up, return status updates, matching
incident fields on both clients, reconnect catch-up, ownership isolation, revoked
sessions and idempotent retries. Store tests cover concurrent queueing and stale
snapshots; notification tests cover deduplication and real agency confirmations.

### Mobile navigation (1.0.4+7)

The mobile bottom bar contains Home, Map and Report. Emergency Center opens
from its home shortcut with a back button. The former More destinations remain
accessible from the home screen, including protected areas, ranger check-in and
connection settings.

### SOS visual update (1.0.3+6)

The mobile SOS control has a crimson gradient, expanding signal rings, a soft
glow and press feedback. ACTIVE uses amber, a travelling arc and an explicit
SOS-in-progress label. Animation does not delay alert creation or stand-down
confirmation. Decorative motion stops for reduced-motion settings, hidden
routes and app suspension. Both light and dark themes use the same clear labels.
`tool/render_sos_preview.dart` renders the real widget for visual review; its
preview is saved in `output/benchmark-review/sos-button-design.png`.

### Emergency contacts and location sharing (1.0.2+5)

Emergency Center has Local Services and My Contacts tabs. Personal contacts
are owned by the authenticated device and contain name, relationship and phone.
Adding, editing, removing and changing sharing consent require a server receipt;
failed updates leave the last confirmed setting visible. Removing a contact
revokes their link and hides them from both personal-contact screens.

The shell detects device location on opening and resuming, and refreshes every
30 seconds while in the foreground after a successful fix. Both mobile and admin
use device permission prompts, never manual latitude/longitude fields. Reports
automatically request a fix; denied access preserves the landmark fallback.

Each enabled personal contact receives a unique 256-bit capability link. The
user sends it with the SMS composer or copies it to their chosen messenger.
The server serves only the owner's most recent location through that link,
checks consent on every request and rejects fixes older than two minutes.
Disabling sharing, removing a contact or changing their phone revokes the old
link. Re-enabling creates a new link. Anyone holding a link can view its location
until revocation/expiry, so send it only to the intended contact. Foreground
updates stop when the app is suspended; no background tracking or automatic
SMS delivery is configured. Recipients need network access to the configured
SafeUG server; laptop/emulator loopback addresses are not public share URLs.

The earlier timed agency notices have been replaced by system notifications for
actual response updates. Pending requests never claim agency contact. Admin-recorded
contact confirmations are retained separately in `agencyResponses`; SOS records
include `requestedAgencies`. Closing the SOS clears pending activation notices.
No automatic agency dispatch or provider acknowledgement is configured locally.

Tour guides show visitor ratings as an average out of five, five stars and a
rating count. Unrated guides show "No ratings yet". Mobile visitors can save or
change one rating per authenticated device; a repeat submission replaces that
device's vote. Ratings are stored in SQLite's `guide_ratings` table. The server
calculates `rating` and `ratingCount` for both clients, and returns only the
requesting visitor's `myRating`. Administrators cannot manufacture ratings by
editing a guide. A rating update wakes all connected mobile and admin clients
through the existing authenticated live channel. Saving a rating requires a
connection; failed saves can be retried without duplicate votes.

"Contact now" opens a WhatsApp chat through `https://wa.me/` using the guide's
published phone number. Ten-digit Uganda numbers beginning with 0 are converted
to +256; international numbers use their country code. Incomplete numbers disable
the chat button; correct them using "Phone / WhatsApp number" in the admin editor.
Opening the chat does not send a message. The guide must use WhatsApp at that
number. Admin edits to guide names, areas, descriptions, phone numbers and status
remain synchronized with mobile; deactivated guides are removed from mobile.

Verified on 30 September 2026 with the guide update: 44 Flutter test cases and all five backend tests
pass; full Flutter analysis reports no issues. Release mobile web, admin web
and Android APK builds succeed. Earlier browser checks used an isolated in-memory
database and verified SOS activation/reload, persisted dark mode, admin response
visibility, gallery report submission, saved evidence viewing and camera preview.
QA images are under `output/benchmark-review/`. Physical capture, microphone and
successful GPS reception still require device testing. No real dispatch was sent.
Browser access to the local test page was denied for the contact-sharing follow-up;
that follow-up was verified with widget, API and authorization/revocation tests.

Brand artwork is stored unchanged in `assets/branding/safeug-logo.png`.
Android/iOS launcher icons and web favicon/install icons are generated with
`dart run flutter_launcher_icons` using the configuration in `pubspec.yaml`.
The supplied logo is also used in app headers, admin login and native launch
screens. iOS icons/splash assets still require an Xcode build to install.

```powershell
flutter pub get
flutter analyze
flutter test
node --test local/server.test.mjs local/contacts.test.mjs local/realtime.test.mjs local/guides.test.mjs
flutter build web --release -t lib/mobile_main.dart
flutter build web --release -t lib/admin_main.dart --base-href /admin/ --output build/admin
flutter build apk --release -t lib/mobile_main.dart
```
