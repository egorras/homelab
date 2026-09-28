# Homelable (network map)

https://map.lab.egorras.net, login `admin` / `admin-password` from `kubernetes/apps/homelable/secret.sops.yaml`.

## The map comes from git
`kubernetes/apps/homelable/topology.yaml` lists the nodes (IP, type, status check, service links) and the
links between them. The `seed` sidecar in the `homelable-backend` pod applies it through the API on every
rollout, and editing the file rolls the pod.

- Nodes are matched by **label**. Renaming one in the file creates a new node, so delete the old one in the UI.
- Only fields set in the file are overwritten. Positions apply on create only, so drag nodes around freely.
- It never deletes anything. Nodes you add by hand or approve from a scan stay put.
- If a scanned node already has the same IP, the seed adopts it instead of drawing a second one.

Logs: `kubectl -n homelable logs deploy/homelable-backend -c seed`. A second run should print only `seed done`.

## Proxmox inventory import
The backend reads a read-only token (`homelable@pve!import`, role PVEAuditor) from env. The seed turns on the
hourly auto-sync and runs one sync; guests show up under **Pending** with CPU/RAM/disk and merge into the
seeded nodes by IP.

The token is created once, **locally**, never by CI (CI commits back only tofu state, so a secret created
there would be lost):
```sh
cd metal/ansible && ANSIBLE_CONFIG=$PWD/ansible.cfg mise exec -- ansible-playbook playbooks/pve.yml --tags homelable
git add kubernetes/apps/homelable/secret.sops.yaml && git commit -m "chore(homelable): proxmox import token"
```
To rotate: `pveum user token remove homelable@pve import` on the host, then run the command above again.
Without the token the backend runs normally and the import is off.
