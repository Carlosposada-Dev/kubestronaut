---
exams: [KCNA]
domain: Cloud Native Architecture, Ecosystem & Community
kcna_domains: 4.2 Ecosystem and Principles + 4.3 Community and Collaboration
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: github.com/cncf/toc (Cloud Native Definition v1.1), glossary.cncf.io, landscape.cncf.io, cncf.io/projects, 12factor.net, kubernetes.io/docs/concepts/workloads/autoscaling, knative.dev, contribute.cncf.io, kubernetes.io/docs/contribute, github.com/kubernetes/enhancements (KEPs)
template: A
language: en
scope: KCNA ONLY — and permanently. No performance exam touches this domain, so this note is never reopened for CKA/CKAD/CKS
status: draft
revised: 2026-09-06 rev2 — 2026 graduation count corrected (three -> five, all named); study guidance added to §1.8; recall Q12 changed from enumeration to recognition; lab step 4 command replaced. SUPERSEDES rev1.
format: Template A per note-templates.md (the only note in the set that uses it), plus the plain-language openers from claude/depth-standard.md AMENDMENT 2026-09-01
graduated_list_verified: 2026-09-06, fetched directly from cncf.io/projects. **38 graduated projects.** This list is VOLATILE — **five graduated during 2026 alone** (Dragonfly, Kyverno, OpenTelemetry, Buildpacks, Kubeflow). Re-check before the exam.
---

# Cloud Native Architecture, Ecosystem & Community

*The only note with no `kubectl` in it. Domain 4 asks what the cloud native world
IS — its definition, its principles, its projects and the people who run them.*

Areas 4.2 and 4.3 together are **Domain 4 (12%) ≈ 7 of the 60 questions**. It is
pure vocabulary and recall, which makes it the **cheapest marks on the exam** —
and the easiest to lose by never reading it.

---

## 1. Core Concepts

### 1.1 The CNCF Cloud Native Definition v1.1

*The official paragraph. KCNA quotes its vocabulary almost word for word.*

Cloud native technologies let organisations build and run **scalable
applications** in **modern, dynamic environments** — public, private and hybrid
clouds.

| The definition's exemplars | The definition's properties |
|---|---|
| Containers, **service meshes**, **microservices**, **immutable infrastructure**, **declarative APIs** | **Loosely coupled**, **resilient**, **manageable**, **observable** |

Combined with robust automation, these allow engineers to make
**high-impact changes frequently, predictably and with minimal toil**.

Three phrases are exam bait because they appear verbatim: **"loosely coupled,
resilient, manageable, observable"**, **"minimal toil"**, and the five exemplar
technologies. Learn the two lists.

The CNCF's own stated goal is to **democratise** these patterns — to make them
available to everyone, not only to companies the size of Google.

### 1.2 Monolith vs microservices

*One deployable unit versus many small ones. The trade is simplicity for
independence, and it is a real trade in both directions.*

| | Monolith | Microservices |
|---|---|---|
| Deployment | **One unit** — all or nothing | **Independent** per service |
| Scaling | Scale the **whole** application | Scale **only the hot service** |
| Technology | One stack | Per-service choice |
| Failure | One bug can take everything down | **Isolated** — if designed for it |
| Communication | In-process function calls | **Over the network** — slow, and it can fail |
| Data | Usually one shared database | A database **per service** |
| Operational complexity | **Low** | **High** — many moving parts |
| Debugging | A single stack trace | Needs **distributed tracing** (note 09 §1.9) |

**Microservices are not automatically better**, and the exam does test that. They
trade in-process calls that cannot fail for network calls that can, and one
deployment for fifty. The honest summary: microservices buy **independence** —
of deployment, scaling and technology — and pay for it in **operational
complexity**.

### 1.3 The twelve-factor app

*A dozen rules for writing applications that survive being run in a container by
a scheduler that may kill them at any moment.*

Published as `12factor.net`, predating Kubernetes and describing exactly the app
Kubernetes runs well. The ones KCNA actually asks about:

| Factor | Says | Where you have already seen it |
|---|---|---|
| **III. Config** | Config lives in the **environment**, not in the code | ConfigMaps and Secrets (note 07 §1.10) |
| **VI. Processes** | Processes are **stateless** and share nothing | Why a Pod's writable layer is disposable (note 04 §1.10) |
| **IX. Disposability** | Fast startup, **graceful shutdown** on `SIGTERM` | The termination grace period (note 04 §1.2) |
| **XI. Logs** | Logs are an **event stream to stdout** — the app never manages files | Note 09 §1.8, and why `kubectl logs` shows nothing otherwise |
| **X. Dev/prod parity** | Keep environments as similar as possible | The same image everywhere (note 04 §1.10) |

The other seven: I. Codebase (one repo, many deploys), II. Dependencies
(declared explicitly), IV. Backing services (attached resources), V. Build /
release / run (separate stages), VII. Port binding (self-contained service),
VIII. Concurrency (scale out by process), XII. Admin processes (one-off tasks as
separate processes — a **Job**, in Kubernetes terms).

### 1.4 The four properties

*Immutable, resilient, elastic, loosely coupled. Each has a concrete Kubernetes
mechanism behind it — none is a slogan.*

| Property | Means | Mechanism you have already studied |
|---|---|---|
| **Immutability** | Never modify a running thing; **replace** it | Container images and tags/digests (note 04 §1.10). Never patch a running Pod |
| **Resilience** | Survive failure and **recover automatically** | Controllers reconciling (note 03 §1.3); probes restarting containers (note 08 §1.11) |
| **Elasticity** | Grow and shrink with demand | HPA and the Cluster Autoscaler (§1.5) |
| **Loose coupling** | Components interact through **stable interfaces**, not internals | Services and DNS instead of Pod IPs (note 05 §1.4) |

**Immutability is the one to internalise** because it explains so much of the
rest: if a running instance is never modified, then every change is a new
deployment, every rollback is a redeploy of an old artifact, and configuration
must come from outside the image. Pets versus cattle is the folk version of the
same idea.

### 1.5 Autoscaling — three kinds

*One adds Pods, one resizes Pods, one adds machines. They are constantly
confused and the exam separates them.*

| | **HPA** — Horizontal Pod Autoscaler | **VPA** — Vertical Pod Autoscaler | **Cluster Autoscaler** |
|---|---|---|---|
| Changes | **Number of Pod replicas** | **`requests`/`limits` of containers** | **Number of nodes** |
| Direction | **Out / in** | **Up / down** | Cluster grows / shrinks |
| Built in? | **Yes**, a core API | **No** — a separate project | **No** — separate, cloud-specific |
| Triggered by | CPU, memory or custom metrics | Observed usage over time | **`Pending` Pods that cannot be scheduled** |
| Needs | **metrics-server** (note 09 §1.7) | Its own recommender | Cloud API access |

The chain, which is the highest-value thing in this section:

```
load rises
    │
    ▼  HPA adds Pod replicas
more Pods → no node has enough free REQUESTS → Pods go Pending  (note 03 §1.12)
    │
    ▼  Cluster Autoscaler sees the Pending Pods
adds a node → the scheduler places them → capacity restored
```

**The Cluster Autoscaler is triggered by `Pending` Pods**, not by CPU. That is
why an unschedulable Pod is the signal it watches for, and why on a kubeadm
cluster with no autoscaler the Pod simply stays Pending forever — the EKS habit
note 03 §7 warned about.

**HPA and VPA on the same metric conflict**: HPA sees high CPU and adds replicas,
VPA raises requests for the same reason, and they fight. Running both on CPU is a
documented anti-pattern.

**KEDA** (CNCF **graduated**) extends the HPA to event-driven sources — queue
length, Kafka lag, cron — and can scale to zero, which the plain HPA cannot.

### 1.6 Serverless, FaaS and Knative

*You still run on servers. You just stop being the one who thinks about them.*

| Term | Is |
|---|---|
| **Serverless** | A model where the **provider manages the servers**, capacity scales automatically, and you pay for **actual use** |
| **FaaS** — Function as a Service | A **subset** of serverless: deploy a **single function**, triggered by an event |
| **Scale to zero** | No traffic, **no running instances, no cost** — the defining serverless capability |
| **Cold start** | The latency of starting an instance after scaling to zero. The main trade-off |

**Knative** (CNCF **graduated**) brings the serverless model to Kubernetes:

| Component | Does |
|---|---|
| **Knative Serving** | Request-driven autoscaling **including scale to zero**, and revision management |
| **Knative Eventing** | Delivering and routing events between services, using **CloudEvents** |

The distinction the exam wants: **serverless is the model, FaaS is one shape of
it, and Knative is an implementation on Kubernetes.** AWS Lambda is FaaS; Knative
Serving runs whole containers, so it is serverless without being FaaS.

### 1.7 The CNCF Landscape

*A map of the ecosystem, grouped by the problem each project solves. Nobody
memorises it — you memorise the categories.*

`landscape.cncf.io` catalogues **hundreds** of projects and products. Do not try
to learn it. Learn the **layers**, which mirror the order you studied them:

| Layer | Contains | Notes covered |
|---|---|---|
| **Provisioning** | Automation, image build, security & compliance, key management | 04, 07 |
| **Runtime** | Container runtime, cloud native storage, cloud native network | 04, 05, 06 |
| **Orchestration & Management** | Scheduling & orchestration, service mesh, service proxy, API gateway, coordination & service discovery | 03, 05 |
| **App Definition & Development** | Databases, streaming & messaging, app definition, CI/CD | 10 |
| **Observability & Analysis** | Observability, chaos engineering, continuous optimisation | 09 |
| **Platform** (cross-cutting) | Certified Kubernetes distributions, PaaS, hosted platforms | — |

### 1.8 Maturity levels, and the Graduated list

*Three levels, and the Technical Oversight Committee decides who moves between
them.*

| Level | Means | Adoption signal |
|---|---|---|
| **Sandbox** | Early, experimental. Entry point | Innovators |
| **Incubating** | Proven in production by **at least three** end users, healthy contributor base | Early adopters |
| **Graduated** | Highest level: independent **security audit**, documented **governance**, broad adoption, **OpenSSF/CII Best Practices badge**, CNCF Code of Conduct | Early majority |

**The TOC — Technical Oversight Committee — makes the decision**, not the
Governing Board. That is a near-guaranteed question.

**The 38 Graduated projects**, verified directly from `cncf.io/projects` on
**2026-09-06**:

| | | | |
|---|---|---|---|
| Argo | CloudEvents | Harbor | OpenTelemetry |
| Buildpacks | containerd | Helm | Prometheus |
| cert-manager | CoreDNS | in-toto | Rook |
| Cilium | CRI-O | Istio | SPIFFE |
| Crossplane | CubeFS | Jaeger | SPIRE |
| Dapr | Dragonfly | KEDA | TUF |
| Envoy | etcd | Knative | TiKV |
| Falco | Fluentd | KubeEdge | Vitess |
| Flux | Kubeflow | Kubernetes | |
| | Kyverno | Linkerd | |
| | OPA | | |

**This list is volatile — treat the date as part of the fact.** **Five projects
graduated in 2026 alone**, verified against the CNCF announcements:

| Project | Graduated |
|---|---|
| **Dragonfly** | 14 Jan 2026 |
| **Kyverno** | 24 Mar 2026 |
| **OpenTelemetry** | 21 May 2026 |
| **Buildpacks** | 11 Aug 2026 |
| **Kubeflow** | 17 Aug 2026 |

Five in eight months is the whole argument for distrusting any pre-2026 study
material here — most of it still lists OpenTelemetry as incubating. **Re-check
`cncf.io/projects` before the exam** rather than trusting this table.

**How to study this list — and it is not by memorising 38 names.** KCNA tests
**recognition**, not enumeration: questions give you names and ask which is
graduated, or which is not a CNCF project at all. So spend recall time on two
things only:

1. **The ~12 you have already used** in the other ten notes — Kubernetes,
   containerd, etcd, CoreDNS, Prometheus, Helm, Envoy, Fluentd, Jaeger,
   OpenTelemetry, Argo, Flux. You know what they do; you only need their level.
2. **The surprises table below, in full.** That is where the marks per minute
   are, because those are exactly the names an exam writer picks for a
   distractor.

The remaining ~26 are worth one read for familiarity and nothing more.

**The high-value surprises — things that are NOT graduated:**

| Project | Actual level | Why it catches people |
|---|---|---|
| **CNI** (Container Network Interface) | **Incubating** | You use it daily (note 05 §1.3). CSI and CRI are not CNCF projects at all |
| **gRPC** | **Incubating** | Ubiquitous, and still not graduated |
| **Backstage** | **Incubating** | Very high profile |
| **OpenCost** | **Incubating** | Note 09 §1.13 |
| **Keycloak**, **Tekton**, **Thanos**, **NATS**, **KubeVirt** | **Incubating** | All well known |
| **Grafana** | **Not a CNCF project at all** | Note 09 §1.11 |

Two from your own out-of-scope list are graduated: **Istio** and **Kyverno**.
Knowing their maturity is in scope; operating them is not, until 1 Dec.

### 1.9 Open standards

*Interfaces that let Kubernetes stay small: the contract is in-tree, the
implementation is not. You have met four of them already.*

| Standard | Between | Implementations | Owner |
|---|---|---|---|
| **OCI** — Open Container Initiative | Image format and runtime behaviour | runc, crun, containerd images | **Linux Foundation**, not CNCF |
| **CRI** — Container Runtime Interface | kubelet ↔ runtime | containerd, CRI-O | Kubernetes |
| **CNI** — Container Network Interface | Runtime ↔ network plugin | Calico, Cilium, Flannel | **CNCF, incubating** |
| **CSI** — Container Storage Interface | Kubernetes ↔ storage driver | EBS CSI, Ceph, Longhorn | Kubernetes / cross-industry |
| **OpenTelemetry** | Apps ↔ observability backends | The OTel SDKs and Collector | **CNCF, graduated** |
| **SMI** — Service Mesh Interface | Apps ↔ service mesh | *(historical)* | **Archived by CNCF** — see below |

**The pattern is the single most valuable idea in this note**, because you have
now seen it four times: **the interface lives in Kubernetes; the implementation
lives outside it.** That is how one project supports every runtime, every
network plugin and every storage vendor without containing code for any of them.

**On SMI:** the KCNA curriculum lists it among the open standards, but SMI is
**no longer an active CNCF project** — it does not appear on the graduated or
incubating lists, and its role was largely absorbed by the **Gateway API**
(note 05 §1.11). Know what SMI *was* — a standard interface for service mesh
features — and know that it is historical. This is one place where the published
curriculum has aged.

### 1.10 How the CNCF is governed

*Three bodies, three jobs. Knowing which one decides what is the whole question.*

| Body | Responsible for |
|---|---|
| **Governing Board (GB)** | **Business**: marketing, budget, membership. **Not technical decisions** |
| **Technical Oversight Committee (TOC)** | **Technical vision**, accepting projects, and **moving them between maturity levels** |
| **End User Technical Advisory Board (End User TAB)** | The **voice of end users** — organisations that consume rather than sell cloud native tech |

The CNCF is part of the **Linux Foundation**, a non-profit. Kubernetes was the
**first** project donated, by Google, in 2015 — the CNCF was founded to host it.

**The exam question is almost always "who decides on graduation?"** and the
answer is the **TOC**. The Governing Board handles money and marketing.

### 1.11 TAGs, SIGs, WGs and KEPs

*Two different organisations, two different vocabularies, easily mixed up.*

| Group | Belongs to | Is |
|---|---|---|
| **TAG** — Technical Advisory Group | **The CNCF** | Advises the **TOC** on a domain — Security, Observability, Network. **Formerly called CNCF SIGs** |
| **SIG** — Special Interest Group | **Kubernetes** | Owns an **area of the project** — sig-network, sig-node, sig-storage. Persistent |
| **WG** — Working Group | **Kubernetes** | **Cross-SIG** and **time-bounded** — dissolves when the goal is met |
| **KEP** — Kubernetes Enhancement Proposal | **Kubernetes** | The **design document** every significant change must go through |

**TAG belongs to the CNCF; SIG belongs to Kubernetes.** The rename from "CNCF
SIG" to "TAG" exists precisely to stop the confusion, which tells you the exam
finds it worth asking.

**A KEP is why nothing lands by surprise.** Every feature you have met with a
version number — dockershim's removal, PSP's replacement, the cgroup v2 move —
went through a KEP with motivation, design and a graduation plan from alpha to
beta to stable (note 02 §1.3).

### 1.12 The contributor ladder

*Four rungs, and the distinction that matters is who can approve a merge.*

| Role | Can |
|---|---|
| **Contributor** | Open issues and pull requests. Anyone |
| **Member** | An established contributor, formally recognised in the org |
| **Reviewer** | Review code in an area and comment `/lgtm` — "looks good to me" |
| **Approver** | **Approve merges** in an area — `/approve`. The gate |
| **Maintainer / Owner** | Set direction, own the project's governance |

**Reviewer ≠ approver.** A reviewer says the code is good; an **approver** is the
one whose sign-off actually merges it. Both are recorded in `OWNERS` files in the
Kubernetes repository.

Every CNCF project adopts the **CNCF Code of Conduct** — it is one of the
requirements for graduation, alongside the security audit and the governance
documentation.

### 1.13 Licences

*Kubernetes is Apache 2.0. The distinction to know is permissive versus copyleft.*

| | **Permissive** | **Copyleft** |
|---|---|---|
| Examples | **Apache 2.0**, MIT, BSD | **GPL**, AGPL, LGPL |
| Can you use it in closed-source software? | **Yes** | **Only under conditions** |
| Must you publish your changes? | **No** | **Yes** — derivative works inherit the licence |
| Typical in CNCF | **Almost everything** | Rare |

**Kubernetes and nearly all CNCF projects use Apache 2.0.** What distinguishes it
from MIT is an **explicit patent grant**: contributors grant a licence to their
relevant patents, which is why enterprises are comfortable adopting it. That
patent clause is the exam-worthy detail.

### 1.14 The personas

*Four job shapes the curriculum names. The boundaries are fuzzy in real life and
tidy on the exam.*

| Persona | Optimises for | Typically does |
|---|---|---|
| **Developer** | Shipping features | Writes the application, owns its code and tests |
| **DevOps Engineer** | Flow from commit to production | CI/CD pipelines, automation, breaking the dev/ops wall |
| **SRE** — Site Reliability Engineer | **Reliability as a measurable target** | SLIs, SLOs, error budgets (note 09 §1.12), incident response, toil reduction |
| **Platform Engineer** | **Developer experience** | Builds the internal platform other teams deploy onto; treats the platform as a product |

**SRE is the one with a definition rather than a vibe:** it applies software
engineering to operations, and its distinguishing artefacts are the **SLO and the
error budget**. If a question mentions error budgets, it is asking about SRE.

---

## 2. Key Components

| Component | Function | When it appears |
|---|---|---|
| **CNCF** | Non-profit under the Linux Foundation hosting cloud native projects | Everywhere in Domain 4 |
| **TOC** | Technical vision; **decides project maturity** | "Who approves graduation?" |
| **Governing Board** | Budget, marketing, membership | The distractor for the TOC |
| **End User TAB** | Voice of end users | Third body in the structure |
| **TAG** | CNCF advisory group per domain | vs Kubernetes SIG |
| **KEP** | Kubernetes design proposal process | Feature graduation alpha→beta→stable |
| **Landscape** | Categorised map of the ecosystem | "Which category does X belong to?" |
| **Glossary** | `glossary.cncf.io` — the exam's own vocabulary | Many questions are phrased from it |
| **HPA / VPA / Cluster Autoscaler** | Replicas / sizes / nodes | The three-way distinction |
| **Knative** | Serverless on Kubernetes, scale to zero | Serverless questions |
| **KEDA** | Event-driven autoscaling, scale to zero | HPA's extension |

---

## 3. Operational Patterns

```
Which autoscaler?
├─ "too much load, need more copies"        → HPA          (replicas)
├─ "the Pods are the wrong SIZE"            → VPA          (requests/limits)
└─ "Pods are Pending, nowhere to put them"  → Cluster Autoscaler (nodes)

Which maturity level?
├─ experimental, few users                  → Sandbox
├─ production use, ≥3 end users             → Incubating
└─ security audit + governance + adoption   → Graduated     (decided by the TOC)

Which body decides?
├─ budget, marketing, membership            → Governing Board
├─ project maturity, technical vision       → TOC
└─ end-user representation                  → End User TAB

TAG or SIG?
├─ CNCF, advises the TOC, per domain        → TAG   (formerly CNCF SIG)
├─ Kubernetes, owns an area, permanent      → SIG
└─ Kubernetes, cross-SIG, time-bounded      → Working Group
```

---

## 4. Hands-On

*Minimal by design — this domain has almost no commands. **Target: 10 minutes.**
The value is in having once seen the real sources.*

```bash
# 1. Read the Cloud Native Definition in full. It is one paragraph.
#    github.com/cncf/toc  →  DEFINITION.md

# 2. Open cncf.io/projects and count the Graduated projects yourself.
#    Compare against §1.8. If the number is not 38, the list has moved.

# 3. Open landscape.cncf.io, filter by "Graduated", and look at the CATEGORIES.
#    Name the layer for: Cilium, Harbor, Argo, Falco, Vitess.

# 4. The only cluster commands here. Run BOTH and compare — together they prove
#    the HPA is core Kubernetes and the other two autoscalers are not:
kubectl api-resources | grep -i horizontalpodautoscaler   # autoscaling/v2 — built in
kubectl api-resources | grep -i verticalpodautoscaler     # EMPTY — VPA is not core
kubectl api-resources | grep -i clusterautoscaler         # EMPTY — nor is the CA
```

---

## 5. Exam Intelligence

*Keyword → answer mappings. Domain 4 is recognition, so these are worth more
than reasoning here.*

| If the question says | The answer involves |
|---|---|
| "loosely coupled, resilient, manageable, observable" | The **Cloud Native Definition v1.1** |
| "minimal toil" | The Definition, or **SRE** |
| "error budget", "SLO" | **SRE** (note 09 §1.12) |
| "who approves graduation" | The **TOC** |
| "budget", "marketing", "membership" | The **Governing Board** |
| "formerly a CNCF SIG" | A **TAG** |
| "cross-SIG, time-bounded" | A **Working Group** |
| "design proposal", "alpha to beta to stable" | A **KEP** |
| "scale to zero" | **Serverless / Knative / KEDA** |
| "adds nodes" | **Cluster Autoscaler** |
| "adjusts requests and limits" | **VPA** |
| "adds replicas" | **HPA** |
| "config in the environment", "logs to stdout" | **Twelve-factor app** |
| "never modify, replace" | **Immutability** |
| "patent grant" | **Apache 2.0** |
| "derivative works must be published" | **Copyleft / GPL** |
| "developer experience", "platform as a product" | **Platform Engineer** |

---

## 6. Exam Traps

| Distractor | Why it's wrong |
|---|---|
| "The Governing Board decides project graduation" | The **TOC** does. The GB handles business |
| "A TAG is a Kubernetes group" | TAG = **CNCF**. SIG = **Kubernetes** |
| "SIGs are time-bounded" | SIGs are permanent; **Working Groups** are time-bounded |
| "Incubating requires a security audit" | That is **Graduated**. Incubating needs ≥3 production end users |
| "Serverless means there are no servers" | The **provider** manages them. You still run on servers |
| "FaaS and serverless are the same" | FaaS is a **subset** of serverless |
| "Knative is a FaaS platform only" | Knative Serving runs **whole containers** |
| "HPA changes CPU and memory requests" | That is the **VPA**. HPA changes **replica count** |
| "The Cluster Autoscaler reacts to high CPU" | It reacts to **`Pending` Pods** |
| "VPA is built into Kubernetes" | **HPA is.** VPA and the Cluster Autoscaler are separate projects |
| "Run HPA and VPA on CPU together for best results" | They **conflict**. Documented anti-pattern |
| "Microservices are always better than a monolith" | A trade: independence for **operational complexity** |
| "Twelve-factor says store config in a config file in the image" | **In the environment** |
| "OCI is a CNCF project" | **Linux Foundation**, not CNCF |
| "CNI is a graduated CNCF project" | **Incubating** |
| "Grafana is a CNCF project" | It is not (note 09 §1.11) |
| "OpenTelemetry is incubating" | **Graduated 21 May 2026** |
| "Apache 2.0 is copyleft" | **Permissive**, with an explicit **patent grant** |
| "A reviewer can approve a merge" | An **approver** can. The reviewer gives `/lgtm` |
| "Kubernetes is GPL" | **Apache 2.0** |

**X ≠ Y**

- **Governing Board ≠ TOC** — business vs technical, and only the TOC graduates projects
- **TAG ≠ SIG** — CNCF vs Kubernetes
- **SIG ≠ Working Group** — permanent area vs time-bounded, cross-SIG effort
- **Sandbox ≠ Incubating ≠ Graduated** — experimental / ≥3 production users / audited
- **HPA ≠ VPA ≠ Cluster Autoscaler** — replicas / sizes / nodes
- **Serverless ≠ FaaS** — the model vs one shape of it
- **Monolith ≠ microservices** — simplicity vs independence, both real trades
- **Permissive ≠ copyleft** — Apache/MIT vs GPL
- **Reviewer ≠ approver** — `/lgtm` vs `/approve`
- **OCI ≠ CRI ≠ CNI ≠ CSI** — image and runtime format / runtime API / network / storage
- **Interface ≠ implementation** — in-tree contract vs out-of-tree plugin
- **SRE ≠ DevOps Engineer** — reliability as a measured target vs flow to production

---

## 7. EKS / AWS Equivalency Map

| Cloud native concept | AWS equivalent | Key difference |
|---|---|---|
| Cluster Autoscaler | **Karpenter**, or the CA with an ASG | Karpenter picks instance types per Pod instead of scaling fixed groups. **Neither exists on kubeadm** |
| HPA | Identical — it is core Kubernetes | Needs metrics-server on both (note 09 §1.7) |
| Serverless / FaaS | **AWS Lambda** | Lambda is FaaS with no Kubernetes. Knative brings the model **into** the cluster |
| Knative | AWS App Runner / Fargate, loosely | Knative runs **on your cluster** and is portable |
| OpenCost | **Cost Explorer** + tags | OpenCost attributes cost **per namespace and Pod**; AWS bills per instance |
| CNCF Landscape | The AWS service catalogue | One is vendor-neutral and portable; the other is not |

The honest framing: nearly every AWS managed service has a cloud native
equivalent that runs anywhere, and the trade is **convenience versus
portability**. KCNA is written from the portable side, so when a question offers
a vendor-specific answer and a neutral one, the neutral one is usually correct.

---

## 8. Objectives Covered

KCNA areas **4.2** and **4.3**.

- [ ] The CNCF Cloud Native Definition v1.1 — both vocabulary lists
- [ ] Microservices vs monolith, and what each trades away
- [ ] The twelve-factor app — at minimum config, logs, processes, disposability
- [ ] Immutability, resilience, elasticity, loose coupling
- [ ] HPA vs VPA vs Cluster Autoscaler, and what triggers each
- [ ] Serverless, FaaS, Knative, scale to zero, cold start
- [ ] The CNCF Landscape — the layers, not the projects
- [ ] Sandbox → Incubating → **Graduated**, and that the **TOC** decides
- [ ] The Graduated list — **verified 2026-09-06, re-check before the exam**
- [ ] Open standards: OCI, CRI, CNI, CSI, OpenTelemetry (and SMI as historical)
- [ ] CNCF structure: Governing Board, TOC, End User TAB
- [ ] TAGs vs Kubernetes SIGs vs Working Groups vs KEPs
- [ ] Contributor ladder: contributor, member, reviewer, approver, maintainer
- [ ] Apache 2.0; permissive vs copyleft; the patent grant
- [ ] Code of conduct as a graduation requirement
- [ ] Personas: Developer, DevOps Engineer, SRE, Platform Engineer

---

## 9. Practice Questions

*Exam-style. Each explains why the wrong options are wrong — that is the point.*

**1. A project has completed an independent security audit, documented its
governance and has adoption across many organisations. Which body moves it to
Graduated?**

A. The Governing Board · B. The Technical Oversight Committee · C. The End User
TAB · D. The Linux Foundation Board

> **B.** The TOC owns technical direction and project maturity. **A** handles
> budget, marketing and membership — never technical decisions. **C** represents
> end users advisorily and decides nothing about projects. **D** governs the
> Linux Foundation, not CNCF project maturity.

**2. A Deployment's Pods are `Pending` because no node has enough allocatable
CPU. Which component is designed to react?**

A. HPA · B. VPA · C. Cluster Autoscaler · D. metrics-server

> **C.** The Cluster Autoscaler watches for **unschedulable Pods** and adds
> nodes. **A** would add more Pods, worsening it. **B** would change requests —
> possibly helping by accident, but it reacts to usage, not to Pending. **D** only
> supplies metrics; it takes no action.

**3. Which statement about serverless is correct?**

A. There are no servers · B. All serverless is FaaS · C. Scale to zero means no
instances run when there is no traffic · D. Knative cannot scale to zero

> **C.** **A** is the classic misreading — the *provider* manages the servers.
> **B** inverts the relationship: FaaS is a subset of serverless. **D** is false;
> scale to zero is Knative Serving's headline capability.

**4. Which pair is correctly matched?**

A. TAG — a Kubernetes group · B. Working Group — permanent, owns an area ·
C. KEP — the Kubernetes design proposal process · D. SIG — advises the CNCF TOC

> **C.** **A** and **D** are swapped: TAGs are CNCF and advise the TOC; SIGs are
> Kubernetes. **B** describes a **SIG**; Working Groups are cross-SIG and
> time-bounded.

**5. Why do enterprises favour Apache 2.0 over MIT for a project like
Kubernetes?**

A. It is copyleft · B. It contains an explicit patent grant · C. It forbids
commercial use · D. It requires publishing derivative works

> **B.** The explicit patent grant is Apache 2.0's distinguishing feature. **A**
> is wrong — it is permissive. **C** is wrong; permissive licences allow
> commercial use. **D** describes **copyleft**, which Apache 2.0 is not.

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. Recite the four properties from the Cloud Native Definition v1.1, and name
   three of its five exemplar technologies.
2. Give two things microservices buy you and two things they cost you.
3. Name four of the twelve factors, and for each say which Kubernetes feature
   implements it.
4. Define immutability, and explain why it forces configuration out of the image.
5. Name the three autoscalers, what each changes, and which is built into
   Kubernetes.
6. What triggers the Cluster Autoscaler? Why is it not CPU?
7. Trace the chain from a traffic spike to a new node, naming each component.
8. Why is running HPA and VPA on CPU together an anti-pattern?
9. Define serverless, FaaS and scale to zero, and state the relationship between
   the first two. What is the main trade-off?
10. What are Knative's two components, and what does each do?
11. Name the three CNCF maturity levels, what Graduated additionally requires,
    and which body decides.
12. Of these six — **Cilium, Backstage, Harbor, gRPC, Falco, OpenCost** — say
    which are Graduated and which are Incubating. Then: roughly how many
    projects graduated during 2026, and name two of them.
13. Name three well-known projects that are **not** Graduated, and one that is
    not a CNCF project at all.
14. Name the four open standards you have studied, what each sits between, and
    which is not a CNCF project.
15. State the pattern all four share in one sentence.
16. Name the three CNCF governing bodies and one responsibility each.
17. Distinguish TAG, SIG, Working Group and KEP.
18. Distinguish reviewer from approver. And: which licence is Kubernetes, is it
    permissive or copyleft, and what is its distinguishing clause?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — Scaling the wrong dimension

A service handles a traffic spike badly. Latency rises, CPU sits at 95%, and
`kubectl top` shows each Pod using far more memory than it requests. There are 3
replicas on a 3-node cluster that is 90% committed on requests.

a. Name each autoscaler and state precisely what each would do here.
b. Which one addresses the CPU symptom, and what happens **next** given the 90%
   commitment? Name the Pod state and the note that explains it.
c. Which addresses the memory-versus-requests mismatch, and why is it a different
   kind of fix?
d. The team enables HPA and VPA, both on CPU. Describe the conflict concretely —
   what does each observe and do?
e. Without the third autoscaler on a kubeadm cluster, what is the end state? Cite
   the EKS habit this breaks.
f. Rank the three by what you would enable first here, and defend the ordering.

### Drill 2 — Is this cloud native?

A team claims their application is cloud native. It is one deployable unit; it
reads config from a file baked into the image; it writes logs to
`/var/log/app.log`; it is upgraded by SSH-ing in and patching files; and it keeps
session state in memory on each instance.

a. Test it against the four properties of the Definition. Which does it fail, and
   why for each?
b. Identify the twelve-factor violations by number and name — there are at least
   four.
c. For the logging violation, name two concrete consequences you already studied,
   one from note 08 and one from note 09.
d. "Upgraded by SSH-ing in and patching" violates which single property most
   directly? What is the cloud native replacement, and which note describes the
   artifact involved?
e. In-memory session state breaks which factor, and what does it prevent the
   platform from doing safely?
f. Being a monolith is on the list of complaints. Argue that this is the **least**
   serious problem here, then give the strongest counter-argument.

### Drill 3 — Reading the ecosystem correctly

Your team proposes four tools: **Cilium** for networking, **Backstage** as a
developer portal, **OpenCost** for cost visibility, and **Grafana** for
dashboards. Leadership asks for the risk profile of each.

a. Give the CNCF maturity of each. Which one is not a CNCF project at all?
b. Explain what Graduated actually guarantees, listing the specific requirements
   — and what it does **not** guarantee.
c. Two are Incubating. State what that level does guarantee about production use.
d. For the non-CNCF tool, explain what you lose and why it is still a defensible
   choice.
e. Cilium implements a standard. Name it, name its maturity level, and explain
   why the standard being incubating does not make Cilium risky.
f. State the interface-versus-implementation pattern and apply it to all four
   tools, saying which are implementations of a standard and which are not.

### Drill 4 — Who decides, and how does it ship?

A contributor wants a new Kubernetes field, and separately wants their own
project accepted by the CNCF.

a. Name the document required for the Kubernetes change, and the three
   graduation stages the feature itself will pass through (note 02 §1.3).
b. Which Kubernetes group owns the review? Distinguish it from the group that
   would form if the change spanned several areas.
c. On the pull request, one person comments `/lgtm` and another `/approve`.
   Name both roles and say which one causes the merge.
d. For the CNCF project: name the body that accepts it, the entry maturity level,
   and three concrete requirements for reaching Graduated.
e. Leadership asks the Governing Board to fast-track the graduation. Explain why
   that request is addressed to the wrong body.
f. The project is Apache 2.0. Name one reason an enterprise legal team prefers
   that over MIT, and one over GPL.
