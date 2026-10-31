#!/usr/bin/env bash
# Return a cluster node to plain Ubuntu without recreating the VM (keeps its MAC, so its IP).
# Runs INSIDE the node. Removes everything prep-node.sh, kubeadm, Calico and node_tools() add.
set -uo pipefail
sudo kubeadm reset -f >/dev/null 2>&1
sudo systemctl stop kubelet containerd 2>/dev/null
sudo apt-mark unhold kubelet kubeadm kubectl cri-tools >/dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq kubelet kubeadm kubectl cri-tools kubernetes-cni containerd runc >/dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq --purge >/dev/null 2>&1
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet /etc/cni /opt/cni /var/lib/cni \
  /var/lib/calico /var/run/calico /var/log/calico /var/log/pods /var/log/containers \
  /var/lib/containerd /etc/containerd /run/containerd /etc/crictl.yaml \
  /etc/apt/sources.list.d/kubernetes.list /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
  /etc/modules-load.d/k8s.conf /etc/sysctl.d/k8s.conf \
  /usr/local/bin/yq /usr/local/bin/etcdctl /usr/local/bin/etcdutl /usr/local/bin/helm \
  /root/.kube ~/.kube ~/.cache/helm ~/.config/helm ~/.local/share/helm \
  ~/.ssh/config ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/known_hosts
# cp1's lab key on the workers; multipass's own key stays
sed -i '/ubuntu@cp1$/d' ~/.ssh/authorized_keys
sed -i '/# ---- CKA lab ----/,/# ---- end CKA lab ----/d' ~/.bashrc
sudo iptables -F; sudo iptables -t nat -F; sudo iptables -t mangle -F; sudo iptables -X
sudo nft flush ruleset 2>/dev/null
echo "$(hostname): wiped"
