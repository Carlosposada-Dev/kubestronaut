---
domain: D4 — Application Environment, Configuration and Security
group: 2 — Identity and Permissions
bullets: [4.1, 4.2, 4.6, 4.7]
exams: [CKAD]
index: ckad-D4.md
theory: notes_07, notes_02
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D4.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D4 · Group 2 — Identity and Permissions (bullets 4.1, 4.2, 4.6, 4.7)

> Index, drill table and scoreboard: **`ckad-D4.md`**. Session: **Thu 3 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these: who the Pod is to the API (4.6), what that identity may do (4.2) and what its processes may do on the node (4.7). 4.1 and the RBAC half of 4.2 are pointers to `cka/`.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 4.1 CRDs and operators · 4.2 Authentication, authorization and admission control · 4.6 ServiceAccounts · 4.7 Application security

---

## 4.1 CRDs and operators — home: `cka/cka-D1-3-access.md` 1.8

Recognise-only stands: `k get crd`, `k api-resources | grep GROUP`, `k explain KIND`,
create a custom resource from a given manifest, CR vs CRD delete. No new work.

---

## 4.2 Authentication, authorization and admission control — home: `cka/cka-D1-3-access.md` 1.1

**Reported: R10, R11.** RBAC is not rewritten: the two-rule method and one `can-i`
per rule stand. CKAD delta:

- The subject is almost always a **ServiceAccount** (4.6), and the task is finished
  on the workload, not on the Role.
- R11 "read the logs": resource **`pods/log`** — singular (7 Nov miss: `pods/logs`).
  `k -n NS create role R --verb=get,list --resource=pods,pods/log`
- Proof: `k -n NS auth can-i get pods/log --as=system:serviceaccount:NS:SA`
- Admission — recognise the three that reject application objects, by their message:
  ResourceQuota (`exceeded quota`), LimitRange (`maximum cpu usage per Container is…`),
  Pod Security Admission (`violates PodSecurity "restricted:latest"` — namespace label
  `pod-security.kubernetes.io/enforce`). Theory: notes_07 §1.12–1.13.

---

## 4.6 ServiceAccounts ✍️

**Runs on: cp1.** · **Theory →** notes_07 §1.4 · **Docs →** search
`service account` → "Configure Service Accounts for Pods" · **Target: 4:00** ·
**Reported: R10, R11**

Must contain: create an SA; set it on a Deployment imperatively and on a Pod by
`replace --force`; find which SA an existing RoleBinding expects; prove the
permission from the SA's point of view; `automountServiceAccountToken: false`.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS get rolebinding RB -o yaml | grep -A4 subjects  # R10: the SA name the binding expects — create THAT name
k -n NS create sa SA
k -n NS set serviceaccount deploy D SA                  # Deployment: imperative, rolls
k -n NS get pod P -o yaml > p.yaml ; vim p.yaml ; k replace --force -f p.yaml   # Pod: serviceAccountName is immutable
k -n NS auth can-i list pods --as=system:serviceaccount:NS:SA                   # 🔍
k -n NS get pod P -o jsonpath='{.spec.serviceAccountName}'; echo                # 🔍
```

**R10 in one sentence:** the Role and the RoleBinding exist; the binding names a
ServiceAccount that does not — create it with that exact name and namespace, then
put it on the Pod. Nothing in RBAC complains about a subject that does not exist.

To measure: a Pod naming a missing SA (the ReplicaSet event); `replace --force`
output; `can-i` before and after.

```
(your runbook here)
```

---

## 4.7 Application security — SecurityContext, capabilities ✍️

**Runs on: cp1.** · **Theory →** notes_07 §1.11 · **Docs →** search
`security context` → "Configure a Security Context for a Pod or Container" ·
**Target: 5:00** · **Reported: R7**

Must contain: which field lives at which level; `runAsUser` / `runAsGroup` /
`fsGroup` / `runAsNonRoot`; `capabilities.add` / `drop`; `allowPrivilegeEscalation`;
`readOnlyRootFilesystem`; the proof from inside the container.

| Field | Pod level (`spec.securityContext`) | Container level (`containers[].securityContext`) |
|---|---|---|
| `runAsUser`, `runAsGroup`, `runAsNonRoot` | ✅ | ✅ (wins) |
| `fsGroup` | ✅ | — |
| `capabilities`, `allowPrivilegeEscalation`, `readOnlyRootFilesystem`, `privileged` | — | ✅ |

```yaml
    spec:
      securityContext:
        runAsUser: 1000
      containers:
      - name: app
        securityContext:
          capabilities:
            add: ["NET_ADMIN", "SYS_TIME"]     # no CAP_ prefix
          allowPrivilegeEscalation: false
```

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS edit deploy D                                   # no imperative flag for any of it
k -n NS rollout status deploy D
k -n NS exec deploy/D -- id                             # 🔍 uid=1000
k -n NS get deploy D -o jsonpath='{.spec.template.spec.containers[0].securityContext}'; echo   # 🔍
```

To measure: `capabilities` written at Pod level (the error); an image that cannot
start as a non-root UID (nginx → CrashLoopBackOff: use the image the task gives);
`runAsNonRoot: true` on a root image.

⚠️ **EKS:** identical fields; Pod Security Admission labels are the same mechanism.

```
(your runbook here)
```

---

## §9. Exam mode

> 4.2 → `cka-D1-3-access.md §9` (RBAC tasks). The rest: tasks in CKAD wording with
> 🧪 setup and 🔍 grader are written the day each bullet is worked.
