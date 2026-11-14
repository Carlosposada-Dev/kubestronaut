---
domain: D3 — Application Observability and Maintenance
weight: 15%
exams: [CKAD]
theory: notes_02, notes_08, notes_09
k8s_version: v1.37
status: skeleton — 0 / 5 bullets
revision: 2026-11-13 (r1 — skeleton; draft paths unmeasured, migrated to Template C the day each bullet is worked)
---

# D3 — Application Observability and Maintenance (15%)

> Operational layer. Theory in notes_08 (the method, probes, logs, debug), notes_09
> §1.7 (metrics-server) and notes_02 §1.3 (API groups and versions).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**.

**What unites these five.** The application is already deployed and something must be
*read* from it: is its manifest still valid (3.1), is it healthy (3.2), what does it
consume (3.3), what does it say (3.4), why is it broken (3.5). Three of the five are
one-liners whose only trap is writing the answer to the file the task names.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 3.1 deprecations · 3.2 probes · 3.3 top / events · 3.4 logs · 3.5 debug ladder

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
creates (the volume half lives in `ckad-D1.md` 1.3).

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

## 3.3 Use built-in CLI tools to monitor applications ✍️

**Runs on: cp1 (needs metrics-server — Helm install as in `cka-D1-3-access.md` 1.6).** · **Theory →**
notes_09 §1.7 · **Docs →** `k top -h` · **Target: 2:00**

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k top pods -A --sort-by=memory | head                   # or --sort-by=cpu
k -n NS top pod P --containers
k top nodes
k -n NS get events --sort-by=.lastTimestamp | tail
k -n NS get pods -l app=X -o wide --show-labels
```

The task is usually "write the name of the Pod using the most CPU to /path/file":
the answer is one word in one file — `echo NAME > /path/file`, then `cat` it.

To measure: `top` right after a Pod starts (`metrics not available yet`); `--sort-by`
with `-A`.

---

## 3.4 Utilize container logs ✍️

**Runs on: cp1.** · **Theory →** notes_08 §1.8 · **Docs →** `k logs -h` · **Target: 2:00**

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS logs P -c CONTAINER > /PATH/file                # the file is the answer
k -n NS logs P --previous                               # the container that crashed
k -n NS logs deploy/D --all-containers --tail=20
k -n NS logs -l app=X --prefix --since=10m
```

To measure: `logs` on a multi-container Pod without `-c` (which one, which message);
`--previous` with no previous container.

---

## 3.5 Debugging in Kubernetes ✍️

**Runs on: cp1.** · **Theory →** notes_08 §1.1–1.4, §1.7, §1.10 · **Docs →** search
`debug running pods` / `debug service` · **Target: 6:00 to find + fix** · **Reported: R9**

Must contain the ladder, always in this order — the STATUS column picks the rung:

| `get pods` says | Look at | Usual cause in a CKAD task |
|---|---|---|
| `Pending` | `describe pod` → Events | quota, unbound PVC, nodeSelector, no resources |
| No Pod at all | `describe rs` / `get events` | ResourceQuota or LimitRange rejected it; bad ServiceAccount |
| `ErrImagePull` / `ImagePullBackOff` | Events | image name or tag typo |
| `CrashLoopBackOff` / `Error` | `logs --previous`, exit code | wrong command, missing env / ConfigMap key |
| `CreateContainerConfigError` | Events | ConfigMap / Secret / key does not exist |
| `Running` but `0/1` | `describe` → readiness | probe path / port wrong |
| `Running` `1/1`, no traffic | `get endpointslices`, selector, ports | Service selector / targetPort (`ckad-D5.md` 5.2) |

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS get pods -o wide ; k -n NS describe pod P | tail -20
k -n NS run tmp --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- -T2 SVC:PORT
k -n NS exec -it P -- sh
k -n NS debug -it P --image=busybox:1.36 --target=CONTAINER
```

To measure: one broken object per rung, built by the setup of §9.

```
(your runbook here)
```

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Fix a Deployment manifest written for an old API version and apply it | 3.1 | 5:00 | | | | | |
| 2 | `exec` readiness probe on a file created by an init container | 3.2 | 6:00 | | | | | |
| 3 | Liveness `httpGet` + readiness `tcpSocket` on an existing Deployment | 3.2 | 5:00 | | | | | |
| 4 | Highest-CPU Pod of a namespace written to a file | 3.3 | 2:00 | | | | | |
| 5 | Logs of one container of a multi-container Pod written to a file | 3.4 | 2:00 | | | | | |
| 6 | Three broken Pods, one per rung: find and fix | 3.5 | 9:00 | | | | | |

## §8. Objectives scoreboard — D3

| Bullet | Performed from memory, timed, verified |
|---|---|
| 3.1 API deprecations | ☐ |
| 3.2 Probes | ☐ |
| 3.3 CLI monitoring | ☐ |
| 3.4 Logs | ☐ |
| 3.5 Debugging | ☐ |
| **Total** | **0 / 5** |

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
