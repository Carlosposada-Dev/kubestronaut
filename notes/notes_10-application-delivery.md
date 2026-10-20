---
exams: [KCNA, CKAD]
domain: Application Delivery
kcna_domains: 3.1 Application Delivery
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: opengitops.dev (the four principles), kubernetes.io/docs/concepts/workloads/controllers/deployment, helm.sh/docs, kubectl.docs.kubernetes.io/references/kustomize, argo-cd.readthedocs.io and fluxcd.io — "What is GitOps / Core Concepts" pages ONLY, per claude/sources.md
template: B
language: en
scope: KCNA ONLY — CKAD layer appended from 5 Oct
status: draft
revised: 2026-09-06 rev2 — 7 amendments from the note 10 recall session (§1.2, §1.5, §1.6, §1.7, §1.8, §1.10) plus 3 new traps. SUPERSEDES rev1.
prior_revision: 2026-09-06 rev1 — first issue
format: per claude/depth-standard.md AMENDMENT 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). CNCF maturity verified this session — Flux graduated **30 Nov 2022**, Argo graduated **6 Dec 2022**, Helm graduated **2020**.
scope_warning: plan.md §2 puts Argo CD out of scope until 1 Dec. The curriculum asks only "what they are and how they differ", so this note stays at that level and goes no further. Same treatment as service mesh in note 05 §1.13.
no_duplication: the Deployment → ReplicaSet → Pod mechanism and the rolling-update internals are note 03 §1.4. Referenced here, never repeated.
---

# Application Delivery

*Everything in this note lives above the cluster. It is about how a change gets
from a commit to a running Pod — and who or what pushes the button.*

KCNA area 3.1 is the larger half of Domain 3 (16%) and worth roughly **6–7 of the
60 questions**. It is vocabulary-heavy: the exam tests whether you can tell four
similar-sounding practices apart.

---

## 1. Core Concepts

### 1.1 CI, Continuous Delivery, Continuous Deployment

*Three terms, two of which share an abbreviation. The difference is exactly one
thing: whether a human presses a button.*

| Term | Ends when | Human involved? |
|---|---|---|
| **CI** — Continuous **Integration** | Code is merged, **built and tested** automatically | The merge |
| **CD** — Continuous **Delivery** | Every passing change is **ready to release**, waiting in an artifact store | **Yes — someone approves the deploy** |
| **CD** — Continuous **Deployment** | Every passing change **is in production**, automatically | **No — nobody approves** |

```
commit → build → test        = Continuous Integration
                    ↓
              release-ready  = Continuous Delivery   ── human clicks deploy ──┐
                    ↓                                                          │
              in production  = Continuous Deployment  ── no human at all ──────┘
```

**The distinction the exam wants:** Continuous Delivery means you *could* deploy
at any moment; Continuous Deployment means you *do*, without asking. Delivery
keeps a gate, Deployment removes it. Both are abbreviated CD, which is the whole
reason it is a question.

Continuous Deployment requires far more confidence: automated tests must be
trusted completely, and rollback must be fast, because there is no human left to
catch a bad change.

### 1.2 GitOps and the four principles

*Git holds the desired state of the system, and something inside the cluster
works continuously to make reality match it.*

GitOps applies the reconciliation loop you already know (note 01 §1.2) to
**deployment**: instead of a controller comparing a Pod count against
`spec.replicas`, an agent compares the **live cluster** against **a Git
repository**.

**The four OpenGitOps principles** — published at `opengitops.dev`, and worth
memorising as a list because KCNA asks for them:

| # | Principle | Means |
|---|---|---|
| 1 | **Declarative** | The whole system is expressed **declaratively** — desired state, not steps |
| 2 | **Versioned and Immutable** | State is stored in Git: **versioned**, auditable, and **immutable** history |
| 3 | **Pulled Automatically** | Software agents **pull** the desired state automatically. Nobody pushes |
| 4 | **Continuously Reconciled** | Agents **continuously** observe and correct **drift** between actual and desired |

Two things follow that make GitOps more than a naming convention:

- **Git is the single source of truth.** A change made with `kubectl edit`
  directly on the cluster is **drift**, and principle 4 means the agent will
  **revert it** — the fix is to change Git, not the cluster.
- **Rollback is `git revert`.** Because the history is versioned and immutable,
  going back to any prior state is an ordinary Git operation.

**The test that separates real GitOps from CI/CD with YAML in Git.** A pipeline
that runs `kubectl apply -f` on merge satisfies principles 1 and 2 and fails 3
and 4 — and the two it fails are the ones that define GitOps. Ask: **what happens
if nobody touches Git for a week?** With a pipeline, a `kubectl scale` made on
Monday survives all week, because nothing runs between merges. With an agent, it
does not survive a minute. Principle 4 requires something **always watching**, not
something that runs when triggered.

### 1.3 Push-based vs pull-based deployment

*In push, a pipeline outside the cluster holds credentials and reaches in. In
pull, an agent inside the cluster reaches out. The security difference is the
point.*

| | **Push** (traditional CI/CD) | **Pull** (GitOps) |
|---|---|---|
| Who initiates | The **CI pipeline**, from outside | An **agent inside the cluster** |
| How | `kubectl apply` / `helm upgrade` from the pipeline | The agent watches Git and applies changes itself |
| Cluster credentials | **The pipeline holds them**, outside the cluster | **Never leave the cluster** |
| Firewall | The pipeline must **reach the API server** | The cluster only needs **outbound** access to Git |
| Drift | **Undetected** — nothing checks between deploys | **Detected and corrected** continuously |

```
PUSH:   CI pipeline ──(holds kubeconfig)──► API server
        credentials live outside the cluster; one leak reaches production

PULL:   Git repo ◄──(polls / webhook)── agent inside the cluster ──► API server
        credentials never leave; the cluster needs no inbound access
```

**Why pull is the GitOps answer**, in one line each: no cluster credentials in a
CI system, no inbound access to the API server, and drift is corrected rather
than accumulating silently between deployments.

The trade-off is honest: pull adds a component to run and debug, and a deploy is
no longer instantaneous — the agent applies it on its next reconciliation.

### 1.4 Argo CD and Flux

*Two CNCF graduated implementations of the same idea. KCNA asks what they are and
how they differ — nothing more.*

*Scope note: `plan.md §2` puts Argo CD out of scope until 1 Dec. This section is
the conceptual level the curriculum asks for and stops there.*

| | **Argo CD** | **Flux** |
|---|---|---|
| Origin | Intuit / Applatix, part of the **Argo** project | Weaveworks, 2016 |
| CNCF graduated | **6 Dec 2022** | **30 Nov 2022** |
| Shape | A single application, **UI-first** | A set of composable **controllers** (the GitOps Toolkit) |
| Main abstraction | The **`Application`** CRD | Source + Kustomization / HelmRelease controllers |
| Typical strength | Visual, multi-cluster from one place, strong RBAC and SSO | Modular, CLI- and API-first, easy to compose |

Both do the same job: watch Git, apply to the cluster, reconcile drift. Choosing
between them is a matter of team preference, not capability — and KCNA will not
ask you to choose.

### 1.5 Helm

*A package manager for Kubernetes: one parameterised bundle of manifests you can
install many times with different values.*

The problem: deploying the same application to dev, staging and production means
near-identical YAML with a few values changed. Copying it produces three files
that drift apart.

Helm's four terms — these are the exam's vocabulary:

| Term | Is |
|---|---|
| **Chart** | The **package**: templated manifests plus metadata |
| **Values** | The **configuration** injected into the templates (`values.yaml`, or `--set`) |
| **Release** | **One installed instance** of a chart in a cluster. Install the same chart twice, get two releases |
| **Repository** | Where charts are stored and shared |

```
mychart/
├── Chart.yaml          # name, version, description
├── values.yaml         # DEFAULT values
└── templates/
    ├── deployment.yaml # Go templates: {{ .Values.replicaCount }}
    └── service.yaml
```

Helm **templates**: `{{ .Values.image.tag }}` is substituted at install time, so
one chart produces different manifests per environment.

```bash
helm install myapp ./mychart -f prod-values.yaml
helm upgrade myapp ./mychart --set replicaCount=5
helm rollback myapp 2          # Helm tracks its own revision history
helm list
```

**A chart is to a release what a Docker image is to a container:**

| Docker | Helm |
|---|---|
| **Image** — packaged, versioned artifact | **Chart** |
| **Container** — one running instance of it | **Release** |
| Registry | **Repository** |
| Environment variables at start | **Values** |

One image runs many times with different variables; one chart installs many times
with different values. A release is **one concrete installation with its own
name**, not "a version of the YAML".

**Minimal worked example.** `templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-web
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
        - name: web
          image: "{{ .Values.image.repo }}:{{ .Values.image.tag }}"
```

`values.yaml` — the defaults:

```yaml
replicaCount: 1
image:
  repo: nginx
  tag: "1.27"
```

`helm install prod ./chart --set replicaCount=10` renders, and this is the whole
of what the API server receives:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-web
spec:
  replicas: 10
  template:
    spec:
      containers:
        - name: web
          image: "nginx:1.27"
```

`--set` overrides what you name; everything else falls back to `values.yaml`, and
every line without a `{{ }}` passes through untouched. Note the object name:
Helm **constructs** it from the release name.

**Helm 3 removed Tiller**, the in-cluster server component Helm 2 required. Tiller
held broad cluster permissions and was a well-known security problem; Helm 3 is a
client-side tool that talks to the API server as **you**, with your RBAC.

### 1.6 Kustomize

*Also produces per-environment manifests, but by patching real YAML instead of
filling in a template.*

Kustomize starts from a **base** — plain, valid, deployable Kubernetes YAML — and
applies **overlays** that patch it per environment. There is no template syntax
at all; every file is real YAML you could `kubectl apply` on its own.

```
base/
├── kustomization.yaml
├── deployment.yaml        # valid YAML, deployable as-is
└── service.yaml
overlays/
├── dev/kustomization.yaml     # patch: replicas 1
└── prod/kustomization.yaml    # patch: replicas 10, add resource limits
```

```bash
kubectl apply -k overlays/prod      # built into kubectl — no extra tool
kubectl kustomize overlays/prod     # render without applying
```

**Worked example.** `base/deployment.yaml` is ordinary YAML, deployable on its own:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: web
          image: nginx:1.27
```

`overlays/prod/kustomization.yaml` — **two different transformers, and `name`
means a different thing in each**:

```yaml
resources:
  - ../../base          # what I start from

replicas:
  - name: web           # ← name of the DEPLOYMENT (metadata.name)
    count: 10

images:
  - name: nginx         # ← name of the IMAGE (spec.containers[].image)
    newTag: "1.29"
```

`kubectl kustomize overlays/prod/` yields the same Deployment with `replicas: 10`
and `nginx:1.29` — and still named `web`. Kustomize **keeps** the object name;
Helm **builds** one. That contrast is the fastest way to tell rendered output
apart.

**`-f` vs `-k`** — both belong to `kubectl apply`, and differ in what they expect:

| Flag | Expects | Does |
|---|---|---|
| **`-f`** — *file* | A file or directory of **plain manifests** | Sends them to the API server as they are |
| **`-k`** — *kustomize* | A directory containing **`kustomization.yaml`** | **Renders first**, then applies the result |

The file is `kustomization.yaml`, with a K — not "customization".

**Kustomize is built into `kubectl`** (`-k`), which is why it needs nothing
installed. Its design claim is that a base stays readable and valid, whereas a
heavily templated chart is neither until it is rendered.

### 1.7 Helm vs Kustomize

*Fill in the blanks versus patch the original. Both solve per-environment
configuration; they disagree about how.*

| | **Helm** | **Kustomize** |
|---|---|---|
| Mechanism | **Templating** — placeholders filled at install | **Patching** — overlays modify a base |
| Is the source valid YAML? | **No** — it is a template until rendered | **Yes** — the base is deployable as-is |
| Packaging & sharing | **Yes** — repositories, versioned charts | No packaging concept |
| Release tracking / rollback | **Yes** — `helm rollback` | **No** — it only produces YAML |
| Installation | A separate binary | **Built into `kubectl`** |
| Best at | **Distributing** software others install | **Managing your own** manifests across environments |

**Choose by who consumes the artifact, not by how much customisation is needed** —
both customise. Helm wins when the consumer is a **stranger**: fifty customers with
very different configurations need an explicit configuration surface
(`values.yaml` is literally the contract for what may be changed), package
versioning, distribution through a repository, and its own rollback. Kustomize
wins when **the YAML is yours**: three environments differing only in replicas and
image need two small patches, not a template language — and the base stays
readable.

The one-line rule: **consumed by outsiders → Helm. Your own YAML, varying a
little → Kustomize.**

They are not mutually exclusive — Flux and Argo CD both support each, and
Kustomize can patch Helm output.

### 1.8 The two native Deployment strategies

*Kubernetes ships exactly two. Everything else you have heard of is built on top
of them.*

The mechanism — two ReplicaSets alive at once, the new scaling up as the old
scales down — is **note 03 §1.4**, and is not repeated here.

| Strategy | Behaviour | Downtime | Two versions live at once? |
|---|---|---|---|
| **`RollingUpdate`** | Gradual replacement, governed by `maxSurge` / `maxUnavailable` | **None** | **Yes** — unavoidable |
| **`Recreate`** | Terminate **all** old Pods, then create new ones | **Yes, deliberate** | **No** |

`RollingUpdate` is the default. **`Recreate` exists for a real reason**: when two
versions cannot safely run simultaneously — an incompatible database migration,
or a workload holding an exclusive lock such as a `ReadWriteOncePod` volume
(note 06 §1.8). Accepting downtime is sometimes the correct engineering choice.

The consequence people miss: **a rolling update means your old and new code serve
traffic at the same time**, so a schema change must be compatible with both.

Concretely: add a mandatory (`NOT NULL`, no default) column while the old code
does not write it, and every insert served by a **surviving old Pod is rejected**
for the length of the rollout. The failing share shrinks as the rollout advances,
which makes it harder to spot. The discipline that avoids it is **expand/contract**
— add the column as optional, deploy, and only then make it mandatory in a second
change, so no moment is ever incompatible.

**A successful rollout is not a healthy deployment.** `kubectl rollout status`
reports success on Pods starting and passing probes; it knows nothing about
application errors. Rollout success and service health are separate claims.

### 1.9 `maxSurge` and `maxUnavailable`

*One says how far above the target you may go, the other how far below. Together
they set the speed of the rollout.*

| Field | Means | Default |
|---|---|---|
| **`maxSurge`** | How many Pods **above** `replicas` may exist during the update | **25%** |
| **`maxUnavailable`** | How many Pods **below** `replicas` may be unavailable | **25%** |

Both accept a percentage or an absolute number; percentages are rounded — surge
**up**, unavailable **down**.

**Rounding direction matters and is asked:** `maxSurge` rounds **up**,
`maxUnavailable` rounds **down**. With `replicas: 4` and both at 25%, each
resolves to **1** — so at most **5** Pods exist and at least **3** are available.

Those two numbers are the ceiling and the floor of the whole rollout. A stalled
rollout sits exactly on both at once: total at the ceiling means no new Pod can
be created, available at the floor means no old Pod can be terminated. That is
what "stuck" looks like arithmetically, and §11 Drill 2 walks it.

| Setting | Effect |
|---|---|
| `maxSurge: 0` | Never exceed the replica count. Slower; needs spare capacity nowhere |
| `maxUnavailable: 0` | Never drop below full capacity. **Requires room for extra Pods** |
| `maxSurge: 0` **and** `maxUnavailable: 0` | **Invalid** — nothing can start and nothing can stop. The API server rejects it |

That last row is a favourite exam item: the combination is a deadlock, so it is
forbidden outright rather than allowed to hang.

`maxUnavailable: 0` also interacts with scheduling — the surge Pods need capacity
somewhere, and if the cluster has none they stay `Pending` (note 03 §1.12) and
the rollout stalls rather than failing.

### 1.10 Blue/green and canary

*Neither is a Kubernetes feature. Both are patterns you assemble from Services,
labels and Deployments.*

**This is the most common misconception in the domain.** `spec.strategy` accepts
`RollingUpdate` or `Recreate` — there is no `BlueGreen` and no `Canary`.

| Pattern | How it works | Traffic split | Rollback |
|---|---|---|---|
| **Blue/green** | Two **complete** environments. Switch the Service selector from `version: blue` to `version: green` | **All at once**, 0% → 100% | **Instant** — switch the selector back |
| **Canary** | Deploy a **small number** of new Pods alongside the old; both match the same Service | **Gradual**, by replica ratio or by a proxy | Delete the canary Pods |

Both are built from the label selector of note 05 §1.7: a Service sends traffic
to whatever Pods match its selector, so changing labels or replica counts changes
the traffic split without any special feature.

| | Blue/green | Canary |
|---|---|---|
| Resource cost | **Double** — two full environments | Small — a few extra Pods |
| Blast radius if broken | **All users at once** | **A fraction of users** |
| Rollback speed | Instant | Fast |

**`Gateway API` is not "an API gateway".** `Gateway API` is the Kubernetes
standard succeeding Ingress; "API gateway" is a generic product category. Exam
options invert the two words.

Fine-grained splitting ("5% of traffic") needs weighting a Service cannot do —
that is Gateway API (note 05 §1.11), a service mesh (note 05 §1.13), or a
progressive-delivery controller such as Argo Rollouts or Flagger.

### 1.11 Rollback

*A Deployment keeps its old ReplicaSets at zero replicas precisely so it can
scale one of them back up.*

The mechanism is note 03 §1.4: old ReplicaSets are retained, empty, up to
`revisionHistoryLimit` (default **10**).

```bash
kubectl rollout status deployment/web       # watch it; exits non-zero if it fails
kubectl rollout history deployment/web      # list revisions
kubectl rollout undo deployment/web         # back to the PREVIOUS revision
kubectl rollout undo deployment/web --to-revision=3
kubectl rollout pause deployment/web        # freeze mid-rollout
kubectl rollout resume deployment/web
kubectl rollout restart deployment/web      # restart all Pods, no spec change
```

Three things worth holding:

- **`rollout undo` reverses the cluster, not Git.** Under GitOps this is drift,
  and principle 4 means the agent will put the broken version back. The correct
  rollback there is `git revert`.
- **`rollout restart`** replaces every Pod without changing the spec — the clean
  way to force a re-pull or reload mounted configuration.
- **`revisionHistoryLimit: 0` disables rollback entirely**, because there is no
  old ReplicaSet left to scale up.

---

## 2. Objects & Fields That Matter

| Object / thing | Key fields | Default | Gotcha |
|---|---|---|---|
| Deployment strategy | `spec.strategy.type` | `RollingUpdate` | Only two values. No `Canary`, no `BlueGreen` |
| Rolling update | `spec.strategy.rollingUpdate.maxSurge` / `maxUnavailable` | **25% / 25%** | Both `0` is **invalid** |
| History | `spec.revisionHistoryLimit` | **10** | `0` disables rollback |
| Rollout commands | `kubectl rollout status/history/undo/pause/resume/restart` | — | `undo` changes the cluster, not Git |
| Helm | `Chart.yaml`, `values.yaml`, `templates/` | — | Chart = package, Release = installed instance |
| Kustomize | `kustomization.yaml`, `bases`, `overlays` | — | `kubectl apply -k` — built in |
| GitOps | 4 principles at opengitops.dev | — | Declarative, Versioned+Immutable, Pulled, Reconciled |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 3 (CKAD, from 5 Oct).*

---

## 4. Hands-On Lab

**Target: 25 minutes.**

```bash
# 1. Watch a rolling update keep two ReplicaSets alive                 (8 min)
kubectl create deployment web --image=nginx:1.26 --replicas=4
kubectl rollout status deployment/web
kubectl set image deployment/web nginx=nginx:1.27
kubectl get rs -w -l app=web      # Ctrl-C after ~20s: TWO ReplicaSets, one up one down
kubectl get rs -l app=web         # old one now at 0 replicas, still present

# 2. Rollback uses that retained ReplicaSet                            (5 min)
kubectl rollout history deployment/web
kubectl rollout undo deployment/web
kubectl get rs -l app=web         # the OLD one scaled back up. Nothing was rebuilt

# 3. maxSurge 0 + maxUnavailable 0 is rejected                         (4 min)
kubectl patch deployment web -p \
  '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":0}}}}'
# expect an error: both cannot be 0

# 4. Kustomize is already installed                                    (5 min)
mkdir -p /tmp/k/base && cd /tmp/k/base
kubectl create deployment demo --image=nginx --dry-run=client -o yaml > deployment.yaml
cat > kustomization.yaml <<'EOF'
resources: [deployment.yaml]
replicas:
  - name: demo
    count: 7
EOF
kubectl kustomize .               # rendered with replicas: 7. No tool installed

# 5. rollout restart changes nothing but replaces everything           (3 min)
kubectl rollout restart deployment/web
kubectl get pods -l app=web -w    # all Pods replaced; the spec is identical

cd ~; kubectl delete deployment web; rm -rf /tmp/k
```

---

## 5. Verification

```bash
kubectl rollout status deployment/<d>              # exits non-zero on failure
kubectl get rs -l app=<label>                      # how many ReplicaSets, at what counts
kubectl rollout history deployment/<d>
kubectl get deploy <d> -o jsonpath='{.spec.strategy}{"\n"}'
kubectl get deploy <d> -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
helm list -A            # if Helm is in use
```

`kubectl rollout status` is the honest check: it blocks until the rollout
finishes and **exits non-zero if it fails**, which is what makes it usable in a
pipeline.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| Rollout stuck, new Pods `Pending` | No capacity for the surge Pods | `kubectl get pods`; `describe` a pending one | Note 03 §1.12; lower `maxSurge` |
| Rollout never completes, old Pods stay | New Pods never become **Ready** | `kubectl describe pod` → readiness | Fix the probe or the app (note 08 §1.12) |
| `rollout undo` does nothing | `revisionHistoryLimit: 0`, or only one revision | `kubectl rollout history` | Nothing to roll back to |
| Deployment patch rejected | `maxSurge` and `maxUnavailable` both `0` | The API server error message | Set at least one above 0 |
| Rolled back, and the old version returned by itself | **GitOps agent reverted the drift** | Check the agent's sync status | `git revert` instead |
| Errors during every rollout | Old and new versions both serving; incompatible change | — | Backwards-compatible changes, or `Recreate` |
| `helm upgrade` fails, release stuck | A previous operation failed mid-way | `helm list`, `helm history` | `helm rollback` to the last good revision |
| Manifests apply by hand but not via Kustomize | Base is not valid standalone YAML | `kubectl kustomize .` | Fix the base |

---

## 7. EKS vs Vanilla

**Most of this domain is cluster-agnostic** — Helm, Kustomize and GitOps behave
identically wherever they point. The differences are about what is delivered
*for* you.

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| The platform layer | Arrives as **managed add-ons** — CNI, kube-proxy, CoreDNS, EBS CSI — installed and upgraded by AWS. You never wrote those manifests | **You install every one of them yourself**, usually with Helm or raw YAML. This is where Helm stops being theory |
| Registry credentials for the agent | **IRSA** — annotate the ServiceAccount, ECR access is implicit (note 07 §1.4) | An `imagePullSecret` you create by hand (note 04 §1.11) |
| Rollback of platform components | Change the add-on version in the console or Terraform | `helm rollback`, or re-apply the previous manifests. **You own the history** |
| Deployment strategies | Identical — this is pure Kubernetes | Identical |

The habit to unlearn: on EKS a large part of the cluster arrives already
deployed, so "installing software into Kubernetes" is something you have rarely
had to do end to end. On kubeadm nothing arrives, and the Helm and Kustomize
vocabulary above stops being trivia.

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 3.*

---

## 9. Objectives Covered

KCNA area **3.1 Application Delivery**.

- [ ] CI vs Continuous Delivery vs Continuous Deployment
- [ ] GitOps and the **four OpenGitOps principles**
- [ ] Push-based vs pull-based deployment, and why pull is more secure
- [ ] Argo CD and Flux — what they are and how they differ
- [ ] Helm: chart, values, release, repository, templating; Helm 3 has no Tiller
- [ ] Kustomize: bases and overlays; why it uses no templates
- [ ] `RollingUpdate` vs `Recreate`, and when downtime is correct
- [ ] `maxSurge` and `maxUnavailable`, defaults, and the invalid combination
- [ ] Blue/green and canary — **not** native strategies
- [ ] Rollback: `kubectl rollout undo`, and why it is drift under GitOps

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "Continuous Delivery and Continuous Deployment are the same" | Delivery keeps a **human approval gate**. Deployment removes it |
| "CI includes deploying to production" | CI ends at **build and test** |
| "GitOps means storing YAML in Git" | Four principles — and **continuous reconciliation** is the one people skip |
| "GitOps pushes changes to the cluster" | Principle 3 is **pull**. An agent inside the cluster fetches |
| "A `kubectl edit` on a GitOps cluster is permanent" | It is **drift**; the agent reverts it |
| "Argo CD and Flux do fundamentally different jobs" | Same job, different shape. Both CNCF graduated |
| "A Helm chart is one deployed application" | A chart is the **package**; a **release** is an installed instance |
| "Helm needs Tiller in the cluster" | **Helm 3 removed Tiller.** That was Helm 2 |
| "A release is a version of the chart" | A release is **one installation** of a chart, with its own name. One chart, many releases |
| "YAML in Git plus a pipeline that applies on merge is GitOps" | Principles 1 and 2 only. Without an agent **always** reconciling, drift survives between merges |
| "`Gateway API`" ≡ "an API gateway" | `Gateway API` is the Kubernetes standard succeeding Ingress. Not the product category |
| "Kustomize uses templates" | It **patches** real YAML. No template syntax |
| "You must install Kustomize separately" | **Built into `kubectl`** (`-k`) |
| "`BlueGreen` is a Deployment strategy" | Only `RollingUpdate` and `Recreate` exist |
| "Canary is a `spec.strategy` value" | It is a **pattern**, built from labels and Services |
| "`maxSurge` is how many Pods may be unavailable" | That is **`maxUnavailable`**. Surge is how many **extra** |
| "`maxSurge: 0` and `maxUnavailable: 0` makes the safest rollout" | **Invalid.** Nothing could start or stop |
| "`Recreate` is always wrong" | It is correct when two versions cannot coexist |
| "`rollout undo` rebuilds the old version" | It **scales up a retained ReplicaSet**. Nothing is rebuilt |
| "`rollout restart` changes the image" | It changes **nothing**; it replaces the Pods |

**X ≠ Y**

- **CI ≠ CD** — build and test vs release
- **Continuous Delivery ≠ Continuous Deployment** — a gate vs no gate
- **Push ≠ pull** — pipeline reaches in vs agent reaches out
- **GitOps ≠ "YAML in Git"** — reconciliation is the missing principle
- **Chart ≠ release** — the package vs one installed instance
- **Helm ≠ Kustomize** — templating vs patching
- **Helm 2 ≠ Helm 3** — Tiller vs no Tiller
- **`RollingUpdate` ≠ blue/green** — native strategy vs assembled pattern
- **Blue/green ≠ canary** — all at once vs a fraction
- **`maxSurge` ≠ `maxUnavailable`** — above the target vs below it
- **`rollout undo` ≠ `git revert`** — changes the cluster vs changes the truth
- **`rollout restart` ≠ `rollout undo`** — replace Pods vs change revision
- **Deployment ≠ ReplicaSet** — revisions vs replica count (note 03 §1.4)

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. Define CI, Continuous Delivery and Continuous Deployment. What is the single
   difference between the last two?
2. Which of the three requires the most confidence in your test suite, and why?
3. Recite the four OpenGitOps principles. Which one do people most often leave
   out, and what breaks without it?
4. Someone runs `kubectl scale` directly on a GitOps-managed cluster. What
   happens over the next few minutes, and what is the correct way to make that
   change?
5. Contrast push and pull deployment: who initiates, where the credentials live,
   and what inbound access the cluster needs.
6. Give two security advantages of pull, and one honest cost.
7. What are Argo CD and Flux? Name one structural difference. Are both CNCF
   graduated?
8. Define chart, values, release and repository.
9. What was Tiller, which Helm version required it, and why was removing it a
   security improvement?
10. How does Kustomize produce per-environment manifests without templates? What
    is a base and what is an overlay?
11. Why does Kustomize need nothing installed?
12. Give three differences between Helm and Kustomize, including which one can
    roll back.
13. Name the two native Deployment strategies. When is the one with downtime the
    correct choice?
14. Define `maxSurge` and `maxUnavailable`, give their defaults, and compute the
    maximum and minimum Pod counts for `replicas: 4` at the defaults.
15. Why is `maxSurge: 0` with `maxUnavailable: 0` rejected?
16. Are blue/green and canary Deployment strategies? If not, what are they, and
    which Kubernetes object actually moves the traffic?
17. Compare blue/green and canary on resource cost and blast radius.
18. What does `kubectl rollout undo` actually do to make the old version run
    again? Why is it the wrong rollback on a GitOps cluster?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — The rollback that kept undoing itself

A team runs Argo CD. A bad release goes out at 14:00. At 14:05 someone runs
`kubectl rollout undo deployment/api` and the old version returns. At 14:08 the
broken version is running again. Nobody deployed anything.

a. Explain exactly what happened, naming the principle responsible.
b. Which system is the source of truth here, and which one did the engineer
   change?
c. Give the correct rollback procedure, and say how long it takes compared with
   `rollout undo`.
d. Under time pressure, name one legitimate way to stop the agent fighting you,
   and the risk it creates if it is forgotten.
e. Explain why this failure mode **cannot** happen on a push-based pipeline, and
   say what that pipeline gives up in exchange.
f. A colleague concludes "GitOps makes incidents slower". Give the strongest
   version of that argument, then the strongest rebuttal.

### Drill 2 — The rollout that never finished

`kubectl rollout status deployment/web` has been blocking for 20 minutes.
`kubectl get pods` shows **3 old Pods `Running 1/1`** and **2 new Pods
`Running 0/1`** — five in total. The Deployment is `replicas: 4` with the default
surge and unavailable settings.

a. Compute `maxSurge` and `maxUnavailable` for `replicas: 4`, remembering which
   way each one rounds. Then give the maximum total Pods and the minimum
   available Pods.
b. Explain why the rollout stopped at **exactly** this state: which limit forbids
   creating a **third** new Pod, and which forbids terminating a **third** old
   one? Both are binding simultaneously — show that.
c. Walk the sequence from the starting state (4 old, 0 new) to this one, step by
   step, saying which limit permitted each action.
d. The new Pods are `Running` but not `Ready`. Which probe is involved, and what
   is it doing to the rollout? (Note 08 §1.11.)
e. Why is this **safer** than the alternative — what would `maxUnavailable: 100%`
   have done to your users?
f. Is the Service currently sending traffic to the new Pods? Justify using the
   EndpointSlice **condition** from note 05 §1.7, and say how many backends are
   actually serving.
g. Name two commands to stop the rollout: one that freezes it and one that
   reverses it. What does each leave behind?
h. The image tag was `web:latest` and the registry content changed. Name two
   separate problems that creates — one from note 04 §1.10 and one about
   diagnosing this rollout.

### Drill 3 — Choosing a strategy

Four workloads, one cluster:

- **A** — stateless HTTP API, 12 replicas, must never be fully down
- **B** — a service whose new version runs an incompatible database migration
- **C** — a payments change the team wants only 2% of users to hit first
- **D** — a batch processor reading from a `ReadWriteOncePod` volume

a. Choose a strategy or pattern for each and justify it in one sentence.
b. Which two are native `spec.strategy` values, and which two must be assembled?
c. For **B**, explain why `RollingUpdate` is dangerous, being specific about what
   coexists during it.
d. For **D**, explain what the access mode forces (note 06 §1.8) and which
   strategy it therefore requires.
e. For **C**, explain what a plain Service can and cannot do about a 2% split,
   and name two mechanisms that can.
f. For **A**, give `maxSurge` and `maxUnavailable` values that guarantee full
   capacity throughout, and state what the cluster must have for that to work
   without stalling.

### Drill 4 — Helm or Kustomize

A platform team must (i) install Prometheus, maintained by someone else, (ii)
manage their own 30 microservices across dev/staging/prod, (iii) roll back a
platform component to its previous version quickly.

a. Choose a tool for each and justify from the mechanism, not from preference.
b. For (iii), explain why one tool can do this natively and the other cannot.
   What would rollback mean for the tool that cannot?
c. For (ii), explain the argument that a Kustomize base is safer than a chart.
   Then give the strongest counter-argument.
d. They want to install the third-party chart but change one field it does not
   expose as a value. Name the approach that solves this, and which of the two
   tools performs the final step.
e. On EKS, several platform components arrive as managed add-ons instead. Name
   what that replaces from this note, and what the team loses in exchange.
