# kcna-curriculum.md — Objective tracker

> Official curriculum: github.com/cncf/curriculum → `kcna/`
> Version consulted: 2026-08-14 · **Exam target: Thu 10 Sep 2026** (see plan.md §4)
> Format: online, proctored, multiple-choice, 90 minutes, 60 questions, >75% to pass.
> Status table last reconciled: **2026-09-06** — all 11 notes written.

## Note on official granularity

Unlike CKA, **the official KCNA curriculum publishes only 4 domains and 13
sub-areas. There are no finer bullets.** Everything listed under each sub-area
below is a *derived* list — built from the resources CNCF itself recommends
(LFS250 / LFS158) and from the official documentation. It is a reasonable
coverage guide, **not** the official text. Do not treat it as a contract.

Tick `[x]` only when the concept is written in its canonical note **and** you
can explain it without looking.

---

## Domain 1 — Kubernetes Fundamentals (44%)

### 1.1 Kubernetes Core Concepts → notes `01`, `02`
- [ ] What problem an orchestrator solves; declarative vs imperative
- [ ] Reconciliation loop / desired state vs current state
- [ ] Control plane components: kube-apiserver, etcd, kube-scheduler, kube-controller-manager, cloud-controller-manager
- [ ] Node components: kubelet, kube-proxy, container runtime
- [ ] etcd: what it stores, why it is the only stateful component, quorum
- [ ] The API server as the only client of etcd
- [ ] Objects: Pod, ReplicaSet, Deployment, Service, Namespace
- [ ] Object structure: apiVersion, kind, metadata, spec, status
- [ ] Labels, selectors, annotations — and how they differ
- [ ] API groups, versioning (alpha/beta/stable), CRDs and operators
- [ ] kubectl: get / describe / logs / exec / apply / delete

### 1.2 Administration → notes `01`, `07`
- [ ] kubeadm: init, join, what each generates
- [ ] Static Pods and `/etc/kubernetes/manifests/`
- [ ] kubeconfig: clusters, users, contexts
- [ ] Authentication (x509, tokens, ServiceAccounts) vs authorization (RBAC)
- [ ] Role / ClusterRole / RoleBinding / ClusterRoleBinding
- [ ] Namespaces, ResourceQuota, LimitRange
- [ ] Notion of cluster upgrade and of drain/cordon

### 1.3 Scheduling → note `03`
- [ ] What the kube-scheduler does: filtering (predicates) → scoring (priorities)
- [ ] `nodeSelector` vs node affinity vs pod affinity/anti-affinity
- [ ] Taints and tolerations — and why they are NOT the same as affinity
- [ ] Resource requests vs limits; their effect on scheduling
- [ ] QoS classes: Guaranteed / Burstable / BestEffort
- [ ] Why a Pod stays `Pending`
- [ ] DaemonSet, StatefulSet, Job, CronJob — when to use each

### 1.4 Containerization → note `04`
- [ ] Container vs virtual machine; Linux namespaces and cgroups
- [ ] OCI: image spec, runtime spec, distribution spec
- [ ] runc as the low-level runtime
- [ ] CRI: what it is and why it exists
- [ ] containerd and CRI-O; **dockershim was removed in 1.24**
- [ ] Images: layers, registries, tags vs digests
- [ ] Basic Dockerfile; minimal images (distroless, scratch)
- [ ] Image security: non-root, never `:latest`

---

## Domain 2 — Container Orchestration (28%)

### 2.1 Networking → note `05`
- [ ] Kubernetes network model: one IP per Pod, no NAT between Pods
- [ ] CNI: what the spec is, what a plugin does (Calico, Cilium, Flannel)
- [ ] Service: ClusterIP, NodePort, LoadBalancer, ExternalName
- [ ] Headless Service
- [ ] kube-proxy: iptables vs IPVS
- [ ] CoreDNS and the FQDN format `svc.ns.svc.cluster.local`
- [ ] Ingress vs Service; Ingress Controller
- [ ] Gateway API (successor to Ingress) — at minimum, what it is
- [ ] NetworkPolicy: default allow, and what changes on the first policy
- [ ] Service mesh: control plane vs data plane, sidecar, mTLS

### 2.2 Security → note `07`
- [ ] The 4C's: Cloud, Cluster, Container, Code
- [ ] Authentication / Authorization / Admission Control (the order matters)
- [ ] RBAC in depth; ServiceAccount and its token
- [ ] Secrets vs ConfigMaps; **Secrets are base64, not encrypted by default**
- [ ] SecurityContext: runAsNonRoot, readOnlyRootFilesystem, capabilities
- [ ] Pod Security Admission (privileged/baseline/restricted) — replaced PSP
- [ ] Admission controllers: mutating vs validating

### 2.3 Troubleshooting → note `08`
- [ ] Pod phases: Pending, Running, Succeeded, Failed, Unknown
- [ ] Container states: CrashLoopBackOff, ImagePullBackOff, ErrImagePull, OOMKilled, CreateContainerConfigError
- [ ] `kubectl describe` → Events section as the first step
- [ ] `kubectl logs`, `--previous`, `-c <container>`
- [ ] `kubectl exec`, `port-forward`
- [ ] Node `NotReady`: kubelet, disk, network
- [ ] Probes: liveness / readiness / startup, and what breaks when misconfigured

### 2.4 Storage → note `06`
- [ ] Ephemeral volumes: emptyDir, configMap, secret, downwardAPI
- [ ] PersistentVolume, PersistentVolumeClaim and the binding between them
- [ ] StorageClass and dynamic provisioning
- [ ] Access modes: RWO, ROX, RWX, RWOP
- [ ] Reclaim policy: Retain / Delete
- [ ] CSI: why it replaced in-tree drivers
- [ ] Storage in a StatefulSet: volumeClaimTemplates

---

## Domain 3 — Cloud Native Application Delivery (16%)

### 3.1 Application Delivery → note `10`
- [ ] CI vs CD vs Continuous Deployment
- [ ] GitOps: the **4 OpenGitOps principles** (declarative, versioned and immutable, pulled automatically, continuously reconciled)
- [ ] Push-based vs pull-based deployment
- [ ] Argo CD and Flux — **only what they are and how they differ**
- [ ] Helm: chart, values, release, templating
- [ ] Kustomize: bases and overlays; why it uses no templates
- [ ] Strategies: RollingUpdate, Recreate, blue/green, canary
- [ ] `maxSurge` and `maxUnavailable`
- [ ] Rollback: `kubectl rollout undo`

### 3.2 Debugging → note `08`
- [ ] Debugging the app vs debugging the cluster
- [ ] Ephemeral containers / `kubectl debug`
- [ ] Reading namespace events sorted by time
- [ ] Telling image / config / resource / network failures apart

---

## Domain 4 — Cloud Native Architecture (12%)

### 4.1 Observability → note `09`
- [ ] The three pillars: metrics, logs, traces
- [ ] Observability ≠ monitoring
- [ ] Prometheus: **pull** model, exporters, Alertmanager, basic PromQL
- [ ] Metric types: counter, gauge, histogram, summary
- [ ] Grafana as the visualisation layer
- [ ] OpenTelemetry: one standard for all three signals
- [ ] Jaeger, Fluentd / Fluent Bit
- [ ] metrics-server vs Prometheus (`kubectl top` comes from the former)
- [ ] SLI / SLO / SLA and error budgets
- [ ] FinOps / cost management — yes, it appears in KCNA

### 4.2 Cloud Native Ecosystem and Principles → note `11`
- [ ] CNCF Cloud Native Definition (v1.1)
- [ ] Microservices vs monolith; the 12-factor app
- [ ] Immutability, resilience, elasticity, loose coupling
- [ ] Autoscaling: HPA, VPA, Cluster Autoscaler — and how they differ
- [ ] Serverless, FaaS, Knative
- [ ] CNCF Landscape: the main categories
- [ ] Maturity levels: Sandbox → Incubating → **Graduated** (memorise the Graduated list)
- [ ] Open standards: OCI, CRI, CNI, CSI, SMI, OpenTelemetry

### 4.3 Cloud Native Community and Collaboration → note `11`
- [ ] CNCF structure: Governing Board, **TOC**, End User Community
- [ ] CNCF TAGs (formerly CNCF-level SIGs)
- [ ] Kubernetes SIGs, Working Groups, KEPs
- [ ] Roles: contributor, maintainer, reviewer, approver
- [ ] Open source licences: Apache 2.0 (Kubernetes'), permissive vs copyleft
- [ ] Code of conduct, contributor ladders
- [ ] Personas: Platform Engineer, SRE, DevOps Engineer, Developer

---

## Status by canonical note

**All 11 notes are written.** Note filenames use the `notes_` prefix so they
land in the project's notes folder — the `notes/NN-` paths used earlier in this
file's history were never the real filenames.

| Note | KCNA domains | Written | Lines | §10 recall done |
|---|---|---|---|---|
| `notes_01-cluster-architecture.md` | 1.1, 1.2 | ✅ 2026-08-16 | 1063 | ✅ 23 Aug — 20/36 |
| `notes_02-api-and-objects.md` | 1.1 | ✅ 2026-08-22 | 1001 | ✅ 23 Aug — 17/23 (74%) |
| `notes_03-workloads-and-scheduling.md` | 1.3 | ✅ 2026-08-31 | 616 | ✅ 1 Sep — 14/18 |
| `notes_04-containers-and-runtimes.md` | 1.4 | ✅ 2026-09-01 | 640 | ☐ |
| `notes_05-networking.md` | 2.1 | ✅ 2026-09-02 | 737 | ☐ |
| `notes_06-storage.md` | 2.4 | ✅ 2026-09-03 | 660 | ☐ |
| `notes_07-security-and-rbac.md` | 1.2, 2.2 | ✅ 2026-09-04 | 848 | ☐ |
| `notes_08-troubleshooting-and-debugging.md` | 2.3, 3.2 | ✅ 2026-09-05 | 708 | ☐ |
| `notes_09-observability.md` | 4.1 | ✅ 2026-09-05 | 650 | ☐ |
| `notes_10-application-delivery.md` | 3.1 | ✅ 2026-09-06 | 625 | ☐ |
| `notes_11-cloud-native-architecture.md` | 4.2, 4.3 | ✅ 2026-09-06 | 697 | ☐ |

**Total: 8,245 lines across 11 notes. All 13 curriculum sub-areas covered.**

### What "written" does and does not mean

A ✅ in the *Written* column means the note exists and its §9 objectives map to
the curriculum. It does **not** mean the material is learned. That is what the
*§10 recall* column tracks, and it is the honest picture right now: **3 of 11
notes have been recalled closed-book.** Note production finishing is not the
same as Block 1 finishing.

The objective checkboxes higher up this file stay unticked until you can explain
each without looking — that rule has not changed and should not be relaxed to
make the file look finished.

### Deferred, with a date

| Item | Owed | Due |
|---|---|---|
| §11 Scenario Drills, notes 03–11 | 9 notes × 3–4 drills | **7 Sep**, before mock #1 |
| §10 recall, notes 04–11 | 8 notes | Rolling, through **9 Sep** |
| Re-verify the CNCF Graduated list | note 11 §1.8 | Before the exam — 5 projects graduated in 2026 |
| Deduplicate rollout defaults (25/25, revisionHistoryLimit 10) | notes 03 §1.4 and 10 §1.9/§1.11 | **Block 2**, when note 03 reopens |
