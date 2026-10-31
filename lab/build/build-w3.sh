#!/usr/bin/env bash
# w3 snapshot prep<minor>: cleanw3 + node prep pinned to NEXT (same patch as lab-v<next>), tools, NOT joined.
# Runs on the HOST (WSL). cleanw3 itself is never modified.
#   CONFIRM=yes ./build-w3.sh     (restoring cleanw3 discards w3's current state)
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

NEXT=${NEXT:-$(k8s_latest 1.37)}
YQ=${YQ:-$(gh_latest mikefarah/yq)}
SNAP="prep$(echo "${NEXT%.*}" | tr -d .)"
log "resolved: NEXT $NEXT · yq $YQ → w3.$SNAP"
[ "${CONFIRM:-}" = yes ] || { echo "dry run — set CONFIRM=yes to restore w3 to cleanw3"; exit 0; }

log "restore w3 to cleanw3"
multipass stop w3 >/dev/null
multipass restore w3.cleanw3 --destructive >/dev/null
multipass start w3 >/dev/null
wait_ssh w3

log "node prep $NEXT on w3"
multipass transfer prep-node.sh w3:/home/ubuntu/prep-node.sh
multipass exec w3 -- env K8S_MINOR="v${NEXT%.*}" K8S_VER="$NEXT" bash /home/ubuntu/prep-node.sh
node_tools w3 "$YQ"
hosts_sync w3        # names of the current cp1/w1/w2, for join drills
[ "$(ip w3)" = "$W3_IP" ] || { echo "w3 IP changed: $(ip w3) (expected $W3_IP)"; exit 1; }

# Not joined, no CNI leftovers
multipass exec w3 -- bash -c '[ ! -e /etc/kubernetes/kubelet.conf ] && [ -z "$(ls -A /etc/cni/net.d 2>/dev/null)" ]' \
  || { echo "w3 is joined or has CNI config"; exit 1; }

snap "$SNAP" "node prep only: kubeadm/kubelet/kubectl $NEXT held, cri-tools, containerd SystemdCgroup, yq $YQ, k alias — not joined" w3
multipass list --snapshots
