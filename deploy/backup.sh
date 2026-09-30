#!/usr/bin/env bash
set -euo pipefail
umask 077
backup_file="/var/backups/safeug/safeug-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
/opt/safeug/node/bin/node /opt/safeug/current/local/maintenance.mjs backup --output "$backup_file"
/opt/safeug/node/bin/node /opt/safeug/current/local/maintenance.mjs check --database "$backup_file"
# Retain 14 days. Export encrypted copies off the VPS before pruning.
find /var/backups/safeug -maxdepth 1 -type f -name 'safeug-*.sqlite' -mtime +14 -delete
