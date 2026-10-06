#!/bin/bash
# Keeps the container alive across the chicken-and-egg gap before first-time login: the daemon
# exits non-zero when not authenticated, which would otherwise crash-loop the container so fast
# (startedAt == finishedAt) that there's no window left to `kubectl exec`/Headlamp-terminal in and
# run `multica setup self-host` + `claude login` + `codex login`. Retrying in a loop instead means
# the container is always reachable, and once login succeeds the next retry just runs for good.
set -u
while true; do
  multica daemon start --foreground --no-auto-update --no-auto-reload --runtime-name homelab-k3s
  echo "multica daemon exited ($?); retrying in 30s" >&2
  sleep 30
done
