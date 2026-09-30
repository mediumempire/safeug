#!/usr/bin/env bash
set -euo pipefail
umask 027
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
source_dir="$(realpath "${1:?Usage: sudo bash deploy/install.sh /path/to/safeug-release}")"
for file in release.json local/server.mjs build/web/index.html build/admin/index.html; do
  [[ -f "$source_dir/$file" ]] || { echo "Missing release file: $file" >&2; exit 1; }
done
[[ -x /opt/safeug/node/bin/node ]] || { echo 'Run deploy/install-node.sh first.' >&2; exit 1; }
/opt/safeug/node/bin/node -e 'if(Number(process.versions.node.split(".")[0])!==24)throw Error("Node.js 24 LTS required")'
command -v rsync >/dev/null
command -v curl >/dev/null
release_id="$(/opt/safeug/node/bin/node -p 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).release' "$source_dir/release.json")"
[[ "$release_id" =~ ^[a-zA-Z0-9._+-]+$ ]] || { echo 'Invalid release id' >&2; exit 1; }
target="/opt/safeug/releases/$release_id"
[[ ! -e "$target" ]] || { echo "Release already installed: $target" >&2; exit 1; }
getent passwd safeug >/dev/null || useradd --system --user-group --home-dir /var/lib/safeug --shell /usr/sbin/nologin safeug
install -d -m 0755 /opt/safeug /opt/safeug/releases
install -d -o safeug -g safeug -m 0700 /var/lib/safeug /var/backups/safeug
install -d -o root -g safeug -m 0750 /etc/safeug
if [[ ! -e /etc/safeug/safeug.env ]]; then
  initial_password="$(/opt/safeug/node/bin/node -e 'process.stdout.write(require("crypto").randomBytes(24).toString("base64url"))')"
  {
    printf '%s\n' 'NODE_ENV=production' 'SAFEUG_HOST=127.0.0.1' 'SAFEUG_PORT=8099' 'SAFEUG_PUBLIC_ORIGIN=https://www.safeug.online' 'SAFEUG_TRUST_PROXY=1' 'SAFEUG_DATABASE_PATH=/var/lib/safeug/safeug.sqlite'
    printf 'SAFEUG_ADMIN_PASSWORD=%s\n' "$initial_password"
  } > /etc/safeug/safeug.env
  unset initial_password
  chown root:safeug /etc/safeug/safeug.env
  chmod 0640 /etc/safeug/safeug.env
fi
previous="$(readlink -f /opt/safeug/current || true)"
if [[ -f /var/lib/safeug/safeug.sqlite && -n "$previous" ]]; then
  /opt/safeug/node/bin/node "$previous/local/maintenance.mjs" backup --database /var/lib/safeug/safeug.sqlite --output "/var/backups/safeug/pre-deploy-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
fi
install -d -m 0755 "$target"
rsync -a --no-owner --no-group "$source_dir/" "$target/"
chown -R root:root "$target"
chmod -R u=rwX,go=rX "$target"
chmod 0755 "$target/deploy/backup.sh"
for unit in safeug.service safeug-backup.service safeug-backup.timer; do
  install -m 0644 "$target/deploy/$unit" "/etc/systemd/system/$unit"
done
ln -s "$target" /opt/safeug/current.next
mv -Tf /opt/safeug/current.next /opt/safeug/current
systemctl daemon-reload
systemctl enable safeug.service safeug-backup.timer
systemctl restart safeug.service
systemctl start safeug-backup.timer
healthy=0
for attempt in $(seq 1 20); do
  if curl --silent --fail --max-time 2 http://127.0.0.1:8099/healthz | /opt/safeug/node/bin/node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{if(JSON.parse(s).ok!==true)process.exit(1)}catch{process.exit(1)}})'; then healthy=1; break; fi
  sleep 1
done
if [[ $healthy -ne 1 ]]; then
  echo 'Startup failed; review journalctl -u safeug. Restoring previous code if available.' >&2
  if [[ -n "$previous" && -d "$previous" ]]; then
    ln -s "$previous" /opt/safeug/current.rollback
    mv -Tf /opt/safeug/current.rollback /opt/safeug/current
    systemctl restart safeug.service
  fi
  exit 1
fi
echo 'SafeUG backend is healthy. Configure DNS, TLS and the Virtualmin proxy next.'
echo 'Fresh database: username admin; bootstrap password is in /etc/safeug/safeug.env (root access only).'
echo 'Imported databases retain their existing admin password. Use maintenance.mjs to reset it.'
