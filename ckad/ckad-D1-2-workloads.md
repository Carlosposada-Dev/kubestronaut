---
domain: D1 — Application Design and Build
group: 2 — Pick the Controller
bullets: [1.2]
exams: [CKAD]
index: ckad-D1.md
theory: notes_03
k8s_version: v1.37
status: 'r2 — Template C, measured on ckad-v137 (21 Nov 2026)'
revision: '2026-11-21 (r2 — Template C: shape in the 29 Oct format, whiteboard and traps measured on ckad-v137, §9 Set 1 with four graders verified) · 2026-11-13 (r1 — split out of ckad-D1.md, unmeasured skeleton)'
---

# D1 · Group 2 — Pick the Controller (bullet 1.2)

> Index, drill table, scoreboard and where every command runs: **`ckad-D1.md`**.
> Session: **Tue 1 Dec** (`plan.md §10.2`). Objectives and the reported-task list
> (R#): `ckad-curriculum.md`. Reference implementation of the format:
> `cka/cka-D1-2-lifecycle.md`.
>
> One sub-session: **which controller owns the Pods** — Deployment, DaemonSet,
> StatefulSet, Job, CronJob — and the knobs of each. Every output below was measured
> on `ckad-v137` (v1.37.2, 3 nodes) on 21 Nov 2026.

---

## Legend — what to type in the exam, what is only for learning

| Mark | Meaning | In the exam |
|---|---|---|
| 🎯 | **Exam path** — the task is not done without it | type it |
| 🔍 | **Verification** — proves the task worked | type it, once, at the end |
| ⏱ | **Waiting** — fixed machine time | start another task, come back |
| 📚 | **Study only** — teaches the mechanism, scores nothing | skip |
| 🧪 | **Scaffolding** — exists because this is a home lab | never appears in the exam |

**Rule that outranks the marks:** whatever the task statement spells out — a name, a
namespace, an image, a schedule, a number — is literal. 🎯 blocks show defaults, not
orders. Copy the literals into shell variables before the first command (the 8 Nov
method, `ckad-curriculum.md §1`).

**Conventions in this file:** `k` = `kubectl` (preconfigured in the exam) ·
`$do` = `--dry-run=client -o yaml` (the per-host line, `plan.md §13`) · every block
runs on **cp1** in the lab; in the exam, on the host the task names.

Card index: **1.2** choose and use the right workload resource.

---

## 1.2 Choose and use the right workload resource ⚙️

**Runs on: cp1** (exam: the task's host) · **Theory →** note 03 §1.3 · note 03 §1.5 ·
note 03 §1.6 · note 03 §1.7 · note 03 §1.8 ·
**Docs →** search `CronJob` · `Jobs` · `DaemonSet` · `StatefulSets` ·
**explain →** `kubectl explain cronjob.spec.jobTemplate.spec` ·
**Target: 5:00** (CronJob with knobs + manual run) · **Reported: R3, R5**

### The shape

**The idea.** Answer one question — *does the work end on its own?* — to pick the
controller, then put every knob on the one `spec` level that owns it. Not here:
rolling updates and rollbacks (2.2, `ckad-D2-1-strategies.md`), probes (3.2),
volumes and StorageClasses (1.4, `ckad-D1-3-pod-design.md`).

**The analogy — a staffing agency.** A **Deployment** is permanent staff: N
interchangeable employees, always on duty. A **DaemonSet** is one security guard per
building (node) — you never say how many, the buildings decide. A **StatefulSet** is
named staff with their own locker: `web-1` always comes back to `web-1`'s locker. A
**Job** is a contractor hired to finish a piece of work N times and then leave. A
**CronJob** is the standing order with the agency — "send a contractor every 30
minutes" — it never works itself, it only sends Jobs. The order form (CronJob) holds a
contract (Job) which describes the worker (Pod): three forms nested inside each other,
and every clause belongs on exactly one of them.

| # | Step | What it does | Why (the failure it prevents) | Watch out | Exam? |
|---|---|---|---|---|---|
| 1 | **Choose** the kind | Maps the task's wording to one of five controllers | `kind` cannot be edited later, and a Job's Pod template is immutable — a wrong choice means delete and redo | "every node" → DaemonSet · "until it completes" → Job · "every 30 minutes" → CronJob · "stable name / own storage" → StatefulSet · else Deployment | 🎯 |
| 2 | **Generate** imperatively | `k create cronjob/job/deployment … $do > f.yaml` writes the skeleton | Hand-typed YAML costs minutes and fails on `apiVersion`, nesting or selector | There is **no** `create daemonset` / `create statefulset` — generate a Deployment and convert. `create job` has **no `--restart`** (it writes `Never`); `create cronjob` writes `OnFailure` | 🎯 |
| 3 | Put the **knobs** on their level | Adds the task's numbers in vim, under the right `spec` | A knob on the wrong level is rejected (`strict decoding error: unknown field`) | `activeDeadlineSeconds` is valid on **both** the Job and the Pod — the wrong level is accepted silently | 🎯 |
| 4 | **Convert** when the kind has no generator | Deployment YAML → DaemonSet (drop `replicas` + `strategy`) or StatefulSet (add `serviceName` + a headless Service) | A DaemonSet with `replicas` is rejected; without a toleration it skips the control plane | Conversion happens **before** `apply` — `kind` is immutable | 🎯 |
| 5 | **Apply and run once** | `apply`, then `k create job NAME --from=cronjob/CJ` | A `*/30` schedule makes you wait up to 30 min; the manual Job is the "test it" of R3 and the whole of R5 | The manual Job needs a **new name**; the same name twice → `already exists` | 🎯 |
| 6 | **Prove** | `get cj,job,pods` · `logs job/NAME` · `get ds` | A Job that hit its deadline or backoff limit looks "created" until you read `STATUS` | `FailureTarget` is a transient status (~30 s) before `Failed` | 🔍 |

**How it connects — the symptom of each missing step**

| Step skipped or wrong | What you see |
|---|---|
| 1 Choose | Two Pods with random suffixes where the task asked for one per node, or for `db-0` |
| 2 Generate | `apiVersion` / `selector` errors, wrong nesting — time gone before the first apply |
| 3 Knobs | `strict decoding error: unknown field "spec.completions"` — or, silently, a Pod-level `activeDeadlineSeconds` |
| 4 Convert | `unknown field "spec.replicas", unknown field "spec.strategy"` · DaemonSet `DESIRED 2` on a 3-node cluster · `pg-0.pg` does not resolve |
| 5 Run once | `LAST SCHEDULE <none>`, no Job, the "test it" requirement unproven |
| 6 Prove | A Job in `Failed` (`BackoffLimitExceeded` / `DeadlineExceeded`) declared done |

**What is what**

| 🎯 Type it in the exam | 🔍 Check it | 📚 Understanding only |
|---|---|---|
| `k create cronjob` / `job` / `deployment … $do` | `k get cj,job,pods` columns | Job name suffix = scheduled minute since the epoch |
| knob lines in vim, at the right indent | `k logs job/NAME` | `ownerReferences` CronJob → Job → Pod |
| `k create job NAME --from=cronjob/CJ` | `k get ds` `DESIRED` = node count | DaemonSet Pods placed by the scheduler via node affinity |
| kind swap + delete `replicas`/`strategy` | `k -n NS events --for job/NAME` | `concurrencyPolicy` / `startingDeadlineSeconds` timing |
| `k create service clusterip NAME --clusterip=None` | `nslookup pod-0.svc` from a busybox Pod | `volumeClaimTemplates` binding (needs a StorageClass) |

**Mnemonic — C·G·K·C·R·P:** ***C**ats **G**row **K**iwis, **C**onvert **R**abbits, **P**urr.*
Choose → Generate → Knobs → Convert → Run → Prove. **Why this order:** the kind decides
which generator exists (1 → 2); the generator decides the nesting the knobs go into
(2 → 3); conversion must happen before the first `apply` because `kind` is immutable
(4 → 5); a manual run needs the CronJob to exist (5 after apply); proof is last
because it reads what the controller did.

### The whiteboard

#### W1 · Choose — five controllers, one question

```
Does the work end on its own?
├─ yes ── on a schedule? ── yes → CronJob
│                        └─ no  → Job
└─ no  ── one per node?   ── yes → DaemonSet
          └─ no ── does each replica need its own identity/storage?
                   ├─ yes → StatefulSet
                   └─ no  → Deployment
```

| Kind | Answers | Cannot do | Short name | Imperative generator |
|---|---|---|---|---|
| Deployment | N interchangeable replicas, forever, rolling versions | per-node placement · stable names · finish | `deploy` | `create deployment` |
| DaemonSet | one Pod per (matching) node | `replicas` — the field does not exist | `ds` | **none** — convert a Deployment |
| StatefulSet | N replicas with stable name, DNS and own PVC | random names | `sts` | **none** — convert a Deployment |
| Job | run to completion, N successes | `restartPolicy: Always` · `replicas` | — (none) | `create job` |
| CronJob | a Job on a schedule | create Pods directly | `cj` | `create cronjob` |

Measured short names (`k api-resources`):

```
daemonsets      ds      apps/v1    true   DaemonSet
deployments     deploy  apps/v1    true   Deployment
statefulsets    sts     apps/v1    true   StatefulSet
cronjobs        cj      batch/v1   true   CronJob
jobs                    batch/v1   true   Job
```

**Task wording → kind.** "on every node / each node / a log or monitoring agent" →
DaemonSet · "once / a batch / until it completes / N times" → Job · "every N minutes /
daily at / on a schedule" → CronJob · "stable network identity / ordered start / its
own storage per replica" → StatefulSet · anything else long-running → Deployment.

#### W2 · Generate — `create cronjob` and `create job`

```bash
# ▶▶ cp1 — ubuntu@cp1   🎯
k -n NS create cronjob cj --image=busybox:1.28 --schedule="*/30 * * * *" $do -- sh -c "date; echo hi" > cj.yaml
k -n NS create job j --image=busybox:1.28 $do -- sh -c "echo hi" > j.yaml
```

| Piece | Meaning |
|---|---|
| `--image` | the container image — the container is named after the object (`cj`, `j`) |
| `--schedule="…"` | five cron fields, **quoted** (the `*` would glob in bash) — `create cronjob` only |
| `--restart=OnFailure\|Never` | `create cronjob` only. Default **`OnFailure`**. `create job` rejects the flag: `error: unknown flag: --restart` and writes **`Never`** |
| `$do` | `--dry-run=client -o yaml` — print, do not create |
| `-- sh -c "…"` | everything after `--` becomes `command:`; without `--` the words are parsed as flags |

Measured output of the CronJob generator — **three `spec`s, three indents**:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cj
  namespace: d12-lab
spec:                          # ← CronJob level (2 spaces for its fields)
  jobTemplate:
    metadata:
      name: cj
    spec:                      # ← Job level: Job knobs go right under this line (6 spaces)
      template:
        metadata: {}
        spec:                  # ← Pod level (10 spaces)
          containers:
          - command:
            - sh
            - -c
            - date; echo hi
            image: busybox:1.28
            name: cj
            resources: {}
          restartPolicy: OnFailure
  schedule: '*/30 * * * *'
status: {}
```

A plain Job has the same last two levels one step up: Job knobs at 2 spaces under
`spec:`, Pod fields at 6 spaces.

**Cron fields** — `minute hour day-of-month month day-of-week`, in **UTC** unless
`spec.timeZone` is set:

| Schedule | Runs |
|---|---|
| `*/30 * * * *` | every 30 minutes (:00 and :30) |
| `30 * * * *` | **once an hour**, at minute 30 — the classic misread of "every 30 minutes" |
| `0 */2 * * *` | every 2 hours, on the hour |
| `0 3 * * *` | daily at 03:00 |
| `0 0 * * 0` | Sundays at midnight |

Measured rejections:

```
spec.schedule: Invalid value: "*/30 * * *": expected exactly 5 fields, found 4: [*/30 * * *]
spec.schedule: Invalid value: "every 30m": expected exactly 5 fields, found 2: [every 30m]
spec.schedule: Invalid value: "CRON_TZ=UTC */30 * * * *": cannot use TZ or CRON_TZ in schedule, use timeZone field instead
```

#### W3 · Knobs — which `spec` owns which field

What R3 asks for, written into the generated file in vim (the four lines go right
under the `    spec:` that has **4 spaces** — the Job level):

```yaml
  jobTemplate:
    spec:
      completions: 4               # how many Pods must succeed
      parallelism: 2               # how many run at once
      backoffLimit: 3              # failed retries before the Job is Failed
      activeDeadlineSeconds: 60    # the whole Job's time limit
      template:
        spec:
          restartPolicy: OnFailure # Pod level — OnFailure | Never
```

| Field | Level | Default | Measured on `ckad-v137` |
|---|---|---|---|
| `completions` | Job | 1 | `completions: 4` + `parallelism: 2` → `Running 0/4` with 2 Pods → `Complete 4/4` in 16 s, 4 Pods `Completed` |
| `parallelism` | Job | 1 | see above |
| `backoffLimit` | Job | **6** | `backoffLimit: 1` on `exit 1` → 2 Pods `Error` (1 retry), `Failed`, event `BackoffLimitExceeded` |
| `activeDeadlineSeconds` | Job **and** Pod | none | Job level 10 on `sleep 300` → `FailureTarget` / `DeadlineExceeded` at 10 s, Pod deleted with its 30 s grace, `Failed` at 55 s |
| `ttlSecondsAfterFinished` | Job | none | `5` → the finished Job and its Pod were gone at the next `get jobs` |
| `restartPolicy` | Pod | Job `Never` · CronJob `OnFailure` | `Always` → `restartPolicy: Required value: valid values: "OnFailure", "Never"` |
| `schedule` | CronJob | — | see W2 |
| `concurrencyPolicy` | CronJob | `Allow` | `Forbid` + `*/1` + `sleep 100` → event `JobAlreadyActive: Not starting job because prior execution is running and concurrency policy is Forbid`. Values are case-sensitive: `forbid` → `Unsupported value` |
| `suspend` | CronJob | `false` | `true` → `SUSPEND True` in `get cj`; nothing deleted |
| `timeZone` | CronJob | UTC | `America/Bogota` → `TIMEZONE` column; `Mars/Base` → `unknown time zone Mars/Base` |
| `startingDeadlineSeconds` | CronJob | none | accepted (a missed run older than this is skipped) |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | CronJob | 3 / 1 | accepted |

**The wrong level, measured.** CronJob-level `completions`:
`strict decoding error: unknown field "spec.completions"`. Pod-level `parallelism`:
`strict decoding error: unknown field "spec.template.spec.parallelism"`.
**The silent one:** `activeDeadlineSeconds` under the Pod `spec` is accepted — it then
limits each Pod, not the Job. "The job must be terminated if it runs longer than N
seconds" is the **Job** level.

**Job template is immutable.** `k set image job/slow slow=busybox:1.36` →
`Job.batch "slow" is invalid: spec.template: Invalid value: … field is immutable`. Fix
the file and `k replace --force -f j.yaml` (delete + create in one command).

🔎 Docs: `CronJob` (concept page, the schedule syntax table) · `Jobs` (the
completions/parallelism/backoff sections) · `kubectl explain cronjob.spec` ·
`kubectl explain job.spec` · `kubectl explain cronjob.spec.jobTemplate.spec.activeDeadlineSeconds`.

#### W4 · Run once — `create job --from` (R5, and the "test it" of R3)

```bash
# ▶▶ cp1 — ubuntu@cp1   🎯
k -n NS apply -f cj.yaml
k -n NS create job cj-test --from=cronjob/cj        # cj/cj works too
k -n NS get job,pods                                # 🔍
k -n NS logs job/cj-test                            # 🔍 one Pod's log
```

Measured (completions 4, parallelism 2):

```
job.batch/cj-test   Running    0/4   2s    ← two Pods at once
job.batch/cj-test   Complete   4/4   16s   ← 25 s later
Found 4 pods, using pod/cj-test-lj55z
Sat Nov 21 20:20:30 UTC 2026
```

What `--from` writes — the proof that the Job came from the CronJob, not from
`--image` (graders check exactly this):

```
ownerReferences: [{"kind":"CronJob","name":"cj","controller":true,…}]
annotations:     {"cronjob.kubernetes.io/instantiate":"manual"}
```

A scheduled run, for comparison, is named `<cronjob>-<minutes since the epoch>`
(`tick-29921543`). Measured errors: `--from=cronjob/nope` →
`cronjobs.batch "nope" not found`; the same name twice →
`jobs.batch "cj-test" already exists`.

#### W5 · DaemonSet — convert a Deployment

```bash
# ▶▶ cp1 — ubuntu@cp1   🎯
k -n NS create deployment agent --image=busybox:1.28 $do -- sleep 3600 > ds.yaml
vim ds.yaml     # kind: DaemonSet · delete "replicas:" and "strategy: {}"
k apply -f ds.yaml
k -n NS get ds agent                                # 🔍 DESIRED = number of nodes
```

Measured, `kind` swapped but nothing deleted:

```
DaemonSet in version "v1" cannot be handled as a DaemonSet: strict decoding error: unknown field "spec.replicas", unknown field "spec.strategy"
```

After deleting both lines: `DESIRED 2 · CURRENT 2 · READY 2`, Pods on **w1 and w2
only** — cp1 carries `node-role.kubernetes.io/control-plane:NoSchedule`. When the task
says "every node, including the control plane", add to the Pod `spec`:

```yaml
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
```

Measured: `DESIRED 3`, one Pod on cp1. The leftover `status: {}` is harmless. Fewer
nodes → `nodeSelector` in the Pod `spec`.

#### W6 · StatefulSet — recognise and build the minimum 📚→🎯

```bash
# ▶▶ cp1 — ubuntu@cp1   🎯
k -n NS create service clusterip web --clusterip=None      # headless: no ClusterIP, DNS per Pod
k -n NS create deployment web --image=nginx:1.29 --replicas=2 $do > sts.yaml
vim sts.yaml    # kind: StatefulSet · delete "strategy: {}" · add "serviceName: web" under spec
k apply -f sts.yaml
```

Measured:

```
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          4s      ← ordinal names, created 0 then 1
web-1   1/1     Running   0          3s
$ k run dns --image=busybox:1.28 --rm -i --restart=Never -- nslookup web-0.web
Name:      web-0.web
Address 1: 10.244.190.109 web-0.web.d12-lab.svc.cluster.local
```

`k delete pod web-1` → a new `web-1` (same name) · `k scale sts web --replicas=3` →
`web-2`. `serviceName` is optional in the v1.37 schema, but without it (and the
headless Service) no per-Pod DNS name exists.

**`volumeClaimTemplates`** — one PVC per Pod, named `<template>-<pod>`. Measured on this
lab, which has **no StorageClass**: PVC `data-db-0` `Pending` with
`no persistent volumes available for this claim and no storage class is set`; Pod
`db-0` `Pending` with `pod has unbound immediate PersistentVolumeClaims`. Deleting the
StatefulSet **left the PVC behind**. Provisioning is 1.4's subject.

#### W7 · Prove — what each column tells you

| Command | Columns that matter | Measured values |
|---|---|---|
| `k get cj` | `SCHEDULE TIMEZONE SUSPEND ACTIVE LAST SCHEDULE` | `*/30 * * * *  <none>  False  0  <none>` before any run |
| `k get job` | `STATUS COMPLETIONS DURATION` | `Running` · `Complete` · `Failed` · `FailureTarget` (transient) |
| `k get job X -o jsonpath='{.status.conditions[*].type}'` | condition types | `SuccessCriteriaMet Complete` · `FailureTarget Failed` |
| `k get ds` | `DESIRED CURRENT READY` | `DESIRED` = nodes that tolerate and match |
| `k -n NS events --for job/X` | reasons | `SuccessfulCreate` · `BackoffLimitExceeded` · `SuccessfulDelete` |

### Command card — 1.2

```
CHOOSE   ends? schedule→cj · once→job │ forever: per node→ds · own name/disk→sts · else deploy
GEN      k -n NS create cronjob|job|deployment NAME --image=IMG [--schedule="m h dom mon dow"] $do -- CMD > f.yaml
KNOBS    vim: Job knobs under "    spec:" (completions parallelism backoffLimit activeDeadlineSeconds ttlSecondsAfterFinished)
CJ       spec level: concurrencyPolicy suspend timeZone startingDeadlineSeconds  ·  Pod: restartPolicy OnFailure|Never
CONVERT  ds: kind DaemonSet, delete replicas+strategy (+ cp toleration) · sts: kind StatefulSet + serviceName + svc --clusterip=None
APPLY    k apply -f f.yaml
RUN      k -n NS create job NAME --from=cronjob/CJ
PROVE    k -n NS get cj,job,pods · k -n NS logs job/NAME · k -n NS get ds
FIX      Job template is immutable → edit f.yaml → k replace --force -f f.yaml
```

### Traps

| Error | Cause |
|---|---|
| `strict decoding error: unknown field "spec.completions"` (CronJob) | Job knob at CronJob level — it belongs under `jobTemplate.spec` |
| `unknown field "spec.template.spec.parallelism"` | Job knob at Pod level |
| Grader fails on the time limit, `apply` was fine | `activeDeadlineSeconds` under the Pod `spec` — accepted silently; the task meant the Job |
| `restartPolicy: Required value: valid values: "OnFailure", "Never"` | `Always` (or `--restart=Always`) in a Job or CronJob |
| `error: unknown flag: --restart` | `create job` has no `--restart`; it writes `Never` — change it in vim |
| `expected exactly 5 fields, found 4` | cron expression with a missing field, or words instead of fields |
| `cannot use TZ or CRON_TZ in schedule` | time zone goes in `spec.timeZone`, not in the schedule string |
| CronJob runs once an hour | "every 30 minutes" written as `30 * * * *` instead of `*/30 * * * *` |
| `concurrencyPolicy: Unsupported value: "forbid"` | values are case-sensitive: `Allow` `Forbid` `Replace` |
| `unknown field "spec.replicas", unknown field "spec.strategy"` | Deployment converted to DaemonSet without deleting both lines |
| DaemonSet `DESIRED 2` on a 3-node cluster | control-plane taint — add the toleration when the task says "every node" |
| `jobs.batch "X" already exists` | the manual `--from` run repeated with the same name |
| Job `STATUS FailureTarget` | deadline or backoff hit; the Pod is still in its grace period — becomes `Failed` |
| `spec.template: Invalid value: … field is immutable` | `set image` / edit on a Job's Pod template — `replace --force` |
| PVC `Pending`, Pod `unbound immediate PersistentVolumeClaims` | `volumeClaimTemplates` in a cluster with no StorageClass and no matching PV |

⚠️ **EKS:** the objects are identical. What differs is around them: DaemonSets there
are mostly add-ons you did not write (`aws-node` = VPC CNI, `kube-proxy`,
`ebs-csi-node`), and the control plane is not a node you can see — "every node" never
raises the toleration question. A StatefulSet's `volumeClaimTemplates` bind at once
through the default `gp2`/`gp3` StorageClass (EBS CSI); this vanilla lab has none, so
the PVC stays `Pending`. Fargate profiles do not run DaemonSets at all.

---

## §9. Exam mode — Set 1 · 4 tasks · 17 min

Wording as the CKAD phrases it. **During the clock, read only the task text.** Setup
blocks are untimed and encoded so you cannot read the pre-seeded state; each starts
with its own reset line (delete and recreate the namespace). Graders run on **cp1**
**after** the clock stops and print `PASS`/`FAIL` per check. A FAIL is pasted, not
fixed first.

**Graders verified 21 Nov 2026 on `ckad-v137`**, each against three states: setup
alone (every check FAIL, except "not modified" guards), a correct solution (all PASS)
and a typical wrong one (FAIL caught): T1 `30 * * * *` + manual Job via `--image` +
Pod-level deadline → 4 FAIL · T2 Job from the wrong CronJob, no log file → 2 FAIL ·
T3 no toleration → 2 FAIL · T4 normal ClusterIP Service + Deployment → 5 FAIL.

```
Task 1  (weight 6%)                                            target 6 min
Namespace: d12-reports

Create a CronJob named report-gen that runs every 30 minutes. It uses the image
busybox:1.28 and runs the command: sh -c "date; echo report done"

Each run must:
  - complete successfully 3 times, with at most 2 Pods running at the same time
  - restart failed containers in place
  - be retried at most 2 times before it is considered failed
  - be terminated if it runs longer than 40 seconds

Then test the CronJob without waiting for its schedule: start a run named
report-gen-manual from it and confirm that it completes.
```

🧪 Setup (reset: `kubectl delete ns d12-reports`, then create it):

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEyLXJlcG9ydHMgLS1pZ25vcmUtbm90LWZvdW5kIC0td2FpdD10cnVlID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGNyZWF0ZSBucyBkMTItcmVwb3J0cyA+L2Rldi9udWxsICYmIGVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Ck49ZDEyLXJlcG9ydHM7IEo9J3suc3BlYy5qb2JUZW1wbGF0ZS5zcGVjJwpnKCl7IGt1YmVjdGwgLW4gJE4gZ2V0IGNyb25qb2IgcmVwb3J0LWdlbiAtbyBqc29ucGF0aD0iJDEiIDI+L2Rldi9udWxsOyB9Cm9rICIkKGcgJ3suc3BlYy5zY2hlZHVsZX0nKSIgIiovMzAgKiAqICogKiIgInNjaGVkdWxlIGV2ZXJ5IDMwIG1pbnV0ZXMiCm9rICIkKGcgJ3suc3BlYy5qb2JUZW1wbGF0ZS5zcGVjLnRlbXBsYXRlLnNwZWMuY29udGFpbmVyc1swXS5pbWFnZX0nKSIgImJ1c3lib3g6MS4yOCIgImltYWdlIgpvayAiJChnICIkSi5jb21wbGV0aW9uc30iKSIgIjMiICJjb21wbGV0aW9ucyAzIgpvayAiJChnICIkSi5wYXJhbGxlbGlzbX0iKSIgIjIiICJwYXJhbGxlbGlzbSAyIgpvayAiJChnICIkSi5iYWNrb2ZmTGltaXR9IikiICIyIiAiYmFja29mZkxpbWl0IDIiCm9rICIkKGcgIiRKLmFjdGl2ZURlYWRsaW5lU2Vjb25kc30iKSIgIjQwIiAiYWN0aXZlRGVhZGxpbmVTZWNvbmRzIDQwIChKb2IgbGV2ZWwpIgpvayAiJChnICIkSi50ZW1wbGF0ZS5zcGVjLnJlc3RhcnRQb2xpY3l9IikiICJPbkZhaWx1cmUiICJyZXN0YXJ0UG9saWN5IE9uRmFpbHVyZSIKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgam9iIHJlcG9ydC1nZW4tbWFudWFsIC1vIGpzb25wYXRoPSd7Lm1ldGFkYXRhLm93bmVyUmVmZXJlbmNlc1swXS5raW5kfS97Lm1ldGFkYXRhLm93bmVyUmVmZXJlbmNlc1swXS5uYW1lfScgMj4vZGV2L251bGwpIiAiQ3JvbkpvYi9yZXBvcnQtZ2VuIiAiSm9iIHJlcG9ydC1nZW4tbWFudWFsIGNyZWF0ZWQgZnJvbSB0aGUgQ3JvbkpvYiIKa3ViZWN0bCAtbiAkTiB3YWl0IC0tZm9yPWNvbmRpdGlvbj1jb21wbGV0ZSBqb2IvcmVwb3J0LWdlbi1tYW51YWwgLS10aW1lb3V0PTYwcyA+L2Rldi9udWxsIDI+JjEKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgam9iIHJlcG9ydC1nZW4tbWFudWFsIC1vIGpzb25wYXRoPSd7LnN0YXR1cy5zdWNjZWVkZWR9JyAyPi9kZXYvbnVsbCkiICIzIiAibWFudWFsIHJ1biBjb21wbGV0ZWQgMy8zIgo=' | base64 -d | bash
```

```
Task 2  (weight 3%)                                            target 2 min
Namespace: d12-ops

The CronJob cleanup in namespace d12-ops is scheduled once a day. Run it once now,
as a Job named cleanup-now, without changing the CronJob. Save the output of that
run to /home/ubuntu/cleanup.log.
```

🧪 Setup (reset: `kubectl delete ns d12-ops; rm -f /home/ubuntu/cleanup.log`):

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEyLW9wcyAtLWlnbm9yZS1ub3QtZm91bmQgLS13YWl0PXRydWUgPi9kZXYvbnVsbCAyPiYxOyBybSAtZiAvaG9tZS91YnVudHUvY2xlYW51cC5sb2cKa3ViZWN0bCBjcmVhdGUgbnMgZDEyLW9wcyA+L2Rldi9udWxsCmt1YmVjdGwgLW4gZDEyLW9wcyBjcmVhdGUgY3JvbmpvYiBjbGVhbnVwIC0taW1hZ2U9YnVzeWJveDoxLjI4IC0tc2NoZWR1bGU9IjE1IDMgKiAqICoiIC0tIHNoIC1jICdlY2hvICJjbGVhbnVwOiByZW1vdmVkIDQyIHN0YWxlIGZpbGVzIicgPi9kZXYvbnVsbAprdWJlY3RsIC1uIGQxMi1vcHMgY3JlYXRlIGNyb25qb2IgYXVkaXQgLS1pbWFnZT1idXN5Ym94OjEuMjggLS1zY2hlZHVsZT0iMCAqICogKiAqIiAtLSBzaCAtYyAnZWNobyBhdWRpdCBvaycgPi9kZXYvbnVsbAplY2hvICJzZXR1cCBkb25lIgo=' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Ck49ZDEyLW9wcwpvayAiJChrdWJlY3RsIC1uICROIGdldCBqb2IgY2xlYW51cC1ub3cgLW8ganNvbnBhdGg9J3subWV0YWRhdGEub3duZXJSZWZlcmVuY2VzWzBdLmtpbmR9L3subWV0YWRhdGEub3duZXJSZWZlcmVuY2VzWzBdLm5hbWV9JyAyPi9kZXYvbnVsbCkiICJDcm9uSm9iL2NsZWFudXAiICJKb2IgY2xlYW51cC1ub3cgY3JlYXRlZCBmcm9tIENyb25Kb2IgY2xlYW51cCIKa3ViZWN0bCAtbiAkTiB3YWl0IC0tZm9yPWNvbmRpdGlvbj1jb21wbGV0ZSBqb2IvY2xlYW51cC1ub3cgLS10aW1lb3V0PTYwcyA+L2Rldi9udWxsIDI+JjEKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgam9iIGNsZWFudXAtbm93IC1vIGpzb25wYXRoPSd7LnN0YXR1cy5zdWNjZWVkZWR9JyAyPi9kZXYvbnVsbCkiICIxIiAiY2xlYW51cC1ub3cgY29tcGxldGVkIgpvayAiJChncmVwIC1jICdyZW1vdmVkIDQyIHN0YWxlIGZpbGVzJyAvaG9tZS91YnVudHUvY2xlYW51cC5sb2cgMj4vZGV2L251bGwpIiAiMSIgIi9ob21lL3VidW50dS9jbGVhbnVwLmxvZyBob2xkcyB0aGUgcnVuJ3Mgb3V0cHV0IgpvayAiJChrdWJlY3RsIC1uICROIGdldCBjcm9uam9iIGNsZWFudXAgLW8ganNvbnBhdGg9J3suc3BlYy5zY2hlZHVsZX0nIDI+L2Rldi9udWxsKSIgIjE1IDMgKiAqICoiICJDcm9uSm9iIGNsZWFudXAgbm90IG1vZGlmaWVkIgo=' | base64 -d | bash
```

```
Task 3  (weight 4%)                                            target 4 min
Namespace: d12-infra

Create a DaemonSet named log-agent that runs one Pod on every node of the cluster,
including the control plane node. Use the image busybox:1.28 with the command
sleep 3600. The Pods must carry the label app=log-agent.
```

🧪 Setup (reset: `kubectl delete ns d12-infra`, then create it):

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEyLWluZnJhIC0taWdub3JlLW5vdC1mb3VuZCAtLXdhaXQ9dHJ1ZSA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBjcmVhdGUgbnMgZDEyLWluZnJhID4vZGV2L251bGwgJiYgZWNobyAic2V0dXAgZG9uZSIK' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Ck49ZDEyLWluZnJhOyBub2Rlcz0kKGt1YmVjdGwgZ2V0IG5vZGVzIC0tbm8taGVhZGVycyB8IHdjIC1sKQpvayAiJChrdWJlY3RsIC1uICROIGdldCBkcyBsb2ctYWdlbnQgLW8ganNvbnBhdGg9J3sua2luZH0nIDI+L2Rldi9udWxsKSIgIkRhZW1vblNldCIgIkRhZW1vblNldCBsb2ctYWdlbnQgZXhpc3RzIgpvayAiJChrdWJlY3RsIC1uICROIGdldCBkcyBsb2ctYWdlbnQgLW8ganNvbnBhdGg9J3suc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbMF0uaW1hZ2V9JyAyPi9kZXYvbnVsbCkiICJidXN5Ym94OjEuMjgiICJpbWFnZSIKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgZHMgbG9nLWFnZW50IC1vIGpzb25wYXRoPSd7LnNwZWMudGVtcGxhdGUubWV0YWRhdGEubGFiZWxzLmFwcH0nIDI+L2Rldi9udWxsKSIgImxvZy1hZ2VudCIgIlBvZCBsYWJlbCBhcHA9bG9nLWFnZW50IgpzbGVlcCA1Cm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IGRzIGxvZy1hZ2VudCAtbyBqc29ucGF0aD0ney5zdGF0dXMuZGVzaXJlZE51bWJlclNjaGVkdWxlZH0nIDI+L2Rldi9udWxsKSIgIiRub2RlcyIgIm9uZSBQb2Qgc2NoZWR1bGVkIHBlciBub2RlLCBjb250cm9sIHBsYW5lIGluY2x1ZGVkIgpvayAiJChrdWJlY3RsIC1uICROIGdldCBkcyBsb2ctYWdlbnQgLW8ganNvbnBhdGg9J3suc3RhdHVzLm51bWJlclJlYWR5fScgMj4vZGV2L251bGwpIiAiJG5vZGVzIiAiYWxsICRub2RlcyBQb2RzIFJlYWR5Igo=' | base64 -d | bash
```

```
Task 4  (weight 5%)                                            target 5 min
Namespace: d12-data

A database needs each replica to keep a stable network identity. Create a headless
Service named pg and a workload named pg with 2 replicas of the image nginx:1.29,
governed by that Service, so that the first replica is reachable as pg-0.pg inside
the namespace.
```

🧪 Setup (reset: `kubectl delete ns d12-data`, then create it):

```bash
echo 'a3ViZWN0bCBkZWxldGUgbnMgZDEyLWRhdGEgLS1pZ25vcmUtbm90LWZvdW5kIC0td2FpdD10cnVlID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGNyZWF0ZSBucyBkMTItZGF0YSA+L2Rldi9udWxsICYmIGVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Ck49ZDEyLWRhdGEKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgc3ZjIHBnIC1vIGpzb25wYXRoPSd7LnNwZWMuY2x1c3RlcklQfScgMj4vZGV2L251bGwpIiAiTm9uZSIgIlNlcnZpY2UgcGcgaXMgaGVhZGxlc3MiCm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IHN0cyBwZyAtbyBqc29ucGF0aD0ney5zcGVjLnNlcnZpY2VOYW1lfScgMj4vZGV2L251bGwpIiAicGciICJTdGF0ZWZ1bFNldCBwZyBnb3Zlcm5lZCBieSBTZXJ2aWNlIHBnIgprdWJlY3RsIC1uICROIHJvbGxvdXQgc3RhdHVzIHN0cy9wZyAtLXRpbWVvdXQ9OTBzID4vZGV2L251bGwgMj4mMQpvayAiJChrdWJlY3RsIC1uICROIGdldCBzdHMgcGcgLW8ganNvbnBhdGg9J3suc3RhdHVzLnJlYWR5UmVwbGljYXN9JyAyPi9kZXYvbnVsbCkiICIyIiAiMiByZXBsaWNhcyBSZWFkeSIKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgcG9kcyAtbyBuYW1lIDI+L2Rldi9udWxsIHwgc29ydCB8IHRyICdcbicgJyAnKSIgInBvZC9wZy0wIHBvZC9wZy0xICIgIlBvZHMgbmFtZWQgcGctMCBhbmQgcGctMSIKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgZW5kcG9pbnRzbGljZSAtbCBrdWJlcm5ldGVzLmlvL3NlcnZpY2UtbmFtZT1wZyAtbyBqc29ucGF0aD0ne3JhbmdlIC5pdGVtc1sqXS5lbmRwb2ludHNbKl19eHtlbmR9JyAyPi9kZXYvbnVsbCkiICJ4eCIgIlNlcnZpY2UgcGcgc2VsZWN0cyBib3RoIFBvZHMiCnI9JChrdWJlY3RsIC1uICROIHJ1biBkbnNjaGVjayAtLWltYWdlPWJ1c3lib3g6MS4yOCAtLXJtIC1pIC0tcmVzdGFydD1OZXZlciAtLXF1aWV0IC0tIG5zbG9va3VwIHBnLTAucGcgPC9kZXYvbnVsbCAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ3BnLTAucGcuZDEyLWRhdGEuc3ZjLmNsdXN0ZXIubG9jYWwnKQpvayAiJChbICIkciIgLWdlIDEgXSAmJiBlY2hvIHllcykiICJ5ZXMiICJwZy0wLnBnIHJlc29sdmVzIGluIEROUyIK' | base64 -d | bash
```

**Variations — the same tasks as the exam rewords them:** "a Job that runs 5 Pods in
total, 3 at a time" (completions/parallelism) · "delete finished Jobs automatically
after 2 minutes" (`ttlSecondsAfterFinished: 120`) · "do not start a new run while the
previous one is still running" (`concurrencyPolicy: Forbid`) · "pause the CronJob
without deleting it" (`suspend: true`) · "run the schedule in the Europe/Madrid time
zone" (`timeZone`) · "only on nodes labelled `disk=ssd`" (DaemonSet + `nodeSelector`).

### Run log

| Date | Task | With | Time | Grader | Errors / notes |
|---|---|---|---|---|---|
| | | | | | |
