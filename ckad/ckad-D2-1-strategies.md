---
domain: D2 — Application Deployment
group: 1 — Roll It Out
bullets: [2.1, 2.2]
exams: [CKAD]
index: ckad-D2.md
theory: notes_10, notes_03
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D2.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D2 · Group 1 — Roll It Out (bullets 2.1, 2.2)

> Index, drill table and scoreboard: **`ckad-D2.md`**. Session: **Mon 30 Nov** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these two: changing what runs without dropping traffic — inside one Deployment (2.2, rolling update) or across two (2.1, blue/green and canary).
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.1 Blue/green and canary with Kubernetes primitives · 2.2 Deployments and rolling updates

---

## 2.1 Blue/green and canary with Kubernetes primitives ✍️

**Runs on: cp1.** · **Theory →** notes_10 §1.10 · **Docs →** search `canary` →
"Managing Workloads" (canary deployments) · **Target: 6:00** · **Reported: R6**

Must contain: reading the existing Deployment's labels and the Service's selector
**before** anything; a second Deployment made from the first (new name, new image,
the labels the task dictates); blue/green = move the Service selector in one step;
canary = both Deployments behind one selector, the split set by replicas; the proof.

**The whole mechanism in one line.** A Service sends traffic to every Ready Pod that
carries **all** the labels in its selector, in equal shares per Pod. So:

| Strategy | Labels | The switch |
|---|---|---|
| Blue/green | Pods differ in one label (`version: blue` / `green`); the Service selects it | Change the Service selector — all traffic moves at once |
| Canary | Both Deployments' Pods carry the label the Service selects (`app: web`) and differ in another | Replica ratio: 8 + 2 = 80 / 20 |

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS get deploy D1 --show-labels ; k -n NS get svc S -o jsonpath='{.spec.selector}'; echo
k -n NS get deploy D1 -o yaml > d2.yaml
vim d2.yaml                # name · image · the differing label in selector.matchLabels AND template.labels · delete status, uid, resourceVersion, creationTimestamp
k apply -f d2.yaml ; k -n NS rollout status deploy D2
# blue/green
k -n NS set selector svc S 'app=web,version=green'      # or: k -n NS edit svc S
# canary — total stays what the task says
k -n NS scale deploy D1 --replicas=8 ; k -n NS scale deploy D2 --replicas=2
k -n NS get endpointslices -l kubernetes.io/service-name=S    # 🔍 the Pod IPs behind the Service
k -n NS get pods -l app=web -L version -o wide                # 🔍 which Pods match the selector
```

**Read the task for two numbers:** the total number of Pods and the percentage. 20%
of 10 = 2 canary + 8 stable. A total that the task caps (a quota, "max 10 Pods") is
how this task is failed with correct YAML.

To measure: `set selector` semantics (does it replace the whole selector?); the
immutable-selector error when a Deployment's `matchLabels` is edited in place; the
endpoints during the switch; a `wget` loop that shows the 80/20.

⚠️ **EKS:** same primitives; in the day job this is done by Argo Rollouts or ALB
weighted target groups — out of the exam.

```
(your runbook here)
```

---

## 2.2 Deployments and rolling updates — home: `cka/cka-D2-1-workloads.md` 2.1

**Target: 4:00** · **Reported: R16** · card: that file, `### Command card — 2.1`

Nothing is rewritten. CKAD delta — the R16 variation, to run after R1:

- "Change the container name and the image": the container name has no imperative
  verb → `k -n NS edit deploy D` (both changes in one edit = one revision). After a
  rename, `set image` needs the **new** container name.
- A Deployment's own `metadata.name` cannot be changed — a new name is a new object.
- Then `rollout status` → `rollout history` → `rollout undo` → prove the image.

Owed: R1 blind (`orders` / `checkout`, grader in that file's §9) · R16 variation with
a new setup and grader.

---

## §9. Exam mode

> 2.2 → `cka-D2-1-workloads.md §9` R1 · 2.3/2.4 → `cka-D1-3-access.md §9` H1.
> 2.1 tasks with 🧪 setup and 🔍 grader are written the day it is worked.
