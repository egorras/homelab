"""Seed Homelable from topology.yaml, then idle. Runs as a sidecar of homelable-backend (same image: httpx and
PyYAML are already there) and talks to it on localhost.

Idempotent: nodes are matched by label and only the fields topology.yaml sets are patched; positions are
applied on create only, so layout done in the UI survives. Links are added when missing, never removed.
Also switches on Proxmox auto-sync when the backend has a token (env), and runs one sync.
"""

import os
import time

import httpx
import yaml

API = os.environ.get("HOMELABLE_API", "http://localhost:8000/api/v1")
TOPOLOGY = os.environ.get("TOPOLOGY", "/seed/topology.yaml")
NOTE = "Managed in git: kubernetes/apps/homelable/topology.yaml"


def log(msg: str) -> None:
    print(msg, flush=True)


def wait_ready(client: httpx.Client) -> None:
    while True:
        try:
            if client.get(f"{API}/health").status_code == 200:
                return
        except httpx.TransportError:
            pass
        time.sleep(3)


def login(client: httpx.Client) -> None:
    r = client.post(
        f"{API}/auth/login",
        json={"username": os.environ.get("HOMELABLE_USER", "admin"), "password": os.environ["HOMELABLE_PASSWORD"]},
    )
    r.raise_for_status()
    client.headers["Authorization"] = f"Bearer {r.json()['access_token']}"


def desired_node(spec: dict) -> dict:
    check = spec.get("check", {})
    body = {
        "type": spec["type"],
        "label": spec["label"],
        "hostname": spec.get("hostname"),
        "ip": spec.get("ip"),
        "os": spec.get("os"),
        "check_method": check.get("method", "ping"),
        "check_target": check.get("target"),
        "notes": spec.get("notes", NOTE),
    }
    if "services" in spec:
        body["services"] = [
            {"service_name": s["name"], "protocol": "tcp", "host": s["url"]} for s in spec["services"]
        ]
    return body


def service_keys(services: list) -> list:
    return [(s.get("service_name"), s.get("host")) for s in services or []]


def drift(current: dict, want: dict) -> dict:
    changed = {}
    for key, value in want.items():
        have = current.get(key)
        if key == "services":
            if service_keys(have) != service_keys(value):
                changed[key] = value
        elif have != value:
            changed[key] = value
    return changed


def seed_nodes(client: httpx.Client, specs: dict) -> dict[str, str]:
    by_label = {n["label"]: n for n in client.get(f"{API}/nodes").raise_for_status().json()}
    ids = {}
    for key, spec in specs.items():
        want = desired_node(spec)
        node = by_label.get(want["label"])
        if node is None:
            x, y = spec.get("pos", [None, None])
            r = client.post(f"{API}/nodes", json={**want, "pos_x": x, "pos_y": y})
            if r.status_code == 409:  # same ip already drawn (e.g. approved from a scan): adopt that node
                node_id = r.json()["detail"]["existing_node_id"]
                node = client.get(f"{API}/nodes/{node_id}").raise_for_status().json()
                log(f"adopt   {want['label']} (was {node['label']})")
            else:
                r.raise_for_status()
                ids[key] = r.json()["id"]
                log(f"create  {want['label']}")
                continue
        changed = drift(node, want)
        if changed:
            client.patch(f"{API}/nodes/{node['id']}", json=changed).raise_for_status()
            log(f"update  {want['label']}: {', '.join(sorted(changed))}")
        ids[key] = node["id"]
    return ids


def seed_links(client: httpx.Client, links: list, ids: dict[str, str]) -> None:
    existing = {frozenset((e["source"], e["target"])) for e in client.get(f"{API}/edges").raise_for_status().json()}
    for link in links:
        src, dst = ids[link["from"]], ids[link["to"]]
        if frozenset((src, dst)) in existing:
            continue
        body = {"source": src, "target": dst, "type": link.get("type", "ethernet"), "label": link.get("label")}
        client.post(f"{API}/edges", json=body).raise_for_status()
        log(f"link    {link['from']} -> {link['to']}")


def proxmox_sync(client: httpx.Client) -> None:
    config = client.get(f"{API}/proxmox/config").raise_for_status().json()
    if not config["token_configured"]:
        log("proxmox: no token in env, skipping auto-sync")
        return
    if not config["sync_enabled"]:
        client.post(f"{API}/proxmox/config", json={"sync_enabled": True, "sync_interval": 3600}).raise_for_status()
        log("proxmox: auto-sync enabled (hourly)")
    client.post(f"{API}/proxmox/sync-now").raise_for_status()
    log("proxmox: sync started (results under Pending)")


def main() -> None:
    with open(TOPOLOGY) as f:
        topology = yaml.safe_load(f)
    with httpx.Client(timeout=30) as client:
        wait_ready(client)
        login(client)
        proxmox_sync(client)
        ids = seed_nodes(client, topology["nodes"])
        seed_links(client, topology.get("links", []), ids)
    log("seed done")


if __name__ == "__main__":
    while True:
        try:
            main()
            break
        except Exception as exc:  # backend restarting, bad topology, ...: retry, stay visible in logs
            log(f"seed failed: {exc!r}; retrying in 60s")
            time.sleep(60)
    while True:  # keep the sidecar alive; a topology change rolls the pod and seeds again
        time.sleep(86400)
