---
domain: D2 — Application Deployment
group: 2 — Helm and Kustomize
bullets: [2.3, 2.4]
exams: [CKAD]
index: ckad-D2.md
theory: notes_10
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D2.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D2 · Group 2 — Helm and Kustomize (bullets 2.3, 2.4)

> Index, drill table and scoreboard: **`ckad-D2.md`**. Session: **Tue 1 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> Both numerals live in `cka/cka-D1-3-access.md` 1.6. This file holds only the CKAD delta and the runs owed.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.3 Helm · 2.4 Kustomize

---

## 2.3 Helm — home: `cka/cka-D1-3-access.md` 1.6

**Target: 6:00 (H1)** · card: that file, 1.6

CKAD wording leans on *existing* releases and charts: find a release in an unknown
namespace (`helm list -A`), upgrade it to a named chart version, roll back, uninstall;
install from a repo with one `--set`. All inside H1 and micro-drills M1–M5.

Owed: **H1 cold ×2 ≤ 6:00** — closes CKAD 2.3/2.4 and CKA 1.6 with the same run.

---

## 2.4 Kustomize — home: `cka/cka-D1-3-access.md` 1.6

Base + overlay, `namePrefix`, `images`, `replicas`, `k apply -k DIR`, `k kustomize DIR`
to render. Covered by H1 (the Kustomize half) and M4/M5.

---

## §9. Exam mode

> 2.2 → `cka-D2-1-workloads.md §9` R1 · 2.3/2.4 → `cka-D1-3-access.md §9` H1.
> 2.1 tasks with 🧪 setup and 🔍 grader are written the day it is worked.
