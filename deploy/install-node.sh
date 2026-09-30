#!/usr/bin/env bash
# A private Node runtime avoids replacing Node used by other Virtualmin domains.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
case "$(uname -m)" in x86_64) arch=x64;; aarch64|arm64) arch=arm64;; *) echo 'Supported: x86_64 and arm64' >&2; exit 1;; esac
command -v curl >/dev/null
command -v xz >/dev/null
work="$(mktemp -d)"
cd "$work"
curl --fail --show-error --location --proto '=https' --tlsv1.2 https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o SHASUMS256.txt
archive="$(awk -v arch="$arch" '$2 ~ ("^node-v24\\.[0-9]+\\.[0-9]+-linux-" arch "\\.tar\\.xz$") {print $2}' SHASUMS256.txt)"
[[ "$archive" =~ ^node-v24\.[0-9]+\.[0-9]+-linux-(x64|arm64)\.tar\.xz$ ]] || { echo 'No matching official Node 24 archive' >&2; exit 1; }
version="${archive%-linux-*}"
curl --fail --show-error --location --proto '=https' --tlsv1.2 "https://nodejs.org/dist/${version#node-}/$archive" -o "$archive"
awk -v name="$archive" '$2==name' SHASUMS256.txt | sha256sum -c -
install -d -m 0755 /opt/safeug/runtime
if [[ ! -x "/opt/safeug/runtime/${archive%.tar.xz}/bin/node" ]]; then
  tar -xJf "$archive" -C /opt/safeug/runtime --no-same-owner
fi
[[ ! -e /opt/safeug/node || -L /opt/safeug/node ]] || { echo '/opt/safeug/node must be a symlink' >&2; exit 1; }
ln -sfn "/opt/safeug/runtime/${archive%.tar.xz}" /opt/safeug/node
/opt/safeug/node/bin/node --version
echo "Official archive and checksum retained at $work. Restart SafeUG after runtime upgrades."
