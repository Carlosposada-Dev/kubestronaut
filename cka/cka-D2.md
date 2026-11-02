---
domain: D2 — Workloads and Scheduling
weight: 15%
exams: [CKA, CKAD]
theory: notes_03, notes_02, notes_07
k8s_version: v1.37
status: skeleton — 0 / 5 bullets
revision: 2026-11-02 (r2 — split into index + 2 content files, the D1 pattern; bullet text moved unchanged) · r1 2026-09-12 skeleton
---

# D2 — Workloads and Scheduling (15%)

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in two content files, one per group of bullets.
> Dates and windows: `plan.md` owns them.

> Operational layer. Theory lives in notes_03 (recalled 14/18) and notes_02 —
> **not repeated here**. ⚙️ = pre-written (not guessable). ✍️ = you write it in
> the lab, then rewrite from memory and diff.
> A bullet closes when done twice in a row under target **without looking**.
>
> §0 exam-environment drill: see `cka-D1.md` §0. Type it at 0:00 every session.

**Why this domain is cheap points.** 15% of the paper and almost 100% imperative.
If a D2 task takes you more than 5 minutes you are writing YAML you did not need
to write. That is the whole lesson of this domain.

## Content map — where every topic lives

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: per numeral, `The shape` → `The whiteboard` →
> `Command card` → `Traps` (error · cause) → `EKS`, and one `Exam mode` per file.
> Until then they hold the r1 ✍️ text, moved here unchanged.

| File | Bullets | Covers |
|---|---|---|
| **`cka-D2-1-workloads.md`** | 2.1, 2.2, 2.4 | Deployments, rollouts and rollbacks · ConfigMaps and Secrets · probes, restart policies, PodDisruptionBudget |
| **`cka-D2-2-scheduling.md`** | 2.3, 2.5 | requests/limits and QoS · nodeSelector / nodeAffinity · taints and tolerations · ResourceQuota / LimitRange · HPA + metrics-server |

**Why two groups.** Group 1 is one application's life — how it rolls, what it is
configured with, how it stays healthy. Group 2 is where it runs and how big it is;
it is grouped by `resources.requests`, which both the scheduler (2.5) and the HPA
(2.3) read.

**One topic, one home.** A topic lives where it is first *executed by hand*, and
every other bullet links to it:

| Topic | Home | Also used by |
|---|---|---|
| **`$do > f.yaml` then edit** (fields with no imperative flag) | `-1-workloads` 2.1 | 2.4 probes · 2.5 affinity, tolerations |
| **`resources.requests` / `limits`** | `-2-scheduling` 2.5 | 2.3 HPA (its prerequisite) |
| **PodDisruptionBudget** | `-1-workloads` 2.4 | `cka-D1-2-lifecycle.md` 1.4 / 1.4c — the drain that a PDB blocks |
| **Readiness probe ↔ EndpointSlice** | `-1-workloads` 2.4 | D3 Services |
| **metrics-server / `kubectl top`** | `-2-scheduling` 2.3 | D5 (`cka-D5.md` points here) |
| **Secrets** | `-1-workloads` 2.2 | `cka-D1-3-access.md` 1.1 step 7 (`create pods` ≈ read every Secret) |

---

## §7. Drill table

| # | Task | File | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Deployment → image update → watch rollout → rollback to rev N | -1 | 4:00 | | | | | |
| 2 | ConfigMap 3 ways + consume as env and as mount | -1 | 4:00 | | | | | |
| 3 | Secret generic + docker-registry, read value back | -1 | 3:00 | | | | | |
| 4 | HPA on an existing Deployment, incl. adding requests | -2 | 5:00 | | | | | |
| 5 | Add all three probes to a running Deployment | -1 | 5:00 | | | | | |
| 6 | PDB + prove it by blocking a drain | -1 | 4:00 | | | | | |
| 7 | Taint a node, schedule a Pod onto it with a toleration | -2 | 4:00 | | | | | |
| 8 | nodeAffinity required + preferred in one Pod | -2 | 5:00 | | | | | |
| 9 | ResourceQuota + LimitRange in a namespace, prove both | -2 | 5:00 | | | | | |

## §8. Objectives scoreboard — D2

| Bullet | File | Performed from memory, timed, verified |
|---|---|---|
| 2.1 Deployments, rollouts, rollbacks | -1 | ☐ |
| 2.2 ConfigMaps & Secrets | -1 | ☐ |
| 2.3 Workload autoscaling | -2 | ☐ |
| 2.4 Self-healing primitives (+ PDB) | -1 | ☐ |
| 2.5 Admission & scheduling | -2 | ☐ |
| **Total** | | **0 / 5** |
