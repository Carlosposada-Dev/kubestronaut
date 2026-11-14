---
domain: D3 — Application Observability and Maintenance
group: 1 — Keep It Valid and Healthy
bullets: [3.1, 3.2]
exams: [CKAD]
index: ckad-D3.md
theory: notes_02, notes_08
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D3.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D3 · Group 1 — Keep It Valid and Healthy (bullets 3.1, 3.2)

> Index, drill table and scoreboard: **`ckad-D3.md`**. Session: **Mon 7 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these two: both are edits to a manifest that has no imperative flag — the API version it is written for (3.1) and the probes that tell the kubelet it is alive (3.2).
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 3.1 Understand API deprecations · 3.2 Implement probes and health checks

---

## 3.1 Understand API deprecations ✍️

**Runs on: cp1.** · **Theory →** notes_02 §1.3, §2.3 · **Docs →** search
`deprecated api migration` → "Deprecated API Migration Guide" · **Target: 5:00** ·
**Reported: R2**

Must contain: a manifest written for an old cluster that `apply` rejects; finding the
current group/version for a kind; fixing the fields that changed with the version;
proving it with a server-side dry run before applying.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k apply -f old.yaml --dry-run=server                    # read the error: it names the kind and version it cannot find
k api-resources | grep -i KIND                          # current APIVERSION for the kind
k explain KIND | head -5                                # GROUP / VERSION again
vim old.yaml ; k apply -f old.yaml --dry-run=server && k apply -f old.yaml
k -n NS rollout status deploy D                         # 🔍
```

The changes worth knowing by heart (the migration guide has the rest):

| Kind | Old | Current | What else changes |
|---|---|---|---|
| Deployment / DaemonSet / ReplicaSet | `extensions/v1beta1`, `apps/v1beta1`, `apps/v1beta2` | `apps/v1` | `spec.selector` is **mandatory** and must match `template.metadata.labels` |
| Ingress | `extensions/v1beta1`, `networking.k8s.io/v1beta1` | `networking.k8s.io/v1` | `pathType` required; `backend.service.name` + `backend.service.port.number` |
| CronJob | `batch/v1beta1` | `batch/v1` | — |
| PodDisruptionBudget | `policy/v1beta1` | `policy/v1` | — |
| HorizontalPodAutoscaler | `autoscaling/v2beta2` | `autoscaling/v2` | — |

R2 as reported ("apiVersion, selector, namespace"): fix the version, add the selector,
and put the object in the namespace the task names (`metadata.namespace` or `-n`).

To measure: the exact `apply` error for `extensions/v1beta1`; the error for a missing
selector; whether `kubectl convert` exists on the lab (plugin, not guaranteed in the exam).

```
(your runbook here)
```

---

## 3.2 Implement probes and health checks ✍️

**Runs on: cp1.** · **Theory →** notes_08 §1.11–1.12 · **Docs →** search
`liveness readiness` → "Configure Liveness, Readiness and Startup Probes" ·
**Target: 5:00** · **Reported: R14**

Must contain: the three probes and what each one controls (liveness → restart;
readiness → Ready condition and the EndpointSlice; startup → holds the other two);
the four handlers (`exec`, `httpGet`, `tcpSocket`, `grpc`); the timing fields
(`initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold`,
`successThreshold`); R14 — an `exec` readiness probe on a file an init container
creates (the volume half lives in `ckad-D1-3-pod-design.md` 1.3).

**No imperative flag exists for probes**: `$do > f.yaml` or `edit`, block from the docs.

```yaml
    readinessProbe:            # under the CONTAINER, same level as image
      exec:
        command: ["cat", "/work/ready"]
      initialDelaySeconds: 5
      periodSeconds: 10
```

```bash
# ▶▶ cp1 🔍 — draft path, unmeasured
k -n NS get pod P                                       # READY 1/1
k -n NS describe pod P | grep -A3 -i readiness          # the probe as stored + its failures in Events
```

To measure: READY `0/1` + the `Readiness probe failed` event text; the EndpointSlice
`ready: false`; a liveness failure's RESTARTS; a Pod's probes are immutable in place
(`replace --force`), a Deployment's roll.

```
(your runbook here)
```

---

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
