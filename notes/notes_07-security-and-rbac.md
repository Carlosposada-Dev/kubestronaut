---
exams: [KCNA, KCSA, CKA, CKAD, CKS]
domain: Security & RBAC
kcna_domains: 1.2 Administration (the parts not covered by note 01) + 2.2 Security
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/security/ (overview, pod-security-standards, pod-security-admission, service-accounts), /reference/access-authn-authz/ (authentication, authorization, rbac, admission-controllers, node), /concepts/configuration/secret, /tasks/configure-pod-container/security-context, /concepts/policy/ (resource-quotas, limit-range), CNCF Cloud Native Security Whitepaper (the 4C's)
template: B
language: en
scope: KCNA ONLY — KCSA/CKS layers appended from 19 Oct. This note is reopened twice more than any other
status: draft
revised: 2026-09-05 rev3 — §1.15 cluster upgrade added (curriculum gap); stale cross-ref into note 03 corrected to §1.11. SUPERSEDES rev1 and rev2.
written: 2026-09-04
format: per claude/depth-standard.md AMENDMENT 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). Verified this session — PodSecurityPolicy deprecated v1.21, **removed v1.25**; Pod Security Admission is its built-in replacement; Secret-based ServiceAccount tokens **no longer auto-generated since v1.24** (TokenRequest API + projected volume, bounded lifetime). Version skew re-verified 2026-09-05 against kubernetes.io/releases/version-skew-policy — kubelet may be **three** minor versions older than kube-apiserver (only two, before v1.25); many secondary sources still say two.
closes_mistakes: row 26 (ConfigMap vs Secret — fully, the storage half was note 06 §1.3)
closes_curriculum_gap: 1.2 bullet 7 "Notion of cluster upgrade and of drain/cordon" — §1.14 covers drain/cordon, §1.15 (added 2026-09-05) covers the upgrade notion. Note 01 line 870 deferred this to CKA Block 2, leaving it uncovered at KCNA depth across all seven notes. §1.15 is the KCNA-level answer only; the kubeadm procedure stays deferred.
no_duplication: kubeadm init/join, static Pods, kubeconfig structure, the three CAs and cert lifetimes are note 01. Referenced here, never repeated.
---

# Security & RBAC

*Two questions, asked in order on every single API request: who are you, and are
you allowed to do that? Everything else is detail.*

This note serves **all five certifications** — more than any other — and covers
two KCNA sub-areas: the access-control half of **1.2 Administration** and all of
**2.2 Security**, together ≈ **8–10 of the 60 questions**.

---

## 1. Core Concepts

### 1.1 The 4C's of cloud native security

*Security is four nested layers, and each one can only be as strong as the layer
outside it.*

| Layer | Covers | Example control |
|---|---|---|
| **Cloud** | The infrastructure: datacentre, VPC, IAM, physical access | Network isolation, encrypted disks, provider IAM |
| **Cluster** | The Kubernetes cluster itself | RBAC, authentication, NetworkPolicy, API server hardening |
| **Container** | The image and the runtime | Non-root, minimal base image, scanning, SecurityContext |
| **Code** | Your application | Input validation, dependency management, TLS, no hardcoded secrets |

```
┌─ Cloud ──────────────────────────────┐
│  ┌─ Cluster ───────────────────────┐ │
│  │  ┌─ Container ────────────────┐ │ │
│  │  │  ┌─ Code ───────────────┐  │ │ │
│  │  │  └──────────────────────┘  │ │ │
│  │  └────────────────────────────┘ │ │
│  └─────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**The nesting is the point, and it is the exam question.** You cannot secure a
cluster on compromised infrastructure, and perfect RBAC does not save you from an
application that leaks its own credentials. Each layer depends on the one that
contains it. Order — outermost to innermost — is Cloud, Cluster, Container, Code.

### 1.2 The request path: authentication → authorization → admission

*Every request passes three gates in a fixed order, and knowing which gate
rejected you is most of the debugging.*

```
kubectl / Pod / controller
        │
        ▼
   ┌─────────────────┐
   │ AUTHENTICATION  │  "Who are you?"        → fail: 401 Unauthorized
   └─────────────────┘
        │  identity established (user + groups)
        ▼
   ┌─────────────────┐
   │ AUTHORIZATION   │  "May you do this?"    → fail: 403 Forbidden
   └─────────────────┘   (RBAC)
        │  allowed
        ▼
   ┌─────────────────┐
   │ ADMISSION       │  mutating, then validating
   └─────────────────┘  → fail: 403, naming a plugin or webhook
        │  accepted
        ▼
     persisted to etcd
```

**The order is fixed and is examined directly.** Authentication first — an
unauthenticated request is never authorized. Admission last — it only ever sees
requests that already passed RBAC.

**Reading a 403 correctly** is the practical skill, and it is already in your
error log:

| The message names | Which gate | What to fix |
|---|---|---|
| A **user, a verb and a resource** — *"User X cannot create pods in namespace Y"* | **Authorization** (RBAC) | A Role/Binding is missing |
| A **plugin or webhook** — *"admission webhook denied the request"* | **Admission** | A policy rejected an otherwise-permitted request |

Same HTTP code, completely different cause. And note what admission does **not**
do: it never establishes *intent* or identity — by the time it runs, who you are
and what you may do are already settled.

### 1.3 Authentication — establishing identity

*Kubernetes has no user database. It verifies a credential and reads your name
off it.*

**There is no `User` object in Kubernetes.** You cannot `kubectl get users`. A
user is whatever a valid credential says it is:

| Method | Identity comes from | Used by |
|---|---|---|
| **X.509 client certificate** | The cert's **CN** = username, **O** fields = groups | Humans, `kubectl`, control plane components |
| **ServiceAccount token** | A signed JWT naming the SA | **Pods and workloads** |
| **Bearer / static tokens** | A configured token file | Bootstrap, simple setups |
| **OIDC** | An external identity provider | Enterprise SSO |
| **Webhook / proxy** | An external service | **How EKS maps IAM identities** (see §7) |

The certificate details — the three CAs, `admin.conf` vs `super-admin.conf`,
1-year leaf and 10-year CA lifetimes — are **note 01 §2.1 and §2.2**. Not
repeated here.

Two identity kinds exist, and confusing them is a classic distractor:

| | Human users | ServiceAccounts |
|---|---|---|
| Kubernetes object? | **No** — external, no API object | **Yes** — a real, namespaced object |
| Created by | Your CA or IdP | `kubectl create serviceaccount` |
| Used by | People and their tooling | **Pods** |
| Username form | Whatever the CN says | `system:serviceaccount:<ns>:<name>` |

Requests that authenticate as nobody become the user `system:anonymous` in group
`system:unauthenticated`.

### 1.4 ServiceAccounts and their tokens

*A ServiceAccount is the identity a Pod uses to talk to the API server — and
every Pod gets one whether it asked or not.*

Every namespace has a ServiceAccount called **`default`**, and a Pod that names
none is assigned it. That default SA has almost no permissions, which is correct
and also why "my Pod can't list Pods" is such a common surprise.

**How the token reaches the Pod — and this changed in v1.24:**

| | Before v1.24 | **v1.24 onward (current)** |
|---|---|---|
| Token storage | An auto-created **Secret** per SA | **No Secret is auto-created** |
| Delivery | Mounted from that Secret | **Projected volume**, issued by the **TokenRequest API** |
| Lifetime | **Never expired** | **Bounded**, auto-rotated |
| On Pod deletion | Token still valid | **Automatically invalidated** |

The token lands at `/var/run/secrets/kubernetes.io/serviceaccount/` inside every
container. The security gain is real: a leaked pre-1.24 token was valid forever;
a leaked modern one dies with its Pod.

You can still create a long-lived token by making the Secret manually, and
`kubectl create token <sa>` mints a short-lived one on demand (default 1 hour).

**Opt out when the Pod does not need the API at all** —
`automountServiceAccountToken: false`, settable on the ServiceAccount or the Pod,
with **the Pod spec winning** if both are set. Most applications never call the
Kubernetes API, so mounting a credential into them is pure attack surface.

### 1.5 RBAC — the four objects

*Two objects say what may be done; two say who may do it. The only difference
within each pair is whether it applies to one namespace or the whole cluster.*

RBAC lives in the API group **`rbac.authorization.k8s.io/v1`**.

| | Defines permissions | Grants them to subjects |
|---|---|---|
| **Namespaced** | **Role** | **RoleBinding** |
| **Cluster-wide** | **ClusterRole** | **ClusterRoleBinding** |

A binding connects **subjects** (users, groups, ServiceAccounts) to **one** role.

The four combinations, and the third row is the one exams love:

| Role type | Binding type | Result |
|---|---|---|
| Role | RoleBinding | Permissions **in that one namespace** |
| ClusterRole | ClusterRoleBinding | Permissions **across every namespace**, plus cluster-scoped resources |
| **ClusterRole** | **RoleBinding** | **The ClusterRole's permissions, applied only inside the binding's namespace** |
| Role | ClusterRoleBinding | **Invalid.** Does not exist |

That third row is how you write a permission set **once** and grant it in twenty
namespaces without twenty copies. It is also why the default ClusterRoles
(`view`, `edit`, `admin`, `cluster-admin`) are useful: bind `edit` with a
RoleBinding and the subject gets edit rights in that namespace only.

**Cluster-scoped resources need a ClusterRole.** Nodes, PersistentVolumes,
Namespaces and StorageClasses do not live in a namespace, so a Role cannot grant
access to them — the object model forbids it.

### 1.6 What a rule actually says

*Three lists: which API group, which resources, which verbs. All three must
match, or the request is not permitted.*

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: prod
  name: pod-reader
rules:
- apiGroups: [""]                    # "" = the CORE group (note 02 §1.3)
  resources: ["pods", "pods/log"]    # subresources are separate resources
  verbs: ["get", "list", "watch"]
```

| Field | Note |
|---|---|
| `apiGroups` | `""` is the **core group** — it has no name (note 02 §1.3). `"apps"` for Deployments |
| `resources` | **Plural, lowercase**: `pods`, not `Pod`. Subresources are separate: `pods/log`, `pods/exec` |
| `verbs` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection` |

Two things people get wrong:

- **`get` does not imply `list`.** They are separate verbs. `kubectl get pods`
  without a name needs **`list`**; with a name it needs **`get`**. A Role with
  only `get` produces a confusing partial failure.
- **`pods/log` is not covered by `pods`.** Reading logs needs the subresource
  granted explicitly — likewise `pods/exec` for `kubectl exec`.

### 1.7 RBAC is additive — there is no deny

*You cannot write a rule that forbids something. You can only fail to write one
that permits it.*

| Property | Consequence |
|---|---|
| **Default is deny** | With no matching rule, the answer is no |
| **Rules are purely additive** | Permissions from all bindings are unioned |
| **No deny rules exist** | You cannot subtract a permission by adding a rule |

So removing access means **removing or narrowing a binding** — never adding a
"deny" one, because there is no such thing. If a subject can do something you did
not intend, some binding grants it, possibly through a group or an inherited
default ClusterRole.

The command that answers this without reasoning through every binding:

```bash
kubectl auth can-i create deployments --as=jane -n prod
kubectl auth can-i --list --as=system:serviceaccount:prod:myapp -n prod
```

**Authorization modes** are configured on the API server; kubeadm enables
**`Node,RBAC`**. The `Node` authorizer is a special mode restricting each kubelet
to the objects its own node needs — which is what stops a compromised worker from
reading every Secret in the cluster.

### 1.8 Namespaces — a scope boundary, not a security boundary

*Namespaces divide names and permissions. They do not divide the network, and
they do not contain a container breakout.*

| Namespaces DO | Namespaces DO NOT |
|---|---|
| Scope object names — two `web` Deployments can coexist | **Isolate the network** — see note 05 §1.12 |
| Provide an RBAC boundary via Role/RoleBinding | Isolate nodes — Pods from different namespaces share hardware |
| Scope ResourceQuota and LimitRange | Contain a kernel escape (note 04 §1.1) |
| Scope Pod Security Admission labels | Apply to cluster-scoped objects |

The four default namespaces: `default`, `kube-system`, `kube-public`,
`kube-node-lease`.

**"A namespace is a security boundary" is false and is a favourite distractor.**
By default a Pod in namespace A can open a connection to a Pod in namespace B —
that is note 05's allow-all default. Namespaces plus **NetworkPolicy** plus RBAC
plus quotas begin to approach isolation; the namespace alone provides none.

### 1.9 ResourceQuota and LimitRange

*One caps the namespace as a whole; the other sets the rules for each individual
Pod. They are frequently swapped in exam options.*

| | **ResourceQuota** | **LimitRange** |
|---|---|---|
| Applies to | **The namespace in aggregate** | **Each individual Pod/container** |
| Says | "This namespace may use 20 CPU total, and hold at most 10 PVCs" | "Each container gets 100m CPU by default; none may exceed 2" |
| Can set defaults? | **No** | **Yes** — injects `requests`/`limits` when omitted |
| Enforced at | Object creation, against the namespace total | Object creation, per object |
| Failure looks like | `exceeded quota` | `minimum/maximum constraint violated` |

Two interactions worth holding:

- **A ResourceQuota that limits CPU or memory forces every Pod to declare
  requests and limits.** Without them the quota cannot be computed, so the Pod is
  rejected outright — a surprising failure the first time you meet it.
- **A LimitRange silently changes QoS class** (note 03 §1.11): its injected
  defaults can turn a would-be BestEffort Pod into Burstable, or a Burstable one
  into Guaranteed if requests and limits end up equal.

### 1.10 ConfigMap vs Secret

*Both are key–value objects mounted into Pods. The only real difference is how
seriously Kubernetes treats the contents — and it is less serious than the name
suggests.*

**This closes `mistakes.md` row 26.** The volume mechanism was note 06 §1.3; this
is the confidentiality half.

| | ConfigMap | Secret |
|---|---|---|
| Holds | **Non-confidential** configuration | **Confidential** data — passwords, tokens, keys |
| Encoding | Plain text | **base64** |
| **Encrypted?** | No | **Not by default** |
| At rest in etcd | Plain | **Plain, unless encryption at rest is configured** |
| On the node | Written to disk | **tmpfs (RAM)** — never touches node disk |
| Size limit | ~1 MiB | ~1 MiB |
| Consumed as | Env vars or mounted files | Env vars or mounted files |

**`base64` is encoding, not encryption.** It is reversible by anyone, with no
key, in one command. This is the single most-tested security fact in KCNA:

```bash
echo 'cGFzc3dvcmQxMjM=' | base64 -d      # password123
```

base64 exists so binary data can live in a text field — nothing more.

**What actually protects a Secret** is therefore not the Secret type itself:

| Control | Protects against |
|---|---|
| **RBAC** limiting `get`/`list` on secrets | Anyone reading them through the API |
| **Encryption at rest** (`EncryptionConfiguration` on the API server) | Someone reading etcd's files or a backup |
| Not mounting them where they are not needed | Blast radius after a container compromise |
| An external store (Vault, cloud secret manager) | Everything above, at operational cost |

**Anyone who can create a Pod in a namespace can read every Secret in that
namespace** — mount it and print it. So `create pods` is effectively
`read all secrets here`, which is why that permission is far more powerful than
it looks.

### 1.11 SecurityContext

*Where you say what the container is not allowed to be — starting with root.*

Settable at Pod level (applies to all containers) or per container, where the
container-level value wins.

| Field | Does | Why it matters |
|---|---|---|
| `runAsNonRoot: true` | **Refuses to start** a container running as UID 0 | Container root plus a kernel escape is host root (note 04 §1.1) |
| `runAsUser` / `runAsGroup` | Forces a specific UID/GID | Explicit, verifiable identity |
| `readOnlyRootFilesystem: true` | Filesystem is immutable; writes need a volume | Blocks the attacker's first move: dropping a tool on disk |
| `allowPrivilegeEscalation: false` | Blocks gaining more privileges than the parent | Stops `setuid` escalation |
| `privileged: true` | **Nearly all host capabilities** | Effectively host root. Almost never justified |
| `capabilities.drop: ["ALL"]` | Removes Linux capabilities, add back only what is needed | Least privilege at kernel granularity |

`runAsNonRoot: true` is the highest-value single field: it is a hard stop, not a
warning, and it forces the image to have been built with a `USER` (note 04
§1.14).

### 1.12 Pod Security Admission

*Three preset security levels applied by labelling a namespace. It replaced
PodSecurityPolicy, which was removed.*

**PodSecurityPolicy was deprecated in v1.21 and removed in v1.25.** Its
replacement, **Pod Security Admission (PSA)**, is built into the API server — no
CRDs, no controller to install.

The three **Pod Security Standards**:

| Level | Allows | Use for |
|---|---|---|
| **`privileged`** | Everything. No restrictions | Trusted infrastructure workloads |
| **`baseline`** | Blocks known privilege escalations; permissive otherwise | Most applications |
| **`restricted`** | Heavily locked down — non-root required, capabilities dropped, seccomp on | Security-sensitive workloads |

Applied as **namespace labels**, with three independent modes:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted   # reject violating Pods
    pod-security.kubernetes.io/audit: restricted     # allow, record in the audit log
    pod-security.kubernetes.io/warn: restricted      # allow, warn the user
```

| Mode | Effect |
|---|---|
| `enforce` | **Rejects** the Pod |
| `audit` | Allows it, logs a violation |
| `warn` | Allows it, returns a warning to the client |

The standard rollout is `warn` and `audit` first to find what would break, then
`enforce`. And note where PSA sits: it is an **admission** control, so it runs
**after** RBAC — it constrains what a Pod may look like, never who may create it.

### 1.13 Admission controllers

*Plugins that inspect a request after RBAC approved it, and either change it or
reject it. Mutating always runs before validating.*

```
authorized request
      │
      ▼
 MUTATING admission     → may CHANGE the object (inject defaults, sidecars)
      │
      ▼
 VALIDATING admission   → may only ACCEPT or REJECT
      │
      ▼
   persisted
```

| | Mutating | Validating |
|---|---|---|
| Can modify the object? | **Yes** | **No** |
| Can reject it? | Yes | Yes |
| Runs | **First** | **Second** |
| Example | `DefaultStorageClass`, `DefaultTolerationSeconds`, sidecar injection | `PodSecurity`, `ResourceQuota`, policy webhooks |

**The order is not arbitrary:** mutation must finish before validation, or a
plugin could approve an object that a later plugin then changes into something
invalid. Validation sees the final form.

Examples already met in earlier notes — proof this is machinery you have been
using all along:

| Plugin | Seen in | Type |
|---|---|---|
| `DefaultTolerationSeconds` | Note 03 §1.10 — the 300s eviction delay | Mutating |
| `DefaultStorageClass` | Note 06 §1.6 — fills in the default class | Mutating |
| `LimitRanger` | §1.9 above — injects resource defaults | Mutating |
| `ResourceQuota` | §1.9 above — rejects over-quota objects | Validating |
| `PodSecurity` | §1.12 above | Validating |

`ValidatingAdmissionWebhook` and `MutatingAdmissionWebhook` are the extension
points that let external systems participate — which is where the policy engines
from your day job live. *Those tools remain out of scope until 1 Dec per
`plan.md §2`; the mechanism is in scope, the products are not.*

### 1.14 cordon and drain

*Cordon stops new Pods arriving. Drain also evicts the ones already there.*

| Command | Does | Mechanism |
|---|---|---|
| `kubectl cordon <node>` | Marks it unschedulable. **Running Pods stay** | Adds the taint `node.kubernetes.io/unschedulable:NoSchedule` |
| `kubectl drain <node>` | Cordons **and evicts** every eligible Pod | Cordon, then delete Pods via the eviction API |
| `kubectl uncordon <node>` | Makes it schedulable again | Removes the taint |

This is note 03's taint machinery under a friendlier name — `cordon` is a taint,
and the Pods leave for the reasons §1.10 of that note describes.

Two flags that exist because of things you already know:

- **`--ignore-daemonsets`** is almost always required, because DaemonSet Pods
  tolerate the unschedulable taint (note 03 §1.5) and will not leave. Without the
  flag, drain refuses to proceed.
- **`--delete-emptydir-data`** is required if any Pod uses an `emptyDir`, because
  draining **destroys that data** (note 06 §1.3). The flag exists to make you
  acknowledge the loss.

### 1.15 The notion of a cluster upgrade

*Upgrading is not one action. It is a sequence, in a fixed order, one minor
version at a time — and the `drain` from §1.14 is one of its steps.*

*KCNA scope: the shape and the rules. The `kubeadm upgrade` procedure itself is
CKA material and stays deferred to Block 2.*

**Why clusters must be upgraded at all:** Kubernetes supports only the **three
most recent minor releases**, roughly a year of patches. Outside that window
there are no security fixes — the same argument that retired Ingress-NGINX in
note 05 §1.10.

**Rule 1 — one minor version at a time.** Skipping minor versions is
**unsupported**. Going from 1.33 to 1.36 means 1.33 → 1.34 → 1.35 → 1.36, each
hop validated separately. Patch upgrades within a minor (1.35.2 → 1.35.6) are
free.

**Rule 2 — control plane first, workers second. Never the reverse.** The reason
is the **version skew policy**, and `kube-apiserver` is the anchor everything
else is measured against:

| Component | May be, relative to kube-apiserver |
|---|---|
| **kube-apiserver** | The reference. In HA, instances within **1** minor of each other |
| kube-controller-manager, kube-scheduler | Up to **1** minor **older**. Never newer |
| **kubelet** | Up to **3** minors older (only 2, before v1.25). **Never newer** |
| kube-proxy | Same as kubelet — up to **3** older |
| `kubectl` | Within **1** minor, older **or** newer |

**"Never newer" is the load-bearing phrase.** A kubelet ahead of the API server
is unsupported and may fail to register, so upgrading a worker first can break
the node. Upgrading the control plane first is always safe, because every other
component is allowed to lag.

The sequence — and this is where §1.14 fits:

```
1. Upgrade the first control-plane node     (etcd, apiserver, scheduler, c-m)
2. Upgrade any remaining control-plane nodes
3. Then, for each worker, ONE AT A TIME:
       drain  ──►  upgrade kubelet  ──►  uncordon
       └─ §1.14. Pods move off first; the node takes work again afterwards
```

That is why `drain` and "cluster upgrade" are a **single curriculum bullet**:
drain is not a neighbouring topic, it is **step 3a**. Doing workers one at a time
is what keeps the workload serving throughout — the same reasoning as a rolling
Deployment rather than `Recreate` (note 03 §1.4).

**Managed vs self-managed** is the distinction most likely to be asked:

| | Managed (EKS, GKE, AKS) | Self-managed (kubeadm) |
|---|---|---|
| Control plane | **The provider upgrades it** — one API call | **You** upgrade each CP node yourself |
| Workers | Node groups, often rolled for you | You drain, upgrade and uncordon each one |
| Skew policy | Still applies — the provider enforces it | **Still applies, and nobody enforces it for you** |

The skew rules do not disappear on a managed cluster. On EKS they are why the
console refuses to upgrade a control plane too far ahead of your nodes — a rule
you have been obeying without needing to know it existed.

---

## 2. Objects & Fields That Matter

| Object | Key fields | Default | Gotcha |
|---|---|---|---|
| ServiceAccount | `automountServiceAccountToken` | `true` | Every namespace has `default`; Pod spec beats SA spec |
| Role / ClusterRole | `rules[].apiGroups/.resources/.verbs` | — | `""` = core group; resources are **plural, lowercase** |
| RoleBinding | `roleRef`, `subjects[]` | — | `roleRef` is **immutable** — delete and recreate to change it |
| ClusterRoleBinding | `roleRef`, `subjects[]` | — | Grants cluster-wide. Easy to over-grant |
| Secret | `data` (base64), `type`, `stringData` | opaque | **Encoded, not encrypted.** tmpfs on the node |
| ConfigMap | `data`, `binaryData` | — | Non-confidential only |
| SecurityContext | `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities`, `privileged` | all unset | Container level overrides Pod level |
| Namespace (PSA) | labels `pod-security.kubernetes.io/{enforce,audit,warn}` | none | Values: `privileged`, `baseline`, `restricted` |
| ResourceQuota | `spec.hard` | — | Forces every Pod to declare requests/limits |
| LimitRange | `spec.limits[].default/.defaultRequest/.max/.min` | — | Silently changes QoS class |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 2 (CKA, from 11 Sep) with
`kubectl create role/rolebinding`, `kubectl auth can-i` and `--dry-run` paths.*

---

## 4. Hands-On Lab

On the 3-node kubeadm cluster. **Target: 25 minutes.**

```bash
# 1. base64 is not encryption                                          (4 min)
kubectl create secret generic demo --from-literal=password=hunter2
kubectl get secret demo -o jsonpath='{.data.password}'; echo
kubectl get secret demo -o jsonpath='{.data.password}' | base64 -d; echo   # hunter2

# 2. The default ServiceAccount can do almost nothing                  (6 min)
kubectl create namespace lab
kubectl auth can-i list pods --as=system:serviceaccount:lab:default -n lab   # no

kubectl create role pod-reader --verb=get,list,watch --resource=pods -n lab
kubectl create rolebinding read-pods --role=pod-reader \
  --serviceaccount=lab:default -n lab
kubectl auth can-i list pods --as=system:serviceaccount:lab:default -n lab   # yes
kubectl auth can-i list pods --as=system:serviceaccount:lab:default -n default  # no

# 3. get does not imply list; pods/log is separate                     (5 min)
kubectl auth can-i get pods/log --as=system:serviceaccount:lab:default -n lab   # no
kubectl auth can-i --list --as=system:serviceaccount:lab:default -n lab

# 4. Pod Security Admission rejects, visibly                           (6 min)
kubectl label namespace lab pod-security.kubernetes.io/enforce=restricted
kubectl run bad --image=nginx -n lab          # REJECTED — read the message closely
kubectl label namespace lab pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl run ok --image=nginx -n lab           # accepted

# 5. Anyone who can create a Pod can read every Secret there           (4 min)
kubectl run reader -n default --image=busybox:1.36 --restart=Never -it --rm \
  --overrides='{"spec":{"volumes":[{"name":"s","secret":{"secretName":"demo"}}],
  "containers":[{"name":"reader","image":"busybox:1.36","stdin":true,"tty":true,
  "volumeMounts":[{"name":"s","mountPath":"/s"}]}]}}' -- cat /s/password

kubectl delete namespace lab; kubectl delete secret demo
```

---

## 5. Verification

```bash
kubectl auth can-i <verb> <resource> --as=<user> -n <ns>     # the decisive command
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>
kubectl get rolebinding,clusterrolebinding -A -o wide | grep <subject>
kubectl describe clusterrole <name>
kubectl get ns <ns> --show-labels | grep pod-security
kubectl get pod <p> -o jsonpath='{.spec.serviceAccountName}{"\n"}'
kubectl get resourcequota,limitrange -n <ns>
```

Never reason about permissions from the YAML. `kubectl auth can-i` asks the API
server the same question it will ask at request time.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `401 Unauthorized` | Credential invalid or expired | `kubectl config view` | Renew the cert or token |
| `403` naming **user/verb/resource** | RBAC — no rule permits it | `kubectl auth can-i ... --as=<user>` | Add a Role and binding |
| `403` naming a **plugin or webhook** | **Admission** rejected it after RBAC allowed it | Read the message for the plugin name | Fix the object, or the policy |
| Pod rejected on create in a labelled namespace | Pod Security Admission `enforce` | `kubectl get ns --show-labels` | Add the SecurityContext, or relax the level |
| `kubectl get pods` works by name, fails without one | `get` granted, **`list`** not | `kubectl auth can-i list pods --as=...` | Add the `list` verb |
| `kubectl logs` denied although pods are readable | `pods/log` subresource not granted | `kubectl auth can-i get pods/log --as=...` | Add the subresource |
| Pod cannot reach the API from inside | `automountServiceAccountToken: false`, or no RBAC for the SA | `kubectl auth can-i --list --as=system:serviceaccount:...` | Mount the token; bind a Role |
| Pod rejected: `must specify limits` | A **ResourceQuota** on CPU/memory exists | `kubectl get resourcequota -n <ns>` | Declare requests and limits |
| QoS class changed unexpectedly | A **LimitRange** injected defaults | `kubectl get limitrange -n <ns> -o yaml` | Set resources explicitly |
| `kubectl drain` refuses to start | DaemonSet Pods present | `kubectl get ds -A` | `--ignore-daemonsets` |
| Container will not start: `runAsNonRoot` | Image has no `USER`, so it runs as UID 0 | `kubectl describe pod` | Rebuild with `USER` (note 04 §1.14) |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| **Authentication** | **IAM** identities mapped to Kubernetes users/groups (access entries, or the older `aws-auth` ConfigMap). You never issue a certificate | **X.509 client certificates** signed by the cluster CA. There is no IAM and nothing external to map |
| Who is admin | The IAM principal that created the cluster gets implicit admin | Whoever holds `admin.conf` (note 01 §2.1) |
| Pod → cloud credentials | **IRSA / Pod Identity**: annotate a ServiceAccount, the Pod gets AWS credentials | A ServiceAccount token authenticates **only to the Kubernetes API**. Nothing else exists to authenticate to |
| Secret encryption at rest | Optional **KMS envelope encryption**, enabled with a checkbox | **Plain in etcd** unless you write an `EncryptionConfiguration` yourself |
| Losing access | Rare — IAM is the recovery path | Lose `admin.conf` with no backup and you are locked out of your own cluster |
| PSP legacy | Never existed on modern EKS; PSA from the start | Same PSA, but you set the namespace labels yourself |
| Cluster upgrade | One API call for the control plane; node groups often roll themselves, and the console enforces the skew policy for you | You upgrade every node yourself, workers one at a time with `drain`/`uncordon`, and **nothing stops you violating the skew policy** |

The habit to unlearn: on EKS, "permissions" means IAM **and** RBAC, and IAM does
the identity half. On vanilla there is only RBAC, and identity comes from a
certificate you or kubeadm signed. Every IAM reflex has no equivalent in the exam
environment.

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 2.*

---

## 9. Objectives Covered

KCNA areas **1.2 Administration** (access-control half) and **2.2 Security**.

- [ ] The 4C's, in order, and why the nesting matters
- [ ] Authentication → authorization → admission, and which produces 401 vs 403
- [ ] Authentication methods; that there is **no User object**
- [ ] ServiceAccounts, their tokens, and what changed in v1.24
- [ ] Role / ClusterRole / RoleBinding / ClusterRoleBinding — all four combinations
- [ ] Rule anatomy: apiGroups, resources, verbs; `get` ≠ `list`
- [ ] RBAC is additive; there are no deny rules
- [ ] Namespaces as a scope boundary, **not** a security boundary
- [ ] ResourceQuota vs LimitRange
- [ ] Secrets vs ConfigMaps; **base64 is not encryption**
- [ ] SecurityContext: `runAsNonRoot`, `readOnlyRootFilesystem`, capabilities
- [ ] Pod Security Admission: three levels, three modes; **PSP removed in v1.25**
- [ ] Admission controllers: mutating before validating
- [ ] cordon vs drain, and why `--ignore-daemonsets` is needed
- [ ] The notion of a cluster upgrade: one minor at a time, control plane first
- [ ] Version skew: kubelet up to 3 minors older, and never newer

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "Secrets are encrypted" | **base64-encoded.** Encryption at rest is a separate, opt-in configuration |
| "base64 protects the value" | It is reversible with no key, in one command |
| "There is a User object" | There is not. Identity comes from the credential |
| "Admission runs before authorization" | **authn → authz → admission**, always |
| "Validating admission can add defaults" | Only **mutating** modifies. Validating accepts or rejects |
| "A namespace isolates the network" | It does not. That is **NetworkPolicy** (note 05 §1.12) |
| "You can write a deny rule in RBAC" | RBAC is **additive only**. Remove the binding instead |
| "A Role can grant access to nodes" | Nodes are cluster-scoped — that needs a **ClusterRole** |
| "A ClusterRole always grants cluster-wide access" | With a **RoleBinding** it applies to one namespace only |
| "A Role can be used with a ClusterRoleBinding" | Invalid combination |
| "`get` on pods lets you list them" | Separate verbs. And `pods/log` is a separate resource |
| "PodSecurityPolicy is the current mechanism" | **Removed in v1.25.** It is Pod Security Admission |
| "PSA levels are enforce/audit/warn" | Those are the **modes**. The **levels** are privileged/baseline/restricted |
| "ServiceAccount tokens never expire" | Since **v1.24** they are bounded and die with the Pod |
| "ResourceQuota sets per-Pod defaults" | That is **LimitRange**. Quota caps the namespace total |
| "`cordon` evicts the running Pods" | It only blocks new ones. **`drain`** evicts |
| "`privileged: true` is fine inside a container" | It is effectively host root |
| "You can upgrade 1.33 straight to 1.36" | **One minor version at a time.** Skipping is unsupported |
| "Upgrade the workers first, then the control plane" | **Control plane first.** A kubelet must never be newer than the API server |
| "A kubelet may be at most 2 minors behind" | **Three**, since v1.25. Many blogs still say two |
| "Managed clusters are exempt from the skew policy" | It still applies — the provider enforces it instead of you |

**X ≠ Y**

- **Authentication ≠ authorization** — who you are vs what you may do; 401 vs 403
- **Authorization ≠ admission** — may you vs is this object acceptable
- **Mutating ≠ validating** — changes the object vs only judges it
- **Encoding ≠ encryption** — base64 vs a key
- **ConfigMap ≠ Secret** — non-confidential vs confidential (and tmpfs-backed)
- **Role ≠ ClusterRole** — namespaced vs cluster-wide permissions
- **RoleBinding ≠ ClusterRoleBinding** — where the grant applies
- **ClusterRole+RoleBinding ≠ ClusterRole+ClusterRoleBinding** — one namespace vs all
- **User ≠ ServiceAccount** — external, no object vs a real namespaced object
- **Namespace ≠ security boundary** — names and RBAC vs actual isolation
- **ResourceQuota ≠ LimitRange** — namespace total vs per-object rules
- **PSA level ≠ PSA mode** — privileged/baseline/restricted vs enforce/audit/warn
- **`cordon` ≠ `drain`** — block new vs also evict existing
- **`runAsNonRoot` ≠ `runAsUser`** — refuse UID 0 vs pick a specific UID
- **Minor upgrade ≠ patch upgrade** — one hop at a time vs free within a minor
- **`cordon` alone ≠ `drain` in an upgrade** — a node state vs step 3a of a sequence

---

## 10. Active Recall

Closed book, out loud. 21 questions.

1. Name the 4C's from outside in, and explain why the order matters.
2. Name the three gates every API request passes, in order. Which returns 401
   and which returns 403?
3. You get a 403. How do you tell whether RBAC or admission rejected it, from
   the message alone?
4. Where does a human user's username come from? Is there a `User` object?
5. Name three authentication methods and which identity kind uses each.
6. What is a ServiceAccount, which one does a Pod get by default, and what is
   its full username form?
7. What changed about ServiceAccount tokens in v1.24, and what does that fix?
8. Name the four RBAC objects and lay out the 2×2 of namespaced vs cluster-wide.
9. What does ClusterRole + RoleBinding produce, and why would anyone want that?
10. Which apiGroup string means the core group, and why does it have no name?
11. Why does a Role with only the `get` verb break `kubectl get pods`? And why
    does `kubectl logs` need something extra?
12. Can you write an RBAC rule that denies something? If not, how do you remove
    access?
13. Is a namespace a security boundary? Give two things it does and two it does
    not.
14. Distinguish ResourceQuota from LimitRange. Which one can change a Pod's QoS
    class, and how?
15. What is the real difference between a ConfigMap and a Secret? What does
    base64 provide?
16. Name three things that actually protect a Secret, and explain why
    `create pods` is effectively `read all secrets in this namespace`.
17. Name four SecurityContext fields and what each prevents. Which one is a hard
    stop at startup?
18. Name the three Pod Security **levels** and the three **modes**. What
    replaced what, and in which version?
19. Difference between `cordon` and `drain`. Why is `--ignore-daemonsets`
    normally required, and what does `--delete-emptydir-data` acknowledge?
20. You are on 1.33 and want 1.36. How many upgrades, and why not in one hop?
    Which goes first, control plane or workers, and which single skew rule
    forces that order?
21. How many minor versions may a kubelet lag behind kube-apiserver, and what is
    the one thing it may never be? Where does `drain` appear in the sequence?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — Two 403s that look identical

A developer runs `kubectl create deployment web --image=nginx -n prod` and gets a
403. You grant the missing RBAC. They retry and get **another 403**.

a. The first message named a user, a verb and a resource. Which gate was that,
   and what did you add to fix it?
b. The second names an admission webhook. Which gate is that, and why could it
   not have fired the first time? Use the ordering.
c. Explain why RBAC being correct is not sufficient for the request to succeed.
d. A colleague proposes adding a deny rule for the webhook's condition. Explain
   why that sentence contains two separate misunderstandings.
e. The namespace is labelled `pod-security.kubernetes.io/enforce=restricted` and
   the image runs as root. Name which component rejects it, at which gate, and
   the two changes — one in the Pod, one in the image — that fix it properly.

### Drill 2 — The over-permissioned ServiceAccount

An application's ServiceAccount in namespace `apps` should read ConfigMaps in
`apps` only. An audit shows it can read **Secrets in every namespace**. Nobody
recalls granting that.

a. Name every way a subject can accumulate permissions it was not directly
   granted. There are at least three.
b. Which single command lists everything it can actually do, and why is that
   better than reading the bindings?
c. You find a ClusterRoleBinding to the `view` ClusterRole. Explain precisely why
   that produces cluster-wide access, and what one-word change to the binding
   would have limited it to `apps`.
d. The fix is proposed as "add a Role that denies secrets". Explain why that
   cannot work, and give the correct fix.
e. The app never calls the Kubernetes API at all. Name the field that removes the
   credential entirely, the two places it can be set, and which wins.
f. Explain how this SA could read Secrets **even with no secrets permission at
   all**, if it can create Pods. Which permission is the real one to audit?

### Drill 3 — The namespace that was supposed to be isolated

A team is given namespace `tenant-a` with RBAC restricted to that namespace, a
ResourceQuota, and a LimitRange. They are told it is isolated.

a. List what that setup does isolate, and what it does not. Be specific about
   the network.
b. A Pod in `tenant-a` opens a connection to a database Pod in `tenant-b`. Does
   it succeed by default? Name the object that would stop it and the note it
   comes from.
c. They deploy a Pod with no `resources` block and it is rejected. Which of the
   two policy objects caused that, and why does its presence make resources
   mandatory?
d. They add resources and the Pod runs — but its QoS class is not what they
   expected. Which object changed it, and by what mechanism?
e. A Pod in `tenant-a` runs as root and exploits a kernel vulnerability. What
   does the namespace protect at that point? Name the layer of the 4C's that
   failed and the SecurityContext field that would have blocked the first step.
f. Rank by isolation value: NetworkPolicy, PSA `restricted`, RBAC scoping,
   ResourceQuota. Defend the ordering, and say which pair is closest.

### Drill 4 — Draining a node at 2 a.m.

You must patch node `w2`. It runs: 3 Deployment Pods, 1 DaemonSet Pod
(node-exporter), 1 StatefulSet Pod `db-1` with a bound PVC, and one Pod using an
`emptyDir` for a cache.

a. You run `kubectl cordon w2`. What happens to the five Pods, and what happens
   to Pods scheduled a minute later? Name the taint involved.
b. You run `kubectl drain w2` and it refuses to start. Which Pod caused that,
   why does it not leave, and which flag is required?
c. Which flag does the `emptyDir` Pod require, and what exactly are you agreeing
   to lose? Cite the lifetime rule.
d. `db-1` is evicted. Trace what must happen for it to run on another node —
   name the objects involved and the one condition that could leave it `Pending`
   forever on a cloud with zonal disks.
e. The three Deployment Pods reschedule immediately. Which controller creates
   the replacements, and why is the answer not "the Deployment"?
f. After patching you forget `uncordon`. Describe what you would observe over
   the next week, and which single command would have revealed it.
