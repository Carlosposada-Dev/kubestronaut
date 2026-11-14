---
domain: D4 — Application Environment, Configuration and Security
group: 1 — Limits and Configuration
bullets: [4.3, 4.4, 4.5]
exams: [CKAD]
index: ckad-D4.md
theory: notes_07, notes_03
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D4.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D4 · Group 1 — Limits and Configuration (bullets 4.3, 4.4, 4.5)

> Index, drill table and scoreboard: **`ckad-D4.md`**. Session: **Wed 2 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these three: values handed to the container from outside its image — how much it may use (4.3) and what it is configured with (4.4, 4.5). All three are `create` + `set` one-liners.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 4.3 Requests, limits and quotas · 4.4 ConfigMaps · 4.5 Create and consume Secrets

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

## §9. Exam mode

> 4.2 → `cka-D1-3-access.md §9` (RBAC tasks). The rest: tasks in CKAD wording with
> 🧪 setup and 🔍 grader are written the day each bullet is worked.
