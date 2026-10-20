---
exams: [KCNA, CKA, CKAD]
domain: Kubernetes API & Objects
kcna_domains: 1.1 Core Concepts
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/overview/working-with-objects, /working-with-objects/labels, /working-with-objects/namespaces, /overview/kubernetes-api, /architecture/garbage-collection, /extend-kubernetes/api-extension/custom-resources, /extend-kubernetes/operator, /reference/using-api/api-concepts
template: B
language: en
status: draft
written: 2026-08-22
revised: 2026-08-23 (v2 — depth standard: watch mechanics, ownerReferences, finalizers, real CRD, scenario drills)
k8s_version_checked_against: v1.36 docs
---

# Kubernetes API & Objects

## ⚡ Reading map — read this first

This note serves **three exams**. Read the KCNA column now; the rest is
deliberate prepay for CKA and CKAD and stays here untouched.

**KCNA weight of this note:** curriculum area 1.1, roughly **6–7 questions out
of 60**. It is a higher-yield note than 01 for KCNA — labels, namespaces and the
object model appear all over the exam, including inside other domains.

| Section | KCNA (2 Sep) | CKA/CKAD | Note |
|---|---|---|---|
| §1.1 `spec` vs `status` | ✅ **core** | ✅ | The idea the whole exam rests on |
| §1.2 Four required fields | ✅ **core** | ✅ | KCNA: the four fields + name rules. `uid` nuance is CKA |
| §1.3 API groups & versions | ✅ **core** | ✅ | **alpha/beta/stable is a guaranteed KCNA question.** Skip `/api` vs `/apis` |
| §1.4 Request path | ✅ read | ✅ | KCNA: authn → authz → admission, in that order |
| §1.5 `watch` & `resourceVersion` | ❌ **skip now** | ✅ | Explains note 01, but KCNA never asks |
| §1.6 kubectl | ✅ **core** | ✅ | KCNA: get / describe / logs / exec / apply. Skip field selectors |
| §1.7 apply vs create | ⚠️ partial | ✅ | KCNA: `create` fails if it exists, `apply` merges. **Skip server-side apply** |
| §1.8 Labels & selectors | ✅ **core** | ✅ | **Highest-yield section in the note.** Learn both selector types |
| §1.9 Namespaces | ✅ **core** | ✅ | The four defaults, namespaced vs cluster-scoped, *not* a network boundary |
| §1.10 ownerReferences & GC | ⚠️ partial | ✅ **core** | KCNA: deleting a parent deletes its children. **Skip the 3 cascade policies** |
| §1.11 Finalizers | ❌ **skip now** | ✅ | Pure CKA |
| §1.12 CRDs & operators | ✅ read | ✅ | KCNA: CRD = schema, operator = CRD + controller. **Skip the full CRD YAML** |
| §2.1 metadata anatomy | ⚠️ skim | ✅ | KCNA: name, namespace, labels, annotations. The rest is CKA |
| §2.2 spec/status example | ✅ read | ✅ | Best single illustration of §1.1 — read the annotations, skip `generation` |
| §2.3 Where kinds live | ✅ **core** | ✅ | Worth memorising the apiVersion column |
| §5 Verification | ❌ skip now | ✅ | Needs a cluster you do not have until 30 Aug |
| §6 Failure Modes | ⚠️ skim | ✅ | KCNA: the empty-Service and wrong-namespace rows |
| §7 EKS vs Vanilla | — | ✅ | Personal blind-spot map, not an exam section |
| §10 Active Recall | Q 1–4, 6, 7, 9–14, 20–25, 34, 35, 37–39 | all 40 | ~23 questions are KCNA scope |
| §11 Scenario Drills | Scenarios 1 and 4 | all 6 | The others need §1.10 and §1.11 |

**KCNA path: §1.1 → 1.2 → 1.3 → 1.4 → 1.6 → 1.8 → 1.9 → 1.12 → 2.2 → 2.3**,
then the 23 recall questions. About 60 minutes.

Everything marked ❌ is not wasted — it is written, verified and waiting for
3 September.

---

## 1. Core Concepts

### 1.1 What an object is, and why `spec`/`status` is the whole philosophy

> 🟢 **KCNA · READ CLOSELY** — core exam material.

Official wording: *"Kubernetes objects are persistent entities in the Kubernetes
system."* They are **records of intent**. Creating one is not a command that runs
and finishes — it is a promise the cluster now has to keep, forever, until you
withdraw it.

Every object carries two nested fields, and they are the YAML form of the control
loop from note 01:

| Field | Meaning | Who writes it |
|---|---|---|
| **`spec`** | The **desired state**. What you want to exist. | **You** |
| **`status`** | The **actual state**, as observed by the system. | **Kubernetes** |

```
  You write spec  ─────────▶  etcd  ◀─────────  controller writes status
                                │
                                │  controller watches, compares, acts
                                ▼
                          real world converges
```

**You never write `status`. Kubernetes never invents `spec`.** That is the whole
contract. When `kubectl get deploy` prints `2/3`, you are reading `status` (2)
against `spec` (3) — a gap a controller is currently working to close.

Modern APIs enforce this: `status` is a **separate subresource** with its own
endpoint (`/status`) and its own RBAC. A controller can be allowed to write
status without being allowed to change spec.

### 1.2 The four required fields

> 🟡 **KCNA · PARTIAL** — the four fields and the name rules are core. The `name` vs `uid` box is CKA — skim it.

Every single object, without exception:

```yaml
apiVersion: apps/v1          # which API group and version handles this object
kind: Deployment             # the object type
metadata:                    # identity
  name: web
  namespace: default
spec:                        # desired state — shape depends entirely on kind
  replicas: 3
```

- **`apiVersion`** — group and version (`v1`, `apps/v1`, `batch/v1`).
- **`kind`** — the type. Always PascalCase: `Pod`, not `pod`.
- **`metadata`** — must contain `name`; also holds `namespace`, `labels`,
  `annotations`, and system-generated fields.
- **`spec`** — desired state.

> **`name` vs `uid` — a distinction the exam likes.**
> A **`name`** is chosen by you and unique **per kind, per namespace**. You can
> have a Pod named `web` and a Service named `web` in the same namespace, and a
> Pod named `web` in every other namespace.
> A **`uid`** is generated by Kubernetes and unique **across the cluster, across
> time**. It is what distinguishes a Pod named `web` from a *different* Pod named
> `web` created after the first was deleted. This matters because
> `ownerReferences` (§1.10) point at **uid**, not name — so a recreated parent
> does not accidentally adopt the old parent's children.

**Name rules:** lowercase alphanumeric, `-` and `.`, max **253** characters — a
DNS subdomain name. No uppercase, no underscores. This bites people from AWS,
where resource names accept almost anything.

### 1.3 The API is a REST tree, not a flat namespace

> 🟢 **KCNA · READ CLOSELY** — core exam material. **alpha/beta/stable is a near-guaranteed KCNA question.** Skip the `/api` vs `/apis` path detail.

`apiVersion` is not decoration. It selects a real HTTP path:

```
apiVersion: v1              →  /api/v1/namespaces/default/pods/web
apiVersion: apps/v1         →  /apis/apps/v1/namespaces/default/deployments/web
apiVersion: batch/v1        →  /apis/batch/v1/namespaces/default/jobs/backup
```

Note `/api/` versus `/apis/`. The **core group** is the original API from before
groups existed: it has **no group name**, only `v1`, and it lives under `/api/`.
Everything designed afterwards lives under `/apis/<group>/<version>/`.

| Core group (`v1`, under `/api/`) | Named groups (under `/apis/`) |
|---|---|
| Pod, Service, ConfigMap, Secret | `apps` — Deployment, ReplicaSet, StatefulSet, DaemonSet |
| Namespace, Node, ServiceAccount | `batch` — Job, CronJob |
| PersistentVolume, PersistentVolumeClaim | `networking.k8s.io` — Ingress, NetworkPolicy |
| Event, Endpoints | `rbac.authorization.k8s.io` — Role, ClusterRole |

**Vocabulary that gets tested:** a **kind** is the type in YAML (`Deployment`);
a **resource** is the lowercase plural in the URL (`deployments`). RBAC rules are
written against **resources**, not kinds — that is why a Role says
`resources: ["pods"]` and never `["Pod"]`.

**Version maturity — memorise the table, not the vibes:**

| Level | Example | On by default | What it promises |
|---|---|---|---|
| **Alpha** | `v1alpha1` | **No** — must be enabled with `--runtime-config` | May be buggy, may be dropped **without notice**, may lose data. Disabled because it is dangerous, not because it is new. |
| **Beta** | `v1beta1` | Varies by release | Well tested, but the **schema may still change incompatibly**, and the API may be removed after a deprecation window |
| **Stable (GA)** | `v1` | Yes | The name persists for many subsequent releases |

The progression is `v1alpha1` → `v1beta1` → `v1`. **These express compatibility
guarantees, not code quality.** A `v1beta1` API can be rock-solid in production
and still be renamed next release — that is exactly what the label warns you about.

### 1.4 What happens to a request — the short version

> 🟢 **KCNA · READ ONCE** — KCNA needs the order: **authentication → authorization → admission**. That is it.

Full detail lives in note 07, but the shape belongs here because it explains
several error messages:

```
kubectl  ──HTTPS :6443──▶  ┌─────────────────────────────────┐
                           │ 1. Authentication  who are you? │  → 401
                           │ 2. Authorization   may you?     │  → 403
                           │ 3. Admission       mutate/valid │  → 403
                           │ 4. Persist to etcd              │
                           └─────────────────────────────────┘
```

- **401 Unauthorized** = your certificate/token was not accepted at all.
- **403 Forbidden** = you were identified, RBAC said no. The message names the
  user, the verb and the resource — read it, it tells you exactly what to fix.
- **403 from admission** = RBAC already said yes; a plugin or webhook then
  refused the *content* of the object. The message names a **plugin or
  webhook**, never a verb — that is how you tell the two 403s apart.
- Admission is where defaults get injected. The 300-second node-failure
  tolerations from note 01 §1.11 are added to your Pod **here**, not by you.

**Do not confuse admission with schema validation.** They are different
rejections at different moments, and only one of them is admission:

| | Schema validation | Admission |
|---|---|---|
| Asks | Is this a legal Kubernetes object? | The object is legal — do we allow it *here*? |
| Fails on | Misspelled field, wrong type, missing required value | The object violates a policy |
| Decided by | The **API server itself** | A **plugin or webhook** |
| Can be disabled | No | Yes — admission plugins are configurable |
| Code | **422 Unprocessable Entity** | **403 Forbidden** |

Reading rule: **`is invalid` naming a field → 422, the API server.
`denied` naming a webhook or plugin → 403, admission.**

Ordering, precisely: mutating admission → schema validation → validating
admission → etcd. Schema validation sits *inside* that sequence but is not an
admission controller.

### 1.5 `watch`, `resourceVersion`, and why nothing polls

> 🔴 **KCNA · SKIP FOR NOW** — Explains *why* note 01 works, but KCNA never asks about `resourceVersion` or optimistic concurrency. Comes back 3 Sep for CKA.

Every controller, every kubelet and `kubectl get -w` all use the same mechanism.
Understanding it removes most of the mystery from note 01.

- A `LIST` returns objects **plus a `resourceVersion`** — a cluster-wide logical
  clock, not a timestamp.
- A `WATCH` says *"stream me every change since resourceVersion N"*. The API
  server holds the connection open and pushes ADDED / MODIFIED / DELETED events.
- **Nothing polls etcd in a loop.** This is why a 5000-node cluster does not melt
  the datastore, and why the kubelet finds out about its Pod within milliseconds.

`resourceVersion` also gives **optimistic concurrency**. `kubectl apply` sends the
version it read; if someone else wrote in between, the API server rejects it with
a conflict. That is the origin of:

```
Error from server (Conflict): Operation cannot be fulfilled on deployments.apps "web":
the object has been modified; please apply your changes to the latest version and try again
```

It is not a bug — it is the API server refusing to let you silently clobber
somebody else's write.

### 1.6 kubectl is just an HTTP client

> 🟡 **KCNA · PARTIAL** — core: `get`, `describe`, `logs`, `exec`, `apply`, `delete`, `explain`. Skip the field-selector subsection.

Everything `kubectl` does you could do with `curl` against `:6443`. Prove it to
yourself once and the tool stops feeling magical:

```bash
kubectl get pods -v=8          # prints every HTTP request it makes
```

| Command | What it does | When you reach for it |
|---|---|---|
| `kubectl get <kind>` | List, short form | First look |
| `kubectl get <kind> <name> -o yaml` | The full object, `spec` **and** `status` | When you need real state |
| `kubectl describe <kind> <name>` | Summary **+ Events** | **Always first when something is broken** |
| `kubectl logs <pod> [-c <ctr>] [--previous]` | Container output | App-level failure |
| `kubectl exec -it <pod> -- sh` | Shell inside the container | Interactive debugging |
| `kubectl apply -f <file>` | Declarative create-or-update | The normal way to work |
| `kubectl create <kind> <name>` | Imperative create — **fails if it exists** | Speed, and generating YAML |
| `kubectl explain <kind>.<field>` | Field docs **from the cluster itself** | You forgot a field path |
| `kubectl api-resources` | Every kind, its group, its short name, and whether it is namespaced | Discovering CRDs |
| `kubectl api-versions` | Every group/version this cluster serves | Checking support |
| `kubectl auth can-i <verb> <resource>` | RBAC self-check | Before blaming the cluster |

Two that are underused and that the exam rewards:

```bash
# The field path, without internet. Works for CRDs too.
kubectl explain pod.spec.containers.resources
kubectl explain deployment.spec.strategy --recursive

# Is this kind namespaced? Which group? What is its short name?
kubectl api-resources | grep -i ingress
```

**Field selectors** are the other half of querying, and people forget they exist
because labels get all the attention. They filter on **object fields**, not
labels, and only certain fields are indexed:

```bash
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector spec.nodeName=worker-01
kubectl get events --field-selector type=Warning
```

### 1.7 `apply` vs `create` vs `replace` vs `patch`

> 🟡 **KCNA · PARTIAL** — KCNA needs one line: **`create` fails if the object exists, `apply` merges**. **Skip server-side apply and `managedFields`.**

| | `create` | `apply` | `replace` | `patch` |
|---|---|---|---|---|
| Object absent | creates | creates | **fails** | fails |
| Object present | **fails** | **merges** | overwrites whole object | changes named fields |
| Style | imperative | **declarative** | imperative | imperative |
| Remembers prior config | no | **yes** | no | no |

`apply` is what makes GitOps possible: applying the same file twice is a no-op,
and applying a changed file produces exactly the diff. Same instinct as
`terraform apply` — different tool, identical idea.

**How `apply` knows what you removed.** Deleting a field from your YAML must
delete it from the cluster, but the cluster cannot tell "I removed this" from "I
never set this". Classic `apply` solves it by storing your last submission in the
annotation `kubectl.kubernetes.io/last-applied-configuration` and three-way
merging (last-applied, your file, live object). **Server-side apply** replaces
that hack with `metadata.managedFields`, where the API server tracks which
manager owns which field — which is why two controllers fighting over one field
now produces a readable conflict instead of a silent flap.

### 1.8 Labels, selectors, annotations

> 🟢 **KCNA · READ CLOSELY** — core exam material. **Highest-yield section in either note** — labels reappear inside networking, security and troubleshooting questions.

**Labels** are key/value pairs used to **identify and select**. They are the glue
of the entire system: a Service finds its Pods by label, a ReplicaSet owns its
Pods by label, a NetworkPolicy targets Pods by label, the scheduler places Pods by
node labels.

```yaml
metadata:
  labels:
    app.kubernetes.io/name: web        # prefixed key (recommended convention)
    tier: frontend
    environment: production
```

Rules: key and value each max **63 characters**, alphanumeric plus `-`, `_`, `.`.
Keys may carry an optional DNS-subdomain prefix and a slash:
`app.kubernetes.io/name`. Prefixed keys are how tools avoid colliding with yours.

**Selectors** — two kinds, and both appear in YAML as well as on the CLI:

```bash
# Equality-based:  =   ==   !=
kubectl get pods -l environment=production
kubectl get pods -l 'tier!=frontend'
kubectl get pods -l 'environment=production,tier=frontend'   # comma = AND

# Set-based:  in   notin   exists (bare key)   !exists (!key)
kubectl get pods -l 'environment in (production, staging)'
kubectl get pods -l 'tier notin (frontend)'
kubectl get pods -l 'partition'      # has the key, any value
kubectl get pods -l '!partition'     # does NOT have the key
```

```yaml
# In YAML, a Service takes ONLY equality-based (a plain map):
spec:
  selector:
    app: web

# A Deployment/ReplicaSet takes the richer form:
spec:
  selector:
    matchLabels:
      app: web
    matchExpressions:
    - {key: tier, operator: In, values: [frontend, backend]}
```

> That asymmetry is examinable: **Service selectors cannot express set-based
> logic.** They are a flat map and nothing more.

**Annotations** are also key/value, but they are **not selectable**. They exist to
attach non-identifying metadata that tools read: build numbers, git commits,
ingress controller tuning, `kubectl.kubernetes.io/last-applied-configuration`.

> **One-line rule:** if you would ever want to *find* objects by it, it is a
> **label**. If it is information merely *attached* to the object, it is an
> **annotation**. Annotations have no practical size cap; labels stop at 63 chars.

### 1.9 Namespaces and scope

> 🟢 **KCNA · READ CLOSELY** — core exam material. Learn the four defaults, the namespaced-vs-cluster-scoped pairs, and that a namespace is **not** a network boundary.

Namespaces isolate **groups of resources within a single cluster**. Names must be
unique within a namespace, not across them.

**The four initial namespaces:**

| Namespace | What lives there |
|---|---|
| `default` | Your objects when you do not say otherwise |
| `kube-system` | Kubernetes' own components and add-ons |
| `kube-public` | Readable by **everyone, including unauthenticated users**. Holds `cluster-info`. Rarely used otherwise. |
| `kube-node-lease` | The node heartbeat Leases from note 01 §1.10 |

**Namespaced vs cluster-scoped** — memorise the pairs:

| Namespaced | Cluster-scoped |
|---|---|
| Pod, Service, Deployment, ReplicaSet | **Node** |
| ConfigMap, Secret, ServiceAccount | **Namespace** itself |
| **Role, RoleBinding** | **ClusterRole, ClusterRoleBinding** |
| **PersistentVolumeClaim**, Ingress, Job | **PersistentVolume**, **StorageClass** |
| LimitRange, ResourceQuota | **CustomResourceDefinition** |

The pattern: things representing **physical or cluster-wide infrastructure** are
cluster-scoped; things representing **your workload** are namespaced. A PV is a
real disk somewhere, so it is cluster-scoped; a PVC is your app asking for one,
so it is namespaced.

```bash
kubectl api-resources --namespaced=false     # learn this output by heart
```

DNS consequence: a Service is reachable at
`<service>.<namespace>.svc.cluster.local`. Same namespace → bare `<service>`
works. Across namespaces → at least `<service>.<namespace>`.

> **When NOT to use namespaces.** The docs are blunt: *"For clusters with a few to
> tens of users, you should not need to create or think about namespaces at all."*
> They exist for many users across teams, isolation and access control — not for
> tidiness.
>
> **And they are not a network boundary.** Pods in different namespaces reach each
> other freely. Only a **NetworkPolicy** stops that.

### 1.10 `ownerReferences` and garbage collection

> 🟡 **KCNA · PARTIAL** — KCNA needs one idea: **deleting a parent deletes its children, via `ownerReferences`**. **Skip the three cascade policies.**

This is the mechanism behind "I deleted the Deployment and the Pods vanished",
and it is the answer to *who deleted my Pods*.

Every dependent object carries a pointer to its owner in **`metadata.ownerReferences`**:

```yaml
# A Pod created by a ReplicaSet:
metadata:
  name: web-7d4b8c9f5-x2mnp
  ownerReferences:
  - apiVersion: apps/v1
    kind: ReplicaSet
    name: web-7d4b8c9f5
    uid: 8f3a2b1c-...          # ← points at the UID, not the name
    controller: true            # this owner is the managing controller
    blockOwnerDeletion: true    # owner cannot finish deleting until I am gone
```

The **garbage-collector-controller** watches for objects whose owner no longer
exists and deletes them. Kubernetes sets these references automatically; you
rarely write them by hand.

Two hard rules the docs state and the exam tests:

- **Cross-namespace owner references are not allowed.** An owner must live in the
  same namespace as its dependent.
- **A cluster-scoped object cannot own a namespaced one.** A dangling reference
  makes the dependent a garbage-collection candidate.

**Three cascading-deletion policies:**

| Policy | Owner | Dependents | kubectl |
|---|---|---|---|
| **Background** (default) | deleted **immediately** | cleaned up asynchronously afterwards | `--cascade=background` |
| **Foreground** | enters "deletion in progress", finishes **last** | deleted **first** | `--cascade=foreground` |
| **Orphan** | deleted | **kept**, their `ownerReferences` stripped | `--cascade=orphan` |

`--cascade=orphan` is the one worth remembering as a *technique*: it lets you
delete a Deployment while its Pods keep serving traffic, then hand them to a new
owner. It is also how you accidentally leave a cluster littered with unowned
ReplicaSets.

Kubernetes also garbage-collects things that have no owner at all: terminated
Pods, completed Jobs, expired CSRs, unused images and containers on a node, and
the Lease of a deleted Node.

### 1.11 Finalizers — why deletion sometimes hangs

> 🔴 **KCNA · SKIP FOR NOW** — Pure CKA. KCNA does not ask why a namespace hangs in `Terminating`. Comes back 3 Sep for CKA.

A **finalizer** is a string in `metadata.finalizers` that means *"do not actually
delete this object until I have cleaned up"*.

```yaml
metadata:
  name: my-pvc
  finalizers:
  - kubernetes.io/pvc-protection
```

The sequence:

1. You issue `DELETE`. The API server does **not** remove the object.
2. It sets `metadata.deletionTimestamp` — the object is now *terminating*.
3. Controllers watching it do their cleanup (detach a volume, delete a cloud
   load balancer, deregister from an external system).
4. Each removes **its own** finalizer string.
5. When the list is empty, the object is finally deleted.

**This is the complete explanation for a Namespace stuck in `Terminating`
forever.** Something inside it has a finalizer whose controller is gone or
failing, so step 4 never happens.

```bash
kubectl get ns stuck -o jsonpath='{.spec.finalizers}{"\n"}{.metadata.finalizers}'
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n1 kubectl get -n stuck --ignore-not-found     # find what is left
```

> Force-removing a finalizer is a last resort: you are telling Kubernetes to skip
> the cleanup, which can leak real cloud resources. Know why it is stuck first.

### 1.12 CRDs, custom resources and operators

> 🟡 **KCNA · PARTIAL** — core idea: **CRD = schema only; operator = CRD + controller**. **Skip the full CRD YAML** — you will not be asked to write one.

A **CustomResourceDefinition** extends the API with your own `kind`. Register a
CRD and the API server accepts, validates, versions and stores that kind, and
`kubectl get <yourkind>` just works — no code written.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com          # MUST be <plural>.<group>
spec:
  group: example.com
  scope: Namespaced                    # or Cluster
  names:
    kind: Database                     # PascalCase, singular — used in YAML
    plural: databases                  # lowercase — used in the URL and RBAC
    singular: database
    shortNames: [db]                   # kubectl get db
  versions:
  - name: v1
    served: true                       # answer requests at this version
    storage: true                      # persist in this version (exactly ONE true)
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              engine: {type: string, enum: [mysql, postgres]}
              version: {type: string}
            required: [engine, version]
          status:
            type: object
```

Then instances look like any other object:

```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: orders-db
spec:
  engine: postgres
  version: "16"
```

**But a CRD alone does nothing.** It is a typed, validated table in etcd. It
creates no Pods, provisions no database. Behaviour needs a controller:

```
CRD                 defines the schema — the kind now exists
  ↓
Custom Resource     an instance — a validated record in etcd
  ↓
Custom Controller   watches that kind and acts (the same loop as note 01)
  ↓
Operator            = CRD + controller + operational knowledge
```

Official framing: an operator *"captures the key aim of a human operator who is
managing a service"* — someone who knows how the system should behave, how to
deploy it and how to react to problems — and encodes that in software.

**CRD vs aggregated API server:** a CRD is declarative, stored in etcd, and free.
An **aggregated API server** is your own API server registered via an `APIService`
object — needed only when you require custom storage, custom verbs, or logic the
API server cannot express. KCNA needs the distinction to exist, not the detail.

**Custom resource vs ConfigMap:** use a CR when you want schema validation,
versioning, per-resource RBAC, and a controller that *reacts*. Use a ConfigMap for
inert key/value app configuration nobody watches.

> You have already used operators without naming them. Anything at work that added
> new `kubectl get` kinds — cert-manager, a Kyverno `ClusterPolicy`, an Istio
> `VirtualService` — is a CRD, and something is reconciling it. *(Those tools stay
> out of scope until 1 Dec; the pattern does not.)*

---

## 2. Objects & Fields That Matter

### 2.1 Anatomy of `metadata`

> 🟡 **KCNA · SKIM** — KCNA: `name`, `namespace`, `labels`, `annotations`. The other eight fields are CKA.

| Field | Written by | Why you care |
|---|---|---|
| `name` | you | Unique per kind per namespace. DNS subdomain, ≤ 253 chars |
| `namespace` | you | Absent = whatever your context says, usually `default` |
| `labels` | you | **Selectable.** ≤ 63 chars per key and value |
| `annotations` | you / tools | **Not selectable.** No practical size cap |
| `uid` | Kubernetes | Cluster-wide unique, across time. What `ownerReferences` point at |
| `resourceVersion` | Kubernetes | The watch/optimistic-concurrency token (§1.5) |
| `generation` | Kubernetes | Increments when **`spec`** changes — not on status writes |
| `creationTimestamp` | Kubernetes | — |
| `ownerReferences` | controllers | Cascading deletion (§1.10) |
| `finalizers` | controllers / you | Blocks deletion until cleanup runs (§1.11) |
| `deletionTimestamp` | Kubernetes | Present ⇒ the object is **terminating** |
| `managedFields` | API server | Server-side apply field ownership (§1.7) |

### 2.2 A real object, `spec` and `status` side by side

> 🟢 **KCNA · READ ONCE** — the best single illustration of §1.1. Read the annotations; skip the `generation` vs `observedGeneration` point.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: default
  uid: 3f2b1a90-7c4e-4d11-9a2f-5e8b6c1d0a33
  generation: 2                       # spec has been edited twice
  resourceVersion: "184203"
  labels:
    app: web

spec:                                 # ─── YOU wrote everything below ───
  replicas: 3
  selector:
    matchLabels:
      app: web                        # must match template.metadata.labels
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  template:                           # the Pod template — a Pod spec inside
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27

status:                               # ─── KUBERNETES wrote everything below ───
  observedGeneration: 2               # the controller has seen spec v2
  replicas: 3
  readyReplicas: 2                    # ← the "2/3" you see in kubectl get
  availableReplicas: 2
  updatedReplicas: 3
  conditions:
  - type: Available
    status: "False"
    reason: MinimumReplicasUnavailable
```

Three things to read out of that:

- `readyReplicas: 2` against `spec.replicas: 3` **is** the gap the controller is
  closing. `kubectl get` just formats it as `2/3`.
- `observedGeneration` vs `generation` tells you whether the controller has even
  *seen* your latest edit. If they differ, the controller is behind or dead —
  a fast way to spot a stopped controller-manager.
- `spec.selector.matchLabels` **must** match `spec.template.metadata.labels`. A
  mismatch is rejected on `apply`, and it is a favourite exam trap.

### 2.3 Where kinds live

> 🟢 **KCNA · READ CLOSELY** — core exam material. Worth memorising the `apiVersion` column outright.

| Kind | apiVersion | Scope |
|---|---|---|
| Pod, Service, ConfigMap, Secret, Namespace, ServiceAccount, Endpoints | `v1` | namespaced |
| **Node**, **PersistentVolume** | `v1` | **cluster** |
| Deployment, ReplicaSet, StatefulSet, DaemonSet | `apps/v1` | namespaced |
| Job, CronJob | `batch/v1` | namespaced |
| Ingress, NetworkPolicy | `networking.k8s.io/v1` | namespaced |
| Role, RoleBinding | `rbac.authorization.k8s.io/v1` | namespaced |
| **ClusterRole, ClusterRoleBinding** | `rbac.authorization.k8s.io/v1` | **cluster** |
| **StorageClass** | `storage.k8s.io/v1` | **cluster** |
| **CustomResourceDefinition** | `apiextensions.k8s.io/v1` | **cluster** |
| HorizontalPodAutoscaler | `autoscaling/v2` | namespaced |

---

## 3. Speed Patterns

> ⚪ **NOT AN EXAM SECTION** — Empty until Block 2 (CKA).

<!-- EMPTY UNTIL BLOCK 2 (CKA). Do not fill during KCNA. -->

---

## 4. Hands-On Lab

> 🔴 **KCNA · SKIP FOR NOW** — Needs the kubeadm cluster, which does not exist until 30 Aug. Comes back 3 Sep for CKA.

> **Deferred until Sun 30 Aug**, when the kubeadm cluster exists.

1. Create two namespaces, put a Pod with the same name in each, prove both exist
   and that `uid` differs.
2. Label the Pods differently. Select each with an equality-based selector, then
   with a set-based one. Add an annotation and prove you cannot select on it.
3. `kubectl get pods -v=8` and read the actual HTTP request.
4. Create a Deployment. Find the ReplicaSet's `ownerReferences`, then the Pods'.
   Draw the chain. Delete the Deployment with `--cascade=orphan` and watch the
   Pods survive.
5. Create a PVC with no matching PV, then delete it — watch it hang on the
   `kubernetes.io/pvc-protection` finalizer.
6. Apply the `Database` CRD above, create an `orders-db` instance, and confirm
   `kubectl get db` works and that **nothing happens**. That is the lesson.

---

## 5. Verification

> 🔴 **KCNA · SKIP FOR NOW** — Needs a cluster. Run these on 30 Aug. Comes back 3 Sep for CKA.

```bash
# Everything this cluster knows: kind, short name, group, namespaced?
kubectl api-resources -o wide
kubectl api-resources --namespaced=false        # memorise this list

# Field docs, straight from the cluster — works for CRDs too
kubectl explain deployment.spec.strategy
kubectl explain pod.spec.containers.livenessProbe --recursive

# spec vs status, and whether the controller has seen your edit
kubectl get deploy web -o jsonpath='{.metadata.generation} {.status.observedGeneration}{"\n"}'

# The ownership chain, top to bottom
kubectl get rs -l app=web -o jsonpath='{.items[*].metadata.ownerReferences[*].kind}{"\n"}'
kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.ownerReferences[0].name}{"\n"}'

# Selectors
kubectl get pods -l 'environment in (prod,staging)' --show-labels
kubectl get pods -l '!tier'
kubectl get pods --field-selector spec.nodeName=worker-01

# Why is this Service empty?
kubectl get endpointslice -l kubernetes.io/service-name=web

# What is blocking this deletion?
kubectl get ns stuck -o jsonpath='{.spec.finalizers}{"\n"}'

# Am I even allowed?
kubectl auth can-i create deployments -n default
kubectl auth can-i --list
```

---

## 6. Failure Modes

> 🟡 **KCNA · SKIM** — KCNA: the **Service with no endpoints** row and the **wrong namespace** row. The rest is CKA.

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `no matches for kind "Ingress" in version "extensions/v1beta1"` | Removed apiVersion | `kubectl api-versions \| grep networking` | Update to `networking.k8s.io/v1` |
| `Error from server (AlreadyExists)` | `create` on an existing object | — | Use `apply` |
| `Error from server (Conflict): the object has been modified` | Someone else wrote between your read and write | — | Re-read and re-apply. Expected, not a bug |
| `Error from server (Forbidden): ... cannot list resource "pods"` | RBAC | `kubectl auth can-i list pods` | Fix the Role/Binding — the message names user, verb and resource |
| Service exists but **no endpoints** | `spec.selector` matches no Pod labels | `kubectl get endpointslice`; `kubectl get pods --show-labels` | Fix label or selector. A typo in either is **completely silent** |
| `kubectl get pods` empty but the app is running | Wrong namespace | `kubectl get pods -A` | `-n <ns>` or set it in the context |
| Namespace stuck in `Terminating` | A finalizer's controller is gone (§1.11) | `kubectl get ns <n> -o jsonpath='{.spec.finalizers}'` | Remove the blocking resource, or its controller |
| Deleted a Deployment, Pods still running | `--cascade=orphan`, or `ownerReferences` were stripped | `kubectl get pods -o jsonpath='{.items[*].metadata.ownerReferences}'` | Delete them by label |
| `the server doesn't have a resource type "xyz"` | CRD not installed | `kubectl api-resources \| grep xyz` | Install the CRD / operator |
| Object name rejected | Uppercase or underscore | — | Lowercase, `-` and `.` only, ≤ 253 chars |
| Deployment applies but nothing happens | `selector.matchLabels` ≠ `template.metadata.labels`, or the controller-manager is down | Compare `generation` vs `observedGeneration` | Fix labels, or see note 01 §1.6 |
| CRD applied, `kubectl get` works, nothing is created | **There is no controller.** Working as designed | `kubectl get pods -A \| grep operator` | Install the operator, not just the CRD |

---

## 7. EKS vs Vanilla ← rewrite this section in your own words

> ⚪ **NOT AN EXAM SECTION** — Your personal blind-spot map, not an exam section.

> **Learner-owned section.** Starting point below. Add rows from your day job.

| Behaviour | On EKS | On kubeadm (what the exam tests) |
|---|---|---|
| The API itself | Identical | Identical — this is the whole point of Kubernetes |
| API server version | You choose a minor version; AWS owns the process | You own every flag in the static Pod manifest |
| Enabling an alpha API | **Impossible.** No `--runtime-config` access | Edit `--runtime-config` / `--feature-gates`, kubelet restarts it |
| Admission plugins | Fixed by AWS, plus AWS's own webhooks | `--enable-admission-plugins`, visible and editable |
| `kubectl api-resources` | Includes AWS CRDs (`eniconfigs`, `securitygrouppolicies`, `targetgroupbindings`) | Only what you installed |
| Who you are | An **IAM** principal, mapped to a Kubernetes user/group | The **CN and O of an x509 certificate** |
| `kubectl auth can-i` | Answers for your mapped identity | Answers for your certificate identity |
| Terraform's role | Terraform writes objects through the **same API** — `kubernetes_manifest` is just `apply` | You use `kubectl apply` directly |
| The 4 default namespaces | Identical | Identical |

**The pattern:** the object model is the same everywhere. What EKS removes is
**control of the API server process**. Every exam task phrased "configure the API
server" is a task that does not exist in your day job — which is exactly why it
is the part you have to study rather than recall.

---

## 8. Timed Drills

> ⚪ **NOT AN EXAM SECTION** — Empty until Block 2 (CKA).

<!-- EMPTY UNTIL BLOCK 2 (CKA). -->

---

## 9. Objectives Covered

> ⚪ **NOT AN EXAM SECTION** — Tracker. Tick as you go.

- [ ] Objects: Pod, ReplicaSet, Deployment, Service, Namespace
- [ ] Object structure: apiVersion, kind, metadata, spec, status
- [ ] `name` vs `uid`; why `ownerReferences` use uid
- [ ] API groups, the `/api` vs `/apis` split, kind vs resource
- [ ] Versioning: alpha / beta / stable and what each guarantees
- [ ] Labels, selectors (equality and set-based), annotations
- [ ] `watch` and `resourceVersion`; optimistic concurrency
- [ ] `apply` vs `create` vs `replace` vs `patch`
- [ ] Namespaces; namespaced vs cluster-scoped; namespaces are not a network boundary
- [ ] `ownerReferences`, garbage collection, the three cascade policies
- [ ] Finalizers and terminating objects
- [ ] CRDs, custom resources, operators; CRD vs aggregated API server
- [ ] kubectl: get / describe / logs / exec / apply / delete / explain / api-resources
- [ ] ResourceQuota and LimitRange ← **covered in note 07**

---

## KCNA — Traps & Distractors

> 🟢 **KCNA · READ CLOSELY** — core exam material.

<!-- TEMPORARY. Delete after the exam; migrate survivors into §6. -->

| Distractor | Why it is wrong |
|---|---|
| "You can select objects by annotation" | Annotations are **not** selectable. Only labels. |
| "`v1beta1` means nearly stable, so it is safe" | Beta schemas can still change **incompatibly**. The label is a compatibility promise, not a quality score. |
| "Alpha APIs are on by default" | **Off** by default; must be enabled explicitly. |
| "Namespaces provide network isolation" | They do **not**. Only a NetworkPolicy does. |
| "Every resource lives in a namespace" | Node, PV, StorageClass, ClusterRole, CRD and Namespace itself are cluster-scoped. |
| "`apiVersion: v1` means Kubernetes version 1" | It means version `v1` of the **core API group**. Nothing to do with the release. |
| "A CRD adds behaviour to the cluster" | A CRD adds a **schema**. Behaviour needs a controller. |
| "`ownerReferences` point at the owner's name" | They point at the owner's **`uid`**, so a recreated parent cannot adopt old children. |
| "Deleting a Deployment always deletes its Pods" | Not with `--cascade=orphan`. |
| "Foreground is the default cascade policy" | **Background** is the default. |
| "A namespace stuck Terminating is an API server bug" | A **finalizer** whose controller is gone. |
| "You write `status` to fix a stuck object" | You never write `status`. It is a separate subresource owned by controllers. |
| "`kubectl create -f` and `kubectl apply -f` are the same" | `create` fails if the object exists; `apply` merges and remembers. |
| "Object names can be any string" | Lowercase DNS subdomain, ≤ 253 chars. No uppercase, no underscores. |
| "RBAC rules name kinds, e.g. `Pod`" | RBAC names **resources**: `pods`, lowercase plural. |
| "A Service selector can use `In` / `NotIn`" | Service selectors are a **flat equality map** only. |
| "Controllers poll the API server on a timer" | They hold a **watch**; the API server pushes changes. |

**X ≠ Y**

- **Label ≠ annotation** — selectable vs merely attached.
- **`spec` ≠ `status`** — your intent vs observed reality. You never write status.
- **`name` ≠ `uid`** — unique per namespace per kind vs unique cluster-wide forever.
- **kind ≠ resource** — `Deployment` in YAML vs `deployments` in URLs and RBAC.
- **Core group ≠ named group** — `/api/v1` vs `/apis/apps/v1`.
- **API group ≠ API version** — `apps` vs `v1` in `apps/v1`.
- **Namespaced ≠ cluster-scoped** — PVC vs PV, Role vs ClusterRole.
- **Namespace ≠ security boundary** — naming and RBAC boundary, not a network one.
- **CRD ≠ custom resource ≠ operator** — schema vs instance vs schema+controller.
- **CRD ≠ aggregated API server** — declarative in etcd vs your own API process.
- **`generation` ≠ `resourceVersion`** — spec edits vs every write, status included.
- **Finalizer ≠ ownerReference** — blocks deletion vs causes deletion.
- **Background ≠ foreground ≠ orphan** — the three cascade policies.
- **`apply` ≠ `create`** — declarative merge vs imperative one-shot.

---

## 10. Active Recall

> 🟡 **KCNA · PARTIAL** — **KCNA scope: questions 1–4, 6, 7, 9–14, 20–25, 34, 35, 37–39.** The rest are CKA/CKAD.

Closed book, out loud. Any hesitation becomes a row in `mistakes.md`.

1. Name the four required fields of every object.
2. `spec` vs `status` — who writes each, and why is status a separate subresource?
3. `kubectl get deploy` shows `2/3`. Which field is 2 and which is 3?
4. `name` vs `uid` — scope of uniqueness for each.
5. Why do `ownerReferences` point at uid rather than name?
6. In `apiVersion: apps/v1`, what is `apps` and what is `v1`?
7. Why does `apiVersion: v1` have no group name? Which URL prefix does it use?
8. kind vs resource — which one does RBAC name?
9. What does alpha guarantee? Beta? Is alpha on by default?
10. Max length of a label value? Of an object name?
11. Give the same intent as an equality-based and a set-based selector.
12. What does `-l '!tier'` select?
13. Can a Service selector use `In`? Why or why not?
14. Label vs annotation in one line.
15. What is a field selector, and give two examples.
16. What is `resourceVersion` for? Name its two uses.
17. Why does no controller poll etcd?
18. What produces `Error from server (Conflict)`, and is it a bug?
19. How does `apply` know you deleted a field? Name both mechanisms.
20. Name the four initial namespaces and what each holds.
21. Name six cluster-scoped resources.
22. PVC or PV — which is namespaced, and what is the underlying logic?
23. Do namespaces isolate network traffic? What does?
24. FQDN of Service `api` in namespace `prod`?
25. A Service has no endpoints. What is wrong and how do you confirm it?
26. What is in `ownerReferences`, and which controller acts on it?
27. Name the three cascade policies and which is the default.
28. What does `--cascade=orphan` do, and when is it useful?
29. Can an object in namespace A own an object in namespace B?
30. What is a finalizer? Walk the five steps of a blocked deletion.
31. Why does a namespace hang in `Terminating` forever?
32. Which metadata field tells you an object is terminating?
33. `generation` vs `observedGeneration` — what does a mismatch tell you?
34. What is a CRD, and what does it *not* give you?
35. Define an operator in one sentence.
36. CRD vs aggregated API server — when do you need the second?
37. Custom resource vs ConfigMap — which for what?
38. Which command gives you a field path with no internet access?
39. `create` vs `apply` vs `replace` vs `patch` — one line each.
40. A Deployment applies cleanly but no Pods appear. Name three possible causes.

---

## 11. Scenario Drills

> 🟡 **KCNA · PARTIAL** — **KCNA scope: Scenarios 1 and 4.** The others depend on §1.10 and §1.11.

Integrated problems. Reason through the whole chain out loud before checking
yourself. Naming the right object is half an answer; the exam rewards the order.

---

**Scenario 1 — The Service that serves nothing**

You deploy `web` (3 Pods, all `Running`, all `Ready`) and a Service `web` on port
80. `curl web.default.svc.cluster.local` times out. `kubectl get svc web` shows a
ClusterIP. `kubectl get endpointslice` returns an object with an empty
`endpoints` list.

- a) Which controller was supposed to populate that EndpointSlice, and what does
  it match on?
- b) Give two distinct root causes that produce exactly this symptom.
- c) Which single command proves which of the two it is?
- d) Why did neither `kubectl apply` nor `kubectl get pods` warn you?
- e) The Service selector is `{app: web, tier: frontend}` and the Pods carry
  `{app: web}`. Does the Service match? Explain the matching rule.
- f) Could you have written this selector as `tier in (frontend, backend)`?

---

**Scenario 2 — The namespace that will not die**

`kubectl delete ns staging` returned success 40 minutes ago.
`kubectl get ns staging` still shows `Terminating`.

- a) What did the API server actually do when you issued the delete?
- b) Which metadata field would confirm that, and what value does it hold?
- c) Explain, in five steps, why the object is still there.
- d) Give a command that lists what is still alive inside the namespace.
- e) You find a PVC with `kubernetes.io/pvc-protection`. What is that finalizer
  waiting for?
- f) You could strip the finalizer by hand. What are you risking, and what should
  you check first?

---

**Scenario 3 — Orphaned and confused**

A colleague ran `kubectl delete deploy web --cascade=orphan` last week. Today you
run `kubectl apply -f web-deployment.yaml` with `replicas: 3`. You now have
**six** Pods matching `app=web`, and `kubectl get deploy web` reports `3/3`.

- a) Why are there six Pods rather than three?
- b) Why does the Deployment report `3/3` and not `6/3`? Be precise about what
  the ReplicaSet counts.
- c) What is in `metadata.ownerReferences` of the three old Pods?
- d) Why did the new ReplicaSet not adopt them? Name the exact field that prevents it.
- e) How do you clean up the three orphans without touching the new ones?
- f) What would have happened differently with the default cascade policy?

---

**Scenario 4 — Nothing happens**

You install a vendor's CRD bundle. `kubectl api-resources | grep backup` shows
`backups.example.com`. You create a `Backup` object; `kubectl get backups` lists
it. No backup is ever taken, and `status` stays empty.

- a) Explain in one sentence why this is working exactly as designed.
- b) Which of the four layers (CRD / CR / controller / operator) is missing?
- c) Which command would confirm the missing piece is absent?
- d) The vendor says "the CRD includes validation, so it must be working". Why is
  that a category error?
- e) `status` is empty. Given §1.1, who was supposed to fill it, and through which
  endpoint?
- f) If the vendor had shipped an aggregated API server instead, what would be
  different about where the `Backup` objects are stored?

---

**Scenario 5 — The silent edit**

You run `kubectl edit deploy web` and change the image. You save. `kubectl get
deploy web` shows `3/3 READY` and the **old** image is still serving traffic
twenty minutes later.

- a) Compare `metadata.generation` and `status.observedGeneration`. What would
  each look like, and what does the comparison prove?
- b) Given note 01, which component is broken? How do you know it is not the
  scheduler and not the API server?
- c) Did your edit reach etcd? Justify your answer from what you can observe.
- d) Why does `kubectl get` still say `3/3` rather than warning you?
- e) Which controller was supposed to act, and what object should it have created?

---

**Scenario 6 — Trace the object**

You run `kubectl apply -f web-deployment.yaml` on a healthy cluster.

Trace from your keystroke to a running container. For each step name: the
component, whether it **reads** or **writes**, which object kind it touches,
and whether it talks to etcd directly. Include the three gates inside the API
server and both controllers in the ownership chain. There are at least nine steps.

Then answer: which `metadata` field links each created object to the one above
it, and which controller would delete the whole tree if you removed the top?
