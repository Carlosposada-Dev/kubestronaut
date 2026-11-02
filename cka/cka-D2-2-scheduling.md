---
domain: D2 — Workloads and Scheduling
group: 2 — Placement & Sizing
bullets: [2.3, 2.5]
exams: [CKA, CKAD]
index: cka-D2.md
theory: notes_03, notes_07
status: skeleton (r1 text, ✍️ — nothing drilled)
revision: 2026-11-02 (r1 — split out of `cka-D2.md` r1; text unchanged) — migrated to Template C the day each bullet is worked
---

# D2 · Group 2 — Placement & Sizing (bullets 2.3, 2.5)

> Index, drill table and scoreboard: **`cka-D2.md`**.
> Legend, typing conventions and lab-vs-exam node moves: **`cka-D1-2-lifecycle.md`** (reference implementation).
>
> What unites these two: both start from `resources.requests`. The scheduler places
> a Pod by its requests (2.5), and an HPA on CPU computes its percentage from the
> same requests (2.3). Learn 2.5 first; 2.3 links back to it. Both run on **cp1**.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.3 HPA · 2.5 scheduling, taints, requests/limits, quotas

---

## 2.3 Configure workload autoscaling ✍️

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §3.x · **Docs →** search `horizontal pod autoscale` ·
**Target: 5 min**

Must contain: the imperative `autoscale` one-liner with min/max/CPU target, how
to read the current/target column, and **the prerequisite** — an HPA on CPU
does nothing unless (a) metrics-server is running and (b) the Pod template
declares `resources.requests.cpu`. Without requests there is no percentage to
compute and the HPA sits at `<unknown>`.

That prerequisite is the task. Verify with `kubectl top pods` **before**
touching the HPA.

⚠️ **EKS:** metrics-server is not installed by default there either — but in your
day job someone else installed it. Here you install it.

```
(your runbook here)
```

---

## 2.5 Pod admission and scheduling ✍️

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §4.x · **Docs →** search `taints and tolerations` /
`assign pod node` / `resource quotas` · **Target: 5 min**

Must contain:

- `nodeSelector` vs `nodeName` vs `nodeAffinity`
  (`requiredDuringScheduling...` vs `preferredDuringScheduling...`)
- taints: the imperative add and **the remove syntax** (trailing `-`), the three
  effects (`NoSchedule`, `PreferNoSchedule`, `NoExecute`) and which one evicts
  Pods already running
- tolerations, including `operator: Exists` with no value
- `requests` vs `limits`, and the three QoS classes with the rule that decides
  each
- ResourceQuota (namespace **aggregate**) vs LimitRange (**per container**
  default/max) — the amendment queued from note 07 lands here

**The diagnostic reflex:** a Pod stuck `Pending` → `kubectl describe pod` and
read the scheduler event verbatim. It names the reason (insufficient cpu, taint,
no matching node). Do not guess.

**Trap:** control-plane nodes carry a `NoSchedule` taint. A task that says "run
it on the control plane" means tolerate that taint, not remove it.

```
(your runbook here)
```

---

## §9. Exam mode — Set 2 (placement & sizing)

Not written yet. Written the day this file's bullets are drilled: tasks in CKA
wording, weights, targets, base64 setup and grader (`claude/session-protocol.md` §3).
