#!/usr/bin/env bash
# CKAD add-ons on top of lab-v<n>: podman on cp1 (ckad-D1 1.1), an Ingress controller (ckad-D5 5.3) and
# metrics-server (ckad-D3). SNAPSHOT=yes freezes the result as ckad-v<n> (cp1 w1 w2). First run 21 Nov 2026, desktop.
# Runs on the lab HOST, as the normal user. Idempotent — safe to re-run after a snapshot restore.
set -euo pipefail
# Non-interactive: with an inherited stdin, the SNAPSHOT=yes restart stopped silently with exit 0 (21 Nov, desktop).
exec < /dev/null
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
kc delete ns "$NS" --wait=true >/dev/null   # wait: a snapshot taken right after must not hold a Terminating ns
[ "$code" = 200 ] && log "PASS ingress ($code)" || { log "FAIL ingress (http $code)"; exit 1; }

log "metrics-server via Helm in kube-system (ckad-D3: kubectl top)"
# Quoted list: unquoted {…} is brace-expanded by bash (measured 8 Nov, cka-D1-3-access.md 1.6).
multipass exec cp1 -- helm upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server/ \
  --namespace kube-system \
  --set 'args={--kubelet-insecure-tls}' \
  --wait --timeout 5m
ok=0
for _ in $(seq 1 30); do
  kc top nodes >/dev/null 2>&1 && { ok=1; break; }
  sleep 5
done
kc top nodes || true
[ "$ok" = 1 ] && log "PASS metrics (kubectl top nodes)" || { log "FAIL metrics: kubectl top nodes never answered"; exit 1; }

# SNAPSHOT=yes: freeze the result as ckad-v<minor>, a child of lab-v<minor>. Stops cp1 w1 w2, then restarts them.
if [ "${SNAPSHOT:-no}" = yes ]; then
  minor=$(kc get node cp1 -o jsonpath='{.status.nodeInfo.kubeletVersion}' | sed -E 's/^v1\.([0-9]+)\..*/\1/')
  snap "ckad-v1$minor" "lab-v1$minor + CKAD add-ons: podman (cp1), ingress-nginx NodePort $HTTP_NODEPORT, metrics-server" cp1 w1 w2
  # The multipass socket can refuse requests for ~10 s right after a snapshot (plan.md §8.1 traps): retry.
  for _ in 1 2 3 4 5 6; do multipass start cp1 w1 w2 && break; sleep 10; done
  for n in cp1 w1 w2; do wait_ssh "$n"; done
  v=$(multipass exec cp1 -- kubelet --version | awk '{print $2}' | sed 's/^v//')
  wait_ready "$v"
  log "ckad-v1$minor ready"
fi
