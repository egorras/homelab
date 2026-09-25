# 3. CI reaches the lab through ephemeral Tailscale nodes

**Status:** accepted

## Context
Tofu and Ansible need to reach the Proxmox API and guest SSH from GitHub Actions. The repo is public.

## Options
- **Self-hosted runner in the lab**: GitHub advises against it on public repos, because a fork PR can execute code inside the LAN.
- **GitHub-hosted runner + Tailscale**: chosen.

## Decision
- Tailscale runs on the Proxmox host (subnet router for the LAN), not in a guest, so there is no bootstrap chicken-and-egg.
- Workflows join via a Tailscale **OAuth client** limited to creating **ephemeral** nodes tagged `tag:ci`.
- Tailnet ACL: `tag:ci` may reach only Proxmox `:8006`/`:22`, guest `:22` and the VPS `:22`.
- Apply jobs run only on `main`, in the protected `homelab` environment. No `pull_request_target`, so fork PRs never see secrets.
- Third-party actions are pinned by commit SHA.

## Consequences
A leaked OAuth secret grants short-lived, ACL-limited access; rotate it in the Tailscale admin console.
