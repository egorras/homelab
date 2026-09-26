# homelab

Single-node home lab defined entirely in this repo: **push to `main` → it's deployed.**

| Layer | Tooling | Deployed by |
|---|---|---|
| Hypervisor (Proxmox VE) | automated install (`answer.toml`) + Ansible | one-time bootstrap, then CI |
| VMs & LXCs | OpenTofu (`bpg/proxmox`) + Ansible | GitHub Actions over Tailscale |
| Apps | Kubernetes (k3s) + Flux | Flux pulls from git |
| Secrets | SOPS + age | decrypted in-cluster / in CI |

```
Proxmox host ── tailscale (subnet router)
├── VM  k3s       all apps, reconciled by Flux
├── LXC adguard   DNS          ┐ outside the cluster on purpose —
├── LXC jellyfin  iGPU (QSV)   ┘ see docs/adr/0002
└── VM  haos      Home Assistant OS
Oracle Cloud VPS (arm64) ── second Flux cluster: external monitoring, public endpoints
```

## Layout
```
metal/        proxmox install, ansible roles, opentofu, tailnet policy
kubernetes/   clusters/{home,oracle}, infrastructure, platform, apps
docs/         adr/ (decisions), runbooks/
```

## Getting started
```sh
make tools   # pinned toolchain via mise (or open the devcontainer)
make lint    # same checks as CI
```

Roadmap and status: [PLAN.md](PLAN.md). Decisions: [docs/adr](docs/adr).
