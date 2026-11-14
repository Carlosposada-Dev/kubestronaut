---
domain: D5 — Services and Networking
group: 2 — Restrict the Traffic
bullets: [5.1]
exams: [CKAD]
index: ckad-D5.md
theory: notes_05
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D5.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D5 · Group 2 — Restrict the Traffic (bullet 5.1)

> Index, drill table and scoreboard: **`ckad-D5.md`**. Session: **Mon 16 Nov, second block** (`plan.md §10`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> One sub-session: reading NetworkPolicies and making a Pod comply by its labels. The only numeral that gets a mini-shape before the guided pass.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 5.1 Basic understanding of NetworkPolicies

---

## 5.1 Basic understanding of NetworkPolicies ✍️

**Runs on: cp1 (Calico enforces).** · **Theory →** notes_05 §1.12 · **Docs →** search
`network policies` → copy the example · **Target: 5:00** · **Reported: R12**

Must contain: reading an existing policy and saying in words who it selects and what
it allows; the reported task — **make a Pod comply with existing policies by changing
its labels**; a default-deny; one allow rule from a `podSelector`; AND vs OR in `from`;
the proof in both directions.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS get netpol ; k -n NS describe netpol              # PodSelector = who it applies to · From/To = who is allowed
k -n NS get pods --show-labels
k -n NS label pod P role=frontend --overwrite             # R12: the Pod moves into the policy, the policy is not touched
k -n NS exec P -- wget -qO- -T2 TARGET:PORT               # 🔍 allowed path answers
k -n NS exec OTHER -- wget -qO- -T2 TARGET:PORT           # 🔍 denied path times out
```

**How to read R12.** Three kinds of string appear: the policy's `spec.podSelector`
(which Pods it governs), its `ingress.from` / `egress.to` selectors (which peers are
allowed), and the Pods' labels. The task gives a Pod with a wrong or missing label;
find the label the policies expect on *both* ends of the conversation and set it.
"Do not modify the NetworkPolicies" is usually in the statement — and editing them
scores zero even if traffic flows.

```yaml
  ingress:
  - from:
    - podSelector: {matchLabels: {role: frontend}}        # one item with both selectors   = AND
      namespaceSelector: {matchLabels: {team: a}}
    - podSelector: {matchLabels: {role: admin}}           # a second item                   = OR
```

No imperative create: authoring = docs example + edit. Egress policies that forget
DNS (UDP/TCP 53) break name resolution, not the connection.

To measure: `describe netpol` layout; the timeout vs refused difference; a Pod
selected by no policy (all allowed); default-deny then one allow.

⚠️ **EKS:** the VPC CNI enforces NetworkPolicy only when enabled; security groups are
a separate layer that Kubernetes does not show.

```
(your runbook here)
```

---

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
