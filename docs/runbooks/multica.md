# Multica: AI coding-agent task board

Server on the Oracle VPS (manifests: `kubernetes/apps-oracle/multica`), reached at
`http://100.83.54.16:30080` (web) / `:30081` (API) over Tailscale - no hostname, no TLS, since
Tailscale is already the trust boundary (same reasoning as `immich-ml`). The agent runtime
(manifests: `kubernetes/apps/multica-runtime`) runs on the homelab k3s cluster so it's on 24/7,
independent of any PC.

Replaces an earlier hand-run Dokploy/Compose stack on the same VPS (`home-multica-wg1szc-*`,
ports 8450/8451) - decommissioned once the Flux-managed version below was verified working.

## First-time setup (interactive - can't be scripted/GitOps'd)
1. **Create the Oracle cluster's SOPS key** (one-time; see PR that added this runbook for why):
   generate an age keypair, create a `sops-age` Secret in Oracle's `flux-system` namespace with
   the private key, store the private key in the password manager, add the public key to
   `.sops.yaml`. Needed before `kubernetes/apps-oracle/multica`'s secret can decrypt.
2. Open `http://100.83.54.16:30080`. No email configured, so the verification code is in the
   backend logs: `ssh ubuntu@100.83.54.16 "sudo k3s kubectl -n multica logs -f deploy/multica-backend | grep 'Verification code'"`.
   Log in, create a fresh workspace.
3. Re-point the PC's existing CLI at the new server:
   ```sh
   multica config set server_url http://100.83.54.16:30081
   multica config set app_url http://100.83.54.16:30080
   multica login
   ```
4. In the web app, **Settings → Runtimes → Add a computer**, copy the two generated commands.
5. Run them inside the homelab runtime pod:
   ```sh
   kubectl -n multica-runtime exec -it deploy/multica-runtime -- bash
   ```
   (paste the two commands), then in the same shell: `claude login` and `codex login` - both open
   a URL; open it in your own browser and paste the resulting code back. These persist on the
   pod's PVC (`multica-runtime-home`), so they survive restarts/reschedules.
6. Verify: `multica daemon status` inside the pod, and both the PC and the homelab pod listed
   under Settings → Runtimes in the web app.

## Troubleshooting
- Runtime pod `ImagePullBackOff` the first time: GHCR makes a brand-new package private by
  default even in a public repo. After the `multica-runtime-image` workflow's first successful
  push, go to the package's settings on GitHub (github.com/egorras/homelab → Packages →
  `multica-runtime` → Package settings) and change visibility to Public. One-time only.
- Runtime pod `CrashLoopBackOff` before step 5 is done: expected - the daemon exits if it isn't
  logged in yet. Not a bug.
- Backend pod not `Ready`: it waits on Postgres + migrations behind a startupProbe; give it a
  minute before worrying. `kubectl -n multica logs deploy/multica-backend`.
- Bumping the runtime image: `.github/workflows/multica-runtime-image.yml` builds
  `ghcr.io/egorras/multica-runtime` on changes under `multica-runtime/`; the Deployment currently
  tracks `:latest` rather than a pinned sha (unlike this repo's other apps) because there was no
  published tag to pin to yet. Switch `kubernetes/apps/multica-runtime/app.yaml` to a `sha-<short>`
  tag once you want reproducible, deliberate upgrades instead.
