---
domain: D1 — Application Design and Build
group: 3 — Shape the Pod
bullets: [1.3, 1.4]
exams: [CKAD]
index: ckad-D1.md
theory: notes_03, notes_04, notes_06
k8s_version: v1.37.2 (ckad-v137)
status: 'r2 — Template C, measured on ckad-v137 (21 Nov 2026)'
revision: '2026-11-21 (r2 — Template C: shape, whiteboard measured on ckad-v137, cards, traps, EKS, §9 Set 1 with verified graders) · 2026-11-13 (r1 — split out of ckad-D1.md, skeleton)'
---

# D1 · Group 3 — Shape the Pod (bullets 1.3, 1.4)

> Index, drill table, scoreboard and where every command runs: **`ckad-D1.md`**.
> Session: **Wed 9 Dec** (`plan.md §10.2`). Objectives and the reported-task list
> (R#): `ckad-curriculum.md`. Reference implementation of the format:
> `cka/cka-D1-2-lifecycle.md`.
>
> What unites these two: what goes *inside* one Pod — how many containers share it
> (1.3) and where its data lives (1.4). The shared `emptyDir` of 1.3 is the first
> volume of 1.4, so 1.3 comes first.
>
> **Nothing in this file is imperative past the first line.** `k run … $do` gives you
> one container; init containers, sidecars, volumes, PVs and PVCs have no `kubectl
> create` verb and no flag. The skill is: generate the skeleton, then add the right
> block **from the docs page** in the right place, with two-space indentation.

---

## Legend — what to type in the exam, what is only for learning

| Mark | Meaning | In the exam |
|---|---|---|
| 🎯 | **Exam path** — the task is not done without it | type it |
| 🔍 | **Verification** — proves the task worked | type it, once, at the end |
| ⏱ | **Waiting** — fixed machine time, cannot be shortened | start another task, come back |
| 📚 | **Study only** — teaches the mechanism, scores nothing | skip |
| 🧪 | **Scaffolding** — exists because this is a home lab | never appears in the exam |

**Rule that outranks the marks:** whatever the task statement spells out — a name, a
path, an image, a mount point, a size — is literal. 🎯 blocks show defaults, not orders.

**Typing conventions** (same as CKA, `cka-D1-2-lifecycle.md`): `$do` =
`--dry-run=client -o yaml`; literals into shell variables before the first command
(the 8 Nov method); existing object → `k get … -o yaml > f.yaml` **before** editing.

Card index: **1.3** multi-container Pod (init · sidecar · probe) · **1.4** volumes
(emptyDir · hostPath · PV + PVC + Pod).

---

## 1.3 Understand multi-container Pod design patterns ⚙️

**Runs on: cp1** (exam: the task's host). · **Theory →** note 04 §1.4 (what a Pod shares),
note 03 §1.4 · **Docs →** search `init containers` · `sidecar containers` ·
**`kubectl explain`** `pod.spec.initContainers` · `pod.spec.initContainers.restartPolicy` ·
**Target: 6:00** (R14) · **7:00** (sidecar into a Deployment) · **Reported: R14** (init half;
the probe half is `ckad-D3-1-health.md` 3.2)

### The shape

**The idea.** One Pod, several containers that share one network and the volumes you
give them: an **init container** runs to completion *before* the app, a **sidecar**
runs *beside* the app for its whole life, and an **`emptyDir`** is how they pass files.
It does not cover probe types and timings (D3 3.2) or persistent data (1.4).

**Analogy — a food truck.** The *prep cook* (init container) chops everything before
the window opens and goes home. The *chef* (app container) cooks while the window is
open. The *cashier* (sidecar) works next to the chef all shift, and leaves when the
chef leaves. The *pass-through shelf* (`emptyDir`) is the only place they can hand
things to each other — each one has their own pockets (filesystem).

| # | Step | What it does | Why (the failure it prevents) | Watch out | Exam? |
|---|---|---|---|---|---|
| 1 | Generate the skeleton | `k run … $do` writes a one-container Pod | Typing `apiVersion`/`metadata` by hand costs a minute and invites typos | The container name defaults to the **Pod name** (`k run`) or the **image name** (`k create deploy`) | 🎯 |
| 2 | Add the shared volume | `spec.volumes` with an `emptyDir` | Containers do **not** share a filesystem; without it the init's file never reaches the app | `volumes` is at **Pod** level, `volumeMounts` at **container** level — two halves | 🎯 |
| 3 | Add the init container | `spec.initContainers`: runs to completion, in order, before any app container | The app starts against a file that does not exist yet | Mount the volume in the init **too**; an init that exits non-zero loops forever (`Init:CrashLoopBackOff`) | 🎯 |
| 4 | Add the sidecar | Native: an `initContainers` entry with `restartPolicy: Always`. Classic: a second entry in `containers` | A helper (log shipper, proxy) that must live as long as the app | Native starts **first** and does not block a Job's completion; an init **without** `restartPolicy: Always` that never exits blocks the Pod at `Init:0/1` | 🎯 |
| 5 | Add the probe the task asks for | `readinessProbe.exec` on the **app** container | A Pod reported Ready before its precondition holds | The probe goes on the container that serves, never on the init | 🎯 |
| 6 | Apply / roll out, then prove | `apply`; for an existing Pod `replace --force`; for a Deployment it rolls | A Pod's container list is immutable — `apply` is refused | `logs`/`exec` need **`-c <name>`** once there is more than one container | 🔍 |

**How it connects — the symptom tells you the missing step**

| Missing / wrong | What you see |
|---|---|
| Volume not mounted in the init (2–3) | `Init:Error` → `Init:CrashLoopBackOff` (the init cannot write `/work/…`) |
| Volume not mounted in the app (2) | Pod `0/1 Running`, event `Readiness probe failed: cat: /work/ready: No such file or directory` |
| Init exits non-zero (3) | `Init:Error`, then `Init:CrashLoopBackOff`; `logs <pod>` → `waiting to start: PodInitializing` |
| Sidecar placed in `initContainers` without `restartPolicy: Always` (4) | Pod stuck at `Init:0/1` forever, no error |
| Classic sidecar in a Job (4) | Job never completes: Pod `1/2 NotReady`, `COMPLETIONS 0/1` |
| Container added to a live Pod with `apply` (6) | `spec.containers: Forbidden: pod updates may not add or remove containers` |
| No `-c` on a multi-container Pod (6) | `Defaulted container "app" out of: app, tail (init)` — you read the wrong container's logs |

**What is what**

| 🎯 type it in the exam | 🔍 check it | 📚 understanding only |
|---|---|---|
| `k run … $do > f.yaml` · the `volumes` / `initContainers` / `volumeMounts` blocks from the docs · `restartPolicy: Always` on a sidecar · `readinessProbe.exec` · `replace --force` | `get pod` READY + STATUS · `logs -c` · `exec -c … -- cat` · `describe pod` events | ambassador (proxy to the outside) and adapter (reformat output) — same mechanics, different job · `shareProcessNamespace` · the pause container |

**Mnemonic — S·V·I·S·P·A: "Sixteen Vegans Invaded Sam's Pizza Again."**
**S**keleton → **V**olume → **I**nit → **S**idecar → **P**robe → **A**pply.
Why this order: every container block references the volume by name, so the volume
exists first; the init must be in place before you decide what the app can assume;
the probe tests what the init produced, so it is written last, against a known path.

### The whiteboard

#### Step 1 — the skeleton (🎯, 20 s)

```bash
# ▶▶ cp1 — ubuntu@cp1
N=NS; P=POD                                   # literals first
k -n $N run $P --image=nginx:1.29 $do > p.yaml
```

Measured output (trimmed) — note the container name = Pod name:

```yaml
spec:
  containers:
  - image: nginx:1.29
    name: web
    resources: {}
  restartPolicy: Always
```

Delete `resources: {}`, `dnsPolicy`, `status: {}` if they bother you; they are harmless.
For a Deployment: `k create deploy D --image=IMG $do` — its container is named after the
**image** (`busybox`), not the Deployment (measured). If the task names the container,
change `name:`.

#### Steps 2–3 — shared volume + init container (🎯)

Docs page `init containers` → copy the `initContainers:` block; page `volumes` →
`emptyDir`. Result, as measured on v1.37.2:

```yaml
spec:
  volumes:                     # Pod level — declares the shelf
  - name: shared
    emptyDir: {}
  initContainers:              # runs to completion, in order, before containers
  - name: prep
    image: busybox:1.28
    command: ["sh","-c","echo ok > /work/ready"]
    volumeMounts:              # container level — puts the shelf in this container
    - name: shared
      mountPath: /work
  containers:
  - name: web
    image: nginx:1.29
    volumeMounts:
    - name: shared
      mountPath: /work
```

| Field | Level | Rule |
|---|---|---|
| `volumes[].name` | Pod | the name every `volumeMounts` refers to |
| `volumeMounts[].mountPath` | container | may differ per container; the **data** is the same |
| `initContainers` | Pod | same schema as `containers`; run **sequentially**, each must exit 0 |

STATUS through the phases, measured (`get pods` every 3 s; `web` is the good Pod with an
8 s init, `bad` an init that `exit 1`):

```
bad   0/1   Init:0/1                0             0s
web   0/1   Init:0/1                0             0s
bad   0/1   Init:Error              1 (2s ago)    3s
bad   0/1   Init:CrashLoopBackOff   1 (4s ago)    6s
web   1/1   Running                 0             9s
```

READY counts **app** containers only (`1/1`, the init is not in it). Reading the failing
init:

```bash
# ▶▶ cp1
k -n $N logs bad                 # → Defaulted container "app" out of: app, prep (init)
                                 #   Error … container "app" … is waiting to start: PodInitializing
k -n $N logs bad -c prep         # → the init's own output — the real clue
```

#### Step 4 — the sidecar: native vs classic (🎯)

Two ways to run a helper next to the app. **Prefer native** when the task says the
helper must *start before* the app, or the Pod belongs to a **Job**; write classic when
the task literally says "add a second container".

```yaml
# native sidecar — an init container that never "completes"
  initContainers:
  - name: log-agent
    image: busybox:1.28
    restartPolicy: Always          # ← this one line makes it a sidecar
    command: ["sh","-c","tail -F /var/log/app.log"]
    volumeMounts: [{name: logs, mountPath: /var/log}]
# classic sidecar — just a second app container
  containers:
  - name: app …
  - name: log-agent …
```

| | Native (`initContainers` + `restartPolicy: Always`) | Classic (second `containers` entry) |
|---|---|---|
| Starts | **before** the app containers (then the next init/app starts at once) | at the same time as the app |
| READY column (measured) | `2/2` — counted | `2/2` — counted |
| In a Job | Job **completes** (measured: `Complete 1/1`) | Job **never completes** (measured: `1/2 NotReady`, `0/1` after 44 s) |
| `logs` without `-c` | `Defaulted container "app" out of: app, tail (init)` | `Defaulted container "app" out of: app, tail` |

`kubectl explain pod.spec.initContainers.restartPolicy` (v1.37.2) says it in one line:
the init container "will be continually restarted on exit until all regular containers
have terminated … often referred to as a 'sidecar' container". Search term on
kubernetes.io: `sidecar containers`.

⚠️ Measured trap: `restartPolicy: Always` written on a **regular** container is
**accepted** by v1.37 (`kubectl apply --dry-run=server` → `created`) — it is a different
feature (per-container restart rules) and does **not** make a sidecar. The field must sit
under `initContainers`.

#### Step 4b — adding a sidecar to an **existing Deployment** (🎯, 7:00)

The template of a Deployment is editable and **rolls**; a bare Pod's container list is
not. Path:

```bash
# ▶▶ cp1
k -n $N get deploy D -o yaml > d.yaml       # backup + working file
vim d.yaml                                  # add: volumes, the sidecar, the app's volumeMounts
k apply -f d.yaml                           # (or: k -n $N edit deploy D)
k -n $N rollout status deploy D             # ⏱ ~10 s
```

Measured rollout (2 replicas): a new ReplicaSet, Pods `2/2`, the old ones `1/1 Terminating`.
Three things you add, all with the **same volume name**: `spec.template.spec.volumes`, the
sidecar's `volumeMounts`, and a `volumeMounts` on the **existing** container (the app must
write into the shared directory, or the sidecar tails an empty file).

🔍 Proof — and a measured trap:

```bash
# ▶▶ cp1
k -n $N logs deploy/D -c log-agent --tail=3
# right after the rollout this printed:
#   Found 4 pods, using pod/api-7b7d574d8f-xtz8t
#   error: container log-agent is not valid for pod … out of: busybox
# → it picked an OLD, Terminating Pod. Wait for rollout status, then re-run:
#   Found 2 pods, using pod/api-66c887cfc9-q8lc6
#   Sat Nov 21 20:23:08 UTC 2026
```

#### Step 5 — the probe R14 needs (🎯, details in D3 3.2)

```yaml
  containers:
  - name: web
    …
    readinessProbe:
      exec:
        command: ["cat","/work/ready"]
      periodSeconds: 5
```

Without the file (no shared volume), measured: Pod `0/1 Running`, event
`Readiness probe failed: cat: /work/ready: No such file or directory`. A failing
**readiness** probe never restarts the container — it only keeps the Pod out of Service
endpoints (that is liveness's job; D3).

#### Step 6 — apply, and the immutable container list (🎯)

```bash
# ▶▶ cp1 — adding a container to a Pod that already exists
k -n $N get pod P -o yaml > p.yaml ; vim p.yaml
k apply -f p.yaml
#   The Pod "web" is invalid: spec.containers: Forbidden: pod updates may not add or remove containers
k replace --force -f p.yaml
#   pod "web" deleted from d13-m namespace
#   pod/web replaced
```

🔍 Final proof, every task: `k -n $N get pod P` (READY n/n) · `k -n $N logs P -c C` ·
`k -n $N exec P -c C -- cat /path`.

📚 **Recognise only — ambassador and adapter.** Same mechanics as a sidecar (a helper
container in the Pod), named by its job: an **ambassador** proxies the app's outbound
connections (the app talks to `localhost`, the ambassador to the real backend); an
**adapter** rewrites the app's output into a standard format (e.g. logs → JSON, metrics
→ Prometheus). The exam asks you to *build* the container, not to name the pattern.

### Command card — 1.3

```
LITERALS  N=… P=… ; k -n $N run $P --image=IMG $do > p.yaml   (deploy: get -o yaml > d.yaml)
VOLUME    spec.volumes: - name: V  emptyDir: {}
INIT      spec.initContainers: - name/image/command + volumeMounts V → /path
SIDECAR   initContainers entry + restartPolicy: Always  (or 2nd containers entry if asked)
MOUNT     same V in EVERY container that reads or writes it
PROBE     readinessProbe.exec.command on the APP container
APPLY     k apply -f   (live Pod → k replace --force -f)  · deploy → rollout status
PROVE     get pod (n/n) · logs -c C · exec -c C -- cat /path
```

### Traps

| Error | Cause |
|---|---|
| `Init:Error` → `Init:CrashLoopBackOff` | The init exits non-zero — usually it writes to a path it has not mounted |
| `Init:0/1` forever, no event | A long-running helper in `initContainers` **without** `restartPolicy: Always` |
| `Readiness probe failed: … No such file or directory` | The app container does not mount the shared volume, or the paths differ |
| `spec.containers: Forbidden: pod updates may not add or remove containers` | `apply` on a live Pod — use `replace --force` (or edit the Deployment) |
| `container X is not valid for pod … out of: busybox` | `logs deploy/D -c X` picked an old Pod mid-rollout — wait for `rollout status` |
| `Defaulted container "app" out of: …` and the wrong output | No `-c` on a multi-container Pod |
| Job stuck `0/1`, Pod `1/2 NotReady` | Classic sidecar in a Job — make it native |
| Sidecar container named `busybox` | `create deploy` names the container after the image — rename if the task names it |
| Sidecar "works" but tails nothing | Volume mounted in the sidecar but not in the app container |

⚠️ **EKS:** no difference in the API. In practice the sidecars you meet on EKS are
**injected** (App Mesh/Istio Envoy, the CloudWatch/Fluent Bit agent, the IRSA token
volume) by a mutating webhook — you see them in `get pod -o yaml` without having
written them. The exam makes you write them by hand.

---

## 1.4 Utilize persistent and ephemeral volumes ⚙️

**Runs on: cp1** (exam: the task's host). · **Theory →** note 06 §1.3 (ephemeral),
note 06 §1.4 and §1.5 (PV/PVC, binding), note 06 §1.8 (access modes), note 06 §1.9
(reclaim), note 06 §1.12 (Pending PVC) · **Docs →** search
`Configure a Pod to Use a PersistentVolume for Storage` (PV + PVC + Pod in three blocks)
· `volumes` (emptyDir, hostPath) · **`kubectl explain`** `pv.spec` · `pvc.spec` ·
`pod.spec.volumes.emptyDir` · **Target: 7:00** (PV + PVC + Pod) · **3:00** (emptyDir) ·
**Reported:** not in the list — still 1 of 4 bullets of a 20% domain

### The shape

**The idea.** A Pod gets a directory either for **its own lifetime** (`emptyDir`,
`hostPath`) or from **storage that outlives it** — a **PersistentVolume** (the disk) that
a **PersistentVolumeClaim** (the request) binds to, and the Pod mounts the **claim**,
never the PV. ConfigMap / Secret / projected volumes are the same `volumes` mechanism
but belong to D4 (`ckad-D4-1-config.md`).

**Analogy — a hotel.** `emptyDir` is the **room's minibar**: it exists while you are
checked in, and it is emptied when you check out (the Pod is deleted). `hostPath` is the
**luggage room of one specific hotel** — it stays, but only in that building (node). A
PV is a **safe-deposit box** the manager installs; the PVC is your **request form**
("one box, at least 500 Mi, for one guest, type *manual*"); the reception desk (the PV
controller) hands you the box only if *every* line of the form matches a box; the Pod
says "my box is the one on form `data`" — it never names the box.

| # | Step | What it does | Why (the failure it prevents) | Watch out | Exam? |
|---|---|---|---|---|---|
| 1 | Decide the lifetime | Pod-lifetime → `emptyDir`; node directory → `hostPath`; survives the Pod → PV + PVC | Data lost on a Pod delete, or a PV built where scratch space was asked | `emptyDir` survives **container** restarts, not Pod deletion | 🎯 |
| 2 | Ephemeral: write the `volumes` entry | `emptyDir: {}` · `medium: Memory` + `sizeLimit` · `hostPath: {path, type}` | — | `medium: Memory` is a tmpfs capped at `sizeLimit` and counts against memory | 🎯 |
| 3 | Persistent: the PV (cluster-scoped) | capacity, `accessModes`, `storageClassName`, backend (`hostPath` in a lab) | No PV → a PVC with no provisioner stays `Pending` | **No namespace** on a PV; static PVs default to `Retain` (measured) | 🎯 |
| 4 | The PVC (namespaced) | request ≤ PV capacity, same access mode, **same class** | Any mismatch → `Pending`, and the Pod behind it `Pending` | The event says `storageclass "manual" not found` even when the real cause is size or mode | 🎯 |
| 5 | The Pod mounts the claim | `volumes[].persistentVolumeClaim.claimName` + `volumeMounts` | — | Pod references the **PVC** name, never the PV | 🎯 |
| 6 | Prove | `get pv,pvc` (Bound, CLAIM column) · write and read back · delete the Pod, read again | "Created" is not "Bound" | A `hostPath` PV is **node-local**: a Pod on another node sees an empty directory (measured) | 🔍 |

**How it connects — the symptom tells you the missing step**

| Missing / wrong | What you see |
|---|---|
| No matching PV — size, mode or class (3–4) | PVC `Pending`, event `ProvisioningFailed … storageclass.storage.k8s.io "manual" not found` |
| PVC class omitted, PV has a class (4) | PVC `Pending` — omitted binds only to PVs with **no** class (lab has no default SC) |
| Pod points at a Pending PVC (5) | Pod `Pending`, `0/3 nodes are available: pod has unbound immediate PersistentVolumeClaims` |
| Pod points at a PVC that does not exist (5) | Pod `Pending`, `persistentvolumeclaim "ghost" not found` |
| PVC deleted, recreated, expects the old PV (`Retain`) | PV `Released`, new PVC `Pending` — the PV still carries the old `claimRef` |
| PVC deleted while a Pod uses it | PVC stuck `Terminating` until the Pod goes (`pvc-protection`) |
| `emptyDir` `medium: Memory` filled past `sizeLimit` (2) | write stops at the limit (measured: 64 of 80 MiB) |

**What is what**

| 🎯 type it in the exam | 🔍 check it | 📚 understanding only |
|---|---|---|
| the three blocks from the docs page, literals changed · `emptyDir` / `medium` / `sizeLimit` · `hostPath.path` + `type` · `claimName` | `k get pv,pvc -n N` (STATUS, CLAIM, STORAGECLASS) · `describe pvc` events · `exec … -- cat` | dynamic provisioning and `volumeBindingMode` (no StorageClass in the lab) · `Released` → `claimRef` removal · RWOP · CSI |

**Mnemonic — L·P·C·M·P: "Lazy Penguins Cannot Make Pancakes."**
**L**ifetime → **P**V → **C**laim → **M**ount → **P**rove.
Why this order: the lifetime decides whether steps P and C exist at all; the PV must
exist (and be `Available`) before the claim, or the claim sits `Pending` and you start
debugging a race you created; the Pod is last because it cannot start until its claim
is `Bound`.

### The whiteboard

#### Step 1 — what the lab has (🔍, measured)

```bash
# ▶▶ cp1
k get sc ; k get pv
#   No resources found       ← kubeadm ships no StorageClass and no provisioner
#   No resources found
```

So every PVC here binds **only** to a PV you create. On the exam, run the same line
first: if a StorageClass exists and the task names it, a PVC alone may be enough.

#### Step 2 — ephemeral volumes (🎯, 3:00)

```yaml
spec:
  volumes:
  - name: scratch
    emptyDir:
      medium: Memory          # tmpfs (RAM)
      sizeLimit: 64Mi
  - name: disk
    emptyDir: {}              # node disk, Pod lifetime
  - name: host
    hostPath:
      path: /var/data
      type: DirectoryOrCreate # created on the node if missing
  containers:
  - name: app
    volumeMounts:
    - {name: scratch, mountPath: /scratch}
    - {name: disk,    mountPath: /disk}
    - {name: host,    mountPath: /host}
```

Measured inside the container (`df -h`):

```
tmpfs        64.0M    0   64.0M   0% /scratch      ← medium: Memory, capped at sizeLimit
/dev/sda1    18.3G 5.5G   12.9G  30% /disk         ← node disk
```

`dd` of 80 MiB into `/scratch` stopped at **64.0 MB**. The `hostPath` file stayed on
**w2** (`ls /var/d13-host` on the node) after the Pod was deleted — the `emptyDir`s did
not. `explain pod.spec.volumes.hostPath.type` lists the types; `DirectoryOrCreate` is
the one to remember.

#### Steps 3–5 — PV + PVC + Pod (🎯, 7:00)

Docs page `Configure a Pod to Use a PersistentVolume for Storage` — copy its three
blocks, change the literals. Measured version:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: PV                     # no namespace — cluster-scoped
spec:
  storageClassName: manual     # must equal the PVC's (or both absent)
  capacity:
    storage: 1Gi               # ≥ the request
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /srv/data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: CLAIM
  namespace: NS
spec:
  storageClassName: manual
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: POD
  namespace: NS
spec:
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: CLAIM         # the PVC, never the PV
  containers:
  - name: app
    image: nginx:1.29
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
```

| Must agree for a bind | PV | PVC |
|---|---|---|
| Class | `storageClassName` | same string, or **both absent** |
| Access mode | supports it | asks for it |
| Size | `capacity.storage` | `requests.storage` ≤ that |

Binding matrix, measured (two PVs: `d13-pv-noclass` 1Gi no class, `d13-pv-manual` 1Gi
class `manual`):

```
NAME        STATUS    VOLUME           CAPACITY   ACCESS MODES   STORAGECLASS
c-omitted   Bound     d13-pv-noclass   1Gi        RWO                          ← class omitted → bound the no-class PV
c-big       Pending                               manual                       ← 2Gi > 1Gi
c-fast      Pending                               fast                         ← no such class, no PV
c-rwx       Pending                               manual                       ← RWX asked, PV is RWO
```

All three `Pending` claims show the **same** event, whatever the real cause:

```
Warning  ProvisioningFailed  persistentvolume-controller  storageclass.storage.k8s.io "manual" not found
```

Read it as "**no PV matches, and nobody can provision one**", then compare the three
lines of the table above with `k get pv`. Also measured: the bound claim shows
`CAPACITY 1Gi` (the PV's), not the `500Mi` it asked for; a **static** PV created without
`persistentVolumeReclaimPolicy` shows `Retain`.

```bash
# ▶▶ cp1 🔍 — proof
k get pv PV                         # STATUS Bound · CLAIM NS/CLAIM
k -n NS get pvc CLAIM               # STATUS Bound · VOLUME PV
k -n NS exec POD -- sh -c 'echo hi > /usr/share/nginx/html/index.html; cat /usr/share/nginx/html/index.html'
```

#### Step 6 — what survives, and where (🔍 / 📚)

Measured with a `hostPath` PV: Pod deleted and recreated three times → it landed on
**w2** each time and read `persisted`. Forced onto **w1** (`nodeName: w1`):
`cat: can't open '/data/f': No such file or directory`. A `hostPath` PV is one directory
**on one node** — fine for the exam, never for real data (EKS: an EBS volume follows
the Pod's attachment instead).

Reclaim, measured: delete the PVC → PV `Released` (CLAIM still `d13-v/data`); a new PVC
with the same spec → `Pending`. 📚 Making the PV reusable means removing its
`spec.claimRef` (`k patch pv PV --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'`
→ `Available` → bound again). Deleting a PVC while a Pod mounts it → `Terminating`
until the Pod is gone.

### Command card — 1.4

```
CHECK     k get sc ; k get pv                    (no SC → you must create the PV)
DOCS      "Configure a Pod to Use a PersistentVolume for Storage" → copy 3 blocks
PV        name · storageClassName · capacity · accessModes · hostPath.path   (no namespace)
PVC       -n NS · SAME class · SAME mode · request ≤ capacity
POD       volumes: persistentVolumeClaim.claimName: PVC · volumeMounts: name + mountPath
EPHEMERAL emptyDir: {} | medium: Memory + sizeLimit | hostPath: path + type
APPLY     k apply -f f.yaml
PROVE     get pv,pvc (Bound + CLAIM) · exec -- write/read · describe pvc if Pending
```

### Traps

| Error | Cause |
|---|---|
| PVC `Pending`, `storageclass.storage.k8s.io "X" not found` | No PV matches class **or** size **or** access mode — the event names the class whatever the cause |
| PVC `Pending` with the class omitted | PV has a `storageClassName`; omitted binds only to class-less PVs (no default SC) |
| `pod has unbound immediate PersistentVolumeClaims` | The Pod is fine; its PVC is `Pending` — debug the PVC |
| `persistentvolumeclaim "X" not found` on the Pod | `claimName` typo, or the PVC is in another namespace |
| PVC shows a bigger CAPACITY than requested | Normal — it shows the bound PV's capacity |
| Old data gone after a reschedule | `hostPath` PV is node-local; the new Pod is on another node |
| New PVC `Pending`, PV `Released` | `Retain` PV still holds the old `claimRef` |
| PVC stuck `Terminating` | A Pod still mounts it (`pvc-protection`) |
| `/cache` is not a tmpfs | `medium: Memory` missing — `sizeLimit` alone keeps it on disk |

⚠️ **EKS:** there is a **default StorageClass** (`gp2`, or `gp3` with the EBS CSI
driver), so a bare PVC provisions an EBS volume by itself — you never write a PV. EBS is
**RWO and zonal** (`WaitForFirstConsumer` binds it in the Pod's AZ); RWX needs **EFS**
(EFS CSI driver). Dynamic PVs default to **`Delete`**: `kubectl delete pvc` destroys the
EBS volume. On a kubeadm cluster (the exam) there is no StorageClass unless the task
gives one.

---

## §9. Exam mode — Set 1 · 4 tasks · 25 min

Wording as the CKAD phrases it. **During the clock, read only the task text.** Each
🧪 setup is untimed and base64-encoded (it starts with its own reset); each 🔍 grader
runs **after** the clock stops and prints `PASS`/`FAIL` per check. A FAIL is pasted, not
fixed first. All run on **cp1**.

**Graders verified 21 Nov 2026 on `ckad-v137`** against three states each: setup only
(T1 10/10 FAIL · T2 7/10 FAIL — the 3 PASS are the untouched app container · T3 8/8 FAIL · T4 5/5 FAIL), a correct solution (all PASS) and a typical wrong solution
(FAIL caught): T1 init without the mount → 3 FAIL · T2 classic sidecar, app not mounted
→ 3 FAIL · T3 PVC without `storageClassName` → 5 FAIL · T4 `sizeLimit` without
`medium: Memory` → 2 FAIL.

### Task 1 · init container + readiness probe (weight 6%) · target 6:00 · R14

```
Namespace: d13-mercury

Create a Pod named checker in namespace d13-mercury, using image nginx:1.29.
Before the main container starts, an init container named init-ready, using image
busybox:1.28, must create the file /work/ready. Both containers must mount a shared
emptyDir volume named workdir at /work.
Add a readiness probe to the main container that runs the command cat /work/ready
every 5 seconds. The Pod must become Ready.
```

🧪 Setup:

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEzLW1lcmN1cnkgLS1pZ25vcmUtbm90LWZvdW5kIC0td2FpdD10cnVlID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGNyZWF0ZSBucyBkMTMtbWVyY3VyeSA+L2Rldi9udWxsCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'Tj1kMTMtbWVyY3VyeTsgUD1jaGVja2VyCm9rKCl7IFsgIiQxIiA9ICIkMiIgXSAmJiBlY2hvICJQQVNTICAkMyIgfHwgZWNobyAiRkFJTCAgJDMgKGdvdCAnJDEnLCB3YW50ICckMicpIjsgfQpqKCl7IGt1YmVjdGwgLW4gJE4gZ2V0IHBvZCAkUCAtbyBqc29ucGF0aD0iJDEiIDI+L2Rldi9udWxsOyB9Cm9rICIkKGogJ3subWV0YWRhdGEubmFtZX0nKSIgIiRQIiAiUG9kICRQIGV4aXN0cyBpbiAkTiIKb2sgIiQoaiAney5zcGVjLmNvbnRhaW5lcnNbMF0uaW1hZ2V9JykiICJuZ2lueDoxLjI5IiAibWFpbiBjb250YWluZXIgaW1hZ2Ugbmdpbng6MS4yOSIKb2sgIiQoaiAney5zcGVjLmluaXRDb250YWluZXJzWzBdLm5hbWV9L3suc3BlYy5pbml0Q29udGFpbmVyc1swXS5pbWFnZX0nKSIgImluaXQtcmVhZHkvYnVzeWJveDoxLjI4IiAiaW5pdCBjb250YWluZXIgaW5pdC1yZWFkeSwgYnVzeWJveDoxLjI4IgpvayAiJChqICd7LnNwZWMudm9sdW1lc1s/KEAubmFtZT09IndvcmtkaXIiKV0uZW1wdHlEaXJ9JykiICJ7fSIgInZvbHVtZSB3b3JrZGlyIGlzIGFuIGVtcHR5RGlyIgpvayAiJChqICd7LnNwZWMuaW5pdENvbnRhaW5lcnNbMF0udm9sdW1lTW91bnRzWz8oQC5uYW1lPT0id29ya2RpciIpXS5tb3VudFBhdGh9JykiICIvd29yayIgImluaXQgY29udGFpbmVyIG1vdW50cyB3b3JrZGlyIGF0IC93b3JrIgpvayAiJChqICd7LnNwZWMuY29udGFpbmVyc1swXS52b2x1bWVNb3VudHNbPyhALm5hbWU9PSJ3b3JrZGlyIildLm1vdW50UGF0aH0nKSIgIi93b3JrIiAibWFpbiBjb250YWluZXIgbW91bnRzIHdvcmtkaXIgYXQgL3dvcmsiCm9rICIkKGogJ3suc3BlYy5jb250YWluZXJzWzBdLnJlYWRpbmVzc1Byb2JlLmV4ZWMuY29tbWFuZH0nIHwgdHIgLWQgJyBbXSInIHwgc2VkICdzLywvIC9nJykiICJjYXQgL3dvcmsvcmVhZHkiICJyZWFkaW5lc3MgcHJvYmU6IGV4ZWMgY2F0IC93b3JrL3JlYWR5IChvbiB0aGUgbWFpbiBjb250YWluZXIpIgpvayAiJChqICd7LnNwZWMuY29udGFpbmVyc1swXS5yZWFkaW5lc3NQcm9iZS5wZXJpb2RTZWNvbmRzfScpIiAiNSIgInByb2JlIGV2ZXJ5IDUgcyIKb2sgIiQoaiAney5zdGF0dXMuY29uZGl0aW9uc1s/KEAudHlwZT09IlJlYWR5IildLnN0YXR1c30nKSIgIlRydWUiICJQb2QgaXMgUmVhZHkiCm9rICIkKGt1YmVjdGwgLW4gJE4gZXhlYyAkUCAtYyAkKGogJ3suc3BlYy5jb250YWluZXJzWzBdLm5hbWV9JykgLS0gY2F0IC93b3JrL3JlYWR5ID4vZGV2L251bGwgMj4mMSAmJiBlY2hvIHllcykiICJ5ZXMiICIvd29yay9yZWFkeSBleGlzdHMgaW4gdGhlIG1haW4gY29udGFpbmVyIgo=' | base64 -d | bash
```

### Task 2 · sidecar into an existing Deployment (weight 7%) · target 7:00

```
Namespace: d13-venus

The Deployment orders in namespace d13-venus writes its log to
/var/log/orders/app.log. Add a sidecar container named log-shipper, using image
busybox:1.28, that runs the command: tail -F /var/log/orders/app.log
The log directory must be shared between the existing container and the sidecar
through a volume named logs of type emptyDir, mounted at /var/log/orders in both.
The sidecar must be started before the application container and keep running for
the lifetime of the Pod. Do not rename or change the command of the existing
container. Make sure all replicas are available afterwards.
```

🧪 Setup:

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEzLXZlbnVzIC0taWdub3JlLW5vdC1mb3VuZCAtLXdhaXQ9dHJ1ZSA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBjcmVhdGUgbnMgZDEzLXZlbnVzID4vZGV2L251bGwKa3ViZWN0bCAtbiBkMTMtdmVudXMgY3JlYXRlIGRlcGxveW1lbnQgb3JkZXJzIC0taW1hZ2U9YnVzeWJveDoxLjI4IC0tcmVwbGljYXM9MiAtLSBzaCAtYyAnbWtkaXIgLXAgL3Zhci9sb2cvb3JkZXJzOyB3aGlsZSB0cnVlOyBkbyBlY2hvICJvcmRlciAkKGRhdGUgKyVzKSIgPj4gL3Zhci9sb2cvb3JkZXJzL2FwcC5sb2c7IHNsZWVwIDI7IGRvbmUnID4vZGV2L251bGwKa3ViZWN0bCAtbiBkMTMtdmVudXMgcGF0Y2ggZGVwbG95bWVudCBvcmRlcnMgLS10eXBlPWpzb24gLXAgJ1t7Im9wIjoicmVwbGFjZSIsInBhdGgiOiIvc3BlYy90ZW1wbGF0ZS9zcGVjL2NvbnRhaW5lcnMvMC9uYW1lIiwidmFsdWUiOiJvcmRlcnMifV0nID4vZGV2L251bGwKa3ViZWN0bCAtbiBkMTMtdmVudXMgcm9sbG91dCBzdGF0dXMgZGVwbG95bWVudCBvcmRlcnMgLS10aW1lb3V0PTEyMHMgPi9kZXYvbnVsbAplY2hvICJzZXR1cCBkb25lIgo=' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'Tj1kMTMtdmVudXM7IEQ9b3JkZXJzCm9rKCl7IFsgIiQxIiA9ICIkMiIgXSAmJiBlY2hvICJQQVNTICAkMyIgfHwgZWNobyAiRkFJTCAgJDMgKGdvdCAnJDEnLCB3YW50ICckMicpIjsgfQpqKCl7IGt1YmVjdGwgLW4gJE4gZ2V0IGRlcGxveSAkRCAtbyBqc29ucGF0aD0iJDEiIDI+L2Rldi9udWxsOyB9Cm9rICIkKGogJ3suc3RhdHVzLnJlYWR5UmVwbGljYXN9L3suc3BlYy5yZXBsaWNhc30nKSIgIjIvMiIgIkRlcGxveW1lbnQgJEQgaGFzIDIvMiByZWFkeSByZXBsaWNhcyIKb2sgIiQoaiAney5zcGVjLnRlbXBsYXRlLnNwZWMuY29udGFpbmVyc1s/KEAubmFtZT09Im9yZGVycyIpXS5pbWFnZX0nKSIgImJ1c3lib3g6MS4yOCIgImFwcCBjb250YWluZXIgb3JkZXJzIGtlcHQgKG5hbWUgKyBpbWFnZSkiCm9rICIkKGogJ3suc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbPyhALm5hbWU9PSJvcmRlcnMiKV0uY29tbWFuZFsyXX0nIHwgZ3JlcCAtYyAnYXBwLmxvZycpIiAiMSIgImFwcCBjb250YWluZXIgY29tbWFuZCB1bmNoYW5nZWQiClM9IiQoaiAney5zcGVjLnRlbXBsYXRlLnNwZWMuaW5pdENvbnRhaW5lcnNbPyhALm5hbWU9PSJsb2ctc2hpcHBlciIpXS5pbWFnZX17LnNwZWMudGVtcGxhdGUuc3BlYy5jb250YWluZXJzWz8oQC5uYW1lPT0ibG9nLXNoaXBwZXIiKV0uaW1hZ2V9JykiCm9rICIkUyIgImJ1c3lib3g6MS4yOCIgInNpZGVjYXIgbG9nLXNoaXBwZXIgZXhpc3RzLCBpbWFnZSBidXN5Ym94OjEuMjgiCkM9IiQoaiAney5zcGVjLnRlbXBsYXRlLnNwZWMuaW5pdENvbnRhaW5lcnNbPyhALm5hbWU9PSJsb2ctc2hpcHBlciIpXS5jb21tYW5kfXsuc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbPyhALm5hbWU9PSJsb2ctc2hpcHBlciIpXS5jb21tYW5kfXsuc3BlYy50ZW1wbGF0ZS5zcGVjLmluaXRDb250YWluZXJzWz8oQC5uYW1lPT0ibG9nLXNoaXBwZXIiKV0uYXJnc317LnNwZWMudGVtcGxhdGUuc3BlYy5jb250YWluZXJzWz8oQC5uYW1lPT0ibG9nLXNoaXBwZXIiKV0uYXJnc30nKSIKb2sgIiQoZWNobyAiJEMiIHwgZ3JlcCAtYyAndGFpbCAtRiAvdmFyL2xvZy9vcmRlcnMvYXBwLmxvZ1x8InRhaWwiLCItRiIsIi92YXIvbG9nL29yZGVycy9hcHAubG9nIicpIiAiMSIgInNpZGVjYXIgcnVucyB0YWlsIC1GIC92YXIvbG9nL29yZGVycy9hcHAubG9nIgpvayAiJChqICd7LnNwZWMudGVtcGxhdGUuc3BlYy52b2x1bWVzWz8oQC5uYW1lPT0ibG9ncyIpXS5lbXB0eURpcn0nKSIgInt9IiAidm9sdW1lIGxvZ3MgaXMgYW4gZW1wdHlEaXIiCm9rICIkKGogJ3suc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbPyhALm5hbWU9PSJvcmRlcnMiKV0udm9sdW1lTW91bnRzWz8oQC5uYW1lPT0ibG9ncyIpXS5tb3VudFBhdGh9JykiICIvdmFyL2xvZy9vcmRlcnMiICJhcHAgbW91bnRzIGxvZ3MgYXQgL3Zhci9sb2cvb3JkZXJzIgpvayAiJChqICd7LnNwZWMudGVtcGxhdGUuc3BlYy5pbml0Q29udGFpbmVyc1s/KEAubmFtZT09ImxvZy1zaGlwcGVyIildLnZvbHVtZU1vdW50c1s/KEAubmFtZT09ImxvZ3MiKV0ubW91bnRQYXRofXsuc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbPyhALm5hbWU9PSJsb2ctc2hpcHBlciIpXS52b2x1bWVNb3VudHNbPyhALm5hbWU9PSJsb2dzIildLm1vdW50UGF0aH0nKSIgIi92YXIvbG9nL29yZGVycyIgInNpZGVjYXIgbW91bnRzIGxvZ3MgYXQgL3Zhci9sb2cvb3JkZXJzIgpvayAiJChqICd7LnNwZWMudGVtcGxhdGUuc3BlYy5pbml0Q29udGFpbmVyc1s/KEAubmFtZT09ImxvZy1zaGlwcGVyIildLnJlc3RhcnRQb2xpY3l9JykiICJBbHdheXMiICJuYXRpdmUgc2lkZWNhcjogaW5pdENvbnRhaW5lciB3aXRoIHJlc3RhcnRQb2xpY3kgQWx3YXlzIChzdGFydHMgZmlyc3QpIgpvayAiJChrdWJlY3RsIC1uICROIGxvZ3MgZGVwbG95LyREIC1jIGxvZy1zaGlwcGVyIC0tdGFpbD01IDI+L2Rldi9udWxsIHwgZ3JlcCAtYyAnXm9yZGVyICcpIiAiNSIgImt1YmVjdGwgbG9ncyAtYyBsb2ctc2hpcHBlciBzaG93cyB0aGUgYXBwJ3MgbGluZXMiCg==' | base64 -d | bash
```

### Task 3 · PV + PVC + Pod (weight 7%) · target 8:00

```
Namespace: d13-earth

Create a PersistentVolume named d13-earth-pv with a capacity of 1Gi, access mode
ReadWriteOnce, storageClassName local-manual, backed by the hostPath /srv/d13-earth.
Create a PersistentVolumeClaim named earth-claim in namespace d13-earth that
requests 500Mi with access mode ReadWriteOnce and storageClassName local-manual.
Create a Pod named earth-app in namespace d13-earth, using image nginx:1.29, that
mounts the claim at /usr/share/nginx/html. Finally, write the text earth into the
file /usr/share/nginx/html/index.html from inside the Pod.
```

🧪 Setup (also removes the PV and the hostPath directories on w1/w2):

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEzLWVhcnRoIC0taWdub3JlLW5vdC1mb3VuZCAtLXdhaXQ9dHJ1ZSA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBkZWxldGUgcHYgZDEzLWVhcnRoLXB2IC0taWdub3JlLW5vdC1mb3VuZCA+L2Rldi9udWxsIDI+JjEKZm9yIG4gaW4gdzEgdzI7IGRvIHNzaCAtbyBCYXRjaE1vZGU9eWVzICRuICdzdWRvIHJtIC1yZiAvc3J2L2QxMy1lYXJ0aCcgPi9kZXYvbnVsbCAyPiYxOyBkb25lCmt1YmVjdGwgY3JlYXRlIG5zIGQxMy1lYXJ0aCA+L2Rldi9udWxsCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'Tj1kMTMtZWFydGgKb2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CnB2KCl7IGt1YmVjdGwgZ2V0IHB2IGQxMy1lYXJ0aC1wdiAtbyBqc29ucGF0aD0iJDEiIDI+L2Rldi9udWxsOyB9CnB2YygpeyBrdWJlY3RsIC1uICROIGdldCBwdmMgZWFydGgtY2xhaW0gLW8ganNvbnBhdGg9IiQxIiAyPi9kZXYvbnVsbDsgfQpwb2QoKXsga3ViZWN0bCAtbiAkTiBnZXQgcG9kIGVhcnRoLWFwcCAtbyBqc29ucGF0aD0iJDEiIDI+L2Rldi9udWxsOyB9Cm9rICIkKHB2ICd7LnNwZWMuY2FwYWNpdHkuc3RvcmFnZX0vey5zcGVjLmFjY2Vzc01vZGVzWypdfS97LnNwZWMuc3RvcmFnZUNsYXNzTmFtZX0nKSIgIjFHaS9SZWFkV3JpdGVPbmNlL2xvY2FsLW1hbnVhbCIgIlBWIGQxMy1lYXJ0aC1wdjogMUdpLCBSV08sIGNsYXNzIGxvY2FsLW1hbnVhbCIKb2sgIiQocHYgJ3suc3BlYy5ob3N0UGF0aC5wYXRofScpIiAiL3Nydi9kMTMtZWFydGgiICJQViBob3N0UGF0aCAvc3J2L2QxMy1lYXJ0aCIKb2sgIiQocHZjICd7LnNwZWMucmVzb3VyY2VzLnJlcXVlc3RzLnN0b3JhZ2V9L3suc3BlYy5hY2Nlc3NNb2Rlc1sqXX0vey5zcGVjLnN0b3JhZ2VDbGFzc05hbWV9JykiICI1MDBNaS9SZWFkV3JpdGVPbmNlL2xvY2FsLW1hbnVhbCIgIlBWQyBlYXJ0aC1jbGFpbTogNTAwTWksIFJXTywgbG9jYWwtbWFudWFsIgpvayAiJChwdmMgJ3suc3RhdHVzLnBoYXNlfS97LnNwZWMudm9sdW1lTmFtZX0nKSIgIkJvdW5kL2QxMy1lYXJ0aC1wdiIgIlBWQyBib3VuZCB0byBkMTMtZWFydGgtcHYiCm9rICIkKHBvZCAney5zcGVjLmNvbnRhaW5lcnNbMF0uaW1hZ2V9L3suc3RhdHVzLnBoYXNlfScpIiAibmdpbng6MS4yOS9SdW5uaW5nIiAiUG9kIGVhcnRoLWFwcCBuZ2lueDoxLjI5IFJ1bm5pbmciClY9IiQocG9kICd7LnNwZWMudm9sdW1lc1s/KEAucGVyc2lzdGVudFZvbHVtZUNsYWltLmNsYWltTmFtZT09ImVhcnRoLWNsYWltIildLm5hbWV9JykiCm9rICIkKFsgLW4gIiRWIiBdICYmIHBvZCAiey5zcGVjLmNvbnRhaW5lcnNbMF0udm9sdW1lTW91bnRzWz8oQC5uYW1lPT1cIiRWXCIpXS5tb3VudFBhdGh9IikiICIvdXNyL3NoYXJlL25naW54L2h0bWwiICJjbGFpbSBtb3VudGVkIGF0IC91c3Ivc2hhcmUvbmdpbngvaHRtbCIKb2sgIiQoa3ViZWN0bCAtbiAkTiBleGVjIGVhcnRoLWFwcCAtLSBjYXQgL3Vzci9zaGFyZS9uZ2lueC9odG1sL2luZGV4Lmh0bWwgMj4vZGV2L251bGwpIiAiZWFydGgiICJpbmRleC5odG1sIGNvbnRhaW5zIGVhcnRoIgpOT0RFPSIkKHBvZCAney5zcGVjLm5vZGVOYW1lfScpIgpvayAiJChbIC1uICIkTk9ERSIgXSAmJiBzc2ggLW8gQmF0Y2hNb2RlPXllcyAkTk9ERSAnc3VkbyBjYXQgL3Nydi9kMTMtZWFydGgvaW5kZXguaHRtbCcgMj4vZGV2L251bGwpIiAiZWFydGgiICJkYXRhIGlzIG9uIHRoZSBQViAoaG9zdFBhdGggb24gJE5PREUpIgo=' | base64 -d | bash
```

### Task 4 · in-memory scratch volume (weight 4%) · target 3:00

```
Namespace: d13-mars

Create a Pod named cache in namespace d13-mars, using image busybox:1.28 and the
command sleep 3600. Give it a volume named scratch that is an emptyDir stored in
memory, limited to 64Mi, mounted at /cache.
```

🧪 Setup:

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEzLW1hcnMgLS1pZ25vcmUtbm90LWZvdW5kIC0td2FpdD10cnVlID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGNyZWF0ZSBucyBkMTMtbWFycyA+L2Rldi9udWxsCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'Tj1kMTMtbWFyczsgUD1jYWNoZQpvaygpeyBbICIkMSIgPSAiJDIiIF0gJiYgZWNobyAiUEFTUyAgJDMiIHx8IGVjaG8gIkZBSUwgICQzIChnb3QgJyQxJywgd2FudCAnJDInKSI7IH0KaigpeyBrdWJlY3RsIC1uICROIGdldCBwb2QgJFAgLW8ganNvbnBhdGg9IiQxIiAyPi9kZXYvbnVsbDsgfQpvayAiJChqICd7LnNwZWMuY29udGFpbmVyc1swXS5pbWFnZX0vey5zdGF0dXMucGhhc2V9JykiICJidXN5Ym94OjEuMjgvUnVubmluZyIgIlBvZCBjYWNoZSBidXN5Ym94OjEuMjggUnVubmluZyIKb2sgIiQoaiAney5zcGVjLnZvbHVtZXNbPyhALm5hbWU9PSJzY3JhdGNoIildLmVtcHR5RGlyLm1lZGl1bX0nKSIgIk1lbW9yeSIgInZvbHVtZSBzY3JhdGNoIGlzIGFuIGVtcHR5RGlyIGluIE1lbW9yeSIKb2sgIiQoaiAney5zcGVjLnZvbHVtZXNbPyhALm5hbWU9PSJzY3JhdGNoIildLmVtcHR5RGlyLnNpemVMaW1pdH0nKSIgIjY0TWkiICJzaXplTGltaXQgNjRNaSIKb2sgIiQoaiAney5zcGVjLmNvbnRhaW5lcnNbMF0udm9sdW1lTW91bnRzWz8oQC5uYW1lPT0ic2NyYXRjaCIpXS5tb3VudFBhdGh9JykiICIvY2FjaGUiICJtb3VudGVkIGF0IC9jYWNoZSIKb2sgIiQoa3ViZWN0bCAtbiAkTiBleGVjICRQIC0tIGRmIC9jYWNoZSAyPi9kZXYvbnVsbCB8IGF3ayAnTlI9PTJ7cHJpbnQgJDF9JykiICJ0bXBmcyIgIi9jYWNoZSBpcyBhIHRtcGZzIGluc2lkZSB0aGUgY29udGFpbmVyIgo=' | base64 -d | bash
```

**Variations for the next runs** (new literals each time): the init container clones
or downloads into the volume instead of `touch`; the sidecar as a **classic** second
container when the task says "add a second container"; a PVC that must bind to an
existing PV whose class you must read first (`k get pv`); a PVC that stays `Pending`
and must be fixed without deleting the PV; `hostPath` with `type: DirectoryOrCreate`.

🧪 Clean-up after a run: `k delete ns d13-mercury d13-venus d13-earth d13-mars; k delete pv d13-earth-pv`.

### Run log

| Date | Task | With | Time | Score | Errors / notes |
|---|---|---|---|---|---|
| | | | | | |
