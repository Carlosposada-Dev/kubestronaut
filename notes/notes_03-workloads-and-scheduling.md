---
exams: [KCNA, CKA, CKAD]
domain: Workloads & Scheduling
kcna_domains: 1.3 Scheduling
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/scheduling-eviction/ (kube-scheduler, assign-pod-node, taint-and-toleration), /concepts/workloads/pods, /concepts/workloads/controllers/ (replicaset, deployment, daemonset, statefulset, job, cron-jobs), /concepts/configuration/manage-resources-containers, /tasks/configure-pod-container/quality-service-pod
template: B
language: en
scope: KCNA ONLY — CKA layer appended in Block 2 (from 10 Sep)
status: draft
written: 2026-08-31
k8s_version_checked_against: v1.37 (released 2026-08-26; previous stable v1.36.2). Defaults quoted have been stable for many releases; version-sensitive facts name the release that changed them.
---

# Workloads & Scheduling

Two questions. **Which object do I create** for a kind of work, and **how does a
Pod end up on a specific node**. KCNA area 1.3 ≈ 6–7 of the 60 questions.

---

## 1. Core Concepts

### 1.1 The scheduler is a controller that writes one field

kube-scheduler does not start containers, does not talk to nodes, and does not
talk to etcd. It runs the same watch → compare → decide → act loop as every
controller (note 01 §1.2), and its act step writes **one field**: `spec.nodeName`.

1. It **watches** the API server for Pods with `spec.nodeName` empty and
   `spec.schedulerName` matching its own name (default `default-scheduler`).
2. It runs the scheduling cycle (§1.2) against its cached view of the nodes.
3. It **POSTs a `Binding`** to the Pod's `/binding` subresource; the API server
   writes `spec.nodeName` into etcd. The scheduler never touches etcd itself.
4. The **kubelet on that node is watching** for Pods whose `spec.nodeName` is
   its own node name, sees it appear, and starts pulling images.

Nothing tells the kubelet to act — it notices. Which is why a Pod with
`spec.nodeName` set by hand runs without the scheduler ever seeing it.

**If the scheduler dies:** running Pods are untouched and Services keep routing.
Only **new Pods stay `Pending` forever**. "Scheduler down" is not an outage.

### 1.2 Filtering, then scoring

**Filtering** (old name *predicates*) removes every node that **cannot** run the
Pod: not enough **allocatable** CPU/memory for the Pod's **requests**,
`nodeSelector` or required node affinity unsatisfied, a `NoSchedule` taint not
tolerated, host port taken, node not `Ready` or cordoned. Hard yes/no.

**Scoring** (*priorities*) ranks the survivors 0–100 — resource balance after
placement, image already cached on the node, `preferred` affinity weights,
topology spread. Highest total wins, ties broken at random.

The two failures differ, and the exam tests the difference. **Filtering returned
zero nodes** → `Pending` plus a `FailedScheduling` event, and nothing changes
until the cluster changes. **Scoring picked a node you dislike** → the Pod runs;
never an error.

When filtering returns nothing, the scheduler may try **preemption**: a Pod with
higher `priorityClassName` priority can evict lower-priority Pods to make room.
Default priority is 0, so most Pods preempt nothing.

### 1.3 Why controllers exist above the Pod

A Pod is the smallest deployable unit and **mortal by design** — if its node
dies, the Pod object is deleted and nothing recreates it. Everything above a Pod
answers *who recreates it, and how many*:

```
Deployment  →  ReplicaSet  →  Pod    "N copies, and I can change versions"
DaemonSet             ────→  Pod     "exactly one per matching node"
StatefulSet           ────→  Pod     "N copies with stable identity and order"
CronJob     →  Job    ────→  Pod     "run to completion, on a schedule"
```

Each arrow is a real link in the child's `metadata.ownerReferences` (note 02
§1.10) — that is what makes deletion cascade downward.

### 1.4 Pod, ReplicaSet, Deployment

**Pod** — one or more containers sharing a network namespace (they reach each
other on `localhost`, share the Pod IP) and able to share volumes. Scheduled as
a unit, never split across nodes. `restartPolicy` defaults to `Always`, so the
kubelet restarts a crashed *container*, but nobody replaces a lost *Pod*. Bare
Pods are for debugging only.

**ReplicaSet** — keeps N Pods matching a label selector alive: count Pods
matching `spec.selector`, compare to `spec.replicas`, create or delete the
difference. It selects **by labels, not ownership**, so it will adopt existing
Pods whose labels match. The API server rejects a ReplicaSet whose
`spec.template.metadata.labels` do not match its own selector. Rarely created
directly.

**Deployment** — manages **ReplicaSets, not Pods**. This is the ownership fact
that already cost an answer (note 01 Q13): `deployment-controller` creates and
scales ReplicaSets, one per revision, and `replicaset-controller` creates the
Pods. A rolling update is therefore just *two ReplicaSets alive at once*, the
new scaling up as the old scales down; old ones are kept at 0 replicas so
`kubectl rollout undo` can scale them back (`revisionHistoryLimit`, default
**10**). `RollingUpdate` is the default strategy — `maxSurge` **25%**,
`maxUnavailable` **25%**; `Recreate` kills everything first and accepts
downtime. **Use for stateless apps with interchangeable replicas.**

### 1.5 DaemonSet — the gap from note 01 Q26, closed

**A DaemonSet runs exactly one Pod on every node that matches its criteria.**
You do not set `replicas` — **the field does not exist**. The node count *is*
the replica count. Add a node and a Pod appears on it within seconds; remove the
node and the Pod goes with it.

The mechanism matters, because "DaemonSets bypass the scheduler" is an outdated
answer that still shows up as a distractor:

- `daemonset-controller` watches **Nodes** and **Pods**, and for each node
  lacking one, creates a Pod.
- Since **v1.12** it does *not* set `spec.nodeName`. It creates the Pod with a
  `nodeAffinity` term requiring `metadata.name` **In** `[that-node]` and lets the
  **default scheduler** place it — normal filtering and scoring, with only ever
  one feasible node.
- It **injects tolerations automatically**: `not-ready`, `unreachable`,
  `disk-pressure`, `memory-pressure`, `pid-pressure`, `unschedulable`. The
  `NoExecute` ones carry **no `tolerationSeconds`** — tolerate forever.

That last point is the whole reason DaemonSets run infrastructure: when a node
goes sick you want the monitoring agent and the network plugin to stay on it,
because they are what might tell you why.

**Use for node-level agents** — CNI plugins (Calico, Cilium, Flannel),
`kube-proxy`, log collectors (Fluent Bit), node-exporter, CSI drivers. Not apps.
Add a `nodeSelector` to the Pod template and "one per node" becomes "one per
*matching* node".

### 1.6 StatefulSet

For Pods that are **not interchangeable**. Three guarantees a Deployment lacks:

1. **Stable ordinal names** — `web-0`, `web-1`, not random suffixes; a
   replacement `web-1` gets the same name back.
2. **Stable network identity** — `web-0.<service>.<ns>.svc.cluster.local`, via a
   required **headless Service** named in `spec.serviceName`.
3. **Stable storage** — `volumeClaimTemplates` creates one PVC *per Pod*, tied
   to the Pod name, so `web-1` always remounts `web-1`'s data. **PVCs are not
   deleted with the StatefulSet.**

Pods are created **0 → N-1**, each waiting for the previous to be Ready, and
deleted in reverse; `podManagementPolicy: Parallel` disables the ordering.
**Use for** databases, message queues, anything where a replica owns data or
peers find each other by name (etcd, Kafka, PostgreSQL).

### 1.7 Job and CronJob

**Job** runs Pods **to completion**, then stops. `restartPolicy` must be
`OnFailure` or `Never` — `Always` is rejected, because Pods that always restart
can never complete. `completions` (default 1) is how many successes are needed,
`parallelism` (1) how many run at once, `backoffLimit` (**6**) how many retries
before the Job is `Failed`. A finished Job and its Pods **stay** so logs can be
read; `ttlSecondsAfterFinished` auto-deletes them. Use for migrations, batch
work, backups.

**CronJob** creates a **Job** on a schedule — `CronJob → Job → Pod`, never a Pod
directly. `spec.schedule` is standard cron (`"*/5 * * * *"`), in **UTC** unless
`spec.timeZone` is set. `concurrencyPolicy` defaults to `Allow`; `Forbid` skips
a run if the previous is still going, `Replace` kills it. History kept:
`successfulJobsHistoryLimit` **3**, `failedJobsHistoryLimit` **1**.
`suspend: true` pauses scheduling without deleting anything.

### 1.8 Choosing — the decision tree

```
Does the work end on its own?
├─ yes ── on a schedule? ── yes → CronJob
│                        └─ no  → Job
└─ no  ── one per node?   ── yes → DaemonSet
          └─ no ── does each replica need its own identity/storage?
                   ├─ yes → StatefulSet
                   └─ no  → Deployment
```

A bare Pod is absent from this tree on purpose.

### 1.9 nodeSelector, node affinity, pod affinity

All three live **on the Pod** and pull it toward something.

**`spec.nodeSelector`** is the simple one: exact label equality, **every** entry
must match, no operators, no preference, no negation. A filtering input.

```yaml
spec:
  nodeSelector:
    disktype: ssd            # node must carry label disktype=ssd
    kubernetes.io/os: linux  # AND this one
```

Nodes carry built-in labels — `kubernetes.io/hostname`, `/os`, `/arch`,
`topology.kubernetes.io/zone`, `/region` — plus whatever you add with
`kubectl label node`.

**Node affinity** (`spec.affinity.nodeAffinity`) is the same purpose with more
grammar. `requiredDuringSchedulingIgnoredDuringExecution` acts in **filtering**
(hard; no match means `Pending`). `preferredDuringSchedulingIgnoredDuringExecution`
acts in **scoring** (soft; adds `weight` 1–100, schedules anyway if nothing
matches). Operators are `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt` —
`NotIn` and `DoesNotExist` give anti-affinity against nodes.

**`IgnoredDuringExecution` is exam bait.** The rule is evaluated at scheduling
time only; if node labels change afterwards the running Pod is **not** evicted.
Nothing enforces node affinity at runtime today. Structure trap:
`nodeSelectorTerms` entries are **OR**'d, `matchExpressions` inside one term are
**AND**'d.

**Pod affinity / anti-affinity** schedules relative to **other Pods**, not node
labels, with the same required/preferred pair. Every rule needs a mandatory
**`topologyKey`** — a *node* label naming the domain: `kubernetes.io/hostname`
means "the same node", `topology.kubernetes.io/zone` means "the same zone".
podAffinity puts me *near* matching Pods (a cache beside its app);
podAntiAffinity keeps me *away* (don't put all three replicas on one node). So
"spread across nodes" is podAntiAffinity on my own label with
`topologyKey: kubernetes.io/hostname`.

### 1.10 Taints and tolerations — and why they are NOT affinity

**Direction is the entire difference.** Affinity and `nodeSelector` live on the
**Pod** and say "I want that kind of node" — attraction. A **taint** lives on the
**node** and says "keep Pods off me" — repulsion. A **toleration** lives on the
Pod and says "that particular repulsion does not apply to me" — an exemption.

A taint is `key=value:effect`, set with `kubectl taint node`. `NoSchedule` makes
filtering drop the node for Pods without the toleration. `PreferNoSchedule` is a
soft scoring penalty. `NoExecute` does what NoSchedule does **and evicts Pods
already running** that do not tolerate it.

**The asymmetry KCNA tests:** a toleration is permission, not attraction.
Tolerating a taint does **not** send the Pod there — it only stops the node from
being filtered out. To make the Pod *land* there you need the toleration **and**
a nodeSelector or node affinity. Dedicated node pools always use both.

Kubernetes taints nodes itself when conditions go bad:
`node.kubernetes.io/not-ready`, `unreachable`, `memory-pressure`,
`disk-pressure`, `pid-pressure`, and `unschedulable` (what `kubectl cordon`
sets). On kubeadm, `node-role.kubernetes.io/control-plane:NoSchedule` is applied
at `kubeadm init` — the only reason your workloads avoid the control plane. The
older `node-role.kubernetes.io/master` taint was **removed in v1.25**.

`tolerationSeconds` on a `NoExecute` toleration means "tolerate, but only this
long". The `DefaultTolerationSeconds` admission controller adds **300s** for
`not-ready` and `unreachable` to Pods that do not set their own — that is the
5-minute delay before a dead node's Pods are deleted. DaemonSet Pods (§1.5) get
the same tolerations with **no** `tolerationSeconds`, so the clock never starts.

### 1.11 Requests vs limits, and QoS classes

```yaml
resources:
  requests:          # read by the SCHEDULER, at scheduling time
    cpu: "250m"      # 250 millicores = 0.25 core
    memory: "128Mi"
  limits:            # enforced by the KUBELET, at runtime
    cpu: "500m"
    memory: "256Mi"
```

**Requests are a scheduling contract; limits are a runtime ceiling.** Different
components, different moments — the highest-yield distinction in this note.

The scheduler sums the **requests** of all Pods assigned to a node against the
node's **allocatable** capacity (capacity minus `kube-reserved`,
`system-reserved` and the eviction threshold). It never reads limits and never
reads actual usage, so a node at 1% real CPU can be unschedulable because its
requests are fully committed. Over the **CPU** limit a container is
**throttled** — slowed, not killed, because CPU is compressible. Over the
**memory** limit it is **OOMKilled** and its restart counter increments, because
a page already handed out cannot be taken back. And because only requests are
checked at scheduling, a cluster **can be overcommitted**: the sum of limits may
exceed capacity, the sum of requests cannot.

**QoS class** is derived by the kubelet from those numbers — **you cannot set
it** — and appears in `status.qosClass`. It decides who dies first when the node
runs out of memory.

| Class | Condition | Evicted |
|---|---|---|
| **Guaranteed** | Every container sets requests **and** limits for **both** CPU and memory, and **requests == limits** | Last |
| **Burstable** | At least one container sets some request or limit, but not the Guaranteed pattern | Second |
| **BestEffort** | **No** container sets any request or limit | **First** |

"Every container" includes init containers — one sloppy sidecar demotes the
whole Pod. A `LimitRange` on the namespace injects defaults, which silently
changes the QoS class of everything created there afterwards.

### 1.12 Why a Pod stays `Pending`

`Pending` means the API server accepted the object but not all containers are
running. Two very different situations produce it, and the **event source**
separates them.

**A. Not scheduled** — `spec.nodeName` still empty, events from
`default-scheduler`, reason `FailedScheduling`:

- Insufficient free **requests** → `0/3 nodes are available: 3 Insufficient cpu`
- Untolerated taint (often a control-plane-only cluster) →
  `node(s) had untolerated taint {...}`
- `nodeSelector` / required affinity matches nothing →
  `node(s) didn't match Pod's node affinity/selector`
- Anti-affinity unsatisfiable → `node(s) didn't satisfy existing pods anti-affinity rules`
- PVC unbound → `pod has unbound immediate PersistentVolumeClaims`
- All nodes cordoned or `NotReady` → `node(s) were unschedulable`
- **The scheduler is not running** → **no event at all**, silence

That last one is the diagnostic gem: a Pending Pod with *no* scheduling event
has never been looked at, so nothing is watching.

**B. Scheduled, not started** — `spec.nodeName` is set and events come from
`kubelet`: image pulling, `ImagePullBackOff`, a volume not mounting. Not a
scheduling problem at all.

**First command, always:** `kubectl describe pod <name>`, read **Events** from
the bottom, and check the source column.

### 1.13 Why kube-apiserver is a static Pod and not a DaemonSet

The control plane also runs "one copy per control-plane node", which sounds
exactly like a DaemonSet. It cannot be one — bootstrap dependency loop. What a
DaemonSet needs before a Pod can run:

1. The DaemonSet object stored — **in etcd, written by the API server**
2. `daemonset-controller` watching it — **through the API server**
3. The controller creating a Pod object — **through the API server**
4. The scheduler binding it — **through the API server**
5. Only then does the kubelet see it

Every step needs a working kube-apiserver. Delivered this way, the API server
would have to be running before it could start. The loop has no entry point.

**Static Pods break it by removing the API server from the path.** The kubelet
watches a local directory — on kubeadm, `/etc/kubernetes/manifests/` — and
starts any Pod manifest it finds there by talking **directly to the container
runtime**. No API server, no scheduler, no controller-manager, no etcd: a file
and a local process. Hence `kube-apiserver.yaml`, `etcd.yaml`,
`kube-scheduler.yaml` and `kube-controller-manager.yaml` in that directory.

Two consequences the exam likes. Once the API server is up, the kubelet creates
a **mirror Pod** so the static Pod is visible in `kubectl get pods -n
kube-system` — but the mirror is a read-only reflection, so **deleting it does
not stop the container**; the kubelet recreates it from the file, and to stop a
static Pod you move the file out of the directory. And static Pod names have the
node name appended — `kube-apiserver-cp01` — which is the giveaway that a Pod is
static.

**The rule: a static Pod is the only workload that survives a dead control
plane, because it is the only one that never needed it.**

---

## 2. Objects & Fields That Matter

| Object | Key fields | Default | Gotcha |
|---|---|---|---|
| Pod | `spec.nodeName`, `spec.restartPolicy`, `spec.schedulerName` | `Always`, `default-scheduler` | Setting `nodeName` by hand skips the scheduler |
| ReplicaSet | `spec.replicas`, `spec.selector`, `spec.template` | 1 | Selector must match template labels or it is rejected |
| Deployment | `spec.strategy`, `spec.revisionHistoryLimit` | RollingUpdate 25/25, 10 | Owns ReplicaSets, never Pods |
| DaemonSet | `spec.template.spec.nodeSelector` | — | **No `replicas` field exists** |
| StatefulSet | `spec.serviceName`, `volumeClaimTemplates`, `podManagementPolicy` | `OrderedReady` | Headless Service required; PVCs outlive it |
| Job | `completions`, `parallelism`, `backoffLimit` | 1, 1, **6** | `restartPolicy: Always` is invalid |
| CronJob | `schedule`, `concurrencyPolicy`, `suspend` | `Allow`, `false` | UTC unless `spec.timeZone` |
| Pod placement | `spec.nodeSelector`, `spec.affinity`, `spec.tolerations` | — | Tolerations permit; they do not attract |
| Container | `resources.requests`, `resources.limits` | unset → BestEffort | Requests schedule, limits constrain |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 2 (CKA, from 10 Sep) with the
imperative `--dry-run=client -o yaml` paths and what cannot be done imperatively.*

---

## 4. Hands-On Lab

The 3-node kubeadm cluster exists as of yesterday. **Target: 25 minutes.**
Snapshot the VMs first.

```bash
# 1. The control-plane taint that shapes everything                     (2 min)
kubectl describe node <cp-node> | grep -i -A2 taint

# 2. Requests, not usage, drive scheduling                              (8 min)
kubectl run hog --image=nginx --overrides='{"spec":{"containers":[{"name":"hog",
  "image":"nginx","resources":{"requests":{"cpu":"3"}}}]}}'
kubectl get pod hog                 # Pending: no node has 3 free cores of request
kubectl describe pod hog | tail -5  # read the FailedScheduling text

# 3. A label that matches nothing, then make it match                  (10 min)
kubectl run picky --image=nginx \
  --overrides='{"spec":{"nodeSelector":{"disktype":"ssd"}}}'
kubectl get pod picky               # Pending
kubectl label node <worker1> disktype=ssd
kubectl get pod picky -w            # schedules in seconds, nothing restarted

# 4. A DaemonSet counts nodes; static Pods are files                    (5 min)
kubectl get daemonset -n kube-system                  # kube-proxy + your CNI
sudo ls /etc/kubernetes/manifests/                    # on the control plane
kubectl get pods -n kube-system | grep kube-apiserver # note the node-name suffix

kubectl delete pod hog picky
```

---

## 5. Verification

```bash
kubectl get pods -o wide                                     # NODE = where it landed
kubectl get pod <name> -o jsonpath='{.spec.nodeName}{"\n"}'
kubectl get pod <name> -o jsonpath='{.status.qosClass}{"\n"}'
kubectl describe pod <name> | grep -A10 Events
kubectl describe node <node> | grep -A8 "Allocated resources"
kubectl get events --sort-by=.lastTimestamp
```

Never accept "it looks fine". A node name in the NODE column is the proof.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| Pending, `Insufficient cpu/memory` | Requests exceed allocatable | `kubectl describe node \| grep -A8 Allocated` | Lower requests or add a node |
| Pending, `untolerated taint` | Single-node cluster or dedicated pool | `kubectl describe node \| grep -i taint` | Add a toleration, or remove the taint |
| Pending, `didn't match node affinity/selector` | Label typo, or node never labelled | `kubectl get nodes --show-labels` | `kubectl label node ...` |
| Pending, **no events at all** | Scheduler not running | `kubectl get pods -n kube-system \| grep sched` | Restart the scheduler static Pod |
| Pod deleted 5 min after a node went silent | `NoExecute` `unreachable` + default 300s toleration | `kubectl get events` | Expected behaviour, not a bug |
| Container `OOMKilled`, restarting | Memory **limit** too low | `kubectl describe pod \| grep -i -A3 "Last State"` | Raise the memory limit |
| App slow, never restarts | CPU **limit** throttling | `kubectl top pod` against the limit | Raise the CPU limit |
| DaemonSet has fewer Pods than nodes | Untolerated taint, or nodeSelector excludes a node | `kubectl get ds -n <ns>` — DESIRED vs CURRENT | Add a toleration or fix the selector |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| Control plane nodes | Invisible — never in `kubectl get nodes`, no control-plane taint exists | Listed, and carries `node-role.kubernetes.io/control-plane:NoSchedule` |
| Control plane workloads | Nothing to see; no static Pods you can reach | `/etc/kubernetes/manifests/` holds apiserver, etcd, scheduler, controller-manager |
| Pending because the cluster is full | Karpenter or Cluster Autoscaler adds a node; it schedules a minute later | **Pending forever.** Nothing adds nodes. The most dangerous EKS habit |
| DaemonSets | `aws-node` (VPC CNI) and `kube-proxy` arrive pre-installed; you never wrote them | You install the CNI DaemonSet yourself or no Pod ever gets an IP |
| Node labels | AWS injects `topology.kubernetes.io/zone`, `node.kubernetes.io/instance-type`, `eks.amazonaws.com/*` | Only built-in `kubernetes.io/*`. **Anything you nodeSelector on, you label by hand** |
| Taints on a node pool | Declared in the managed node group / Terraform, applied at node creation | `kubectl taint node ...`, by you, after the node exists |

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 2.*

---

## 9. Objectives Covered

KCNA area **1.3 Scheduling** — tick only when explainable without looking.

- [ ] Filtering (predicates) → scoring (priorities); what the scheduler writes
- [ ] `nodeSelector` vs node affinity vs pod affinity/anti-affinity
- [ ] Taints and tolerations, and why they are not affinity
- [ ] Requests vs limits and their effect on scheduling
- [ ] QoS classes: Guaranteed / Burstable / BestEffort
- [ ] Why a Pod stays `Pending`
- [ ] DaemonSet, StatefulSet, Job, CronJob — when to use each
- [ ] Pod, ReplicaSet, Deployment and the ownership chain
- [ ] Static Pods vs DaemonSets (the bootstrap loop)

---

## KCNA — Traps & Distractors

*Temporary. Delete after 9 Sep 2026; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "The scheduler starts the Pod on the node" | It writes `spec.nodeName`. The **kubelet** starts it |
| "A DaemonSet has `replicas: <node count>`" | There is no `replicas` field. Node count *is* the count |
| "DaemonSet Pods bypass the scheduler" | Outdated. Since v1.12 they use nodeAffinity + the default scheduler |
| "A toleration makes the Pod prefer that node" | It only removes the block. Attraction needs affinity |
| "The scheduler considers limits" | Requests only. Limits are the kubelet's business |
| "Exceeding the CPU limit kills the container" | CPU is throttled. **Memory** kills |
| "requests == limits on memory alone is Guaranteed" | Both CPU **and** memory, on **every** container |
| "Node affinity is re-checked when node labels change" | `IgnoredDuringExecution` — scheduling time only |
| "kube-apiserver runs as a DaemonSet" | Bootstrap loop. It is a **static Pod**, from a file on disk |

**X ≠ Y**

- **Filtering ≠ scoring** — feasible vs best
- **Requests ≠ limits** — scheduler vs kubelet, placement vs runtime
- **Taint ≠ node affinity** — on the node repelling vs on the Pod attracting
- **Toleration ≠ attraction** — permission to be there, not a reason to go
- **Deployment ≠ ReplicaSet** — revisions vs replica count
- **DaemonSet ≠ Deployment with replicas = node count** — a Deployment could put every copy on one node
- **StatefulSet ≠ Deployment with volumes** — identity and ordering, not just storage
- **Job ≠ CronJob** — runs once vs creates Jobs on a schedule
- **Static Pod ≠ DaemonSet Pod** — file on disk vs API object
- **Pending (unscheduled) ≠ Pending (image pulling)** — source `default-scheduler` vs `kubelet`
- **`unschedulable` taint ≠ node down** — that one is `kubectl cordon`

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. The scheduler picks node X. What exactly does it write, to which component
   does it send it, and who then starts the container?
2. Name the two scheduling phases, their old names, and what each produces.
3. kube-scheduler is down for an hour. What breaks, and what does not?
4. What is a DaemonSet, and which field does it deliberately not have?
5. Give three real workloads that belong in a DaemonSet.
6. Why do DaemonSet Pods survive a node going `NotReady`, when normal Pods are
   deleted after five minutes?
7. Why can kube-apiserver not be delivered as a DaemonSet? Walk the loop.
8. Where does the kubelet look for static Pod manifests on kubeadm, and what
   happens if you `kubectl delete` the resulting Pod?
9. Draw the ownership chain from CronJob to a running container. How many
   objects, and which controller creates each?
10. During a rolling update, how many ReplicaSets exist, and why are the old
    ones kept afterwards?
11. Three guarantees a StatefulSet gives that a Deployment does not.
12. Which two `restartPolicy` values are legal in a Job, and why is the third
    rejected?
13. State the direction of a taint and of a node affinity rule. Which one lives
    on the node?
14. You taint a node `gpu=true:NoSchedule` and add the matching toleration to a
    Pod. Will the Pod land there? What else is needed to make it land there?
15. Which of requests and limits does the scheduler read? Which does the kubelet
    enforce, and what happens when each is exceeded?
16. Define the three QoS classes by their exact condition, and say which is
    evicted first under memory pressure.
17. A Pod is `Pending` with no events at all. What does that tell you, and which
    single component do you check?
18. `spec.nodeName` is set but the Pod is still `Pending`. Which half of §1.16
    are you in, and whose events do you read?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — The zone that filled up

Six nodes, two per zone across three zones, 4 allocatable cores each. A
Deployment has `replicas: 6`, `requests.cpu: 1`, and a **required**
podAntiAffinity on its own app label with
`topologyKey: topology.kubernetes.io/zone`.

a. How many Pods can ever schedule? Explain via the topologyKey.
b. The rest are `Pending`. Which phase produced that, and what does the event
   text say?
c. You change `topologyKey` to `kubernetes.io/hostname`. Now how many schedule?
d. You instead switch the rule to `preferred` with weight 100. How many
   schedule, and where do they go?
e. Once they are running, someone relabels a node's zone. Does the rule still
   hold? Name the part of the field name that answers this.

### Drill 2 — Pending on a fresh cluster

`kubeadm init` is done, one control-plane node, no workers yet. You run
`kubectl create deployment web --image=nginx`. The Pod is `Pending`.

a. Give the exact reason and the taint key involved.
b. Two different ways to make it schedule. Which is correct for a real cluster,
   which is a lab shortcut?
c. `kube-proxy` and the CNI Pods **are** running on that same node. Why are they
   not blocked by the same taint?
d. You join a worker and the Pod schedules there. Was the scheduler restarted,
   re-queried, or something else? Describe the mechanism.
e. Before the CNI was installed the node was `NotReady`. Would the Pod have
   scheduled onto a *worker* in that state? Which phase rejects it?

### Drill 3 — The 3 a.m. eviction

At 03:00:00 a worker's kubelet stops reporting. On it: one nginx Deployment Pod
with no tolerations specified, and one node-exporter DaemonSet Pod.

a. Around what time is the node's condition marked, and does `Ready` become
   `False` or `Unknown`? Why that one?
b. Which taint is applied, with which effect(s)?
c. At what time is the nginx Pod deleted? Which admission controller put that
   number there, and what is the number?
d. Which controller performs the deletion, and which one creates the
   replacement? Name both.
e. The node-exporter Pod is never evicted. Which specific field of its
   toleration explains that, and who set it?
f. The replacement nginx Pod is `Pending` for 30 seconds, then runs. What was
   happening in those 30 seconds?

### Drill 4 — QoS under pressure

A node has 8Gi allocatable memory. Three Pods:

- **A** — one container: `requests.memory 2Gi`, `limits.memory 2Gi`,
  `requests.cpu 500m`, `limits.cpu 500m`
- **B** — two containers: the first sets `requests.memory 1Gi` and no limit, the
  second sets nothing
- **C** — no `resources` block anywhere

a. Give each Pod's QoS class, justified against the exact condition.
b. The node hits memory pressure. State the eviction order and why.
c. Pod A's container tries to allocate 3Gi. What happens, and what does
   `kubectl describe pod` show under Last State?
d. Pod A's container tries to use a full core. What happens instead, and why is
   the outcome different from (c)?
e. A `LimitRange` with memory defaults is added to the namespace and Pod C is
   recreated. Does its QoS class change? Does the *existing* Pod C change?
f. How much memory can the scheduler still commit on this node, and which of the
   three Pods' numbers did it use to work that out?
