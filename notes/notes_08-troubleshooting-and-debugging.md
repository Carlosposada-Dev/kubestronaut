---
exams: [KCNA, CKA, CKAD]
domain: Troubleshooting & Debugging
kcna_domains: 2.3 Troubleshooting + 3.2 Debugging
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/tasks/debug/ (debug-application, debug-pods, debug-running-pod, debug-cluster), /concepts/workloads/pods/pod-lifecycle, /tasks/configure-pod-container/configure-liveness-readiness-startup-probes, /reference/kubectl/
template: B
language: en
scope: KCNA ONLY — CKA layer appended from 11 Sep (troubleshooting is CKA's largest domain at 30%)
status: draft
written: 2026-09-05
format: per claude/depth-standard.md AMENDMENT 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). Verified this session — restart backoff sequence 10s→20s→40s→80s→160s, **capped at 300s**, reset after ~10 min of successful running; `maxContainerRestartPeriod` is configurable in KubeletConfiguration (1s–300s).
role: SYNTHESIS NOTE. Every failure here has its mechanism in notes 03–07. This note is the router, not a new subject.
---

# Troubleshooting & Debugging

*Every failure in this note is a mechanism you already studied, seen from the
outside. The skill is not new knowledge — it is knowing which of the five earlier
notes a symptom belongs to.*

KCNA areas 2.3 and 3.2 together ≈ **8–9 of the 60 questions**. On CKA it becomes
the single largest domain at 30%, so nothing written here is spent only once.

---

## 1. Core Concepts

### 1.1 The method — always the same four steps

*Look at the object, read its events, read its logs, then go to the node. In that
order, every time.*

```
1. kubectl get pods -o wide        →  What state? Which node? How many restarts?
2. kubectl describe pod <name>     →  EVENTS, read from the BOTTOM
3. kubectl logs <name> --previous  →  What did the application itself say?
4. node level (crictl, journalctl) →  Only if the first three did not answer it
```

**Step 2 answers most questions**, and the field that matters is not the status —
it is **who emitted the event**:

| Event source | Meaning |
|---|---|
| `default-scheduler` | Not placed yet. A **scheduling** problem — note 03 |
| `kubelet` | Placed, and failing to start or run — note 04, 06, or the app |
| A **controller** | The object was created but its controller objects |
| **No events at all** | Nobody has looked at it. The responsible component is not running |

That last row is the diagnostic gem repeated from note 03 §1.12: silence is
itself a finding.

### 1.2 Pod phases

*Five words describing where the Pod is in its life. Deliberately coarse — the
phase almost never tells you what is wrong.*

`status.phase` is one of exactly five values:

| Phase | Means |
|---|---|
| **`Pending`** | Accepted by the API server, **not all containers running**. Either unscheduled, or scheduled and still starting |
| **`Running`** | Bound to a node, **at least one** container running or starting |
| **`Succeeded`** | **All** containers exited **0** and will not restart. Job territory |
| **`Failed`** | All containers terminated, **at least one** with non-zero exit |
| **`Unknown`** | The node's state cannot be obtained — usually the node is unreachable |

Note the asymmetry that gets tested: `Running` needs **at least one** container
up; `Succeeded` needs **all** of them finished cleanly.

### 1.3 Phase is not container state

*A Pod can be `Running` while its container has crashed forty times. The phase
and the state answer different questions.*

This is the most important distinction in the note. Each **container** has its
own state, independent of the Pod phase:

| Container state | Means | Carries a `reason` |
|---|---|---|
| **`Waiting`** | Not running — pulling, or waiting to retry | **Yes** — `CrashLoopBackOff`, `ImagePullBackOff`, `CreateContainerConfigError` |
| **`Running`** | Executing now | No |
| **`Terminated`** | Finished or was killed | **Yes** — `Completed`, `Error`, `OOMKilled` |

**`CrashLoopBackOff` is not a phase and not a state.** It is a *reason* attached
to the `Waiting` state. The Pod's phase during a crash loop is **`Running`** —
which is why `kubectl get pods` showing `Running` proves nothing on its own, and
why the `READY` and `RESTARTS` columns matter more than `STATUS`.

```
kubectl get pods
NAME    READY   STATUS             RESTARTS      AGE
web-0   0/1     CrashLoopBackOff   7 (2m ago)    23m
        └─┬─┘   └────────┬─────┘   └──┬──┘
          │              │            └── the number that tells the truth
          │              └── a container-state REASON, not the phase
          └── 0 of 1 containers Ready → out of every Service (note 05 §1.7)
```

### 1.4 The status reasons worth memorising

*Each one names a different stage of getting a container running, so the reason
alone tells you where to look.*

| Reason | Stage that failed | Mechanism in | Usual cause |
|---|---|---|---|
| **`ErrImagePull`** | The pull itself, **first attempt** | Note 04 §1.11 | Typo, missing tag, wrong registry, no credentials |
| **`ImagePullBackOff`** | The pull, **now backing off after retries** | Note 04 §1.11 | Same as above — it just gave up faster each time |
| **`CreateContainerConfigError`** | Config assembly, **before** the container starts | Notes 06 §1.3, 07 §1.10 | A referenced **ConfigMap or Secret does not exist** |
| **`CrashLoopBackOff`** | The container started, then **exited repeatedly** | This note §1.6 | App error, bad config, missing dependency, failing liveness probe |
| **`OOMKilled`** | Running, then killed by the kernel | Note 03 §1.11 | Memory **limit** exceeded |
| **`CreateContainerError`** | Container creation | Note 04 | Bad command/entrypoint, runtime problem |
| **`Completed`** | Nothing — it finished | Note 03 §1.7 | Normal for a Job. **A bug for a Deployment** |

**`ImagePullBackOff` vs `CrashLoopBackOff` is the cleanest split in the whole
domain:** with `ImagePullBackOff` the image **never arrived**, so there are no
logs to read. With `CrashLoopBackOff` the image pulled fine and the container ran
— so there **are** logs, and they hold the answer.

### 1.5 Exit codes

*The number the process returned. Anything above 128 means it was killed by a
signal, and the signal number is the code minus 128.*

| Code | Means |
|---|---|
| **0** | Success. Normal for a Job; a bug for a long-running service |
| **1** | Generic application error — read the logs |
| **2** | Misuse of a shell builtin, bad arguments |
| **126** | Command found but **not executable** |
| **127** | **Command not found** — wrong path or missing binary in a minimal image |
| **137** | **128 + 9 = SIGKILL.** Almost always **OOMKilled** |
| **143** | **128 + 15 = SIGTERM.** Graceful shutdown — normal during a rollout |

**127 is a note 04 problem in disguise:** a `scratch` or distroless image has no
shell, so an entrypoint written as a shell command cannot be found. The exit code
tells you it is an image-construction issue, not an application bug.

### 1.6 The restart backoff

*Kubernetes slows down each retry so a crashing container cannot burn the node.
The delay grows, then stops growing at five minutes.*

```
crash → 10s → 20s → 40s → 80s → 160s → 300s → 300s → 300s …
                                        └── capped at 5 minutes
```

Reset rule: after roughly **10 minutes of successful running**, the counter
clears and the next crash starts again at 10s.

Three consequences worth knowing:

- **After you fix the cause, the Pod may sit idle for up to 5 minutes** before
  trying again. Deleting the Pod resets the timer — that is what "it only worked
  after I deleted it" actually means.
- **`RESTARTS` is a more honest signal than `STATUS`.** A container crashing
  every 12 minutes never reaches `CrashLoopBackOff`, because the reset fires
  first. It shows as `Running` all day while restarting dozens of times. Alerting
  on the status misses it entirely; alerting on the restart count does not.
- The cap is configurable per node via `maxContainerRestartPeriod` in the
  KubeletConfiguration (between 1s and 300s).

### 1.7 `kubectl describe` and Events

*The Events block at the bottom is a timeline of what the cluster tried to do to
this object. It is the first thing to read and the most often skipped.*

```bash
kubectl describe pod <name>            # Events are at the BOTTOM
kubectl get events --sort-by=.lastTimestamp          # whole namespace, chronological
kubectl get events --field-selector involvedObject.name=<pod>
kubectl get events -A --sort-by=.lastTimestamp | tail -30
```

Three properties of Events that change how you use them:

| Property | Consequence |
|---|---|
| They are **namespaced objects** | `kubectl get events -n <ns>` — and they show in `kubectl get all`? No, they do not |
| They **expire**, default about **1 hour** | An incident from this morning has already vanished. Capture before you fix |
| They are **not sorted by default** | Always pass `--sort-by=.lastTimestamp` or you will misread the order |

The expiry is why "capture state before changing anything" is a real rule and not
caution theatre: restarting a Pod to "see if it helps" can destroy the only
evidence you had.

### 1.8 `kubectl logs`

*Logs are the application's own account. The flag that matters is the one that
reads the container that already died.*

| Command | Reads |
|---|---|
| `kubectl logs <pod>` | The current container's stdout/stderr |
| `kubectl logs <pod> --previous` | **The previous, crashed instance** |
| `kubectl logs <pod> -c <container>` | A specific container in a multi-container Pod |
| `kubectl logs <pod> -f` | Follow, live |
| `kubectl logs <pod> --tail=50 --timestamps` | Last 50 lines, with times |
| `kubectl logs -l app=web --prefix` | All Pods matching a label |

**`--previous` is the single most valuable flag in the domain.** In a crash loop
the current container is `Waiting`, so plain `kubectl logs` returns nothing
useful or errors out. The output you need belongs to the instance that already
died, and `--previous` is the only way to reach it.

Kubernetes reads whatever the process writes to **stdout/stderr**. An application
logging to a file inside the container is invisible to `kubectl logs` — and the
file dies with the container (note 04 §1.10).

### 1.9 `kubectl exec` and `port-forward`

*One gets you a shell inside a running container; the other brings a port to your
laptop without exposing anything.*

```bash
kubectl exec -it <pod> -- /bin/sh              # a shell inside
kubectl exec -it <pod> -c <container> -- sh    # pick the container
kubectl exec <pod> -- env                      # one command, no shell session
kubectl port-forward pod/<pod> 8080:80         # localhost:8080 → the Pod
kubectl port-forward svc/<svc> 8080:80         # through a Service
```

`exec` requires the **`pods/exec`** subresource in RBAC (note 07 §1.6) and a
shell in the image — neither is guaranteed.

**`port-forward` is the safe way to test a Service** without creating a NodePort
or a LoadBalancer. It also splits a networking problem cleanly: if
`port-forward` to the Pod works but the Service does not, the application is
fine and the fault is in the Service, the selector or the EndpointSlice — note 05
§1.7.

### 1.10 `kubectl debug` and ephemeral containers

*When the image has no shell, you attach a second container that does, into the
same Pod.*

Note 04 §1.13 sold you distroless and `scratch` images for their small attack
surface. The bill comes due here: `kubectl exec -- /bin/sh` fails, because there
is no `/bin/sh` to run.

An **ephemeral container** is added to a **running** Pod for debugging. It has no
restart policy, no probes, no resource guarantees — and it cannot be added to a
Pod spec in advance.

```bash
kubectl debug -it <pod> --image=busybox:1.36 --target=<container>
kubectl debug <pod> -it --image=busybox:1.36 --copy-to=<pod>-debug   # a copy, safer
kubectl debug node/<node> -it --image=busybox:1.36                   # onto a node
```

`--target` puts it in the **same process namespace** as the chosen container, so
you can see and inspect that process. Without `--target` you share only the Pod's
network and volumes.

Why this works when `exec` does not: the tools come from **your** debug image, not
from the application image. The application image stays minimal, which was the
point.

### 1.11 Probes — the three, and what each controls

*All three ask "is this container alright?". They differ entirely in what happens
when the answer is no.*

| Probe | On failure | Controls |
|---|---|---|
| **`livenessProbe`** | **Restarts the container** | Recovery from a hung process |
| **`readinessProbe`** | **Removes the Pod from Service endpoints.** Does not restart | Whether traffic is sent |
| **`startupProbe`** | Kills the container if it never passes | **Disables the other two until it succeeds** |

```
Pod starts
    │
    ├── startupProbe running ──► liveness and readiness are SUSPENDED
    │        │
    │        ▼ passes once
    ├── livenessProbe   → fails → RESTART the container
    └── readinessProbe  → fails → remove from EndpointSlice (note 05 §1.7)
                                  Pod keeps running, gets no traffic
```

| Field | Default | Means |
|---|---|---|
| `initialDelaySeconds` | 0 | Wait before the first check |
| `periodSeconds` | 10 | How often |
| `timeoutSeconds` | 1 | How long a check may take |
| `failureThreshold` | 3 | Consecutive failures before acting |
| `successThreshold` | 1 | Consecutive successes to be considered healthy |

Handler types: `httpGet` (2xx/3xx is success), `tcpSocket` (connection opens),
`exec` (exit code 0), and gRPC.

### 1.12 What misconfigured probes look like

*Probe bugs are the cruellest failures, because the cluster is doing exactly what
you told it to.*

| Misconfiguration | Symptom | Why |
|---|---|---|
| Liveness too aggressive on a **slow-starting** app | **Endless restart loop**, app never finishes booting | Liveness fails during startup and restarts before the app is ready. **The `startupProbe` exists for this** |
| Liveness pointing at a **dependency** (the database) | The app restarts because something **else** is down | Liveness must test *this* container only |
| **Readiness never passes** | Pod `Running`, `READY 0/1`, Service has **no endpoints** | The empty-EndpointSlice failure from note 05 §1.7, seen from the other side |
| **No readiness probe** at all | Traffic reaches Pods that are not ready; errors during every rollout | Nothing removes them from the EndpointSlice |
| `timeoutSeconds` too low | Random restarts under load | A slow response is read as a failure |

The pairing to remember: **liveness restarts, readiness routes.** Using liveness
where you meant readiness turns a slow dependency into an outage, because
restarting never fixes a dependency that is down elsewhere.

### 1.13 Node `NotReady`

*The kubelet stopped saying it was fine. Either it is dead, the node is out of a
resource, or the network plugin is broken.*

| Cause | Check | Note |
|---|---|---|
| **kubelet not running** | `systemctl status kubelet`, `journalctl -u kubelet -f` | The node reports nothing at all |
| **No CNI / CNI broken** | `ls /etc/cni/net.d`, CNI Pods in `kube-system` | Note 05 §1.3 — the fresh-cluster case |
| **Disk pressure** | `kubectl describe node`, `df -h` | Taint `disk-pressure`, eviction follows |
| **Memory / PID pressure** | `kubectl describe node` → Conditions | Taints, then eviction |
| **Runtime down** | `systemctl status containerd`, `crictl ps` | Note 04 §1.9 |
| **Network partition** | Node reachable from your laptop? | `Ready: Unknown`, not `False` |

The consequences are note 03 §1.10 exactly: `Ready: False` produces the
`not-ready` taint, silence produces `unreachable`, and 300 seconds later the Pods
are deleted — while DaemonSet Pods stay, because they tolerate both forever.

**`Ready: False` vs `Ready: Unknown` is a reported illness versus silence.** The
node saying "I am unhealthy" and the node saying nothing at all are different
failures with different first steps.

### 1.14 Telling the four failure classes apart

*Almost every Pod problem is one of four things, and the symptom names which
one — this table is the whole note compressed.*

| Class | Signature symptom | First command | Mechanism note |
|---|---|---|---|
| **Scheduling** | `Pending`, events from `default-scheduler` | `kubectl describe pod` | **Note 03 §1.12** |
| **Image** | `ErrImagePull` / `ImagePullBackOff`, no logs exist | `kubectl describe pod` | **Note 04 §1.11** |
| **Config** | `CreateContainerConfigError`, or a crash on startup | `kubectl describe pod`, then `logs --previous` | **Notes 06 §1.3, 07 §1.10** |
| **Resource** | `OOMKilled`, exit **137**, or throttling | `kubectl describe pod` → Last State | **Note 03 §1.11** |
| **Network** | Pod healthy, connections fail | `kubectl get endpointslice` | **Note 05 §1.7** |
| **Storage** | `Pending` with `unbound … PersistentVolumeClaims` | `kubectl get pvc` | **Note 06 §1.12** |
| **Permissions** | `403` from an application or controller | `kubectl auth can-i --as=…` | **Note 07 §1.2** |

**Mapping this onto the curriculum's own phrasing** — 3.2 asks you to separate
*debugging the app* from *debugging the cluster*, and the seven classes above
divide cleanly:

| Side | Classes | You are looking at | Tools |
|---|---|---|---|
| **The app** | Image, Config, Resource, and the crash itself | The **Pod** and what you shipped: image, env, ConfigMap, limits, code | `kubectl logs`, `describe`, `exec`, `debug` |
| **The cluster** | Scheduling, Node, CNI, control plane | The **infrastructure**: nodes, scheduler, kubelet, network plugin | `kubectl get nodes`, `describe node`, `journalctl -u kubelet`, `crictl` |
| **Crosses both** | Network, Storage, Permissions | A cluster object the app depends on: Service, PVC, RBAC | `get endpointslice`, `get pvc`, `auth can-i` |

**The line to cross is step 4 of §1.1.** While the answer is inside the Pod you
stay in `kubectl`; once you have ruled the Pod out, you go to the node. A Pod
that will not start on **one** node but runs on others is a cluster problem
wearing an app costume — and a Pod failing identically on **every** node is
almost always yours.

The triage question, in order:

```
Is spec.nodeName empty?
├─ yes → SCHEDULING. Read the default-scheduler event.        (note 03)
└─ no  → Is the container Running?
         ├─ no  → what is the Waiting reason?
         │        ├─ ImagePull*        → IMAGE   (note 04)
         │        ├─ CreateContainer*  → CONFIG  (notes 06, 07)
         │        └─ CrashLoopBackOff  → logs --previous, then exit code
         └─ yes → Is it READY?
                  ├─ no  → readiness probe failing → no traffic  (note 05)
                  └─ yes → the app runs. Look at Service, DNS, NetworkPolicy
```

---

## 2. Objects & Fields That Matter

| Object / field | Path | Note |
|---|---|---|
| Pod phase | `status.phase` | The five values; coarse by design |
| Container state | `status.containerStatuses[].state` | `waiting` / `running` / `terminated` |
| Waiting reason | `…state.waiting.reason` | Where `CrashLoopBackOff` actually lives |
| Last termination | `…lastState.terminated.reason` / `.exitCode` | Where `OOMKilled` and 137 appear |
| Restart count | `status.containerStatuses[].restartCount` | More honest than `STATUS` |
| Ready | `status.containerStatuses[].ready` | Drives EndpointSlice membership |
| Probes | `spec.containers[].livenessProbe` / `readinessProbe` / `startupProbe` | Restart / route / delay-the-others |
| Node conditions | `status.conditions` on the Node | `Ready`, `MemoryPressure`, `DiskPressure`, `PIDPressure` |
| Events | `kubectl get events` | Namespaced, **~1 h TTL**, unsorted by default |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 2 (CKA, from 11 Sep) — this is
CKA's largest domain at 30%, so this section will be the biggest in the file.*

---

## 4. Hands-On Lab

Break things deliberately. **Target: 30 minutes.**

```bash
# 1. CrashLoopBackOff — and why plain logs is useless                  (7 min)
kubectl run crasher --image=busybox:1.36 --restart=Always \
  -- sh -c "echo starting; sleep 2; exit 1"
sleep 45
kubectl get pod crasher                     # STATUS CrashLoopBackOff, phase is Running
kubectl logs crasher                        # little or nothing
kubectl logs crasher --previous             # "starting" — the dead instance
kubectl describe pod crasher | grep -A4 "Last State"     # Exit Code: 1

# 2. ImagePullBackOff — note there are NO logs at all                  (5 min)
kubectl run nosuch --image=nginx:doesnotexist-9999
kubectl describe pod nosuch | tail -6       # ErrImagePull → ImagePullBackOff
kubectl logs nosuch                         # error: the container never started

# 3. CreateContainerConfigError — a missing reference                  (5 min)
kubectl run needsconfig --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"needsconfig","image":"nginx",
  "envFrom":[{"configMapRef":{"name":"ghost"}}]}]}}'
kubectl get pod needsconfig                 # CreateContainerConfigError
kubectl describe pod needsconfig | tail -4  # names the missing ConfigMap

# 4. OOMKilled and exit code 137                                       (6 min)
# NOTE: restartPolicy MUST be Always here. With Never the container dies once and
# never restarts, so there is no PREVIOUS run — the result appears under "State:",
# and "Last State:" does not exist at all. Always also demonstrates §1.6's backoff.
kubectl run hungry --image=busybox:1.36 --restart=Always \
  --overrides='{"spec":{"containers":[{"name":"hungry","image":"busybox:1.36",
  "command":["sh","-c","dd if=/dev/zero of=/dev/null bs=200M count=10; sleep 60"],
  "resources":{"limits":{"memory":"32Mi"}}}]}}'
sleep 45
kubectl describe pod hungry | grep -A6 "Last State"      # OOMKilled, Exit Code: 137
kubectl get pod hungry                                   # RESTARTS climbing, backoff visible

# 5. Readiness failing = Running but no endpoints                      (7 min)
kubectl create deployment neverready --image=nginx
kubectl patch deployment neverready --type=json -p='[{"op":"add",
  "path":"/spec/template/spec/containers/0/readinessProbe",
  "value":{"httpGet":{"path":"/nope","port":80},"periodSeconds":5}}]'
sleep 30
kubectl get pods -l app=neverready          # Running, but READY 0/1
kubectl expose deployment neverready --port=80

# The EndpointSlice is NOT empty — a not-ready Pod is LISTED, flagged ready:false.
# kube-proxy simply skips it when programming rules. Check the CONDITION, not the count:
kubectl get endpointslice -l kubernetes.io/service-name=neverready \
  -o jsonpath='{.items[*].endpoints[*].conditions.ready}{"\n"}'    # false
kubectl describe svc neverready | grep -i endpoints    # THIS shows only ready ones

kubectl delete pod crasher nosuch needsconfig hungry --ignore-not-found
kubectl delete deployment neverready; kubectl delete svc neverready
```

---

## 5. Verification

```bash
kubectl get pods -o wide                                   # STATUS, READY, RESTARTS, NODE
kubectl describe pod <p> | grep -A15 Events
kubectl describe pod <p> | grep -A6 "Last State"           # exit code lives here
kubectl logs <p> --previous
kubectl get events --sort-by=.lastTimestamp
kubectl get endpointslice -l kubernetes.io/service-name=<svc>
kubectl get nodes; kubectl describe node <n> | grep -A8 Conditions
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>
```

Capture output **before** you change anything. Events expire in about an hour and
a Pod delete destroys `--previous`.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `Pending`, `default-scheduler` events | Resources, taint, selector, PVC | `kubectl describe pod` | Note 03 §1.12 |
| `Pending`, **no events** | Scheduler not running | `kubectl get pods -n kube-system \| grep sched` | Restart the static Pod |
| `ImagePullBackOff` | Bad tag, registry, or credentials | `kubectl describe pod` | Note 04 §1.11 |
| `CreateContainerConfigError` | Missing ConfigMap/Secret | `kubectl describe pod` | Create the object |
| `CrashLoopBackOff` | App exits non-zero | `kubectl logs --previous` + exit code | Depends on the code |
| Exit **137** | Memory limit hit | `describe` → Last State | Raise the limit (note 03 §1.11) |
| Exit **127** | No shell / binary in a minimal image | `kubectl logs --previous` | Fix the entrypoint (note 04 §1.13) |
| `Running`, `READY 0/1`, no traffic | Readiness failing | `kubectl describe pod` → probe events | Fix the probe or the endpoint |
| Restart loop on a slow-booting app | Liveness fires during startup | `kubectl describe pod` | Add a `startupProbe` |
| Restarts but `STATUS` never shows CrashLoop | Crashing slower than the 10-min reset | `RESTARTS` column | Watch the count, not the status |
| `kubectl exec` fails, no shell | distroless/scratch image | `kubectl exec -- ls` fails too | `kubectl debug` |
| `kubectl logs` empty on a healthy app | App logs to a file, not stdout | `kubectl exec -- ls /var/log` | Log to stdout |
| Node `NotReady` | kubelet, CNI, disk, runtime | `journalctl -u kubelet` | §1.13 |
| Everything worked an hour ago, no events remain | Event TTL (~1 h) | — | Capture earlier next time |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| A node goes `NotReady` | The managed node group **replaces the instance automatically**. The problem disappears before you diagnose it | **Nothing replaces anything.** The node stays broken until you fix it, and fixing it is the exercise |
| Reaching the node | You mostly do not — CloudWatch and SSM instead of SSH | **You SSH in and use `journalctl -u kubelet` and `crictl`.** Expected, not exceptional |
| Logs | Often shipped to CloudWatch and kept for weeks | `kubectl logs` only, and it dies with the container. **`--previous` is one instance deep** |
| Historical evidence | CloudWatch and CloudTrail keep it | **Events expire in ~1 hour.** If you did not capture it, it is gone |
| Image pull failures | Usually IAM/ECR or a VPC endpoint | Usually the tag, DNS, or a missing `imagePullSecret` |
| Debugging the control plane | **Impossible — it is AWS's** | `crictl ps`, static Pod manifests, `journalctl`. It is yours to inspect |

The habit to unlearn: on EKS, a sick node heals itself and the evidence lives in
CloudWatch. On the exam nothing heals, nothing is archived, and a Pod deleted in
haste takes the only logs with it.

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 2.*

---

## 9. Objectives Covered

KCNA areas **2.3 Troubleshooting** and **3.2 Debugging**.

- [ ] The five Pod phases and what each asserts
- [ ] Container states vs phase; where `CrashLoopBackOff` actually lives
- [ ] `ImagePullBackOff`, `ErrImagePull`, `OOMKilled`, `CreateContainerConfigError`
- [ ] Exit codes 0, 1, 126, 127, 137, 143
- [ ] The restart backoff sequence and its reset rule
- [ ] `kubectl describe` → Events as the first step; the event **source**
- [ ] `kubectl logs`, `--previous`, `-c`
- [ ] `kubectl exec`, `port-forward`
- [ ] Ephemeral containers / `kubectl debug`, and why `exec` fails on distroless
- [ ] Reading namespace events sorted by time; the ~1 h TTL
- [ ] Probes: liveness / readiness / startup, and what each does on failure
- [ ] What misconfigured probes look like
- [ ] Node `NotReady`: kubelet, CNI, disk, runtime
- [ ] Telling image / config / resource / network failures apart

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "`CrashLoopBackOff` is a Pod phase" | It is a **`Waiting` state reason**. The phase is `Running` |
| "A `Running` Pod is healthy" | `Running` means ≥1 container started. Read **READY** and **RESTARTS** |
| "`kubectl logs` shows why it crashed" | In a crash loop you need **`--previous`** |
| "`ImagePullBackOff` — check the logs" | The container **never started**. There are no logs |
| "Exit code 137 means the app returned 137" | **128 + 9 = SIGKILL.** The kernel killed it — usually OOM |
| "A failing liveness probe removes the Pod from the Service" | Liveness **restarts**. **Readiness** removes it from endpoints |
| "A failing readiness probe restarts the container" | It does not restart anything |
| "`startupProbe` runs alongside the others" | It **suspends** liveness and readiness until it passes |
| "Deleting the Pod fixed it" | It reset the **backoff timer**. The cause is still there |
| "No `CrashLoopBackOff` means no restarts" | The backoff resets after ~10 min. Watch **RESTARTS** |
| "Events are permanent" | They expire in about **an hour** |
| "`kubectl get events` is chronological" | **Unsorted** unless you pass `--sort-by=.lastTimestamp` |
| "`kubectl exec` always gives a shell" | Not on distroless or `scratch`. Use `kubectl debug` |
| "Ephemeral containers can be declared in the Pod spec" | They are added to a **running** Pod only |
| "`Succeeded` means it is working" | For a Deployment it means the container **exited** — a bug |
| "`Ready: False` and `Ready: Unknown` are the same" | Reported illness vs **silence**. Different taints |

**X ≠ Y**

- **Pod phase ≠ container state** — five coarse words vs waiting/running/terminated
- **`CrashLoopBackOff` ≠ a phase** — it is a `Waiting` reason
- **`ImagePullBackOff` ≠ `CrashLoopBackOff`** — never started vs started and died
- **`ErrImagePull` ≠ `ImagePullBackOff`** — first failure vs backing off
- **liveness ≠ readiness** — restarts vs removes from endpoints
- **readiness ≠ startup** — routes traffic vs suspends the other two
- **`logs` ≠ `logs --previous`** — the live container vs the one that died
- **`exec` ≠ `debug`** — needs a shell in the image vs brings its own
- **`Running` ≠ `Ready`** — started vs receiving traffic
- **137 ≠ 143** — SIGKILL (OOM) vs SIGTERM (graceful)
- **`Ready: False` ≠ `Ready: Unknown`** — `not-ready` taint vs `unreachable`
- **Event ≠ log** — what the cluster did vs what the app said

---

## 10. Active Recall

Closed book, out loud. 19 questions.

1. Name the five Pod phases and what each asserts. Which needs *all* containers
   and which needs only *one*?
2. A Pod shows `CrashLoopBackOff`. What is its actual phase, and what is
   `CrashLoopBackOff` technically?
3. Name the three container states and which two carry a reason.
4. Give the four steps of the debugging method, in order.
5. In `kubectl describe`, why is the event **source** more useful than the event
   text? Name three sources and what each implies.
6. What does it mean when a Pod has **no events at all**?
7. Distinguish `ImagePullBackOff` from `CrashLoopBackOff`. In which can you read
   logs, and why not in the other?
8. What does `CreateContainerConfigError` almost always mean?
9. Give the meaning of exit codes 0, 1, 127, 137 and 143. What is the rule for
   any code above 128?
10. Why would a container in a minimal image exit 127, and which note does that
    belong to?
11. Recite the restart backoff sequence and its cap. When does it reset?
12. A container restarts 40 times a day but never shows `CrashLoopBackOff`.
    Explain how, and which column you should have watched.
13. Which `kubectl logs` flag matters most in a crash loop, and why is the plain
    command useless there?
14. An app logs to `/var/log/app.log`. Why does `kubectl logs` show nothing, and
    what happens to that file when the container dies?
15. Name the three probes and exactly what each does on failure.
16. An app takes 90 seconds to boot and is stuck in a restart loop. Which probe
    is misconfigured, which probe fixes it, and how?
17. Readiness never passes. Describe the full chain of consequences down to the
    Service.
18. `kubectl exec -- /bin/sh` fails on a distroless image. What do you use, and
    why does it work when `exec` does not?
19. A node is `NotReady`. Name four possible causes, and say which produces
    `Ready: False` versus `Ready: Unknown`.

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — Four Pods, four different failures

One namespace, four broken Pods:

- `alpha` — `Pending`, no events at all
- `beta` — `Running`, `READY 0/1`, `RESTARTS 0`
- `gamma` — `Running`, `READY 0/1`, `RESTARTS 14`
- `delta` — `ImagePullBackOff`

a. Classify each by failure class and name the note that holds its mechanism.
b. For each, give the **single** command you would run first, and say what you
   expect it to show.
c. `beta` and `gamma` look nearly identical in `kubectl get pods`. Which column
   separates them, and what does that difference tell you about which probe is
   involved in each?
d. For `delta`, a colleague asks for the logs. Explain why that request cannot be
   satisfied, using the container lifecycle.
e. `gamma`'s last exit code is 137. Name the cause, the field where you found it,
   and which of the four classes it belongs to.
f. Rank the four by how quickly you could resolve each, and justify the ordering
   by how much information the symptom already gives you.

### Drill 2 — The fix that did not take

A Pod is in `CrashLoopBackOff` because of a typo in an environment variable. You
correct the Deployment. Five minutes later the Pod still shows
`CrashLoopBackOff`, `RESTARTS 9`.

a. Name two independent reasons the Pod might still look broken, only one of
   which is a real problem.
b. Explain the timing precisely: with 9 restarts, how long is the current wait?
   Recite the sequence.
c. Someone deletes the Pod and it comes up healthy, concluding "deleting fixed
   it". Correct that conclusion — what did the delete actually do?
d. Correcting a Deployment should have created a new Pod anyway. Explain what
   should have happened via the ownership chain from note 03 §1.3–§1.4, and what it
   would mean if the old Pod is still there.
e. Before deleting, what should have been captured, and why does the ~1 hour
   event TTL make that urgent?

### Drill 3 — The probe that caused the outage

A service is fine for weeks. The database has a slow morning: queries take 8
seconds instead of 200 ms. Within minutes **every** replica of the app is
restarting, and the outage is total — worse than the slow database alone.

a. The app has `livenessProbe` on `/health`, which queries the database. Explain
   the exact mechanism that turned a slow dependency into a total outage.
b. Which probe should have been on that endpoint instead? Describe what would
   have happened differently, step by step, down to the EndpointSlice.
c. With the correct probe, would users have seen errors? Explain what "no healthy
   endpoints" looks like to a client versus "restarting Pods".
d. The restarts made the database **worse**. Explain that feedback loop —
   what does each restarting replica do to a struggling database on boot?
e. Name the three concrete changes you would make: one to the probe type, one to
   what the endpoint tests, one to the probe timing fields.
f. Explain why a `startupProbe` would not have prevented this, being precise
   about which phase of the Pod's life each probe governs.

### Drill 4 — A node at 3 a.m.

`w2` is `NotReady`. On it were 4 Deployment Pods, 1 DaemonSet Pod, and a
StatefulSet Pod `db-1` with a bound PVC.

a. Name four possible causes, and for each the one command that confirms it.
b. `kubectl describe node w2` shows `Ready: Unknown`, not `False`. What does that
   distinguish, and which taint follows?
c. Build the timeline: at what point are the Deployment Pods deleted, which
   admission controller set that delay, and which controller performs the
   deletion?
d. The DaemonSet Pod is never evicted. Explain why, and why that is deliberate
   for a node you are trying to diagnose.
e. `db-1`'s replacement is `Pending`. Give two independent reasons, one from
   note 03 and one from note 06.
f. You SSH to `w2`. `kubectl` does not work there. Name the two node-level
   commands you would run, what each inspects, and why neither needs a working
   API server.
g. On EKS this node would have been replaced automatically before you woke up.
   Name what you would have gained and what you would have permanently lost.
