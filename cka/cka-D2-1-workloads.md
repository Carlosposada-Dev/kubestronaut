---
domain: D2 — Workloads and Scheduling
group: 1 — Run & Configure the Application
bullets: [2.1, 2.2, 2.4]
exams: [CKA, CKAD]
index: cka-D2.md
theory: notes_03, notes_02, notes_07
status: skeleton (r1 text, ✍️ — nothing drilled)
revision: 2026-11-02 (r1 — split out of `cka-D2.md` r1; text unchanged except two counts fixed and a stale date removed) — migrated to Template C the day each bullet is worked
---

# D2 · Group 1 — Run & Configure the Application (bullets 2.1, 2.2, 2.4)

> Index, drill table and scoreboard: **`cka-D2.md`**.
> Legend, typing conventions and lab-vs-exam node moves: **`cka-D1-2-lifecycle.md`** (reference implementation).
>
> What unites these three: one Deployment, from creation to a safe rollout — how it
> rolls (2.1), what it is configured with (2.2), and how it stays healthy and
> protected while nodes are drained (2.4). All of them run on **cp1** with `kubectl`.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.1 rollouts · 2.2 ConfigMaps & Secrets · 2.4 probes + PDB

---

## 2.1 Deployments, rolling updates and rollbacks ✍️

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §1.4–1.6 · **Docs →** search `deployment` →
"Updating a Deployment" · **Target: 4 min**

Write during the lab session for this bullet. Your runbook must contain:

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

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §2.x, notes_07 · **Docs →** search `configmap` /
`secret` · **Target: 4 min**

Must contain: the three imperative sources (`--from-literal`, `--from-file`,
`--from-env-file`), the three Secret types you can create imperatively
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

## 2.4 Primitives for robust, self-healing deployments ✍️ — includes PDB

> r1 text — migrated to Template C the day it is worked.

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

**Three traps from your amendment queue:**
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

## §9. Exam mode — Set 1 (workloads)

Not written yet. Written the day this file's bullets are drilled: tasks in CKA
wording, weights, targets, base64 setup and grader (`claude/session-protocol.md` §3).
