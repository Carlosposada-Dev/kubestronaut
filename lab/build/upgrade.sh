#!/usr/bin/env bash
# kubeadm upgrade of cp1, w1, w2 to TARGET (one minor up), following the official procedure.
# Usage: upgrade.sh 1.37.2   — runs on the lab HOST; every Kubernetes command runs inside a VM.
# Idempotent: a node already on TARGET is skipped, so a failed run can simply be re-run.
set -euo pipefail
cd "$(dirname "$0")"
TARGET=$1
MINOR=v${TARGET%.*}

move_pkgs() {  # $1 = node, $2.. = packages to move to $TARGET
  local n=$1; shift
  multipass exec "$n" -- bash -s "$TARGET" "$MINOR" "$@" <<'EOF'
set -euo pipefail
TARGET=$1 MINOR=$2; shift 2
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${MINOR}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${MINOR}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update -qq
VER=$(apt-cache madison kubeadm | awk -v v="$TARGET" '$3 ~ "^"v"-" && !f {print $3; f=1}')
[ -n "$VER" ] || { echo "$TARGET not in repo"; exit 1; }
args=(); for p in "$@"; do args+=("$p=$VER"); done
sudo apt-mark unhold "$@" >/dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --allow-change-held-packages "${args[@]}" >/dev/null
sudo apt-mark hold "$@" >/dev/null
EOF
}
kc() { multipass exec cp1 -- kubectl "$@"; }
wait_api() {  # the apiserver static Pod restarts with the kubelet; wait until it answers again
  for _ in $(seq 1 36); do kc get --raw=/readyz >/dev/null 2>&1 && return 0; sleep 5; done
  echo "apiserver did not come back"; return 1
}
restart_kubelet() { multipass exec "$1" -- bash -c 'sudo systemctl daemon-reload && sudo systemctl restart kubelet'; wait_api; }
kubelet_ver() { kc get node "$1" -o jsonpath='{.status.nodeInfo.kubeletVersion}'; }

wait_api
if [ "$(kubelet_ver cp1)" = "v$TARGET" ]; then
  echo "-- cp1 already on $TARGET"
else
  echo "-- cp1: kubeadm $TARGET"
  move_pkgs cp1 kubeadm
  multipass exec cp1 -- sudo kubeadm upgrade apply "v$TARGET" -y > "upgrade-apply-$TARGET.log" 2>&1 \
    || grep -q "already" "upgrade-apply-$TARGET.log"
  grep -qE "SUCCESS|already" "upgrade-apply-$TARGET.log" || { tail -20 "upgrade-apply-$TARGET.log"; exit 1; }
  echo "-- cp1: kubelet + kubectl"
  kc drain cp1 --ignore-daemonsets --delete-emptydir-data >/dev/null
  move_pkgs cp1 kubelet kubectl
  restart_kubelet cp1
fi
kc uncordon cp1 >/dev/null

for n in w1 w2; do
  if [ "$(kubelet_ver "$n")" = "v$TARGET" ]; then echo "-- $n already on $TARGET"; kc uncordon "$n" >/dev/null; continue; fi
  echo "-- $n"
  move_pkgs "$n" kubeadm
  multipass exec "$n" -- sudo kubeadm upgrade node > "upgrade-node-$n.log" 2>&1
  kc drain "$n" --ignore-daemonsets --delete-emptydir-data >/dev/null
  move_pkgs "$n" kubelet kubectl
  restart_kubelet "$n"
  kc uncordon "$n" >/dev/null
done
