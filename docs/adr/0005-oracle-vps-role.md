# 5. The Oracle VPS is a second, small cluster for what must work when home is down

**Status:** accepted

## Decision
The Oracle A1 VPS (arm64, Always Free) runs its own single-node k3s managed by Flux from `kubernetes/clusters/oracle`.
It hosts external uptime monitoring of home (Gatus → ntfy), public endpoints (webhooks) and later an off-site backup target.
Its existing WireGuard VPN stays a host service, codified with Ansible before anything else changes.

## Not here
- Joining it to the home cluster: a WAN-spanning control plane is fragile.
- Large storage (the free tier has ~200 GB of block storage) or anything irreplaceable: free instances can be reclaimed.
