<div align="center">

# 🏠 homelab

Single-node home lab defined entirely in this repo: **push to `main` → it's deployed.**

[![lint](https://img.shields.io/github/actions/workflow/status/egorras/homelab/lint.yml?branch=main&label=lint&logo=githubactions&logoColor=white&style=flat-square)](https://github.com/egorras/homelab/actions/workflows/lint.yml)
[![infra](https://img.shields.io/github/actions/workflow/status/egorras/homelab/infra.yml?branch=main&label=infra&logo=githubactions&logoColor=white&style=flat-square)](https://github.com/egorras/homelab/actions/workflows/infra.yml)
[![renovate](https://img.shields.io/badge/renovate-enabled-1a1f6c?logo=renovate&logoColor=white&style=flat-square)](renovate.json)
[![last commit](https://img.shields.io/github/last-commit/egorras/homelab/main?style=flat-square&logo=git&logoColor=white)](https://github.com/egorras/homelab/commits/main)

[![Proxmox](https://img.shields.io/badge/Proxmox_VE-E57000?logo=proxmox&logoColor=white&style=flat-square)](https://www.proxmox.com)
[![k3s](https://img.shields.io/badge/k3s-FFC61C?logo=k3s&logoColor=black&style=flat-square)](https://k3s.io)
[![Flux](https://img.shields.io/badge/Flux-5468FF?logo=flux&logoColor=white&style=flat-square)](https://fluxcd.io)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=opentofu&logoColor=black&style=flat-square)](https://opentofu.org)
[![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white&style=flat-square)](https://www.ansible.com)
[![SOPS](https://img.shields.io/badge/SOPS_+_age-0A0A0A?logo=letsencrypt&logoColor=white&style=flat-square)](https://getsops.io)
[![Tailscale](https://img.shields.io/badge/Tailscale-242424?logo=tailscale&logoColor=white&style=flat-square)](https://tailscale.com)

</div>

## ✨ How it works

| Layer | Tooling | Deployed by |
|---|---|---|
| Hypervisor (Proxmox VE) | automated install (`answer.toml`) + Ansible | one-time bootstrap, then CI |
| VMs & LXCs | OpenTofu (`bpg/proxmox`) + Ansible | GitHub Actions over Tailscale |
| Apps | Kubernetes (k3s) + Flux | Flux pulls from git |
| Secrets | SOPS + age | decrypted in-cluster / in CI |

```mermaid
flowchart LR
  git[(github.com/egorras/homelab)]
  ci[GitHub Actions<br/>ephemeral tailnet node]

  subgraph home[Proxmox host · Fujitsu D958]
    k3s[VM k3s<br/>all apps]
    adguard[LXC adguard<br/>DNS]
    jellyfin[LXC jellyfin<br/>iGPU QSV]
    haos[VM haos<br/>Home Assistant]
  end

  oracle[Oracle Cloud VPS<br/>2nd Flux cluster]

  git -- "Flux pulls (~1 min)" --> k3s
  git -- "PR: plan · merge: apply" --> ci
  ci -- "Tailscale: tofu + ansible" --> home
  git -. planned .-> oracle
  oracle -. probes .-> home
```

AdGuard and Jellyfin live outside the cluster on purpose ([ADR 0002](docs/adr/0002-services-outside-the-cluster.md)).

## 🧩 Services

| | Service | URL | Runs on |
|---|---|---|---|
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/immich.svg" width="20"> | Immich | `photos.lab.egorras.net` | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyfin.svg" width="20"> | Jellyfin | `jellyfin.lab.egorras.net` | LXC |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg" width="20"> | Home Assistant | LAN | VM (HAOS) |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/adguard-home.svg" width="20"> | AdGuard Home | `adguard.lab.egorras.net` | LXC |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/homepage.svg" width="20"> | Homepage | `home.lab.egorras.net` | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg" width="20"> | Grafana + VictoriaMetrics | `grafana.lab.egorras.net` | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/headlamp.svg" width="20"> | Headlamp | `k8s.lab.egorras.net` | k3s |
| 🗺️ | Homelable (network map) | `map.lab.egorras.net` | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proxmox.svg" width="20"> | Proxmox VE | `pve.lab.egorras.net` | bare metal |

`*.lab.egorras.net` is LAN / tailnet only, with a wildcard Let's Encrypt cert (DNS-01 via Cloudflare).
Alerts go to Telegram.

## 🖥️ Hardware

| Host | Specs |
|---|---|
| Fujitsu Esprimo D958 SFF | i5-8500 (UHD 630 Quick Sync), 24 GB RAM, 256 GB NVMe, 4 TB HDD |
| Oracle Cloud A1.Flex | 2 OCPU / 12 GB, arm64 (Always Free) |

## 📁 Layout

```
metal/        proxmox install, ansible roles, opentofu, tailnet policy
kubernetes/   clusters/, infrastructure/, apps/  (one folder per app, apps/_template to start)
docs/         adr/ (decisions), runbooks/
```

## 🚀 Getting started

```sh
make tools      # pinned toolchain via mise (or open the devcontainer)
make lint       # same checks as CI, including gitleaks
make check      # dry run: ansible --check --diff + tofu plan
make help       # everything else
```

New app → copy `kubernetes/apps/_template` ([runbook](docs/runbooks/new-app.md)).

## 🔐 Public-repo hygiene

Everything secret is SOPS-encrypted (tofu state too, [ADR 0004](docs/adr/0004-encrypted-tofu-state-in-git.md)).
gitleaks runs in pre-commit and CI, actions are pinned by SHA, fork PRs get no secrets, and CI reaches the
lab only as an ephemeral, ACL-limited Tailscale node ([ADR 0003](docs/adr/0003-ci-access-over-tailscale.md)).

## 📚 Docs

[Roadmap & status](PLAN.md) · [Decisions (ADRs)](docs/adr) · [Runbooks](docs/runbooks)
