# API token comes from PROXMOX_VE_API_TOKEN (set by run.sh from metal/secrets.sops.yaml).
provider "proxmox" {
  endpoint = "https://192.168.0.18:8006/"
  insecure = true # self-signed; reached over the tailnet only
}

variable "state_passphrase" {
  description = "State encryption passphrase (tofu_state_passphrase in metal/secrets.sops.yaml)."
  type        = string
  sensitive   = true
}

locals {
  # Guests, keys and versions are defined once, for Ansible and tofu alike.
  lab  = yamldecode(file("${path.module}/../ansible/inventory/group_vars/all.yml"))
  node = "pve"

  gateway     = local.lab.lan_gateway
  nameservers = [local.lab.lan_gateway] # the router, not AdGuard: guests must resolve while AdGuard is down
}

# Every guest lands in this pool.
resource "proxmox_virtual_environment_pool" "homelab" {
  pool_id = "homelab"
  comment = "Managed by OpenTofu (egorras/homelab)"
}
