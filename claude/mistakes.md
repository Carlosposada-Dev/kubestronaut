# mistakes.md — Error log

> `plan.md §6`: **no session ends without this file being updated.**
> A day with nothing to record here means you did not test yourself hard enough.

## How to fill it

One row per error **understood**, not per question missed. The column that
matters is *Root cause*: "I didn't know" is a useless answer. Real causes are
almost always one of these five:

| Code | Root cause | What it means |
|---|---|---|
| `EKS` | Assumed EKS behaviour | What AWS does for me is done by someone else here, or by nobody |
| `CONF` | Confused two similar concepts | X ≠ Y. The note needs a "confusions" row |
| `GAP` | Never studied it | Coverage hole. Goes back to the curriculum tracker |
| `SPEED` | Knew it but was too slow | CKA/CKAD/CKS only |
| `READ` | Misread the question or the prompt | The most expensive error and the easiest to fix |
| `LIT` | Knew the mechanism, missed the exact string or number | Added 5 Sep — `GAP` was hiding the dominant failure mode |

An error with root cause `CONF` or `EKS` **must** end up as a line in §6 or §7
of its canonical note. If it never reached the note, it is not learned.

---

## Block 1 — KCNA

### Session 2026-08-23 — note 01 Active Recall (36 questions)

Result: ~20 solid, 8 partial, 8 wrong. Strong on architecture and control flow;
weak on the identity/PKI/ports layer.

| # | Q | What I answered | What was correct | Cause | Note | Re-verified |
|---|---|---|---|---|---|---|
| 1 | 10 | Named 3 loop steps: watch, compare, act | Four: watch → compare → **decide** → act | `GAP` | 01 §1.2 | ☐ |
| 2 | 13 | "replicaset controller" alone owns Deployment→RS→Pod | **Two** controllers: deployment-controller makes the RS, replicaset-controller makes the Pods. A Deployment never creates Pods | `CONF` | 01 §1.6 | ☐ |
| 3 | 14 | Did not know which controller or which field | **garbage-collector-controller**, acting on **`metadata.ownerReferences`** | `GAP` | 01 §1.6 / 02 §1.10 | ☐ |
| 4 | 18 | Quorum arithmetic as 5/2+1 = 3.5 → 3; said "tolerates 2 **pods**" | Integer division: 5/2 = 2, +1 = **3**. Tolerates n − quorum = 2 **etcd members** | `CONF` | 01 §1.4 | ☐ |
| 5 | 20 | kubelet "1052", scheduler "1057" | kubelet **10250**, scheduler **10259**, controller-manager **10257**, kube-proxy health **10256** | `GAP` | 01 §2.3 | ☐ |
| 6 | 22 | Knew both taint names, could not map them to conditions | `Ready: False` → **`not-ready`**; `Ready: Unknown` → **`unreachable`**. Silence = unreachable | `CONF` | 01 §1.10 | ☐ |
| 7 | 23 | Grace period "40 or 50s"; taint = not-ready; node-lifecycle evicts | **50s** (v1.32+, was 40s); a silent node gets **`unreachable`**; the **taint-eviction-controller** evicts (split out in v1.29). Total ≈ 350s | `GAP` | 01 §1.11 | ☐ |
| 8 | 24 | Did not know the two effects | **`NoSchedule` + `NoExecute`**, both applied. NoSchedule blocks new Pods, NoExecute starts the 300s clock | `GAP` | 01 §1.11 | ☐ |
| 9 | 25 | replicaset, scheduler, kubelet, api server | **taint-eviction-controller → replicaset-controller → scheduler → kubelet.** The API server is the bus, not an actor | `CONF` | 01 §1.11 | ☐ |
| 10 | 26 | Did not know what a DaemonSet is | One Pod per node (agents). Its Pods tolerate `NoExecute` with **no `tolerationSeconds`** → never evicted for node health | `GAP` | 03 (pending) | ☐ |
| 11 | 28 | Did not know where the username comes from | Username = certificate **CN**; groups = certificate **O** fields. There is no `User` object in Kubernetes | `GAP` | 01 §2.2 | ☐ |
| 12 | 29 | Did not know | `admin.conf`: CN=`kubernetes-admin`, O=`kubeadm:cluster-admins`, on every CP node. `super-admin.conf`: CN=`kubernetes-super-admin`, O=`system:masters`, only on the init node | `GAP` | 01 §2.1 | ☐ |
| 13 | 31 | Did not know | The **kubelet rotates its own cert**; it lives in `/var/lib/kubelet/pki/`, outside kubeadm's scope, so `check-expiration` cannot report it | `GAP` | 01 §2.1 | ☐ |
| 14 | 32 | Answered `staticPodPath` but not the object kind | It is a **`KubeletConfiguration`** (`kubelet.config.k8s.io/v1beta1`), **not** a kubeconfig | `CONF` | 01 §2.1 | ☐ |
| 15 | 33 | "etcd, apiserver, controller-manager" | The three CAs are **cluster CA**, **front-proxy CA**, **etcd CA**. apiserver and controller-manager get certs *signed by* the cluster CA; they have no CA of their own | `CONF` | 01 §2.1 | ☐ |
| 16 | 34 | RSA keys, but not the blast radius | Replacing `sa.key`/`sa.pub` invalidates **every existing ServiceAccount token** at once | `GAP` | 01 §2.1 | ☐ |
| 17 | 35 | Did not know | Leaf certs **1 year**, CAs **10 years** | `GAP` | 01 §2.1 | ☐ |

Minor wording corrections (not scored as errors):
- Q1 said "plano de datos" — Kubernetes vocabulary is **node components** / worker node. "Data plane" belongs to service mesh.
- Q3 said nodes "run"; nodes run **Pods**.
- Q5/Q8 said the scheduler and kubelet reach etcd; **only the API server does**.
- Q6 phases have names: **filtering (predicates)** and **scoring (priorities)**.

---

## Recurring confusions (X ≠ Y)

When the same pair shows up twice above, promote it here. Re-read the day before
the exam.

| X | Y | The difference in one line |
|---|---|---|
| deployment-controller | replicaset-controller | Makes ReplicaSets (revisions) vs makes Pods (count) |
| node-lifecycle-controller | taint-eviction-controller | Marks and taints vs actually deletes the Pod (split in v1.29) |
| `Ready: False` | `Ready: Unknown` | Reported illness → `not-ready` vs silence → `unreachable` |
| `kubelet.conf` | `/var/lib/kubelet/config.yaml` | kubeconfig (identity) vs KubeletConfiguration (behaviour) |
| Cluster CA | per-component certs | Three CAs exist; components get *signed* certs, not their own CA |

---

## Confirmed EKS→vanilla traps

Only the ones that actually cost an answer.

| I assumed (because of EKS) | Reality on kubeadm | Date |
|---|---|---|
| _(none yet — the 2026-08-23 gaps were `GAP`/`CONF`, not EKS assumptions)_ | | |

---

## Practice scores

| Date | Mock | Score | Weakest domain | Action |
|---|---|---|---|---|
| | | | | |

### Session 2026-08-23 — note 02 Active Recall (23 KCNA-scope questions)

Result: **14 solid, 6 partial, 3 wrong ≈ 74%** — just under the >75% pass line.
Improvement over note 01, and this time measured on KCNA-scope questions only.

| # | Q | What I answered | What was correct | Cause | Note | Re-verified |
|---|---|---|---|---|---|---|
| 18 | 4 | Said "uuid"; flag "--orphan" | It is **`uid`**, and the flag is **`--cascade=orphan`** | `CONF` | 02 §1.2 | ☐ |
| 19 | 7 | "v1 is the stable version of the Kubernetes API"; "prefix is k8s.io/v1"; did not know why no group name | `v1` is stable for the **core group**, not for Kubernetes. **There is no `k8s.io/v1` prefix** — the core group has no group name; URL is `/api/v1`. **Why: the core group predates API groups**, kept nameless for backward compatibility | `GAP` | 02 §1.3 | ☐ |
| 20 | 9 | "both alpha and beta are off by default" | **Alpha always off. Beta varies** — long-standing beta on, newer beta off. Also missed: alpha may be **dropped without notice** and **may lose data** | `CONF` | 02 §1.3 | ☐ |
| 21 | 11 | Muddled example (`!=pdn,!=qa`) | Clean pair: `environment=production` ↔ `environment in (production)`; negative `environment!=production` ↔ `environment notin (production)` | `CONF` | 02 §1.8 | ☐ |
| 22 | 12 | Named the family but never said what it selects | `-l '!tier'` selects objects that **do not carry the key `tier` at all** | `GAP` | 02 §1.8 | ☐ |
| 23 | 24 | Did not know | **`api.prod.svc.cluster.local`** — format `<service>.<namespace>.svc.cluster.local`. Near-guaranteed KCNA question | `GAP` | 02 §1.9 | ☐ |
| 24 | 25 | Gave the *how to confirm*, not the *what is wrong* | **What:** the Service `spec.selector` matches no Pod labels, or the Pods are not `Ready`. **How:** `kubectl get endpointslice` + `kubectl get pods --show-labels` | `READ` | 02 §1.8 / §6 | ☐ |
| 25 | 35 | "a schema with a controller" | An operator is **CRD + controller + encoded operational knowledge** — the third part is the official definition | `CONF` | 02 §1.12 | ☐ |
| 26 | 37 | "ConfigMap — I don't know it, maybe discovery or secrets" | A **ConfigMap** holds **non-confidential** key/value config that Pods consume as env vars or mounted files. Confidential data is a **Secret**. Nothing to do with discovery | `GAP` | 07 (pending) | ☐ |

**Coach error to note:** Q7 asks for the URL prefix, but the §1.3 banner tells the
learner to skip the `/api` vs `/apis` detail. The question was out of the scope
the note itself declared. Fixed by the KCNA-only policy from note 03 onward.

**Cross-session pattern (01 + 02):** conceptual reasoning is reliable; the
failures cluster on **exact strings and numbers** — ports, DNS suffixes, group
names, RBAC group names, cert lifetimes, default flag values. Fix by drilling
literals, not by re-reading prose.
| `uid` | `uuid` | Kubernetes calls it `uid`. "UUID" is not the field name |
| ConfigMap | Secret | Non-confidential config vs confidential data |
| Alpha off by default | Beta off by default | Alpha always off; **beta varies** |
| core group `v1` | `k8s.io/v1` | The core group has **no** group name. URL is `/api/v1` |

---

## Rows 57–67 — 6 Sep, notes 09 and 10

> **File integrity warning.** This copy jumps from row 26 to row 57. Rows **27–56**
> (notes 03–08, logged 1 Sep and 5 Sep) exist only in the local file and are
> missing here. `plan.md` reserves **Wed 9 Sep** for a full review of this log —
> restore those rows before then or that review covers a third of the record.

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 57 | 09 §1.1 | **Reincidence, same day**: attributed observability to "the cardinality" after explicit correction | Instrumentation **richness** is what makes a system observable. High cardinality is only safe in logs and traces | `CONF` | 09 §1.1 | ☐ |
| 58 | 09 §1.3 | Did not name the workload that makes Pushgateway necessary | **Job / CronJob** — lifetime shorter than the scrape interval | `LIT` | 09 §1.3 | ☐ |
| 59 | 09 §1.4 | Claimed kube-state-metrics can run as a DaemonSet | **Deployment, single replica.** It reads the API, not the nodes; replicas would duplicate every series and `sum()` would return 3× the truth | `CONF` | 09 §1.4 | ☐ |
| 60 | 09 §1.5 | Chose histogram without justifying by where the quantile is computed | Answer with the criterion the question asks for, not with the downstream consequence | `READ` | 09 §1.5 | ☐ |
| 61 | 09 §1.7 | Said metrics-server "stopped working" | On kubeadm it was **never installed**. A missing component, not a broken one | `CONF` | 09 §1.7 | ☐ |
| 62 | 09 §1.9 | Defined *span* as forwarding the trace ID to the next hop — **twice in one session** | **Span = one operation** inside a trace; a trace is a tree of spans. Forwarding the ID is context propagation | `CONF` | 09 §1.9 | ☐ |
| 63 | 09 §1.12 | Computed `100% − 99.9%` as 0.01% | **0.1%** → about **43 minutes per 30 days** | `LIT` | 09 §1.12 | ☐ |
| 64 | 10 §1.2 | **Reincidence, same day**: OpenGitOps principle 1 given as "Git is the source of truth" | **Declarative** → Versioned & Immutable → Pulled Automatically → Continuously Reconciled. Git-as-truth is a *consequence*, not the principle | `LIT` | 10 §1.2 | ☐ |
| 65 | 10 §1.3 | Counted drift detection as a **security** advantage of pull | The security pair: **no cluster credentials in CI**, **no inbound access to the API server**. Drift detection is an operational advantage | `CONF` | 10 §1.3 | ☐ |
| 66 | 10 §1.5 | Defined *release* as "the version of the YAML" | A release is **one concrete installation** of a chart, with its own name. One chart, many releases | `LIT` | 10 §1.5 | ☐ |
| 67 | 10 §1.9 | Computed `maxSurge`/`maxUnavailable` = 1 but never gave the max/min Pod counts the question asked for | `replicas: 4` at defaults → **max 5, min 3** | `READ` | 10 §1.9 | ☐ |

**Retracted:** a `READ` row dictated earlier on 6 Sep ("answered 18 items to 13
questions") was **the coach's error, not the learner's** — the coach improvised
13 questions instead of using the note's own §10, which has 18. No learner error
occurred. Two corrections dictated in the same turn (Alertmanager's four
functions, the Pushgateway distractor) were also **out of scope of what the
questions asked** and are withdrawn.

**Session pattern, 6 Sep:** the profile holds for a fourth and fifth time.
**No mechanism was wrong across 36 recall questions.** Every miss was a literal
(`up`, `Job/CronJob`, `Declarative`, the release definition), an arithmetic slip
(0.01% vs 0.1%), or a `READ` — the question asked for X and the answer gave the
consequence of X. Two of the eleven rows are **same-day reincidences**, both
corrected explicitly earlier in the same session: *span* and *Declarative*. Those
two are the drill priority.

**New confusions for the note §7 tables:**

| Not this | But this | Why |
|---|---|---|
| Instrumentation richness | Cardinality | How many attributes you emit vs how many series they produce |
| Span | Trace ID / context propagation | One operation vs the identifier that joins them |
| kube-state-metrics reads etcd | It reads the **Kubernetes API** | Only the API server talks to etcd |
| `Gateway API` | "an API gateway" | A Kubernetes standard vs a product category |
| `kustomization.yaml` | "customization.yaml" | Spelled with a K |
| Rollout succeeded | Deployment is healthy | `rollout status` only checks Pods start and pass probes |

---

## Rows 68–74 — 6 Sep, note 11

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 68 | 11 §1.6 | **Reincidence, same day**: "serverless literally means no server" | Servers still exist — **the provider manages them** and you pay for actual use. "There are no servers" is an exam distractor | `CONF` | 11 §1.6 | ☐ |
| 69 | 11 §1.6 | Answered the FaaS/serverless relationship when the question asked for the **trade-off** | The trade-off is the **cold start** — latency when scaling up from zero | `READ` | 11 §1.6 | ☐ |
| 70 | 11 §1.4 | Could not say why immutability forces configuration out of the image | One image for every environment ⇒ it can hold nothing environment-specific ⇒ inject at runtime. This **is** twelve-factor III | `GAP` | 11 §1.4 | ☐ |
| 71 | 11 §1.8 | Classified **Falco** as incubating; did not know **Harbor** | Both are **Graduated**. And **five** projects graduated in 2026: Dragonfly, Kyverno, OpenTelemetry, Buildpacks, Kubeflow | `LIT` | 11 §1.8 | ☐ |
| 72 | 11 §1.8 | Gave **Calico** as an example of "not Graduated" | Calico is **not a CNCF project at all** (Tigera) — a different category, alongside Grafana | `CONF` | 11 §1.8 | ☐ |
| 73 | 11 §1.9 | Did not identify **OCI** as the open standard that is not CNCF | OCI belongs to the **Linux Foundation**. Three distinct states: CNCF project with a maturity level (CNI, incubating) · Kubernetes specification with none (CRI, CSI) · Linux Foundation (OCI) | `LIT` | 11 §1.9 | ☐ |
| 74 | 11 §1.10 | Named the **WG** as the third CNCF governing body | The third is the **End User TAB**. The WG belongs to **Kubernetes**, not the CNCF — the two vocabularies must not mix | `CONF` | 11 §1.10 | ☐ |

**Session pattern, 6 Sep (three notes, 54 recall questions).** The profile is now
confirmed beyond argument: **no mechanism was wrong anywhere in the session.**
Every single miss across notes 09, 10 and 11 was one of three things — a missing
**literal** (`up`, `Job/CronJob`, `Declarative`, the definition of *release*, OCI's
owner, the End User TAB), an **arithmetic slip** (0.01% vs 0.1%; max/min Pods not
computed), or a **`READ`** — the question asked for X and the answer gave the
consequence of X.

**Three same-day reincidences**, all corrected explicitly earlier in the same
session: *span* misdefined, *Declarative* replaced by "Git is the source of
truth", and *serverless* as "no servers". Reincidence within hours is the
strongest available signal that **re-reading does not fix literals**. These
three, plus the 20 rows marked `LIT`, are the drill list — written from memory,
not re-read.

**Classification, not knowledge, is the weak spot in note 11.** Rows 71–73 are all
the same failure: the learner knows what Falco, Harbor, Calico and OCI *do*, and
misplaces their **category**. Drill as three buckets, not as one list: CNCF
Graduated · CNCF Incubating · **not a CNCF project** (Calico, Grafana, and — as a
different case again — OCI under the Linux Foundation, and CRI/CSI as Kubernetes
specifications with no maturity level).

---

## Block 2 — CKA (from 12 Sep 2026)

> Codes `SPEED` and `EKS` are now live. From this block a row also needs a
> **time** when the cause is `SPEED` (Actual vs Target), and an `EKS` row must
> land in the note's §7 the same day.

### Rows 75– — 12 Sep, planning session (comprehension checks)

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 75 | 05 §1.x | `LoadBalancer <pending>` reasoned correctly (no cloud-controller-manager) but the EKS side was "EKS resolves it" — component not named | **AWS cloud-controller-manager** (in-tree, CLB) or **AWS Load Balancer Controller** (NLB/ALB). "The cloud handles it" scores zero in a performance exam | `PREC` | 05 §7 | ☐ |

**Terminology, 12 Sep:** "practice bundle attempt" — the LF registration includes
**killer.sh** (2 sessions); KodeKloud/Udemy include their own **mock exams**.
These are different products with different roles (`plan.md §6.2`); do not call
both "the mock".

### Rows 76– — 16 Sep, etcd backup/restore (phase T)

> ⚠️ Numbered from the project copy (ends at row 75). If the local copy holds
> 13–15 Sep rows, merge them first and renumber these after them.

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 76 | D1-2 1.4b | Used the image tag `3.6.6-0` as the release version → download 404 | Three version strings: image `3.6.6-0` · release `v3.6.6` · apt `1.35.8-1.1` | `LIT` | D1-2 1.4b traps | ☐ |
| 77 | D1 §0 | Boot block: `~\.vimrc` | Linux paths use `/`: `~/.vimrc`. Newline is `\n` | `LIT` | D1 §0 | ☐ |
| 78 | D1-2 1.4b | Endpoint as `http//localhost:2379-3380` | **`https://127.0.0.1:2379`** — https, single port. 2379 clients, 2380 peers | `LIT` | D1-2 1.4b | ☐ |
| 79 | D1-2 1.4b | "restore needs no certs because they are inside the snapshot" | Restore is **offline file work** — no connection exists. The `.db` holds data, never credentials. `etcdctl` = network client, `etcdutl` = file utility | `CONF` | D1-2 1.4b | ☐ |
| 80 | D1-2 1.4b | Without `sudo`: "permissions" in general, first failing line not named | **`--key`** fails first: `server.key` is root-only (600); certs are public (644) | `PREC` | D1-2 1.4b | ☐ |
| 81 | D1-2 1.4b | Called the live data in `/var/lib/etcd` "old data" | `/var/lib/etcd` = **current** (newest). The photo is in `etcd-restore` | `CONF` | D1-2 1.4b | ☐ |

**Coach errors, 16 Sep (not learner rows):** issued 10 tasks + 40 commands at once
(→ teach-first method); claimed `crictl` ships with kubeadm — absent on this
node; a check question assumed a peer cert would be rejected — probably accepted;
the "drop `-0`" instruction was hidden in a comment (contributed to row 76).

**Session pattern:** every mechanism right when taught one step at a time (static
Pods vs kubelet, the missing-hostPath consequence, the whole procedure summarised
unprompted). Misses were literals (76–78) and one causal confusion (79). Same
profile as Block 1.

**Recurring confusions — added 16 Sep:**

| Term | Confused with | Difference |
|---|---|---|
| `kubectl` | `kubelet` | Client you type (ctl = control) vs agent on every node |
| `etcdctl` | `etcdutl` | Network client, needs endpoint + certs vs offline file utility, needs neither |
| `pki/ca.crt` | `pki/etcd/ca.crt` | Kubernetes CA vs etcd CA |
| `--data-dir` / `mountPath` | `hostPath.path` | Paths inside the container vs the directory on the node |

### Rows 82–88 — 17 Sep, etcd backup/restore (phase E) + upgrade from memory

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 82 | D1-2 1.4 | `source <(complete kubectl bash)` | `source <(kubectl completion bash)`, then `complete -o default -F __start_kubectl k`. **`kubectl completion bash` generates** the script; **`complete` registers** it — two commands, two lines, that order | `CONF` | D1 §0 | ☐ |
| 83 | D1-2 1.4b | `/etcd/kubernetes/manifest/` — **twice in one session** | `/etc/kubernetes/manifests/` — `etc` (system config), not `etcd` (the database); `manifests` **plural** | `LIT` | D1-2 1.4b | ☐ |
| 84 | D1-2 1.4b | `--endpoinst=` | `--endpoints=`. Recovered well: read the command's own `--help` and retyped | `LIT` | D1-2 1.4b | ☐ |
| 85 | D1-2 1.4b | `etcdutl status <file>` | `etcdutl snapshot status <file>` — `snapshot` is the command group | `LIT` | D1-2 1.4b | ☐ |
| 86 | D1-2 1.4b | `k get cm, deploy` | `k get cm,deploy` — **no space** after the comma, or kubectl reads two arguments in `type/name` form | `LIT` | D1-2 1.4b | ☐ |
| 87 | D1-2 1.4b | `grep B2 'name: etcd-data' …` → `No such file or directory`, **and continued to the next step anyway** | `grep -B2`. The dash is the symptom; the root cause is method: **a command that returns an error is not a passed verification.** Read the output before moving on | `PREC` | D1-2 1.4b | ☐ |
| 88 | D1-2 1.4b | Used `manifests.bk` where the runbook says `manifests.bak` | Harmless only because all three commands used the same invented name. Under a clock, use the runbook's literal | `PREC` | D1-2 1.4b | ☐ |

**What went right, 17 Sep** — the exam skills, recorded because they are evidence
too: the whole procedure summarised correctly and unprompted before executing;
`--endpoinst` and `etcdutl status` diagnosed from the tool's own help without
asking; and the fast-variant failure diagnosed **from evidence** (`crictl ps`
CREATED column, `get <name>` vs `get <type>`) instead of by guessing.

**Coach errors, 17 Sep (not learner rows):** recommended the in-place "fast
variant" as an exam path before testing it — it corrupts the API server's view
(retracted, `cka-D1-2-lifecycle.md` 1.4b); said `etcdctl snapshot save --help`
gives a usable command, when its example paths are the generic `/etc/etcd/`
install, not kubeadm's `pki/etcd/`; claimed Tab completion fails under `sudo` for
permission reasons — the directory is world-readable, the real cause is bash
splitting words on `=`.

**Session pattern, 17 Sep:** six of seven rows are literals, zero are mechanism.
The mechanisms held under pressure, including an unplanned failure. **Literals are
now the only thing standing between this and exam speed** — they are fixed by
repetition at the keyboard, not by re-reading notes.

**Recurring confusions — added 17 Sep:**

| Term | Confused with | Difference |
|---|---|---|
| `kubectl completion bash` | `complete` | Generates the completion script vs registers it in bash |
| `/etc/` | `/etcd/` | The system config directory vs the database's name |
| `k get <type>` (list) | `k get <type> <name>` | May be served from the **API server watch cache** vs always goes to **etcd** |
| `&&` | `;` | Stops at the first failure vs runs regardless — same speed, different safety |

### Rows 89–90 — 19 Sep, §C certificates + 1.4c node lifecycle

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 89 | D1-2 1.4c | `--print-join-comand` | `--print-join-command` | `LIT` | D1-2 1.4c | ☐ |
| 90 | D1-2 1.5 | Thought a control-plane `join` needed a `drain` + `delete` first | `join` admits a machine **outside** the cluster; `drain`/`delete` remove one **inside** it. A join only needs a clean machine (fresh install, or `kubeadm reset -f`) | `CONF` | D1-2 1.5 | ☐ |

**Handwritten rehearsal, 19 Sep** (upgrade + 1.4b written from memory, no console,
before the session): structure and order **complete and correct** in both
procedures; 11 errors, all literals — `export do=` without the two dashes, an
unclosed `sed` quote twice, `/ect/apt/sources.d.list/`, `apt-mark unhold` with no
package, `kubeadnm`, `manifest` singular (4th time), `etcdutl status` without
`snapshot` (2nd time), `critctl`, `k create cm` with no name. One **skipped step**,
not a literal: the kubeadm binary upgrade was omitted on w2.

**Coach errors, 19 Sep:** predicted that `kubectl delete node` would leave the
Pods running on the machine — **wrong**, measured: the kubelet watches the API,
loses its Pod assignments and stops the containers within seconds. Corrected in
`cka-D1-2-lifecycle.md` 1.4c. Also proposed `grep -E '…|controller'` for the
restart check, which matches `calico-kube-controllers`.

**Session pattern, 19 Sep:** two runtime errors in three hours at the console
against eleven in one handwritten page. **The literals are a writing problem, not
a knowledge problem** — they get fixed by typing into a shell that answers back,
not by writing on paper. From here, rehearsals happen in the terminal.

### Rows 91–92 — 26 Sep, upgrade R2 (18:00)

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 91 | D1-2 1.4 | Eight literals in one run: `apr`, `--allow-change-heald-packages`, `apt-ache`, `madion`, `sed '\|s\|…'`, `systemctlrestart`, `kubeclt`, `ssh 2` | Correct strings in the card. The long flag cost a retry — the price of the shortcut | `LIT` | D1-2 1.4 | ☐ |
| 92 | D1-2 1.4 | `systemctlrestart` failed on w2 and the run continued — the kubelet was restarted by Ubuntu's `needrestart`, not by the command | Read the tail of every chained line. The proof is `get nodes` showing the new version, not the absence of an error you did not read | `PREC` | D1-2 1.4 | ☐ |

**Coach error, 26 Sep:** claimed `--allow-change-held-packages` leaves the hold in
place. **Wrong, measured by the learner:** `apt-mark showhold` was empty on all
three nodes after the run. Runbook r9 re-holds once per node, chained into the
kubelet line.

### Rows 93–102 — 31 Oct, D1-1 1.2 node prep + 1.3 whiteboard

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 93 | D1-1 1.2 | Pinned install `=1.37.1-1.1` over 1.37.2 → `E: Packages were downgraded and -y was used without --allow-downgrades` | Installing an older version than the one present needs `--allow-downgrades` (held packages: `unhold` first) | `GAP` | D1-1 1.2 | ☐ |
| 94 | D1-1 1.2 | "It didn't work" → `clear` → the `E:` line was gone | Read the `E:` line before anything else; it names the fix | `READ` | D1-1 1.2 | ☐ |
| 95 | D1-1 1.2 | `lsmod \| grep 'overlay\|br_netfilter'` without `-E` → empty | Alternation needs `grep -E` | `LIT` | D1-1 1.2 | ☐ |
| 96 | D1-1 1.2 | Recall: `sysctl --system` named as the persistent half; path `/etc/systcl/` | Persistent = the file `/etc/sysctl.d/k8s.conf`; `sysctl --system` = apply now | `CONF` | D1-1 1.2 | ☐ |
| 97 | D1-1 1.2 | Recall: kubelet crash-loop on a prepared node blamed on the missing CNI | The kubelet loops because it has no config until `init`/`join` writes `/var/lib/kubelet/config.yaml`. No CNI = `NotReady`, not a loop | `CONF` | D1-1 1.2 | ☐ |
| 98 | D1-1 1.2 | Recall: "kubeadm may be up to 3 minors below" | kubelet ≤ apiserver, up to 3 minors older · kubeadm = the cluster version · kubectl ±1 | `CONF` | D1-1 1.2 | ☐ |
| 99 | D1-1 1.2 | `apt-mark hold` left out of two spoken summaries of the install step | `install` and `hold` are one card line | `PREC` | D1-1 1.2 | ☐ |
| 100 | D1-1 1.2 | "`SystemdCgroup = true` means containerd manages the cgroups" | The reverse: `true` = containerd delegates cgroup management to **systemd**, the same manager the kubelet uses | `CONF` | D1-1 1.2 | ☐ |
| 101 | D1-1 1.2 | Break/fix solved (3:59 ✅) by walking every prep step, cause not classified | Classify first: network wording → steps 2–3 → `sysctl` ×3 → `cannot stat /proc/sys/net/bridge/…` = module missing → `modules-load.d` file | `SPEED` | D1-1 1.2 | ☐ |
| 102 | D1-1 1.3 | "The worker was prepared with `kubeadm init`" | The worker is prepared by 1.2 (node prep); `init` builds a control plane — on `w3` it was undone with `reset` before the join | `CONF` | D1-1 1.3 | ☐ |

**Coach errors, 31 Oct:**
- The runbook's trap said `no matches for kind "Installation"` means the CRDs ship in `operator-crds.yaml`. In Calico v3.33 the operator installs its own CRDs (`-manage-crds=true`); the error right after creating the operator is timing. Fixed in the traps table.
- Card 1.3 had `kubeadm token create` without `sudo`. Fixed.
- I quoted `kubeadm reset`'s three-line warning from older versions; v1.37 prints one paragraph with the same three items.
- The 1.2 break/fix wording named the category ("network requirements"). The exam gives a symptom or a literal list. From now on, exam-mode sets use that wording.

### Rows 103–110 — 31 Oct, D1-1 1.3 stage 4 + 1.7 sim A

| # | Source | Error | Correction | Root cause | Note | Fixed |
|---|---|---|---|---|---|---|
| 103 | D1-1 1.3 | Join T1 5:33 vs 3:00 — 2 min lost moving the join line from cp1 to w3 | Two terminals open before `go`; copy the line before leaving cp1. Rerun 2:42 | `SPEED` | D1-1 1.3 | ✅ 31 Oct |
| 104 | D1-1 1.3 | "The new node waited for certs and CNI routes" before `Ready` | Certs come inside `join` (TLS bootstrap). The wait is the `calico-node` DaemonSet pulling images and writing `/etc/cni/net.d/10-calico.conflist`; containerd sees the file → `NetworkReady=true` → `Ready` | `CONF` | D1-1 1.3 | ☐ |
| 105 | D1-1 1.3 | Did not know who removes a DaemonSet Pod during a decommission | Two halves: the API object goes when **PodGC** (controller-manager) collects Pods of a deleted node; the container goes at **`kubeadm reset`** (CRI). `drain --ignore-daemonsets` leaves both | `GAP` | D1-1 1.3 | ☐ |
| 106 | D1-1 1.3 | CNI T3 declared done with the node `NotReady` and CoreDNS `Pending` | The `prove` line is part of the task: `tigerastatus calico True` + `Ready` + CoreDNS. In the exam: flag, move on, come back to prove | `PREC` | D1-1 1.3 | ☐ |
| 107 | D1-1 1.3 | `crictl ps` `Running` read as "Calico is up" | `Running` = the process lives; `READY 1/1` in `kubectl get pods` = the readiness probe passes | `CONF` | D1-1 1.3 | ☐ |
| 108 | D1-1 1.7 | `crictl logs <id> > 2&1 \| tail -5` → file `~/2`, background job, `1: command not found` | `2>&1`, four characters together | `LIT` | D1-1 1.7 | ☐ |
| 109 | D1-1 1.7 | Sim A (cert path): read both manifests whole and checked etcd — the 26 Sep cause — 10:27 vs 6:00 | The log line carries a literal (`apiserver.cert`): grep it → `vim +<line>`. No line-by-line reading, no "last time it was etcd" | `PREC` | D1-1 1.7 | ☐ |
| 110 | D1-1 1.7 | Sim A (YAML): took the repeated `Failed deleting a mirror pod … :6443 refused` as the cause; `tail` hid the real line | The `:6443 refused` is the symptom echoing back. Grep the file name → `couldn't parse as pod (yaml: line 41)` → check ±2 lines for indentation | `READ` | D1-1 1.7 | ☐ |

**Coach errors, 31 Oct (cont.):**
- Said `kubeadm token create` needs `sudo`. Measured: it works without it when `~/.kube/config` exists (kubeadm checks `$KUBECONFIG` → `~/.kube/config` → `admin.conf`). Card and trap corrected.
- During the YAML sim I quoted the kubelet line from my own setup check without saying so.

### Practice scores — Block 2

| Date | Paper | Score | Time used | Weakest domain |
|---|---|---|---|---|
| Sat 26 Sep | KodeKloud Mock A | | | |
| Sat 3 Oct | KodeKloud Mock B | | | |
| 4–5 Oct | Bundle practice attempt | | | |
| Tue 6 Oct | killer.sh s1 (gate ≥ 60%) | | | |
| Thu 8 Oct | killer.sh s2 (gate ≥ 70% / target ≥ 75%) | | | |
