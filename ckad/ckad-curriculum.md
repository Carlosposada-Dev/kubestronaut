# ckad-curriculum.md — Certified Kubernetes Application Developer, official objectives

> Source: the CKAD domains and competencies as listed on the Linux Foundation CKAD
> page, pasted by the learner on **13 Nov 2026**; weights as published there.
> Exam environment **v1.37** (LF page, `plan.md` log 1 Nov). **Owed:** diff against
> `github.com/cncf/curriculum` → `CKAD_Curriculum_v1.37.pdf` at the first session.
> Companion to `cka/cka-curriculum.md`. Exam mechanics, the 8-minute rule and the
> per-host setup are the same exam platform: `cka-curriculum.md §1`, `plan.md §13`.
>
> **Tick rule.** A CKAD objective is ticked only when it can be **performed on the
> lab, from memory, inside its target time, with a verification command.**

---

## 1. Exam mechanics — what differs from CKA

| Item | Value |
|---|---|
| Format · duration · pass mark | Performance-based · **2 hours** · **66%** |
| Tasks | ~15–20, each on a designated SSH host (`plan.md §13`) |
| Allowed docs | kubernetes.io/docs, the Kubernetes blog, helm.sh/docs — **no Gateway API docs** (CKA only) |
| Simulator | killer.sh — 2 sessions (same questions), 36 h each |
| Retake | 1 free. Registration expires **30 Nov 2026** |

**What kind of exam it is.** No cluster administration: no kubeadm, no etcd, no node
work. Every task is "make this application object right, in this namespace". It is a
**speed and literals** exam — ~6 min per task, most of them imperative, and the points
are lost on a wrong name, a wrong namespace or an unverified answer, not on mechanism.

**Three habits that carry the paper**

1. Copy the task's literals (namespace, names, image, path) into shell variables
   before the first command (the 8 Nov method).
2. Existing object → `k get … -o yaml > f.yaml` **before** editing: a backup and a
   file to `replace --force` when a field is immutable.
3. One proof per requirement — the verification command is part of the task.

---

## 2. Domains and weighting — official

| # | Domain | Weight | File | Canonical notes |
|---|---|---|---|---|
| D1 | Application Design and Build | **20%** | `ckad-D1.md` | 03, 04, 06 |
| D2 | Application Deployment | **20%** | `ckad-D2.md` | 03, 10 |
| D3 | Application Observability and Maintenance | **15%** | `ckad-D3.md` | 02, 08, 09 |
| D4 | Application Environment, Configuration and Security | **25%** | `ckad-D4.md` | 02, 07 |
| D5 | Services and Networking | **20%** | `ckad-D5.md` | 05 |

---

## 3. Objectives, coverage and destination

Status: ☐ not started · ◐ worked in CKA or note exists, CKAD task not timed ·
✅ performed from memory within target time.
**R#** = the row of the reported-task list in §4.

### D1 — Application Design and Build (20%)

| # | Competency | Note | Status | Already in the repo | R# |
|---|---|---|---|---|---|
| 1.1 | Define, build and modify container images | 04 | ☐ | — (new: podman) | R1 |
| 1.2 | Choose and use the right workload resource (Deployment, DaemonSet, CronJob, etc.) | 03 | ☐ | — | R3, R5 |
| 1.3 | Understand multi-container Pod design patterns (sidecar, init and others) | 03, 04 | ☐ | — | R14 |
| 1.4 | Utilize persistent and ephemeral volumes | 06 | ☐ | `cka-D4.md` (skeleton) | — |

### D2 — Application Deployment (20%)

| # | Competency | Note | Status | Already in the repo | R# |
|---|---|---|---|---|---|
| 2.1 | Use Kubernetes primitives to implement common deployment strategies (blue/green, canary) | 10 | ☐ | — | R6 |
| 2.2 | Understand Deployments and how to perform rolling updates | 03 | ◐ | `cka-D2-1-workloads.md` 2.1 — guided pass done, R1 blind owed | R16 |
| 2.3 | Use the Helm package manager to deploy existing packages | 10 | ◐ | `cka-D1-3-access.md` 1.6 — H1 6:32 11/11, cold owed | — |
| 2.4 | Kustomize | 10 | ◐ | `cka-D1-3-access.md` 1.6 | — |

### D3 — Application Observability and Maintenance (15%)

| # | Competency | Note | Status | Already in the repo | R# |
|---|---|---|---|---|---|
| 3.1 | Understand API deprecations | 02 | ☐ | — | R2 |
| 3.2 | Implement probes and health checks | 08 | ☐ | `cka-D2-1-workloads.md` 2.4 (skeleton) | R14 |
| 3.3 | Use built-in CLI tools to monitor Kubernetes applications | 09 | ☐ | metrics-server installed by Helm in 1.6 | — |
| 3.4 | Utilize container logs | 08 | ☐ | — | — |
| 3.5 | Debugging in Kubernetes | 08 | ☐ | — | R9 |

### D4 — Application Environment, Configuration and Security (25%)

| # | Competency | Note | Status | Already in the repo | R# |
|---|---|---|---|---|---|
| 4.1 | Discover and use resources that extend Kubernetes (CRD, Operators) | 02 | ✅ CKA 8 Nov | `cka-D1-3-access.md` 1.8 (recognise-only) | — |
| 4.2 | Understand authentication, authorization and admission control | 07 | ✅ CKA 8 Nov (RBAC) | `cka-D1-3-access.md` 1.1 — cold 3:46 · 3:24 | R10, R11 |
| 4.3 | Understand requests, limits, quotas | 03, 07 | ☐ | `cka-D2-2-scheduling.md` 2.5 (skeleton) | R4 |
| 4.4 | Understand ConfigMaps | 07 | ☐ | `cka-D2-1-workloads.md` 2.2 (skeleton) | — |
| 4.5 | Create & consume Secrets | 07 | ☐ | `cka-D2-1-workloads.md` 2.2 (skeleton) | R13 |
| 4.6 | Understand ServiceAccounts | 07 | ◐ | `cka-D1-3-access.md` 1.1 (SA as a subject) | R10, R11 |
| 4.7 | Understand Application Security (SecurityContexts, Capabilities, etc.) | 07 | ☐ | — | R7 |

### D5 — Services and Networking (20%)

| # | Competency | Note | Status | Already in the repo | R# |
|---|---|---|---|---|---|
| 5.1 | Demonstrate basic understanding of NetworkPolicies | 05 | ☐ | `cka-D3.md` 3.2 (skeleton) | R12 |
| 5.2 | Provide and troubleshoot access to applications via services | 05 | ☐ | `cka-D3.md` 3.3 (skeleton) | R9, R15 |
| 5.3 | Use Ingress rules to expose applications | 05 | ☐ | `cka-D3.md` 3.5 (skeleton) | R8, R9 |

---

## 4. Reported-task list — R1 to R16 (study priority, not the syllabus)

Topics reported by a candidate who sat the exam in October 2026 (~75% of her paper).
**It is a priority order, not a specification:** the exam draws from a pool, and the
wording and literals below are hers from memory. Every row maps to an objective in
§3, which is why the list is trusted. Three rows are corrected where the report
cannot be literally right.

| R# | Reported topic | Bullet | Correction / what it really tests |
|---|---|---|---|
| R1 | Build an image with podman, run it, export to a file | 1.1 | An **image** is written with `podman save`; `podman export` writes a **container's** filesystem. Know both; the task names the format (often OCI) |
| R2 | Move a Deployment manifest from 1.15 to a current version | 3.1 | `apiVersion: apps/v1`, a mandatory `spec.selector` that matches the template labels, and whatever else the task names |
| R3 | CronJob every 30 min with parallelism, completions, restart policy, a time limit; test it | 1.2 | Schedule `*/30 * * * *`; the knobs are `completions`, `parallelism`, `backoffLimit`, `activeDeadlineSeconds`, `restartPolicy` — a Job has no `replicas` |
| R4 | Deployment limits = half the namespace quota; then redefine the quota so only one Pod fits | 4.3 | Read the ResourceQuota first; arithmetic with units |
| R5 | Create a Job from a CronJob | 1.2 | `k create job NAME --from=cronjob/CJ` |
| R6 | Blue/green and canary: a second Deployment, same label, 80/20 split | 2.1 | The Service selector is the switch; the split is the replica ratio |
| R7 | Add capabilities and `runAsUser` to a Deployment | 4.7 | `runAsUser` is Pod- or container-level; `capabilities` is **container-level only** |
| R8 | Create an Ingress for a Service | 5.3 | `k create ingress` exists; `ingressClassName` matters |
| R9 | Find and fix a Service and an Ingress | 5.2, 5.3, 3.5 | Empty endpoints → Service selector vs Pod labels; Ingress → class, Service name, port |
| R10 | A Pod must `get` Pods in its namespace; Role and RoleBinding are given | 4.6 | Create the ServiceAccount the binding names and set it on the Pod |
| R11 | A Deployment's Pod must read logs: create Role, RoleBinding and SA | 4.2, 4.6 | Resource is `pods/log` (singular) — the 7 Nov miss |
| R12 | A Pod must talk only to others in its namespace, policies already exist | 5.1 | Change the **Pod's labels** to match the existing policies; never edit the policies |
| R13 | Create a Secret and feed it to a Deployment as env vars | 4.5 | `create secret generic` + `set env --from=secret/…` or `secretKeyRef` |
| R14 | Readiness probe with `exec`; the file is created by an init container | 3.2, 1.3 | Probe on the app container, shared `emptyDir` |
| R15 | Change a Service from ClusterIP to NodePort | 5.2 | `spec.type` (+ `nodePort` if the task names one) |
| R16 | Change a Deployment's container name and image, roll out, roll back with `undo` | 2.2 | A Deployment cannot be renamed — "name" is the container's. Both changes make one revision |

**Objectives the list does not touch** — still on the paper: 1.3 sidecar · 1.4 volumes
· 2.3 Helm · 2.4 Kustomize · 3.3 `top` · 3.4 logs · 4.1 CRDs · 4.4 ConfigMaps ·
DaemonSet / StatefulSet (1.2).

---

## 5. What is explicitly NOT in this curriculum

Everything that made CKA hard: kubeadm, upgrades, etcd, certificates, static Pods,
node troubleshooting, CNI/CRI, Gateway API, StorageClass authoring. If a CKAD session
drifts there, it is off the paper.

---

## 6. Coverage scoreboard

| Domain | Objectives | ✅ performed from memory |
|---|---|---|
| D1 Application Design and Build (20%) | 4 | 0 |
| D2 Application Deployment (20%) | 4 | 0 |
| D3 Observability and Maintenance (15%) | 5 | 0 |
| D4 Environment, Configuration and Security (25%) | 7 | 2 (4.1, 4.2 — closed in CKA D1-3) |
| D5 Services and Networking (20%) | 3 | 0 |
| **Total** | **23** | **2** |

Updated at every `cierre`. The numbers that decide nothing: hours. The numbers that
matter: this table and the killer.sh score.
