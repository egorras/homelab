# Add an app

One PR, no manual steps: Flux deploys it about a minute after merge, with `https://<name>.lab.egorras.net` and a
valid certificate (the wildcard, served by Traefik by default).

1. Copy the template:
   ```sh
   cp -r kubernetes/apps/_template kubernetes/apps/<name>
   sed -i 's/APP/<name>/g' kubernetes/apps/<name>/*.yaml
   ```
2. In `kubernetes/apps/<name>/app.yaml` set the image (a pinned tag, never `latest`), the container `PORT`, the
   readiness probe path, resources, and uncomment the PVC if the app keeps data.
3. Secrets, if any (repo root). This pipes straight into SOPS, so nothing lands on disk in plain text. The age
   recipients are given explicitly (`--config /dev/null` skips `.sops.yaml`'s path-regex rules) because on a
   native Windows `sops.exe`, `--filename-override` alone doesn't match the `kubernetes/.*` rule — the path gets
   backslash-normalized first, so it silently falls through to the single-admin-key rule and Flux can't decrypt
   the result in-cluster. Keep these two keys in sync with the first rule in `.sops.yaml` if they ever rotate:
   ```sh
   printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: <name>\nstringData:\n  KEY: %s\n' "$VALUE" \
     | sops --config /dev/null encrypt \
         --age "age14uzygqz0hgepvwphdrsualggykr8wpesulf29vphwzhr6ttxafhqmsjpgs,age1pme5neke5tpnfllq03gmp7595ldn3azkaw8qna557t0r94f604lsg2yluv" \
         --encrypted-regex '^(data|stringData)$' \
         --input-type yaml --output-type yaml \
         --filename-override kubernetes/apps/<name>/secret.sops.yaml \
     > kubernetes/apps/<name>/secret.sops.yaml
   ```
   Add `- secret.sops.yaml` to the app's `kustomization.yaml`; reference it with `envFrom`/`secretKeyRef`.
   Files under `kubernetes/` are encrypted to the admin key and the cluster key (`.sops.yaml`).
4. Add `- <name>` to `kubernetes/apps/kustomization.yaml`.
5. Optional: a probe in `kubernetes/infrastructure/configs/monitoring/probes.yaml` (alerts when it's down) and a tile
   in `kubernetes/apps/homepage/config/services.yaml`.
6. `make lint` (kustomize build + kubeconform), open a PR, merge.

Check: `kubectl -n flux-system get kustomization apps` (after `make kubeconfig`), then open the URL.

Services that run outside k3s (LXC/VM guests) get a name the same way, without a Deployment: add a Service,
EndpointSlice and Ingress rule to `kubernetes/apps/lab-services/services.yaml`.
