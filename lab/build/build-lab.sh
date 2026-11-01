#!/usr/bin/env bash
# Rebuild the CKA lab: cp1 + w1 + w2 on BASE, snapshot lab-v<base minor>, kubeadm-upgrade to NEXT,
# snapshot lab-v<next minor>. w3 is handled by build-w3.sh.
# Runs on the lab HOST. Steps: lab/lab-kubeadm-3-nodos-tutorial.md + cka-D1.md §0.4.
#
#   CONFIRM=yes ./build-lab.sh                delete + relaunch the VMs (default; new MACs → new IPs,
#                                             ssh and /etc/hosts are re-pointed before any snapshot)
#   CONFIRM=yes MODE=inplace ./build-lab.sh   keep the VMs (and their IPs), wipe them, rebuild
#
# Versions are resolved at run time unless overridden: BASE / NEXT (newest patch in the v1.36 / v1.37
# apt repos), CALICO and YQ (latest GitHub release). etcdctl follows the etcd image the cluster runs.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

NODES="cp1 w1 w2"
MODE=${MODE:-fresh}
BASE=${BASE:-$(k8s_latest 1.36)}
NEXT=${NEXT:-$(k8s_latest 1.37)}
CALICO=${CALICO:-$(gh_latest projectcalico/calico)}
YQ=${YQ:-$(gh_latest mikefarah/yq)}
BASE_SNAP="lab-v$(echo "${BASE%.*}" | tr -d .)"
NEXT_SNAP="lab-v$(echo "${NEXT%.*}" | tr -d .)"
log "resolved: BASE $BASE · NEXT $NEXT · Calico $CALICO · yq $YQ · mode $MODE"
[ "${CONFIRM:-}" = yes ] || { echo "dry run — set CONFIRM=yes to destroy and rebuild $NODES"; exit 0; }

# ---------- 1. Clean slate ----------
log "IPs before: cp1=$(ip cp1) w1=$(ip w1) w2=$(ip w2) w3=$(ip w3)"
log "delete every snapshot of $NODES"
multipass stop $NODES >/dev/null   # a running VM locks its disk: snapshot delete fails
for n in $NODES; do
  for s in $(multipass list --snapshots --format csv | awk -F, -v n="$n" '$1==n{print $2}' | tac); do
    multipass delete --purge "$n.$s"
  done
done
if [ "$MODE" = fresh ]; then
  log "delete + relaunch VMs"
  multipass delete --purge $NODES 2>/dev/null || true
  multipass launch 24.04 --name cp1 --cpus 2 --memory 4G --disk 20G >/dev/null 2>&1 || true
  for n in w1 w2; do multipass launch 24.04 --name "$n" --cpus 2 --memory 3G --disk 20G >/dev/null 2>&1 || true; done
else
  log "wipe VMs in place"
  multipass start $NODES >/dev/null
  for n in $NODES; do
    wait_ssh "$n"
    multipass transfer wipe-node.sh "$n:/tmp/wipe-node.sh"
    multipass exec "$n" -- bash /tmp/wipe-node.sh
  done
  multipass restart $NODES >/dev/null
fi
for n in $NODES; do wait_ssh "$n"; [ -n "$(ip "$n")" ] || { echo "$n has no IP"; exit 1; }; done
CP_IP=$(ip cp1)
w3_ip_record
printf 'cp1=%s\nw1=%s\nw2=%s\nw3=%s\n' "$CP_IP" "$(ip w1)" "$(ip w2)" "$W3_IP" > "$IPS_FILE"
log "cp1=$CP_IP w1=$(ip w1) w2=$(ip w2) (recorded in $(basename "$IPS_FILE"))"

# ---------- 2. Node prep + cluster on BASE ----------
log "prep nodes for $BASE"
for n in $NODES; do multipass transfer prep-node.sh "$n:/home/ubuntu/prep-node.sh"; done
pids=()
for n in $NODES; do
  multipass exec "$n" -- env K8S_MINOR="v${BASE%.*}" K8S_VER="$BASE" bash /home/ubuntu/prep-node.sh > "prep-$n.log" 2>&1 &
  pids+=($!)
done
rc=0; for p in "${pids[@]}"; do wait "$p" || rc=1; done
tail -qn1 prep-*.log; [ $rc = 0 ] || { echo "node prep failed"; exit 1; }

log "kubeadm init v$BASE"
multipass exec cp1 -- sudo kubeadm init --kubernetes-version="v$BASE" \
  --apiserver-advertise-address="$CP_IP" --pod-network-cidr=10.244.0.0/16 --node-name=cp1 > kubeadm-init.log 2>&1
multipass exec cp1 -- bash -c 'mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config'

log "Calico $CALICO"
multipass exec cp1 -- kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/tigera-operator.yaml" >/dev/null
multipass exec cp1 -- bash -c "curl -fsSLO https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/custom-resources.yaml && sed -i 's#192.168.0.0/16#10.244.0.0/16#' custom-resources.yaml && grep -q 10.244.0.0/16 custom-resources.yaml"
# The operator registers its CRDs after it starts: retry until the Installation is accepted.
ok=0; for _ in $(seq 1 30); do multipass exec cp1 -- kubectl apply -f custom-resources.yaml >/dev/null 2>&1 && { ok=1; break; }; sleep 10; done
[ $ok = 1 ] || { echo "Calico Installation never accepted"; exit 1; }

log "join workers"
JOIN=$(multipass exec cp1 -- sudo kubeadm token create --print-join-command)
for n in w1 w2; do multipass exec "$n" -- sudo $JOIN > "join-$n.log" 2>&1; done
for n in w1 w2; do kc label node "$n" node-role.kubernetes.io/worker= --overwrite >/dev/null; done
wait_ready "$BASE"

log "exam-like shell + tools, ssh + /etc/hosts on the new IPs"
for n in $NODES; do node_tools "$n" "$YQ"; done
ssh_sync
hosts_sync $NODES
HELM=$(helm_tool)
ETCD=$(etcd_tools)
log "yq $YQ · etcdctl $ETCD · helm $HELM · ssh cp1->w1,w2 OK"

log "acceptance on $BASE"
multipass transfer acceptance.sh cp1:/tmp/acceptance.sh
multipass exec cp1 -- bash /tmp/acceptance.sh 2>&1 | grep -v "couldn't attach" | tee acceptance-$BASE.log
grep -q '^FAIL' acceptance-$BASE.log && { echo "acceptance failed on $BASE"; exit 1; }

snap "$BASE_SNAP" "kubeadm $BASE, Calico $CALICO, etcdctl $ETCD, helm $HELM, yq $YQ — upgrade source" $NODES

# ---------- 3. Upgrade to NEXT ----------
log "upgrade $BASE -> $NEXT"
multipass start $NODES >/dev/null
wait_ready "$BASE"
bash ./upgrade.sh "$NEXT"
wait_ready "$NEXT"
# Build-only: keep cri-tools on the same minor as the cluster (the drill itself never touches it).
for n in $NODES; do
  multipass exec "$n" -- bash -c 'V=$(apt-cache madison cri-tools | awk "!f{print \$3; f=1}"); sudo apt-mark unhold cri-tools >/dev/null; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --allow-change-held-packages cri-tools=$V >/dev/null; sudo apt-mark hold cri-tools >/dev/null'
done
ETCD=$(etcd_tools)
log "acceptance on $NEXT"
multipass transfer acceptance.sh cp1:/tmp/acceptance.sh
multipass exec cp1 -- bash /tmp/acceptance.sh 2>&1 | grep -v "couldn't attach" | tee acceptance-$NEXT.log
grep -q '^FAIL' acceptance-$NEXT.log && { echo "acceptance failed on $NEXT"; exit 1; }

snap "$NEXT_SNAP" "kubeadm $NEXT, Calico $CALICO, etcdctl $ETCD, helm $HELM, yq $YQ — default" $NODES
multipass list --snapshots
log "done — $NODES stopped"
