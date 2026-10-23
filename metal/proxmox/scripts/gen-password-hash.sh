#!/usr/bin/env bash
# Generate a SHA-512 crypt hash for use as root-password-hashed in answer.toml.
# Run on any Linux shell with openssl (e.g. WSL) - never store the plaintext password.
set -euo pipefail

read -rs -p "Root password: " password
echo
read -rs -p "Confirm: " confirm
echo

if [[ "$password" != "$confirm" ]]; then
  echo "Passwords did not match." >&2
  exit 1
fi

# -stdin avoids the password showing up in `ps` output (argv is world-readable).
openssl passwd -6 -stdin <<< "$password"
