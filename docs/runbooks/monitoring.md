# Monitoring and alerts

VictoriaMetrics stack in k3s (`kubernetes/infrastructure/*/monitoring`): metrics from k3s, the Proxmox host
(node-exporter) and blackbox probes of everything outside the cluster. Alerts (severity `warning`/`critical`)
go from Alertmanager to an ntfy.sh topic; the topic name is secret, in SOPS.

## Get alerts on the phone
1. Install the **ntfy** app (Android/iOS).
2. Get the topic (from WSL/Linux, repo root):
   ```sh
   sops decrypt --extract '["stringData"]["url"]' kubernetes/infrastructure/controllers/monitoring/ntfy.sops.yaml
   ```
   The part between `ntfy.sh/` and `?` is the topic.
3. In the app: **+** → topic name → server `ntfy.sh` → Subscribe.
4. Test: `curl -d "test from homelab" https://ntfy.sh/<topic>`.

## Grafana
https://grafana.lab.egorras.net, user `admin`, password:
```sh
sops decrypt --extract '["stringData"]["admin-password"]' kubernetes/infrastructure/controllers/monitoring/grafana-admin.sops.yaml
```

## Adding a probe
Append a URL to `kubernetes/infrastructure/configs/monitoring/probes.yaml` (`http_2xx`, `http_2xx_insecure` for
self-signed, or `dns`). `ProbeFailed` fires after 3 minutes down.
