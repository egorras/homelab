# BookOrbit: ebooks, audiobooks, comics

BookOrbit at https://books.lab.egorras.net (manifests: `kubernetes/apps/bookorbit`) is a self-hosted library and
reader for EPUB/MOBI/AZW3/PDF, CBZ/CBR comics, and M4B/MP3 audiobooks, with Kobo/KOReader sync and OPDS.

| What | Where |
|---|---|
| Book files | HDD `/mnt/hdd/books` -> virtiofs `books` -> k3s VM `/mnt/books` -> `/books` |
| Postgres (metadata, users, reading progress) | PVC `bookorbit-postgres` on the VM disk (no backup yet) |
| App config/cache | PVC `bookorbit-data` on the VM disk |

The `books` share is provisioned the same way as `photos`/`media`: `pve_host_hdd_dirs` (Ansible) creates
`/mnt/hdd/books`, `proxmox_hardware_mapping_dir.books` (OpenTofu) maps it into Proxmox, and the k3s VM mounts it
over virtiofs (`k3s_books_mountpoint`). Applying the OpenTofu change reconfigures the k3s VM's hardware and
requires a reboot to attach the new virtiofs device.

## First setup (once)
1. Deploy the PR, then `findmnt /mnt/books` on the k3s VM to confirm the virtiofs share is mounted (reboot the VM
   if OpenTofu just added it and it isn't there yet).
2. Open https://books.lab.egorras.net and complete setup using the bootstrap token:
   ```sh
   sops -d kubernetes/apps/bookorbit/secret.sops.yaml | yq .stringData.setup-bootstrap-token
   ```
3. Copy or sync book files into `/mnt/hdd/books` on the Proxmox host (owner/mode: BookOrbit chowns what it needs
   to PUID/PGID 1000 on startup).

## Troubleshooting
- Requests download paths: qBittorrent's `books` category saves to `/data/downloads/books`, mapped in
  BookOrbit's download client to `/downloads` (host `/mnt/media/downloads/books`). qBittorrent's default
  Automatic Torrent Management must be enabled so new requests use the category folder. For existing
  book torrents saved under `/data/downloads`, enable Automatic Torrent Management on those torrents to
  relocate them. Recover a failed import through Settings -> Requests -> Download clients -> Reconcile,
  then attach the completed torrent to its failed request; this reuses the existing download.
- Pod stuck in `ContainerCreating` with `hostPath type check failed`: the `books` share isn't mounted in the VM
  (`findmnt /mnt/books`), or `/mnt/hdd/books` is missing on the Proxmox host (rerun the `pve_host` Ansible role).
- No readiness probe path is documented for the app container, so it's a plain TCP check on port 3000; a pod can
  report Ready slightly before the app finishes its first-boot migrations.
