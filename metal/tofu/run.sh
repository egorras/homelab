#!/usr/bin/env bash
# Run tofu in metal/tofu with its secrets exported from metal/secrets.sops.yaml (never written to disk).
# Same entry point locally and in CI: `metal/tofu/run.sh plan`.
set -euo pipefail
cd "$(dirname "$0")"

secret() { sops decrypt --extract "[\"$1\"]" ../secrets.sops.yaml; }
TF_VAR_state_passphrase="$(secret tofu_state_passphrase)"
PROXMOX_VE_API_TOKEN="$(secret proxmox_api_token)"
# Same token cert-manager uses: one secret to rotate.
CLOUDFLARE_API_TOKEN="$(sops decrypt --extract '["stringData"]["api-token"]'   ../../kubernetes/infrastructure/configs/cloudflare-api-token.sops.yaml)"
export TF_VAR_state_passphrase PROXMOX_VE_API_TOKEN CLOUDFLARE_API_TOKEN

exec tofu "$@"
