# cka-curriculum.md — Certified Kubernetes Administrator, official objectives

> Source: **CNCF open-source curriculum**, `github.com/cncf/curriculum` → `cka/README.md`
> (domains and weights) + Linux Foundation CKA certification page (exam mechanics),
> both read **11 Sep 2026**. Curriculum revision tracks **Kubernetes v1.35**.
> Companion to `claude/kcna-curriculum.md`. Same rule, harder bar.
>
> **Tick rule.** KCNA objectives were ticked when *explainable without looking*.
> A CKA objective is ticked only when it can be **performed on the 3-node kubeadm
> cluster, from memory, inside its target time, with a verification command.**
> Explaining it is not evidence. Watching a video about it is not evidence.

---

## 1. Exam mechanics — the constraints the study plan must satisfy

| Item | Value |
|---|---|
| Format | Online, proctored, **performance-based** — command line, live clusters |
| Duration | **2 hours** |
| Tasks | ~15–20 hands-on tasks, no multiple choice |
| Pass mark | **66%** |
| Partial credit | **Yes** — an incomplete task still scores. Never leave a task blank |
| Kubernetes version | **v1.35** |
| Allowed docs | **One** browser tab: `kubernetes.io/docs`, `kubernetes.io/blog`, `helm.sh/docs` |
| Simulator | **killer.sh — 2 sessions** included with the registration |
| Result | Emailed ~**24 h** after the exam |
| Retake | 1 free, included in the bundle |

**Arithmetic that governs every drill in Block 2.** 120 min ÷ ~17 tasks =
**7 min per task average**, and that average already includes reading the
question, switching context to the right cluster, and verifying. Therefore:

- **Hard rule: 8 minutes and no answer → flag it, move on, come back.**
  Partial credit means a 60%-finished task is worth more than a perfect one
  never reached.
- **Every task ends with a verification command.** Unverified is unscored in
  practice — it is how a `kubectl apply` against the wrong context is lost.
- **`kubectl config use-context` is task step zero, every single time.** The exam
  spans multiple clusters. Solving the right task on the wrong cluster is the
  cheapest zero available.

---

## 2. Domains and weighting — official

| # | Domain | Weight | Canonical notes |
|---|---|---|---|
| D1 | Cluster Architecture, Installation & Configuration | **25%** | 01, 02, 07, 10 |
| D2 | Workloads & Scheduling | **15%** | 03 |
| D3 | Services & Networking | **20%** | 05 |
| D4 | Storage | **10%** | 06 |
| D5 | Troubleshooting | **30%** | 08 (+ 09) |

**Read the weights, not the syllabus order.** Troubleshooting alone is 30% —
larger than any other domain and larger than Storage and Workloads combined. It
is also the one domain that cannot be studied by reading, because it is not a
topic; it is the other four domains examined backwards. The study block gives it
its own week **after** the other four are built, not before.

D1 at 25% is the second-largest and is **exactly the EKS blind spot**. D1 + D5 =
**55% of the exam sits on material EKS has never required.**

---

## 3. Objectives, coverage and destination

Status: ☐ not started · ◐ note exists, CKA layer not added · ✅ performed from
memory within target time.

### D1 — Cluster Architecture, Installation & Configuration (25%)

| # | Competency | Note | Status | EKS differs |
|---|---|---|---|---|
| 1.1 | Manage role based access control (**RBAC**) | 07 | ◐ | ⚠️ yes |
| 1.2 | Prepare underlying infrastructure for installing a Kubernetes cluster | 01 | ◐ | ⚠️ yes |
| 1.3 | Create and manage Kubernetes clusters using **kubeadm** | 01 | ◐ | ⚠️ **total** |
| 1.4 | Manage the **lifecycle** of Kubernetes clusters (upgrades) | 01 | ◐ | ⚠️ **total** |
| 1.5 | Implement and configure a **highly-available control plane** | 01 | ☐ | ⚠️ **total** |
| 1.6 | Use **Helm and Kustomize** to install cluster components | 10 | ◐ | — |
| 1.7 | Understand **extension interfaces** (CNI, CSI, CRI) | 01, 04, 05, 06 | ◐ | ⚠️ yes |
| 1.8 | Understand **CRDs**, install and configure **operators** | 02 | ◐ | — |

**Also inside D1 in practice, though not a bullet:** etcd backup and restore,
certificate management and renewal, static Pods, kubelet configuration,
`kubeconfig` and cluster contexts, node join/drain/cordon/delete. These appear in
tasks scored under D1 and D5. Do not treat their absence from the bullet list as
absence from the exam.

### D2 — Workloads & Scheduling (15%)

| # | Competency | Note | Status | EKS differs |
|---|---|---|---|---|
| 2.1 | Application deployments, **rolling updates and rollbacks** | 03 | ◐ | — |
| 2.2 | Use **ConfigMaps and Secrets** to configure applications | 02, 07 | ◐ | ⚠️ minor |
| 2.3 | Configure **workload autoscaling** (HPA) | 03, 11 | ◐ | ⚠️ yes |
| 2.4 | Primitives for **robust, self-healing** deployments | 03 | ◐ | — |
| 2.5 | Configure **Pod admission and scheduling** (limits, node affinity, taints) | 03 | ◐ | ⚠️ minor |

**Open gap carried from 10 Sep:** PodDisruptionBudget was drafted for note 03 and
**never applied**. It belongs to 2.4 and it is CKA-scoped. Apply it in W2.

### D3 — Services & Networking (20%)

| # | Competency | Note | Status | EKS differs |
|---|---|---|---|---|
| 3.1 | Understand **connectivity between Pods** | 05 | ◐ | ⚠️ **yes** |
| 3.2 | Define and enforce **NetworkPolicies** | 05, 07 | ◐ | ⚠️ **yes** |
| 3.3 | **ClusterIP, NodePort, LoadBalancer** service types and endpoints | 05 | ◐ | ⚠️ **yes** |
| 3.4 | Use the **Gateway API** to manage Ingress traffic | 05 | ☐ | — |
| 3.5 | **Ingress controllers** and Ingress resources | 05 | ◐ | ⚠️ yes |
| 3.6 | Understand and use **CoreDNS** | 05 | ◐ | — |

### D4 — Storage (10%)

| # | Competency | Note | Status | EKS differs |
|---|---|---|---|---|
| 4.1 | **StorageClasses** and dynamic volume provisioning | 06 | ◐ | ⚠️ yes |
| 4.2 | Configure **volume types, access modes, reclaim policies** | 06 | ◐ | ⚠️ yes |
| 4.3 | Manage **PersistentVolumes and PersistentVolumeClaims** | 06 | ◐ | — |

### D5 — Troubleshooting (30%)

| # | Competency | Note | Status | EKS differs |
|---|---|---|---|---|
| 5.1 | Troubleshoot **clusters and nodes** | 08 | ◐ | ⚠️ **total** |
| 5.2 | Troubleshoot **cluster components** | 08, 01 | ◐ | ⚠️ **total** |
| 5.3 | **Monitor** cluster and application resource usage | 09 | ◐ | ⚠️ minor |
| 5.4 | Manage and evaluate **container output streams** | 08, 09 | ◐ | — |
| 5.5 | Troubleshoot **services and networking** | 08, 05 | ◐ | ⚠️ yes |

---

## 4. Note mapping — no new files

**Every CKA objective lands on a note that already exists.** Block 2 writes zero
new note files. It reopens eight and adds the CKA layer to each, exactly as
`plan.md §9.2` specifies. If a CKA session ever proposes a new note file, that is
a signal the taxonomy was mis-applied, not that a file is missing.

| Note | Current `exams:` | Change required in Block 2 |
|---|---|---|
| 01 cluster-architecture | KCNA, KCSA, CKA, CKS | CKA layer: kubeadm init/join, upgrade, etcd, certs, static Pods, HA topologies |
| 02 api-and-objects | KCNA, CKA, CKAD | CKA layer: CRDs, operators, imperative object creation |
| 03 workloads-and-scheduling | KCNA, CKA, CKAD | CKA layer: rollouts/rollbacks, HPA, affinity, taints, **PDB (drafted, unapplied)** |
| 05 networking | KCNA, CKA, CKAD, CKS | CKA layer: NetworkPolicy authoring, **Gateway API (new)**, Ingress, CoreDNS config |
| 06 storage | KCNA, CKA, CKAD | CKA layer: StorageClass authoring, dynamic provisioning, reclaim policy behaviour |
| 07 security-and-rbac | KCNA, KCSA, CKA, CKAD, CKS | CKA layer: Role/RoleBinding/CRB authoring and `auth can-i` verification |
| 08 troubleshooting | KCNA, CKA, CKAD | CKA layer: the whole D5 method, node and control-plane failures |
| 09 observability | KCNA, CKAD, CKS | **add `CKA`** — 5.3 and 5.4 are CKA objectives (`kubectl top`, metrics-server, logs) |
| 10 application-delivery | KCNA, CKAD | **add `CKA`** — 1.6 Helm and Kustomize is a D1 objective, inside a 25% domain |

**Two tag corrections above are real findings, not bookkeeping.** Notes 09 and 10
were written as non-CKA material. They are CKA material. They were also the two
weakest-reviewed notes going into KCNA.

---

## 5. EKS contrast — the blind-spot register

These are the places where three years of EKS intuition produces a **wrong CKA
answer**. Each one belongs in the corresponding note's CKA layer as an explicit
`⚠️ EKS` callout.

| Topic | Vanilla / kubeadm (what CKA tests) | EKS (what the day job taught) |
|---|---|---|
| Control plane | Static Pods in `/etc/kubernetes/manifests`, visible, editable, restarted by kubelet on file change | Fully managed and **invisible**. No node, no manifest, no process to inspect |
| etcd | A container you can `exec` into; `etcdctl snapshot save/restore` is a scored task | AWS-managed. No endpoint, no snapshot, no restore. Backups are AWS's problem |
| Upgrade | `kubeadm upgrade plan` → `apply` → drain → kubelet → uncordon, node by node | One API call / one Terraform attribute. The mechanism is entirely hidden |
| Node join | `kubeadm join` with a token and a CA cert hash, with a TTL | Managed node group or Karpenter. Bootstrap is a launch-template userdata script |
| Authn → authz | x509 client certs from the cluster CA, in `kubeconfig` | IAM identity mapped via **EKS Access Entries / `aws-auth`**, then RBAC. The RBAC half is identical; the identity half is not |
| CNI | Calico (or similar): **overlay**, Pod CIDR distinct from node CIDR, NAT-free via routes | **VPC CNI**: Pod IPs come from real VPC subnets, ENI-attached, subject to ENI/IP limits per instance type |
| NetworkPolicy | Enforced by the CNI — Calico enforces, Flannel does not | VPC CNI only enforces policy when explicitly enabled; security groups are a separate, non-Kubernetes layer |
| LoadBalancer Service | Stays `<pending>` forever — no cloud controller in a kubeadm cluster. **This is correct behaviour, not a fault** | Provisions an NLB/CLB via the AWS cloud controller / LB controller |
| StorageClass | None by default in kubeadm. A PVC with no class binds only to a PV with no class | `gp2`/`gp3` default class present, EBS CSI driver installed as an addon |
| Cluster autoscaling | Cluster Autoscaler concepts only | **Karpenter** — AWS-specific, not exam content, and not a synonym |
| Certificates | `kubeadm certs check-expiration`, 1-year leaf certs, manual renewal | Rotated by AWS. Never seen |

**Discipline rule.** When a CKA lab behaves differently from EKS, the correct
reaction is to write the delta into the note, not to "fix" the lab so it behaves
like EKS.

---

## 6. What is explicitly NOT in this curriculum

Out of scope for Block 2, regardless of how much the internet talks about them:
service mesh (**Istio**), policy engines (**Kyverno**, OPA/Gatekeeper), **Argo CD**
and GitOps controllers, **Terraform**, Prometheus operator internals, and
everything CKS-specific (seccomp, AppArmor, Falco, image scanning, runtime
classes). Four of those are already named in `plan.md §2` as out of scope until
**1 Dec**. Helm and Kustomize are **in** scope — they are objective 1.6.

CKAD-only material is also out: multi-container patterns as a design topic,
canary/blue-green strategy, the Downward API as an exam objective. It arrives in
Block 3, on the same notes.

---

## 7. Coverage scoreboard

| Domain | Objectives | ✅ performed from memory |
|---|---|---|
| D1 Cluster Architecture (25%) | 8 | 0 |
| D2 Workloads & Scheduling (15%) | 5 | 0 |
| D3 Services & Networking (20%) | 6 | 0 |
| D4 Storage (10%) | 3 | 0 |
| D5 Troubleshooting (30%) | 5 | 0 |
| **Total** | **27** | **0** |

Update this table at the end of every Block 2 session. **The number that decides
whether the 3 Oct exam is sat is this one, plus the two killer.sh scores** — not
hours studied and not notes extended.
