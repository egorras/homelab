#!/usr/bin/env bash
# Build a Proxmox VE ISO that installs itself unattended using answer.toml.
# Output: metal/proxmox/out/proxmox-ve-auto.iso — flash to USB (dd / balenaEtcher / Rufus in DD mode).
set -euo pipefail
cd "$(dirname "$0")"

ISO=proxmox-ve_9.2-1.iso
SHA256=4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c
OUT=out
mkdir -p "$OUT"

if ! command -v proxmox-auto-install-assistant >/dev/null; then
  SUDO=$([ "$(id -u)" -eq 0 ] || echo sudo)
  $SUDO curl -fsSLo /usr/share/keyrings/proxmox-archive-keyring.gpg \
    https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg
  echo "deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
    | $SUDO tee /etc/apt/sources.list.d/pve.list >/dev/null
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq proxmox-auto-install-assistant
fi

[ -f "$OUT/$ISO" ] || curl -fL --progress-bar -o "$OUT/$ISO" "https://enterprise.proxmox.com/iso/$ISO"
echo "$SHA256  $OUT/$ISO" | sha256sum -c --quiet

HASH=$(sops decrypt --extract '["root_password_hash"]' ../secrets.sops.yaml)
trap 'rm -f "$OUT/answer.toml"' EXIT
sed "s|__ROOT_PASSWORD_HASH__|$HASH|" answer.toml > "$OUT/answer.toml"

proxmox-auto-install-assistant validate-answer "$OUT/answer.toml"
proxmox-auto-install-assistant prepare-iso "$OUT/$ISO" --fetch-from iso \
  --answer-file "$OUT/answer.toml" --output "$OUT/proxmox-ve-auto.iso"
echo "Built $OUT/proxmox-ve-auto.iso"
