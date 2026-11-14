---
domain: D2 — Application Deployment
weight: 20%
exams: [CKAD]
theory: notes_03, notes_10
k8s_version: v1.37
status: skeleton — 0 / 4 bullets (2.2, 2.3, 2.4 worked in CKA, CKAD runs owed)
revision: 2026-11-13 (r1 — skeleton; 2.2–2.4 point at their CKA homes; draft paths unmeasured)
---

# D2 — Application Deployment (20%)

> Operational layer. Theory in notes_10 §1.5–1.11 and notes_03 §1.4.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> **Three of the four bullets already have a home in `cka/`** and are not rewritten
> here (one topic, one home). This file holds 2.1, which is new, and for the other
> three only the CKAD delta and the runs still owed.

**Why this domain goes first.** It is the cheapest 20% on the paper: 2.2 has a
measured runbook and a verified drill waiting, 2.3/2.4 need one cold run, and 2.1 is
two `create deployment` and a selector.

| Bullet | Home | State on 13 Nov | Owed |
|---|---|---|---|
| 2.1 Blue/green, canary | **here** | new | guided pass → blind |
| 2.2 Rolling updates | `cka/cka-D2-1-workloads.md` 2.1 | guided pass done, card written | **R1 blind** (target 4:00) + R16 variation below |
| 2.3 Helm | `cka/cka-D1-3-access.md` 1.6 | H1 6:32, 11/11, micro-drills 5/5 | **H1 cold ×2 ≤ 6:00** |
| 2.4 Kustomize | `cka/cka-D1-3-access.md` 1.6 | inside H1 | same H1 runs |

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.1 blue/green + canary · 2.2 → cka 2.1 card · 2.3 / 2.4 → cka 1.6 card

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

## 2.3 Helm — home: `cka/cka-D1-3-access.md` 1.6

**Target: 6:00 (H1)** · card: that file, 1.6

CKAD wording leans on *existing* releases and charts: find a release in an unknown
namespace (`helm list -A`), upgrade it to a named chart version, roll back, uninstall;
install from a repo with one `--set`. All inside H1 and micro-drills M1–M5.

Owed: **H1 cold ×2 ≤ 6:00** — closes CKAD 2.3/2.4 and CKA 1.6 with the same run.

## 2.4 Kustomize — home: `cka/cka-D1-3-access.md` 1.6

Base + overlay, `namePrefix`, `images`, `replicas`, `k apply -k DIR`, `k kustomize DIR`
to render. Covered by H1 (the Kustomize half) and M4/M5.

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Blue/green: second Deployment + switch the Service selector | 2.1 | 5:00 | | | | | |
| 2 | Canary: second Deployment, same Service, 80/20 on a fixed total | 2.1 | 6:00 | | | | | |
| 3 | R1 rollout + strategy + rollback (`cka-D2.md §7` row 1) | 2.2 | 4:00 | | | | | |
| 4 | R16: rename container + new image, roll out, `undo`, prove | 2.2 | 4:00 | | | | | |
| 5 | H1 Helm + Kustomize, cold (`cka-D1.md §7` row 8) | 2.3, 2.4 | 6:00 | | | | | |

## §8. Objectives scoreboard — D2

| Bullet | Performed from memory, timed, verified |
|---|---|
| 2.1 Blue/green, canary | ☐ |
| 2.2 Rolling updates | ☐ |
| 2.3 Helm | ☐ |
| 2.4 Kustomize | ☐ |
| **Total** | **0 / 4** |

## §9. Exam mode

> 2.2 → `cka-D2-1-workloads.md §9` R1 · 2.3/2.4 → `cka-D1-3-access.md §9` H1.
> 2.1 tasks with 🧪 setup and 🔍 grader are written the day it is worked.
