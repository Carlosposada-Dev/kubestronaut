---
domain: D1 — Cluster Architecture, Installation & Configuration
group: 2 — Lifecycle
bullets: [1.4, 1.5]
exams: [CKA]
index: cka-D1.md
theory: notes_01
status: drilled (1.4 partial · 1.4b ✅ 17 Sep · §C ✅ 1.4c ✅ 19 Sep · 1.5 read)
revision: 2026-09-26 (r9 — held-package flag REMOVES the hold (measured); one chained re-hold per node) · r8 2026-09-26 ( one drain line; verify v<x.y.z>; targets unified with cka-D1 §7; exam flow without nested ssh) · r7 2026-09-26 ( `apt` not `apt-get`; one parking directory /etc/kubernetes/; worker order per docs + overlap during apply; held-package flag; clean-v134 as upgrade base) · prev r6 2026-09-19
---

# D1 · Group 2 — Lifecycle (bullets 1.4, 1.5)

> ⚠️ **29 Oct — literals out of date.** The exam now runs **v1.37** and the lab was
> rebuilt: the upgrade source is **`lab-v136` (1.36.5)**, the target **1.37.x**,
> etcd **3.6.8** on 1.36 and **3.7.0** on 1.37. The upgrade blocks below still say
> 1.34 → 1.35.8 and etcd 3.6.5/3.6.6. The mechanism is unchanged; translate the
> minor in the `.list` URL, the apt/kubeadm versions and the etcd release until the
> literal refresh is done (owed — `plan.md §15`, 29 Oct).

> Index, boot block, execution locations, scaffolding and scoreboard:
> **`cka-D1.md`**.
>
> **This is the highest-value file in D1.** Upgrade and etcd restore are the two
> tasks most likely to appear, and both are pure blind spot: EKS performs them
> for you or forbids them entirely.
>
> Homes for shared topics: **static Pods (§S)** and **certificates (§C)** live
> here. `cka-D1-1-install.md` creates both and links back.

---

## Legend — what to type in the exam, what is only for learning

Every command block in this file is marked. Under a clock, run only 🎯 and 🔍.

| Mark | Meaning | In the exam |
|---|---|---|
| 🎯 | **Exam path** — the task is not done without it | type it |
| 🔍 | **Verification** — proves the task worked | type it, once, at the end |
| ⏱ | **Waiting** — fixed machine time, cannot be shortened | start another task, come back |
| 📚 | **Study only** — teaches the mechanism, scores nothing | skip |
| 🧪 | **Scaffolding** — exists because this is a home lab | never appears in the exam |

**Rule that outranks the marks:** whatever the task statement spells out — a path,
a file name, a version, a node — is literal. 🎯 blocks show defaults, not orders.

### Typing conventions — chosen for speed (26 Sep)

| Convention | Why |
|---|---|
| **`apt`, not `apt-get`** | Identical for interactive use; 4 characters fewer on every call, and the upgrade calls it ~10 times. The docs write `apt-get` — do not let that throw you. `apt` warns "no stable CLI interface" only when **piped**; harmless. `apt-mark` and `apt-cache madison` have no short form — they stay |
| **Always pin the version** (`kubeadm=1.35.9-1.1`) | Without one, apt installs the **newest** package in the repo. That is only correct when the task says "latest"; a task that names `v1.35.8` fails if you land on `.9` |
| **One parking directory: `/etc/kubernetes/`** | To stop the control plane, move the manifests **one level up**. No `mkdir`, no invented name, and the kubelet watches only `manifests/` itself. Nothing else in `/etc/kubernetes/` ends in `.yaml` |
| **Chain with `&&`** | Stops at the first failure; `;` marches on and hides it. Same speed |
| **One `drain` line for every node** | `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`. The second flag is harmless where there is no `emptyDir`, and fatal to forget where there is one — one variant to memorise, zero to choose |

### Lab vs exam — how you move between nodes (verified on the LF page, 26 Sep)

| | Lab | Exam |
|---|---|---|
| Where you start | cp1 | `base` — **no kubectl there** |
| Reaching a worker | `ssh w1` **from cp1** | **`exit` to base, then `ssh w1`** — nested ssh is not supported |
| `k` + completion | in `~/.bashrc` (mirrors the exam) | preconfigured on every SSH host |
| Your `$do` / `.vimrc` | persist | **die on every `exit`** — re-run the per-host line (`plan.md §13`) |

In every command block, `▶▶ w1` means *"a shell on w1"*: in the lab via
`ssh w1` from cp1; in the exam via base.

### Every numeral has the same two pieces

| Piece | What it is | Use it in |
|---|---|---|
| **The shape** | numbered table: *what we do · why*. The declarative summary, no commands | learning, and the 30 s of re-reading before a timed run |
| **Command card** | the whole procedure in ≤ 10 lines, one verb per line | **while executing.** The only thing you look at under a clock |

Card index: **1.4** upgrade · **1.4b** etcd save/restore · **§C** certificates ·
**1.4c** node lifecycle · **1.5** HA (decision card, nothing to run).

### Fixed section order — every numeral, in this file and the next ones

`Shape` (what · why, no commands) → `Whiteboard` (the mechanism, with the
commands and the phases) → `Command card` → `Traps` (two columns: error · cause)
→ `EKS` → and once per file, `Exam mode`.

**Traps stay two columns.** Error, cause, done. A trap that needs a paragraph is
not a trap, it is a mechanism, and it belongs in the whiteboard.

**Discarded approaches are deleted, not documented.** Once a shortcut is proven
wrong, it leaves the file — only its consequence survives, as one trap row.

---

## §S. Static Pods — the concept the rest of this file rests on

**Runs on: cp1** (this lab has one control-plane node; workers have no static
Pods).
**Theory →** notes_01 §1.4 · **Docs →** search `static pods` ·
`kubectl explain pod.metadata.ownerReferences`

### The shape

A **static Pod** is a Pod the kubelet runs from a **file on disk**, with no
scheduler and no API server involved. The kubelet watches
`/etc/kubernetes/manifests/` and reconciles whatever it finds there.

That is how the control plane bootstraps itself: `kube-apiserver` cannot be
created *through* the API server, so it is a file.

```bash
# ▶▶ cp1
ls -l /etc/kubernetes/manifests/
#   etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
grep -n staticPodPath /var/lib/kubelet/config.yaml     # where the kubelet looks
```

### Four consequences you will be examined on

1. **Editing the file is the only way to change them.** No `kubectl edit`, no
   `apply`. Save the file and the kubelet acts within seconds.
2. **`kubectl delete pod` does not remove them.** You delete the *mirror*; the
   kubelet recreates it. To stop one, **move the manifest out of the directory**.
3. **`drain` cannot evict them**, which is why draining cp1 does not take down
   the control plane. What `drain` protects is the node's *ordinary* Pods.
4. **A mirror Pod's `AGE` is not the component's age.** The kubelet recreates the
   mirror in the API server every time it starts. After a VM boot `etcd-cp1`
   shows a fresh `AGE` with `RESTARTS 0` and nothing actually restarted. **Never
   diagnose "etcd restarted" from that column.**

### The manoeuvre — used by both the etcd restore and the cert renewal

```bash
# ▶▶ cp1 — stop the whole control plane: park the manifests ONE LEVEL UP
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/
# ... do the work (edit them there if needed: /etc/kubernetes/etcd.yaml) ...
# ▶▶ cp1 — start it again
sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/
```

While the manifests are out, `kubectl` does not work. **`sudo crictl ps` is your
only window.** Learn that reflex here, not in D5 under a clock.

⚠️ **EKS:** you have never seen `/etc/kubernetes/manifests/` and never will.
There is no node you can reach that runs a control-plane component.

---

## 1.4 Manage the lifecycle of clusters — upgrade ⚙️ HIGH VALUE

**Runs on: cp1 (phase A); each worker (phase B) — lab: `ssh w1` from cp1 · exam: `exit` to base, then `ssh w1`.**
**Theory →** notes_01 §7 · **Docs →** search `upgrading kubeadm clusters` ·
**Target (wall, from `cka-D1.md §7` row 2): cp1 only 8:00 · cp1 + 1 worker 12:00.** Keyboard clock is a diagnostic, not a target. Runs → `cka-D1.md §7`

### The shape

| # | What we do | Why |
|---|---|---|
| 1 | Point apt at the new minor | A v1.34 repo can never see a v1.35 package |
| 2 | Upgrade the **kubeadm binary** | It is the tool that performs the upgrade; it is not disruptive |
| 3 | `upgrade apply` on cp1 | Static Pods + certificates + CoreDNS + kube-proxy + the ConfigMaps |
| 4 | `drain` the node | The only disruptive step is next |
| 5 | Upgrade the **kubelet package** and restart it | `kubeadm` never does this for you |
| 6 | `uncordon` | Give the node back to the scheduler |
| 7 | Repeat on each worker, **one at a time**, with `upgrade node` | A worker only rewrites its own kubelet config |
| 8 | Verify past `get nodes` | That column only reads the kubelet version |

**Two rules govern the whole procedure.** The kubelet may lag the API server but
**never lead it** — so the control plane goes first, workers after, one at a
time. And **`kubeadm` moves one minor at a time, never two**.

**Every node, both phases, runs the same three beats:**

```
  point apt at the new minor   →   upgrade the kubeadm BINARY   →   upgrade the KUBELET package
       (the repo URL                  (does the k8s work)             (drain · install · restart · uncordon)
        carries the minor)
```

**Only the middle beat differs:**

| | Middle beat | What it actually does |
|---|---|---|
| **cp1** | `kubeadm upgrade apply <version>` | static Pods (etcd, apiserver, controller-manager, scheduler) **+ renews every control-plane certificate + upgrades the CoreDNS Deployment and the kube-proxy DaemonSet + uploads the `kubeadm-config` and `kubelet-config` ConfigMaps** |
| **w1, w2** | `kubeadm upgrade node` | rewrites this node's kubelet config, nothing else. Its own output says so four times: *Skipping phase. Not a control plane node.* |

**And that is why `drain` moves.** The rule is single:

> **`drain` goes immediately before the kubelet package upgrade + restart** — the
> only step that disrupts the node's workloads.

On cp1 the kubelet beat comes **last** (after `apply`), so `drain` is late. On a
worker the kubelet beat is **the whole thing**, so `drain` is first.

> Upgrading the `kubeadm` **binary** before draining is harmless — nothing is
> running it. Only the kubelet restart is disruptive. (Verified 14 Sep: the
> reordering on w2 was correct, not an error.)
>
> And draining cp1 does not disturb the control plane at all, because **`drain`
> cannot touch static Pods** (§S).

### The whiteboard

#### Phase A — control plane (cp1)

Set the version **once per node** as a variable — it is typed three times per
node otherwise, and each retype is a chance for `kubeadnm=`. It does not survive
`ssh`: set it again on each worker.

```bash
# ▶▶ cp1
v=1.35.9-1.1                                    # apt format: NO v, WITH -1.1 — from the task

# BEAT 1 — the repo URL carries the minor. A v1.34 repo can never see v1.35.
sudo sed -i 's|v1.34|v1.35|' /etc/apt/sources.list.d/kubernetes.list
sudo apt update                                 # refreshes the INDEX. Upgrades nothing.
#   📚 sudo apt-cache madison kubeadm | head   — only when the task gives no version

# BEAT 2 — the binary, then the control plane
sudo apt install -y --allow-change-held-packages kubeadm=$v
sudo kubeadm upgrade apply v1.35.9 -y           # kubeadm format: WITH v, NO -1.1   ⏱ 2–4 min
```

⏱ **While `upgrade apply` runs, do the worker's pre-stage in a second terminal**
(see Phase B, beats 1–2). Installing the kubeadm **binary** on a worker is not
disruptive and needs nothing from cp1. This is the biggest saving in the task:
it hides one worker's `apt update` + install inside a wait you pay anyway.

```bash
# ▶▶ cp1 — after apply prints SUCCESS
# BEAT 3 — the kubelet package. kubeadm does NOT do this for you.
kubectl drain cp1 --ignore-daemonsets --delete-emptydir-data
sudo apt install -y --allow-change-held-packages kubelet=$v kubectl=$v && sudo apt-mark hold kubeadm kubelet kubectl && sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon cp1      # 'connection refused' right after the restart = API server coming back. Retry
```

**`--allow-change-held-packages` installs through the hold — and REMOVES it.**
Measured 26 Sep: `apt-mark showhold` printed nothing on all three nodes after the
run. So the hold is re-set **once per node, chained into the kubelet line** (the
last step on every node): `&& sudo apt-mark hold kubeadm kubelet kubectl`. Zero
extra commands, and `&&` means nothing is frozen if the install fails.
Why bother: with ~118 packages upgradable, one stray `sudo apt upgrade` moves the
Kubernetes packages to whatever the repo holds newest.

🔍 End of task: `apt-mark showhold` → the three names, on every upgraded node.

**`needrestart` is not your friend.** Ubuntu's `needrestart` restarted the kubelet
on w2 on 26 Sep even though the typed `systemctlrestart` failed. The exam host may
not do that. The only proof is `get nodes` showing the new version.

#### Phase B — each worker (w1, then w2 — never both at once)

**Order per the docs: kubeadm → `upgrade node` → drain → kubelet → uncordon.**
The drain comes **late**, immediately before the only disruptive step — so the
node is out of service for the shortest possible time, and beats 1–2 can run
before cp1 has even finished.

```bash
# ▶▶ w1 — beats 1–2: can run while cp1's apply is still going
hostname
v=1.35.9-1.1
sudo sed -i 's|v1.34|v1.35|' /etc/apt/sources.list.d/kubernetes.list
sudo apt update && sudo apt install -y --allow-change-held-packages kubeadm=$v
```
```bash
# ▶▶ w1 — beat 3: only AFTER cp1's apply has succeeded
sudo kubeadm upgrade node                       # NOT "upgrade apply"
```
```bash
# ▶▶ cp1 — beat 4
kubectl drain w1 --ignore-daemonsets --delete-emptydir-data
```
```bash
# ▶▶ w1 — beat 5
sudo apt install -y --allow-change-held-packages kubelet=$v kubectl=$v && sudo apt-mark hold kubeadm kubelet kubectl && sudo systemctl daemon-reload && sudo systemctl restart kubelet
exit
```
```bash
# ▶▶ cp1 — beat 6
kubectl uncordon w1
```

Repeat phase B for **w2** only if the task asks for it.

**Exam flow (no nested ssh):** CP host → `exit` → `ssh w1` (beats 1–3) → `exit` →
`ssh <CP host>` (drain) → `exit` → `ssh w1` (beat 5) → `exit` → `ssh <CP host>`
(uncordon). More hops than the lab — which is why the worker's beats 1–2 go
**first**, while `apply` runs, so the hop is paid once.

#### 🔍 Verification — `get nodes` is NOT enough

```bash
# ▶▶ cp1
kubectl get nodes          # upgraded nodes Ready at v<x.y.z>, the rest untouched, none SchedulingDisabled

# That column reads ONE field: .status.nodeInfo.kubeletVersion.
# These were also upgraded and it cannot show any of them:
kubectl -n kube-system get ds kube-proxy -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get deploy coredns -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get po kube-apiserver-cp1 -o jsonpath='{.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get po etcd-cp1 -o jsonpath='{.spec.containers[0].image}{"\n"}'
kubectl get --raw='/readyz?verbose' | tail -3
```

⚠️ **"Ready and v1.35.8 on all three nodes" does not mean the upgrade is
complete.** It means the kubelet was upgraded. A stale CoreDNS or kube-proxy
coexists with that output in silence.

> **`.status.nodeInfo.kubeProxyVersion` is deprecated and off by default since
> v1.33** — a node cannot reliably know kube-proxy's version, since the kubelet
> does not manage it. The field returns **empty**. kube-proxy is verified only
> through the DaemonSet image.

**Dropped from the exam path (26 Sep):** `apt-cache madison` (📚 — only when the
task gives no version), `kubeadm upgrade plan` (📚 — `apply` refuses a wrong
version anyway), `kubeadm version` (🔍 — the final check covers it), `mkdir` of a
parking directory (replaced by `/etc/kubernetes/`), and the `unhold`/`hold` pairs
(replaced by `--allow-change-held-packages` + **one** chained `apt-mark hold` per node).

**Two clocks in this task — measure only the first.**

| Clock | What | Budget |
|---|---|---|
| **Keyboard** | reading, deciding, typing, drain/uncordon | diagnostic only — if the wall target is missed, this says whether it was typing or waiting |
| ⏱ **Waiting** | `apt update`/`install`, `upgrade apply`, kubelet restart | 4–6 min — fixed per step, but **overlappable** across nodes |

**Runs:** 17 Sep — sequence from memory, >15:00 wall on cp1 + w1. **26 Sep R1**
(from `clean-v134` → 1.35.9): **20:00 wall vs 12:00 target**, sequential, before
r7. **26 Sep R2: 18:00** (3 nodes, held-package flag, old worker order, no
overlap; holds lost — found after the run). Next run uses the overlap and the held-package flag; time the
keyboard clock separately.

### Command card — 1.4 upgrade

```
VAR       v=<x.y.z-1.1>                                                      [each node]
REPO      sudo sed -i 's|v1.34|v1.35|' /etc/apt/sources.list.d/kubernetes.list   [each node]
BINARY    sudo apt update && sudo apt install -y --allow-change-held-packages kubeadm=$v
CP1       sudo kubeadm upgrade apply v<x.y.z> -y      ⏱ → meanwhile REPO+BINARY on w1
          DRAIN cp1 → KUBELET → BACK cp1
WORKER    sudo kubeadm upgrade node                   (after cp1 succeeded · NOT "apply")
DRAIN     kubectl drain <node> --ignore-daemonsets --delete-emptydir-data  [CP host · same line for every node]
KUBELET   sudo apt install -y --allow-change-held-packages kubelet=$v kubectl=$v \
            && sudo apt-mark hold kubeadm kubelet kubectl \
            && sudo systemctl daemon-reload && sudo systemctl restart kubelet
BACK      kubectl uncordon <node>                                           [cp1]
PROVE     get nodes + kube-proxy DS image + coredns image + apiserver/etcd image + apt-mark showhold
```

Versions: `v1.35.9` for kubeadm · `1.35.9-1.1` for apt. **cp1:** binary → apply →
drain → kubelet → uncordon. **Worker:** binary → `upgrade node` → drain → kubelet →
uncordon.

### Traps

| Error | Cause |
|---|---|
| `apt install kubeadm=v1.35.8` | apt **never** takes a `v`: `1.35.8-1.1`. `kubeadm` **always** does: `v1.35.8`. Read them from `apt-cache madison` and `kubeadm upgrade plan` |
| `madison` shows no 1.35 | The repo URL carries the minor; bump it first |
| Landed on 1.35.10 when the task said 1.35.8 | No version pinned — apt took the newest in the repo |
| `kubeadm upgrade node` fails on the worker | Ran before cp1's `apply` finished |
| `E: Held packages were changed` | Held package installed without `--allow-change-held-packages` (or without `unhold`) |
| `apt-mark showhold` empty after the upgrade | The flag removed the holds. Re-hold in the kubelet line |
| Node shows the new version though `restart kubelet` failed | Ubuntu's `needrestart` did it for you. Do not rely on it |
| `uncordon` → `connection refused` right after the kubelet restart | API server restarting. Wait 10 s and retry |
| `kubeadm=$v` installs nothing / wrong string | `v` is not set on this node — variables do not cross `ssh` |
| `kubeadm upgrade apply` on a worker | Workers take `upgrade node` |
| `get nodes` still shows the old version | The **kubelet is an apt package**; `kubeadm` never moves it |
| `Access denied` after `sudo cmd1 && cmd2` | `sudo` applies to one command. Write it twice |
| drain refuses to start | Missing `--ignore-daemonsets` (plural) or `--delete-emptydir-data` |
| drain hangs on a Pod | A **PodDisruptionBudget** — the Eviction API honouring it. Correct behaviour; wait |
| Upgrade "succeeded", node takes no Pods | Forgot `uncordon` — graded as failed |
| Phase B commands ran on cp1 | Forgot to `ssh`. `hostname` first |
| `localhost:8080 refused` on a worker | No kubeconfig there — `drain`/`uncordon` run from cp1 |

⚠️ **EKS:** one API call or one Terraform attribute. Control plane and node
groups upgrade **separately**. The managed node group performs the drain for you
and **respects PDBs** — exactly what you watched happen by hand. The kubelet
version is **baked into the AMI**: nodes are not upgraded, they are replaced.
No repo URL, no `apt-mark hold`, no `upgrade node`, no `uncordon`.

**Rewrite from memory:**
```
The three beats, and what differs between phases:
Phase A:
Phase B:
```

---

## 1.4b etcd backup and restore ⚙️ — not a bullet, a scored task

**Runs on: cp1 only.** etcd is a static Pod on the control-plane node.
**Theory →** notes_01 §1.4 · **Docs →** search `backing up an etcd cluster` ·
**Target: save + verify 5 min · restore 10 min**
**Taught 16 Sep, teach-first (`claude/session-protocol.md` §3).** Rewritten from
the questions actually asked. Command card at the end of the section.

### The shape

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | Prepare the terminal (boot block) | The exam hands you an empty shell | 🎯 |
| 2 | Read the endpoint and the three cert paths | etcd talks to no one without mutual TLS | 🎯 only if the task omits them |
| 3 | Create an object **before** | Something that must survive | 📚 lab only — the task names its own object |
| 4 | **Take the photo** (`snapshot save` + `status`) | The scored task | 🎯 |
| 5 | Create an object **after** | Something that must disappear | 📚 lab only |
| 6 | **Restore the photo** (stop → restore → repoint → start) | The other scored task | 🎯 |
| 7 | Prove: "before" is there, "after" is gone | Evidence the cluster travelled back in time | 🔍 |
| 8 | Repeat 4–7 without looking | This is what buys exam speed | 📚 |
| 9 | Someone breaks it, you diagnose blind | The skill D5 is made of | 📚 |

### The whiteboard

etcd is the cluster's database: every object `kubectl` shows lives there.
**Save** = photograph the whiteboard. **Restore** = wipe a board and copy the
photo onto it. The cluster **travels back in time** to the moment of the photo;
anything created after it disappears.

| | `snapshot save` | `snapshot restore` |
|---|---|---|
| Tool | **`etcdctl`** — *ctl*, a network client | **`etcdutl`** — *utl*, an offline file utility |
| etcd running? | **Yes**, it talks to the live process | Irrelevant — you stopped it first |
| Talks to | the etcd process over the network | **nobody** — reads a file, writes directories |
| Endpoint + certs | **required** (mutual TLS) | **none** — there is no connection to protect |
| `sudo` because | `server.key` is root-only (600) | writing under `/var/lib` |

The `.db` file holds **cluster data**, never credentials.

### The four values `save` needs — mutual TLS

| Value | Flag | Meaning | kubeadm default |
|---|---|---|---|
| Where | `--endpoints` | client port, **https** | `https://127.0.0.1:2379` |
| Whom I trust | `--cacert` | the CA that signed etcd's cert — **I verify etcd** | `/etc/kubernetes/pki/etcd/ca.crt` |
| Who I am | `--cert` | my certificate — **etcd verifies me** | `/etc/kubernetes/pki/etcd/server.crt` |
| Proof | `--key` | my private key | `/etc/kubernetes/pki/etcd/server.key` |

**Memorise the defaults** (`https://127.0.0.1:2379` + `pki/etcd/` + `ca.crt ·
server.crt · server.key`). **Confirm** them in 10 s when the task gives no paths:

```bash
# ▶▶ cp1
sudo grep file /etc/kubernetes/manifests/etcd.yaml     # ignore every --peer-* line
```

If the task **states** paths, use those exactly.

`etcdctl snapshot save --help` prints a full example with all four flags — but its
paths are the generic etcd install (`/etc/etcd/etcd.crt`). **Copy the skeleton and
the flag order from it; the values come from you.** Forgot the file names?
`ls /etc/kubernetes/pki/etcd/` — no `sudo` needed, the directory is world-readable
(only the `.key` contents are not). Tab completion after `--cacert=` is unreliable
because bash splits words on `=`; type the path or recall the line with ↑.

- **2379 = clients** (you, the API server) · **2380 = peers** (etcd ↔ etcd).
- `--peer-*` files are for member-to-member traffic. Use the client ones.
  (Open experiment: kubeadm's peer cert is signed by the same etcd CA and is
  probably accepted as a client cert. Not a reason to use it.)
- `/etc/kubernetes/pki/ca.crt` — **no `etcd/`** — is the *Kubernetes* CA. With it
  `etcdctl` rejects etcd's certificate: `x509: certificate signed by unknown
  authority`. The failure happens on **your** side.
- Certificates are public (644). **Only the key is secret**, so a missing `sudo`
  fails first on `--key`.

`ETCDCTL_API=3`: default since etcd 3.4; API v2 is gone in 3.6. Harmless, costs
14 characters, protects you against an old binary — keep writing it. With v2
(etcd ≤ 3.3), `snapshot save` does not exist.

### 🎯 SAVE + 🔍 VERIFY — the exam task (5 min)

```bash
# ▶▶ cp1
sudo mkdir -p /opt/backup
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/backup/etcd.db                  # → Snapshot saved at …

sudo etcdutl snapshot status /opt/backup/etcd.db -w table   # HASH · REVISION · TOTAL KEYS · SIZE
```

Mnemonic: **where → whom I trust → who I am → what I do.**
`\` must be the **last** character of the line — a trailing space breaks it.
*"Verify the snapshot is valid"* = the `status` table. The file existing is not
verification.

### 🎯 RESTORE — part A: stop, then restore into a NEW directory

Replacing etcd's data with the control plane running is changing the engine of a
moving car. The control plane is static Pods (§S), so **moving the manifests out
stops them**; `kubectl delete pod` would not. The **kubelet is a systemd service,
not a Pod** — it keeps running and watching `staticPodPath`, and it is the one
that brings everything back in part B.

```bash
# ▶▶ cp1
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/     # park one level up
sudo crictl ps | grep -E 'etcd|kube-apiserver'      # repeat every ~20 s until EMPTY
                                                    # kubectl → connection refused: CORRECT
sudo etcdutl snapshot restore /opt/backup/etcd.db --data-dir=/var/lib/etcd-restore
sudo ls /var/lib/etcd-restore                       # → member
```

**Why a new directory:** the live data in `/var/lib/etcd` stays intact (your way
back), and `etcdutl` **refuses** a `--data-dir` that already exists — a second run
needs a second name.

State after part A: control plane **off** · `/var/lib/etcd` = **current** data
(the newest, not "old") · `/var/lib/etcd-restore` = **the photo** · etcd does not
know the new directory exists yet.

### 🎯 RESTORE — part B: repoint the volume, start again

`/var/lib/etcd` appears **three times** in `etcd.yaml`. Two are paths *inside the
container*; one is the directory *on the node*. Change **only the node one**.

```yaml
    - --data-dir=/var/lib/etcd          # ① inside the container      — leave
    volumeMounts:
    - mountPath: /var/lib/etcd          # ② where the volume appears  — leave
      name: etcd-data
  volumes:
  - hostPath:
      path: /var/lib/etcd               # ③ the directory ON THE NODE — CHANGE
      type: DirectoryOrCreate
    name: etcd-data                     # ← find the volume by THIS name
```

Analogy: ③ chooses **which USB stick** is plugged in; ① and ② are the drive
letter inside the container, which does not change. The other `hostPath`
directly above (`/etc/kubernetes/pki/etcd`, `name: etcd-certs`) is **not** it.

```bash
# ▶▶ cp1
sudo vim /etc/kubernetes/etcd.yaml                 # the parked copy
#   G → ↑ to "path: /var/lib/etcd" above "name: etcd-data" → A → -restore → Esc → :wq
sudo grep -B2 'name: etcd-data' /etc/kubernetes/etcd.yaml
#   mountPath: /var/lib/etcd (unchanged) · path: /var/lib/etcd-restore (changed)
sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/
sudo crictl ps | grep -E 'etcd|kube-apiserver'      # etcd first, then apiserver. 1–2 min
```

Why not `sed`: an unscoped `s|/var/lib/etcd|…|` rewrites all three.

### 🔍 PROVE

```bash
# ▶▶ cp1
kubectl get nodes                          # 3× Ready — discard the first answer
kubectl get <the object the task names>    # the scored proof
```

In the lab, prove it with two markers: a ConfigMap created **before** the save
(must survive) and a ConfigMap + Deployment created **after** it (must vanish).
Within a minute the kubelets also kill the after-snapshot nginx containers — the
API no longer knows them. **etcd decides, the nodes obey.**

### Traps

| Error | Cause |
|---|---|
| `after-snap` still there after the restore | The `hostPath` edit was skipped — the restore worked, nobody reads it |
| `x509: unknown authority` | `pki/ca.crt` instead of `pki/etcd/ca.crt` — Kubernetes CA ≠ etcd CA |
| connection refused / TLS error | `http://` or port 2380 — clients are **https**, **2379** |
| `permission denied` | No `sudo`: `server.key` is root-only |
| `etcdutl` refuses to restore | `--data-dir` already exists — new name every run |
| 404 downloading etcd | Image tag `3.6.6-0` used as the release `v3.6.6` |
| `no such file or directory` on the manifests | `/etc/kubernetes/manifests/` — `etc` not `etcd`, plural |
| `get <type>` lists an object that `get <type> <name>` says is NotFound | The API server served its **watch cache**. It never restarted. Restart it, and never restore without stopping the control plane |
| `unknown command` on `etcdutl status` | The group is `snapshot`: `etcdutl snapshot status` |
| ⏳ `etcdctl snapshot restore` | Believed removed in etcd 3.6 (only `save` left). Verify with `etcdctl snapshot --help` and record it here |

📚 `kubectl edit` is useless on static Pods: the API shows a read-only **mirror
pod**, the file is the original — and during a restore the API is down anyway.

### Command card — 1.4b etcd save / restore

```
SAVE      sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
            --cacert=/etc/kubernetes/pki/etcd/ca.crt \
            --cert=/etc/kubernetes/pki/etcd/server.crt \
            --key=/etc/kubernetes/pki/etcd/server.key \
            snapshot save <file>
VERIFY    sudo etcdutl snapshot status <file> -w table
STOP      sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/   (crictl ps: gone)
RESTORE   sudo etcdutl snapshot restore <file> --data-dir=/var/lib/etcd-restore
EDIT      sudo vim /etc/kubernetes/etcd.yaml → volumes → etcd-data → hostPath.path (ONLY this)
START     sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/   (crictl ps: back)
PROVE     kubectl get <the object the task names>
```

🧪 **Two unrelated things share a word.** `multipass snapshot` freezes a virtual
machine and is scaffolding. **`etcd snapshot` freezes cluster state and is a
scored exam task.** Restoring the VM is cheating on an etcd task.

⚠️ **EKS:** no endpoint, no certificates, no snapshot, no restore — etcd is
unreachable. Cluster backup on EKS happens at the **API-object level** (e.g.
Velero), never at the etcd level. You have also never had a control plane to stop,
nor seen a control-plane `hostPath`; on EKS `hostPath` only appears in agent
DaemonSets.

---

## §C. Certificates and the PKI ⚙️

**Runs on: cp1.**
**Theory →** notes_01 §2.1 · **Docs →** search
`certificate management with kubeadm` · **Target: 6 min**

### The shape

| # | What we do | Why |
|---|---|---|
| 1 | `certs check-expiration` | See what expires and when — also the answer to "which ones?" |
| 2 | `certs renew all` | Replaces the **leaves**; the CAs are untouched |
| 3 | Restart the control plane (§S manoeuvre) | Static Pods hold the old certs **in memory** |
| 4 | Re-copy `admin.conf` to `~/.kube/config` | Your kubeconfig is a **copy**, and it is now stale |
| 5 | `check-expiration` again + `get nodes` | Proves both ends: renewed, and you can still connect |

Two lifetimes, and everything follows from them: **leaf certificates last 1 year,
the CAs last 10.** A renewal replaces the leaves and leaves the trust anchor
alone — which is why clients keep working across a renewal.

```bash
# ▶▶ cp1
sudo kubeadm certs check-expiration
sudo kubeadm certs renew all         # also renews the certs inside /etc/kubernetes/*.conf

# restart the control plane so it loads them (§S manoeuvre)
sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/ → crictl ps until empty → sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/

# your own kubeconfig is a COPY — it is now stale
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

**Verify:** `sudo kubeadm certs check-expiration` → every leaf ~364 days ·
`kubectl get nodes` still works.

### Command card — §C certificates

```
SEE       sudo kubeadm certs check-expiration
RENEW     sudo kubeadm certs renew all
RESTART   sudo mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/ → crictl ps until empty → sudo mv /etc/kubernetes/*.yaml /etc/kubernetes/manifests/
KUBECONF  sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config
PROVE     sudo kubeadm certs check-expiration   (leaves ~364d)  +  kubectl get nodes
```

The kubelet's own cert (`/var/lib/kubelet/pki/`) rotates by itself and never
appears here.

### Why `~/.kube/config` survived the upgrade

It is an **independent copy** of `admin.conf`, with three things embedded in
base64: `certificate-authority-data` (the cluster CA), `client-certificate-data`
(your admin cert) and `client-key-data`.

`kubeadm upgrade apply` rotated the **leaves** but not the **CA**. Same trust
anchor on both ends: the API server presents a *new* cert signed by the *same*
CA your copy trusts, and you present an *old but valid* cert signed by the same
CA the server trusts. Both sides still validate.

⚠️ **But the two files have now diverged.** `/etc/kubernetes/admin.conf` holds a
fresh cert; your copy holds the old one. And **`kubeadm certs check-expiration`
is blind to your copy** — it reads `/etc/kubernetes/`. When your copy's client
cert expires it will still report `admin.conf` as healthy while you cannot
connect.

> **After any `certs renew`, re-copy `admin.conf`.** Not optional.

**What actually breaks a kubeconfig:**

| Cause | Symptom |
|---|---|
| Client cert expired (1 year) | `Unauthorized` → `certs renew` + **re-copy** |
| **CA** regenerated (cluster rebuilt) | Nothing saves the old copy |
| `server:` URL changed (new advertise address, `--control-plane-endpoint`) | `connection refused` or a SAN mismatch |
| 🧪 Clock skew after a VM restore | `x509: certificate has expired or is not yet valid` — **not a certificate problem**, see `cka-D1.md §0.3` |

### Traps

| Error | Cause |
|---|---|
| `check-expiration` says 364d but `kubectl` still fails | The control plane was not restarted — the old certs are in memory |
| `renew` changed only one line | `renew <name>` is selective; the task asked for `renew all` |
| Locked out right after renewing | `~/.kube/config` is a **copy**; re-copy `admin.conf` |
| `permission denied` reading the kubeconfig | Missing `chown` after `sudo cp` |
| `invalid: not yet valid` in the lab | VM clock skew after a snapshot restore — compare with `date`, not a cert problem |
| Looking for certs on a worker | They exist only on cp1; the kubelet's own cert rotates itself |
| Leaves already fresh before you renewed | `kubeadm upgrade apply` renews them. Expected, not an error |
| `grep controller` in the restart check | Matches `calico-kube-controllers`. Use `kube-controller-manager` |

**Run 19 Sep, measured:** `renew apiserver` moved that one line to 364d and left
the other ten at 361d — proof that `renew` is selective and that the CAs
(Aug 2036) are never touched. After the restart, all four came back with
`ATTEMPT 0`. The control plane does not die at once: scheduler and
controller-manager exit first, etcd and the API server take ~30 s longer, so
wait for **all four** to disappear.

**What cannot be done imperatively:** changing a certificate's lifetime. One year
is the built-in default; changing it means an external CA, and that is out of
scope for CKA.

⚠️ **EKS:** you never see a `.crt`. AWS rotates the control-plane PKI; the only
thing resembling this is the kubelet cert on your nodes, which rotates itself.

## 1.4c Node lifecycle — drain, delete, re-join ⚙️

**Runs on: cp1, plus `ssh <node>`.**
**Docs →** search `safely drain a node` · `kubectl drain --help` ·
**Target: 5 min**

### The shape

| # | What we do | Why |
|---|---|---|
| 1 | `drain` the node | Move the workloads off before touching it |
| 2 | `delete node` | Removes the **API object**; the machine is still running |
| 3 | `kubeadm reset -f` on the machine | Wipes its cluster state — without this the re-join is half-broken |
| 4 | Mint a join command on cp1 | Tokens expire (24 h); you always make a new one |
| 5 | `kubeadm join` on the machine | It comes back as a fresh node |
| 6 | Verify `Ready`, not `SchedulingDisabled` | A node that returns cordoned is a silent half-failure |

```bash
# ▶▶ cp1 — imperative, all of it
kubectl cordon w2                                            # mark unschedulable, evict nothing
kubectl drain w2 --ignore-daemonsets --delete-emptydir-data  # cordon + evict
kubectl uncordon w2
kubectl delete node w2                                       # removes the OBJECT only
kubeadm token create --print-join-command                    # mint a new join command
```
```bash
# ▶▶ w2 — the machine must be cleaned before it can re-join
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo kubeadm join ...          # from the printed command
```

**Verify:** `kubectl get nodes` → the node returns, `Ready`, not
`SchedulingDisabled`.

### Command card — 1.4c node lifecycle

```
OFF       kubectl drain <node> --ignore-daemonsets --delete-emptydir-data   [cp1]
REMOVE    kubectl delete node <node>                                        [cp1]
CLEAN     sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d               [the node]
TOKEN     kubeadm token create --print-join-command                         [cp1]
JOIN      sudo kubeadm join …   (paste the printed line, add sudo)          [the node]
LABEL     kubectl label node <node> node-role.kubernetes.io/worker=         [cp1]
PROVE     kubectl get nodes   → Ready, NOT SchedulingDisabled, role back    [cp1]
          kubectl get pods -A -o wide | grep <node>   → DaemonSets 1/1      [cp1]
```

If the task only asks for maintenance, it stops at `drain` + `uncordon`.

**`delete node` stops the workloads within seconds (measured 19 Sep).** The
kubelet keeps a watch open against the API; when the Node object disappears the
answer becomes "no Pods for you", and the kubelet shuts its containers down —
the same rule as the etcd restore: **the API decides, the kubelet obeys.** What
survives on the machine is the kubelet itself, containerd, and the cluster files
on disk. Those files are what `kubeadm reset` removes.

**Readiness ≠ running (19 Sep):** `calico-node` showed `0/1 Running` for ~15 s
after the join. `Running` means the container started; `1/1` means it passed its
readiness probe. Verify on `1/1`.

### Traps

| Error | Cause |
|---|---|
| `localhost:8080 connection refused` | `drain`, `delete node` or `token create` run on the worker — it has no kubeconfig. They are **API calls**: run them where a kubeconfig is |
| `drain` refuses to start | Missing `--ignore-daemonsets` (plural) or `--delete-emptydir-data` |
| `drain` hangs on a Pod | A PodDisruptionBudget honoured by the Eviction API. Correct behaviour — wait |
| Pods with no controller disappear for good | `--force` deletes them and nothing recreates them |
| Node returns as `ROLES <none>` | The role label is not inherited: `kubectl label node <n> node-role.kubernetes.io/worker=` |
| `join` fails or the node is half-broken | `kubeadm reset -f` was skipped |
| Yesterday's token is rejected | Tokens expire in 24 h — mint a new one |
| `kubeadm reset` run on cp1 | It wipes `/var/lib/etcd` — the cluster is gone |
| `delete node` done when only maintenance was asked | `drain` + `uncordon`, nothing else |
| Verified on `Running` instead of `1/1` | `Running` = started · `1/1` = passed the readiness probe |
| cordon used where drain was meant | `cordon` stops **new** Pods only; `drain` also evicts the running ones |

**What cannot be done imperatively:** nothing — `cordon`, `drain`, `uncordon`,
`taint`, `label`, `delete node` and `kubeadm token create` are all one-liners.

⚠️ **EKS:** you delete a node by terminating an instance, and the node group
replaces it. `kubeadm reset` has no analogue.

---

## 1.5 Highly-available control plane ⚙️ READ, do not build

**Runs on: nothing.** This bullet is read and answered.
**Theory →** notes_01 §1.4 · **Docs →** search `high availability topology` ·
**Target: recognise and answer, 4 min**

### The shape

| # | What we answer | Why it is asked |
|---|---|---|
| 1 | Stacked or external etcd | The only two topologies kubeadm supports |
| 2 | How many members | Quorum is `n/2 + 1`, integer division |
| 3 | What `init` needs | `--control-plane-endpoint` cannot be added later |
| 4 | How a second control-plane node joins | `--control-plane` + `--certificate-key` |

Two topologies: **stacked** (etcd as a static Pod on each control-plane node —
kubeadm's default) and **external** (etcd on its own machines). Stacked couples
control-plane loss to etcd-member loss; external survives it and costs more
machines.

Quorum is `n/2 + 1`, **integer division**: 3 members → quorum 2, tolerates 1;
5 → quorum 3, tolerates 2. **Even numbers buy nothing.**

```bash
# first control-plane node, behind a load balancer on :6443
sudo kubeadm init --control-plane-endpoint "k8s-lb:6443" --upload-certs
# additional control-plane nodes
sudo kubeadm join k8s-lb:6443 --token <t> --discovery-token-ca-cert-hash sha256:<h> \
  --control-plane --certificate-key <key>
```

**Traps:** `--control-plane-endpoint` **cannot be added later** without
regenerating certs — it must be present at `init` · `--certificate-key` expires
in **2 h** (`kubeadm init phase upload-certs --upload-certs` regenerates it) · a
**worker** join has neither `--control-plane` nor `--certificate-key`.

### Decision card — 1.5 HA

```
TOPOLOGY   stacked = etcd static Pod on each CP node (kubeadm default)
           external = etcd on its own machines (survives CP loss, more machines)
QUORUM     n/2 + 1  →  3 members: quorum 2, tolerates 1 · 5: quorum 3, tolerates 2
           even numbers buy nothing
INIT       --control-plane-endpoint "<lb>:6443" --upload-certs   (NOT addable later)
CP JOIN    --control-plane --certificate-key <key>      (key expires in 2 h)
W JOIN     neither of those two flags
```

### Joining a control-plane node — the half you CAN practise

A CP join is a worker join plus two flags. The `certificate-key` comes from a
Secret that `upload-certs` writes, and both halves are safe to produce on a
single-node lab: only the final `join` needs a machine you do not have.

```bash
# ▶▶ cp1 — 1) publish the CAs into the kubeadm-certs Secret and get the key
sudo kubeadm init phase upload-certs --upload-certs     # prints the certificate key
kubectl -n kube-system get secret kubeadm-certs         # 8 entries: the 3 CAs + keys + SA key pair

# ▶▶ cp1 — 2) mint the join command, then append the two CP flags
kubeadm token create --print-join-command
#   → kubeadm join <ep>:6443 --token <t> --discovery-token-ca-cert-hash sha256:<h>
#   + --control-plane --certificate-key <key>
```

```bash
# ▶▶ THE NEW MACHINE (cp2) — never on cp1
sudo kubeadm join <ep>:6443 --token <t> --discovery-token-ca-cert-hash sha256:<h> \
  --control-plane --certificate-key <key>
```

🔴 **`join` is not the opposite of `drain`.** `drain`/`delete node` remove a node
that is **inside** the cluster; `join` admits a machine that is **outside** it.
A join needs a clean machine — freshly installed, or `kubeadm reset -f`. Running
that command on cp1 tells the control plane to join itself.

### Restoring etcd with several members — recognise the shape

One snapshot, restored **on every member**, each with its own identity flags.
The single-node command drilled in 1.4b is the degenerate case.

```bash
# ▶▶ on EACH control-plane node — same snapshot file, different --name / peer URL
sudo etcdutl snapshot restore snap.db \
  --name cp1 \
  --initial-cluster cp1=https://10.0.0.1:2380,cp2=https://10.0.0.2:2380,cp3=https://10.0.0.3:2380 \
  --initial-advertise-peer-urls https://10.0.0.1:2380 \
  --data-dir /var/lib/etcd-restore
```

Why the extra flags: a restore **rewrites the membership** — that is the
`Trimming membership information` line in the 1.4b log. Without them each member
comes back believing it is a one-member cluster. Then every node gets the same
`hostPath` edit and all three control planes restart.

**Probability check:** the CKA environment is single-control-plane. A multi-member
restore does not fit a graded task, and a CP join, if it appears, arrives with
the command in the statement. **Read it, recognise it, do not build it.**

🧪 Your lab has one control-plane node. A fourth VM plus 4 hours would buy less
than 4 hours of troubleshooting practice. **Decided, not deferred.**

---

## §9. Exam mode — Set 1 (lifecycle) · 3 tasks · 20 min

Wording as the CKA phrases it. No verification handed to you. No `multipass`
between the start and the stop — if you break it, fix it forward.

🧪 **Start from `lab-v134`** (1.34.11, alias, crictl, etcd 3.6.5 on cp1).
Everything Set 1 needs is inside it — no setup before the clock.

```
Task 1  (weight 8%)                                          target 12 min
Context: k8s-lab

The cluster is running v1.34.11. Upgrade the control plane node cp1 and the
worker node w1 to v1.35.8. Do not upgrade w2.
Ensure that after the upgrade both upgraded nodes are able to accept workloads.
```

```
Task 2  (weight 7%)                                           target 5 min
Context: k8s-lab

Create a snapshot of the etcd database at /opt/etcd-backup.db and verify that
the snapshot file is valid. Do not stop any cluster component.
```

```
Task 3  (weight 4%)                                           target 4 min
Context: k8s-lab

Node w2 is scheduled for hardware maintenance. Evacuate it so that no workload
runs on it and no new workload is scheduled to it. DaemonSet-managed Pods may
remain. Do not delete the node.
```

### Variations — the same task as the exam actually rewords it

Drill these once each; the shape changes, the procedure does not.

| Variation | What it really tests |
|---|---|
| "Upgrade **only** the control plane node" | Do you stop, or do you touch the workers anyway |
| "**Finish** the upgrade — cp1 has already been upgraded" | Can you recognise the current state before acting |
| "After the upgrade the node accepts no workloads. Fix it." | `uncordon` |
| "Upgrade to **1.36**" from 1.34 | One minor at a time — the answer is *two* upgrades, or a refusal |
| "Restore etcd from `/opt/backup.db`. The object `x` must exist afterwards." | The verification is named in the task; step 3 (hostPath) is where it fails |

<details>
<summary>Self-verification — open only after the clock stops</summary>

```bash
# Task 1
kubectl get nodes    # cp1 v1.35.8 Ready · w1 v1.35.8 Ready · w2 v1.34.11 Ready
                     # NOTHING SchedulingDisabled
# Task 2
sudo etcdutl snapshot status /opt/etcd-backup.db --write-out=table
# Task 3
kubectl get nodes    # w2 Ready,SchedulingDisabled
kubectl get po -A -o wide --field-selector spec.nodeName=w2   # DaemonSet Pods only
```

</details>

| Task | Score | Time | Root cause code |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
