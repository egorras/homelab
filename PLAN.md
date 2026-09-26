# Roadmap

Built one thin layer at a time; each milestone ends with a check that proves it works.
Guiding test: **USB install + `make bootstrap` + merge to `main` reproduces the whole lab with no manual SSH.**
Any manual step found along the way becomes code or a runbook.

## Hardware
- Home: Fujitsu Esprimo D958 SFF — i5-8500 (UHD 630 Quick Sync), 24 GB RAM, 256 GB NVMe (system), 4 TB HDD (media, backups)
- Cloud: Oracle Cloud A1.Flex — 2 OCPU / 12 GB, arm64 (Always Free)

## CI/CD model
- **Apps** (`kubernetes/`): Flux pulls; merged changes are live in ~1 min. CI only validates (kustomize build, kubeconform).
- **Infra** (`metal/`): a GitHub-hosted runner joins the tailnet as an *ephemeral* `tag:ci` node (OAuth client).
  PR → `tofu plan` + `ansible --check --diff` posted as a comment. Merge to `main` → apply, in the protected `homelab`
  environment, serialized by a concurrency group; encrypted tofu state committed back.
- **Secrets**: GitHub holds only `SOPS_AGE_KEY`, `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`; everything else is SOPS-encrypted in git.
- **Public-repo hygiene**: gitleaks in pre-commit + CI, actions pinned by SHA (Renovate), no `pull_request_target`,
  tailnet ACL limits `tag:ci` to the hosts it deploys.

## Milestones
- [x] **M0 — repo foundation**: toolchain (mise/devcontainer), pre-commit, lint CI, SOPS, Renovate, ADRs.
  ✅ lint green; gitleaks blocks a planted fake key.
- [x] **M1 — Proxmox from code**: `answer.toml` auto-install on NVMe (HDD untouched); Ansible `pve_host` — repos,
  NIC offload fix + watchdog, HDD mount + backup storage/job, sensors + node-exporter, Tailscale on host,
  `tofu@pve` token, CI SSH key. ✅ second run = 0 changed; host reachable over Tailscale.
- [x] **M2 — infra pipeline**: tailnet ACL + OAuth, `infra.yml`, tofu state encryption. ✅ PR shows plan, merge applies.
- [ ] **M3 — guests**: k3s VM (Debian cloud-init, 4c/12 GB), AdGuard LXC, Jellyfin LXC (`/dev/dri`), HAOS VM.
  ✅ `tofu plan` clean; DNS, Jellyfin, HA respond.
- [x] **M4 — k3s + Flux**: k3s via Ansible, `flux bootstrap`, SOPS decryption, cert-manager wildcard
  `*.lab.egorras.net` (DNS-01), `whoami`. ✅ merged change live in ~1 min with a valid cert.
- [ ] **M5 — platform + first apps**: VictoriaMetrics + Grafana + Alertmanager → ntfy, blackbox probes;
  Homepage, Homelable; `apps/_template` + runbook. ✅ new app = one PR copying the template.
- [ ] **M6 — Oracle VPS**: codify the existing host (WireGuard) with 0 drift first, then k3s + Flux `clusters/oracle`:
  Gatus probing home → ntfy. ✅ home k3s down → phone alert from the cloud.

**Later** (one PR each via the template): media stack, Immich, n8n + CloudNativePG, Homebox, Authelia SSO,
backups (Garage + off-site), DR drill (destroy k3s VM → time to recovery), docs site.
