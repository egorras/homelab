# Immich

Photos at https://photos.lab.egorras.net (manifests: `kubernetes/apps/immich`).

| Data | Where | Backed up by |
|---|---|---|
| Originals (`library/`, `upload/`), `encoded-video/`, `profile/` | HDD `/mnt/hdd/photos` → virtiofs → k3s VM `/mnt/photos` → `/data` | nothing yet (off-site copy: Later) |
| Nightly DB dumps (`backups/`; schedule and retention in Administration → Settings → Backup) | same HDD folder | same |
| Postgres | PVC `immich-postgres` (VM disk, NVMe) | nightly vzdump of the k3s VM + the dumps above |
| Thumbnails | PVC `immich-thumbs` (NVMe) | not needed: regenerated from originals |
| ML models | PVC `immich-model-cache` (NVMe) | not needed: downloaded again |

Immich stores absolute paths (`/data/...`) in the database, so the library must stay mounted at `/data`.

## Restore the database from a dump

For a fresh cluster, a rebuilt k3s VM, or the one-time move from the old lab (dump
`immich-db-backup-20260926T020000-v3.2.2-pg14.19.sql.gz`, Immich v3.2.2).

1. Deploy the **same Immich version** as the dump (its name has it) with `immich-server` and
   `immich-machine-learning` at `replicas: 0`: only Postgres and Valkey run, and nothing writes to the empty DB.
   Postgres creates the empty `immich` database on first start.
2. On the k3s VM (`ssh debian@k3s.lab.egorras.net`), load the dump. The `sed` is from Immich's restore docs: the
   dump clears `search_path`, which breaks the vector extensions on restore.
   ```sh
   D=/mnt/photos/backups/immich-db-backup-<timestamp>-<version>-pg14.<x>.sql.gz
   zcat "$D" \
     | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
     | sudo k3s kubectl -n immich exec -i deploy/immich-postgres -- psql -q -U postgres -d immich
   ```
   Errors about `\restrict` or objects that don't exist yet (the dump's `DROP ... IF EXISTS` lines) are harmless.
3. Set both Deployments back to `replicas: 1` in git (PR, merge). The server's `thumbs-marker` init container
   marks the empty thumbnail volume so Immich's folder checks pass.
4. Log in, then **Administration → Jobs → Generate Thumbnails → All**. (*Missing* can skip them: the restored
   database still lists the old thumbnail files.) With the old job concurrency of 1, ~8.6k assets take a few hours.
5. Only then upgrade Immich, one release at a time as the release notes require.

## Upgrade

Bump `immich-server` and `immich-machine-learning` together (Renovate groups them), after reading the release notes.
The Postgres image changes only when a release note says so; its major version must match existing data.

## Phone app

Server URL `https://photos.lab.egorras.net`. Traefik's read timeout is raised to 600s
(`kubernetes/infrastructure/configs/traefik-config.yaml`) so large video uploads aren't cut off at 60s.
