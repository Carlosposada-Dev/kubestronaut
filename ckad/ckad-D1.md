---
domain: D1 — Application Design and Build
weight: 20%
exams: [CKAD]
theory: notes_03, notes_04, notes_06
k8s_version: v1.37
status: skeleton — 0 / 4 bullets
revision: 2026-11-13 (r1 — skeleton; draft paths unmeasured, migrated to Template C the day each bullet is worked)
---

# D1 — Application Design and Build (20%)

> Operational layer. Theory lives in notes_03 (workloads), notes_04 (images) and
> notes_06 (volumes) — **not repeated here**. ✍️ = worked in the lab, then rewritten
> from memory. A bullet closes when done twice in a row under target **without looking**.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
> Per-host setup at 0:00 of every session: `plan.md §13`.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

**What unites these four.** Everything that is decided *before* the application is
deployed: the image it runs (1.1), the controller that owns it (1.2), how many
containers share its Pod (1.3) and where its data lives (1.4).

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.1 images · 1.2 Job / CronJob / DaemonSet · 1.3 init + sidecar · 1.4 volumes

---

## 1.1 Define, build and modify container images ✍️

**Runs on: the task's host (lab: cp1, podman from `lab/build/ckad-addons.sh`).** ·
**Theory →** notes_04 §1.10, §1.12 · **Docs →** not on kubernetes.io: `podman --help`,
`podman save --help` · **Target: 5:00** · **Reported: R1**

Must contain: reading a Dockerfile and changing one instruction (`FROM`, `RUN`,
`COPY`, `ENV`, `USER`, `CMD` vs `ENTRYPOINT`); build with a name **and tag**; list;
run detached with a name; logs; **save the image** to a tar in the format the task
names; **export a container**; tag and push to the registry the task names.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
podman build -t NAME:TAG -f DIR/Dockerfile DIR          # the last argument is the build context
podman images | grep NAME                               # 🔍
podman run -d --name CTR NAME:TAG ; podman ps -a ; podman logs CTR
podman save -o /PATH/img.tar NAME:TAG                   # image → tar (add --format oci-archive if OCI is asked)
podman export -o /PATH/ctr.tar CTR                      # container filesystem → tar (same as: export CTR > file)
podman tag NAME:TAG REGISTRY/NAME:TAG ; podman push REGISTRY/NAME:TAG
```

To measure in the guided pass: whether `podman` needs `sudo` on the lab; short image
names (`FROM nginx`) vs fully qualified (`docker.io/library/nginx`); the default
`save` format and what `--format oci-archive` changes; the error for a missing tag;
`docker` accepts the same verbs (the task names the tool).

**The distinction R1 turns on:** `save` ↔ `load` move an **image** (layers + metadata);
`export` ↔ `import` move a **container's flattened filesystem** (no history, no CMD).
The task says which object and which file — the verb follows from that.

⚠️ **EKS:** day to day the image is built by a pipeline and pushed to ECR; the local
build → save → load path never appears.

```
(your runbook here)
```

---

## 1.2 Choose and use the right workload resource ✍️

**Runs on: cp1.** · **Theory →** notes_03 §1.5–1.8 · **Docs →** search `cronjob` /
`job` → "Running an Automated Task" / "Job patterns" · **Target: 5:00** ·
**Reported: R3, R5**

Must contain: the decision (Deployment / DaemonSet / StatefulSet / Job / CronJob —
notes_03 §1.8); Job and CronJob created imperatively and completed in vim; the five
Job knobs and where each lives; a manual run of a CronJob; a DaemonSet built from a
Deployment manifest (there is no `create daemonset`).

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS create job J --image=IMG $do -- sh -c 'CMD' > j.yaml
k -n NS create cronjob CJ --image=IMG --schedule="*/30 * * * *" --restart=OnFailure $do -- sh -c 'CMD' > cj.yaml
vim cj.yaml ; k apply -f cj.yaml
k -n NS create job CJ-test --from=cronjob/CJ            # R5 — the manual run, also the proof of R3
k -n NS get cj,job,pods ; k -n NS logs job/CJ-test      # 🔍
```

```yaml
spec:                              # CronJob
  schedule: "*/30 * * * *"
  concurrencyPolicy: Forbid        # Allow | Forbid | Replace
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:                          # Job
      completions: 4               # how many Pods must succeed
      parallelism: 2               # how many run at once
      backoffLimit: 3              # retries before the Job is Failed
      activeDeadlineSeconds: 60    # the Job's time limit
      ttlSecondsAfterFinished: 120
      template:
        spec:
          restartPolicy: OnFailure # Never | OnFailure — Always is rejected
```

**The indentation is the task.** A CronJob nests three `spec`s (CronJob → Job → Pod);
every knob belongs to exactly one. "Replicas" in a report means `completions` /
`parallelism` — a Job has no `replicas`. `activeDeadlineSeconds` exists at Job level
(whole Job) and at Pod level (one Pod): the task wording decides.

DaemonSet: `k create deploy D --image=IMG $do > ds.yaml` → `kind: DaemonSet`, delete
`replicas`, `strategy` and `status`.

To measure: the events of a Job that hits `activeDeadlineSeconds`; what `--restart`
writes; `get job` columns with `completions`/`parallelism`; `concurrencyPolicy` proof.

⚠️ **EKS:** identical objects. DaemonSets there are mostly add-ons (VPC CNI, kube-proxy).

```
(your runbook here)
```

---

## 1.3 Multi-container Pod design patterns ✍️

**Runs on: cp1.** · **Theory →** notes_03 §1.4, notes_04 §1.4 · **Docs →** search
`init containers` / `sidecar containers` · **Target: 6:00** · **Reported: R14 (the
init half)**

Must contain: an init container that prepares a file in a shared `emptyDir`; a
sidecar that reads what the main container writes (log tailer); the native sidecar
form (an `initContainers` entry with `restartPolicy: Always`); `-c` on `logs` and
`exec`; reading `Init:0/1`, `Init:Error`, `PodInitializing` in `get pods`.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS run P --image=IMG $do -- sh -c 'CMD' > p.yaml   # one container generated…
vim p.yaml                                              # …volumes + initContainers / second container by hand
k -n NS logs P -c CONTAINER ; k -n NS exec P -c CONTAINER -- ls /SHARED
```

```yaml
spec:
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: init
    image: busybox:1.36
    command: ["sh","-c","echo ok > /work/ready"]
    volumeMounts: [{name: shared, mountPath: /work}]
  containers:
  - name: app
    image: nginx:1.29
    volumeMounts: [{name: shared, mountPath: /work}]
```

A Pod's containers cannot be added or removed in place: existing Pod →
`k get pod P -o yaml > p.yaml`, edit, `k replace --force -f p.yaml`. In a Deployment
the template is editable and rolls.

To measure: `get pods` STATUS through the init phases; the `replace --force` output;
the default container chosen by `logs` without `-c`.

```
(your runbook here)
```

---

## 1.4 Utilize persistent and ephemeral volumes ✍️

**Runs on: cp1.** · **Theory →** notes_06 §1.3–1.5, §1.8, §1.12 · **Docs →** search
`persistent volume pod` → "Configure a Pod to Use a PersistentVolume for Storage" ·
**Target: 7:00** · not in the reported list — still 1 of 4 bullets of a 20% domain

Must contain: `emptyDir` (and `medium: Memory`); a `hostPath` PV + a PVC that binds
to it + a Pod that mounts it; the three fields that must agree for a bind
(`storageClassName`, `accessModes`, capacity ≥ request); `subPath`; a ConfigMap /
Secret as a volume (home: `ckad-D4.md` 4.4 / 4.5).

**Nothing here is imperative.** No `create pv`, no `create pvc`. The path is the docs
page above: three YAML blocks (PV, PVC, Pod), copy and change the literals — the
drill is finding that page in 20 s.

To measure: a PVC `Pending` because of a `storageClassName` mismatch (the event
text); the lab has no default StorageClass; what `get pv` shows in `CLAIM` once bound.

⚠️ **EKS:** a `gp2`/`gp3` default class provisions the PV for you; here a PVC with no
class binds only to a pre-created PV with no class.

```
(your runbook here)
```

---

## §7. Drill table

| # | Task | Bullet | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Build an image from a given Dockerfile, run it, save it to a tar | 1.1 | 5:00 | | | | | |
| 2 | CronJob `*/30` with completions, parallelism, backoff, deadline; run it once by hand | 1.2 | 5:00 | | | | | |
| 3 | Job from an existing CronJob + read its logs | 1.2 | 1:00 | | | | | |
| 4 | DaemonSet from a Deployment manifest | 1.2 | 3:00 | | | | | |
| 5 | Pod with an init container that writes into a shared `emptyDir` | 1.3 | 6:00 | | | | | |
| 6 | Add a log-tailing sidecar to an existing Deployment | 1.3 | 5:00 | | | | | |
| 7 | PV + PVC + Pod mounting it, data written and read back | 1.4 | 7:00 | | | | | |

## §8. Objectives scoreboard — D1

| Bullet | Performed from memory, timed, verified |
|---|---|
| 1.1 Container images | ☐ |
| 1.2 Workload resources | ☐ |
| 1.3 Multi-container patterns | ☐ |
| 1.4 Volumes | ☐ |
| **Total** | **0 / 4** |

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
