# 2. DNS, remote access, Jellyfin and Home Assistant live outside k3s

**Status:** accepted

## Context
If everything runs in the cluster, a broken cluster also takes away the tools needed to fix it.

## Decision
- **AdGuard (LXC)**: DNS must keep working while the cluster is down.
- **Tailscale on the Proxmox host**: remote and CI access must not depend on any guest (see ADR 3).
- **Jellyfin (LXC)**: needs `/dev/dri` for Quick Sync. Passing the iGPU to a VM (vfio) removes the host's only
  display adapter; an LXC shares it instead.
- **Home Assistant OS (VM)**: an appliance OS with its own updater; not a good fit for Kubernetes.

## Consequences
Each is still code (tofu + an Ansible role), just not Flux-managed. Ingress to them can be added in k3s via
selectorless Services.
