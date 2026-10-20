---
domain: D1 — Cluster Architecture, Installation & Configuration
group: 3 — Access & Extend the API
bullets: [1.1, 1.6, 1.8]
exams: [CKA]
index: cka-D1.md
theory: notes_07, notes_10, notes_02
status: 1.1 drilled (A1 ✗ 7:00 · sim 11/11 in 8:00) · 1.6, 1.8 draft
revision: 2026-09-28 (r2 — 1.1 migrated to Template C from the 27–28 Sep session; editing decision table; §9 RBAC tasks with graders) · prev r1 2026-09-14
---

# D1 · Group 3 — Access & Extend the API (bullets 1.1, 1.6, 1.8)

> Index, boot block, execution locations and scoreboard: **`cka-D1.md`**.
> Legend, typing conventions and lab-vs-exam node moves: **`cka-D1-2-lifecycle.md`** (reference implementation).
>
> What unites these three: they run **on top of** a working cluster. All of them
> run on **cp1** and none of them can damage a node.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.1 RBAC · 1.6 Helm + Kustomize · 1.8 CRDs

---

## 1.1 Manage role-based access control (RBAC) ⚙️

**Runs on: cp1.** · **Theory →** notes_07 §1.5–1.9 · **Docs →** search `rbac` → *Using RBAC Authorization* · **Target: 4:00** (`cka-D1.md §7`)

### The shape

*Someone (subject) may do something (verb) to something (resource) somewhere (namespace or cluster). Four objects answer those four questions; `auth can-i` proves the answer.*

| # | What we do | Why | Exam? |
|---|---|---|---|
| 1 | ServiceAccount | The identity. There is no `User` object — users come from certificates | 🎯 |
| 2 | Role / ClusterRole | The *what*: rules of three lists — apiGroups · resources · verbs | 🎯 |
| 3 | RoleBinding / ClusterRoleBinding | The *to whom* and the *where*. `roleRef` is immutable | 🎯 |
| 4 | `auth can-i --as` | The only valid proof: one `yes` and one `no` | 🔍 |
| 5 | ClusterRole + RoleBinding | Permissions written once, granted in one namespace — the exam's favourite pattern | 🎯 |
| 6 | Workload with the SA | `serviceAccountName` — no flag on `kubectl run` | 🎯 |
| 7 | `create pods` ≈ read every Secret | Privilege escalation through an innocent verb | 📚 |

**Where permissions apply — the table behind steps 3 and 5:**

|  | RoleBinding in `ns-x` | ClusterRoleBinding |
|---|---|---|
| **Role** (in `ns-x`) | valid in `ns-x` only | ❌ does not exist |
| **ClusterRole** | valid in `ns-x` only (reuse pattern) | valid in every namespace **+ cluster-scoped resources** |

### The whiteboard

**How the authorizer decides (the model every trap below comes from).** For each
request it takes the identity — **username + all its groups** — and collects every
binding that names the username **or any of the groups**: all ClusterRoleBindings,
plus the RoleBindings **of the request's namespace only**. It unions their rules.
Any rule matches → `yes`. There is no deny.

- A request **without a namespace** (`get nodes`, `list pv`) only ever sees ClusterRoleBindings.
- References are resolved **at request time**, never at creation: a binding to a role that does not exist is accepted and grants nothing.

**Step 1 — ServiceAccount = a username with a fixed format**

```bash
# ▶▶ cp1 🎯
k create ns rbac-lab
k -n rbac-lab create sa deploy-bot
```

RBAC sees it as `system:serviceaccount:<ns>:<name>`, member of the groups
`system:serviceaccounts`, `system:serviceaccounts:<ns>` and `system:authenticated`.

```bash
# ▶▶ cp1 📚
k auth whoami --as=system:serviceaccount:rbac-lab:deploy-bot   # Username + Groups exactly as RBAC evaluates them
k auth whoami --as=deploy-bot                                  # a USER named deploy-bot — a different identity
```

Since v1.24 the SA has no Secret: the token is injected into the Pod as a
projected volume at `/var/run/secrets/kubernetes.io/serviceaccount/`.

**Step 2 — Role: three lists that must all match**

| List | Literal that fails |
|---|---|
| `apiGroups` | core group = **`[""]`** (a list holding the empty string). `[]` is **rejected** by validation. Deployments/StatefulSets/DaemonSets = `apps` — kubectl fills it in for you |
| `resources` | **plural, lowercase**: `pods`. Subresources are separate: `pods/log`, `pods/exec` |
| `verbs` | `get` ≠ `list` — `k get pods` with no name needs `list` |

```bash
# ▶▶ cp1 🎯 — one rule, same verbs for every resource
k -n rbac-lab create role pod-reader --verb=get,list,watch --resource=pods

# 🎯 — different verbs per resource: NOT imperative. Generate both rules, never type YAML keys
k -n rbac-lab create role pod-reader --verb=get,list,watch --resource=pods $do > r.yaml
k -n rbac-lab create role x --verb=get --resource=pods/log $do | tail -6 >> r.yaml   # last 6 lines = one rule block
k apply -f r.yaml                                                                    # $do creates NOTHING until this line
```

More usage examples:

```bash
k -n X create role cm-rw --verb=get,list,create,update,delete --resource=configmaps
k -n X create role deploy-mgr --verb=create,update --resource=deployments,statefulsets   # apiGroups: [apps] auto
k -n X create role one-secret --verb=get --resource=secrets --resource-name=db-creds      # only that object
```

```bash
# ▶▶ cp1 🔍
k -n rbac-lab describe role pod-reader        # one row per resource: pods [get list watch] · pods/log [get]
```

**Step 3 — RoleBinding: NAME, then role, then subject flag**

```bash
# ▶▶ cp1 🎯
k -n rbac-lab create rolebinding pod-reader-bot --role=pod-reader --serviceaccount=rbac-lab:deploy-bot
#                                ^ NAME of the binding  ^ what      ^ who, always <ns>:<name>
```

| Flag | Use |
|---|---|
| `--role=` / `--clusterrole=` | exactly one — sets `roleRef.kind` |
| `--serviceaccount=ns:sa` | colon, namespace mandatory — even inside a ClusterRoleBinding |
| `--user=` / `--group=` | other subject kinds; every subject flag is repeatable |

Usage examples:

```bash
k -n X create rolebinding devs-view --clusterrole=view --group=dev-team          # a Group from certificates (O=)
k -n X create rolebinding all-sa-cm --clusterrole=cm-editor --group=system:serviceaccounts:X   # every SA of X, incl. future ones
k -n X create rolebinding jane-edit --clusterrole=edit --user=jane --user=bob     # two users, one binding
```

Subject shape when writing YAML by hand: `kind: ServiceAccount` carries
**`namespace`**; `kind: User` / `Group` carry **`apiGroup: rbac.authorization.k8s.io`**.

**Step 4 — Prove it: one yes, one no, and read the reason**

```bash
# ▶▶ cp1 🔍
SA=system:serviceaccount:rbac-lab:deploy-bot
k auth can-i list pods -n rbac-lab --as=$SA                    # yes
k auth can-i get pods --subresource=log -n rbac-lab --as=$SA   # yes
k auth can-i delete pods -n rbac-lab --as=$SA                  # no
k auth can-i list pods -n default --as=$SA                     # no — binding lives in rbac-lab
k auth can-i --list -n rbac-lab --as=$SA                       # 📚 union of every binding that applies
```

`no - RBAC: … "x" not found` → a binding **was** evaluated and its `roleRef` is broken
(typo, or the role was never applied). A bare `no` → **no** binding matched this
identity in that scope (wrong subject, zero subjects, wrong namespace, cluster-scoped resource).

Who grants an unexpected `yes`? Look at bindings to the identity's **groups**:

```bash
# ▶▶ cp1 🔍
k get clusterrolebinding -o wide | grep -E 'system:authenticated|system:serviceaccounts'
k -n X get rolebinding -o wide                                  # USERS · GROUPS · SERVICEACCOUNTS columns
```

**Step 5 — ClusterRole + the right binding**

```bash
# ▶▶ cp1 🎯 — reuse in one namespace
k create clusterrole cm-editor --verb=get,list,create,update --resource=configmaps      # no -n
k -n rbac-lab create rolebinding cm-editor-all-sa --clusterrole=cm-editor --group=system:serviceaccounts:rbac-lab

# 🎯 — cluster-scoped resource: ONLY a ClusterRoleBinding reaches it
k create clusterrole node-reader --verb=get,list --resource=nodes
k create clusterrolebinding node-crb --clusterrole=node-reader --serviceaccount=rbac-lab:deploy-bot
k auth can-i get nodes --as=$SA        # yes ("not namespace scoped" warning is harmless)
```

Scope of a resource: `k api-resources | grep -i <name>` → `NAMESPACED` column.
Least privilege: PVCs in one namespace + PVs cluster-wide = **two** role objects and
**two** bindings; one ClusterRole in a ClusterRoleBinding would also grant PVCs everywhere.

**Step 6 — A workload that runs as the SA**

```bash
# ▶▶ cp1 🎯 — Pod: no flag exists → $do + one line
k -n rbac-lab run bot-pod --image=nginx $do > pod.yaml
#   add under spec:, same level as containers:   serviceAccountName: deploy-bot
k apply -f pod.yaml

# 🎯 — Deployment: imperative setter
k -n rbac-lab create deploy bot --image=nginx
k -n rbac-lab set serviceaccount deploy bot deploy-bot          # type · object · SA   (alias: set sa)
k -n rbac-lab rollout status deploy bot
```

```bash
# ▶▶ cp1 🔍
k -n rbac-lab get pod bot-pod -o jsonpath='{.spec.serviceAccountName}{"\n"}'
k -n rbac-lab get deploy bot -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
k -n rbac-lab exec bot-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount     # 📚 ca.crt namespace token
```

A running Pod's SA **cannot** be changed (`edit` → Forbidden). Recreate it — see the editing table.
`spec.serviceAccount` is a deprecated alias the API fills in; set both or delete it.

**Step 7 — `create pods` ≈ read every Secret in the namespace** 📚

```bash
# ▶▶ cp1 📚
k -n rbac-lab create secret generic db --from-literal=pw=hunter2
k -n rbac-lab create role pod-maker --verb=create --resource=pods
k -n rbac-lab create rolebinding pod-maker --role=pod-maker --serviceaccount=rbac-lab:deploy-bot
k auth can-i get secrets -n rbac-lab --as=$SA          # no
k create -f leak.yaml --as=$SA                         # Pod that mounts secret "db" and cats it
k -n rbac-lab logs leak --as=$SA                       # hunter2
```

Nobody checks whether a Pod's creator may read the Secrets it mounts. The same holds
for anything that creates Pods for you (create deployments/jobs/…, patch a workload's
template) and for `pods/exec` into a Pod that already mounts one. The **namespace**
is the boundary; Pod Security Admission does **not** help (even `restricted` allows
`secret` volumes); the native policy answer is ValidatingAdmissionPolicy (CKS).

### Editing RBAC objects — decision table

*First question: is the field mutable? Rules and subjects are; `roleRef` is not.*

| You need to change | Mutable? | Fastest path |
|---|---|---|
| A Role's verbs/resources | ✅ | Regenerate and apply — the whole `rules` list is replaced, so include everything: `k -n X create role R --verb=… --resource=… $do \| k apply -f -` |
| Add a rule with **different** verbs | ✅ | `k -n X get role R -o yaml > r.yaml` → append with the `tail -6` trick → `k apply -f r.yaml` |
| **Add** a subject to a binding | ✅ | `k -n X set subject rolebinding RB --serviceaccount=X:new-sa` (also `--user=` `--group=`) |
| Remove or replace subjects | ✅ | `k -n X edit rolebinding RB`, or regenerate with the full subject list `$do \| k apply -f -` |
| The binding's **role** (other role, or a typo in its name) | ❌ | Read the current subjects first: `k -n X get rolebinding RB -o wide`. Then one line, repeating **all** of them: `k -n X create rolebinding RB --clusterrole=NEW --serviceaccount=X:S $do \| k replace --force -f -` |
| You already ran `edit` and it failed | — | Your changes are saved: `head -8 /tmp/kubectl-edit-*.yaml` (the reason), then `k replace --force -f /tmp/kubectl-edit-<n>.yaml` |
| A running Pod's `serviceAccountName` | ❌ | Same `/tmp` recipe, or `k get pod P -o yaml > p.yaml`, edit, `k replace --force -f p.yaml` |

`replace --force` = delete + create in one command. `apply` on an object made with
`create` prints a `last-applied-configuration` warning — harmless, ignore it.

### Command card — 1.1

```bash
k create ns X; k -n X create sa S
k -n X create role R --verb=get,list,watch --resource=pods                      # same verbs for all resources
k -n X create role R … $do > r.yaml; k create role x --verb=get --resource=pods/log $do | tail -6 >> r.yaml; k apply -f r.yaml
k -n X create rolebinding RB --role=R --serviceaccount=X:S                     # NAME first · --clusterrole= · --group= · --user=
k create clusterrole CR --verb=… --resource=…; k create clusterrolebinding CRB --clusterrole=CR --serviceaccount=X:S   # nodes, pv
k auth can-i <verb> <res> -n X --as=system:serviceaccount:X:S                  # 1 yes + 1 no · read the reason after "no -"
k -n X create rolebinding RB --clusterrole=NEW --serviceaccount=X:S $do | k replace --force -f -    # roleRef is immutable
k -n X set subject rolebinding RB --serviceaccount=X:S2                        # add a subject
k -n X set sa deploy D S · Pod: $do + serviceAccountName · edit fails → k replace --force -f /tmp/kubectl-edit-*.yaml
```

### Traps

| Error | Cause |
|---|---|
| `can-i … --as=deploy-bot` says `no` although the binding is right | A bare name impersonates a **User**. SA = `system:serviceaccount:<ns>:<name>` |
| `create rolebinding --role=R serviceaccount:ns:sa` → `created`, grants nothing | The positional argument is the binding's **NAME**; no `--serviceaccount=` flag → **zero subjects** |
| Role/ClusterRole "does not exist" right after writing it | `$do > file` creates nothing — `apply` was never run |
| `rules[0].apiGroups: Required value` | `apiGroups: []`. The core group is `[""]` |
| `unknown field "…apigroups"` / `"-verbs"` / `pods/logs` grants nothing | Hand-typed keys: `apiGroups`, `verbs:` (no dash), `pods/log` singular. Generate rules instead of typing them |
| `unknown flag: --verbs` / `--resources` | Both flags are **singular**: `--verb=`, `--resource=` |
| `exactly one NAME is required, got 2` | Space after `=` or `,` (`--clusterrole= view`, `cm, deploy`) splits the argument |
| `roleRef: … cannot change roleRef` | `roleRef` is immutable — `replace --force` or delete + create |
| `no - RBAC: role "x" not found` | The binding points at a role that does not exist (typo or never applied). Creation never checks references |
| RoleBinding + ClusterRole for `nodes` → `no` | A request without a namespace only sees ClusterRoleBindings |
| Identity has permissions nobody gave it | A binding to one of its **groups** (`system:authenticated` → e.g. `calico-tiered-policy-passthrough` in this lab) |
| `get roles` does not show the ClusterRole | ClusterRoles are cluster-scoped: `k get clusterrole <name>` |
| `edit pod` → Forbidden when changing the SA | Pod spec is immutable except a few fields — recreate from the `/tmp` copy |
| `can-i` without `--as` always `yes` | It answers for **you**, the admin |
| Subject `kind: serviceaccount` rejected | Kinds are case-sensitive: `User` · `Group` · `ServiceAccount` |
| "only get on pods/log" but `list` granted too | One imperative line shares verbs across all its resources — needs a second rule |

⚠️ **EKS**

| | EKS | kubeadm (exam) |
|---|---|---|
| Where User/Group names come from | IAM principal → **access entry** (or `mapRoles` in `aws-auth`, legacy) maps to a username + groups | Client certificate: CN = user, O = groups |
| Permissions with no RBAC object | **Access policies** (e.g. `AmazonEKSClusterAdminPolicy`) are evaluated by the EKS authorizer — no binding shows them; their scope is `namespace` or `cluster`, mirroring RB vs CRB | Every `yes` has a visible binding: `k get rolebinding,clusterrolebinding -A -o wide` |
| What a ServiceAccount is for | **IRSA** (`eks.amazonaws.com/role-arn` annotation; a webhook injects a 2nd token at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token` + `AWS_ROLE_ARN`) or **Pod Identity** (association + agent) → AWS credentials | The token authenticates **only to the Kubernetes API** |
| KMS Secrets encryption | Protects Secrets **at rest in etcd** — it is not access control; step 7 works the same | — |

---

## 1.6 Use Helm and Kustomize to install cluster components ⚙️

> r1 text — migrated to Template C the day it is worked (next block of this session).

**Runs on: cp1.**
**Theory →** notes_10 §1.5–1.7 · **Docs →** `helm.sh/docs` (allowed in the exam)
and search `kustomize` · **Target: 6 min**

### The shape

Both turn source material into manifests, and they disagree on how:

| | **Helm** | **Kustomize** |
|---|---|---|
| Method | **templating** — fills placeholders with values | **overlay** — patches a complete base |
| Input | a chart + `values.yaml` / `--set` | `kustomization.yaml` + patches |
| Object names | Helm **builds** them: `<release>-<chart>` | Kustomize **keeps** them, adds a prefix |
| State | tracks releases (`helm list`) | stateless — it only renders |
| `kubectl` flag | — (its own binary) | **`-k`** |

```bash
# ▶▶ cp1 — Helm
helm repo add <name> <url> && helm repo update
helm search repo <chart> --versions
helm install <rel> <repo>/<chart> -n <ns> --create-namespace --set key=value
helm list -A
helm upgrade <rel> <repo>/<chart> --version x.y.z
helm template <rel> <repo>/<chart>        # render without installing — read before you apply
helm uninstall <rel> -n <ns>

# ▶▶ cp1 — Kustomize
kubectl kustomize ./overlays/prod          # render
kubectl apply -k ./overlays/prod           # apply — -k, not -f
```

**Verify:** `helm list -n <ns>` shows `deployed` · `kubectl get all -n <ns>` ·
for Kustomize, `kubectl kustomize` output matches what you expect **before** you
apply.

**Traps:**

1. **`-f` is a file, `-k` is a kustomization directory.** One character, whole task.
2. In `kustomization.yaml`, `name` under `replicas:` means the **object**; under `images:` it means the **image**. Same key, different referent.
3. `helm template` is the safe way to inspect a chart — no cluster changes. Use it before `install` when the task says "review".
4. Helm must be installed **on cp1**, not on the host.
5. `--create-namespace` or the install fails on a missing namespace.

⚠️ **EKS:** identical — Helm and Kustomize do not care what runs the control
plane. This is the one bullet in D1 where your day job transfers directly.

---

## 1.8 Understand CRDs, install and configure operators ✍️ — you write this

> r1 text — migrated to Template C the day it is worked (next block of this session).

**Runs on: cp1.**
**Theory →** notes_02 §1.9–1.11 · **Docs →** search `custom resources` ·
**Target: 5 min**

### The shape

A **CRD** teaches the API server a new kind. A **CR** is an instance of that
kind. An **operator** is a controller that watches those CRs and makes reality
match them. The CRD alone does nothing — it only creates the vocabulary.

### Your task during the lab — start with the operator you already have

You do not need to install a demo operator. **`tigera-operator` and the
`Installation` CR are a real operator, running in your cluster, that you
installed yourself on 31 Aug** (see `cka-D1-1-install.md` 1.3).

Build the runbook from it. Find your own commands; the search terms are
`custom resources` and `kubectl api-resources --help`. It must end up answering:

1. How do you **list** the CRDs in a cluster, and filter for one operator's?
2. How do you discover the **fields** of a custom kind you have never seen?
   (Hint: the same command that works for built-in kinds.)
3. How do you tell, from `kubectl api-resources`, whether a kind is
   **namespaced** or cluster-scoped, and what its short name is?
4. Where is the operator's own **Deployment**, and what happens to the objects it
   manages if you scale it to zero?
5. What is the difference between deleting a **CR** and deleting its **CRD**?

```
(your runbook here)
```

### Traps

1. **Deleting a CRD deletes every CR of that kind**, cluster-wide, without a second prompt. The most destructive single command in this bullet.
2. `kubectl explain` works on custom kinds **only if the CRD publishes a schema** — most do.
3. The operator **reconciles**: delete something it owns and it comes back. To actually stop it, scale the operator's Deployment to 0. (This is why "break Calico" in D5 is not `kubectl delete ds calico-node`.)
4. CRs are namespaced or cluster-scoped depending on the CRD's `scope:` — `api-resources` is how you check, not guesswork.

⚠️ **EKS:** you meet CRDs constantly at work (Karpenter's `NodePool`,
`EC2NodeClass`, the AWS Load Balancer Controller's `TargetGroupBinding`) — but
always as a **consumer** of someone else's operator. What the CKA asks is the
mechanics underneath: list, explain, scope, delete semantics.

---

## §9. Exam mode — access tasks (feed `cka-D1-1-install.md §9` Set 2)

Wording as the CKA phrases it. Setup blocks are untimed and encoded so you cannot
read them; graders run **after** the clock stops. A FAIL is pasted, not fixed first.

```
Task A  (weight 5%)                                           target 5 min
Context: k8s-lab

Create a new ClusterRole named deployment-clusterrole, which only allows to
create the following resource types:
  - Deployment
  - StatefulSet
  - DaemonSet

Create a new ServiceAccount named cicd-token in the existing namespace
app-team1.

Bind the new ClusterRole deployment-clusterrole to the new ServiceAccount
cicd-token, limited to the namespace app-team1, using the existing
RoleBinding cicd-binding in that namespace.
```

🧪 Setup (reset first: `k delete ns app-team1; k delete clusterrole deployment-clusterrole`):

```bash
echo 'a3ViZWN0bCBjcmVhdGUgbnMgYXBwLXRlYW0xID4vZGV2L251bGwgMj4mMQprdWJlY3RsIC1uIGFwcC10ZWFtMSBjcmVhdGUgZGVwbG95IGxlZ2FjeSAtLWltYWdlPW5naW54ID4vZGV2L251bGwgMj4mMQprdWJlY3RsIC1uIGFwcC10ZWFtMSBjcmVhdGUgcm9sZWJpbmRpbmcgY2ljZC1iaW5kaW5nIC0tY2x1c3RlcnJvbGU9dmlldyAtLXNlcnZpY2VhY2NvdW50PWFwcC10ZWFtMTpjaWNkLXRva2VuID4vZGV2L251bGwgMj4mMQplY2hvICJzZXR1cCBkb25lIgo=' | base64 -d | bash
```

🔍 Grader:

```bash
echo 'Uz1zeXN0ZW06c2VydmljZWFjY291bnQ6YXBwLXRlYW0xOmNpY2QtdG9rZW4Kb2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CmNpKCl7IGt1YmVjdGwgYXV0aCBjYW4taSAiJEAiIC0tYXM9JFMgMj4vZGV2L251bGwgfCBhd2sgJ3twcmludCAkMX0nOyB9Cm9rICIkKGt1YmVjdGwgZ2V0IGNsdXN0ZXJyb2xlIGRlcGxveW1lbnQtY2x1c3RlcnJvbGUgLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJjbHVzdGVycm9sZS5yYmFjLmF1dGhvcml6YXRpb24uazhzLmlvL2RlcGxveW1lbnQtY2x1c3RlcnJvbGUiICJDbHVzdGVyUm9sZSBkZXBsb3ltZW50LWNsdXN0ZXJyb2xlIGV4aXN0cyIKb2sgIiQoa3ViZWN0bCAtbiBhcHAtdGVhbTEgZ2V0IHNhIGNpY2QtdG9rZW4gLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJzZXJ2aWNlYWNjb3VudC9jaWNkLXRva2VuIiAiU2VydmljZUFjY291bnQgY2ljZC10b2tlbiBleGlzdHMgaW4gYXBwLXRlYW0xIgpmb3IgciBpbiBkZXBsb3ltZW50cyBzdGF0ZWZ1bHNldHMgZGFlbW9uc2V0czsgZG8gb2sgIiQoY2kgY3JlYXRlICRyIC1uIGFwcC10ZWFtMSkiICJ5ZXMiICJjYW4gY3JlYXRlICRyIGluIGFwcC10ZWFtMSI7IGRvbmUKb2sgIiQoY2kgY3JlYXRlIGRlcGxveW1lbnRzIC1uIGRlZmF1bHQpIiAibm8iICJjYW5ub3QgY3JlYXRlIGRlcGxveW1lbnRzIG91dHNpZGUgYXBwLXRlYW0xIgpvayAiJChjaSBkZWxldGUgZGVwbG95bWVudHMgLW4gYXBwLXRlYW0xKSIgIm5vIiAiY3JlYXRlIG9ubHkgLSBubyBkZWxldGUiCm9rICIkKGNpIGNyZWF0ZSBwb2RzIC1uIGFwcC10ZWFtMSkiICJubyIgIm5vIHBvZHMiCm9rICIkKGNpIGxpc3QgcG9kcyAtbiBhcHAtdGVhbTEpIiAibm8iICJvbGQgdmlldyBwZXJtaXNzaW9ucyBnb25lIgpvayAiJChrdWJlY3RsIC1uIGFwcC10ZWFtMSBnZXQgcm9sZWJpbmRpbmcgY2ljZC1iaW5kaW5nIC1vIGpzb25wYXRoPSd7LnJvbGVSZWYua2luZH0vey5yb2xlUmVmLm5hbWV9JyAyPi9kZXYvbnVsbCkiICJDbHVzdGVyUm9sZS9kZXBsb3ltZW50LWNsdXN0ZXJyb2xlIiAiZXhpc3RpbmcgYmluZGluZyBjaWNkLWJpbmRpbmcgbm93IGdyYW50cyBkZXBsb3ltZW50LWNsdXN0ZXJyb2xlIgpvayAiJChrdWJlY3RsIGdldCBjbHVzdGVycm9sZWJpbmRpbmcgLW8gd2lkZSAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ2FwcC10ZWFtMS9jaWNkLXRva2VuJykiICIwIiAibm8gQ2x1c3RlclJvbGVCaW5kaW5nIGZvciBjaWNkLXRva2VuIgo=' | base64 -d | bash
```

```
Task B  (weight 4%)                                           target 4 min
Context: k8s-lab

Create a ServiceAccount named deploy-bot in namespace ops. Grant it permission
to list and watch Pods in that namespace only, and to read the logs of those
Pods. Demonstrate that the permission works and that it cannot delete Pods.
```

```
Task C  (weight 4%)                                           target 4 min
Context: k8s-lab

The ServiceAccount monitor in namespace observability must be able to list the
Nodes and PersistentVolumes of the cluster, and the PersistentVolumeClaims of
namespace observability only. Grant no other permission.
```

```
Task D  (weight 3%)                                           target 5 min
Context: k8s-lab

A custom resource definition is installed in this cluster. Identify every custom
kind belonging to the Calico operator, state whether each is namespaced, and
write the list to /opt/crds.txt.
```

### Variations — the same task as the exam rewords it

- "…allows **only** get on …" next to another resource with more verbs → two rules (`tail -6` trick).
- "The user **jane** …" → subject `--user=jane`; prove with `--as=jane`.
- "Every ServiceAccount in namespace X …" → `--group=system:serviceaccounts:X`.
- "Modify the existing binding so that …" → check: `roleRef` or `subjects`? Editing table.
- "…in all namespaces" → ClusterRole + **ClusterRoleBinding**.
- "Pod P must run as ServiceAccount S" with P already running → recreate from `/tmp` or `-o yaml`.

| Task | Date | Score | Time | Root cause code |
|---|---|---|---|---|
| A | 28 Sep | 11/11 | 8:00 ✗ | `LIT` flags `--verbs`/`--resources` (rows 116–117) |
| B (lab run 2 `audit`) | 28 Sep | 0 functional | 7:00 ✗ | `PREC` no apply · `CONF` binding NAME · `LIT` (rows 112–115) |
| C | | | | |
| D | | | | |
