---
exams: [KCNA, KCSA, CKA, CKS]
domain: Cluster Architecture & Administration
kcna_domains: 1.1 Core Concepts, 1.2 Administration
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/architecture, /overview/components, /architecture/controller, /architecture/nodes, /workloads/pods/static-pods, /reference/networking/ports-and-protocols, /reference/command-line-tools-reference/kube-controller-manager, /concepts/scheduling-eviction/taint-and-toleration, /reference/labels-annotations-taints, /setup/best-practices/certificates, /tasks/administer-cluster/kubeadm/kubeadm-certs, /reference/config-api/kubelet-config.v1beta1
template: B
language: en
status: draft
written: 2026-08-16
revised: 2026-08-23 (v2 — deeper controller-manager, node-failure timeline, real file contents, scenario drills)
k8s_version_checked_against: v1.36 docs
---

# Cluster Architecture & Administration

## ⚡ Reading map — read this first

This note serves **four exams**. Only part of it is on KCNA. Read the KCNA
column now; the rest is deliberate prepay for CKA and stays here untouched.

**KCNA weight of this note:** it covers curriculum areas 1.1 and 1.2, which are
roughly **6–7 questions out of 60**. Do not spend six hours here.

| Section | KCNA (2 Sep) | CKA (26 Sep) | Note |
|---|---|---|---|
| §1.1 Mental model | ✅ **core** | ✅ | The single highest-value page |
| §1.2 Control loop | ✅ **core** | ✅ | |
| §1.3 kube-apiserver | ✅ **core** | ✅ | |
| §1.4 etcd | ✅ read | ✅ | KCNA: what it stores, why odd numbers. Skip the Raft detail |
| §1.5 kube-scheduler | ✅ read | ✅ | KCNA: filtering then scoring. That is enough |
| §1.6 controller-manager | ⚠️ **partial** | ✅ | KCNA: the definition + the **ownership chains** box. **Skip the 15-row table** |
| §1.7 cloud-controller-manager | ✅ read | ✅ | KCNA: what it does, why on-prem lacks it |
| §1.8 Node components | ✅ **core** | ✅ | |
| §1.9 Static Pods | ⚠️ skim | ✅ | KCNA: "managed by the kubelet from disk". Nothing more |
| §1.10 Nodes & conditions | ⚠️ skim | ✅ | KCNA: `Ready` exists. Lease detail is CKA |
| §1.11 Failure timeline | ❌ **skip now** | ✅ **core** | Pure CKA. No KCNA question asks for seconds |
| §2.1 File contents & PKI | ❌ **skip now** | ✅ **core** | Zero KCNA value. Highest CKA value in the note |
| §2.2 kubeconfig | ⚠️ partial | ✅ | KCNA: a context = cluster + user + namespace. Skip the cert identity part |
| §2.3 Ports | ⚠️ partial | ✅ | KCNA: **6443** only. The rest is CKA |
| §5 Verification | ❌ skip now | ✅ | Needs a cluster you do not have until 30 Aug |
| §6 Failure Modes | ⚠️ skim | ✅ **core** | KCNA: the CNI and LoadBalancer rows only |
| §7 EKS vs Vanilla | — | ✅ | Personal blind-spot map, not an exam section |
| §10 Active Recall | Q 1–13, 15, 16, 18, 19, 21, 22, 27, 36 | all 36 | ~23 questions are KCNA scope |
| §11 Scenario Drills | Scenario 6 only | all 6 | The others need §1.11 and §2.1 |

**KCNA path through this note: §1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 (partial) →
1.7 → 1.8, then the 23 recall questions.** About 60 minutes, not four hours.

Everything marked ❌ is not wasted — it is written, verified and waiting for
3 September, when it becomes the most valuable material in the file.

---

## 1. Core Concepts

### 1.1 The mental model that solves half the exam

> 🟢 **KCNA · READ CLOSELY** — core exam material.

Kubernetes is not a system where a boss gives orders to workers. It is a system
where **every component is a client of the same database**, and each one watches
the slice it cares about and acts on it.

```
                        ┌──────────────────┐
   kubectl ────────────▶│                  │
   kubelet (each node) ▶│  kube-apiserver  │◀────▶  etcd
   kube-scheduler ─────▶│                  │      (ONLY component
   controller-manager ─▶│   :6443 HTTPS    │       that talks to it)
   cloud-controller ───▶│                  │
                        └──────────────────┘
```

Three statements you must be able to recite:

1. **The API server is the only component that talks to etcd.** Nobody else.
   To change cluster state, you go through the API server.
2. **Controllers do not modify things directly.** They observe current state via
   the API server, compare it to desired state, and write the change back
   *through the API server*. Official wording: *"controllers ... take action by
   communicating changes back through the API server."*
3. **The scheduler does not place Pods.** It only writes `spec.nodeName` on a
   Pod that does not have one. The kubelet on that node is watching the API
   server, sees a Pod bound to itself, and starts it.

> ⚠️ **Very common trap:** believing the API server *tells* the kubelet to create
> a Pod. It does not. The kubelet **pulls** (`watch`), it is not **pushed** to.
> The kubelet opens an outbound connection to the API server and watches. This is
> why the control plane never needs to reach into the node network to schedule work.

### 1.2 The control loop, and what "reconcile" actually means

> 🟢 **KCNA · READ CLOSELY** — core exam material.

Official wording: *"A control loop is a non-terminating loop that regulates the
state of a system."*

The official analogy is a thermostat: you set the temperature (**desired state**),
the actual room temperature is the **current state**, and the thermostat acts to
close the gap. It never terminates.

```
   ┌──▶ WATCH current state (via API server)
   │            │
   │            ▼
   │    == desired state?  ── yes ──▶ do nothing
   │            │
   │            no
   │            ▼
   │    DECIDE what change closes the gap
   │            │
   │            ▼
   └──── ACT: send an update request to the API server,
              which persists it to etcd
```

**"Reconcile" is stronger than "check".** A controller does not merely observe
and report a drift. It *initiates the corrective action* — it issues create,
update, patch and delete requests against the API. Observing is step one of
four; the loop is only doing its job when it writes.

This is why Kubernetes is **declarative**: you describe the outcome, and a
non-terminating loop is responsible for producing and maintaining it.

| | Imperative | Declarative |
|---|---|---|
| What you express | the **steps** | the **outcome** |
| Example | `kubectl run nginx --image=nginx` | `kubectl apply -f pod.yaml` |
| If someone deletes the resource | nothing restores it | the controller restores it |
| Terraform analogue | `aws ec2 run-instances` | `terraform apply` |

### 1.3 kube-apiserver

> 🟢 **KCNA · READ CLOSELY** — core exam material.

*"Exposes the Kubernetes API. The API server is the front end for the Kubernetes
control plane."*

- The **only** component with a connection to etcd.
- Every request passes three gates in order:
  **Authentication → Authorization → Admission Control** (detail in note 07).
- Stateless and horizontally scalable — you can run several behind a load
  balancer. It is the only control plane component that scales that way trivially,
  precisely because all the state lives in etcd.
- Listens on **:6443** (HTTPS).

**If it dies:** the cluster freezes. `kubectl` stops responding, no controller can
read or write, nothing new schedules. **But Pods already running keep running** —
the kubelet is autonomous and keeps its containers alive from its local view.
You lose the ability to *change* things, not the workloads themselves.

### 1.4 etcd

> 🟢 **KCNA · READ ONCE** — what it stores, and why the member count is odd. Skip the Raft/quorum arithmetic.

*"Consistent and highly-available key value store used as Kubernetes' backing
store for all cluster data."*

- **All cluster state lives here** — every object, Secret and piece of config.
- Uses the **Raft** consensus algorithm → it needs **quorum = (n/2)+1**.
- That is why the member count is **odd**: 3 tolerates 1 failure, 5 tolerates 2.
  With 4 members quorum is 3, so you still tolerate only 1 failure while paying
  more write latency. **Four is never better than three.**
- **kubeadm defaults to "stacked" etcd**: it runs as a static Pod on the same
  control plane node. The alternative is an external etcd cluster.
- Backing up etcd *is* backing up the cluster: `etcdctl snapshot save`.

**If it dies:** the API server can neither read nor write. Functionally equivalent
to losing the cluster. This is the one thing that must be backed up.

### 1.5 kube-scheduler

> 🟢 **KCNA · READ ONCE** — filtering then scoring, and that a Pod with no feasible node stays `Pending`. That is enough.

*"Watches for newly created Pods with no assigned node, and selects a node for
them to run on."*

Two phases, and the vocabulary is examinable:

```
  All nodes
     │
     ▼
  FILTERING  (predicates)   → which nodes COULD run this Pod?
     │                         resources, taints, affinity, node selectors
     ▼
  feasible nodes
     │
     ▼
  SCORING    (priorities)   → which feasible node is BEST?
     │                         spread, least-requested, image locality
     ▼
  one winner → write spec.nodeName via the API server
```

If no node survives filtering, the Pod stays **`Pending`** and an event says why.

**If it dies:** existing Pods are untouched. New Pods stay `Pending` **forever** —
nobody assigns them a node, so no kubelet ever claims them.

### 1.6 kube-controller-manager — the deep version

> 🟡 **KCNA · PARTIAL** — read the definition, the four loop steps and the **ownership chains** box at the end. **Skip the 15-row controller table** — for KCNA you need only: Deployment→ReplicaSet→Pod, CronJob→Job→Pod, node controller, ServiceAccount controller.

**What it actually is:** a control plane **daemon**, shipped as a **single binary
running as a single process**, that runs **many independent reconciliation loops
concurrently** — one per controller, each as its own goroutine with its own
watch, its own work queue and its own resync period.

Official wording: *"Logically, each controller is a separate process, but to
reduce complexity, they are all compiled into a single binary and run in a single
process."* Read that carefully — logically separate, physically one process. That
is why there is **one** `kube-controller-manager` static Pod and not thirty.

**What each loop does — the four steps, not two:**

| Step | What happens |
|---|---|
| 1. **Watch** | Open a `watch` against the API server for the object kinds it owns |
| 2. **Compare** | Diff the observed current state against the declared desired state |
| 3. **Decide** | Compute the minimum set of API operations that closes the gap |
| 4. **Act** | **Send create / update / patch / delete requests to the API server**, which persists them to etcd |

Step 4 is the one people leave out. A controller does not report drift — it
**writes**. And it never writes to etcd directly: it is an API server client like
everything else.

> **Leader election.** In an HA control plane every replica of
> `kube-controller-manager` is running, but only **one is the active leader** —
> they contend for a Lease object in `kube-system`. Otherwise three copies of the
> ReplicaSet controller would each create the missing Pod and you would get three.
> The same is true of `kube-scheduler`. The API server, by contrast, is
> genuinely active-active, because it holds no loops of its own.

**Which controllers matter.** The `--controllers` flag accepts **52 names** in
v1.36 and grows every release, so memorising the list is worthless. Memorise the
**pattern** (`<thing>-controller`, `-foo` to disable, default `*`) and the
**dozen that carry real behaviour**:

| Controller | What it reconciles | Why it matters |
|---|---|---|
| **deployment-controller** | Deployment → **ReplicaSets** | Creates a *new* RS per revision. This is what makes rolling updates and `rollout undo` possible. It does **not** create Pods. |
| **replicaset-controller** | ReplicaSet → **Pods** | The one that actually counts Pods and creates/deletes to hit `replicas`. **CKA/KCNA favourite:** Deployment→RS→Pod is a two-controller chain, not one. |
| **statefulset-controller** | StatefulSet → Pods + PVCs | Ordered, named Pods (`web-0`, `web-1`) created and deleted **one at a time, in order**, each with its own PVC from `volumeClaimTemplates` |
| **daemonset-controller** | DaemonSet → one Pod per eligible node | Watches **nodes** as well as Pods, so a new node gets its Pod automatically |
| **job-controller** | Job → Pods run to completion | *"Watches for Job objects that represent one-off tasks, then creates Pods to run those tasks to completion."* |
| **cronjob-controller** | CronJob → **Jobs** on a schedule | Another two-step chain: CronJob→Job→Pod |
| **node-lifecycle-controller** | Node health → conditions and taints | Marks nodes `NotReady`/`Unknown` and taints them. See §1.11 |
| **taint-eviction-controller** | `NoExecute` taints → Pod deletion | **Split out of the node controller in v1.29.** This is what actually evicts |
| **endpointslice-controller** | Service + Pods → EndpointSlices | *"Provides a link between Services and Pods."* A Service with no endpoints is usually this loop finding no label match |
| **serviceaccount-controller** | Namespace → default ServiceAccount | *"Create default ServiceAccounts for new namespaces."* |
| **namespace-controller** | Namespace deletion → cascade | Deletes everything inside a terminating namespace; blocked by finalizers |
| **garbage-collector-controller** | `ownerReferences` → orphan cleanup | Delete a Deployment and its RS and Pods vanish. **This is why**, and it is the answer to "who deleted my Pods?" |
| **persistentvolume-binder-controller** | PVC ↔ PV binding | Binds claims to volumes and triggers dynamic provisioning |
| **horizontal-pod-autoscaler-controller** | metrics → `replicas` | HPA. Needs metrics-server to exist |
| **resourcequota-controller** | ResourceQuota usage accounting | Tracks consumption per namespace |

Three are **disabled by default**: `bootstrap-signer-controller`,
`selinux-warning-controller`, `token-cleaner-controller`.

> **Version caution.** The controller set is release-specific. The KCNA exam will
> not ask you to enumerate 52 names — it asks *which controller is responsible
> for X*. Learn the ownership chains:
> `Deployment → ReplicaSet → Pod`, `CronJob → Job → Pod`,
> `StatefulSet → Pod + PVC`, `Service + Pods → EndpointSlice`.

**If it dies:** self-healing stops. ReplicaSets stop replacing dead Pods, dead
nodes are never marked `NotReady`, EndpointSlices go stale, deleted parents leave
orphans behind. Nothing breaks loudly — the cluster just quietly stops correcting
itself, which is far more dangerous.

### 1.7 cloud-controller-manager

> 🟢 **KCNA · READ ONCE** — what it does and why an on-prem cluster does not have one.

*"Embeds cloud-specific control logic ... lets you link your cluster into your
cloud provider's API, and separates out the components that interact with that
cloud platform from components that only interact with your cluster."*

Same daemon pattern as `kube-controller-manager`, but every loop inside talks to
a **provider API** as well as to the Kubernetes API:

| Controller | What it does |
|---|---|
| **cloud-node-lifecycle-controller** | Asks the provider whether an unresponsive node was *actually* deleted, and removes the Node object if so |
| **node-route-controller** | Configures routes in the provider's network fabric |
| **service-lb-controller** | Creates, updates and deletes **provider load balancers** for `type: LoadBalancer` Services |

The quote that explains your `<pending>` LoadBalancer: *"If you are running
Kubernetes on your own premises, or in a learning environment inside your own
computer, the cluster does not have a cloud controller manager."*

### 1.8 Node components

> 🟢 **KCNA · READ CLOSELY** — core exam material.

| Component | What it does (official docs) |
|---|---|
| **kubelet** | *"An agent that runs on each node ... makes sure that containers are running in a Pod."* Takes PodSpecs from several sources and ensures their containers run and stay healthy. **It does not manage containers that were not created by Kubernetes.** |
| **kube-proxy** | *"A network proxy that runs on each node ... maintains network rules on nodes"* that allow traffic to reach your Pods from inside or outside the cluster. Implements part of the **Service** concept. |
| **container runtime** | Runs the containers. containerd, CRI-O, or any implementation of the **CRI**. |

The kubelet takes PodSpecs from **three** sources, and this is the seam that makes
static Pods possible:

1. **The API server** (`watch`) — the normal path
2. **A directory on disk** (`staticPodPath`) — static Pods
3. **An HTTP endpoint** — legacy, rarely used

> The kubelet runs on **every** node, control plane included. That is what lets
> the control plane run its own components as containers.

### 1.9 Static Pods — the concept EKS hid from you completely

> 🟡 **KCNA · SKIM** — KCNA needs one sentence: *a Pod the kubelet runs from a directory on disk, without the API server*. The manifest paths and mirror-Pod mechanics are CKA.

A **static Pod** is a Pod managed **directly by the kubelet**, without the API
server observing or controlling it.

- The kubelet watches a directory (`staticPodPath`) and starts whatever it finds.
  **kubeadm uses `/etc/kubernetes/manifests/`.**
- The kubelet restarts it if it fails. No ReplicaSet, no Deployment involved.
- The kubelet also creates a **mirror Pod** on the API server so it is *visible*
  to `kubectl get pods`. That mirror is **read-only**.
- **`kubectl delete` on the mirror does not kill the static Pod.** The kubelet
  recreates it. To remove it you must move the YAML out of the directory, on the
  node itself.
- Pickup latency is governed by the kubelet's `fileCheckFrequency` — expect
  roughly 20 seconds, not instant.

**Why the control plane must use them.** `kube-apiserver` cannot be a Deployment,
because a Deployment is reconciled by the controller-manager, which is an API
server client, which needs the API server to already be running. Chicken and egg.
The kubelet reads from **local disk** and needs nobody's permission, so it can
bootstrap the API server from nothing.

```
/etc/kubernetes/manifests/
├── etcd.yaml
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
└── kube-scheduler.yaml
```

Edit one of those files and the kubelet detects the change and **restarts that
component by itself**. There is no `systemctl restart kube-apiserver`. Pure CKA
material and 100% invisible on EKS.

### 1.10 Nodes: registration, conditions and heartbeats

> 🟡 **KCNA · SKIM** — KCNA needs: the kubelet self-registers, and `Ready` is the condition that matters. Lease timing detail is CKA.

- **Self-registration:** the kubelet registers itself with the API server. You do
  not create Node objects by hand.
- **Node conditions:** `Ready`, `MemoryPressure`, `DiskPressure`, `PIDPressure`,
  `NetworkUnavailable`.
- **Heartbeats:** the kubelet updates a **Lease** object in the `kube-node-lease`
  namespace (roughly every 10 s). It is a deliberately tiny object — updating the
  full Node status every few seconds would hammer etcd.

`Ready` has **three** values, and the difference decides which taint you get:

| `Ready` | Meaning | Taint applied |
|---|---|---|
| `True` | Healthy, accepting Pods | none |
| `False` | The kubelet **is reporting** and says it is not healthy | `node.kubernetes.io/not-ready` |
| `Unknown` | The node **stopped reporting** — the controller has no idea | `node.kubernetes.io/unreachable` |

> **This is the distinction most people get wrong.** A dead kubelet, a powered-off
> machine or a cut network all produce `Unknown` → **`unreachable`**, because
> silence is not the same as a report of ill health. `not-ready` means the kubelet
> is alive and honest about a problem (no CNI, disk full, runtime down).

### 1.11 What happens when heartbeats stop — the full timeline

> 🔴 **KCNA · SKIP FOR NOW** — Pure CKA. **No KCNA question asks you for seconds or flag names.** Comes back 3 Sep for CKA.

This is the single best integrated exercise in this note. Every number below is a
default and every one is a flag you can change.

```
T = 0s     kubelet stops updating its Lease
           (power cut, kernel panic, kubelet crash, network partition)
             │
             │   node-lifecycle-controller polls every --node-monitor-period = 5s
             │
             ▼
T = 50s    --node-monitor-grace-period expires
           ├─▶ Node condition Ready: True → Unknown   (or False)
           ├─▶ Taint  node.kubernetes.io/unreachable:NoSchedule   ← stops NEW pods
           └─▶ Taint  node.kubernetes.io/unreachable:NoExecute    ← starts the clock
             │
             │   Pods carry an automatic toleration for that taint,
             │   tolerationSeconds = 300 (--default-unreachable-toleration-seconds)
             │
             ▼
T = 350s   taint-eviction-controller deletes the Pod objects from the API
 (~5m50s)  └─▶ ReplicaSet controller notices 2/3 and creates a replacement
             └─▶ scheduler binds the new Pod to a healthy node
               └─▶ that node's kubelet pulls the image and starts the container
```

**Version numbers you must pin down.**

| Flag | Component | Default | Note |
|---|---|---|---|
| `--node-monitor-period` | controller-manager | **5s** | How often health is polled |
| `--node-monitor-grace-period` | controller-manager | **50s** | **Was 40s up to v1.31; changed to 50s in v1.32.** Check your cluster's version. |
| `--node-startup-grace-period` | controller-manager | **1m0s** | Longer window for a booting node |
| `--default-not-ready-toleration-seconds` | **apiserver** | **300** | Injected into Pods by admission |
| `--default-unreachable-toleration-seconds` | **apiserver** | **300** | Injected into Pods by admission |
| `--node-eviction-rate` | controller-manager | **0.1/s** | 1 node per 10 s — mass eviction is deliberately slow |
| `--pod-eviction-timeout` | — | **REMOVED** | Deprecated v1.26, **removed v1.27**. If a question offers it, it is stale. |

**Both effects, not one.** The node lifecycle controller applies
`unreachable`/`not-ready` with **`NoSchedule` *and* `NoExecute`**. `NoSchedule`
immediately stops new Pods landing there; `NoExecute` starts the 300-second
eviction countdown for the Pods already on it. On `kubectl describe node` of a
downed node you will see **two** taint lines with the same key. Exam-grade detail.

**Nobody "moves" a Pod. Four actors hand off in sequence:**

| # | Actor | Action |
|---|---|---|
| 1 | **taint-eviction-controller** | Deletes the **Pod object from the API**. If the machine is genuinely dead it never learns this — Kubernetes' view and reality have diverged, which is exactly why a StatefulSet will not create a replacement until you force-delete or fence the node. |
| 2 | **replicaset-controller** | Its watch sees 2 Pods where `replicas: 3`. Creates a **brand-new Pod object** — new name, new UID, new IP. Nothing was moved or restored. |
| 3 | **kube-scheduler** | Sees a Pod with empty `spec.nodeName`, filters out the tainted node, scores the rest, writes `nodeName`. |
| 4 | **kubelet** (healthy node) | Its watch sees a Pod bound to it. Pulls the image, asks the CRI runtime to start the container. |

> **DaemonSet Pods are exempt.** They receive `NoExecute` tolerations for
> `not-ready` and `unreachable` with **no `tolerationSeconds`**, so they tolerate
> the taint forever and are never evicted for node health. That is correct
> behaviour — a node-local agent should stay with its node.

---

## 2. Objects & Fields That Matter

### 2.1 What is actually inside each file on a kubeadm control plane node

> 🔴 **KCNA · SKIP FOR NOW** — **Zero KCNA value** — the exam never asks about file contents, kubeconfig identities or the PKI. This is the single highest-value section for CKA. Comes back 3 Sep for CKA.

Knowing the paths is worth little. Knowing **what kind of document each one is**
is worth a lot — three of the files below look similar and are not.

```
/etc/kubernetes/
├── manifests/               ← static Pod manifests (Pod objects)
│   ├── etcd.yaml
│   ├── kube-apiserver.yaml
│   ├── kube-controller-manager.yaml
│   └── kube-scheduler.yaml
├── pki/                     ← the entire cluster PKI
├── admin.conf               ← kubeconfig — the human administrator
├── super-admin.conf         ← kubeconfig — break-glass (init node only)
├── kubelet.conf             ← kubeconfig — this node's kubelet
├── controller-manager.conf  ← kubeconfig — the controller-manager
└── scheduler.conf           ← kubeconfig — the scheduler

/var/lib/kubelet/
├── config.yaml              ← KubeletConfiguration (NOT a kubeconfig)
├── kubeadm-flags.env        ← extra CLI flags for the kubelet unit
└── pki/
    └── kubelet-client-current.pem   ← symlink to the rotating client cert

/var/lib/etcd/               ← etcd's data directory
```

---

#### `/etc/kubernetes/admin.conf` — kubeconfig for the human admin

Generated by `kubeadm init`. This is the file you copy to `~/.kube/config`.

```yaml
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...   # the cluster CA
    server: https://192.168.1.10:6443               # the control plane endpoint
users:
- name: kubernetes-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTi...      # CN=kubernetes-admin
    client-key-data: LS0tLS1CRUdJTi...              #  O=kubeadm:cluster-admins
contexts:
- name: kubernetes-admin@kubernetes
  context:
    cluster: kubernetes
    user: kubernetes-admin
current-context: kubernetes-admin@kubernetes
```

> ⚠️ **This changed in Kubernetes v1.29 and most tutorials are now wrong.**
> The certificate in `admin.conf` used to be in the group **`system:masters`**,
> which bypasses RBAC entirely. It is now in **`kubeadm:cluster-admins`**, an
> ordinary RBAC group bound to the `cluster-admin` ClusterRole by a
> ClusterRoleBinding also named `kubeadm:cluster-admins`.
>
> The practical difference: `admin.conf` is now **subject to RBAC**. Delete that
> ClusterRoleBinding and `admin.conf` can do nothing.

---

#### `/etc/kubernetes/super-admin.conf` — the break-glass credential

Also generated by `kubeadm init`, and **only on the node where `init` ran** —
`kubeadm join --control-plane` does not create it.

```yaml
users:
- name: kubernetes-super-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTi...      # CN=kubernetes-super-admin
    client-key-data: LS0tLS1CRUdJTi...              #  O=system:masters
```

`system:masters` is hard-coded in the API server to **bypass authorization
altogether**. No RBAC check applies. Its only purpose is recovering a cluster you
locked yourself out of by breaking RBAC. Keep it off your laptop.

There is a neat bootstrap detail here: kubeadm uses `super-admin.conf` to create
the `kubeadm:cluster-admins` ClusterRoleBinding, because `admin.conf`'s identity
has no power until that binding exists and cannot grant itself.

---

#### `/etc/kubernetes/kubelet.conf` — kubeconfig for this node's kubelet

Same document *kind*, different identity, and one structural surprise:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...
    server: https://192.168.1.10:6443
users:
- name: system:node:worker-01
  user:
    # NOT client-certificate-data — a PATH, because this cert rotates
    client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
    client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
contexts:
- name: system:node:worker-01@kubernetes
  context:
    cluster: kubernetes
    user: system:node:worker-01
current-context: system:node:worker-01@kubernetes
```

- Identity: **CN = `system:node:<nodeName>`, O = `system:nodes`**. The `<nodeName>`
  must match the node's registered name **exactly** — the Node authorizer keys on
  it, and it is how a kubelet is restricted to reading only its own Pods.
- **It references a file, not embedded data.** kubeadm enables automatic client
  certificate rotation, so the cert is a `.pem` **symlink** under
  `/var/lib/kubelet/pki/` that the kubelet replaces on renewal. Embedding the data
  would make rotation impossible.
- **Consequence:** `kubeadm certs check-expiration` deliberately **does not list
  `kubelet.conf`**, because the kubelet manages that cert itself. If a question
  asks why it is missing from the output, that is the answer.
- If this cert expires or the file is corrupted, the API server rejects the
  kubelet and the node goes `NotReady`.

---

#### `/var/lib/kubelet/config.yaml` — **not** a kubeconfig

Completely different kind of document. This is a **Kubernetes API object of kind
`KubeletConfiguration`** that configures the kubelet process itself, read by the
systemd unit instead of passing forty CLI flags.

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
staticPodPath: /etc/kubernetes/manifests   # ← where static Pods come from
cgroupDriver: systemd                      # MUST match the container runtime
clusterDNS:
- 10.96.0.10                               # the CoreDNS Service ClusterIP
clusterDomain: cluster.local
rotateCertificates: true                   # kubelet renews its own client cert
readOnlyPort: 0                            # the old unauthenticated port, disabled
healthzPort: 10248
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook                            # the kubelet asks the API server
```

Two of these are places kubeadm deliberately overrides the upstream default:

- **`cgroupDriver: systemd`** (upstream default is `cgroupfs`). It **must** match
  what containerd is configured with. A mismatch is the single most common
  "kubelet will not start" failure in a hand-built lab. Expect it on 30 Aug.
- **`rotateCertificates: true`** (upstream default `false`). This is what creates
  the rotating `.pem` referenced by `kubelet.conf`.

Change `staticPodPath` here and you change where the kubelet looks for static
Pods — including the control plane's own manifests.

---

#### `/etc/kubernetes/pki/` — the whole cluster PKI

Kubernetes authenticates its components with **client certificates**, so this
directory *is* the cluster's identity system. **Three independent CAs**, not one:

```
/etc/kubernetes/pki/
├── ca.crt / ca.key                       # cluster CA (CN=kubernetes-ca) — signs everything below
├── apiserver.crt / .key                  # API server's TLS serving cert (CN=kube-apiserver)
├── apiserver-kubelet-client.crt / .key   # API server → kubelet  (logs, exec, port-forward)
├── apiserver-etcd-client.crt / .key      # API server → etcd
├── sa.key / sa.pub                       # RSA keypair signing ServiceAccount tokens (NOT a cert)
├── front-proxy-ca.crt / .key             # 2nd CA: the API aggregation layer
├── front-proxy-client.crt / .key         # aggregator → extension API servers
└── etcd/                                 # 3rd CA: etcd's own, fully independent
    ├── ca.crt / ca.key                   # (CN=etcd-ca)
    ├── server.crt / .key                 # etcd's serving cert
    ├── peer.crt / .key                   # etcd member ↔ member
    └── healthcheck-client.crt / .key     # liveness probes against etcd
```

Points that get tested:

- **`sa.key` / `sa.pub` are not certificates.** They are a plain RSA keypair used
  to sign and verify ServiceAccount JWTs. Replace them and every existing
  ServiceAccount token in the cluster becomes invalid at once.
- **etcd has its own CA on purpose.** Compromising the cluster CA should not by
  itself grant direct access to the datastore.
- The `etcd/` subdirectory is **absent** when you use external etcd.
- **Expiry: leaf certificates last 1 year, the CAs last 10 years.**
  `kubeadm certs check-expiration` reports it; `kubeadm certs renew all` renews,
  and must be run **on every control plane node**, followed by restarting the
  static Pods. `kubeadm upgrade` renews them automatically, which is why clusters
  that are upgraded regularly never hit this and clusters left alone for 13
  months die mysteriously.

### 2.2 kubeconfig anatomy — the three questions

> 🟡 **KCNA · PARTIAL** — read only the three-question idea: **a context = cluster + user + namespace**. Skip the certificate-identity discussion.

Every kubeconfig, no matter whose, answers exactly three questions. Read it in
this order and it stops looking arbitrary:

```yaml
apiVersion: v1
kind: Config

# ── 1. WHERE AM I GOING?  (the API endpoint + who to trust) ──────────────
clusters:
- name: prod-cluster
  cluster:
    server: https://192.168.1.10:6443
    certificate-authority-data: LS0tLS1CRUdJTi...   # CA that signs the server cert

# ── 2. WHO AM I?  (my credentials) ───────────────────────────────────────
users:
- name: carlos-admin
  user:
    client-certificate-data: LS0tLS1CRUdJTi...      # CN → username, O → group
    client-key-data: LS0tLS1CRUdJTi...

# ── 3. THE BINDING  (which "where" + which "who" + a default namespace) ──
contexts:
- name: prod-context
  context:
    cluster: prod-cluster      # from block 1
    user: carlos-admin         # from block 2
    namespace: backend         # default namespace for commands in this context

current-context: prod-context  # the one that is active right now
```

**A context is a triple: (cluster, user, namespace).** Switching context switches
all three at once — that is why `kubectl config use-context` can silently change
which namespace your commands hit.

**Where your identity comes from.** There is no `User` object in Kubernetes. Your
username is the **CN** of your client certificate and your groups are its **O**
fields. RBAC then binds those strings to roles. That is the whole model, and it is
why EKS needs a translation layer to map IAM identities onto it.

```bash
kubectl config get-contexts
kubectl config use-context prod-context
kubectl config set-context --current --namespace=backend

# Read your own identity out of the certificate
openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -subject
```

### 2.3 Ports (official table)

> 🟡 **KCNA · PARTIAL** — memorise **6443** (API server) and the **30000–32767** NodePort range. The rest (10250/10256/10257/10259) is CKA.

**Control plane**

| Protocol | Direction | Port | Component |
|---|---|---|---|
| TCP | Inbound | **6443** | kube-apiserver |
| TCP | Inbound | **2379–2380** | etcd (client API / peer) |
| TCP | Inbound | **10250** | Kubelet API |
| TCP | Inbound | **10259** | kube-scheduler |
| TCP | Inbound | **10257** | kube-controller-manager |

**Worker**

| Protocol | Direction | Port | Component |
|---|---|---|---|
| TCP | Inbound | **10250** | Kubelet API |
| TCP | Inbound | **10256** | kube-proxy (health check) |
| TCP | Inbound | **30000–32767** | NodePort Services |

> Ports 10251/10252 (the old insecure scheduler / controller-manager endpoints)
> **have been removed**. A blog or practice question mentioning them is stale.

---

## 3. Speed Patterns

> ⚪ **NOT AN EXAM SECTION** — Empty until Block 2 (CKA).

<!-- EMPTY UNTIL BLOCK 2 (CKA). Do not fill during KCNA. -->

---

## 4. Hands-On Lab

> 🔴 **KCNA · SKIP FOR NOW** — Needs the kubeadm cluster, which does not exist until 30 Aug. Comes back 3 Sep for CKA.

> **Deferred until Sun 30 Aug**, when the kubeadm cluster exists.

1. List the static Pods and find their manifests on disk.
2. `openssl x509 -noout -subject` on the certs behind `admin.conf`,
   `kubelet.conf` and `super-admin.conf`. Confirm the three different identities
   with your own eyes.
3. Break the scheduler on purpose (move `kube-scheduler.yaml` out of the
   directory), create a Deployment, watch the Pods sit `Pending`, put the file
   back, watch them resolve by themselves.
4. `sudo systemctl stop kubelet` on a worker. Time it: when does the node go
   `NotReady`, which taints appear, and when exactly do the Pods disappear?
   Compare against the timeline in §1.11.
5. Take an etcd snapshot.

---

## 5. Verification

> 🔴 **KCNA · SKIP FOR NOW** — Needs a cluster. Run these on 30 Aug. Comes back 3 Sep for CKA.

```bash
# Control plane components, as real Pods
kubectl get pods -n kube-system -o wide

# The static Pods, on disk, on the control plane node
sudo ls -l /etc/kubernetes/manifests/

# Confirm a control plane Pod is a mirror Pod
kubectl get pod kube-apiserver-cp1 -n kube-system \
  -o jsonpath='{.metadata.annotations}' | tr ',' '\n'
# -> must contain kubernetes.io/config.mirror

# Which controllers are enabled, and the flags behind the timeline in §1.11
sudo grep -E 'controllers|node-monitor' /etc/kubernetes/manifests/kube-controller-manager.yaml

# Who is the active controller-manager and scheduler (leader election)
kubectl get lease -n kube-system

# The kubelet's own config, and where it reads static Pods from
sudo grep -E 'staticPodPath|cgroupDriver|clusterDNS' /var/lib/kubelet/config.yaml

# The three identities, read straight from the certificates
sudo grep client-certificate /etc/kubernetes/kubelet.conf
sudo kubeadm certs check-expiration

# Nodes, conditions, taints and heartbeats
kubectl get nodes -o wide
kubectl describe node worker-01 | sed -n '/Taints/,/Conditions/p'
kubectl get leases -n kube-node-lease

# Watch an eviction happen in real time (after stopping a kubelet)
kubectl get pods -o wide -w
```

---

## 6. Failure Modes

> 🟡 **KCNA · SKIM** — KCNA: read only the **no-CNI** row and the **LoadBalancer `<pending>`** row. The rest is CKA troubleshooting.

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `kubectl` returns `connection refused` on :6443 | API server down | `sudo crictl ps -a \| grep apiserver`; `sudo journalctl -u kubelet -f` | Check `/etc/kubernetes/manifests/kube-apiserver.yaml` — a typo there takes it down |
| All new Pods `Pending`, existing ones fine | Scheduler down, or no node survives filtering | `kubectl get events -A --sort-by=.lastTimestamp`; `kubectl describe pod <p>` | Check the scheduler static Pod / node taints / requests |
| Dead Pods are never replaced, but the cluster otherwise works | **controller-manager** down | `kubectl get pods -n kube-system \| grep controller-manager` | Check its static Pod manifest |
| Node `NotReady` with `Ready: Unknown` | Node stopped reporting — kubelet dead, machine down, or network cut | `kubectl describe node <n>` → Conditions + Taints | Restart kubelet / restore the machine |
| Node `NotReady` with `Ready: False` | Kubelet **is** reporting a problem — usually no CNI or disk pressure | `kubectl describe node <n>` → the condition message | Install a CNI / free disk |
| I delete a control plane Pod and **it comes back** | Static Pod; you deleted the mirror | `kubectl get pod <p> -o yaml \| grep config.mirror` | Move the YAML out of `/etc/kubernetes/manifests/` on the node |
| Fresh cluster, every Pod `Pending`, CoreDNS too | **No CNI installed** | `kubectl get nodes` → `NotReady`; `describe node` → `NetworkNotReady` | Install a CNI plugin (Calico, Flannel, Cilium) |
| kubelet will not start on a fresh install | `cgroupDriver` mismatch between kubelet and containerd | `sudo journalctl -u kubelet -n 50`; `grep cgroupDriver /var/lib/kubelet/config.yaml` | Set both to `systemd` |
| `Service type: LoadBalancer` stays `<pending>` | **No cloud-controller-manager** | `kubectl get pods -n kube-system \| grep cloud` (empty) | Expected on kubeadm. Use NodePort, or install MetalLB |
| Whole cluster stops authenticating after ~1 year | Leaf certificates expired | `sudo kubeadm certs check-expiration` | `sudo kubeadm certs renew all`, then restart the static Pods |
| `kubectl` says `Unauthorized` with a valid-looking cert | RBAC binding removed — `admin.conf` is no longer `system:masters` | `kubectl auth can-i --list` | Recreate the `kubeadm:cluster-admins` binding using `super-admin.conf` |

---

## 7. EKS vs Vanilla ← rewrite this section in your own words

> ⚪ **NOT AN EXAM SECTION** — Your personal blind-spot map, not an exam section. Worth 5 minutes, worth 0 questions.

> **Learner-owned section.** Starting point below. Add rows from your day job.

| Behaviour | On EKS | On kubeadm (what the exam tests) |
|---|---|---|
| Control plane components | Run in an AWS-owned account you cannot see. No SSH, no access. | Static Pods in `/etc/kubernetes/manifests/` |
| `kubectl get pods -n kube-system` | `coredns`, `aws-node`, `kube-proxy`, maybe `ebs-csi-*` | **Plus** `kube-apiserver-*`, `etcd-*`, `kube-scheduler-*`, `kube-controller-manager-*` |
| Controller-manager flags (node-monitor-grace-period, eviction rates) | **Not tunable.** AWS owns the process. | Edit the static Pod manifest; the kubelet restarts it |
| Access to etcd | None. AWS backs it up for you. | `etcdctl` on the node. **The backup is your responsibility.** |
| The PKI | Invisible. No `/etc/kubernetes/pki`. | Three CAs, yours to renew. Certs expire after 1 year. |
| Your identity | An **IAM** principal, mapped to a Kubernetes user/group by EKS | The **CN and O of an x509 certificate**. No IAM anywhere. |
| Installing the cluster | Terraform / `eksctl` / console | `kubeadm init` + `kubeadm join` + install a CNI by hand |
| **CNI** | Pre-installed (Amazon VPC CNI). The cluster is born working. | **Nothing ships with it.** Nodes stay `NotReady` until you install one |
| Upgrading | One API call; node groups handled separately | `kubeadm upgrade plan` → `apply` on the CP → `kubeadm upgrade node` on workers, with `drain`/`uncordon` |
| cloud-controller-manager | Present (AWS runs it) | **Absent** on-prem |
| `type: LoadBalancer` | An NLB appears by itself | `<pending>` forever |
| Node failure handling | The same controller loops — but the **cloud**-node-lifecycle-controller can also ask EC2 whether the instance is really gone | Only the timeout-based path in §1.11. Nobody can confirm the machine died. |
| Certificate renewal | Not a problem you have | `kubeadm certs check-expiration` / `renew` |
| etcd backup | No endpoint, no certs — etcd is unreachable. Backups are API-object level (e.g. Velero) | etcd is a static Pod on a node you can SSH into; `snapshot save` over mutual TLS with `pki/etcd/` certs |
| etcd restore | Does not exist; a lost control plane is AWS's incident | Offline file write (`etcdutl`) + repoint `hostPath` + kubelet restarts the control plane |
| Control plane down | There is no control-plane node to stand on | You stop it by moving manifests; `crictl` is the only window while the API is down |
| `hostPath` | You only meet it in agent DaemonSets | Appears in every control-plane manifest |

**The rule that summarises all of it:** every place EKS does something
automatically is a place the exam expects you to do it by hand — and therefore a
place where you must know *what* is actually happening.

---

## 8. Timed Drills

> ⚪ **NOT AN EXAM SECTION** — Empty until Block 2 (CKA).

<!-- EMPTY UNTIL BLOCK 2 (CKA). -->

---

## 9. Objectives Covered

> ⚪ **NOT AN EXAM SECTION** — Tracker. Tick as you go.

- [ ] Declarative vs imperative; the reconciliation loop (desired vs current state)
- [ ] Control plane: kube-apiserver, etcd, kube-scheduler, kube-controller-manager, cloud-controller-manager
- [ ] What kube-controller-manager is: one process, many independent loops that **write** via the API server
- [ ] The main controllers and their ownership chains
- [ ] Node components: kubelet, kube-proxy, container runtime
- [ ] etcd: what it stores, why it is the only stateful component, quorum
- [ ] The API server is the ONLY component that talks to etcd
- [ ] kubeadm init / join and what each generates
- [ ] Static Pods and `/etc/kubernetes/manifests/`
- [ ] kubeconfig: clusters, users, contexts
- [ ] Node conditions, Leases, taints and the eviction timeline
- [ ] Namespaces, ResourceQuota, LimitRange ← **deferred to notes 02 and 07**
- [ ] cordon / drain / uncordon; cluster upgrade ← **CKA depth, Block 2**

---

## KCNA — Traps & Distractors

> 🟢 **KCNA · READ CLOSELY** — core exam material.

<!-- TEMPORARY. Delete after the exam; migrate survivors into §6. -->

| Distractor | Why it is wrong |
|---|---|
| "The API server tells the kubelet to create the Pod" | The kubelet watches (pull). Nobody pushes to it. |
| "The scheduler starts the Pod on the node" | It only writes `spec.nodeName`. The kubelet starts it. |
| "The kubelet reads from etcd" | Only the API server reads and writes etcd. |
| "The controller-manager checks state and reports drift" | It **reconciles** — it issues write requests that change the cluster. |
| "Each controller is its own process" | Logically separate, but **compiled into one binary, one process**. |
| "A Deployment creates Pods" | A Deployment creates **ReplicaSets**; the ReplicaSet creates Pods. |
| "The node lifecycle controller evicts the Pods" | Since **v1.29** eviction is the separate **taint-eviction-controller**. |
| "The Pod is moved to another node" | Pods are never moved. The old object is deleted and a **brand-new** Pod is created — new name, new UID, new IP. |
| "If the control plane goes down, the applications go down" | Pods keep running. What you lose is the ability to change anything. |
| "A 4-member etcd cluster tolerates 2 failures" | Quorum of 4 is 3 → tolerates 1. Same as 3 members, with worse latency. |
| "`kubectl delete pod kube-apiserver-cp1` removes the API server" | It is a mirror Pod. The kubelet recreates it from disk. |
| "Every Kubernetes cluster has a cloud-controller-manager" | Only on a cloud provider. On-prem it does not exist. |
| "kube-proxy routes all Pod traffic" | Only network rules for **Services**. Pod-to-Pod is the **CNI**. |
| "`admin.conf` is in the `system:masters` group" | **Not since v1.29.** It is `kubeadm:cluster-admins`, and it is subject to RBAC. `super-admin.conf` holds `system:masters`. |
| "`kubelet.conf` embeds the client certificate" | It **references a rotating `.pem` file** on disk, because kubeadm enables cert rotation. |
| "`/var/lib/kubelet/config.yaml` is a kubeconfig" | It is a **`KubeletConfiguration`** object. Different kind entirely. |
| "Pods are evicted 40 seconds after a node fails" | 50 s (v1.32+) to mark it, **then 300 s** of toleration. ≈ 5m50s total. |
| "`--pod-eviction-timeout` controls eviction" | **Removed in v1.27.** Eviction is driven by `tolerationSeconds`. |
| "A `NotReady` node means the kubelet reported a problem" | Only if `Ready: False`. If the node went silent it is `Ready: Unknown` → `unreachable`. |

**X ≠ Y**

- **kubelet ≠ kube-proxy** — runs containers vs maintains Service network rules.
- **kube-controller-manager ≠ cloud-controller-manager** — generic vs provider-specific.
- **etcd ≠ API server** — datastore vs interface. etcd has no idea what a Pod is.
- **Static Pod ≠ mirror Pod** — the real one on disk vs its read-only reflection.
- **DaemonSet ≠ static Pod** — both are "one per node", but the DaemonSet is
  reconciled by the control plane and a static Pod by the local kubelet.
- **Deployment controller ≠ ReplicaSet controller** — revisions vs Pod count.
- **node-lifecycle-controller ≠ taint-eviction-controller** — marks and taints vs deletes.
- **`Ready: False` ≠ `Ready: Unknown`** — reported illness vs silence. Different taints.
- **`admin.conf` ≠ `super-admin.conf`** — RBAC-bound cluster-admin vs `system:masters` break-glass.
- **`kubelet.conf` ≠ `/var/lib/kubelet/config.yaml`** — kubeconfig (identity) vs KubeletConfiguration (behaviour).
- **`sa.key` ≠ a certificate** — an RSA keypair that signs ServiceAccount tokens.
- **Node NotReady ≠ Node deleted** — a condition; the Node object still exists.
- **Declarative ≠ YAML** — YAML applied with `create` is imperative. `apply` + reconciliation is what makes it declarative.

---

## 10. Active Recall

> 🟡 **KCNA · PARTIAL** — **KCNA scope: questions 1–13, 15, 16, 18, 19, 21, 22, 27, 36.** The rest (14, 17, 20, 23–26, 28–35) are CKA — leave them.

Closed book, out loud. Any hesitation becomes a row in `mistakes.md`.

1. Name the 5 control plane components and the 3 node components.
2. Which component is the only one that talks to etcd?
3. The `kube-scheduler` dies. What still works and what does not?
4. The `kube-apiserver` dies. Do my applications go down?
5. What exactly does the scheduler write when it "schedules" a Pod?
6. Name the scheduler's two phases and what each decides.
7. How does the kubelet find out a new Pod was assigned to it?
8. What are the kubelet's three sources of PodSpecs?
9. Define `kube-controller-manager` in one sentence — process model included.
10. Name the four steps of a reconciliation loop. Which one do people forget?
11. Why is there only ONE controller-manager Pod if there are 50 controllers?
12. In an HA control plane, why is only one controller-manager replica active?
13. Which controller creates Pods for a Deployment? Trace the full chain.
14. Which controller deletes orphaned objects, and what field does it use?
15. What is a static Pod and who manages it?
16. Why must the control plane be static Pods rather than Deployments?
17. You run `kubectl delete pod etcd-cp1`. What happens?
18. Why must etcd have an odd number of members? How many failures does 5 tolerate?
19. What does `cloud-controller-manager` do and why does your cluster not have one?
20. Which port does the API server listen on? The kubelet? The scheduler?
21. What is a Lease object, which namespace, and how often is it written?
22. `Ready: False` vs `Ready: Unknown` — what causes each, and which taint follows?
23. Give the full node-failure timeline with numbers, from T=0 to Pod deletion.
24. Which two effects are applied with the `unreachable` taint, and what does each do?
25. Name the four actors that hand off when a node dies, in order.
26. Why are DaemonSet Pods not evicted from a failed node?
27. What are the three questions every kubeconfig answers?
28. Where does your *username* come from when you use a client certificate?
29. `admin.conf` vs `super-admin.conf` — identity, group, and which node has each.
30. Why does `kubelet.conf` reference a file path instead of embedding the cert?
31. Why is `kubelet.conf` absent from `kubeadm certs check-expiration`?
32. What kind of object is `/var/lib/kubelet/config.yaml`, and which field sets the static Pod directory?
33. Name the three CAs under `/etc/kubernetes/pki/` and what each signs.
34. What are `sa.key` and `sa.pub`, and what breaks if you replace them?
35. How long do kubeadm leaf certs last? The CAs?
36. On EKS, why does `kubectl get pods -n kube-system` not show the API server?

---

## 11. Scenario Drills

> 🟡 **KCNA · PARTIAL** — **KCNA scope: Scenario 6 only.** Scenarios 1–5 depend on §1.11 and §2.1, which you are skipping.

Integrated problems. Reason out loud through the *whole* chain before checking
yourself — naming the right component is only half a correct answer; the exam
rewards knowing the order things happen in.

---

**Scenario 1 — The silent worker**

A 3-node cluster runs `web` as a Deployment with `replicas: 3`, one Pod per node.
At 14:00:00 someone pulls the power cable on `worker-02`.

- a) At what clock time does `kubectl get nodes` first show `NotReady`?
- b) Is the `Ready` condition `False` or `Unknown`? Which taint appears, and with
  which effect(s)?
- c) At what clock time does the `web` Pod on `worker-02` disappear from
  `kubectl get pods`?
- d) Name every component that acts between 14:00:00 and the new Pod running,
  in order, and say what each one writes.
- e) Does the new Pod keep the old Pod's name? Its IP?
- f) There is also a `fluentd` DaemonSet Pod on `worker-02`. What happens to it,
  and why is that different?
- g) Which single flag would you change to make step (a) happen in half the time,
  and on which component?

---

**Scenario 2 — The half-dead cluster**

You SSH into `cp1`. `kubectl get nodes` works and returns all three nodes as
`Ready`. But a Deployment scaled from 3 to 5 replicas twenty minutes ago still
shows `3/5`, and a Pod you deleted by hand was never replaced.

- a) Which control plane component is broken? How do you know it is not the
  scheduler and not the API server?
- b) Give the exact command that confirms your diagnosis.
- c) Where on disk do you look, and what would make that component fail to start?
- d) You fix the file. What do you run to restart the component — and why is the
  answer *not* `systemctl restart`?
- e) While it was down, was any data lost from etcd?

---

**Scenario 3 — Locked out**

A colleague "cleaned up unused RBAC" and deleted a ClusterRoleBinding. Now
`kubectl get pods` from your laptop returns
`Error from server (Forbidden): pods is forbidden: User "kubernetes-admin" cannot list resource "pods"`.

- a) Which ClusterRoleBinding did they delete? What group and ClusterRole did it join?
- b) Why did this work before v1.29 and break now?
- c) Which file on which node recovers the cluster, and what identity does it carry?
- d) Why can that file fix the problem when `admin.conf` cannot?
- e) Why should that file *not* live on your laptop?

---

**Scenario 4 — The cluster that stopped after a holiday**

A lab cluster built 13 months ago and never touched is powered on. Every
`kubectl` command fails with a TLS error. `systemctl status kubelet` shows the
kubelet running but logging authentication failures.

- a) What happened? Be specific about which certificates and their lifetime.
- b) Which command diagnoses it, and which file will be conspicuously *absent*
  from the output? Why?
- c) What is the fix, and on which nodes must it run?
- d) After renewing, why must you restart the static Pods, and how?
- e) Why do production clusters almost never hit this?

---

**Scenario 5 — The Pod that will not schedule**

You apply a Deployment. The Pod sits `Pending`. `kubectl describe pod` shows
`0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 2 Insufficient cpu.`

- a) Which component produced that message, and during which of its two phases?
- b) The Pod is `Pending`, so `spec.nodeName` is empty. Confirm: has any kubelet
  seen this Pod at all?
- c) Give three distinct ways to make it schedulable, and the trade-off of each.
- d) If instead the message had been about a taint on *every* node, which
  scenario from this note would you suspect?
- e) On EKS, which of the three fixes in (c) would you never use, and why?

---

**Scenario 6 — Trace the write**

You run `kubectl scale deploy web --replicas=5`.

Trace the complete path from your keystroke to a running container. Name every
component the request or its consequences touch, in order, and say for each one
whether it **reads**, **writes**, or **both** — and whether it talks to etcd
directly. There are at least seven steps.
