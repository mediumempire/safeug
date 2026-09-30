# SafeUG implementation and deployment

The supplied September 28 designs inform the forest-green navigation, compact
operations console, and simplified four-destination mobile navigation.

## Connected workflows

- Admin access comes from `roles_admin/{Firebase user UID}`; no client role toggle.
- Mobile SOS and admin incidents share `users/{uid}/incidentReports/{id}`.
- Operator updates are observed by the active mobile SOS listener.
- SOS is stored on device before delivery. A stable document ID makes retries
  idempotent; transactions do not reset an existing incident's response status.
- Pending signals remain scoped to the signed-in account during retry.
- Ranger, protected-area, wildlife and field-device records support admin create,
  edit, live list and search; their collections have matching Firestore rules.
- Community reports and tourist records are visible to authorized operations staff.
- GPS links open the reported coordinates in an external map.

## Required before production validation

Deploy the revised `firestore.rules` to the intended Firebase project and provision
the initial administrator role through a trusted Firebase administrator. No roles
or security rules have been deployed by this implementation session.

Register native Android and iOS Firebase apps and replace the temporary web-app
IDs in `lib/firebase_options.dart`. Configure Firebase email/password and anonymous
authentication. A live two-account test must confirm mobile submission, admin
receipt and operator status update reaching mobile.

Off-grid radio, satellite, EarthRanger and agency dispatch gateways are not
configured. Local persistence is not delivery to a responder. The app no longer
claims police dispatch based on elapsed time. Field-device records are manually
maintained inventory, not automatic device telemetry. No live embedded tracking
map, media upload or ranger patrol workflow is implemented in this revision.

iOS requires Xcode on macOS for signing and device validation. Prototype APKs use
debug signing only when no private release keystore is configured.
