---
domain: D5 — Services and Networking
weight: 20%
exams: [CKAD]
theory: notes_05
k8s_version: v1.37
status: skeleton — 0 / 3 bullets
revision: 2026-11-13 (r1 — skeleton; draft paths unmeasured, migrated to Template C the day each bullet is worked)
---

# D5 — Services and Networking (20%)

> Operational layer. Theory in notes_05 §1.5, §1.7, §1.10, §1.12 (the weakest recalled
> note — 67%; read those four sections before the session).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> These three bullets are **first worked here** and become the home for the matching
> CKA skeletons (`cka-D3.md` 3.2, 3.3, 3.5), which will link back instead of repeating.
> **Draft path** blocks are the expected exam path, **not yet run on the lab**.

**What unites these three — and four of the 16 reported tasks.** Everything is label
matching. A Service finds Pods by labels, an Ingress finds a Service by name and port,
a NetworkPolicy picks Pods by labels. Every "fix it" task in this domain is a
mismatch between two strings; the method is to print both sides next to each other.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 5.2 Services · 5.3 Ingress · 5.1 NetworkPolicy (worked in that order)

---

## 5.2 Provide and troubleshoot access via Services ✍️

**Runs on: cp1.** · **Theory →** notes_05 §1.5, §1.7 · **Docs →** search `service` →
"Connecting Applications with Services" · **Target: 3:00 create · 5:00 fix** ·
**Reported: R9, R15**

Must contain: expose a Deployment with the port the task names; `port` vs
`targetPort` vs `nodePort`; ClusterIP → NodePort on an existing Service; the empty
EndpointSlice and its two causes; the test from a throwaway Pod.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS expose deploy D --name=S --port=80 --target-port=8080 [--type=NodePort]
k -n NS get svc S -o wide ; k -n NS get endpointslices -l kubernetes.io/service-name=S   # 🔍
# R15 — ClusterIP → NodePort
k -n NS patch svc S -p '{"spec":{"type":"NodePort"}}'    # or: k -n NS edit svc S  (+ nodePort: 3xxxx if named)
# R9 — the fix: print both sides
k -n NS get svc S -o jsonpath='{.spec.selector}'; echo
k -n NS get pods --show-labels
k -n NS set selector svc S 'app=web'                     # or edit
k -n NS run tmp --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- -T2 S:80     # 🔍
```

| Empty endpoints | Cause |
|---|---|
| No address at all | selector ≠ Pod labels (key or value typo) |
| Addresses, connection refused | `targetPort` ≠ the port the container listens on |
| Addresses with `ready: false` | readiness probe failing (`ckad-D3.md` 3.2) |

To measure: all three rows on the lab; the NodePort test (`curl NODE_IP:NODEPORT`);
a named `targetPort`; whether `set selector` replaces or merges.

⚠️ **EKS:** `type: LoadBalancer` provisions an NLB there; on the lab and in the exam
it stays `<pending>` — not a fault.

```
(your runbook here)
```

---

## 5.3 Use Ingress rules to expose applications ✍️

**Runs on: cp1 (ingress-nginx from `lab/build/ckad-addons.sh`).** · **Theory →**
notes_05 §1.10 · **Docs →** search `ingress` → "Ingress" (the minimal example) ·
**Target: 4:00 create · 5:00 fix** · **Reported: R8, R9**

Must contain: an Ingress created imperatively with host, path, Service and port;
`pathType`; `ingressClassName` read from the cluster, never guessed; the
rewrite annotation; the test with a `Host` header; the four strings a broken Ingress
can have wrong.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k get ingressclass                                       # the class name to use
k -n NS create ingress I --class=CLASS --rule="HOST/PATH*=S:80"     # trailing * = pathType Prefix; without = Exact
k -n NS get ingress I ; k -n NS describe ingress I       # 🔍 Backends must show Pod IPs, not <error: endpoints not found>
curl -s -H "Host: HOST" http://NODE_IP:INGRESS_NODEPORT/PATH        # 🔍
```

R9 — the four strings, checked in this order: `ingressClassName` (vs `get
ingressclass`) → `backend.service.name` (vs `get svc`) → `backend.service.port`
(vs the Service's `port`, not its `targetPort`) → then the Service itself (5.2).

To measure: `describe ingress` for each of the four mistakes; an Ingress with no
class (ADDRESS stays empty); the no-host rule form `--rule="/PATH*=S:80"`; how the
exam exposes the controller (the task gives the URL to test).

⚠️ **EKS:** the AWS Load Balancer Controller creates an ALB per Ingress and the class
is `alb`; the object and its fields are the same.

```
(your runbook here)
```

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

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
