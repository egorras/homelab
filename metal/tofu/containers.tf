locals {
  containers = {
    adguard = {
      description = "AdGuard Home: LAN DNS, outside k3s on purpose (docs/adr/0002)."
      cores       = 1
      memory      = 512
      swap        = 256
      disk        = 4
      order       = 1
    }
    jellyfin = {
      description = "Jellyfin with Quick Sync; media bind mount + /dev/dri are set by Ansible (root@pam only)."
      cores       = 4
      memory      = 3072
      swap        = 512
      disk        = 24
      order       = 3
    }
  }
}

resource "proxmox_virtual_environment_container" "lxc" {
  for_each = local.containers

  description = "${each.value.description} Managed by OpenTofu."
  node_name   = local.node
  vm_id       = local.lab.guests[each.key].vmid
  pool_id     = proxmox_virtual_environment_pool.homelab.pool_id
  tags        = ["tofu"]

  unprivileged  = true
  start_on_boot = true
  startup {
    order = each.value.order
  }
  features {
    nesting = true # systemd in Debian 13 needs it
  }

  cpu {
    cores = each.value.cores
  }
  memory {
    dedicated = each.value.memory
    swap      = each.value.swap
  }
  disk {
    datastore_id = "local-lvm"
    size         = each.value.disk
  }

  operating_system {
    template_file_id = proxmox_download_file.debian_lxc.id
    type             = "debian"
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = local.lab.guests[each.key].mac
  }

  initialization {
    hostname = each.key
    ip_config {
      ipv4 {
        address = "${local.lab.guests[each.key].ip}/24"
        gateway = local.gateway
      }
    }
    dns {
      # Jellyfin is outside k3s, so use AdGuard for homelab split-DNS names.
      # Keep the router as fallback if AdGuard is unavailable.
      servers = each.key == "jellyfin" ? [local.lab.guests.adguard.ip, local.gateway] : local.nameservers
    }
    user_account {
      keys = local.lab.admin_ssh_keys
    }
  }

  lifecycle {
    # Set by Ansible (pve_host/tasks/lxc_passthrough.yml): tofu's API token can't.
    ignore_changes = [mount_point, device_passthrough]
  }
}
