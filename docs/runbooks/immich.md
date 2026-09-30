# Immich

Photos at https://photos.lab.egorras.net (manifests: `kubernetes/apps/immich`).

| Data | Where | Backed up by |
|---|---|---|
| Originals (`library/`, `upload/`), `encoded-video/`, `profile/` | HDD `/mnt/hdd/photos` → virtiofs → k3s VM `/mnt/photos` → `/data` | nothing yet (off-site copy: Later) |
| Weekly DB dumps (`backups/`, Sun 04:00; schedule and retention in `config.yaml`) | same HDD folder | same |
| Postgres | PVC `immich-postgres` (VM disk, NVMe) | weekly vzdump of the k3s VM + the dumps above |
| Thumbnails | PVC `immich-thumbs` (NVMe) | not needed: regenerated from originals |
| ML models | PVC `immich-model-cache` on the Oracle VPS, not the k3s VM (`kubernetes/apps-oracle/immich-ml`, docs/adr/0005) | not needed: downloaded again |

Immich stores absolute paths (`/data/...`) in the database, so the library must stay mounted at `/data`.

The ML worker (`immich-machine-learning`) runs as its own tiny cluster on the Oracle VPS, reached over Tailscale
(`IMMICH_MACHINE_LEARNING_URL` in `kubernetes/apps/immich/app.yaml`) - it's the one RAM/CPU-heavy piece of Immich
and doesn't need the local photo library, so it doesn't compete with anything else on the k3s VM.

Settings live in `kubernetes/apps/immich/config.yaml` (`IMMICH_CONFIG_FILE`), so Administration → Settings is
read-only; list only keys that differ from the defaults. Integrity checks (missing/untracked files, checksums of
every original) run weekly, Sun 04:00, after the vzdump.

## Restore the database from a dump

For a fresh cluster or a rebuilt k3s VM. (Tried once for the move from the old lab, dump
`immich-db-backup-20260926T020000-v3.2.2-pg14.19.sql.gz`: it worked, but the lab started empty instead.)

1. Deploy the **same Immich version** as the dump (its name has it) with `immich-server` and `immich-microservices`
   at `replicas: 0` (in git, or `kubectl -n flux-system patch kustomization apps --type merge
   -p '{"spec":{"suspend":true}}'` and scale them by hand): only Postgres and Valkey run, nothing writes to the DB.
   Postgres creates the empty `immich` database on first start. (`immich-machine-learning` lives on the Oracle
   VPS and is stateless - leave it running, it has nothing to do with the DB restore.)
2. On the k3s VM (`ssh debian@k3s.lab.egorras.net`), load the dump. The `sed` is from Immich's restore docs: the
   dump clears `search_path`, which breaks the vector extensions on restore.
   ```sh
   D=/mnt/photos/backups/immich-db-backup-<timestamp>-<version>-pg14.<x>.sql.gz
   zcat "$D" \
     | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
     | sudo k3s kubectl -n immich exec -i deploy/immich-postgres -- psql -q -U postgres -d immich
   ```
   Errors about `\restrict` or objects that don't exist yet (the dump's `DROP ... IF EXISTS` lines) are harmless.
3. Set the three Deployments back to `replicas: 1` in git (PR, merge). The `thumbs-marker` init containers
   mark the empty thumbnail volume so Immich's folder checks pass.
4. Log in, then **Administration → Jobs → Generate Thumbnails → All**. (*Missing* can skip them: the restored
   database still lists the old thumbnail files.) With the old job concurrency of 1, ~8.6k assets take a few hours.
5. Only then upgrade Immich, one release at a time as the release notes require.

## Upgrade

Bump the `immich-server` image (used by `immich-server` and `immich-microservices`, in `kubernetes/apps/immich`)
and `immich-machine-learning` (in `kubernetes/apps-oracle/immich-ml`, a separate PR since it's a different
cluster/Flux instance) together, after reading the release notes.
The Postgres image changes only when a release note says so; its major version must match existing data.

## Phone app

Server URL `https://photos.lab.egorras.net`. Traefik's read timeout is raised to 1h
(`kubernetes/infrastructure/configs/traefik-config.yaml`) so large video uploads aren't cut off at 60s.

Uploads go to `immich-server` (API only); jobs run in `immich-microservices`. When they shared one container, an
OOM kill while transcoding took every upload in flight down with it (502 in the app).
