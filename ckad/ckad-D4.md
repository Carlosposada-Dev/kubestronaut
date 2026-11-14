---
domain: D4 — Application Environment, Configuration and Security
weight: 25%
exams: [CKAD]
theory: notes_07, notes_02, notes_03
k8s_version: v1.37
status: skeleton — 2 / 7 bullets (4.1, 4.2 closed in CKA D1-3)
revision: 2026-11-13 (r2 — split into index + 2 content files, the CKA D1/D2 pattern; text moved unchanged) · r1 2026-11-13 skeleton
---

# D4 — Application Environment, Configuration and Security (25%)

> Operational layer. Theory in notes_07 §1.2–1.13, notes_03 §1.11 and notes_02 §1.12.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> **The largest domain, and 6 of the 16 reported tasks.** Two bullets are already
> closed from CKA; the other five are short and almost fully imperative.

**What unites these seven.** Everything the Pod is *given* from outside its image:
its identity and what that identity may do (4.6, 4.2), its limits (4.3), its
configuration (4.4, 4.5), its kernel permissions (4.7) and the extra kinds the
cluster offers (4.1).

| Bullet | Home | State on 13 Nov |
|---|---|---|
| 4.1 CRDs, operators | `cka/cka-D1-3-access.md` 1.8 | ✅ recognise-only, Task D 0:41 |
| 4.2 Authn, authz, admission | `cka/cka-D1-3-access.md` 1.1 (RBAC) + delta in `ckad-D4-2-identity.md` | ✅ RBAC cold 3:46 · 3:24 |
| 4.3 – 4.7 | `ckad-D4-1-config.md` · `ckad-D4-2-identity.md` | new |

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, the drill table and the scoreboard. It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D4-1-config.md`** | 4.3, 4.4, 4.5 | Requests, limits and quotas · ConfigMaps · Create and consume Secrets | Sun 15 Nov, first block |
| **`ckad-D4-2-identity.md`** | 4.1, 4.2, 4.6, 4.7 | CRDs and operators · Authentication, authorization and admission control · ServiceAccounts · Application security | Sun 15 Nov, second block |

> The content files follow **Template C** (`claude/note-templates.md`) from the day
> each bullet is worked: `The shape` → `The whiteboard` → `Command card` → `Traps`
> → `EKS`, and one `Exam mode` per file. Until then they hold the r1 ✍️ skeleton.

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | R4: limits = half the quota, then quota so only one Pod fits | 4.3 | 6:00 | | | | | |
| 2 | ConfigMap from literal + file, consumed as env and as a volume | 4.4 | 4:00 | | | | | |
| 3 | R13: Secret → Deployment env vars, value proven from inside | 4.5 | 3:00 | | | | | |
| 4 | R10: Role + RoleBinding given, make the Pod able to `get pods` | 4.6 | 4:00 | | | | | |
| 5 | R11: SA + Role (`pods`, `pods/log`) + RoleBinding + Deployment | 4.2, 4.6 | 5:00 | | | | | |
| 6 | R7: `runAsUser` + capabilities on an existing Deployment | 4.7 | 4:00 | | | | | |
| 7 | RBAC cold run (`cka-D1.md §7`) — spaced review | 4.2 | 4:00 | | | | | |

## §8. Objectives scoreboard — D4

| Bullet | Performed from memory, timed, verified |
|---|---|
| 4.1 CRDs, operators | ✅ 8 Nov (CKA 1.8, recognise-only) |
| 4.2 Authn, authz, admission | ✅ 8 Nov (CKA 1.1) — R11 variation owed |
| 4.3 Requests, limits, quotas | ☐ |
| 4.4 ConfigMaps | ☐ |
| 4.5 Secrets | ☐ |
| 4.6 ServiceAccounts | ☐ |
| 4.7 SecurityContext, capabilities | ☐ |
| **Total** | **2 / 7** |
