#!/usr/bin/env bash
# One-shot, interactive Proxmox VE install prep: downloads (or reuses) the
# installer ISO, asks for the settings that go in answer.toml, writes it,
# validates it, and builds a ready-to-flash ISO. Optionally writes that ISO
# straight to a USB drive.
#
# Requires proxmox-auto-install-assistant, which only packages for
# Debian/Ubuntu - run this on a Debian/Ubuntu box or inside WSL. It will
# offer to install the tool itself via Proxmox's apt repo.
set -euo pipefail
cd "$(dirname "$0")"

ISO_INDEX_URL="https://enterprise.proxmox.com/iso/"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }

ask() { # ask "prompt" "default" -> echoes the answer on stdout
  local prompt="$1" default="${2:-}" reply
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " reply
    echo "${reply:-$default}"
  else
    read -rp "$prompt: " reply
    echo "$reply"
  fi
}

ask_required() { # like ask, but loops until a non-empty answer is given
  local prompt="$1" default="${2:-}" reply
  while true; do
    reply="$(ask "$prompt" "$default")"
    [[ -n "$reply" ]] && { echo "$reply"; return; }
    echo "This value is required." >&2
  done
}

# choose_from_list "label" "manual prompt" <<< "$candidates" -> echoes the pick
# Numbers a newline-separated candidate list and lets you pick by index, or
# type a value by hand (option 0) when the list is empty or none of it fits.
# Candidates come from THIS machine, which is only the target node if this
# script is running on that node itself (e.g. booted from a live Linux USB
# on that exact hardware) - say so to the user before calling this.
choose_from_list() {
  local manual_prompt="$1" candidates="$2" choice picked n=0
  if [[ -n "$candidates" ]]; then
    echo "$candidates" | nl -w2 -s') '
    echo " 0) type a value manually"
    while true; do
      choice="$(ask "Pick a number, or 0 to type manually" "0")"
      if [[ "$choice" == "0" ]]; then
        break
      fi
      picked="$(echo "$candidates" | sed -n "${choice}p" | awk '{print $1}')"
      if [[ -n "$picked" ]]; then
        echo "$picked"
        return
      fi
      echo "Invalid choice." >&2
    done
  fi
  ask_required "$manual_prompt" ""
}

### 1. Make sure proxmox-auto-install-assistant is available ################
if ! command -v proxmox-auto-install-assistant >/dev/null 2>&1; then
  bold "proxmox-auto-install-assistant is not installed."
  if command -v apt-get >/dev/null 2>&1; then
    reply="$(ask "Add Proxmox's apt repo and install it now? [y/N]" "N")"
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
      sudo mkdir -p /usr/share/keyrings
      sudo curl -fsSL "https://enterprise.proxmox.com/debian/proxmox-archive-keyring-${codename}.gpg" \
        -o /usr/share/keyrings/proxmox-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] https://download.proxmox.com/debian/pve ${codename} pve-no-subscription" \
        | sudo tee /etc/apt/sources.list.d/pve-install-repo.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y proxmox-auto-install-assistant
    else
      echo "See metal/README.md for manual install steps, then re-run this script." >&2
      exit 1
    fi
  else
    echo "No apt-get on this system. Run this script inside WSL (Debian/Ubuntu) instead." >&2
    exit 1
  fi
fi

### 2. Get an ISO #############################################################
bold "ISO"
src_iso=""
existing_iso="$(ls proxmox-ve_*.iso 2>/dev/null | sort -V | tail -1 || true)"
if [[ -n "$existing_iso" ]]; then
  reply="$(ask "Found $existing_iso - use it?" "y")"
  [[ "$reply" =~ ^[Yy]$ ]] && src_iso="$existing_iso"
fi

if [[ -z "$src_iso" ]]; then
  reply="$(ask "Download the latest Proxmox VE ISO now?" "y")"
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    echo "Checking $ISO_INDEX_URL for the latest release..."
    latest_iso="$(curl -fsSL "$ISO_INDEX_URL" | grep -oE 'proxmox-ve_[0-9]+\.[0-9]+-[0-9]+\.iso' | sort -Vu | tail -1)"
    if [[ -z "$latest_iso" ]]; then
      echo "Could not find a listing at $ISO_INDEX_URL - download manually from https://www.proxmox.com/en/downloads and re-run." >&2
      exit 1
    fi
    echo "Downloading $latest_iso ..."
    curl -fL -o "$latest_iso" "${ISO_INDEX_URL}${latest_iso}"
    echo "Verifying checksum..."
    if curl -fsSL "${ISO_INDEX_URL}SHA256SUMS" -o SHA256SUMS.tmp; then
      if ! grep "$latest_iso" SHA256SUMS.tmp | sha256sum -c -; then
        rm -f "$latest_iso" SHA256SUMS.tmp
        echo "Checksum verification failed - deleted the download, aborting." >&2
        exit 1
      fi
      rm -f SHA256SUMS.tmp
    else
      echo "No SHA256SUMS published to verify against - continuing without verification." >&2
    fi
    src_iso="$latest_iso"
  else
    src_iso="$(ask_required "Path to an existing Proxmox VE ISO" "")"
    [[ -f "$src_iso" ]] || { echo "File not found: $src_iso" >&2; exit 1; }
  fi
fi

### 3. Collect answer.toml settings ##########################################
bold "Node settings"
fqdn="$(ask_required "Hostname (FQDN)" "pve1.homelab.lan")"
mailto="$(ask "Admin email (for Proxmox notifications, optional)" "")"
timezone="$(ask "Timezone" "Europe/Vienna")"
keyboard="$(ask "Keyboard layout" "en-us")"
country="$(ask "Country code" "at")"

bold "Network"
while true; do
  net_mode="$(ask "Network mode: dhcp or static" "static")"
  [[ "$net_mode" == "dhcp" || "$net_mode" == "static" ]] && break
  echo "Enter 'dhcp' or 'static'." >&2
done
if [[ "$net_mode" == "static" ]]; then
  echo "NICs visible to THIS machine - only meaningful if this script is running on the target node itself (e.g. booted from a live Linux USB on that hardware). Otherwise pick 0 and type the name from a live shell on the target."
  nic_candidates="$(command -v ip >/dev/null 2>&1 && ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//' | grep -v '^lo$' || true)"
  nic="$(choose_from_list "NIC name on the TARGET node (e.g. eno1)" "$nic_candidates")"
  cidr="$(ask_required "Static IP with prefix (e.g. 192.168.0.10/24)" "192.168.0.10/24")"
  gateway="$(ask_required "Gateway" "192.168.0.1")"
  dns="$(ask "DNS server" "$gateway")"
fi

bold "Disk"
echo "WARNING: all data on the chosen disk is erased during install."
echo "Disks visible to THIS machine - only meaningful if this script is running on the target node itself (e.g. booted from a live Linux USB on that hardware). Otherwise pick 0 and type the name from a live shell ('lsblk') on the target."
disk_candidates="$(command -v lsblk >/dev/null 2>&1 && lsblk -dn -o NAME,SIZE,MODEL,TRAN -e7 2>/dev/null || true)"
disk="$(choose_from_list "Disk device name on the TARGET node (e.g. sda, nvme0n1)" "$disk_candidates")"

bold "Root password"
while true; do
  read -rsp "Root password: " pw1; echo
  read -rsp "Confirm: " pw2; echo
  [[ -n "$pw1" && "$pw1" == "$pw2" ]] && break
  echo "Passwords were empty or did not match, try again." >&2
done
pw_hash="$(openssl passwd -6 -stdin <<< "$pw1")"
unset pw1 pw2

bold "Root SSH key(s) (optional, recommended - lets you disable password SSH login later)"
ssh_keys=()
while true; do
  key="$(ask "Public key to authorize for root (blank to finish)" "")"
  [[ -z "$key" ]] && break
  ssh_keys+=("$key")
done

### 4. Write answer.toml ######################################################
bold "Writing answer.toml"
{
  echo "[global]"
  echo "keyboard = \"$keyboard\""
  echo "country = \"$country\""
  echo "timezone = \"$timezone\""
  echo "fqdn = \"$fqdn\""
  [[ -n "$mailto" ]] && echo "mailto = \"$mailto\""
  echo "root-password-hashed = \"$pw_hash\""
  echo "reboot-on-error = false"
  if [[ ${#ssh_keys[@]} -gt 0 ]]; then
    echo -n "root-ssh-keys = ["
    for k in "${ssh_keys[@]}"; do
      printf '\n  "%s",' "$k"
    done
    echo $'\n]'
  fi
  echo
  echo "[network]"
  if [[ "$net_mode" == "static" ]]; then
    echo "source = \"from-answer\""
    echo "cidr = \"$cidr\""
    echo "dns = \"$dns\""
    echo "gateway = \"$gateway\""
    echo "filter.ID_NET_NAME = \"$nic\""
  else
    echo "source = \"from-dhcp\""
  fi
  echo
  echo "[disk-setup]"
  echo "filesystem = \"ext4\""
  echo "disk-list = [\"$disk\"]"
} > answer.toml
echo "Wrote $(pwd)/answer.toml"

### 5. Validate and build the ISO ############################################
out_iso="pve-autoinstall.iso"
./scripts/build-iso.sh "$src_iso" "$out_iso"

### 6. Optional: write straight to USB ########################################
bold "USB"
is_wsl=false
grep -qi microsoft /proc/version 2>/dev/null && is_wsl=true

if [[ "$is_wsl" == true ]]; then
  echo "Running under WSL - WSL can't write raw USB block devices, so dd here won't reach a drive Windows owns."
  if [[ "$(pwd)" == /mnt/* ]]; then
    win_path="$(wslpath -w "$(pwd)/$out_iso" 2>/dev/null || true)"
    echo "Since this repo is on the Windows filesystem, $out_iso is also at: ${win_path:-<repo path on the C: drive>}"
  fi
  echo "From Windows PowerShell (as Administrator), run:"
  echo "  metal/proxmox/scripts/write-usb.ps1 -IsoPath <path to $out_iso>"
  echo "(or flash it with Rufus / balenaEtcher)."
elif [[ "$(uname -s)" == "Linux" ]]; then
  reply="$(ask "Write $out_iso to a USB drive now?" "N")"
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    lsblk -d -o NAME,SIZE,MODEL,TRAN
    dev="$(ask_required "Device to write to, WITHOUT /dev/ (e.g. sdb) - double-check against the listing above" "")"
    confirm="$(ask_required "Type '$dev' again to confirm ERASING /dev/$dev" "")"
    if [[ "$confirm" == "$dev" ]]; then
      sudo dd if="$out_iso" of="/dev/$dev" bs=4M status=progress conv=fsync
      sync
      echo "Done. Boot the target node from this USB stick."
    else
      echo "Confirmation did not match - skipped. Flash $out_iso manually." >&2
    fi
  fi
else
  echo "Direct USB writing here only supports Linux/WSL. Flash $out_iso with Rufus or balenaEtcher instead." >&2
fi

bold "Done. Built $(pwd)/$out_iso"
