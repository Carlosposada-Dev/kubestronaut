---
domain: D3 — Application Observability and Maintenance
weight: 15%
exams: [CKAD]
theory: notes_02, notes_08, notes_09
k8s_version: v1.37
status: skeleton — 0 / 5 bullets
revision: 2026-11-13 (r2 — split into index + 2 content files, the CKA D1/D2 pattern; text moved unchanged) · r1 2026-11-13 skeleton
---

# D3 — Application Observability and Maintenance (15%)

> Operational layer. Theory in notes_08 (the method, probes, logs, debug), notes_09
> §1.7 (metrics-server) and notes_02 §1.3 (API groups and versions).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>

**What unites these five.** The application is already deployed and something must be
*read* from it: is its manifest still valid (3.1), is it healthy (3.2), what does it
consume (3.3), what does it say (3.4), why is it broken (3.5). Three of the five are
one-liners whose only trap is writing the answer to the file the task names.

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D3-1-health.md`** | 3.1, 3.2 | Understand API deprecations · Implement probes and health checks | Tue 17 Nov |
| **`ckad-D3-2-observe.md`** | 3.3, 3.4, 3.5 | Use built-in CLI tools to monitor applications · Utilize container logs · Debugging in Kubernetes | Tue 17 Nov |

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: `The shape` → `The whiteboard` → `Command card` → `Traps`
> → `EKS`, and one `Exam mode` per file. Until then they hold the r1 ✍️ skeleton.

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Fix a Deployment manifest written for an old API version and apply it | 3.1 | 5:00 | | | | | |
| 2 | `exec` readiness probe on a file created by an init container | 3.2 | 6:00 | | | | | |
| 3 | Liveness `httpGet` + readiness `tcpSocket` on an existing Deployment | 3.2 | 5:00 | | | | | |
| 4 | Highest-CPU Pod of a namespace written to a file | 3.3 | 2:00 | | | | | |
| 5 | Logs of one container of a multi-container Pod written to a file | 3.4 | 2:00 | | | | | |
| 6 | Three broken Pods, one per rung: find and fix | 3.5 | 9:00 | | | | | |

## §8. Objectives scoreboard — D3

| Bullet | Performed from memory, timed, verified |
|---|---|
| 3.1 API deprecations | ☐ |
| 3.2 Probes | ☐ |
| 3.3 CLI monitoring | ☐ |
| 3.4 Logs | ☐ |
| 3.5 Debugging | ☐ |
| **Total** | **0 / 5** |
