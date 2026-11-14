---
domain: D5 — Services and Networking
weight: 20%
exams: [CKAD]
theory: notes_05
k8s_version: v1.37
status: skeleton — 0 / 3 bullets
revision: 2026-11-13 (r2 — split into index + 2 content files, the CKA D1/D2 pattern; text moved unchanged) · r1 2026-11-13 skeleton
---

# D5 — Services and Networking (20%)

> Operational layer. Theory in notes_05 §1.5, §1.7, §1.10, §1.12 (the weakest recalled
> note — 67%; read those four sections before the session).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> These three bullets are **first worked here** and become the home for the matching
> CKA skeletons (`cka-D3.md` 3.2, 3.3, 3.5), which will link back instead of repeating.

**What unites these three — and four of the 16 reported tasks.** Everything is label
matching. A Service finds Pods by labels, an Ingress finds a Service by name and port,
a NetworkPolicy picks Pods by labels. Every "fix it" task in this domain is a
mismatch between two strings; the method is to print both sides next to each other.

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D5-1-services-ingress.md`** | 5.2, 5.3 | Provide and troubleshoot access via Services · Use Ingress rules to expose applications | Sat 5 Dec |
| **`ckad-D5-2-networkpolicy.md`** | 5.1 | Basic understanding of NetworkPolicies | Sat 5 Dec |

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: `The shape` → `The whiteboard` → `Command card` → `Traps`
> → `EKS`, and one `Exam mode` per file. Until then they hold the r1 ✍️ skeleton.

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Expose a Deployment (port ≠ targetPort), prove it from a Pod | 5.2 | 3:00 | | | | | |
| 2 | R15: ClusterIP → NodePort with a named nodePort, prove it from the node | 5.2 | 2:00 | | | | | |
| 3 | R8: Ingress host + path → Service, prove it with `curl -H Host` | 5.3 | 4:00 | | | | | |
| 4 | R9: broken Service + broken Ingress, find and fix both | 5.2, 5.3 | 7:00 | | | | | |
| 5 | R12: make a Pod comply with existing policies by labels only | 5.1 | 5:00 | | | | | |
| 6 | Default-deny + allow one `podSelector` on one port | 5.1 | 6:00 | | | | | |

## §8. Objectives scoreboard — D5

| Bullet | Performed from memory, timed, verified |
|---|---|
| 5.1 NetworkPolicies | ☐ |
| 5.2 Services | ☐ |
| 5.3 Ingress | ☐ |
| **Total** | **0 / 3** |
