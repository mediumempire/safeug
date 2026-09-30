# Tourist registration

Tourists can select **Register as tourist** on Home or More. SOS does not require registration.

Full name and phone are required. Email, country, park/area and emergency contact details are optional. The tourist must consent to sharing the profile with administrators.

Registration is tied to this installation/browser's device credential, not an email/password account. Reinstalling or clearing credentials creates a new device identity. Updating the profile on the same device updates the same server record.

The app saves registration locally first and retries every five seconds, after pending incident signals. The profile displays a pending state until accepted. The admin dashboard's Tourists section and overview count refresh automatically every five seconds while connected. Open a tourist record to see all contact fields.

Offline profiles cannot appear on the dashboard until the device can reach the laptop server. On a physical phone, configure the laptop's reachable LAN address, not 127.0.0.1; the server must be explicitly bound to that interface and Windows Firewall must permit the connection. Use a trusted private network for this HTTP prototype. No external dispatch service is contacted by registration.

Only administrators can see all profiles. A mobile device can read and update its own profile only. Server-owned identity, status and timestamps cannot be set through registration. Registration does not start location sharing.

Prototype limitation: personal details are cached in device preferences and stored in laptop SQLite. Production requires HTTPS, encrypted storage, retention/deletion policies and an account recovery design. iOS source is included; building and signing an iOS app requires macOS/Xcode.

Verification: backend tests cover consent, invalid email, automatic admin visibility, idempotent updates, status preservation and cross-device isolation. Flutter tests cover form validation/consent and offline persistence across store restarts.
