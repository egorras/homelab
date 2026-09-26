# Cluster UIs

## Headlamp (web): https://k8s.lab.egorras.net
Login token (cluster-admin; treat it like a root password):
```sh
kubectl -n headlamp get secret headlamp-admin-token -o jsonpath='{.data.token}' | base64 -d
```
Rotate: `kubectl -n headlamp delete secret headlamp-admin-token`. Flux recreates it within 10 minutes with a new token.

## Lens / kubectl (desktop)
`make kubeconfig` writes `./kubeconfig` (gitignored). On Windows without make:
```sh
ssh debian@192.168.0.240 sudo cat /etc/rancher/k3s/k3s.yaml | sed -e 's/127.0.0.1/192.168.0.240/' -e 's/: default$/: homelab/' > ~/.kube/homelab.yaml
```
Lens: Preferences → Kubernetes → Kubeconfig Syncs → add the file. Same credentials class as the token above.
