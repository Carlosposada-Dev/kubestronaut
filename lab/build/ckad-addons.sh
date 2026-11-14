#!/usr/bin/env bash
# CKAD add-ons on top of lab-v<n>: podman on cp1 (ckad-D1 1.1) and an Ingress controller (ckad-D5 5.3).
# Runs on the lab HOST, as the normal user. Idempotent — safe to re-run after a snapshot restore.
# Written 13 Nov 2026 with the lab down: NOT YET RUN. Verify on first use and delete this line.
set -euo pipefail
cd "$(dirname "$0")"
. ./common.sh

HTTP_NODEPORT=${HTTP_NODEPORT:-30080}
NS=ckad-accept

log "podman on cp1"
multipass exec cp1 -- bash -c 'command -v podman >/dev/null || { sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq podman; }'
multipass exec cp1 -- podman --version
# Fully qualified name on purpose: Ubuntu's podman has no unqualified-search registries by default.
multipass exec cp1 -- podman run --rm docker.io/library/busybox:1.36 echo "podman ok"

log "ingress-nginx via Helm (NodePort $HTTP_NODEPORT)"
multipass exec cp1 -- bash -c 'command -v helm >/dev/null' || { echo "helm missing on cp1 — install it first (cka-D1-3-access.md 1.6)"; exit 1; }
multipass exec cp1 -- helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http="$HTTP_NODEPORT" \
  --wait --timeout 5m
kc get ingressclass
kc -n ingress-nginx get pods,svc

log "acceptance: Deployment -> Service -> Ingress answers 200 through the controller"
kc delete ns "$NS" --ignore-not-found --wait=true >/dev/null
kc create ns "$NS" >/dev/null
kc -n "$NS" create deployment web --image=nginx:1.29 >/dev/null
kc -n "$NS" rollout status deployment web --timeout=180s >/dev/null
kc -n "$NS" expose deployment web --port=80 >/dev/null
kc -n "$NS" create ingress web --class=nginx --rule="accept.lab/*=web:80" >/dev/null
code=000
for _ in $(seq 1 30); do
  code=$(multipass exec cp1 -- curl -s -o /dev/null -w '%{http_code}' -m 3 -H 'Host: accept.lab' "http://localhost:$HTTP_NODEPORT/" || true)
  [ "$code" = 200 ] && break
  sleep 4
done
kc delete ns "$NS" --wait=false >/dev/null
[ "$code" = 200 ] && log "PASS ingress ($code)" || { log "FAIL ingress (http $code)"; exit 1; }

log "metrics-server (ckad-D3 3.3) — reported only; install it with Helm as in cka-D1-3-access.md 1.6"
kc -n kube-system get deploy metrics-server 2>/dev/null || echo "metrics-server not installed"
