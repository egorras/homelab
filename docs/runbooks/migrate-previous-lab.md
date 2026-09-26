# Carry state over from the previous lab (one-time, 2026-09 rebuild)

Tofu and Ansible build the guests; this moves the *data* of the old ones in. Old vzdump backups live in
`/mnt/hdd/backups-previous/dump` (moved there so the new prune job can't touch them; see reinstall-proxmox.md).

| Old guest | New | How |
|---|---|---|
| 100 haos | 100 haos | overwrite the new VM's disk with the old one (the old HA had no HA backups) |
| 104 jellyfin | 103 jellyfin | copy `/var/lib/jellyfin` + `/etc/jellyfin` into the new LXC |
| 102 adguard | 102 adguard | config codified in `roles/adguard` (UI password hash → `adguard_password_hash` in secrets) |
| 103 tailscale | host | replaced by Tailscale on the Proxmox host (docs/adr/0003) |
| 101 docker | k3s | Immich: started empty and re-uploaded from the phone (2026-09-26). The old library + DB dumps are parked in `/mnt/hdd/photos-old` until that finishes; restore steps kept in [immich.md](immich.md). Media stack later (`/mnt/hdd/media`) |

## Jellyfin
Same uid/gid (102/105) in old and new container, so a numeric-owner copy keeps permissions.
```sh
B=$(ls /mnt/hdd/backups-previous/dump/vzdump-lxc-104-*.tar.zst); T=$(mktemp -d /mnt/hdd/restore-tmp/jf.XXXX)
zstd -dc $B | tar -C $T --numeric-owner -xpf - ./var/lib/jellyfin ./etc/jellyfin
pct exec 103 -- systemctl stop jellyfin
pct exec 103 -- sh -c "rm -rf /var/lib/jellyfin /etc/jellyfin"
tar -C $T --numeric-owner -cf - ./var/lib/jellyfin ./etc/jellyfin | pct exec 103 -- tar -C / --numeric-owner -xpf -
pct exec 103 -- systemctl start jellyfin && rm -rf $T
```

## Home Assistant
Extract the old disk (sparse raw, ~4 GB used), then write it over the new VM's disk. Same 32 GB size; the VM
definition stays exactly as tofu made it.
```sh
mkdir -p /mnt/hdd/restore-tmp && cd /mnt/hdd/restore-tmp
zstd -dc /mnt/hdd/backups-previous/dump/vzdump-qemu-100-*.vma.zst > haos.vma && vma extract haos.vma haos && rm haos.vma

V=$(qm config 100 | sed -nE 's/^scsi0: local-lvm:([^,]+),.*/\1/p'); D=/dev/pve/$V
qm stop 100
blkdiscard $D                                  # thin volume back to zeros, so zero blocks can be skipped
qemu-img convert -p -n --target-is-zero -f raw -O raw haos/disk-drive-scsi0.raw $D
qm start 100
```
Afterwards: **Settings → System → Backups** in HA → enable automatic backups (the old install had none), and
`rm -rf /mnt/hdd/restore-tmp`.
