---
domain: D1 — Application Design and Build
group: 2 — Pick the Controller
bullets: [1.2]
exams: [CKAD]
index: ckad-D1.md
theory: notes_03
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D1.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D1 · Group 2 — Pick the Controller (bullet 1.2)

> Index, drill table and scoreboard: **`ckad-D1.md`**. Session: **Tue 1 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> One sub-session: which controller owns the Pods — Job, CronJob, DaemonSet — and the knobs of each.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.2 Choose and use the right workload resource

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

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
