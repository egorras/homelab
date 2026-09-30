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

## Login: one shared account, not "no login"
Sonarr/Radarr/Prowlarr stopped allowing auth to be fully disabled a while back (reacting to exposed-instance
scans) - the closest option is "Disabled for Local Addresses", but that only exempts literal loopback
connections. Traffic through Traefik never qualifies (these apps only ever see Traefik's own connection, not
the original client), so in practice **auth is always enforced** for anything reached via `*.lab.egorras.net`.
To avoid that meaning three different logins, Sonarr/Radarr/Prowlarr run `authenticationRequired: enabled` with
the same shared username/password. Change it in any of the three (Settings → General → Security) and update the
others to match if you want a different one - nothing requires them to stay in sync except convenience.

- **qBittorrent**: does still support a real subnet-based bypass (Settings → WebUI → "Bypass authentication for
  clients in whitelisted IP subnets", `10.42.0.0/16,10.43.0.0/16,192.168.0.0/24`), but it's set up with its own
  separate login instead, for the same reason - simpler to reason about than a bypass rule.
- **Jellyseerr**: no separate account system - it signs you in through Jellyfin directly, and whichever Jellyfin
  user connects it first becomes the Jellyseerr admin. Everyone else signs in with their own Jellyfin account.

## First setup
Wiring (Prowlarr↔Sonarr/Radarr, Sonarr/Radarr↔qBittorrent download client + categories, Jellyseerr↔Jellyfin +
Sonarr/Radarr, Jellyfin's Movies/Shows libraries) is done. What's left needs your own accounts/preferences:
1. **Prowlarr**: Settings → Indexers → add your trackers; Prowlarr pushes them to Sonarr/Radarr automatically
   (Settings → Apps already lists both).
2. Quality profile defaults to `HD-1080p` everywhere (Sonarr/Radarr Settings → Profiles, and Jellyseerr's
   Settings → Services uses the same one) - change it in both places together if you want something else.
3. Request something in Jellyseerr (https://requests.lab.egorras.net) and confirm it flows through: Sonarr/
   Radarr's queue → qBittorrent → (after import) the Jellyfin library.

## RuTracker (and other Cloudflare-fronted indexers)
RuTracker's `login.php` returns 403 "Just a moment..." to any plain HTTP client - it's Cloudflare's JS
challenge in front of the site, not bad credentials. `flaresolverr.yaml` runs a headless-Chromium solver for
this; in Prowlarr add it once as an Indexer Proxy (Settings → Indexer Proxies → FlareSolverr, host
`http://flaresolverr:8191/`), then set RuTracker's indexer to use that proxy. Same fix applies to any other
indexer stuck behind a Cloudflare challenge - just point its proxy field at FlareSolverr too.

## Troubleshooting
- All trackers report `Host not found (authoritative)`: compare `getent hosts tracker.opentrackr.org`
  with `getent hosts tracker.opentrackr.org.` inside the qBittorrent container. The pod needs `dnsConfig`
  `ndots: "1"`: Kubernetes' default `ndots:5` tries cluster search suffixes against Gluetun's public DNS
  resolver before the real tracker name. Keep the fix in Git, since Flux reverts deployment-only patches.
- Random PIA endpoints fail with `Host is unreachable`: check the timestamp in `/gluetun/servers.json`.
  Once the VPN is connected, refresh it with `kubectl -n media exec deployment/qbittorrent -c gluetun --
  /gluetun-entrypoint update -enduser -providers "private internet access" -dns 127.0.0.1` (one command).
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
