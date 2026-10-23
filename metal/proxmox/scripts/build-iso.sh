#!/usr/bin/env bash
# Embed answer.toml into a stock Proxmox VE ISO so it installs unattended.
# Requires `proxmox-auto-install-assistant` (Debian/Ubuntu host, or WSL).
#
# Usage: build-iso.sh /path/to/proxmox-ve-8.x.iso [output.iso]
set -euo pipefail

cd "$(dirname "$0")/.."

src_iso="${1:-}"
out_iso="${2:-pve-autoinstall.iso}"

if [[ -z "$src_iso" ]]; then
  echo "Usage: $0 /path/to/proxmox-ve-8.x.iso [output.iso]" >&2
  echo "Download the stock ISO from https://www.proxmox.com/en/downloads" >&2
  exit 1
fi

if ! command -v proxmox-auto-install-assistant >/dev/null 2>&1; then
  echo "proxmox-auto-install-assistant not found. Install it on a Debian/Ubuntu host (or WSL)." >&2
  exit 1
fi

if [[ ! -f answer.toml ]]; then
  echo "answer.toml not found. Copy answer.toml.example to answer.toml and fill it in first." >&2
  exit 1
fi

proxmox-auto-install-assistant validate-answer answer.toml

proxmox-auto-install-assistant prepare-iso "$src_iso" \
  --fetch-from iso \
  --answer-file answer.toml \
  --output "$out_iso"

echo "Built $out_iso - write it to USB (e.g. Rufus/balenaEtcher/dd) and boot the target node from it."
