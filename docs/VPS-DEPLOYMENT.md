# SafeUG on Apache / Virtualmin

Target: Ubuntu 24.04 LTS, VPS `169.58.25.182`, Namecheap DNS. Both A records were observed pointing to this IP and HTTPS served the Virtualmin welcome page during preparation.

The prepared release uses one backend and one persistent database for all clients:

| Client | Address |
| --- | --- |
| Mobile web | `https://www.safeug.online/` |
| Admin portal | `https://www.safeug.online/admin/` |
| Android / iOS API | `https://www.safeug.online/api/` |
| Health check | `https://www.safeug.online/healthz` |
| Android download, when included | `https://www.safeug.online/downloads/safeug.apk` |

Apache terminates HTTPS and proxies to Node on `127.0.0.1:8099`. Port 8099 stays
private; phones never connect to it. SQLite lives in `/var/lib/safeug/`, outside
versioned code releases. The release includes the compiled web applications, so
the VPS does not need Flutter, npm packages, Firebase Hosting or Next.js.

This guide prepares a single VPS deployment. It does not mean the domain is
already deployed. Confirm your VPS IP, Linux version, SSH access and DNS provider
before changing the server. Back up existing Virtualmin domain configuration.

## 1. DNS and Virtualmin domain

1. In Namecheap: Domain List → Manage → Advanced DNS → Host Records. Create an A record for `safeug.online`
   pointing to the VPS public IPv4. Create `www` as a CNAME to `safeug.online`, or
   an A record to the same IP. Only set AAAA if IPv6 actually reaches this server.
2. In Virtualmin create/select the `safeug.online` virtual server. Enable Apache
   website and SSL website. Ensure its aliases include `www.safeug.online`.
3. Allow incoming TCP 80 and 443. Restrict SSH and the Virtualmin management port
   to trusted administrators where possible. Do not expose 8099.
4. If DNS is on Cloudflare, begin with DNS-only (grey cloud). A later CDN proxy
   requires a deliberate Apache real-client-IP configuration; otherwise rate
   limiting may treat many visitors as one address.
5. Check from outside the VPS: `nslookup safeug.online` and
   `nslookup www.safeug.online` must resolve to the intended server.

## 2. Obtain HTTPS before adding the proxy

In Virtualmin, select the domain, then the SSL certificate screen (commonly
**Server Configuration → SSL Certificate → Let's Encrypt**). Request a
certificate covering **both** `safeug.online` and `www.safeug.online`; enable
automatic renewal. Keep the virtual server's document root available for
`/.well-known/acme-challenge/`.

Do this before adding blanket proxy rules. Camera, device location and browser
notifications need HTTPS. Do not ignore certificate warnings on phones.

## 3. Prepare Linux prerequisites

Use a currently supported Linux release. Ubuntu 22.04/24.04 or Debian 12/13:

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates xz-utils rsync
```

On a supported Rocky/AlmaLinux system:

```bash
sudo dnf install -y curl ca-certificates xz rsync
```

Node 24 LTS is installed separately under `/opt/safeug/node` by the supplied
script. This leaves Node installations used by other hosted sites unchanged.
Its official Linux archive is checked against Node's published SHA-256 list.

## 4. Upload and install a release

The Windows build command is:

```powershell
cd C:\Development\safeug
.\tool\build-release.ps1
# Add -IncludeAndroid only after production signing has been configured.
```

Alternatively, after code reaches GitHub, download the `safeug-vps-release`
artifact from the successful **Verify and package SafeUG** workflow. GitHub CI
packages web/backend only; it never publishes a development-signed APK.

Upload the `.tar.gz` and matching `.sha256` from `output/releases/` using SFTP,
Virtualmin File Manager or `scp`. Use your SSH user's home, **not public_html**:

```powershell
scp C:\Development\safeug\output\releases\RELEASE\safeug-RELEASE.tar.gz USER@169.58.25.182:~/
scp C:\Development\safeug\output\releases\RELEASE\safeug-RELEASE.tar.gz.sha256 USER@169.58.25.182:~/
```

Replace `USER` and `RELEASE` with actual values. Verify the SSH host key
against your VPS control panel on the first connection. On the VPS:

```bash
ssh USER@169.58.25.182
mkdir -p ~/safeug-upload/RELEASE
cd ~/safeug-upload/RELEASE
mv ~/safeug-RELEASE.tar.gz ~/safeug-RELEASE.tar.gz.sha256 .
sha256sum -c safeug-RELEASE.tar.gz.sha256
tar -xzf safeug-RELEASE.tar.gz
sudo bash safeug-release/deploy/install-node.sh
sudo bash safeug-release/deploy/install.sh "$PWD/safeug-release"
sudo systemctl status safeug --no-pager
curl --fail http://127.0.0.1:8099/healthz
```

Expected health response: `{"ok":true,"service":"safeug"}`. Installation creates
the dedicated `safeug` account, a private environment file, a persistent database,
the systemd service and the daily backup timer. It preserves existing data and
environment configuration on subsequent deployments.

For a new database, the username is `admin`. Read the generated password locally
on the server using `sudo cat /etc/safeug/safeug.env`, then store it in your password
manager. Do not share that file or paste it into chat. `SAFEUG_ADMIN_PASSWORD`
only bootstraps a **new** database; changing the environment value does not reset
an existing password. Use step 7 for resets and imported databases.

## 5. Configure Apache in Virtualmin

Ubuntu/Debian:

```bash
sudo a2enmod proxy proxy_http headers rewrite ssl
```

On Rocky/AlmaLinux, use `sudo httpd -M` to confirm `proxy_module`,
`proxy_http_module`, `headers_module`, `rewrite_module` and `ssl_module` are
loaded. If SELinux blocks Apache's loopback connection, the usual managed
reverse-proxy setting is `sudo setsebool -P httpd_can_network_connect 1`.

Open the domain's **Web Configuration / Services → Configure SSL Website →
Edit Directives**. Copy the contents of `deploy/apache-ssl.conf` **inside the
existing `<VirtualHost ...:443>`**. Keep its certificate paths, document root,
logs, `ServerName` and `ServerAlias` declarations. Do not add a nested VirtualHost.
Remove conflicting old root `ProxyPass` rules. Ensure `www.safeug.online` is an
alias on this SSL host.

For the port 80 host, add `deploy/apache-http.conf` inside its existing block.
This redirects HTTP to the canonical www HTTPS address while leaving ACME
renewal paths available. It also makes bare-domain visitors use the same origin,
so admin cookies and browser device identities remain consistent.

Validate before reloading:

```bash
# Ubuntu/Debian
sudo apache2ctl configtest
sudo systemctl reload apache2

# Rocky/AlmaLinux instead
sudo apachectl configtest
sudo systemctl reload httpd
```

The proxy timeout is 60 seconds because live synchronization holds a request for
up to 25 seconds. Do not cache `/api/` or `/share/`. The SSL snippet overwrites
`X-Real-IP` and `X-Forwarded-Proto`; Node trusts these only on the loopback proxy
connection. Admin cookies then carry `Secure`, `HttpOnly` and `SameSite=Strict`.

## 6. Move your existing laptop data privately

Skip this if you intentionally want an empty system. To retain your guides,
contacts, incidents, ratings and device identities, migrate the **whole** SQLite
database before users start using the new online version. Do not import only the
`records` table: authentication, ratings and evidence are separate tables.

On Windows, while the local backend can still run:

```powershell
node local/maintenance.mjs backup --database local/data/safeug.sqlite --output output/deployment-private/safeug-migration.sqlite
node local/maintenance.mjs check --database output/deployment-private/safeug-migration.sqlite
scp output/deployment-private/safeug-migration.sqlite USER@169.58.25.182:~/safeug-migration.sqlite
```

The backup command refuses to overwrite an existing backup. Choose another name
for a later snapshot. This file contains sensitive records and authentication
material. Keep it out of GitHub, release archives and web-accessible folders.

On the VPS, **before live usage**, import it with the service stopped:

```bash
sudo systemctl stop safeug
sudo /opt/safeug/node/bin/node /opt/safeug/current/local/maintenance.mjs backup \
  --database /var/lib/safeug/safeug.sqlite \
  --output /var/backups/safeug/before-migration.sqlite
sudo /opt/safeug/node/bin/node /opt/safeug/current/local/maintenance.mjs check \
  --database "$HOME/safeug-migration.sqlite"
# Preserve the old database and any sidecars together instead of overwriting them.
sudo mkdir /var/lib/safeug/before-migration
sudo find /var/lib/safeug -maxdepth 1 -type f -name 'safeug.sqlite*' \
  -exec mv -t /var/lib/safeug/before-migration -- {} +
sudo install -o safeug -g safeug -m 0600 "$HOME/safeug-migration.sqlite" /var/lib/safeug/safeug.sqlite
sudo systemctl start safeug
```

Do not import an older laptop snapshot after real users start reporting online;
that would overwrite their newer data. Record a cutover time and retire the old
backend as the source of truth. Rotate the imported admin password using step 7.

Existing native installations retain their identity during an endpoint migration
**only if** the migrated database contains their token and the application update
retains device storage. Old development-signed APKs cannot be updated in place
with a different release key. Uninstalling clears guest identity and queued local
data; deliver pending incidents first. Browser storage is separate for each
origin, so localhost browser contacts do not automatically become a new browser's
personal contacts on the public domain. Guest identities also do not merge
between different phones; each device controls its own personal data.

## 7. Admin password changes, backups and recovery

Reset the password without placing it in shell history or command arguments:

```bash
read -r -s -p 'New admin password (16+ characters): ' SAFEUG_NEW_PASSWORD
printf '\n'
printf '%s' "$SAFEUG_NEW_PASSWORD" | sudo -u safeug /opt/safeug/node/bin/node \
  /opt/safeug/current/local/maintenance.mjs reset-admin \
  --database /var/lib/safeug/safeug.sqlite --password-stdin
unset SAFEUG_NEW_PASSWORD
```

Existing admin sessions are revoked. Device identities are retained.

```bash
sudo systemctl start safeug-backup.service
sudo systemctl list-timers safeug-backup.timer
sudo journalctl -u safeug-backup --no-pager -n 30
sudo journalctl -u safeug --no-pager -n 100
```

Daily consistent backups run at 02:00 server time, retain 14 days, and include
evidence and ratings. Encrypt and copy backups to a separate machine/storage
account; a backup on the same VPS is not protection against VPS loss. Monitor
disk usage because photo/video evidence is stored in SQLite.

To restore: stop SafeUG, back up the current database, check the chosen backup,
move the current `safeug.sqlite*` files to a private recovery directory as above,
install the backup as `/var/lib/safeug/safeug.sqlite` owned by `safeug:safeug` with
mode 0600, then start SafeUG. Test restore on a spare instance before an emergency.

## 8. Android and iOS distribution

Both native apps default to `https://www.safeug.online`; production builds hide
the development server selector. Android release builds prohibit cleartext HTTP.
iOS uses the standard HTTPS transport policy. Web clients use their current
origin; the domain redirect keeps it canonical.

**Android:** preserve any existing Play/upload signing key. If this is a new app,
create and securely back up a release keystore before distributing it. Configure
`android/keystore.properties` locally (never commit it):

```properties
storeFile=keystore/safeug-upload.jks
storePassword=YOUR_PRIVATE_STORE_PASSWORD
keyAlias=safeug-upload
keyPassword=YOUR_PRIVATE_KEY_PASSWORD
```

Then run `tool/build-release.ps1 -IncludeAndroid`. The release APK becomes
`/downloads/safeug.apk` in that deployment bundle. For Google Play use:

```bash
flutter build appbundle --release -t lib/mobile_main.dart \
  --dart-define=SAFEUG_API_URL=https://www.safeug.online \
  --dart-define=SAFEUG_ALLOW_SERVER_OVERRIDE=false
```

**iOS:** a VPS/Windows PC cannot produce the signed iOS distribution build. Use
a Mac with Xcode and an Apple Developer membership. Open
`ios/Runner.xcworkspace`, choose your Apple team and unique bundle identifier,
set the signing profiles, and build:

```bash
flutter pub get
flutter build ipa --release -t lib/mobile_main.dart \
  --dart-define=SAFEUG_API_URL=https://www.safeug.online \
  --dart-define=SAFEUG_ALLOW_SERVER_OVERRIDE=false
```

Upload via Xcode/Transporter to App Store Connect and use TestFlight first. An
IPA cannot be installed universally from a website like an APK. Complete platform
privacy disclosures for camera, location, microphone and incident uploads.

Hosting does **not** activate remote push while an app/browser is fully closed.
The existing system notifications operate while connected/running; terminated-app
push still needs native Firebase registrations, APNs and server push credentials.
Hosting also does not connect police/agency dispatch, SMS or satellite providers.

## 9. Verify before announcing the launch

1. Visit both public URLs over a mobile network, not just the VPS/laptop network.
2. Confirm a valid certificate and that the bare domain redirects to www.
3. Sign in to admin, add a guide, edit its WhatsApp number and verify the mobile
   view updates. Rate it on a phone and confirm the same average in admin.
4. Submit a clearly labelled test incident with a photo/video and GPS. Verify
   matching fields/evidence in admin. Test a labelled SOS, acknowledgement and
   stand-down; do not tell real responders a test is an emergency.
5. Disconnect a phone, queue a test incident and reconnect; confirm one record.
6. Test contact sharing, revocation and browser permission prompts on HTTPS.
7. Restart the service, verify data remains, and run a backup/restore drill.
8. Check `systemctl is-enabled safeug` and monitor health, logs and disk space.

This single-process SQLite design is suitable for an initial deployment, but
has not been load-tested for a viral surge. Live admin snapshots and media storage
need capacity monitoring. Do not run multiple backend workers with this in-memory
live-event coordinator. Plan shared event infrastructure, database pagination and
separate object storage before scaling to several servers.

## 10. Updates and rollback

Build/download a new uniquely named release, upload it and run its `install.sh`.
The installer backs up existing data, installs to a new release directory,
switches `/opt/safeug/current`, restarts the service and checks health. If startup
fails it switches back to the previous code. It does not automatically downgrade
the database schema; review migrations before restoring older code or data.

Manual code rollback, replacing `PREVIOUS_RELEASE` with an installed directory:

```bash
sudo ln -s /opt/safeug/releases/PREVIOUS_RELEASE /opt/safeug/current.rollback
sudo mv -Tf /opt/safeug/current.rollback /opt/safeug/current
sudo systemctl restart safeug
curl --fail http://127.0.0.1:8099/healthz
```

If you see **502**, check systemd status and proxy modules/SELinux. If you see
**400 Use the configured HTTPS address**, check `ProxyPreserveHost`, the canonical
www redirect and forwarded headers. If synchronization stalls, check the 60-second
proxy timeout and disable caching for the API. Avoid pasting credentials or full
private incident data when sharing logs for troubleshooting.

## References

- [Namecheap DNS setup](https://www.namecheap.com/support/knowledgebase/article.aspx/208/32/i-dont-want-to-change-nameservers-are-there-any-other-ways-to-point-my-domain-to-your-servers/)
- [Virtualmin SSL certificates](https://www.virtualmin.com/docs/server-components/how-to-add-an-ssl-certificate/)
- [Apache reverse proxy directives](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
- [Node.js supported release lines](https://nodejs.org/en/about/previous-releases)
- [Node SQLite backup API](https://nodejs.org/api/sqlite.html)
- [Flutter Android distribution](https://docs.flutter.dev/deployment/android)
- [Flutter iOS distribution](https://docs.flutter.dev/deployment/ios)
