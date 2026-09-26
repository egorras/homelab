# Public fallback for the lab names: a private IP, so harmless to publish. Lab names resolve even when a client
# skips AdGuard (secondary DNS, phone on mobile data via Tailscale). AdGuard answers the same (roles/adguard).
# Token: CLOUDFLARE_API_TOKEN, from the same SOPS secret cert-manager uses (run.sh).
provider "cloudflare" {}

locals {
  cloudflare_zone_id = "622319fe30d47736a06740668638404d" # egorras.net (not secret)
}

resource "cloudflare_dns_record" "lab" {
  for_each = toset(["lab", "*.lab"])

  zone_id = local.cloudflare_zone_id
  name    = "${each.key}.egorras.net"
  type    = "A"
  content = local.lab.guests.k3s.ip
  ttl     = 300
  proxied = false
  comment = "homelab k3s ingress (LAN only). Managed by OpenTofu (egorras/homelab)"
}
