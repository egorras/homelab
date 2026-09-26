# CI access to the lab (one-time, or after rotating credentials)

GitHub Actions reaches the lab as an ephemeral `tag:ci` tailnet node (docs/adr/0003) and decrypts secrets with the age key.
GitHub holds exactly three secrets: `SOPS_AGE_KEY`, `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`.

## 1. Tailnet policy
Admin console → **Access controls** → replace the policy with [`metal/tailscale/policy.hujson`](../../metal/tailscale/policy.hujson) → Save.
Any later change: edit the file in a PR, paste it after merge.

## 2. OAuth client for CI
Admin console → **Settings → Trust credentials** (OAuth clients) → **+ Credential** → OAuth:
- Scope **Keys → Auth Keys: Write**, tag **`tag:ci`**. Nothing else.

```sh
gh secret set TS_OAUTH_CLIENT_ID      # paste client ID
gh secret set TS_OAUTH_SECRET         # paste client secret
gh secret set SOPS_AGE_KEY < ~/.config/sops/age/keys.txt
```
Rotate: generate a new client, re-run the two `gh secret set` lines, revoke the old client.

## 3. OpenTofu state passphrase
```sh
sops set metal/secrets.sops.yaml '["tofu_state_passphrase"]' "\"$(openssl rand -base64 32)\""
```
Losing it (or the age key) means losing the state; the age key is in the password manager plus an offline copy (docs/adr/0004).

## 4. `homelab` environment
Restricts the apply job to `main`:
```sh
gh api -X PUT repos/egorras/homelab/environments/homelab \
  -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST repos/egorras/homelab/environments/homelab/deployment-branch-policies -f name=main
```

## Check
- Open a PR touching `metal/`: the `infra / plan` job comments with `tofu plan` and `ansible --check --diff`.
- Merge it: `infra / apply` runs, and any tofu state change is committed back as `chore(tofu): update state [skip ci]`.
