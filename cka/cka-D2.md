---
domain: D2 — Workloads and Scheduling
weight: 15%
exams: [CKA, CKAD]
theory: notes_03, notes_02
k8s_version: v1.37
status: draft | drilled | timed-clean
window: W3 — Mon 28 Sep, Tue 29 Sep
---

# D2 — Workloads and Scheduling (15%)

> Operational layer. Theory lives in notes_03 (recalled 14/18) and notes_02 —
> **not repeated here**. ⚙️ = pre-written (not guessable). ✍️ = you write it in
> the lab, then rewrite from memory and diff.
> A bullet closes when done twice in a row under target **without looking**.
>
> §0 exam-environment drill: see `cka-D1.md` §0. Type it at 0:00 every session.

**Why this domain is cheap points.** 15% of the paper and almost 100% imperative.
If a D2 task takes you more than 5 minutes you are writing YAML you did not need
to write. That is the whole lesson of this file.

---

## 2.1 Deployments, rolling updates and rollbacks ✍️

**Theory →** notes_03 §1.4–1.6 · **Docs →** search `deployment` →
"Updating a Deployment" · **Target: 4 min**

Write during the Mon 28 Sep lab. Your runbook must contain:

- creating a Deployment imperatively with replicas and image in one line
- changing the image **without** editing YAML, and how to record the change
- watching a rollout to completion (the command that *blocks* until it is done —
  it is the verification command, do not use `get pods` in a loop)
- reading the history, inspecting one specific revision, rolling back to the
  previous one and to a **named** revision
- pausing and resuming a rollout
- the two `strategy` fields and what `maxUnavailable: 0` costs you

**What cannot be done imperatively** — fill this in yourself; it is the part the
exam tests: strategy, `maxSurge`/`maxUnavailable`, probes, resources, affinity,
tolerations, volumes. All of these mean `$do > f.yaml` then edit.

**Trap already in your log:** revision history is kept by the ReplicaSets. Delete
the old ReplicaSet and the rollback target is gone.

```
(your runbook here)
```

---

## 2.2 ConfigMaps and Secrets ✍️

**Theory →** notes_03 §2.x, notes_07 · **Docs →** search `configmap` /
`secret` · **Target: 4 min**

Must contain: the three imperative sources (`--from-literal`, `--from-file`,
`--from-env-file`), the four Secret types you can create imperatively
(`generic`, `docker-registry`, `tls`), consuming as **env var** vs **envFrom**
vs **mounted volume**, and how to read a Secret's value back in clear text.

**The distinction the exam actually tests:** a mounted ConfigMap updates in the
Pod (eventually, via the kubelet sync); an `env:` value does **not** — it is
fixed at container start. Know which one the task needs.

**Trap:** Secret data is base64, **not encryption**. `kubectl get secret x -o
jsonpath='{.data.key}' | base64 -d`.

```
(your runbook here)
```

---

## 2.3 Configure workload autoscaling ✍️

**Theory →** notes_03 §3.x · **Docs →** search `horizontal pod autoscale` ·
**Target: 5 min**

Must contain: the imperative `autoscale` one-liner with min/max/CPU target, how
to read the current/target column, and **the prerequisite** — an HPA on CPU
does nothing unless (a) metrics-server is running and (b) the Pod template
declares `resources.requests.cpu`. Without requests there is no percentage to
compute and the HPA sits at `<unknown>`.

That prerequisite is the task. Verify with `kubectl top pods` **before**
touching the HPA.

⚠️ **EKS:** metrics-server is not installed by default there either — but in your
day job someone else installed it. Here you install it.

```
(your runbook here)
```

---

## 2.4 Primitives for robust, self-healing deployments ✍️ — includes PDB

**Theory →** notes_03 §1.x + **the PDB block queued since Block 1 goes here, not
in the note** · **Docs →** search `disruption` / `liveness readiness` ·
**Target: 5 min**

Must contain:

- the three probes: liveness (restart), readiness (remove from EndpointSlice),
  startup (suspend the other two while a slow app boots) — and the fields
  `initialDelaySeconds`, `periodSeconds`, `failureThreshold`
- **PodDisruptionBudget**: `minAvailable` vs `maxUnavailable`, the imperative
  creation line, and the proof — `kubectl drain` **blocks** when the budget
  would be violated
- restart policies and what a DaemonSet/StatefulSet guarantees that a Deployment
  does not

**Two traps from your amendment queue:**
- A Pod with **no readiness probe** is Ready the moment the container starts →
  it enters the EndpointSlice immediately and serves 1/N of the 503s.
- A not-ready Pod **stays** in the EndpointSlice with `ready: false`; it is not
  removed from the object.
- PDBs guard **voluntary** disruptions only (drain, eviction API). A node that
  dies ignores them completely.

```
(your runbook here)
```

---

## 2.5 Pod admission and scheduling ✍️

**Theory →** notes_03 §4.x · **Docs →** search `taints and tolerations` /
`assign pod node` / `resource quotas` · **Target: 5 min**

Must contain:

- `nodeSelector` vs `nodeName` vs `nodeAffinity`
  (`requiredDuringScheduling...` vs `preferredDuringScheduling...`)
- taints: the imperative add and **the remove syntax** (trailing `-`), the three
  effects (`NoSchedule`, `PreferNoSchedule`, `NoExecute`) and which one evicts
  Pods already running
- tolerations, including `operator: Exists` with no value
- `requests` vs `limits`, and the three QoS classes with the rule that decides
  each
- ResourceQuota (namespace **aggregate**) vs LimitRange (**per container**
  default/max) — the amendment queued from note 07 lands here

**The diagnostic reflex:** a Pod stuck `Pending` → `kubectl describe pod` and
read the scheduler event verbatim. It names the reason (insufficient cpu, taint,
no matching node). Do not guess.

**Trap:** control-plane nodes carry a `NoSchedule` taint. A task that says "run
it on the control plane" means tolerate that taint, not remove it.

```
(your runbook here)
```

---

## §7. Drill table

| # | Task | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|
| 1 | Deployment → image update → watch rollout → rollback to rev N | 4:00 | | | | | |
| 2 | ConfigMap 3 ways + consume as env and as mount | 4:00 | | | | | |
| 3 | Secret generic + docker-registry, read value back | 3:00 | | | | | |
| 4 | HPA on an existing Deployment, incl. adding requests | 5:00 | | | | | |
| 5 | Add all three probes to a running Deployment | 5:00 | | | | | |
| 6 | PDB + prove it by blocking a drain | 4:00 | | | | | |
| 7 | Taint a node, schedule a Pod onto it with a toleration | 4:00 | | | | | |
| 8 | nodeAffinity required + preferred in one Pod | 5:00 | | | | | |
| 9 | ResourceQuota + LimitRange in a namespace, prove both | 5:00 | | | | | |

## §8. Objectives scoreboard — D2

| Bullet | Performed from memory, timed, verified |
|---|---|
| 2.1 Deployments, rollouts, rollbacks | ☐ |
| 2.2 ConfigMaps & Secrets | ☐ |
| 2.3 Workload autoscaling | ☐ |
| 2.4 Self-healing primitives (+ PDB) | ☐ |
| 2.5 Admission & scheduling | ☐ |
| **Total** | **0 / 5** |
