---
domain: D1 — Application Design and Build
weight: 20%
exams: [CKAD]
theory: notes_03, notes_04, notes_06
k8s_version: v1.37
status: skeleton — 0 / 4 bullets
revision: 2026-11-13 (r2 — split into index + 3 content files, the CKA D1/D2 pattern; text moved unchanged) · r1 2026-11-13 skeleton
---

# D1 — Application Design and Build (20%)

> Operational layer. Theory lives in notes_03 (workloads), notes_04 (images) and
> notes_06 (volumes) — **not repeated here**. ✍️ = worked in the lab, then rewritten
> from memory. A bullet closes when done twice in a row under target **without looking**.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
> Per-host setup at 0:00 of every session: `plan.md §13`.
>

**What unites these four.** Everything that is decided *before* the application is
deployed: the image it runs (1.1), the controller that owns it (1.2), how many
containers share its Pod (1.3) and where its data lives (1.4).

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D1-1-images.md`** | 1.1 | Define, build and modify container images | Tue 8 Dec |
| **`ckad-D1-2-workloads.md`** | 1.2 | Choose and use the right workload resource | Tue 1 Dec |
| **`ckad-D1-3-pod-design.md`** | 1.3, 1.4 | Multi-container Pod design patterns · Utilize persistent and ephemeral volumes | Wed 9 Dec |

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: `The shape` → `The whiteboard` → `Command card` → `Traps`
> → `EKS`, and one `Exam mode` per file. Until then they hold the r1 ✍️ skeleton.

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Build an image from a given Dockerfile, run it, save it to a tar | 1.1 | 5:00 | | | | | |
| 2 | CronJob `*/30` with completions, parallelism, backoff, deadline; run it once by hand | 1.2 | 5:00 | | | | | |
| 3 | Job from an existing CronJob + read its logs | 1.2 | 1:00 | | | | | |
| 4 | DaemonSet from a Deployment manifest | 1.2 | 3:00 | | | | | |
| 5 | Pod with an init container that writes into a shared `emptyDir` | 1.3 | 6:00 | | | | | |
| 6 | Add a log-tailing sidecar to an existing Deployment | 1.3 | 5:00 | | | | | |
| 7 | PV + PVC + Pod mounting it, data written and read back | 1.4 | 7:00 | | | | | |

## §8. Objectives scoreboard — D1

| Bullet | Performed from memory, timed, verified |
|---|---|
| 1.1 Container images | ☐ |
| 1.2 Workload resources | ☐ |
| 1.3 Multi-container patterns | ☐ |
| 1.4 Volumes | ☐ |
| **Total** | **0 / 4** |
