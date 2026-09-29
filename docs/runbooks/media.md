# Media stack: Prowlarr, Sonarr, Radarr, qBittorrent, Jellyseerr

Manifests: `kubernetes/apps/media`. Indexers found by Prowlarr feed Sonarr (TV) and Radarr (movies), which send
downloads to qBittorrent (tunnelled through PIA via a Gluetun sidecar) and import the finished files into
Jellyfin's library. Jellyseerr at https://requests.lab.egorras.net is the front door for everyday use - request
a movie/show there; nobody needs to open Sonarr/Radarr/qBittorrent directly for that.

| What | Where |
|---|---|
| qBittorrent downloads | HDD `/mnt/hdd/media/data/media/downloads` → virtiofs `media` → k3s VM `/mnt/media/downloads` → `/data/downloads` |
| Sonarr library (TV) | `.../media/tv` → `/mnt/media/tv` → `/data/tv`; Jellyfin sees it read-only at `/data/media/tv` |
| Radarr library (movies) | `.../media/movies` → `/mnt/media/movies` → `/data/movies`; Jellyfin sees it read-only at `/data/media/movies` |
| App settings/DBs | one PVC per app (`prowlarr-config`, `sonarr-config`, `radarr-config`, `qbittorrent-config`, `jellyseerr-config`, `gluetun-data`) on the VM disk (weekly vzdump) |

`downloads/`, `movies/` and `tv/` are owned by uid 1000 (`pve_host_media_uid`), same as Pinchflat's `youtube/`
(docs/runbooks/pinchflat.md). All three apps mount the *whole* `/mnt/media` share at `/data`, so qBittorrent's
downloads and Sonarr/Radarr's libraries sit on one filesystem - imports are hardlinks (instant, no extra space),
not copies.

## PIA credentials (one-time, before this deploys)
`kubernetes/apps/media/secret.sops.yaml` doesn't exist yet - `kustomization.yaml` already references it, so
`make lint` (and Flux) will fail until it's created. From WSL/Linux, repo root:
```sh
printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: qbittorrent-pia\nstringData:\n  OPENVPN_USER: %s\n  OPENVPN_PASSWORD: %s\n' \
    "$PIA_USER" "$PIA_PASS" \
  | sops -e --input-type yaml --output-type yaml \
      --filename-override kubernetes/apps/media/secret.sops.yaml /dev/stdin \
  > kubernetes/apps/media/secret.sops.yaml
```
Use PIA's generated `pXXXXXXX` username, not your email - that's what OpenVPN auth expects.

## No per-app login
Everything here is LAN + Tailscale only, so auth is turned off per app rather than juggling five separate
accounts (the same trust model as the rest of this lab). One-time, in each app's own UI after first deploy:
- **Sonarr / Radarr / Prowlarr**: Settings → General → Security → Authentication: **Disabled**.
- **qBittorrent**: Settings → WebUI → check "Bypass authentication for clients on localhost" and add
  `10.42.0.0/16,10.43.0.0/16,192.168.0.0/24` (k3s pod/service CIDRs + LAN) under "Bypass authentication for
  clients in whitelisted IP subnets". The container starts with a random generated password (`docker logs`
  equivalent: `kubectl -n media logs deploy/qbittorrent -c qbittorrent | grep -i password`) - use that once to
  get in and flip the setting.
- **Jellyseerr**: has no separate concept of "no auth" - sign in once with your Jellyfin account (Settings →
  Users → import), everyone else on the LAN can be added the same way or just share that one login.

## First setup
1. **Prowlarr**: Settings → Indexers → add your trackers. Settings → Apps → add Sonarr and Radarr (URLs
   `http://sonarr.media.svc:80` / `http://radarr.media.svc:80`, API keys from each app's Settings → General).
2. **qBittorrent**: Settings → Downloads → default save path `/data/downloads`. Categories `tv` and `movies`
   get created automatically once Sonarr/Radarr add the download client.
3. **Sonarr / Radarr**: Settings → Download Clients → add qBittorrent (`http://qbittorrent.media.svc:80`, same
   category names as above). Settings → Media Management → root folder `/data/tv` (Sonarr) / `/data/movies`
   (Radarr).
4. **Jellyseerr**: Settings → Jellyfin (server + login), Settings → Services → add Sonarr and Radarr (URLs +
   API keys as above, matching root folders/quality profiles).

## Jellyfin libraries (once)
Dashboard → Libraries → Add Media Library:
- content type **Shows**, name `TV Shows`, folder `/data/media/tv`;
- content type **Movies**, name `Movies`, folder `/data/media/movies`.

## Troubleshooting
- `qbittorrent` pod stuck `ContainerCreating`, `hostPath type check failed` on `/dev/net/tun` or `/mnt/media`:
  the media share isn't mounted on the VM (`findmnt /mnt/media`), or the node's `tun` kernel module isn't
  loaded (`lsmod | grep tun`; `modprobe tun` then check `k3s_media_mountpoint`/tun wiring persists across
  reboots).
- Gluetun logs show the OpenVPN handshake failing or timing out: try a different `SERVER_REGIONS`, or flip
  `OPENVPN_PROTOCOL` to `udp` first - the `tcp`/Netherlands combination was this ISP's previous fix, may not
  apply from a different location.
- Sonarr/Radarr import as a copy instead of a hardlink (visible as "not instant" + temporary double disk use):
  check both qBittorrent's save path and Sonarr/Radarr's root folder actually resolve under the same `/data`
  mount - a typo'd category path is the usual cause.
- Forwarded port: `VPN_PORT_FORWARDING` is on, but nothing currently copies PIA's forwarded port into
  qBittorrent's listen port automatically (the previous lab did this with a cron script that isn't carried
  over). Without it, qBittorrent still works, just with worse seeding on trackers that require an open port.
