# 1. Apps run on single-node k3s, reconciled by Flux

**Status:** accepted

## Context
Apps previously ran as Docker Compose stacks on a VM, deployed by hand. The goal is push-to-deploy with drift correction.

## Decision
One k3s VM hosts all apps. Flux watches `kubernetes/clusters/home` and applies what is merged to `main`.

## Consequences
- CI never needs cluster credentials: Flux pulls, so nothing inbound is exposed.
- Drift (manual `kubectl` edits) is reverted automatically.
- More moving parts than Compose; accepted for self-healing and a standard app template.
- Single node, no HA. Recovery = recreate the VM from tofu and let Flux reconcile.
