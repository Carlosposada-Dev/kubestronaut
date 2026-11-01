#!/usr/bin/env bash
# Resolve the versions a fresh build would use today. Read-only; runs on the lab HOST.
set -euo pipefail

# Newest kubeadm in pkgs.k8s.io/core:/stable:/v<minor> — what an unpinned apt-get install picks.
k8s_latest() {
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$1/deb/Packages" \
    | awk '/^Package: kubeadm$/{p=1;next} /^Package:/{p=0} p&&/^Version:/{print $2}' \
    | sort -V | tail -1
}
gh_latest() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -oP '"tag_name": "\K[^"]+'; }

BASE_PKG=$(k8s_latest 1.36)
NEXT_PKG=$(k8s_latest 1.37)
echo "BASE   kubeadm ${BASE_PKG%%-*}  (apt ${BASE_PKG})"
echo "NEXT   kubeadm ${NEXT_PKG%%-*}  (apt ${NEXT_PKG})"
echo "CALICO $(gh_latest projectcalico/calico)"
echo "YQ     $(gh_latest mikefarah/yq)"
echo "HELM3  $(curl -fsSL https://get.helm.sh/helm3-latest-version 2>/dev/null || echo '?')"
