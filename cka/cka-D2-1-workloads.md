---
domain: D2 — Workloads and Scheduling
group: 1 — Run & Configure the Application
bullets: [2.1, 2.2, 2.4]
exams: [CKA, CKAD]
index: cka-D2.md
theory: notes_03, notes_02, notes_07
status: 2.1 guided pass done (Template C, measured); 2.2 + 2.4 r1 skeleton
revision: 2026-11-09 (r2 — 2.1 migrated to Template C from the 8–9 Nov guided pass on lab-v137; §9 R1 setup + grader) · 2026-11-02 (r1 — split out of `cka-D2.md` r1; text unchanged except two counts fixed and a stale date removed) — migrated to Template C the day each bullet is worked
---

# D2 · Group 1 — Run & Configure the Application (bullets 2.1, 2.2, 2.4)

> Index, drill table and scoreboard: **`cka-D2.md`**.
> Legend, typing conventions and lab-vs-exam node moves: **`cka-D1-2-lifecycle.md`** (reference implementation).
>
> What unites these three: one Deployment, from creation to a safe rollout — how it
> rolls (2.1), what it is configured with (2.2), and how it stays healthy and
> protected while nodes are drained (2.4). All of them run on **cp1** with `kubectl`.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 2.1 rollouts · 2.2 ConfigMaps & Secrets · 2.4 probes + PDB

---

## 2.1 Deployments, rolling updates and rollbacks ⚙️

**Runs on: cp1.** · **Theory →** notes_03 §1.4–1.6 · **Docs →** search `deployment` →
"Updating a Deployment" / "Rolling Back" / "Pausing and Resuming" / "Strategy" /
"Clean up Policy" · **Target: 4:00**

> Migrated to Template C on 9 Nov from the guided pass on `lab-v137` (ns `d21`), with
> every output below measured on cp1 on 8–9 Nov.

### The shape

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | Create the Deployment imperatively, prove it with `rollout status` | One line, 20 s; `rollout status` blocks until done — it *is* the proof | 🎯 |
| 2 | Change the image with `set image`, record the change-cause | Every template change = a new ReplicaSet = a new revision | 🎯 |
| 3 | Read the history and one revision's template | Find the revision to go back to — by image, not by guessing the number | 🎯🔍 |
| 4 | Roll back: previous (`undo`) or named (`--to-revision=N`) | Re-scales an old RS and **renumbers** it | 🎯 |
| 5 | Pause, make several changes, resume | Several changes, one rollout, one revision | 🎯 |
| 6 | Strategy: `maxSurge` / `maxUnavailable` / `Recreate` | **No flag exists** → `edit` (or `$do > f.yaml`) | 🎯 |
| 7 | History lives in the RSs: delete one or lower `revisionHistoryLimit` | The rollback target disappears | 🎯📚 |

### The whiteboard

**The model every trap below comes from.** A Deployment does not run Pods. It owns
**ReplicaSets**, one per distinct **pod template** (the RS name carries
`pod-template-hash`). A change to the template (image, env, resources, probes…)
creates a new RS = a new **revision**; a change outside it (`replicas`, `strategy`,
`revisionHistoryLimit`, `paused`) does not. A rolling update scales the new RS up and
the old one down; a rollback scales an old RS up again. **The history is the set of
RSs that still exist** — one row per RS, numbered by a counter that only grows.

**Step 1 — create and prove**

```bash
# ▶▶ cp1 🎯
k create ns d21
k -n d21 create deployment web --image=nginx:1.27 --replicas=3      # or … $do > d.yaml; k apply -f d.yaml
k -n d21 rollout status deployment web                               # deployment "web" successfully rolled out
k -n d21 get deploy,rs -o wide                                       # 🔍 RS web-69c6f74b8b … pod-template-hash=69c6f74b8b
```

The container name comes from the image without its tag (`nginx`); `create deployment`
adds the label `app=web`. Generating with `-n d21 … $do > d.yaml` writes
`namespace: d21` into the file, so `apply` without `-n` lands in `d21`. If `rollout
status` sits on `0 of 3 updated replicas are available`, the Pods are not starting —
Ctrl-C and read `get pods` / events.

**Step 2 — new image + change-cause**

```bash
# ▶▶ cp1 🎯
k -n d21 set image deployment web nginx=nginx:1.28                  # <CONTAINER>=<IMAGE>
k -n d21 annotate deployment web kubernetes.io/change-cause="image to 1.28" --overwrite
k -n d21 rollout status deployment web
```

`set image … web=nginx:1.28` → `error: unable to find container named "web"` (the
container is `nginx`; `get deploy -o wide` → `CONTAINERS`). `--record` still works in
1.37 but prints `Flag --record has been deprecated`. **The annotation stays on the
Deployment and is stamped on the next revision**: on 8 Nov a later `nginx:1.999`
revision showed `image to 1.28`. One `annotate` per change, or the history lies.

The `set` family — each one changes the template, so each one makes a revision:
`set image` (2.1) · `set env … K=V` / `--from=configmap/CM` (2.2) ·
`set resources … --requests=cpu=50m --limits=memory=128Mi` (2.5) · `set serviceaccount` (1.1).

**Step 3 — history and one revision**

```bash
# ▶▶ cp1 🎯
k -n d21 rollout history deployment web                             # REVISION  CHANGE-CAUSE
k -n d21 rollout history deployment web --revision=1                # full pod template: Image: nginx:1.27
k -n d21 describe rs | grep -E 'Name:|revision:|Image:'             # 🔍 RS ↔ revision ↔ image, all at once
```

`rollout` works on `deployment` / `daemonset` / `statefulset` only — never on `rs`.
`revisionHistoryLimit` defaults to **10 old RSs** + the current one.

**Step 4 — rollback (measured, ns `d21`)**

```bash
# ▶▶ cp1 🎯
k -n d21 rollout undo deployment web                                # previous revision
k -n d21 rollout undo deployment web --to-revision=2                # named revision
k -n d21 get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

| Moment | RS `…69c6` (1.27) | RS `…6f9b` (1.28) | Image |
|---|---|---|---|
| create | **rev 1** | — | 1.27 |
| `set image` 1.28 | 1 | **rev 2** | 1.28 |
| `undo` | **rev 3** (1 disappears) | 2 | 1.27 |
| `undo --to-revision=2` | 3 | **rev 4** (2 disappears) | 1.28 |

No RS is created by a rollback; the target gets the next number and keeps its own
change-cause. `describe rs` then shows `deployment.kubernetes.io/revision-history: 1`
— the numbers that RS carried before. Two plain `undo` toggle between the last two.
A Deployment created with `apply` prints a harmless `last-applied-configuration`
warning on every `undo`.

**Step 5 — pause / resume (one rollout for several changes)**

```bash
# ▶▶ cp1 🎯
k -n d21 rollout pause deployment web
k -n d21 set image deployment web nginx=nginx:1.29
k -n d21 set resources deployment web --requests=cpu=50m
k -n d21 annotate deployment web kubernetes.io/change-cause="1.29 + cpu request" --overwrite
k -n d21 rollout resume deployment web
k -n d21 rollout status deployment web
k -n d21 rollout history deployment web --revision=5 | grep -E 'Image|cpu'   # nginx:1.29 + cpu: 50m, same revision
```

While paused: no new RS, `rollout status` waits forever (`0 out of 3 new replicas have
been updated...`), and `undo` is refused: `you cannot rollback a paused deployment;
resume it first`. A forgotten `resume` leaves the task half done although every `set`
said `updated`.

**Step 6 — strategy (not imperative)**

```bash
# ▶▶ cp1 🎯
k -n d21 edit deployment web                                        # existing Deployment
k -n d21 get deploy web -o jsonpath='{.spec.strategy}'; echo        # 🔍 {"rollingUpdate":{"maxSurge":1,"maxUnavailable":0},"type":"RollingUpdate"}
```

```yaml
  strategy:                 # new Deployment: $do > f.yaml, replace `strategy: {}`
    rollingUpdate:
      maxSurge: 1           # extra Pods above replicas — % rounds UP   (25% of 3 → 1)
      maxUnavailable: 0     # Pods allowed missing      — % rounds DOWN (25% of 3 → 0)
    type: RollingUpdate     # Recreate = kill all, then create: delete the 3 rollingUpdate lines
```

Measured: with defaults and 3 replicas, a bad image gives 1 new Pod in `ErrImagePull`
and the 3 old ones keep serving. `maxSurge: 0` + `maxUnavailable: 0` →
`may not be 0 when maxSurge is 0`. `maxUnavailable: 0` costs room for the surge Pod —
no room (resources, quota) and the rollout stalls without removing an old Pod.
`type: Recreate` with `rollingUpdate` left in → `kubectl edit` reopens the buffer with
`# * spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy type is
'Recreate'` — fix it **there**; quitting unchanged gives `Edit cancelled, no valid
changes were saved` and the `/tmp/kubectl-edit-*.yaml` copy later fails `replace` with
`Conflict`. Recreate proof: right after `set image`, every Pod belongs to the new RS
(`ContainerCreating`), none of the old one. Strategy changes create no revision.

**Step 7 — the history lives in the RSs**

```bash
# ▶▶ cp1 🎯📚
k -n d21 delete rs web-69c6f74b8b                                   # an OLD RS (0 replicas)
k -n d21 rollout undo deployment web --to-revision=3                # error: unable to find specified revision 3 in history
k -n d21 edit deployment web                                        # revisionHistoryLimit: 1 → old RSs pruned at once, silently
```

Measured: limit 1 on a Deployment with 3 revisions → 2 RSs (current + 1 old) within
3 s, `history` shows only the last two. The only way back to a lost image is
`set image`, which makes a new revision. Never delete the **active** RS: the
Deployment recreates it and restarts every Pod.

### Command card — 2.1

```bash
k -n NS create deploy D --image=IMG --replicas=N [$do > d.yaml]; k -n NS rollout status deploy D
k -n NS set image deploy D CONTAINER=IMG; k -n NS annotate deploy D kubernetes.io/change-cause="TXT" --overwrite   # container = get deploy -o wide
k -n NS rollout history deploy D [--revision=N]; k -n NS describe rs | grep -E 'Name:|revision:|Image:'
k -n NS rollout undo deploy D [--to-revision=N]                 # read history right before: rollback renumbers
k -n NS get deploy D -o jsonpath='{.spec.template.spec.containers[0].image}'   # -o + jsonpath= + '{.
k -n NS rollout pause deploy D; …set image / set resources --requests=… / annotate…; k -n NS rollout resume deploy D
k -n NS edit deploy D      # strategy.rollingUpdate.{maxSurge,maxUnavailable} · Recreate = 3dd rollingUpdate · revisionHistoryLimit
k -n NS get deploy D -o jsonpath='{.spec.strategy}'; k -n NS get rs   # proof for non-template fields
k -n NS scale deploy D --replicas=N                             # no new revision
```

### Traps

| Error | Cause |
|---|---|
| `unable to find container named "web"` | `set image` takes the **container** name, not the Deployment's |
| History shows a change-cause on the wrong revision | The annotation stays on the Deployment and is copied to the next revision — re-annotate every change |
| `--to-revision=N` lands on the wrong image | An earlier `undo` renumbered the history; read `history` right before |
| `you cannot rollback a paused deployment` | `rollout resume` first |
| `rollout status` never ends | Deployment paused, or Pods not starting (`get pods`, events) |
| `unknown flag: --request` | `--requests` / `--limits`, plural |
| `unrecognized identifier spec` + a huge dump | jsonpath without the leading dot: `'{.spec…}'` — read only the first line |
| `deployments.apps "jsonpath=…" not found` | `-o` missing: the jsonpath was taken as a second name |
| `replicasets.apps "web" not found` on `get deploy,rs web` | The name applies to every type in the list; RSs are `web-<hash>` |
| `flags cannot be placed before plugin name: -n` | `-n` without its value: it ate `get` |
| `rollingUpdate: Forbidden … 'Recreate'` | Delete the `rollingUpdate` block when switching to Recreate |
| `maxUnavailable … may not be 0 when maxSurge is 0` | One of the two must allow movement |
| `unable to find specified revision N in history` | That RS was deleted, or pruned by `revisionHistoryLimit` |

⚠️ **EKS:** the object and every command are identical. Day to day the image change
arrives through a pipeline (Helm/Terraform/Argo CD), so `change-cause` is rarely seen
and `revisionHistoryLimit` is often lowered by tooling. With the VPC CNI a surge Pod
can also stall on subnet IP exhaustion — a limit kubeadm + Calico does not have.

---

## 2.2 ConfigMaps and Secrets ✍️

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §2.x, notes_07 · **Docs →** search `configmap` /
`secret` · **Target: 4 min**

Must contain: the three imperative sources (`--from-literal`, `--from-file`,
`--from-env-file`), the three Secret types you can create imperatively
(`generic`, `docker-registry`, `tls`), consuming as **env var** vs **envFrom**
vs **mounted volume**, and how to read a Secret's value back in clear text.

**The distinction the exam actually tests:** a mounted ConfigMap updates in the
Pod (eventually, via the kubelet sync); an `env:` value does **not** — it is
fixed at container start. Know which one the task needs.

**Trap:** Secret data is base64, **not encryption**. `kubectl get secret x -o
jsonpath='{.data.key}' | base64 -d`.

```
(your runbook here)
```

---

## 2.4 Primitives for robust, self-healing deployments ✍️ — includes PDB

> r1 text — migrated to Template C the day it is worked.

**Theory →** notes_03 §1.x + **the PDB block queued since Block 1 goes here, not
in the note** · **Docs →** search `disruption` / `liveness readiness` ·
**Target: 5 min**

Must contain:

- the three probes: liveness (restart), readiness (remove from EndpointSlice),
  startup (suspend the other two while a slow app boots) — and the fields
  `initialDelaySeconds`, `periodSeconds`, `failureThreshold`
- **PodDisruptionBudget**: `minAvailable` vs `maxUnavailable`, the imperative
  creation line, and the proof — `kubectl drain` **blocks** when the budget
  would be violated
- restart policies and what a DaemonSet/StatefulSet guarantees that a Deployment
  does not

**Three traps from your amendment queue:**
- A Pod with **no readiness probe** is Ready the moment the container starts →
  it enters the EndpointSlice immediately and serves 1/N of the 503s.
- A not-ready Pod **stays** in the EndpointSlice with `ready: false`; it is not
  removed from the object.
- PDBs guard **voluntary** disruptions only (drain, eviction API). A node that
  dies ignores them completely.

```
(your runbook here)
```

---

## §9. Exam mode — Set 1 (workloads)

> Tasks in CKA wording; 🧪 setup and 🔍 grader base64-encoded, run from cp1. Every
> grader is verified against the setup alone, a correct solution and a typical wrong
> one before it is used. Before the first command: copy the task's literals into
> shell variables.

### R1 — rollout + strategy + rollback (row 1 of `cka-D2.md §7`, target 4:00)

Grader verified 9 Nov: setup alone 2/6 (the two baseline checks), correct solution
**6/6**, typical wrong (plain `undo`, change-cause typo, `maxSurge` only) 3/6. Setup
resets the `orders` namespace. Trap built in: the container is **not** called `nginx`.

```
Task  (weight 6%)                                             target 4 min
In namespace orders, the Deployment checkout is running.
1. Update the Deployment to use the image nginx:1.29 and record the change cause
   "upgrade to 1.29" so that it appears in the rollout history. Wait for the rollout
   to complete.
2. Configure the Deployment's rolling update so that no Pod is ever unavailable during
   an update and at most 2 additional Pods are created.
3. Roll the Deployment back to the revision that runs the image nginx:1.27.
```

```bash
# 🧪 setup R1 (cp1)
echo 'a3ViZWN0bCBkZWxldGUgbnMgb3JkZXJzIC0taWdub3JlLW5vdC1mb3VuZCAtLXdhaXQ9dHJ1ZSA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBjcmVhdGUgbnMgb3JkZXJzID4vZGV2L251bGwKa3ViZWN0bCAtbiBvcmRlcnMgY3JlYXRlIGRlcGxveW1lbnQgY2hlY2tvdXQgLS1pbWFnZT1uZ2lueDoxLjI3IC0tcmVwbGljYXM9MyAtLWRyeS1ydW49Y2xpZW50IC1vIHlhbWwgfCBzZWQgJ3MvXlwoICpcKW5hbWU6IG5naW54JC9cMW5hbWU6IGFwcC8nIHwga3ViZWN0bCBjcmVhdGUgLWYgLSA+L2Rldi9udWxsCmt1YmVjdGwgLW4gb3JkZXJzIHJvbGxvdXQgc3RhdHVzIGRlcGxveW1lbnQgY2hlY2tvdXQgLS10aW1lb3V0PTE4MHMgPi9kZXYvbnVsbAprdWJlY3RsIC1uIG9yZGVycyBzZXQgaW1hZ2UgZGVwbG95bWVudCBjaGVja291dCBhcHA9bmdpbng6MS4yOCA+L2Rldi9udWxsCmt1YmVjdGwgLW4gb3JkZXJzIHJvbGxvdXQgc3RhdHVzIGRlcGxveW1lbnQgY2hlY2tvdXQgLS10aW1lb3V0PTE4MHMgPi9kZXYvbnVsbAplY2hvICJzZXR1cCBkb25lIgo=' | base64 -d | bash
# 🔍 grader R1 (cp1, after the clock)
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Ck49b3JkZXJzOyBEPWNoZWNrb3V0Cm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IHJzIC1vIGpzb25wYXRoPSd7cmFuZ2UgLml0ZW1zWypdfXsuc3BlYy50ZW1wbGF0ZS5zcGVjLmNvbnRhaW5lcnNbMF0uaW1hZ2V9eyJ8In17Lm1ldGFkYXRhLmFubm90YXRpb25zLmt1YmVybmV0ZXNcLmlvL2NoYW5nZS1jYXVzZX17IlxuIn17ZW5kfScgMj4vZGV2L251bGwgfCBncmVwIC1jICdebmdpbng6MS4yOXx1cGdyYWRlIHRvIDEuMjkkJykiICIxIiAidGhlIG5naW54OjEuMjkgcmV2aXNpb24gcmVjb3JkcyBjaGFuZ2UtY2F1c2UgJ3VwZ3JhZGUgdG8gMS4yOSciCm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IGRlcGxveSAkRCAtbyBqc29ucGF0aD0ney5zcGVjLnN0cmF0ZWd5LnR5cGV9JyAyPi9kZXYvbnVsbCkiICJSb2xsaW5nVXBkYXRlIiAic3RyYXRlZ3kgdHlwZSBpcyBSb2xsaW5nVXBkYXRlIgpvayAiJChrdWJlY3RsIC1uICROIGdldCBkZXBsb3kgJEQgLW8ganNvbnBhdGg9J3suc3BlYy5zdHJhdGVneS5yb2xsaW5nVXBkYXRlLm1heFVuYXZhaWxhYmxlfScgMj4vZGV2L251bGwpIiAiMCIgIm1heFVuYXZhaWxhYmxlIGlzIDAiCm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IGRlcGxveSAkRCAtbyBqc29ucGF0aD0ney5zcGVjLnN0cmF0ZWd5LnJvbGxpbmdVcGRhdGUubWF4U3VyZ2V9JyAyPi9kZXYvbnVsbCkiICIyIiAibWF4U3VyZ2UgaXMgMiIKb2sgIiQoa3ViZWN0bCAtbiAkTiBnZXQgZGVwbG95ICREIC1vIGpzb25wYXRoPSd7LnNwZWMudGVtcGxhdGUuc3BlYy5jb250YWluZXJzWzBdLmltYWdlfScgMj4vZGV2L251bGwpIiAibmdpbng6MS4yNyIgIkRlcGxveW1lbnQgcnVucyBuZ2lueDoxLjI3IGFnYWluIChyb2xsZWQgYmFjaykiCm9rICIkKGt1YmVjdGwgLW4gJE4gZ2V0IGRlcGxveSAkRCAtbyBqc29ucGF0aD0ney5zcGVjLnJlcGxpY2FzfS97LnN0YXR1cy51cGRhdGVkUmVwbGljYXN9L3suc3RhdHVzLnJlYWR5UmVwbGljYXN9JyAyPi9kZXYvbnVsbCkiICIzLzMvMyIgInJvbGxvdXQgY29tcGxldGU6IDMgcmVwbGljYXMgdXBkYXRlZCBhbmQgcmVhZHkiCg==' | base64 -d | bash
```

| R1 run | Date | Score | Time | Notes |
|---|---|---|---|---|
