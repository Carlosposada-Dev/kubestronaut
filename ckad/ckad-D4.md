---
domain: D4 — Application Environment, Configuration and Security
weight: 25%
exams: [CKAD]
theory: notes_07, notes_02, notes_03
k8s_version: v1.37
status: skeleton — 2 / 7 bullets (4.1, 4.2 closed in CKA D1-3)
revision: 2026-11-13 (r1 — skeleton; 4.1 and 4.2 point at their CKA homes; draft paths unmeasured)
---

# D4 — Application Environment, Configuration and Security (25%)

> Operational layer. Theory in notes_07 §1.2–1.13, notes_03 §1.11 and notes_02 §1.12.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> **The largest domain, and 6 of the 16 reported tasks.** Two bullets are already
> closed from CKA; the other five are short and almost fully imperative.
> **Draft path** blocks are the expected exam path, **not yet run on the lab**.

**What unites these seven.** Everything the Pod is *given* from outside its image:
its identity and what that identity may do (4.6, 4.2), its limits (4.3), its
configuration (4.4, 4.5), its kernel permissions (4.7) and the extra kinds the
cluster offers (4.1).

| Bullet | Home | State on 13 Nov |
|---|---|---|
| 4.1 CRDs, operators | `cka/cka-D1-3-access.md` 1.8 | ✅ recognise-only, Task D 0:41 |
| 4.2 Authn, authz, admission | `cka/cka-D1-3-access.md` 1.1 (RBAC) + delta below | ✅ RBAC cold 3:46 · 3:24 |
| 4.3 – 4.7 | **here** | new |

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 4.3 requests / limits / quota · 4.4 ConfigMaps · 4.5 Secrets · 4.6 ServiceAccounts · 4.7 securityContext

---

## 4.1 CRDs and operators — home: `cka/cka-D1-3-access.md` 1.8

Recognise-only stands: `k get crd`, `k api-resources | grep GROUP`, `k explain KIND`,
create a custom resource from a given manifest, CR vs CRD delete. No new work.

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

## 4.3 Requests, limits and quotas ✍️

**Runs on: cp1.** · **Theory →** notes_03 §1.11, notes_07 §1.9 · **Docs →** search
`resource quota` / `limit range` · **Target: 6:00** · **Reported: R4**

Must contain: requests and limits set imperatively on a Deployment; reading a
ResourceQuota (`Used` / `Hard`); creating and changing one; a LimitRange from the
docs; what happens to a Pod with no requests in a namespace whose quota tracks them;
units (`m`, `Mi` vs `M`).

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS describe quota                                  # read FIRST: Used / Hard per resource
k -n NS set resources deploy D --requests=cpu=100m,memory=64Mi --limits=cpu=250m,memory=128Mi
k -n NS create quota Q --hard=pods=1,requests.cpu=500m,limits.memory=256Mi
k -n NS edit quota Q                                    # change spec.hard in place
k -n NS rollout status deploy D ; k -n NS describe quota   # 🔍
k -n NS describe rs | tail -5                           # 🔍 a quota rejection shows HERE, not on the Deployment
```

**R4 is arithmetic, then two edits.** "Limits = half the namespace quota": read
`limits.cpu` / `limits.memory` in the quota, halve them, `set resources`. "Redefine
the quota so only one Pod can run": `pods: 1`, or limits that fit exactly one Pod —
the task's wording decides. A rolling update needs room for a surge Pod: with `pods: 1`
a `RollingUpdate` of a 1-replica Deployment stalls (home: `cka-D2-1-workloads.md` 2.1 step 6).

To measure: the `FailedCreate` event text on the ReplicaSet; a Pod without requests
under a quota on `requests.cpu`; the stall with `pods: 1`; LimitRange defaults
appearing on a new Pod.

⚠️ **EKS:** identical. Quotas are rarely set there, so the "no Pods and no error on the
Deployment" symptom is unfamiliar.

```
(your runbook here)
```

---

## 4.4 ConfigMaps ✍️

**Runs on: cp1.** · **Theory →** notes_07 §1.10 · **Docs →** search `configmap` →
"Configure a Pod to Use a ConfigMap" · **Target: 4:00** · home for
`cka-D2-1-workloads.md` 2.2 as well (first worked here)

Must contain: the three sources (`--from-literal`, `--from-file`, `--from-env-file`);
the three ways in (one key as `env.valueFrom.configMapKeyRef`, all keys as `envFrom`,
files as a volume); which of them follow a change (mounted: yes, eventually; env: no).

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS create cm CM --from-literal=K1=V1 --from-file=app.conf
k -n NS set env deploy D --from=configmap/CM            # every key becomes an env var
k -n NS set env deploy D --list                         # 🔍
k -n NS exec deploy/D -- env | grep K1                  # 🔍 from inside
```

Volume mount and a renamed variable (`name: DB_HOST` from key `host`) have no flag →
`edit` / `$do > f.yaml` with the docs block.

To measure: what `set env --from` writes into the template; `--from-file` key name =
file name; `CreateContainerConfigError` for a missing key.

```
(your runbook here)
```

---

## 4.5 Create and consume Secrets ✍️

**Runs on: cp1.** · **Theory →** notes_07 §1.10 · **Docs →** search `secret` →
"Distribute Credentials Securely Using Secrets" · **Target: 4:00** · **Reported: R13**

Must contain: `generic`, `tls` and `docker-registry` created imperatively; consumed
as env vars and as a volume; the value read back decoded; `imagePullSecrets`.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS create secret generic S --from-literal=USER=admin --from-literal=PASS=s3cret
k -n NS set env deploy D --from=secret/S                # R13: every key as an env var (secretKeyRef)
k -n NS rollout status deploy D
k -n NS exec deploy/D -- env | grep -E 'USER|PASS'      # 🔍
k -n NS get secret S -o jsonpath='{.data.PASS}' | base64 -d; echo
```

If the task names the **variable** differently from the **key** (`DB_PASSWORD` from
key `PASS`): `edit`, `env[].valueFrom.secretKeyRef.{name,key}`. Read which one the
task spells out before choosing `--from`.

To measure: `set env --from=secret/S --prefix=`; the template it produces; a Secret
written with `stringData` vs `data`.

```
(your runbook here)
```

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

## §9. Exam mode

> 4.2 → `cka-D1-3-access.md §9` (RBAC tasks). The rest: tasks in CKAD wording with
> 🧪 setup and 🔍 grader are written the day each bullet is worked.
