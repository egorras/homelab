# Pinchflat: YouTube channels in Jellyfin

Pinchflat at https://youtube.lab.egorras.net (manifests: `kubernetes/apps/pinchflat`) downloads the channels and
playlists you add; Jellyfin shows them as a Shows library, one show per channel.

| What | Where |
|---|---|
| Videos, `.nfo`, thumbnails, channel posters | HDD `/mnt/hdd/media/data/media/youtube` → virtiofs `media` → k3s VM `/mnt/media/youtube` → `/downloads`; Jellyfin LXC sees it read-only at `/data/media/youtube` |
| Settings, sources, SQLite DB | PVC `pinchflat-config` on the VM disk (weekly vzdump) |

The folder is owned by uid 1000 (`pve_host_media_uid`), the user Pinchflat runs as. No backup: everything here
can be downloaded again.

## First setup (once, in the Pinchflat UI)
1. **Settings**: video codec preference `avc`, audio `m4a` (the defaults). H.264 in mp4 plays directly on TVs and
   projectors; VP9/AV1 would need transcoding or stutter on weak clients.
2. **Media Profiles → New**, preset **Media Center (Plex, Jellyfin, Kodi, etc.)**, then check:
   - output template `/shows/{{ source_custom_name }}/{{ season_by_year__episode_by_date_and_index }} - {{ title }}.{{ ext }}`
     (season = upload year, episode = upload date);
   - download NFO, thumbnail and source images: on (Jellyfin's metadata);
   - preferred resolution: 1080p (about 1-2 GB per hour of video);
   - optional: SponsorBlock `remove`, Shorts `exclude`, livestreams `exclude`.
3. **Sources → New**: paste a channel or playlist URL, pick the profile. Set a retention (e.g. keep 30 days) and
   "download cutoff date" so a big channel doesn't pull its whole back catalogue.

## Jellyfin library (once)
Dashboard → Libraries → Add Media Library:
- content type **Shows**, name `YouTube`, folder `/data/media/youtube/shows`;
- metadata downloaders and image fetchers: untick all (TheTVDB, TheMovieDb, ...); metadata savers: none;
- metadata readers: **Nfo** only. Otherwise Jellyfin matches channels against real TV shows.

New videos appear after Jellyfin's library scan (every 12 h by default; "Scan Library" to see them now).

## Troubleshooting
- Pod stuck in `ContainerCreating` with `hostPath type check failed`: the `media` share isn't mounted in the VM
  (`findmnt /mnt/media` on k3s), or `youtube/` is missing on the host (rerun `pve.yml`).
- Downloads fail with "Sign in to confirm you're not a bot": YouTube rate-limited the home IP. Wait, or add a cookies
  file (Pinchflat docs: "YouTube cookies"). Pinchflat updates yt-dlp by itself, but a fresh YouTube change can break
  it for a day or two.
