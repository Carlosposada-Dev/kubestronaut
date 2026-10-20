# sources.md — Where to study each domain

> Source of truth per domain. If a source is not listed here, it is not studied.
> Last updated: 2026-08-16 · Active block: KCNA · Language: EN

---

## Base rule

**kubernetes.io/docs is the default source for anything Kubernetes.**
Not only because it is correct, but because it is the *only* documentation
allowed during CKA/CKAD/CKS. Every hour spent navigating kubernetes.io now is
speed earned in September. Learn its search and its structure:
`/docs/concepts/` → theory, `/docs/tasks/` → recipes, `/docs/reference/` → fields.

Third-party material (blogs, courses, Medium) only to *unblock* a concept the
official docs failed to explain. Never as the primary source of a note.

---

## Domain → source map (KCNA)

| KCNA domain | Sub-area | Primary source | Secondary |
|---|---|---|---|
| **Kubernetes Fundamentals (44%)** | Core Concepts | kubernetes.io `/docs/concepts/overview/`, `/concepts/architecture/` | LFS158 (free) |
| | Administration | kubernetes.io `/docs/concepts/cluster-administration/`, `/reference/access-authn-authz/` | kubeadm docs |
| | Scheduling | kubernetes.io `/docs/concepts/scheduling-eviction/` | — |
| | Containerization | **OCI specs** (opencontainers.org), kubernetes.io `/docs/concepts/containers/`, `/setup/production-environment/container-runtimes/`, containerd docs | Docker docs **only** for Dockerfile / image build |
| **Container Orchestration (28%)** | Networking | kubernetes.io `/docs/concepts/services-networking/` | CNI spec (github.com/containernetworking/cni) |
| | Security | kubernetes.io `/docs/concepts/security/`, `/reference/access-authn-authz/rbac/` | CNCF Cloud Native Security Whitepaper |
| | Troubleshooting | kubernetes.io `/docs/tasks/debug/` | — |
| | Storage | kubernetes.io `/docs/concepts/storage/` | CSI spec (conceptual) |
| **Cloud Native App Delivery (16%)** | Application Delivery | **opengitops.dev** (the 4 principles), kubernetes.io `/docs/concepts/workloads/`, Helm docs, Kustomize docs | Argo CD / Flux docs — **only the "What is GitOps / Core Concepts" pages** |
| | Debugging | kubernetes.io `/docs/tasks/debug/debug-application/` | — |
| **Cloud Native Architecture (12%)** | Observability | Prometheus docs (`/docs/introduction/overview`, metric types, pull model), OpenTelemetry docs (signals: traces/metrics/logs) | Grafana docs — **shallow**; it is the visualisation layer and carries little weight |
| | Ecosystem & Principles | **glossary.cncf.io**, landscape.cncf.io, cncf.io/projects | CNCF Annual Report |
| | Community & Collaboration | github.com/cncf/toc, kubernetes.io `/docs/contribute/`, SIG/TAG structure | — |

---

## Mandatory reference documents (read once, in full)

1. **Official KCNA curriculum** — github.com/cncf/curriculum, `kcna/` folder.
   It is the literal list of what can appear. Note: it publishes only 4 domains
   and 13 sub-areas — no finer bullets. The derived checklist lives in
   `kcna-curriculum.md`.
2. **CNCF Cloud Native Glossary** — glossary.cncf.io.
   Many KCNA questions are written almost in this exact vocabulary.
   *(A Spanish version exists at glossary.cncf.io/es/, but read the English one —
   the exam is in English and the terminology has to be automatic.)*
3. **CNCF Landscape** — landscape.cncf.io. Do not memorise 1000+ projects.
   Memorise the **Graduated** ones, and know the difference between
   Sandbox / Incubating / Graduated and who decides (the TOC).
4. **Candidate Handbook + Exam Policies** (Linux Foundation).
   Format, proctor rules, room requirements. Read before 29 Aug.
5. **CNCF Cloud Native Definition v1.1** — github.com/cncf/toc. Short. The
   "pillars" come from here.

---

## Courses

| Resource | Cost | Verdict |
|---|---|---|
| **LFS158 — Introduction to Kubernetes** (edX / LF) | Free | Covers Fundamentals well. Good first pass. |
| LFS250 — Kubernetes and Cloud Native Essentials | Included if the bundle was bought with training | The official course, mapped 1:1 to the curriculum. **Check whether the Kubestronaut bundle includes it.** |
| LFS151 — Intro to Cloud Infrastructure Technologies | Free | Optional. Useful for Cloud Native Architecture. |
| KodeKloud / Udemy (Zeal Vora, Sander van Vugt) | Paid | Only when reading fails to land a topic. Not the main route. |

---

## Practice

- **Killercoda** (killercoda.com) — free browser scenarios. Little use for KCNA,
  heavy use for CKA/CKAD/CKS.
- **killer.sh** — 2 sessions included per voucher. **Does not apply to KCNA**
  (it is MCQ). Save it for the final week of each performance block.
- MCQ mocks: use the official course sets and KodeKloud.

---

## ⛔ Blacklist

- **Dump sites** (validexamdumps, skillcertpro, "actual exam questions", etc.).
  Three reasons: they violate the Linux Foundation agreement and can cost the
  certification; they are full of wrong answers; and they train recognition
  instead of understanding. No.
- **Docker documentation as the source for "Containerization".** KCNA is
  post-dockershim and runtime-agnostic. It asks about OCI, CRI, containerd,
  runc. Docker docs teach things that are true in Docker and false in Kubernetes.
- **Blogs dated before 2023** for networking or security. PodSecurityPolicy,
  dockershim, Ingress-only — all obsolete.
- **Istio / Kyverno / Argo CD / Terraform in depth** — out of scope until 1 Dec
  (see `plan.md §2`). Service mesh and GitOps *concepts* are in scope for KCNA;
  operating those tools is not.

---

## A note on EKS

No AWS source belongs here. The EKS documentation describes a cluster where the
control plane is invisible and managed — exactly what the exams test by hand.
Everything studied is verified against the 3-node kubeadm cluster, never against
EKS. EKS↔vanilla differences are recorded in §7 of each note, not here.
