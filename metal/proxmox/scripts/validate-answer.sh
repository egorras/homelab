#!/usr/bin/env bash
# Validate metal/proxmox/answer.toml against the Proxmox VE Automated
# Installer schema. Requires `proxmox-auto-install-assistant` (Debian/Ubuntu
# package `pve-installer` on PVE 8.1+, or run this inside WSL/a Linux box).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v proxmox-auto-install-assistant >/dev/null 2>&1; then
  echo "proxmox-auto-install-assistant not found. Install it on a Debian/Ubuntu host (or WSL)." >&2
  exit 1
fi

if [[ ! -f answer.toml ]]; then
  echo "answer.toml not found. Copy answer.toml.example to answer.toml and fill it in first." >&2
  exit 1
fi

proxmox-auto-install-assistant validate-answer answer.toml
