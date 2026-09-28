# Monitoring and alerts

VictoriaMetrics stack in k3s (`kubernetes/infrastructure/*/monitoring`): metrics from k3s, the Proxmox host
(node-exporter) and blackbox probes of everything outside the cluster. Alerts (severity `warning`/`critical`)
go from Alertmanager to Telegram: bot [@egorras_homelab_bot](https://t.me/egorras_homelab_bot), private chat
with Egor. The bot token is in SOPS (`kubernetes/infrastructure/controllers/monitoring/telegram.sops.yaml`).

## Telegram
- Test the bot (from WSL/Linux, repo root):
  ```sh
  T=$(sops decrypt --extract '["stringData"]["bot-token"]' kubernetes/infrastructure/controllers/monitoring/telegram.sops.yaml)
  curl -s "https://api.telegram.org/bot$T/sendMessage" -d chat_id=60383518 -d text="test from homelab"
  ```
- Another recipient (or a group): they message the bot (or add it to the group), read the chat ID from
  `https://api.telegram.org/bot$T/getUpdates`, then add it as another `telegram_configs` entry in
  `victoria-metrics.yaml`.
- Token leaked: @BotFather → `/revoke`, then `sops kubernetes/infrastructure/controllers/monitoring/telegram.sops.yaml`.

## Grafana
https://grafana.lab.egorras.net, user `admin`, password:
```sh
sops decrypt --extract '["stringData"]["admin-password"]' kubernetes/infrastructure/controllers/monitoring/grafana-admin.sops.yaml
```

## Adding a probe
Append a URL to `kubernetes/infrastructure/configs/monitoring/probes.yaml` (`http_2xx`, `http_2xx_insecure` for
self-signed, or `dns`). `ProbeFailed` fires after 3 minutes down.
