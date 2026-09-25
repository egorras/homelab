# 4. OpenTofu state is encrypted and committed to git

**Status:** accepted

## Context
Single operator, single lab; a remote backend is another account to run. State contains secrets, and the repo is public.

## Decision
Use OpenTofu's native state encryption (`pbkdf2` key provider, AES-GCM). The passphrase is SOPS-encrypted in the repo.
The apply job commits the updated state back to `main` with `[skip ci]`; a workflow `concurrency` group serializes applies.

## Consequences
- No locking beyond the concurrency group: never run `apply` locally while CI runs.
- Losing the age key means losing the state, so the key is kept in a password manager plus an offline copy.
