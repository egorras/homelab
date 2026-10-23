# metal

Everything below the OS/hypervisor layer: Proxmox VE install (`proxmox/`)
and post-install config (`ansible/`). Later additions (VM/LXC provisioning,
more hosts) belong here too.

## Layout

- `proxmox/setup.sh` - **run this.** One interactive script: installs its
  own dependency if missing, downloads (or reuses) the Proxmox ISO, asks
  the install questions, writes `answer.toml`, validates it, builds the
  custom ISO, and optionally flashes it straight to a USB drive.
- `proxmox/answer.toml.example` - reference/documentation for the file
  `setup.sh` generates; not needed if you just run the script.
- `proxmox/scripts/` - the individual steps (`gen-password-hash.sh`,
  `validate-answer.sh`, `build-iso.sh`) as standalone tools, for when you
  want to redo just one step (e.g. rebuild the ISO after hand-editing
  `answer.toml`) instead of re-running the whole wizard. Also
  `write-usb.ps1` - a native Windows PowerShell script that writes the
  built ISO straight to a USB drive (raw block write, like `dd`), for when
  `setup.sh` is run under WSL and can't reach a Windows-owned USB device.
- `ansible/` - post-install config, run over SSH after first boot: repo
  switch, SSH hardening, base/guest-agent packages, subscription nag
  removal. Mirrors the `pve_host` role from the previous iteration of this
  homelab (see "Prior art" below).

## Prerequisites

Run `setup.sh` on a Debian/Ubuntu box or inside WSL on Windows -
`proxmox-auto-install-assistant` only packages for Debian/Ubuntu (it's
shipped from Proxmox's own apt repo, not stock Debian/Ubuntu). The script
detects if it's missing and offers to add the repo and install it for you;
say no and it'll point you at the manual steps instead
(https://pve.proxmox.com/wiki/Package_Repositories).

## Steps

```bash
cd metal/proxmox
./setup.sh
```

It walks you through everything: ISO source, hostname/timezone, network
(DHCP or static + NIC name), target disk, root password, and optionally an
SSH public key for root - then builds `pve-autoinstall.iso`.

Flashing the result to USB:
- **Native Linux:** `setup.sh` offers to `dd` it to a device you pick, with
  a confirmation step.
- **WSL on Windows:** WSL can't write a Windows-owned USB device directly,
  so `setup.sh` instead tells you to run, from an **Administrator**
  PowerShell on the Windows side:
  ```powershell
  metal/proxmox/scripts/write-usb.ps1 -IsoPath <path to pve-autoinstall.iso>
  ```
  It lists disks, hides your system disk, and requires typing the disk
  number back to confirm before it writes (same raw-block approach as
  `dd` - no Rufus/balenaEtcher needed, though either still works fine).

Boot the target node from the USB stick; installation then runs unattended.

Once it reboots into Proxmox, configure it with Ansible:

```bash
cd metal/ansible
ansible-galaxy collection install -r requirements.yml
```

Edit `inventory/hosts.yml` to match the node's real IP (whatever you gave
`setup.sh`), then optionally set `pve_host_admin_ssh_keys` and
`pve_host_disable_password_ssh` in `roles/pve_host/defaults/main.yml` (or
override per-host in `host_vars/`, or with `-e` on the command line).

```bash
ansible-playbook playbooks/pve.yml --check --diff   # dry run
ansible-playbook playbooks/pve.yml                  # apply
```

Re-run it any time; it's idempotent and should report no changes if
nothing drifted.

## Notes

- Double-check the NIC name (`filter.ID_NET_NAME`) and disk (`disk-list`)
  against what the target hardware actually reports - boot the stock ISO
  into a live shell (`ip link`, `lsblk`) first if you're not sure, since
  `disk-list` wipes whatever's on those disks.
- Repo setup (both `setup.sh`'s own dependency install and the `pve_host`
  role) uses the current deb822 `.sources` + `Signed-By` keyring format
  (PVE 9 / Debian trixie); the role also tolerates older PVE 8 `.list`
  files if present.
- `pve_host_disable_password_ssh` defaults to `false` on purpose. Confirm
  key-based login works (`ssh root@<node>`) before flipping it on - there's
  no recovery path from the network if it's wrong, short of console access.

## Prior art

This mirrors (a trimmed-down version of) the `metal/` setup from a previous
iteration of this homelab, which additionally used OpenTofu for VM/LXC
provisioning and sops+age for secrets (since that repo was public). This
repo keeps secrets out of git entirely for now instead - revisit if this
repo goes public too.
