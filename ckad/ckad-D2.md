---
domain: D2 — Application Deployment
weight: 20%
exams: [CKAD]
theory: notes_03, notes_10
k8s_version: v1.37
status: skeleton — 0 / 4 bullets (2.2, 2.3, 2.4 worked in CKA, CKAD runs owed)
revision: 2026-11-13 (r2 — split into index + 2 content files, the CKA D1/D2 pattern; text moved unchanged) · r1 2026-11-13 skeleton
---

# D2 — Application Deployment (20%)

> Operational layer. Theory in notes_10 §1.5–1.11 and notes_03 §1.4.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> **Three of the four bullets already have a home in `cka/`** and are not rewritten
> here (one topic, one home). The content files hold 2.1, which is new, and for the
> other three only the CKAD delta and the runs still owed.

**Why this domain goes first.** It is the cheapest 20% on the paper: 2.2 has a
measured runbook and a verified drill waiting, 2.3/2.4 need one cold run, and 2.1 is
two `create deployment` and a selector.

| Bullet | Home | State on 13 Nov | Owed |
|---|---|---|---|
| 2.1 Blue/green, canary | `ckad-D2-1-strategies.md` | new | guided pass → blind |
| 2.2 Rolling updates | `cka/cka-D2-1-workloads.md` 2.1 | guided pass done, card written | **R1 blind** (target 4:00) + R16 variation in `ckad-D2-1-strategies.md` |
| 2.3 Helm | `cka/cka-D1-3-access.md` 1.6 | H1 6:32, 11/11, micro-drills 5/5 | **H1 cold ×2 ≤ 6:00** |
| 2.4 Kustomize | `cka/cka-D1-3-access.md` 1.6 | inside H1 | same H1 runs |

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D2-1-strategies.md`** | 2.1, 2.2 | Blue/green and canary with Kubernetes primitives · Deployments and rolling updates | Sat 14 Nov |
| **`ckad-D2-2-packaging.md`** | 2.3, 2.4 | Helm · Kustomize | Sat 14 Nov |

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: `The shape` → `The whiteboard` → `Command card` → `Traps`
> → `EKS`, and one `Exam mode` per file. Until then they hold the r1 ✍️ skeleton.

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
