---
domain: D1 — Cluster Architecture, Installation & Configuration
group: 1 — Install & Extend
bullets: [1.2, 1.3, 1.7]
exams: [CKA]
index: cka-D1.md
theory: notes_01, notes_04, notes_05, notes_06
status: draft
revision: 2026-10-30 (r6 — 1.2 card: tee pattern, vim :s, version pin + --allow-downgrades, lsmod lab-only; cgroup paragraph from v1.37 docs; 3 traps) · r5 2026-09-26 ( 1.3 CNI task + Pod CIDR ×3; 1.7 crictl method + .deb CRI; §9 sims A/B/C; stale CNI config; cleanw3) · r4 2026-09-26 (modules step CNI-dependent; bridge sysctls conditional) · r2 2026-09-23 (Template C) · r1 2026-09-14
---

# D1 · Group 1 — Install & Extend (bullets 1.2, 1.3, 1.7)

> Index, boot block, execution locations, scaffolding, drill table and scoreboard:
> **`cka-D1.md`**. Targets live in `cka-D1.md §7`; the header line of each numeral
> only repeats them.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
`[DOC]` copy from kubernetes.io · `[MEM]` type from memory (not in the allowed docs)
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.2 · 1.3 · 1.7

---

## §W3 🧪 The disposable node

**Runs on: HOST.** Scaffolding, never timed. **Never on cp1/w1/w2**: building a
cluster means destroying one. Everything in this file that installs, resets or
runs `init` happens on a fourth VM, `w3` (`10.167.152.248`).

```bash
# ▶▶ HOST — reset w3 to a bare Ubuntu before any 1.2 run
multipass stop w3 && multipass restore w3.cleanw3 --destructive && multipass start w3
multipass shell w3
```

**State of w3 after 26 Sep:** a single-node Calico cluster (`172.20.0.0/16`) from
simulation B. Harmless — but restore `w3.cleanw3` before the next 1.2 run, and
`kubeadm reset` + reboot (§9 sim B setup) before the next CNI run.

| Exercise | Bullet | Status | What it proves |
|---|---|---|---|
| **A.** Node prep, card closed, docs only for `[DOC]` | 1.2 | 🎯 A1 9:33 (26 Sep, verify consulted) | You know why each step exists |
| **B.** Join w3 with a fresh token | 1.3 | 🎯 0:56 (26 Sep) | Token lifecycle |
| **C.** Decommission w3 | 1.3 / 1.4c | 🎯 < 3:00 (26 Sep) | Node object vs machine state |
| **D.** CNI install on a cluster with none (§9 sim B) | 1.3 / 1.7 | 🎯 **3:24 blind (26 Sep)** | The reported CNI task |
| **E.** API server down, diagnosed blind (§9 sim A) | 1.7 / D5 | 🎯 solved, untimed (26 Sep) | `crictl` when `kubectl` is blind |

`kubeadm init` itself stays 📚 for the exam (the exam hands you an existing
cluster), but it is the **scaffolding** that builds the no-CNI cluster sims B needs.

---

## 1.2 Prepare underlying infrastructure ⚙️

**Runs on: the node being prepared (w3).** · **Theory →** notes_01 §1.1–1.3 ·
**Docs →** `container runtimes`, `installing kubeadm` · **Target: 10:00**

### The shape

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | Swap off, now + persistent | The kubelet's memory accounting (requests, limits, OOM, eviction) assumes memory = RAM; by default it refuses to start with swap | 🎯 |
| 2 | Load `overlay` + `br_netfilter`, now + persistent | Insurance for an unknown CNI: `br_netfilter` lets bridged traffic reach iptables (and turns the bridge sysctls on, default `1`); `overlay` backs containerd's snapshotter. Not in kubernetes.io docs | 🎯 |
| 3 | `ip_forward=1` (+ the two bridge sysctls **only if the task lists them**) | The node must route between Pods and the outside. The bridge switches matter only for CNIs that use a Linux bridge | 🎯 |
| 4 | containerd with `SystemdCgroup = true` | Chooses **who manages** cgroups (systemd vs direct cgroupfs writes). kubelet and runtime must use the same manager; systemd is PID 1 on Ubuntu | 🎯 |
| 5 | kubelet, kubeadm, kubectl from `pkgs.k8s.io`, held | Ubuntu does not ship them; one repo per minor; `hold` protects version skew | 🎯 |

### The whiteboard

**Every step has two halves.** Doing only one is the most common way to "pass now,
fail after reboot":

| | Now (kernel memory, lost at reboot) | Persistent (read at boot) |
|---|---|---|
| swap | `swapoff -a` | comment the line in `/etc/fstab` |
| module | `modprobe br_netfilter` | `/etc/modules-load.d/k8s.conf` — module **names** |
| sysctl | `sysctl --system` | `/etc/sysctl.d/k8s.conf` — the **values** |

At boot systemd loads modules before it applies sysctls, so the order holds by itself.

**Are the two bridge sysctls needed? — resolved 26 Sep.** Mostly not, and that is
why the docs dropped them:

- **kubeadm stopped checking them in v1.30** (kubernetes PR #123464): not every
  network implementation needs them, and the **network plugin** is responsible for
  setting them if it does.
- **Who needs them:** kube-proxy in iptables mode, **when Pods hang off a Linux
  bridge** (flannel's `cni0`, the `bridge` plugin). **Calico does not use a Linux
  bridge** — veth + per-Pod routes — so this lab does not need them.
- **Loading `br_netfilter` already sets both to `1`** (kernel default). Measured
  23 Sep: underscored keys were never applied and `sysctl` still showed `1`.

**The modules step has no kubernetes.io source either.** The current *Network
Plugins* page lists only loopback, hostPort and traffic shaping; *Container
Runtimes* only says some network implementations "might expect kernel modules to be
loaded" and sends you to the CNI's own docs. The explicit block lived in
*Installing kubeadm* until ~v1.29.

| Module | Who needs it | In this lab |
|---|---|---|
| `overlay` | containerd's default `overlayfs` snapshotter (`snapshotter = 'overlayfs'` in `config.toml`) | containerd's unit may load it itself — check `systemctl cat containerd \| grep modprobe` |
| `br_netfilter` | kube-proxy iptables mode **with a bridge-based CNI** (flannel, `bridge` plugin). Missing → Services to a same-node endpoint fail, typically DNS when CoreDNS shares the node. kubeadm ≥ 1.30 no longer warns | Calico — not required |

**Rule:** the step is **insurance**, not a Calico requirement. Task says "prepare the
node so networking functions" and the CNI is unknown → do it (seconds, no downside).
Task lists exact items → do exactly those. Bridge sysctl lines only if named or if
`sysctl` reads `0`; the verify keeps all three keys so a `0` cannot slip past.

**What the docs give you and what they don't.** The allowed docs are kubernetes.io.
The containerd install guide is on GitHub (not allowed), and the module names were
removed from the current docs. Memory load: **2 words** (`overlay`, `br_netfilter`)
plus the 3 containerd lines — and the two bridge key names, spelled with
**hyphens**, only for when a task asks for them. Everything else is copied.
The docs page shows *its* Kubernetes version: the minor in the `.list` URL must match
the cluster (`kubeadm version` on an existing node).

```bash
# ▶▶ w3 ─ 1. SWAP [MEM] — look first, act only if needed
swapon --show; grep swap /etc/fstab        # both empty → skip (multipass cloud images have none)
# else: sudo swapoff -a && sudo vim /etc/fstab   → '#' before the swap line

# ▶▶ w3 ─ 2. MODULES [MEM]
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter

# ▶▶ w3 ─ 3. SYSCTL [DOC]
# DOC: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
#      Ctrl+F "Enable IPv4 packet forwarding" → copy the block as-is
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
#   task lists the bridge keys (or they read 0)? add inside the heredoc, HYPHENS:
#   net.bridge.bridge-nf-call-iptables = 1
#   net.bridge.bridge-nf-call-ip6tables = 1
sudo sysctl --system | grep -E 'forward|bridge'   # 🔍 every key you wrote is listed

# ▶▶ w3 ─ 4. CONTAINERD [MEM]
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
#   the docs write "> config.toml" — without root that is Permission denied
sudo vim +/SystemdCgroup /etc/containerd/config.toml   # cursor lands on the line: false → true, :wq
sudo systemctl restart containerd

# ▶▶ w3 ─ 5. PACKAGES [DOC — steps 1–4 verbatim]
# DOC: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
#      Ctrl+F "Installing kubeadm, kubelet and kubectl" → Debian-based distributions
#      Only edit: the minor in the .list URL. The signing key is shared by every minor.
```

```bash
# ▶▶ w3 ─ 🔍 VERIFY [MEM] — the clock stops only when all are green
swapon --show                                               # nothing
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables   # all 1
cat /etc/sysctl.d/k8s.conf                                  # the FILE is right, not only the live value
lsmod | grep -E 'overlay|br_netfilter'                      # 🧪 lab only: the bridge keys reading 1 above already prove br_netfilter; modprobe is silent on success
grep SystemdCgroup /etc/containerd/config.toml              # true
systemctl is-active containerd                              # active
apt-cache madison kubeadm | head -1                         # repo reachable, right minor
apt-mark showhold                                           # kubeadm kubectl kubelet
```

**After step 5 the kubelet restarts in a loop (`activating (auto-restart)`). That is
normal.** `/var/lib/kubelet/config.yaml` does not exist until `kubeadm init` or
`join` writes it. Do not debug it.

**The task wording decides the sysctl set.** If it lists parameters, set exactly
those, persistently in `/etc/sysctl.d/`. If it only says "prepare the node":
`ip_forward` + the module; the bridge keys follow from the module.

**Classify the symptom before hunting the cause.** Won't start → swap. Pod starts
and dies → cgroups. Pod lives but can't talk → `ip_forward` / `br_netfilter`. A
network fault never kills a container.

**cgroup driver on v1.37 + containerd 2.x — resolved from the docs 30 Oct.**
`SystemdCgroup = true` tells containerd (through `runc`) to **delegate** cgroup
management to systemd. *Container Runtimes* (v1.37): with `KubeletCgroupDriverFromCRI`
and a runtime that supports the `RuntimeConfig` CRI RPC (containerd 2.x does), the
kubelet **detects the driver from the runtime and ignores its own `cgroupDriver`**.
So `SystemdCgroup = false` raises no error: kubelet and containerd both use
`cgroupfs`, next to systemd managing the same tree — two managers, unstable under
resource pressure, invisible until then. The classic "Pods start, then die" symptom
belongs to containerd 1.x, whose fallback to the kubelet flag is dropped in v1.38.
Still worth a break/fix after a join, to see what the logs show:

```bash
# ▶▶ w3 — after join
sudo grep cgroupDriver /var/lib/kubelet/config.yaml       # what kubeadm configured
sudo journalctl -u kubelet | grep -i 'cgroup driver'      # what the kubelet actually used
```

Measured 23 Sep: Ubuntu 24.04's own `containerd` package is **2.2.1** (with `runc`
1.3.4) — the same runtime as cp1/w1/w2. The `kubelet` package pulls in
`kubernetes-cni`, which fills `/opt/cni/bin/` (→ 1.7).

### Command card — 1.2
```
look     swapon --show ; grep swap /etc/fstab  → empty = skip, else swapoff -a + vim fstab
modules  [MEM] heredoc | sudo tee /etc/modules-load.d/k8s.conf (overlay, br_netfilter) → modprobe both
sysctl   [DOC] ip_forward heredoc | sudo tee /etc/sysctl.d/k8s.conf (+ bridge keys only if asked) → sysctl --system
runtime  [MEM] apt-get install -y containerd → mkdir -p /etc/containerd
config   containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
edit     vim +/SystemdCgroup → :s/false/true → :wq → systemctl restart containerd
repo     [DOC] Installing kubeadm steps 1–3 — minor in .list = cluster minor (kubeadm version -o short)
install  apt-get install -y kubelet kubeadm kubectl (pin =X.Y.Z-1.1; older than installed → --allow-downgrades) → apt-mark hold
verify   swapon · sysctl ×3 + cat file · grep SystemdCgroup · is-active · madison · showhold
```

### Traps

| Error | Cause |
|---|---|
| File empty after `sudo tee FILE` + `^C` | `tee` truncates on open; `^C` undoes nothing. Always `… \| sudo tee FILE` |
| `containerd default` hangs on `boltdb` | Starts a second daemon. The command is `containerd config default` — it only prints, never needs root |
| `bridge_nf_call_iptables` in the file, yet `sysctl` shows `= 1` | Underscores never applied; `1` is the default once `br_netfilter` loads |
| `grep swwap /etc/fstab` empty → acted anyway | A typo'd check proves nothing — re-run it correctly before acting |
| `cannot stat /proc/sys/net/bridge/…` | Module not loaded — `modprobe` before `sysctl --system` |
| `sed` "succeeds", `grep` empty | A `sed` that matches nothing is silent — edit config lines in vim |
| Works now, broken after reboot | Only the "now" half was done (or only the persistent one) |
| `Unable to locate package kubelet` | `.list` empty or wrong minor — `cat` it before retrying |
| `> config.toml: Permission denied` | Redirection runs as you, not root → `\| sudo tee` |
| kubelet `activating (auto-restart)` | Normal until `init`/`join` writes its config |
| Same failing command run 3× | It fails identically. Look (`cat`, `grep`, the error) or change something first |
| `grep 'overlay\|br_netfilter'` empty although both are loaded | Basic grep reads `\|` literally — alternation needs `grep -E` |
| Pinned `=1.37.1-1.1`, version stays 1.37.2 | Older than installed = a downgrade: `E: Packages were downgraded and -y was used without --allow-downgrades`. Add `--allow-downgrades` (held → `unhold` first, or `--allow-change-held-packages`), then `hold` again |
| "It didn't work", then `clear` | The answer was the `E:` line. Read it before clearing; if it is gone, re-run and read it |

⚠️ **EKS:** none of this exists. AMI + bootstrap script + kubelet config are AWS's;
the kubelet version is tied to the AMI — no repo, no `hold`, upgrade = new AMI or
node group. Completely invisible in the day job.

---

## 1.3 Create and manage clusters using kubeadm ⚙️

**Runs on: cp1 for tokens; the joining node for `join`; w3 for `init`.** ·
**Theory →** notes_01 §1.1, §2.1 · **Docs →** `kubeadm init`, `kubeadm join`,
`creating a cluster with kubeadm` · **Target: join 3:00 · decommission 5:00 · CNI install 6:00**

### The shape

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | `kubeadm init` | PKI, static Pod manifests, control plane, `admin.conf`, a join command valid 24 h. **Installs no CNI** | 📚 (🧪 builds sim B) |
| 2 | Copy `admin.conf` → `~/.kube/config` | kubectl as a normal user | 📚 |
| 3 | Find the cluster's Pod CIDR | The CNI must use the same range | 🎯 |
| 4 | Install the CNI (operator + `Installation` CR) | Until a CNI config exists: `NotReady`, CoreDNS `Pending` | 🎯 🔍 |
| 5 | `kubeadm token create --print-join-command` | Tokens expire in 24 h — mint, never dig | 🎯 |
| 6 | `kubeadm join` on the new node | The CNI DaemonSet then lands on it | 🎯 |
| 7 | Decommission: drain → delete → `kubeadm reset` → `rm -rf /etc/cni/net.d` | API object and machine state are two different things | 🎯 |

PKI and static Pods are created here but manipulated by hand in
`cka-D1-2-lifecycle.md` — that is their home.

### The whiteboard

**`init` — three values change per machine.**

```bash
# ▶▶ w3 🧪 — builds the cluster for sim B
sudo kubeadm init --pod-network-cidr=<cidr> --apiserver-advertise-address=<THIS node's IP> --node-name=<name> | tee kubeadm-init.log
```

- `--pod-network-cidr` — the Pod range. The controller-manager receives it as
  `--cluster-cidr` and hands each node a `/24` slice (`spec.podCIDR`) → a `/16`
  holds 256 nodes. Must not overlap the node network or the Service CIDR (`10.96.0.0/12`).
- `--apiserver-advertise-address` — the IP of **the node running init**. Copying
  cp1's `.47` onto w3 is the classic slip.
- **Do not memorise the kubeconfig block**: `init` prints it (`mkdir -p $HOME/.kube …
  cp -i … chown …`) together with the full `kubeadm join` line. That is what
  `| tee` is for.
- Single-node cluster = control-plane taint: Calico and CoreDNS tolerate it, your
  test Pods do not → `kubectl taint nodes <n> node-role.kubernetes.io/control-plane-`.

**The Pod CIDR of a cluster you did not build — three places, measured 26 Sep:**

```bash
kubectl -n kube-system get pod -l component=kube-controller-manager -o yaml | grep cluster-cidr   # --cluster-cidr=… (fastest)
kubectl -n kube-system get cm kubeadm-config -o yaml | grep podSubnet                              # podSubnet: …
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'; echo                                     # per-node /24 slices
```

⚠️ `kubectl describe node` shows **`PodCIDR: x.x.0.0/24` — the node's slice, not
the cluster range.** Putting that `/24` in Calico's pool is wrong. Proof it matters:
Calico's VXLAN tunnel address on w3 was `10.50.193.192`, outside the node's
`10.50.0.0/24` — Calico IPAM carves its own `/26` blocks from the **whole pool**
and ignores `spec.podCIDR`.

**The CNI task — the shape the exam uses** (reported repeatedly since Feb 2025):
choose between Flannel and Calico → the one that **enforces NetworkPolicies** =
**Calico**. Flannel does not enforce them. (Both use VXLAN here — encapsulation is
not the differentiator; the policy engine is.) The task gives **one** URL: the
operator's. Everything else is derived.

```
given:   https://raw.githubusercontent.com/projectcalico/calico/<ver>/manifests/tigera-operator.yaml
you:     https://raw.githubusercontent.com/projectcalico/calico/<ver>/manifests/custom-resources.yaml
```

Paste the given URL, replace the file name. **No URL is ever memorised** — only the
file name `custom-resources.yaml` and the field `cidr`.

```bash
# ▶▶ the node the task names
kubectl -n kube-system get pod -l component=kube-controller-manager -o yaml | grep cluster-cidr
kubectl create -f <operator URL from the task>
curl -sLO <same directory>/custom-resources.yaml
grep -n cidr custom-resources.yaml            # 🔍 the default: 192.168.0.0/16
vim custom-resources.yaml                      # cidr: <the cluster's value>
grep -n cidr custom-resources.yaml            # 🔍 changed
kubectl create -f custom-resources.yaml
kubectl get tigerastatus                       # 🔍 calico AVAILABLE True
kubectl get nodes; kubectl -n kube-system get pods   # 🔍 Ready · coredns Running
```

- **`create`, never `apply`**: the `Installation` CRD is too large for the
  `last-applied-configuration` annotation — `apply` fails with *annotations: Too long*.
- `custom-resources.yaml` holds four objects in v3.32: `Installation default`
  (the field: `spec.calicoNetwork.ipPools[].cidr`), `APIServer`, `Goldmane`, `Whisker`.
- `no matches for kind "Installation"` → this version ships its CRDs separately:
  `operator-crds.yaml`, same directory, create it first.

**Join — and why the node went `Ready` in under a second (measured 26 Sep).**
`creationTimestamp` 00:44:54 → `Ready` 00:44:55: the kubelet's **first** report
was already Ready. Cause: **`kubeadm reset` does not clean `/etc/cni/net.d/`**
(its own output says so) — `10-calico.conflist` was still there, confirmed with
`sudo ls` after the next reset. A node that re-joins with a stale CNI config goes
Ready instantly; joined to a cluster with a **different** CNI it is Ready with
broken networking. **Ready means "a CNI config file exists", not "the network works".**

Two more measured facts: `kubeadm reset` keeps containerd's images (w3 still had
10 Calico images) · containerd **recreates `/etc/cni/net.d/` empty, mode 700 root**
(its CRI plugin watches `conf_dir`) — an empty directory is harmless, hence
`sudo ls` and "empty = clean".

**Version skew is invisible in STATUS.** w3 joined with kubelet 1.35.9 to a 1.34.11
control plane and showed `Ready`. Only the VERSION column reveals it. The kubelet
must never be newer than the apiserver — check VERSION before any join.

```bash
# ▶▶ cp1 — mint and join
kubeadm token create --print-join-command
# ▶▶ the node — paste, prefix sudo
sudo kubeadm join <ip>:6443 --token <t> --discovery-token-ca-cert-hash sha256:<h>
```

```bash
# ▶▶ cp1 — decommission (§9 Task 3)
kubectl drain w3 --ignore-daemonsets --delete-emptydir-data && kubectl delete node w3
# ▶▶ w3
sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d ~/.kube
sudo ls /etc/cni/net.d/ 2>&1                  # 🔍 empty or "No such file"
```

```bash
# ▶▶ cp1 — 🔍 VERIFY a join
kubectl get nodes -o wide                      # Ready · VERSION equal to the control plane
kubectl -n calico-system get pods -o wide | grep <node>   # calico-node 1/1
```

**CoreDNS placement is history, not design.** 2 replicas, tolerate the
control-plane taint, placed when *created*. A drain moves a replica; an
`uncordon` never brings it back — Kubernetes does not rebalance running Pods.
Only a recreate (`rollout restart`, delete a Pod) lets the scheduler decide again.

### Command card — 1.3
```
cidr     kubectl -n kube-system get pod -l component=kube-controller-manager -o yaml | grep cluster-cidr
operator kubectl create -f <URL from task>
cr       curl -sLO <same dir>/custom-resources.yaml → grep cidr → vim +/cidr :s → grep cidr → kubectl create -f
prove    get tigerastatus (calico True) · get nodes Ready · coredns Running   (2–4 min; webhook "connection refused" meanwhile = wait)
token    sudo kubeadm token create --print-join-command       [cp1]
join     sudo kubeadm join …  (paste, Ctrl+Shift+V)            [node]
verify   get nodes -o wide: Ready + VERSION = cp1 · calico-node 1/1 on the node
off      drain --ignore-daemonsets --delete-emptydir-data → delete node   [cp1]
clean    sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d ~/.kube      [node]
```

### Traps

| Error | Cause |
|---|---|
| Installed Flannel, nodes Ready, task scored 0 | The task required NetworkPolicy enforcement — Calico |
| `annotations: Too long` on the operator | `apply` instead of `create` |
| `no matches for kind "Installation"` | v3.33: the operator installs its own CRDs (`-manage-crds=true`) seconds after starting — wait 20 s, re-run. Still failing after a minute (or an older version) → `operator-crds.yaml`, same directory, create it first |
| `tigerastatus` full of `failed calling webhook … connection refused` | Normal for the first minutes — the webhook Pods need the network `calico-node` is still building. A fault only once `calico-node` is 1/1 |
| Node `Ready`, `calico-node` still 0/1 (31 Oct, ~10 min) | `Ready` flips when `10-calico.conflist` lands, not when Calico works — prove with `tigerastatus` |
| `kubeadm token create` → `admin.conf: permission denied` | Missing `sudo` — kubeadm reads the root-owned `/etc/kubernetes/admin.conf` |
| Calico pool set to a `/24` | Took `describe node`'s `PodCIDR` (node slice) instead of `--cluster-cidr` |
| `grep -n cdir` empty → edited blind | A typo'd check proves nothing — re-run it right |
| `sed` put the runbook's CIDR, not the cluster's | Copied a value instead of reading one — `cat`/`grep` after every edit |
| `init` fails on w3 | `--apiserver-advertise-address` of another node |
| Re-joined node Ready in < 1 s | Stale `/etc/cni/net.d/` — `reset` leaves it |
| Node Ready, VERSION newer than cp1 | Skew — STATUS never checks it |
| `kubectl -n kube-systems get pods` → "No resources found" | kubectl does not validate namespace names — suspect the name before the cluster |
| CoreDNS `Pending` right after `init` | Normal — no CNI yet |
| Join token rejected | TTL 24 h — `token create --print-join-command` |
| Worker join with `--control-plane` | Those flags are for control-plane joins |
| `nslookup` NXDOMAIN on a short name | `busybox:1.36` — pin `1.28` |
| Deleted `calico-node`, it came back | The operator owns it |

⚠️ **EKS:** `kubeadm join` ↔ managed node group / launch-template userdata; token +
CA hash ↔ IAM. The CNI is the **VPC CNI** (`aws-node`), an AWS-managed addon — Pods
get real VPC IPs, so two clusters in peered VPCs **cannot** reuse a range. Here an
overlay CIDR like `10.244.0.0/16` is reused freely across clusters: the routes
never leave each cluster.

---

## 1.7 Understand extension interfaces (CNI, CSI, CRI) ⚙️

**Runs on: the node being inspected.** · **Theory →** notes_01 §1.7, notes_04,
notes_05, notes_06 · **Docs →** `network plugins`, `debugging kubernetes nodes with crictl`
· **Target: find a dead control-plane component < 1:00 · fix ≤ 6:00 · CRI from .deb 5:00**

### The shape

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | Name the three plug points | Kubernetes defines the contract; providers implement it — no per-vendor code in the project | 📚 |
| 2 | Find each one on the node | A broken plug point shows up as a missing file, socket or binary | 🔍 |
| 3 | `crictl` when the API server is down | The only window left | 🎯 (inside D5) |
| 4 | Install a CRI from a `.deb` | Reported May 2026 — the `dpkg` command was **not** given | 🎯 |

**How 1.7 is examined:** almost never as "explain CRI". It hides inside other
tasks — a dead control plane (D5), a CNI install (1.3), a CRI install from a
`.deb` (+ 1.2's sysctls), or "which runtime / CNI does this node use".

### The whiteboard

| Interface | Who calls it | To whom | Where |
|---|---|---|---|
| **CRI** | the kubelet | containerd | `containerRuntimeEndpoint` in `/var/lib/kubelet/config.yaml` → `/run/containerd/containerd.sock` (`/var/run` is a symlink to `/run`) |
| **CNI** | **containerd**, when it creates a Pod's sandbox | a binary in `/opt/cni/bin/` named by the config's `"type"` | config `/etc/cni/net.d/` · both paths in containerd's `config.toml` (`bin_dirs`, `conf_dir`) |
| **CSI** | kubelet + controllers | the storage driver | `kubectl get csidrivers` · `get csinodes` · node annotation `csi.volume.kubernetes.io/nodeid` |

Birth of a Pod: **kubelet →(CRI)→ containerd → sandbox (`pause`) →(CNI)→
`/opt/cni/bin/calico` → the Pod has an IP.** `crictl pods` = sandboxes;
`crictl ps` = containers.

**Which CNI is installed? Read `/etc/cni/net.d/`, never `/opt/cni/bin/`.** On w3
`/opt/cni/bin/` held a `flannel` binary while the CNI was Calico — binaries are
just what is available; the config decides.

```bash
# ▶▶ any node — 🧪 crictl is not in the kubeadm packages
sudo apt install -y cri-tools
printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' | sudo tee /etc/crictl.yaml
sudo crictl version                               # RuntimeName containerd · 2.2.1
```

**A control-plane component is down — the method** (sim A, 26 Sep):

1. `sudo crictl ps -a --name <component>` — **`-a`**, or the dead ones are invisible.
2. Pick the family:

| What you see | Meaning | Look at |
|---|---|---|
| `Exited` containers, ATTEMPT climbing | Manifest valid; the process starts and dies (flag, port, cert, path) | `sudo crictl logs <id> 2>&1 \| tail -5` of the newest Exited |
| **No container at all** | The kubelet cannot parse the manifest (YAML, invalid field) | `sudo journalctl -u kubelet \| grep -i <component> \| tail` |

3. **Read the log right:** the final `F…` line says it died (sim A: `Error creating
   leases … context deadline exceeded`); the **repeated `W…` lines before it say
   why** (`dial tcp 127.0.0.1:2399: connection refused`). `tail -5`, not `tail -1`.
4. Confirm with a **targeted grep** against the side that should be listening
   (`grep listen-client /etc/kubernetes/manifests/etcd.yaml` → 2379), fix with
   `sudo vim`, watch `crictl ps --name` for a new container (ATTEMPT 0, new POD ID).
5. Not back within ~1 min → `sudo systemctl restart kubelet` (reported in the May
   2026 exam). Then `kubectl get nodes` — the proof the task asks for.

**Dependency chain: etcd → apiserver → everything else.** In sim A the scheduler
and controller-manager showed ATTEMPT 2 and `calico-kube-controllers` ATTEMPT 1:
symptoms — they renew their leader lease through the apiserver. Fix the lowest
broken link; the rest recovers on its own.

Typical apiserver breakers: `--etcd-servers` URL/port · a cert path typo
(`no such file or directory`) · unknown flag · broken YAML (no container) · a
non-existent image tag.

**Steps that include a wait are never pasted as one block** — `crictl ps` one
second after moving a manifest still shows it Running. Repeat until the state changes.

**Install a CRI from a `.deb`** (sim C — the `dpkg` line may not be given):

```bash
# ▶▶ the node the task names
sudo dpkg -i <path from the task>.deb           # blank on it? dpkg --help
#   "dependency problems … leaving unconfigured" → dpkg does NOT resolve deps:
sudo apt-get install -f -y
dpkg -L <package> | grep -E '\.(service|socket)$'   # unit name ≠ package name
sudo systemctl enable --now <unit>              # cri-dockerd → cri-docker.service
systemctl is-active <unit>                      # 🔍 active
ls -l /run/cri-dockerd.sock                     # 🔍 the CRI socket exists
# + the sysctls the task lists → /etc/sysctl.d/k8s.conf → sudo sysctl --system  (= 1.2)
```

### Command card — 1.7
```
cri      grep containerRuntimeEndpoint /var/lib/kubelet/config.yaml · ls -l <socket>
tool     cri-tools + /etc/crictl.yaml
dead?    sudo crictl ps -a --name <c>  → Exited = logs · nothing = journalctl -u kubelet
logs     sudo crictl logs <id> 2>&1 | tail -5     (W lines = cause, F line = death)
fix      targeted grep → sudo vim manifest → crictl ps --name (new ID) → restart kubelet if stuck
cni      sudo ls /etc/cni/net.d/ (what is used) · ls /opt/cni/bin/ (what is available)
csi      kubectl get csidrivers · get csinodes
deb      sudo dpkg -i X.deb → apt-get install -f -y if deps → dpkg -L | grep service → enable --now
```

### Traps

| Error | Cause |
|---|---|
| `crictl ps` shows no apiserver, no clue why | Missing `-a` — the Exited containers hold the log |
| Read the whole manifest, found nothing | No hypothesis — logs first, targeted grep second |
| Blamed the scheduler (ATTEMPT 2) | Symptom — it depends on the apiserver |
| Last log line says "deadline exceeded" | The effect; the repeated `W` lines are the cause |
| Fixed the manifest, Pod never returns | Restart the kubelet |
| `vim` on a manifest opens read-only | Missing `sudo` |
| "The CNI is Flannel" (binary seen) | `/opt/cni/bin/` is inventory; `/etc/cni/net.d/` is the answer |
| `failed to create pod sandbox … plugin not found` | The conflist names a binary absent from `/opt/cni/bin/` |
| `dpkg -i` leaves the package unconfigured | `dpkg` does not resolve dependencies → `apt-get install -f` |
| `systemctl enable cri-dockerd` → not found | Unit name ≠ package name → `dpkg -L` |
| `crictl` warns about default endpoints | `/etc/crictl.yaml` missing |
| `ls /etc/cni/net.d` → Permission denied | Directory is 700 root — `sudo` |
| `<container-id>` pasted literally | Bash syntax error — placeholders are replaced, never pasted |

⚠️ **EKS:** CNI = `aws-node` (VPC CNI DaemonSet) · CSI for EBS = a managed addon ·
containerd baked in the AMI · no reachable control plane, so no `crictl` on it and
no manifest to fix — a dead EKS apiserver is an AWS ticket, not a task.

---

## §9. Exam mode — Set 2 (install & extend)

No scaffolding, no verification handed to you, wording as the CKA phrases it.
Runs on **w3**, never on cp1/w1/w2. **During the clock, read only the task text.**

### Task 1 · node prep (weight 7%) · target 10:00
```
A new machine w3 must be prepared to run Kubernetes workloads. Configure the
node so that the kubelet will start successfully and cluster networking will
function. Do not join the node to any cluster.
```
Setup: restore `w3.cleanw3`. Variations: an explicit sysctl list · containerd
installed but misconfigured.

### Task 2 · join (weight 4%) · target 4:00
```
Context: k8s-lab
Join the prepared node w3 to the existing cluster as a worker. The original
join token has expired.
```

### Task 3 · decommission (weight 4%) · target 5:00
```
Context: k8s-lab
Node w3 is being decommissioned. Remove it from the cluster completely, so that
the machine could later be joined to a different cluster without conflict.
```

### Sim A · API server down, blind (weight 7%) · target 6:00
Setup on a w3 that runs a control plane — the break is base64-encoded so you
cannot read it; wait 60 s, `clear`, start the clock:
```bash
echo c2VkIC1pICdzfC0tZXRjZC1zZXJ2ZXJzPWh0dHBzOi8vMTI3LjAuMC4xOjIzNzl8LS1ldGNkLXNlcnZlcnM9aHR0cHM6Ly8xMjcuMC4wLjE6MjM5OXwnIC9ldGMva3ViZXJuZXRlcy9tYW5pZmVzdHMva3ViZS1hcGlzZXJ2ZXIueWFtbA== | base64 -d | sudo bash
```
```
Context: w3
The cluster's API server is not responding. Diagnose the cause and fix it so that
kubectl get nodes works again. Do not recreate the cluster.
```
Next time, encode a **different** break (cert path typo, unknown flag, broken
indentation) — the same one twice tests memory, not diagnosis.

### Sim B · CNI install (weight 6%) · target 6:00
Setup (no clock):
```bash
# ▶▶ w3
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d ~/.kube ~/custom-resources.yaml ~/kubeadm-init.log
sudo reboot                                     # clears vxlan.calico + Calico's iptables
# after reboot — pick a CIDR you will "forget"
sudo kubeadm init --pod-network-cidr=172.20.0.0/16 --apiserver-advertise-address=10.97.0.241 --node-name=w3 > /dev/null
mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config
kubectl get nodes && clear                      # NotReady → ⏱ start
```
```
Context: w3
The cluster's CNI failed a security audit and has been removed. Install and
configure a Container Network Interface that meets these requirements:
  - Pods on all nodes can communicate with each other
  - The CNI must support enforcing NetworkPolicies
  - Use the cluster's existing Pod CIDR

Choose one of:
  Flannel v0.26.1  https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml
  Calico  v3.33.0  https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml
```

### Sim C · CRI from a `.deb` (weight 5%) · shape only
Not simulated in this lab (cri-dockerd needs Docker Engine). Solution: 1.7
whiteboard, `.deb` block.

<details>
<summary>Self-verification — open only after the clock stops</summary>

```bash
# Task 1 — w3
swapon --show; sysctl net.ipv4.ip_forward; lsmod | grep br_netfilter
grep SystemdCgroup /etc/containerd/config.toml; apt-mark showhold
# Task 2 — cp1
kubectl get nodes -o wide                       # w3 Ready, same VERSION as cp1
# Task 3 — cp1 + w3
kubectl get nodes                               # w3 absent
sudo ls /etc/cni/net.d/ 2>&1; ls /etc/kubernetes/   # empty / manifests only
# Sim A — w3
kubectl get nodes; sudo crictl ps --name kube-apiserver
# Sim B — w3
kubectl get installation default -o jsonpath='{.spec.calicoNetwork.ipPools[*].cidr}'; echo
kubectl get tigerastatus; kubectl -n kube-system get pods
```

</details>

### Run log

| Date | Task | With | Time | Errors / notes |
|---|---|---|---|---|
| 23 Sep | 1 run 1 | card | ~30:00 | typos ×5, 2 files emptied by `tee`, `containerd default`, repeated failing commands |
| 23 Sep | 1 run 2 | script | ~7:00 | `bridge_nf_call_*` underscores (masked by the kernel default) |
| 23 Sep | 1 run 3 | card closed | untimed | `grep swwap` → acted without evidence · `restart containerd d` |
| 26 Sep | 1 A1 | blind (verify consulted) | **9:33** | `overlary` (read + fixed) · `restart containerd d` ×2 (repeated) |
| 26 Sep | 3 + 2 | blind | **< 3:00 + 0:56** | join Ready in < 1 s on stale `/etc/cni/net.d/` |
| 26 Sep | Sim A | method coached | untimed | read the manifest first; `crictl ps` without `-a` |
| 26 Sep | Sim B (first pass) | text open | 9:26 | `grep cdir` typo → `sed` wrote the runbook's CIDR, caught with `cat` |
| 26 Sep | **Sim B** | **blind** | **3:24** | CIDR via `kubeadm-config`; skipped the `grep` checks around the edit |
