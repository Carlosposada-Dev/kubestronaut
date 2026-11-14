---
domain: D5 — Services and Networking
group: 1 — Reach the Application
bullets: [5.2, 5.3]
exams: [CKAD]
index: ckad-D5.md
theory: notes_05
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D5.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D5 · Group 1 — Reach the Application (bullets 5.2, 5.3)

> Index, drill table and scoreboard: **`ckad-D5.md`**. Session: **Sat 5 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these two: the path of a request — Ingress → Service → Pod — and the three strings that must match along it. The fix task (R9) breaks one string in each.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 5.2 Provide and troubleshoot access via Services · 5.3 Use Ingress rules to expose applications

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
| Addresses with `ready: false` | readiness probe failing (`ckad-D3-1-health.md` 3.2) |

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

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
