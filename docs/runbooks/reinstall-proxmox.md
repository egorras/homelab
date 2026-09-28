# Reinstall Proxmox from scratch

Wipes the NVMe only. The HDD (`/mnt/hdd`: media, backups) is not in the installer's `disk-list` and is remounted by Ansible.

## Before (once per reinstall)
1. Tailscale admin console, **Access controls**: make sure the policy has
   ```jsonc
   "tagOwners": { "tag:pve": ["autogroup:admin"], "tag:ci": ["autogroup:admin"] },
   "autoApprovers": { "routes": { "192.168.0.0/24": ["tag:pve"] } }
   ```
2. **Settings → Keys → Generate auth key**: one-off, pre-approved, tag `tag:pve`. Store it:
   ```sh
   sops set metal/secrets.sops.yaml '["tailscale_auth_key"]' '"tskey-auth-..."'
   ```
   Remove the old `pve` machine from the tailnet if it exists.
3. Optional — keep the previous lab's guest backups out of reach of the new prune job:
   `ssh root@192.168.0.18 mv /mnt/hdd/backups /mnt/hdd/backups-previous`

## Install
1. `make iso` → `metal/proxmox/out/proxmox-ve-auto.iso`.
2. Flash it to a USB stick (balenaEtcher, or Rufus in **DD mode**, or `dd`).
3. Boot the server from USB (F12 boot menu on the Esprimo). Pick **Automated Installation** or wait
   — it installs to the NVMe and reboots, no prompts. ~10 min.
4. Remove the USB stick. Host comes up at `192.168.0.18`.

## Configure
```sh
ssh-keygen -R 192.168.0.18      # host key changed
make bootstrap                  # ansible pve_host
git add metal/secrets.sops.yaml && git commit -m "chore: rotate proxmox api token"   # token written by bootstrap
make bootstrap                  # must report changed=0
```

## Check
- `https://192.168.0.18:8006` — log in as `root` (password: `sops decrypt --extract '["root_password"]' metal/secrets.sops.yaml`).
- `pve` online in the Tailscale console with route `192.168.0.0/24` approved.
- Datacenter → Backup shows job `weekly`; Storage shows `hdd-backup`.
