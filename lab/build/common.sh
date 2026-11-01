# Shared helpers for the lab build scripts. Sourced, never executed. Runs on the lab HOST.

log() { echo "== [$(date +%H:%M:%S)] $*"; }
ip()  { multipass list --format csv | awk -F, -v n="$1" '$1==n{print $3}'; }
kc()  { multipass exec cp1 -- kubectl "$@"; }

# Newest kubeadm patch in pkgs.k8s.io/core:/stable:/v<minor> — what an unpinned apt-get install picks.
k8s_latest() {
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$1/deb/Packages" \
    | awk '/^Package: kubeadm$/{p=1;next} /^Package:/{p=0} p&&/^Version:/{print $2}' \
    | sort -V | tail -1 | cut -d- -f1
}
gh_latest() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -oP '"tag_name": "\K[^"]+'; }

wait_ssh() {  # $1 = node; a fresh boot answers exec a few seconds after "Running"
  for _ in $(seq 1 60); do multipass exec "$1" -- true >/dev/null 2>&1 && return 0; sleep 5; done
  echo "$1 not reachable"; return 1
}
wait_ready() {  # $1 = expected kubelet version (x.y.z); all three nodes Ready on it
  for _ in $(seq 1 60); do
    [ "$(kc get nodes --no-headers 2>/dev/null | awk -v v="v$1" '$2=="Ready" && $5==v' | wc -l)" = 3 ] && return 0
    sleep 10
  done
  kc get nodes; return 1
}

# Exam-like shell: kubectl completion + `k` alias + completion for k. PS1 colour is lab scaffolding.
SHELL_BLOCK='
# ---- CKA lab ----
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
export PS1='"'"'\[\e[1;31m\]\h\[\e[0m\]:\w\$ '"'"'
# ---- end CKA lab ----'

node_tools() {  # $1 = node, $2 = yq tag. Idempotent.
  multipass exec "$1" -- bash -c "grep -q '# ---- CKA lab ----' ~/.bashrc || printf '%s\n' \"\$1\" >> ~/.bashrc" _ "$SHELL_BLOCK"
  multipass exec "$1" -- bash -c "yq --version 2>/dev/null | grep -q ' $2\$' || { sudo curl -fsSL -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/$2/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq; }"
}

etcd_tools() {  # etcdctl/etcdutl matching the etcd image the cluster runs (read from the static Pod)
  local v
  v=$(kc -n kube-system get pod etcd-cp1 -o jsonpath='{.spec.containers[0].image}' | sed 's/.*://; s/-0$//')
  multipass exec cp1 -- bash -c "etcdctl version 2>/dev/null | grep -q 'etcdctl version: $v\$' || {
      curl -fsSL -o /tmp/etcd.tgz https://github.com/etcd-io/etcd/releases/download/v$v/etcd-v$v-linux-amd64.tar.gz \
      && tar xzf /tmp/etcd.tgz -C /tmp \
      && sudo mv /tmp/etcd-v$v-linux-amd64/etcdctl /tmp/etcd-v$v-linux-amd64/etcdutl /usr/local/bin/ \
      && rm -rf /tmp/etcd.tgz /tmp/etcd-v$v-linux-amd64; }" >&2
  echo "$v"
}

helm_tool() {  # helm 3 on cp1, installed once
  multipass exec cp1 -- bash -c 'command -v helm >/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1'
  multipass exec cp1 -- helm version --short | cut -d+ -f1
}

IPS_FILE=${IPS_FILE:-$(dirname "${BASH_SOURCE[0]}")/lab-ips.env}   # per machine, gitignored; written by build-lab.sh
# w3 is never recreated, so its lease (and IP) is stable on each lab host — but differs between hosts.
# Learned once per machine by w3_ip_record and kept in lab-ips.env; never hardcoded here.
W3_IP=${W3_IP:-$(grep -s '^w3=' "$IPS_FILE" | cut -d= -f2 || true)}

w3_ip_record() {  # make sure W3_IP is known on this machine; boots w3 briefly if it is stopped
  [[ $W3_IP =~ ^[0-9.]+$ ]] && return 0
  local state; state=$(multipass list --format csv | awk -F, '$1=="w3"{print $2}')
  [ "$state" = Running ] || { multipass start w3 >/dev/null; wait_ssh w3; }
  W3_IP=$(ip w3)
  [ "$state" = Running ] || multipass stop w3 >/dev/null
  [[ $W3_IP =~ ^[0-9.]+$ ]] || { echo "cannot learn w3's IP"; return 1; }
  { grep -sv '^w3=' "$IPS_FILE" || true; echo "w3=$W3_IP"; } > "$IPS_FILE.tmp" && mv "$IPS_FILE.tmp" "$IPS_FILE"
  log "w3=$W3_IP recorded in $(basename "$IPS_FILE")"
}

node_ip() {  # live IP, or the one recorded at build time when the VM is stopped (stopped VMs show none)
  local v; v=$(ip "$1")
  if [[ ! $v =~ ^[0-9.]+$ ]]; then
    [ "$1" = w3 ] && v=$W3_IP || v=$(grep -s "^$1=" "$IPS_FILE" | cut -d= -f2)
  fi
  echo "$v"
}

hosts_sync() {  # $@ = nodes to update. Lab names → current IPs, in /etc/hosts AND the cloud-init
                # template (cloud-init rewrites /etc/hosts from it on every boot, i.e. after a restore).
  local block n c1 c2 c3
  c1=$(node_ip cp1); c2=$(node_ip w1); c3=$(node_ip w2)
  for v in "$c1" "$c2" "$c3"; do [[ $v =~ ^[0-9.]+$ ]] || { echo "hosts_sync: missing IP (cp1=$c1 w1=$c2 w2=$c3)"; return 1; }; done
  block=$(printf '# ---- CKA lab hosts ----\n%s cp1\n%s w1\n%s w2\n%s w3\n# ---- end CKA lab hosts ----' \
    "$c1" "$c2" "$c3" "$W3_IP")
  for n in "$@"; do
    multipass exec "$n" -- sudo bash -c '
      for f in /etc/cloud/templates/hosts.debian.tmpl /etc/hosts; do
        sed -i "/# ---- CKA lab hosts ----/,/# ---- end CKA lab hosts ----/d" "$f"
        printf "%s\n" "$1" >> "$f"
      done' _ "$block"
  done
}

ssh_sync() {  # cp1 → w1/w2 passwordless ssh, one-way like the exam. Idempotent; re-run after IP changes.
  local pub n
  multipass exec cp1 -- bash -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519'
  pub=$(multipass exec cp1 -- cat /home/ubuntu/.ssh/id_ed25519.pub)
  for n in w1 w2; do
    multipass exec "$n" -- bash -c "mkdir -p ~/.ssh && { grep -qF '$pub' ~/.ssh/authorized_keys || echo '$pub' >> ~/.ssh/authorized_keys; } && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
  done
  printf 'Host w1\n  HostName %s\n  User ubuntu\n  StrictHostKeyChecking no\nHost w2\n  HostName %s\n  User ubuntu\n  StrictHostKeyChecking no\n' "$(ip w1)" "$(ip w2)" \
    | multipass exec cp1 -- bash -c 'cat > ~/.ssh/config && chmod 600 ~/.ssh/config && rm -f ~/.ssh/known_hosts'
  multipass exec cp1 -- bash -c 'ssh w1 hostname >/dev/null 2>&1 && ssh w2 hostname >/dev/null 2>&1'
}

clean_node() {  # nothing a learner should find in a fresh snapshot
  multipass exec "$1" -- bash -c 'rm -f ~/.vimrc ~/.bash_history ~/.lesshst ~/.viminfo ~/custom-resources.yaml ~/prep-node.sh ~/*.log /tmp/acceptance.sh /tmp/audit.sh; sudo rm -f /root/.bash_history /root/.viminfo'
}

snap() {  # $1 = snapshot name, $2 = comment, $3.. = nodes (stopped, together). Replaces a same-named snapshot.
  local name=$1 comment=$2; shift 2
  for n in "$@"; do clean_node "$n"; done
  multipass stop "$@" >/dev/null
  for n in "$@"; do
    multipass list --snapshots --format csv | awk -F, -v n="$n" -v s="$name" '$1==n && $2==s{f=1} END{exit !f}' \
      && multipass delete --purge "$n.$name"
    multipass snapshot "$n" --name "$name" --comment "$comment" >/dev/null
  done
  log "snapshot $name taken on $*"
}

audit() {  # $1 = node — one "tool value" line per check, from audit.sh inside the node
  multipass transfer audit.sh "$1:/tmp/audit.sh"
  multipass exec "$1" -- bash /tmp/audit.sh
}
