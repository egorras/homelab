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
  you((you<br/>LAN / tailnet))

  subgraph gitops[GitOps]
    direction TB
    git[(github.com/egorras/homelab)]
    ci[GitHub Actions<br/>ephemeral tailnet node]
  end

  subgraph home[Proxmox host · Fujitsu D958]
    direction TB
    k3s[VM: k3s<br/>all apps]
    adguard[LXC: adguard<br/>DNS]
    jellyfin[LXC: jellyfin<br/>iGPU QSV]
    haos[VM: haos<br/>Home Assistant]
  end

  oracle[Oracle Cloud VPS<br/>2nd Flux cluster]

  git -- "Flux pulls<br/>(~1 min)" --> k3s
  git -- "PR → plan<br/>merge → apply" --> ci
  ci -- "tofu + ansible<br/>over Tailscale" --> home
  you -- "https" --> k3s & adguard & jellyfin & haos
  git -. planned .-> oracle
  oracle -. health probes .-> home
```

AdGuard and Jellyfin live outside the cluster on purpose ([ADR 0002](docs/adr/0002-services-outside-the-cluster.md)).

## 🧩 Services

Everything's reachable over LAN / tailnet only, behind a wildcard subdomain with a Let's Encrypt cert
(DNS-01 via Cloudflare). Alerts go to Telegram.

**Media**

| | Service | Runs on |
|---|---|---|
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyseerr.svg" width="20"> | Jellyseerr (requests → Sonarr/Radarr) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sonarr.svg" width="20"> | Sonarr (TV) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/radarr.svg" width="20"> | Radarr (movies) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/prowlarr.svg" width="20"> | Prowlarr (indexers) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/qbittorrent.svg" width="20"> | qBittorrent (behind PIA VPN) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/pinchflat.png" width="20"> | Pinchflat (YouTube → Jellyfin) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jellyfin.svg" width="20"> | Jellyfin | LXC |

**Photos**

| | Service | Runs on |
|---|---|---|
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/immich.svg" width="20"> | Immich | k3s |

**Home**

| | Service | Runs on |
|---|---|---|
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/home-assistant.svg" width="20"> | Home Assistant | VM (HAOS) |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/adguard-home.svg" width="20"> | AdGuard Home | LXC |

**Platform**

| | Service | Runs on |
|---|---|---|
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/homepage.svg" width="20"> | Homepage | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg" width="20"> | Grafana + VictoriaMetrics | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/headlamp.svg" width="20"> | Headlamp | k3s |
| 🗺️ | Homelable (network map) | k3s |
| <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/proxmox.svg" width="20"> | Proxmox VE | bare metal |

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

[Decisions (ADRs)](docs/adr) · [Runbooks](docs/runbooks)
