terraform {
  required_version = ">= 1.12"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.27.0"
    }
  }

  # State and plans are committed to git, encrypted (docs/adr/0004).
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true
    }
    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
