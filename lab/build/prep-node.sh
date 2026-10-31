#!/usr/bin/env bash
# Node prep from lab/lab-kubeadm-3-nodos-tutorial.md (Phase 2), patch version pinned. Runs INSIDE a node.
# Usage: K8S_MINOR=v1.37 K8S_VER=1.37.2 bash prep-node.sh   — idempotent, safe to re-run.
set -euo pipefail
: "${K8S_MINOR:?set K8S_MINOR, e.g. v1.37}" "${K8S_VER:?set K8S_VER, e.g. 1.37.2}"

# 1. Swap off, now and after reboot (comment the swap line once)
sudo swapoff -a
sudo sed -i 's/^\([^#].*\sswap\s.*\)$/#\1/' /etc/fstab

# 2. Modules and sysctl, persistent
printf 'overlay\nbr_netfilter\n' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
sudo modprobe overlay && sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null

# 3. containerd with the systemd cgroup driver, plus the exam-host toolset
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  containerd apt-transport-https ca-certificates curl wget gpg \
  jq vim tmux bash-completion man-db >/dev/null
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/^\(\s*\)SystemdCgroup = false/\1SystemdCgroup = true/' /etc/containerd/config.toml
[ "$(grep -c 'SystemdCgroup = true' /etc/containerd/config.toml)" = 1 ] || { echo "SystemdCgroup not set"; exit 1; }
sudo systemctl restart containerd && sudo systemctl enable containerd >/dev/null 2>&1

# 4. crictl pointed at the containerd socket
cat <<EOF | sudo tee /etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

# 5. Kubernetes packages, pinned and held (cri-tools: newest in the same minor repo)
sudo mkdir -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt-get update -qq
PKG_VER=$(apt-cache madison kubeadm | awk -v v="$K8S_VER" '$3 ~ "^"v"-" && !f {print $3; f=1}')
CRI_VER=$(apt-cache madison cri-tools | awk '!f {print $3; f=1}')
[ -n "$PKG_VER" ] || { echo "kubeadm $K8S_VER not found in repo"; exit 1; }
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --allow-change-held-packages \
  kubelet="$PKG_VER" kubeadm="$PKG_VER" kubectl="$PKG_VER" cri-tools="$CRI_VER" >/dev/null
sudo apt-mark hold kubelet kubeadm kubectl cri-tools >/dev/null
echo "$(hostname): prep done, kubeadm $(kubeadm version -o short), cri-tools ${CRI_VER%%-*}"
