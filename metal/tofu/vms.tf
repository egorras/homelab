# Host directory (created by Ansible pve_host on the HDD) that the k3s VM mounts as virtiofs tag "photos".
resource "proxmox_hardware_mapping_dir" "photos" {
  name    = "photos"
  comment = "Immich library (HDD). Managed by OpenTofu."
  map = [
    {
      node = local.node
      path = "/mnt/hdd/photos"
    },
  ]
}

# Jellyfin's media library (also bind-mounted read-only into its LXC); k3s apps write into subfolders (youtube/).
resource "proxmox_hardware_mapping_dir" "media" {
  name    = "media"
  comment = "Jellyfin media library (HDD). Managed by OpenTofu."
  map = [
    {
      node = local.node
      path = "/mnt/hdd/media/data/media"
    },
  ]
}

# BookOrbit's ebook/audiobook/comics library (HDD).
resource "proxmox_hardware_mapping_dir" "books" {
  name    = "books"
  comment = "BookOrbit library (HDD). Managed by OpenTofu."
  map = [
    {
      node = local.node
      path = "/mnt/hdd/books"
    },
  ]
}

resource "proxmox_virtual_environment_vm" "k3s" {
  name        = "k3s"
  description = "k3s: all apps, reconciled by Flux. Managed by OpenTofu."
  node_name   = local.node
  vm_id       = local.lab.guests.k3s.vmid
  pool_id     = proxmox_virtual_environment_pool.homelab.pool_id
  tags        = ["tofu"]

  on_boot = true
  startup {
    order = 2
  }

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  cpu {
    cores = 4
    type  = "host"
  }
  memory {
    dedicated = 12288
  }

  # No guest agent in the cloud image. Without it Proxmox shuts down via ACPI and backups are crash-consistent,
  # fine for a node Flux rebuilds from git (docs/adr/0001). Turning it on later means a VM reboot.
  agent {
    enabled = false
  }
  stop_on_destroy = true

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    import_from  = proxmox_download_file.debian_cloud.id
    size         = 80
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge = "vmbr0"
  }

  serial_device {} # Debian cloud images log to the serial console

  # Immich originals, the media library and the BookOrbit library stay on the HDD; vzdump doesn't include
  # virtiofs shares, so they aren't copied into the weekly VM backup (their off-site copy is a separate job).
  virtiofs {
    mapping = proxmox_hardware_mapping_dir.photos.name
  }
  virtiofs {
    mapping = proxmox_hardware_mapping_dir.media.name
  }
  virtiofs {
    mapping = proxmox_hardware_mapping_dir.books.name
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "${local.lab.guests.k3s.ip}/24"
        gateway = local.gateway
      }
    }
    dns {
      servers = local.nameservers
    }
    user_account {
      username = "debian" # cloud-init refuses root logins; Ansible uses this user with sudo
      keys     = local.lab.admin_ssh_keys
    }
  }
}

resource "proxmox_virtual_environment_vm" "haos" {
  name        = "haos"
  description = "Home Assistant OS (appliance, own updater: docs/adr/0002). Managed by OpenTofu."
  node_name   = local.node
  vm_id       = local.lab.guests.haos.vmid
  pool_id     = proxmox_virtual_environment_pool.homelab.pool_id
  tags        = ["tofu"]

  on_boot = true
  startup {
    order = 3
  }

  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 4096
  }
  agent {
    enabled = true # HAOS ships the guest agent
  }
  tablet_device = false

  efi_disk {
    datastore_id      = "local-lvm"
    type              = "4m"
    pre_enrolled_keys = false # HAOS isn't signed for Secure Boot
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    import_from  = "local:import/haos_ova-${local.lab.haos_version}.qcow2"
    size         = 32 # = the image's size; local-lvm is 170 GB for all guests
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = local.lab.guests.haos.mac
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  lifecycle {
    # HAOS updates itself; a version bump in all.yml must not rebuild the VM and wipe Home Assistant.
    ignore_changes = [disk[0].import_from]
  }
}
