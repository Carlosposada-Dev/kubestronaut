---
domain: D1 — Cluster Architecture, Installation & Configuration
group: 3 — Access & Extend the API
bullets: [1.1, 1.6, 1.8]
exams: [CKA]
index: cka-D1.md
theory: notes_07, notes_10, notes_02
status: 1.1 ✅ 8 Nov (cold 3:46 · 3:24) · 1.6 ◐ guided + H1 6:32 11/11, micro-drills 5/5 correct — H1 cold owed · 1.8 ✅ 8 Nov (recognise-only, Task D 0:41)
revision: 2026-11-08 (r4 — 4–8 Nov session: 1.1 guided pass + R1–R6 + two cold runs, two-rule method; 1.6 measured facts, card, drill H1, micro-drills M1–M5; 1.8 migrated to Template C from the lab; §9 Task D setup + grader) · 2026-11-02 (r3 — structure audit against D1-1/D1-2, no content migrated: pending list below the header; stale mistakes-row references and lab date fixed) · 2026-09-28 (r2 — 1.1 migrated to Template C from the 27–28 Sep session; editing decision table; §9 RBAC tasks with graders) · prev r1 2026-09-14
---

# D1 · Group 3 — Access & Extend the API (bullets 1.1, 1.6, 1.8)

> Index, boot block, execution locations and scoreboard: **`cka-D1.md`**.
> Legend, typing conventions and lab-vs-exam node moves: **`cka-D1-2-lifecycle.md`** (reference implementation).
>
> What unites these three: they run **on top of** a working cluster. All of them
> run on **cp1** and none of them can damage a node.
>
> **Structure audit, 2 Nov — still owed before this file matches D1-1 / D1-2**
> (Template C, done the day each bullet is worked, never in bulk):
> - **1.1** ✅ shape → whiteboard → card → traps → EKS.
> - **1.6** ◐ measured-facts table + card added (7–8 Nov); the r1 `The shape` block
>   with commands and the numbered traps are still there — fold them into a shape +
>   error · cause traps table when 1.6 closes.
> - **1.8** ✅ 8 Nov: whiteboard + card from the lab; traps kept numbered (recognise-only).
> - **§9** heading still does not follow `Set <n> · <k> tasks · <m> min`. Task D has
>   setup + grader (8 Nov); tasks B and C still have none (B is covered by the 1.1
>   blind runs; C owed for a D1 exam set).

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.1 RBAC · 1.6 Helm + Kustomize · 1.8 CRDs

---

## 1.1 Manage role-based access control (RBAC) ⚙️

**Runs on: cp1.** · **Theory →** notes_07 §1.5–1.9 · **Docs →** search `rbac` → *Using RBAC Authorization* · **Target: 4:00** (`cka-D1.md §7`)

### The shape

*Someone (subject) may do something (verb) to something (resource) somewhere (namespace or cluster). Four objects answer those four questions; `auth can-i` proves the answer.*

**ServiceAccount = who · Role = what · RoleBinding = to whom and where · `auth can-i` = the proof.**

```bash
k create ns X; k -n X create sa S
k -n X create role R --verb=get,list --resource=pods            # same verbs for all
k -n X create rolebinding RB --role=R --serviceaccount=X:S       # NAME first · X:S, not the username
k -n X get rolebinding -o wide                                   # ROLE + SERVICEACCOUNTS columns
k auth can-i list pods -n X --as=system:serviceaccount:X:S       # 1 yes + 1 no · --as = the full username
```

`--serviceaccount=X:S` builds a subject object (`kind: ServiceAccount`, `namespace: X`,
`name: S`); `--as=` impersonates a **username**, and an SA's username is
`system:serviceaccount:X:S`. Measured 5 Nov: `--serviceaccount=system:serviceaccount:X:S`
→ `error: serviceaccount must be <namespace>:<name>`; `--as=X:S` → bare `no` (a User).

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

**WHO is the subject; WHERE is the binding.** The namespace inside `--serviceaccount=ns:sa`
or `--group=system:serviceaccounts:ns` names the identity; `-n` names where the
RoleBinding lives = where the permission applies. They can differ (measured 4 Nov:
a RoleBinding in `probe-a` to `--group=system:serviceaccounts:probe-b` → SA of
`probe-b` gets `yes` in `probe-a`, `no` in its own namespace).

| Subject | in a RoleBinding (`-n X`) | in a ClusterRoleBinding |
|---|---|---|
| `--serviceaccount=Y:S` | S of Y, in X | S of Y, everywhere |
| `--group=system:serviceaccounts:Y` | every SA of Y, in X | every SA of Y, everywhere |
| `--group=system:serviceaccounts` | every SA of the cluster, in X | every SA, everywhere |
| `--user=U` / `--group=G` | certificate CN / O, in X | everywhere |

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

# 🎯 — different verbs per resource: NOT imperative. Generate EVERY rule, glue them, delete the 2nd header
k -n rbac-lab create role pod-reader --verb=get,list,watch --resource=pods $do > r.yaml
k -n rbac-lab create role pod-reader --verb=get --resource=pods/log $do >> r.yaml   # >> appends
vim r.yaml        # /^apiVersion ⏎ (jumps to the 2nd header) · 6dd · :wq
k apply -f r.yaml                                                                    # $do creates NOTHING until this line
```

| vim keys | What they do |
|---|---|
| `/^apiVersion` ⏎ | from line 1, jumps to the **second** `apiVersion:` = the header of rule 2 |
| `6dd` | deletes the 6 header lines: `apiVersion` · `kind` · `metadata:` · `name` · `namespace` · `rules:` (always 6, measured) |
| `:wq` | save — rule 2 now sits under rule 1's `rules:` |

Why this and not typing in vim: **no value is ever typed**. kubectl writes the
resource name and the API group — measured 5 Nov: `--resource=ConfigMaps` →
`configmaps`, `--resource=Deployments` → `deployments` + `apiGroups: apps`. Typing
`ConfigMaps` by hand in vim grants nothing (row 142). History: the `tail -6` pipe
(4 Nov) broke with two verbs; copying the rule in vim (4 Nov) carried `apps` into a
core-group rule and invited typed values. This method replaced both on 5 Nov (R2 ✅).

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
k -n rbac-lab logs leak --as=$SA                       # hunter2 (pods/log get comes from step 2)
```

`leak.yaml` (measured 4 Nov: `can-i get secrets` → `no`, logs → `hunter2`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: leak
  namespace: rbac-lab
spec:
  restartPolicy: Never
  containers:
  - name: c
    image: busybox:1.28
    command: ["cat", "/s/pw"]
    volumeMounts:
    - name: s
      mountPath: /s
  volumes:
  - name: s
    secret:
      secretName: db
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
| Add a rule with **different** verbs | ✅ | `k -n X get role R -o yaml > r.yaml` → `k -n X create role R --verb=… --resource=… $do >> r.yaml` → vim: `/^apiVersion` (2nd) · `6dd` · `:wq` → `k apply -f r.yaml` |
| **Add** a subject to a binding | ✅ | `k -n X set subject rolebinding RB --serviceaccount=X:new-sa` (also `--user=` `--group=`) |
| Remove or replace subjects | ✅ | `k -n X edit rolebinding RB`, or regenerate with the full subject list `$do \| k apply -f -` |
| The binding's **role** (other role, or a typo in its name) | ❌ | Read the current subjects first: `k -n X get rolebinding RB -o wide`. Then render it to a file, repeating **all** of them: `k -n X create rolebinding RB --clusterrole=NEW --serviceaccount=X:S $do > rb.yaml` → `k replace --force -f rb.yaml` (one-line form: `$do \| k replace --force -f -`). `create` has no `--force` |
| You already ran `edit` and it failed | — | Your changes are saved: `head -8 /tmp/kubectl-edit-*.yaml` (the reason), then `k replace --force -f /tmp/kubectl-edit-<n>.yaml` |
| A running Pod's `serviceAccountName` | ❌ | Same `/tmp` recipe, or `k get pod P -o yaml > p.yaml`, edit, `k replace --force -f p.yaml` |

`replace --force` = delete + create in one command. `apply` on an object made with
`create` prints a `last-applied-configuration` warning — harmless, ignore it.

### Command card — 1.1

```bash
k create ns X; k -n X create sa S
k -n X create role R --verb=get,list,watch --resource=pods                      # same verbs for all resources
k -n X create role R …rule1… $do > r.yaml; k -n X create role R …rule2… $do >> r.yaml; vim (/^apiVersion · 6dd); k apply -f r.yaml; k -n X describe role R   # different verbs per resource
k -n X create rolebinding RB --role=R --serviceaccount=X:S; k -n X get rolebinding -o wide   # NAME first · no Tab after --role= · ROLE without .yaml, SA column filled
k create clusterrole CR --verb=… --resource=…; k create clusterrolebinding CRB --clusterrole=CR --serviceaccount=X:S   # nodes, pv
k auth can-i <verb> <res> -n X --as=system:serviceaccount:X:S                  # 1 yes + 1 no · --as singular, --group=system:serviceaccounts:X plural · read the reason after "no -"
k -n X create rolebinding RB --clusterrole=NEW --serviceaccount=X:S $do > rb.yaml; k replace --force -f rb.yaml   # roleRef is immutable
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

### Measured on cp1, 5–7 Nov (guided pass with metrics-server 3.14.0 — Template C migration in progress)

**Analogy that landed:** Helm = `apt` for Kubernetes (repo · `repo update` · chart = `.deb` ·
values = the config · `helm list` = `dpkg -l`). Two differences: one chart installs many
times as named **releases**, and every release keeps a **history** (rollback).
The metrics-server chart renders 9 objects: SA, 2 ClusterRoles, 2 ClusterRoleBindings,
RoleBinding, Deployment, Service, APIService.

| Fact (measured) | Consequence |
|---|---|
| kubeadm kubelet certs have no IP SANs → without `--kubelet-insecure-tls` the pod stays `0/1`, log `x509: … doesn't contain any IP SANs`, `k top nodes` → `Metrics API not available` | `--set args={--kubelet-insecure-tls}` (list syntax). Not needed on EKS |
| `--set args=--x` (no braces) → `range can't iterate over --x` | Lists need `{a,b}` |
| `--set arg={…}` (wrong key) → **no error**, flag never reaches the Deployment | Read the key first: `helm show values <repo>/<chart> > values.yaml; grep -n '^key' values.yaml`. Prove with `jsonpath` on the Deployment, never with `STATUS: deployed` |
| `upgrade` **with** any `--set`/`-f` and **without** `--reuse-values` → chart defaults + only the new values (earlier `args` lost) | Upgrade with a `--set` → always `--reuse-values` |
| `upgrade` with **no** values at all (only `--version`) → previous values kept | Helm reuses them implicitly |
| `rollback <rel> <rev>` → a **new** revision ("Rollback to 1") | History is never rewritten |
| `helm list` without `-n` → only `default` | `-n <ns>` or `-A` on every helm command |
| `uninstall` removes cluster-scoped objects too (APIService), **not** the namespace | `k delete ns` separately if asked |
| Kustomize v5.8.1 in kubectl. `namespace:` in a kustomization does **not** create it → `namespaces "x" not found` | Create the namespace first (or add a Namespace resource) |
| `images: - name: <deployment name>` → silently ignored; `replicas: - name: <wrong>` → error `does not match` | `images.name` = image, `replicas.name` = Deployment |
| `k apply -f <kustomization dir>` → `apiVersion not set, kind not set` | `-k` |
| `labels: - pairs:` does not touch selectors | Safe on an existing Deployment |
| `--set args={a,b}` **unquoted** → bash brace-expands it → `Error: … unexpected arguments: args=b` (one item works unquoted) | Always quote: `--set args='{a,b}'` |
| A list item containing commas splits (`…=InternalIP,Hostname` → two items) | Escape `\,`, or use `-f values.yaml` |
| Several keys: `--set replicas=2,args='{…}'` or repeated `--set` — both work | Repeated `--set` reads easier |
| Short proof after install/upgrade: `helm get values <rel> -n <ns>` (USER-SUPPLIED VALUES) + the component's own behaviour (`k top nodes`) | Replaces the long jsonpath |
| `helm template … --reuse-values` → `unknown flag` (install has none either) | `--reuse-values` exists only on `upgrade` — it reuses the previous **revision** |
| `helm uninstall web-a team-a` (no `-n`) → `Release not loaded: web-a: release: not found`; the 2nd word is read as another release | `not found` on something you just saw = check `-n` before doubting the diagnosis |
| Helm shows a release with an unpullable image as `deployed` | Helm does not watch Pods: `k get pods -A \| grep -vE 'Running\|Completed'` → namespace → `helm list -A` → the release |
| `k apply -k kustomization.yaml` (the file) fails | `-k` takes the **directory**; `k kustomize <dir>` only prints (review), `k apply -k <dir>` renders + applies |
| `namespace:` in a kustomization is a transformer, not a generator — the Namespace object is never created | `k create ns X` first, or add a `kind: Namespace` file to `resources:` |
| `nameprefix:` (lowercase) worked — the field parser ignores case | Write `namePrefix` / `nameSuffix` / `newTag` as the docs do; do not rely on it |
| Release named differently from the task (`metrics-server` vs `metrics`): its APIService survived the namespace deletion → `v1beta1.metrics.k8s.io False (ServiceNotFound)` → **every** namespace stuck `Terminating` (`NamespaceDeletionDiscoveryFailure`) | Always `helm uninstall` (cleans cluster-scoped objects). Stuck namespace: `k get ns X -o yaml` conditions + `k get apiservice \| grep False` |
| Kustomize beyond the fields: `patches:` with a partial YAML (strategic merge, one object by kind+name) or `target:` + `op/path/value` (JSON6902, many objects) — measured on two Deployments | Recognise; copy from the docs page. Pods/ReplicaSets never sit in a base — patch the Deployment template |

**The literal-variables method (adopted 8 Nov, H1 7/11 → 11/11):** before the first
command, copy every name, number and path of the task into a shell variable
(`REL=… NS=… CH=<repo>/<chart> V1=… OV=<path>`), then type only the skeleton
`helm <verb> $REL $CH -n $NS [flags]`. Each literal is typed once, copied from the task.

### Command card — 1.6

```bash
helm repo add <repo> <url>; helm repo update; helm search repo <chart> --versions          # CHART VERSION ≠ APP VERSION
helm show values <repo>/<chart> > values.yaml; grep -n '^<key>' values.yaml               # exact key before --set
helm install <rel> <repo>/<chart> -n <ns> --create-namespace --set k=v --set list={a,b} [--version x.y.z]
helm list -n <ns> · k -n <ns> get deploy <d> -o jsonpath='{.spec.template.spec.containers[0].args}'   # proof = the object
helm upgrade <rel> <repo>/<chart> -n <ns> --reuse-values --set k=v [--version x.y.z]     # --set without --reuse-values drops earlier values
helm history <rel> -n <ns>; helm rollback <rel> <rev> -n <ns>                             # rollback = new revision
helm template <rel> <repo>/<chart> -n <ns> --set … > /path/file.yaml; helm uninstall <rel> -n <ns>   # ns stays
k kustomize <dir> | grep -nE '^kind|name:|namespace:|image:|replicas:'; k apply -k <dir>    # render, then -k
kustomization: resources · namespace · namePrefix · images: [{name: <IMAGE>, newTag}] · replicas: [{name: <DEPLOY>, count}]
```

⚠️ **EKS:** identical — Helm and Kustomize do not care what runs the control
plane. This is the one bullet in D1 where your day job transfers directly.

---

## 1.8 Understand CRDs, install and configure operators — recognise-only ✅ 8 Nov

**Runs on: cp1.**
**Theory →** notes_02 §1.9–1.11 · **Docs →** search `custom resources` →
*Extend the Kubernetes API with CustomResourceDefinitions* (full `CronTab` example) ·
`kubectl explain customresourcedefinition.spec.scope` · **Target: 5 min**

### The shape

A **CRD** teaches the API server a new kind. A **CR** is an instance of that
kind. An **operator** is a controller that watches those CRs and makes reality
match them. The CRD alone does nothing — it only creates the vocabulary.
Analogy that landed: CRD = the blank form · CR = the filled-in form · operator =
the clerk who reads it and acts. Calico in this lab: `tigera-operator` (clerk),
`installation/default` (form). **Tigera** is the company behind Calico — hence the
name and the API group `operator.tigera.io` (groups are a domain the author owns).

### The whiteboard — measured on `lab-v137`, 8 Nov

| Question | Command | Measured |
|---|---|---|
| Which kinds were added? | `k get crd` · `k get crd \| grep <group>` | 32 CRDs: 9 `operator.tigera.io` (the operator's: Installation, TigeraStatus, APIServer…), 22 `projectcalico.org` (Calico's own: IPPool, FelixConfiguration…), 1 `policy.networking.k8s.io` |
| Scope + short name? | `k api-resources --api-group=<group>` → `NAMESPACED`, `SHORTNAMES` | all 9 `operator.tigera.io` cluster-scoped; `projectcalico.org` 18 cluster-scoped, 4 namespaced |
| Fields of an unknown kind? | `k explain installation.spec` | works like a built-in kind (the CRD publishes a schema) |
| Where is the operator? | `k -n tigera-operator get deploy` · its CR `k get installation` · status `k get tigerastatus` | `tigera-operator 1/1` · `default` · `calico` Progressing while w2 is off (the operator compares CR vs reality) |
| Delete a CR vs its CRD | demo CRD `crontabs.stable.example.com` (docs example) + CR `my-cron` → `k delete crd …` | `k get ct` → `NotFound`: **every CR of the kind went with the CRD**. Calico untouched |

### Command card — 1.8

```bash
k get crd | grep <word>                              # which kinds, which group
k api-resources --api-group=<group>                  # KIND · NAMESPACED · SHORTNAMES
k explain <kind>.spec                                # fields
k -n <operator-ns> get deploy                        # the operator; scale to 0 = stop reconciling
k api-resources --api-group=<group> | sudo tee /opt/file    # write a list to a root-owned path
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

### Stage-4 blind runs — 1.1 (row 7 of `cka-D1.md §7`)

Graders verified 5 Nov against an empty state (FAIL), a correct solution (all PASS)
and a typical wrong one (FAIL caught). Use new literals for each future run.

```
Run R1  (target 4 min) — In the existing namespace finance: 1. Create a ServiceAccount
named report-bot. 2. Create a Role named report-reader that allows get and list on
Secrets, and only get on ConfigMaps. 3. Bind the Role report-reader to the ServiceAccount
report-bot with a RoleBinding named report-bot-rb. 4. Verify with kubectl auth can-i that
report-bot can list Secrets in finance and cannot delete them.
```

```bash
# 🧪 setup R1
echo 'a3ViZWN0bCBkZWxldGUgbnMgZmluYW5jZSAtLWlnbm9yZS1ub3QtZm91bmQgPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgY3JlYXRlIG5zIGZpbmFuY2UgPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgLW4gZmluYW5jZSBjcmVhdGUgY29uZmlnbWFwIGxlZGdlciAtLWZyb20tbGl0ZXJhbD1xPTQgPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgLW4gZmluYW5jZSBjcmVhdGUgc2VjcmV0IGdlbmVyaWMgYmFuayAtLWZyb20tbGl0ZXJhbD1pYmFuPXggPi9kZXYvbnVsbCAyPiYxCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
# 🔍 grader R1
echo 'Uz1zeXN0ZW06c2VydmljZWFjY291bnQ6ZmluYW5jZTpyZXBvcnQtYm90Cm9rKCl7IFsgIiQxIiA9ICIkMiIgXSAmJiBlY2hvICJQQVNTICAkMyIgfHwgZWNobyAiRkFJTCAgJDMgKGdvdCAnJDEnLCB3YW50ICckMicpIjsgfQpjaSgpeyBrdWJlY3RsIGF1dGggY2FuLWkgIiRAIiAtLWFzPSRTIDI+L2Rldi9udWxsIHwgYXdrICd7cHJpbnQgJDF9JzsgfQpvayAiJChrdWJlY3RsIC1uIGZpbmFuY2UgZ2V0IHNhIHJlcG9ydC1ib3QgLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJzZXJ2aWNlYWNjb3VudC9yZXBvcnQtYm90IiAiU2VydmljZUFjY291bnQgcmVwb3J0LWJvdCBleGlzdHMgaW4gZmluYW5jZSIKb2sgIiQoa3ViZWN0bCAtbiBmaW5hbmNlIGdldCByb2xlIHJlcG9ydC1yZWFkZXIgLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJyb2xlLnJiYWMuYXV0aG9yaXphdGlvbi5rOHMuaW8vcmVwb3J0LXJlYWRlciIgIlJvbGUgcmVwb3J0LXJlYWRlciBleGlzdHMgaW4gZmluYW5jZSIKb2sgIiQoa3ViZWN0bCAtbiBmaW5hbmNlIGdldCByb2xlYmluZGluZyByZXBvcnQtYm90LXJiIC1vIGpzb25wYXRoPSd7LnJvbGVSZWYua2luZH0vey5yb2xlUmVmLm5hbWV9JyAyPi9kZXYvbnVsbCkiICJSb2xlL3JlcG9ydC1yZWFkZXIiICJSb2xlQmluZGluZyByZXBvcnQtYm90LXJiIHBvaW50cyBhdCBSb2xlIHJlcG9ydC1yZWFkZXIiCm9rICIkKGt1YmVjdGwgLW4gZmluYW5jZSBnZXQgcm9sZWJpbmRpbmcgcmVwb3J0LWJvdC1yYiAtbyBqc29ucGF0aD0ne3JhbmdlIC5zdWJqZWN0c1sqXX17LmtpbmR9OnsubmFtZXNwYWNlfTp7Lm5hbWV9eyIgIn17ZW5kfScgMj4vZGV2L251bGwgfCBncmVwIC1jICdTZXJ2aWNlQWNjb3VudDpmaW5hbmNlOnJlcG9ydC1ib3QnKSIgIjEiICJSb2xlQmluZGluZyBzdWJqZWN0IGlzIFNBIGZpbmFuY2UvcmVwb3J0LWJvdCIKb2sgIiQoY2kgZ2V0IHNlY3JldHMgLW4gZmluYW5jZSkiICJ5ZXMiICJjYW4gZ2V0IHNlY3JldHMgaW4gZmluYW5jZSIKb2sgIiQoY2kgbGlzdCBzZWNyZXRzIC1uIGZpbmFuY2UpIiAieWVzIiAiY2FuIGxpc3Qgc2VjcmV0cyBpbiBmaW5hbmNlIgpvayAiJChjaSBnZXQgY29uZmlnbWFwcyAtbiBmaW5hbmNlKSIgInllcyIgImNhbiBnZXQgY29uZmlnbWFwcyBpbiBmaW5hbmNlIgpvayAiJChjaSBsaXN0IGNvbmZpZ21hcHMgLW4gZmluYW5jZSkiICJubyIgImNhbm5vdCBsaXN0IGNvbmZpZ21hcHMgKGdldCBvbmx5KSIKb2sgIiQoY2kgZGVsZXRlIHNlY3JldHMgLW4gZmluYW5jZSkiICJubyIgImNhbm5vdCBkZWxldGUgc2VjcmV0cyIKb2sgIiQoY2kgbGlzdCBzZWNyZXRzIC1uIGRlZmF1bHQpIiAibm8iICJubyBwZXJtaXNzaW9uIG91dHNpZGUgZmluYW5jZSIK' | base64 -d | bash
```

```
Run R2  (target 4 min) — In the existing namespace billing: 1. Create a ServiceAccount
named ci-runner. 2. Create a Role named deploy-watcher that allows get, list and watch on
Deployments, and only get on ConfigMaps. 3. Bind the Role deploy-watcher to the
ServiceAccount ci-runner with a RoleBinding named ci-runner-rb. 4. Verify with kubectl
auth can-i that ci-runner can watch Deployments in billing and cannot delete them.
```

```bash
# 🧪 setup R2
echo 'a3ViZWN0bCBkZWxldGUgbnMgYmlsbGluZyAtLWlnbm9yZS1ub3QtZm91bmQgPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgY3JlYXRlIG5zIGJpbGxpbmcgPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgLW4gYmlsbGluZyBjcmVhdGUgZGVwbG95IGludm9pY2VyIC0taW1hZ2U9bmdpbnggPi9kZXYvbnVsbCAyPiYxCmt1YmVjdGwgLW4gYmlsbGluZyBjcmVhdGUgY29uZmlnbWFwIHJhdGVzIC0tZnJvbS1saXRlcmFsPXZhdD0xOSA+L2Rldi9udWxsIDI+JjEKZWNobyAic2V0dXAgZG9uZSIK' | base64 -d | bash
# 🔍 grader R2
echo 'Uz1zeXN0ZW06c2VydmljZWFjY291bnQ6YmlsbGluZzpjaS1ydW5uZXIKb2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CmNpKCl7IGt1YmVjdGwgYXV0aCBjYW4taSAiJEAiIC0tYXM9JFMgMj4vZGV2L251bGwgfCBhd2sgJ3twcmludCAkMX0nOyB9Cm9rICIkKGt1YmVjdGwgLW4gYmlsbGluZyBnZXQgc2EgY2ktcnVubmVyIC1vIG5hbWUgMj4vZGV2L251bGwpIiAic2VydmljZWFjY291bnQvY2ktcnVubmVyIiAiU2VydmljZUFjY291bnQgY2ktcnVubmVyIGV4aXN0cyBpbiBiaWxsaW5nIgpvayAiJChrdWJlY3RsIC1uIGJpbGxpbmcgZ2V0IHJvbGUgZGVwbG95LXdhdGNoZXIgLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJyb2xlLnJiYWMuYXV0aG9yaXphdGlvbi5rOHMuaW8vZGVwbG95LXdhdGNoZXIiICJSb2xlIGRlcGxveS13YXRjaGVyIGV4aXN0cyBpbiBiaWxsaW5nIgpvayAiJChrdWJlY3RsIC1uIGJpbGxpbmcgZ2V0IHJvbGViaW5kaW5nIGNpLXJ1bm5lci1yYiAtbyBqc29ucGF0aD0ney5yb2xlUmVmLmtpbmR9L3sucm9sZVJlZi5uYW1lfScgMj4vZGV2L251bGwpIiAiUm9sZS9kZXBsb3ktd2F0Y2hlciIgIlJvbGVCaW5kaW5nIGNpLXJ1bm5lci1yYiBwb2ludHMgYXQgUm9sZSBkZXBsb3ktd2F0Y2hlciIKb2sgIiQoa3ViZWN0bCAtbiBiaWxsaW5nIGdldCByb2xlYmluZGluZyBjaS1ydW5uZXItcmIgLW8ganNvbnBhdGg9J3tyYW5nZSAuc3ViamVjdHNbKl19ey5raW5kfTp7Lm5hbWVzcGFjZX06ey5uYW1lfXsiICJ9e2VuZH0nIDI+L2Rldi9udWxsIHwgZ3JlcCAtYyAnU2VydmljZUFjY291bnQ6YmlsbGluZzpjaS1ydW5uZXInKSIgIjEiICJSb2xlQmluZGluZyBzdWJqZWN0IGlzIFNBIGJpbGxpbmcvY2ktcnVubmVyIgpmb3IgdiBpbiBnZXQgbGlzdCB3YXRjaDsgZG8gb2sgIiQoY2kgJHYgZGVwbG95bWVudHMuYXBwcyAtbiBiaWxsaW5nKSIgInllcyIgImNhbiAkdiBkZXBsb3ltZW50cyBpbiBiaWxsaW5nIjsgZG9uZQpvayAiJChjaSBnZXQgY29uZmlnbWFwcyAtbiBiaWxsaW5nKSIgInllcyIgImNhbiBnZXQgY29uZmlnbWFwcyBpbiBiaWxsaW5nIgpvayAiJChjaSBsaXN0IGNvbmZpZ21hcHMgLW4gYmlsbGluZykiICJubyIgImNhbm5vdCBsaXN0IGNvbmZpZ21hcHMgKGdldCBvbmx5KSIKb2sgIiQoY2kgZGVsZXRlIGRlcGxveW1lbnRzLmFwcHMgLW4gYmlsbGluZykiICJubyIgImNhbm5vdCBkZWxldGUgZGVwbG95bWVudHMiCm9rICIkKGNpIGxpc3QgZGVwbG95bWVudHMuYXBwcyAtbiBkZWZhdWx0KSIgIm5vIiAibm8gcGVybWlzc2lvbiBvdXRzaWRlIGJpbGxpbmciCg==' | base64 -d | bash
```

| Run | Date | Score | Time | Root cause code |
|---|---|---|---|---|
| R1 | 5 Nov | 9/10 | 12:25 ✗ | `LIT` `ConfigMaps` typed in vim (142) · `/n` (143) · missing `>` (144) · `SPEED` `-h` lookups (146) · `PREC` second rule unproven (145) |
| R2 | 5 Nov | 11/11 | 5:35 ✗ | `SPEED` (146) · `PREC` second rule unproven (145). Role file saved at 2:14; new two-rule method clean |
| R3 `payroll` (Jobs + pods/log) | 7 Nov | — | voided at 4:20 | `CONF` `--subresource` used in `create role` (148) — coached, restarted |
| R3′ same task | 7 Nov | 11/12 | 6:08 ✗ | `LIT` `pods/logs` (149) · `PREC` (145) |
| R4 `hr` (Pods + pods/exec) | 7 Nov | 9/11 | 4:34 ✗ | `PREC` 2nd header not deleted → first rule silently lost (150) |
| R5 `legal` (Services + deployments/scale) | 7 Nov | 9/11 | **3:37** | `READ` `deployments` without `/scale` → over-privileged (151) |
| R6 `support` (ConfigMaps + pods/portforward) | 7 Nov | **11/11** | 4:14 ✗ | first clean run with one `can-i` per rule |

Graders for R3–R6 were verified the same way (empty / correct / one typical wrong) and
are not kept: every future run uses new literals.

### Drill H1 — Helm + Kustomize (row 8 of `cka-D1.md §7`, target 6:00)

Grader verified 7 Nov: correct solution 11/11; `--set replicas=2` without
`--reuse-values` caught. ⚠️ The setup wipes **every** Helm release, the metrics
APIService and its cluster objects, `~/kz`, `~/shop`, `~/*.yaml` and the
`metrics-server` repo (hardened 8 Nov after a stale APIService froze namespace
deletion).

```
Task  (weight 7%)                                             target 6 min
Part 1 — Helm: Add the Helm repository https://kubernetes-sigs.github.io/metrics-server/
under the name metrics-server. Install the chart metrics-server, chart version 3.13.0,
as a release named metrics in a new namespace monitoring. The server must run with the
argument --kubelet-insecure-tls. Then upgrade the release metrics to chart version 3.14.0
and set the number of replicas to 2, keeping the existing configuration. Confirm that
kubectl top nodes returns node metrics.
Part 2 — Kustomize: A Kustomize overlay exists at /home/ubuntu/shop/overlays/staging.
Without modifying the base, make the overlay deploy the image nginx:1.28 and apply the
overlay.
```

```bash
# 🧪 setup H1 (run from ~)
echo 'aGVsbSBsaXN0IC1BIC0tbm8taGVhZGVycyAyPi9kZXYvbnVsbCB8IGF3ayAne3ByaW50ICQxLCAkMn0nIHwgd2hpbGUgcmVhZCByIG47IGRvIGhlbG0gdW5pbnN0YWxsICIkciIgLW4gIiRuIiA+L2Rldi9udWxsIDI+JjE7IGRvbmUKa3ViZWN0bCBkZWxldGUgYXBpc2VydmljZSB2MWJldGExLm1ldHJpY3MuazhzLmlvIC0taWdub3JlLW5vdC1mb3VuZCA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBkZWxldGUgY2x1c3RlcnJvbGUsY2x1c3RlcnJvbGViaW5kaW5nIC1sIGFwcC5rdWJlcm5ldGVzLmlvL25hbWU9bWV0cmljcy1zZXJ2ZXIgLS1pZ25vcmUtbm90LWZvdW5kID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGRlbGV0ZSBucyBtb25pdG9yaW5nIG1ldHJpY3Mgc2hvcC1zdGcgc2hvcC1wcm9kIC0taWdub3JlLW5vdC1mb3VuZCA+L2Rldi9udWxsIDI+JjEKaGVsbSByZXBvIHJlbW92ZSBtZXRyaWNzLXNlcnZlciA+L2Rldi9udWxsIDI+JjEKcm0gLXJmIH4vc2hvcCB+L2t6IH4vKi55YW1sCm1rZGlyIC1wIH4vc2hvcC9iYXNlIH4vc2hvcC9vdmVybGF5cy9zdGFnaW5nCmt1YmVjdGwgY3JlYXRlIGRlcGxveSB3ZWIgLS1pbWFnZT1uZ2lueDoxLjI3IC0tZHJ5LXJ1bj1jbGllbnQgLW8geWFtbCA+IH4vc2hvcC9iYXNlL2RlcGxveS55YW1sCnByaW50ZiAncmVzb3VyY2VzOlxuLSBkZXBsb3kueWFtbFxuJyA+IH4vc2hvcC9iYXNlL2t1c3RvbWl6YXRpb24ueWFtbApwcmludGYgJ3Jlc291cmNlczpcbi0gLi4vLi4vYmFzZVxubmFtZXNwYWNlOiBzaG9wLXN0Z1xubmFtZVByZWZpeDogc3RnLVxucmVwbGljYXM6XG4tIG5hbWU6IHdlYlxuICBjb3VudDogMlxuJyA+IH4vc2hvcC9vdmVybGF5cy9zdGFnaW5nL2t1c3RvbWl6YXRpb24ueWFtbAprdWJlY3RsIGNyZWF0ZSBucyBzaG9wLXN0ZyA+L2Rldi9udWxsIDI+JjEKZWNobyAic2V0dXAgZG9uZSIK' | base64 -d | bash
# 🔍 grader H1
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9ClI9JChoZWxtIGxpc3QgLW4gbW9uaXRvcmluZyAtbyBqc29uIDI+L2Rldi9udWxsKQpvayAiJChlY2hvICIkUiIgfCBncmVwIC1vICcibmFtZSI6Im1ldHJpY3MiJyB8IGhlYWQgLTEpIiAnIm5hbWUiOiJtZXRyaWNzIicgIkhlbG0gcmVsZWFzZSBtZXRyaWNzIGV4aXN0cyBpbiBtb25pdG9yaW5nIgpvayAiJChlY2hvICIkUiIgfCBncmVwIC1vICciY2hhcnQiOiJbXiJdKiInIHwgaGVhZCAtMSkiICciY2hhcnQiOiJtZXRyaWNzLXNlcnZlci0zLjE0LjAiJyAicmVsZWFzZSBydW5zIGNoYXJ0IDMuMTQuMCIKb2sgIiQoZWNobyAiJFIiIHwgZ3JlcCAtbyAnInN0YXR1cyI6IlteIl0qIicgfCBoZWFkIC0xKSIgJyJzdGF0dXMiOiJkZXBsb3llZCInICJyZWxlYXNlIHN0YXR1cyBkZXBsb3llZCIKb2sgIiQoaGVsbSBoaXN0b3J5IG1ldHJpY3MgLW4gbW9uaXRvcmluZyAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ21ldHJpY3Mtc2VydmVyLTMuMTMuMCcpIiAiMSIgImhpc3Rvcnkgc2hvd3MgdGhlIDMuMTMuMCBpbnN0YWxsIgpvayAiJChrdWJlY3RsIC1uIG1vbml0b3JpbmcgZ2V0IGRlcGxveSBtZXRyaWNzLW1ldHJpY3Mtc2VydmVyIC1vIGpzb25wYXRoPSd7LnNwZWMudGVtcGxhdGUuc3BlYy5jb250YWluZXJzWzBdLmFyZ3N9JyAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ2t1YmVsZXQtaW5zZWN1cmUtdGxzJykiICIxIiAiLS1rdWJlbGV0LWluc2VjdXJlLXRscyBzdGlsbCBzZXQgYWZ0ZXIgdGhlIHVwZ3JhZGUiCm9rICIkKGt1YmVjdGwgLW4gbW9uaXRvcmluZyBnZXQgZGVwbG95IG1ldHJpY3MtbWV0cmljcy1zZXJ2ZXIgLW8ganNvbnBhdGg9ey5zcGVjLnJlcGxpY2FzfSAyPi9kZXYvbnVsbCkiICIyIiAibWV0cmljcy1zZXJ2ZXIgcnVucyAyIHJlcGxpY2FzIGFmdGVyIHRoZSB1cGdyYWRlIgpUPW5vOyBmb3IgaSBpbiAkKHNlcSAxIDEyKTsgZG8ga3ViZWN0bCB0b3Agbm9kZXMgPi9kZXYvbnVsbCAyPiYxICYmIHsgVD15ZXM7IGJyZWFrOyB9OyBzbGVlcCA1OyBkb25lCm9rICIkVCIgInllcyIgImt1YmVjdGwgdG9wIG5vZGVzIHdvcmtzIgpvayAiJChrdWJlY3RsIC1uIHNob3Atc3RnIGdldCBkZXBsb3kgc3RnLXdlYiAtbyBqc29ucGF0aD0ney5zcGVjLnRlbXBsYXRlLnNwZWMuY29udGFpbmVyc1swXS5pbWFnZX0nIDI+L2Rldi9udWxsKSIgIm5naW54OjEuMjgiICJzdGctd2ViIHJ1bnMgbmdpbng6MS4yOCBpbiBzaG9wLXN0ZyIKb2sgIiQoa3ViZWN0bCAtbiBzaG9wLXN0ZyBnZXQgZGVwbG95IHN0Zy13ZWIgLW8ganNvbnBhdGg9J3suc3BlYy5yZXBsaWNhc30nIDI+L2Rldi9udWxsKSIgIjIiICJzdGctd2ViIGtlZXBzIDIgcmVwbGljYXMiCm9rICIkKGdyZXAgLWMgJ25naW54OjEuMjcnIH4vc2hvcC9iYXNlL2RlcGxveS55YW1sIDI+L2Rldi9udWxsKSIgIjEiICJiYXNlIGxlZnQgdW50b3VjaGVkIChpbWFnZSBjaGFuZ2VkIGluIHRoZSBvdmVybGF5KSIKb2sgIiQoZ3JlcCAtYyAnbmV3VGFnJyB+L3Nob3Avb3ZlcmxheXMvc3RhZ2luZy9rdXN0b21pemF0aW9uLnlhbWwgMj4vZGV2L251bGwpIiAiMSIgIm92ZXJsYXkgc2V0cyB0aGUgaW1hZ2UgKGltYWdlczogbmV3VGFnKSIK' | base64 -d | bash
```

| H1 run | Date | Score | Time | Notes |
|---|---|---|---|---|
| blind 1 | 8 Nov | 7/11 | 15:37 ✗ | release named `metrics-server` (all 4 FAILs), `version` without `--`, `-k` on the file — rows 153–155 |
| variables 1 | 8 Nov | 11/11 | 10:59 ✗ | literal variables adopted: zero literal errors |
| variables 2 | 8 Nov | **11/11** | 6:32 ✗ | 32 s over. Next: H1 **cold**, twice ≤ 6:00, closes 1.6 |

### Micro-drills M1–M5 — Helm + Kustomize, varied wording (8 Nov)

One setup for all five; grade each with `… | base64 -d | bash -s <n>`. Graders
verified 8 Nov (empty / correct). ⚠️ The setup wipes every Helm release, the metrics
APIService, `~/shop ~/kz ~/app ~/charts ~/*.yaml`, and creates a broken release
(`web-b`, unpullable tag) from a local `helm create` chart.

```
M1 (1:30) The Helm release ms in namespace obs was recently upgraded, and since then kubectl
   top nodes no longer works. Roll the release back to the revision that was running before
   the upgrade.
M2 (1:30) Without installing anything in the cluster, render the manifests of the chart
   metrics-server/metrics-server, chart version 3.14.0, for a release named preview in
   namespace tools, with the server argument --kubelet-insecure-tls. Write the result to
   /home/ubuntu/preview.yaml.
M3 (2:00) One of the Helm releases in this cluster deploys a container image that cannot be
   pulled. Find that release and uninstall it. Do not touch any other release.
M4 (2:00) Edit the Kustomize overlay at /home/ubuntu/app/overlays/qa so that all of its
   resources are created in the namespace qa and their names start with the prefix qa-.
   Apply the overlay. The namespace qa does not exist yet. Do not modify the base.
M5 (1:00) Write the fully rendered manifests of the Kustomize overlay at
   /home/ubuntu/app/overlays/prod to /home/ubuntu/prod-rendered.yaml. Do not create anything
   in the cluster.
```

```bash
# 🧪 setup M1–M5 (run from ~, ~20 s)
echo 'aGVsbSBsaXN0IC1BIC0tbm8taGVhZGVycyAyPi9kZXYvbnVsbCB8IGF3ayAne3ByaW50ICQxLCAkMn0nIHwgd2hpbGUgcmVhZCByIG47IGRvIGhlbG0gdW5pbnN0YWxsICIkciIgLW4gIiRuIiA+L2Rldi9udWxsIDI+JjE7IGRvbmUKa3ViZWN0bCBkZWxldGUgYXBpc2VydmljZSB2MWJldGExLm1ldHJpY3MuazhzLmlvIC0taWdub3JlLW5vdC1mb3VuZCA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBkZWxldGUgY2x1c3RlcnJvbGUsY2x1c3RlcnJvbGViaW5kaW5nIC1sIGFwcC5rdWJlcm5ldGVzLmlvL25hbWU9bWV0cmljcy1zZXJ2ZXIgLS1pZ25vcmUtbm90LWZvdW5kID4vZGV2L251bGwgMj4mMQprdWJlY3RsIGRlbGV0ZSBucyBtb25pdG9yaW5nIG1ldHJpY3Mgc2hvcC1zdGcgc2hvcC1wcm9kIG9icyB0b29scyB0ZWFtLWEgdGVhbS1iIHFhIHByb2QgLS1pZ25vcmUtbm90LWZvdW5kID4vZGV2L251bGwgMj4mMQpybSAtcmYgfi9zaG9wIH4va3ogfi9hcHAgfi9jaGFydHMgfi8qLnlhbWwKaGVsbSByZXBvIGFkZCBtZXRyaWNzLXNlcnZlciBodHRwczovL2t1YmVybmV0ZXMtc2lncy5naXRodWIuaW8vbWV0cmljcy1zZXJ2ZXIvID4vZGV2L251bGwgMj4mMTsgaGVsbSByZXBvIHVwZGF0ZSA+L2Rldi9udWxsIDI+JjEKa3ViZWN0bCBjcmVhdGUgbnMgb2JzID4vZGV2L251bGwgMj4mMQpoZWxtIGluc3RhbGwgbXMgbWV0cmljcy1zZXJ2ZXIvbWV0cmljcy1zZXJ2ZXIgLW4gb2JzIC0tdmVyc2lvbiAzLjEzLjAgLS1zZXQgYXJncz0ney0ta3ViZWxldC1pbnNlY3VyZS10bHN9JyA+L2Rldi9udWxsIDI+JjEKaGVsbSB1cGdyYWRlIG1zIG1ldHJpY3Mtc2VydmVyL21ldHJpY3Mtc2VydmVyIC1uIG9icyAtLXZlcnNpb24gMy4xNC4wIC0tc2V0IHJlcGxpY2FzPTIgPi9kZXYvbnVsbCAyPiYxCm1rZGlyIC1wIH4vY2hhcnRzICYmIGNkIH4vY2hhcnRzICYmIGhlbG0gY3JlYXRlIHdlYmFwcCA+L2Rldi9udWxsIDI+JjEgJiYgY2QgfgpoZWxtIGluc3RhbGwgd2ViLWEgfi9jaGFydHMvd2ViYXBwIC1uIHRlYW0tYSAtLWNyZWF0ZS1uYW1lc3BhY2UgPi9kZXYvbnVsbCAyPiYxCmhlbG0gaW5zdGFsbCB3ZWItYiB+L2NoYXJ0cy93ZWJhcHAgLW4gdGVhbS1iIC0tY3JlYXRlLW5hbWVzcGFjZSAtLXNldCBpbWFnZS50YWc9OS45LjktbWlzc2luZyA+L2Rldi9udWxsIDI+JjEKbWtkaXIgLXAgfi9hcHAvYmFzZSB+L2FwcC9vdmVybGF5cy9xYSB+L2FwcC9vdmVybGF5cy9wcm9kCmt1YmVjdGwgY3JlYXRlIGRlcGxveSB3ZWIgLS1pbWFnZT1uZ2lueDoxLjI3IC0tZHJ5LXJ1bj1jbGllbnQgLW8geWFtbCA+IH4vYXBwL2Jhc2UvZGVwbG95LnlhbWwKcHJpbnRmICdyZXNvdXJjZXM6XG4tIGRlcGxveS55YW1sXG4nID4gfi9hcHAvYmFzZS9rdXN0b21pemF0aW9uLnlhbWwKcHJpbnRmICdyZXNvdXJjZXM6XG4tIC4uLy4uL2Jhc2VcbicgPiB+L2FwcC9vdmVybGF5cy9xYS9rdXN0b21pemF0aW9uLnlhbWwKcHJpbnRmICdyZXNvdXJjZXM6XG4tIC4uLy4uL2Jhc2Vcbm5hbWVzcGFjZTogcHJvZFxucmVwbGljYXM6XG4tIG5hbWU6IHdlYlxuICBjb3VudDogM1xuJyA+IH4vYXBwL292ZXJsYXlzL3Byb2Qva3VzdG9taXphdGlvbi55YW1sCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
# 🔍 grader M<n>
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CmNhc2UgIiQxIiBpbgoxKSBvayAiJChoZWxtIGhpc3RvcnkgbXMgLW4gb2JzIDI+L2Rldi9udWxsIHwgZ3JlcCBkZXBsb3llZCB8IGdyZXAgLWMgJ1JvbGxiYWNrIHRvIDEnKSIgIjEiICJNMSBkZXBsb3llZCByZXZpc2lvbiBpcyBhIHJvbGxiYWNrIgogICBvayAiJChoZWxtIGxpc3QgLW4gb2JzIC1vIGpzb24gMj4vZGV2L251bGwgfCBncmVwIC1vICciY2hhcnQiOiJbXiJdKiInKSIgJyJjaGFydCI6Im1ldHJpY3Mtc2VydmVyLTMuMTMuMCInICJNMSByZWxlYXNlIG1zIGJhY2sgb24gY2hhcnQgMy4xMy4wIgogICBvayAiJChrdWJlY3RsIC1uIG9icyBnZXQgZGVwbG95IG1zLW1ldHJpY3Mtc2VydmVyIC1vIGpzb25wYXRoPSd7LnNwZWMudGVtcGxhdGUuc3BlYy5jb250YWluZXJzWzBdLmFyZ3N9JyAyPi9kZXYvbnVsbCB8IGdyZXAgLWMga3ViZWxldC1pbnNlY3VyZS10bHMpIiAiMSIgIk0xIC0ta3ViZWxldC1pbnNlY3VyZS10bHMgcmVzdG9yZWQiIDs7CjIpIEY9L2hvbWUvdWJ1bnR1L3ByZXZpZXcueWFtbAogICBvayAiJCh0ZXN0IC1zICRGICYmIGVjaG8geWVzKSIgInllcyIgIk0yICRGIGV4aXN0cyIKICAgb2sgIiQoZ3JlcCAtYyAnbmFtZTogcHJldmlldy1tZXRyaWNzLXNlcnZlcicgJEYgMj4vZGV2L251bGwgfCBzZWQgJ3MvWzEtOV1bMC05XSovbi8nKSIgIm4iICJNMiBvYmplY3RzIG5hbWVkIGFmdGVyIHJlbGVhc2UgcHJldmlldyIKICAgb2sgIiQoZ3JlcCAtYyAnaGVsbS5zaC9jaGFydDogbWV0cmljcy1zZXJ2ZXItMy4xNC4wJyAkRiAyPi9kZXYvbnVsbCB8IHNlZCAncy9bMS05XVswLTldKi9uLycpIiAibiIgIk0yIHJlbmRlcmVkIGZyb20gY2hhcnQgMy4xNC4wIgogICBvayAiJChncmVwIC1jICdrdWJlbGV0LWluc2VjdXJlLXRscycgJEYgMj4vZGV2L251bGwpIiAiMSIgIk0yIGFyZ3VtZW50IHByZXNlbnQiCiAgIG9rICIkKGdyZXAgLWMgJ25hbWVzcGFjZTogdG9vbHMnICRGIDI+L2Rldi9udWxsIHwgc2VkICdzL1sxLTldWzAtOV0qL24vJykiICJuIiAiTTIgbmFtZXNwYWNlIHRvb2xzIgogICBvayAiJChoZWxtIGxpc3QgLUEgLXEgMj4vZGV2L251bGwgfCBncmVwIC1jICdecHJldmlldyQnKSIgIjAiICJNMiBub3RoaW5nIGluc3RhbGxlZCIgOzsKMykgb2sgIiQoaGVsbSBsaXN0IC1uIHRlYW0tYiAtcSAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ153ZWItYiQnKSIgIjAiICJNMyBicm9rZW4gcmVsZWFzZSB3ZWItYiB1bmluc3RhbGxlZCIKICAgb2sgIiQoaGVsbSBsaXN0IC1uIHRlYW0tYSAtcSAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ153ZWItYSQnKSIgIjEiICJNMyBoZWFsdGh5IHJlbGVhc2Ugd2ViLWEga2VwdCIKICAgb2sgIiQoaGVsbSBsaXN0IC1uIG9icyAtcSAyPi9kZXYvbnVsbCB8IGdyZXAgLWMgJ15tcyQnKSIgIjEiICJNMyByZWxlYXNlIG1zIGtlcHQiIDs7CjQpIG9rICIkKGt1YmVjdGwgLW4gcWEgZ2V0IGRlcGxveSBxYS13ZWIgLW8gbmFtZSAyPi9kZXYvbnVsbCkiICJkZXBsb3ltZW50LmFwcHMvcWEtd2ViIiAiTTQgZGVwbG95IHFhLXdlYiBpbiBuYW1lc3BhY2UgcWEiCiAgIG9rICIkKGdyZXAgLWMgJ25hbWVzcGFjZScgL2hvbWUvdWJ1bnR1L2FwcC9iYXNlL2RlcGxveS55YW1sIC9ob21lL3VidW50dS9hcHAvYmFzZS9rdXN0b21pemF0aW9uLnlhbWwgMj4vZGV2L251bGwgfCBhd2sgLUY6ICd7cys9JDJ9IEVORHtwcmludCBzfScpIiAiMCIgIk00IGJhc2UgdW50b3VjaGVkIgogICBvayAiJChrdWJlY3RsIGdldCBkZXBsb3kgLUEgLS1uby1oZWFkZXJzIDI+L2Rldi9udWxsIHwgYXdrICckMj09IndlYiInIHwgd2MgLWwpIiAiMCIgIk00IG5vdGhpbmcgYXBwbGllZCB3aXRob3V0IHRoZSBvdmVybGF5IiA7Owo1KSBGPS9ob21lL3VidW50dS9wcm9kLXJlbmRlcmVkLnlhbWwKICAgb2sgIiQoZ3JlcCAtYyAncmVwbGljYXM6IDMnICRGIDI+L2Rldi9udWxsKSIgIjEiICJNNSByZW5kZXJlZCBmaWxlIGhhcyByZXBsaWNhcyAzIgogICBvayAiJChncmVwIC1jICduYW1lc3BhY2U6IHByb2QnICRGIDI+L2Rldi9udWxsKSIgIjEiICJNNSByZW5kZXJlZCBmaWxlIGluIG5hbWVzcGFjZSBwcm9kIgogICBvayAiJChrdWJlY3RsIGdldCBucyBwcm9kIC1vIG5hbWUgMj4vZGV2L251bGw7IGt1YmVjdGwgLW4gcHJvZCBnZXQgZGVwbG95IC1vIG5hbWUgMj4vZGV2L251bGwpIiAiIiAiTTUgbm90aGluZyBhcHBsaWVkIiA7Owplc2FjCg==' | base64 -d | bash -s <n>
```

| Drill | Date | Score | Time | Notes |
|---|---|---|---|---|
| M1 rollback | 8 Nov | 3/3 | **1:16** ✅ | read `history` first |
| M2 template to file | 8 Nov | 6/6 | **1:07** ✅ | tried `--reuse-values` on `template` (no such flag) |
| M3 find + uninstall | 8 Nov | 3/3 | 4:13 ✗ | diagnosis right; `uninstall` without `-n` (row 156) |
| M4 namespace + prefix | 8 Nov | 3/3 | **1:23** ✅ | 1st attempt voided (no idea how to write the fields); `nameprefix` lowercase |
| M5 render overlay | 8 Nov | 3/3 | 2:05 ✗ | `k kustomize <dir> > file` |

### Task D — setup and grader (8 Nov)

```bash
# 🧪 setup D
echo 'c3VkbyBybSAtZiAvb3B0L2NyZHMudHh0CmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
# 🔍 grader D — every operator.tigera.io kind with its NAMESPACED value; no projectcalico.org kinds
echo 'Rj0vb3B0L2NyZHMudHh0Cm9rKCl7IFsgIiQxIiA9ICIkMiIgXSAmJiBlY2hvICJQQVNTICAkMyIgfHwgZWNobyAiRkFJTCAgJDMgKGdvdCAnJDEnLCB3YW50ICckMicpIjsgfQpvayAiJCh0ZXN0IC1zICRGICYmIGVjaG8geWVzKSIgInllcyIgIiRGIGV4aXN0cyBhbmQgaXMgbm90IGVtcHR5IgpuPTA7IG09MAp3aGlsZSByZWFkIGtpbmQgc2NvcGU7IGRvIG49JCgobisxKSk7IGdyZXAgLUUgIihefFtbOnNwYWNlOl1dKSRraW5kKFtbOnNwYWNlOl1dfCQpIiAkRiAyPi9kZXYvbnVsbCB8IGdyZXAgLXF3ICIkc2NvcGUiICYmIG09JCgobSsxKSk7IGRvbmUgPCA8KGt1YmVjdGwgYXBpLXJlc291cmNlcyAtLWFwaS1ncm91cD1vcGVyYXRvci50aWdlcmEuaW8gLS1uby1oZWFkZXJzIHwgYXdrICd7cHJpbnQgJE5GLCAkKE5GLTEpfScpCm9rICIkbSIgIiRuIiAiZXZlcnkgb3BlcmF0b3IudGlnZXJhLmlvIGtpbmQgbGlzdGVkIHdpdGggaXRzIE5BTUVTUEFDRUQgdmFsdWUgKCRuIGtpbmRzKSIKb2sgIiQoZ3JlcCAtYyAncHJvamVjdGNhbGljby5vcmcnICRGIDI+L2Rldi9udWxsKSIgIjAiICJubyBraW5kcyBmcm9tIG90aGVyIGdyb3VwcyAocHJvamVjdGNhbGljby5vcmcpIgo=' | base64 -d | bash
```

Task D wording used on 8 Nov adds "(API group operator.tigera.io)" after "Calico operator".

### Variations — the same task as the exam rewords it

- "…allows **only** get on …" next to another resource with more verbs → two rules (`$do > r.yaml`, second rule `$do >> r.yaml`, vim `/^apiVersion` · `6dd`).
- The task names **Kinds** ("Secrets", "ConfigMaps", "Deployments") → `--resource=` takes them and kubectl normalises; never type them in vim (row 142).
- "The user **jane** …" → subject `--user=jane`; prove with `--as=jane`.
- "Every ServiceAccount in namespace X …" → `--group=system:serviceaccounts:X`.
- "Modify the existing binding so that …" → check: `roleRef` or `subjects`? Editing table.
- "…in all namespaces" → ClusterRole + **ClusterRoleBinding**.
- "Pod P must run as ServiceAccount S" with P already running → recreate from `/tmp` or `-o yaml`.

| Task | Date | Score | Time | Root cause code |
|---|---|---|---|---|
| A | 28 Sep | 11/11 | 8:00 ✗ | `LIT` flags `--verbs`/`--resources` (28 Sep rows, never copied into `mistakes.md`; numbers 112–117 now belong to D1-1) |
| B (lab run 2 `audit`) | 28 Sep | 0 functional | 7:00 ✗ | `PREC` no apply · `CONF` binding NAME · `LIT` (same — not in `mistakes.md`) |
| C | | | | |
| D | 8 Nov | 3/3 | **0:41** ✅ | full `api-resources` table piped through `sudo tee` |
