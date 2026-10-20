---
exams: [KCNA, CKA, CKAD]
domain: Storage
kcna_domains: 2.4 Storage
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/storage/ (volumes, persistent-volumes, storage-classes, ephemeral-volumes, volume-snapshots, projected-volumes), /concepts/workloads/controllers/statefulset, kubernetes-csi.github.io (CSI spec, conceptual)
template: B
language: en
scope: KCNA ONLY — CKA/CKAD layers appended from 11 Sep
status: draft
written: 2026-09-03
format: per claude/depth-standard.md AMENDMENT 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). Verified this session — ReadWriteOncePod introduced v1.22, **GA v1.29**; `persistentVolumeClaimRetentionPolicy` alpha v1.23, beta v1.27, **GA v1.32**, both fields default `Retain`; PVC expansion stable since v1.24.
closes_mistakes: row 26 (ConfigMap — the volume-projection half; the confidentiality half stays in note 07)
---

# Storage

*A container's filesystem dies with the container. Everything in this note
exists because sometimes that is unacceptable.*

KCNA area 2.4 ≈ **5–6 of the 60 questions**. It builds directly on note 04
§1.10 (the writable layer) and note 03 §1.6 (StatefulSet identity), and it is
the area where EKS has done the most work invisibly on your behalf.

---

## 1. Core Concepts

### 1.1 Why storage is a problem at all

*The container's writable layer is a scratch pad that is thrown away — not a
disk.*

From note 04 §1.10: a running container is read-only image layers plus **one
thin writable layer on top**, using copy-on-write. That writable layer is
**deleted when the container is removed**. Two consequences that shape everything
below:

| Event | What happens to the writable layer |
|---|---|
| Container **crashes and restarts** in place | Kept — same container, restarted process |
| Container is **replaced** (image change, Pod recreated) | **Gone** |
| Pod is **rescheduled to another node** | **Gone**, and it was never on the new node |

So a database writing to `/var/lib/postgresql` inside the container loses
everything the first time its Pod moves. A **volume** is a directory mounted into
the container from **outside** that writable layer, with its own independent
lifetime.

The whole subject reduces to one question: **how long should this data outlive
the container?**

```
lifetime of the container   →  no volume needed (writable layer)
lifetime of the Pod         →  ephemeral volume  (emptyDir, configMap, secret…)
longer than the Pod         →  persistent volume (PVC → PV)
```

### 1.2 The two families of volume

*Ephemeral volumes are born and die with the Pod. Persistent volumes are separate
objects the Pod merely borrows.*

| | Ephemeral volume | Persistent volume |
|---|---|---|
| Defined in | The Pod spec, inline | **Separate API objects** (PV, PVC) |
| Lifetime | **Tied to the Pod** | Independent — outlives Pods, and usually the workload |
| Survives rescheduling? | **No** | **Yes** |
| Cluster-scoped object? | No | **PV yes, PVC no** (PVC is namespaced) |
| Typical use | Scratch space, config, credentials, metadata | Databases, uploads, anything that matters |

The word "volume" alone is ambiguous, and the exam exploits it. `spec.volumes`
in a Pod holds **both** families — an `emptyDir` and a `persistentVolumeClaim`
appear in the same list and look alike. What differs is what backs them.

### 1.3 The ephemeral volumes worth knowing

*Four things you mount into a Pod that are not persistent storage: scratch space,
configuration, credentials, and facts about the Pod itself.*

| Type | Contains | Lifetime | Notes |
|---|---|---|---|
| **`emptyDir`** | An empty directory | **The Pod.** Deleted when the Pod is removed from the node | **Survives container restarts** — the classic sidecar-sharing mechanism |
| **`configMap`** | Keys from a ConfigMap, as files | The Pod | **Read-only.** One file per key |
| **`secret`** | Keys from a Secret, as files | The Pod | Read-only, backed by **tmpfs** (RAM) — never written to node disk |
| **`downwardAPI`** | Facts about the Pod itself | The Pod | Labels, annotations, name, namespace, resource limits — as files |

**`emptyDir` is the sharing mechanism inside a Pod.** Remember from note 03 §1.4
that containers in a Pod do **not** share a mount namespace — each has its own
filesystem. An `emptyDir` mounted into two of them is how they exchange files. Set
`medium: Memory` and it becomes a tmpfs — fast, and **it counts against the Pod's
memory limit**, so it can trigger the OOMKill from note 03 §1.11.

**`configMap` and `secret` volumes update themselves.** Change the ConfigMap and
the files in the Pod are refreshed by the kubelet, without a restart — with a
lag of up to about a minute. **The exception is `subPath`**: mounting a single
key with `subPath` gives you a file that **never updates**. That is a real
production trap and a fair exam question.

**On `mistakes.md` row 26:** a **ConfigMap** holds non-confidential key/value
configuration that a Pod consumes as environment variables or as mounted files;
a **Secret** holds confidential data. Here you have the volume mechanism. The
confidentiality half — base64 is not encryption, RBAC, encryption at rest — is
note 07's, and that is where the row finally closes.

### 1.4 PersistentVolume and PersistentVolumeClaim

*The PV is the storage that exists. The PVC is a request for some. They are
deliberately written by different people.*

This split is the point of the design, and it is what the exam tests:

| | PersistentVolume (PV) | PersistentVolumeClaim (PVC) |
|---|---|---|
| Represents | **Actual storage** that exists or can exist | A **request** for storage |
| Scope | **Cluster-scoped** | **Namespaced** |
| Written by | Cluster admin, or a provisioner automatically | The application developer |
| Says | "There is 100Gi of fast disk here" | "I need 10Gi, read-write, of the fast class" |
| Analogue | The available apartments | The rental application |

The Pod never references a PV. It references a **PVC**, by name, and the PVC is
bound to a PV:

```
Pod  ──references──►  PVC  ──bound to──►  PV  ──backed by──►  real disk
     (spec.volumes)      (namespaced)      (cluster-scoped)    (EBS, NFS, local…)
```

The developer therefore never needs to know whether the storage is EBS, NFS or a
directory on the node — which is exactly the abstraction Kubernetes is selling.

### 1.5 How binding works

*Binding is a matchmaker, and it is exclusive and permanent.*

A controller watches for unbound PVCs and looks for a PV that satisfies **all**
of:

| Criterion | Rule |
|---|---|
| **Capacity** | PV capacity **≥** PVC request. A 100Gi PV can satisfy a 10Gi claim — and the extra is wasted |
| **Access mode** | The PV must support the mode the PVC asks for |
| **StorageClass** | `storageClassName` must match, **including both being empty** |
| **volumeMode** | `Filesystem` (default) or `Block` must agree |
| Selector | If the PVC has a `selector`, the PV's labels must match |

Two properties that catch people:

- **Binding is 1:1 and exclusive.** A bound PV serves that one PVC and no other,
  even if 90Gi of a 100Gi volume is unused.
- **Binding is permanent.** A PVC never re-binds to a different PV.

If nothing matches, the PVC stays **`Pending`** — and since a Pod cannot start
without its PVC bound, the Pod stays Pending too. That is the
`pod has unbound immediate PersistentVolumeClaims` row from note 03 §1.12,
finally explained from the storage side.

### 1.6 StorageClass and dynamic provisioning

*Without a StorageClass, someone has to create every PV by hand before it is
needed. With one, the PV is created on demand, at claim time.*

**Static provisioning:** an admin creates PVs in advance; PVCs bind to whatever
already exists. Works, does not scale, and wastes capacity through the ≥ rule.

**Dynamic provisioning:** the PVC names a **StorageClass**, and a provisioner
creates a PV — and the real disk behind it — at that moment, sized exactly to the
request.

```
PVC created  (storageClassName: fast)
      │
      ▼  the StorageClass names a provisioner
StorageClass "fast"  ──►  CSI driver  ──►  creates the real disk (e.g. an EBS volume)
      │
      ▼  a matching PV is created automatically and bound
    PV  ◄──bound──  PVC        →  the Pod can now start
```

| StorageClass field | Means |
|---|---|
| `provisioner` | Which CSI driver creates the volume |
| `parameters` | Driver-specific — disk type, IOPS, encryption |
| `reclaimPolicy` | What happens to the PV when the PVC is deleted. **Defaults to `Delete`** |
| `volumeBindingMode` | When to bind — see §1.7 |
| `allowVolumeExpansion` | Whether a PVC may be grown later. PVC expansion is stable since **v1.24** |

**The default StorageClass** is marked by the annotation
`storageclass.kubernetes.io/is-default-class: "true"`. A PVC that omits
`storageClassName` uses it. **If no default exists, that PVC stays `Pending`
forever** — the single most common storage failure on a hand-built cluster,
because kubeadm installs no StorageClass at all.

### 1.7 `volumeBindingMode` — the zone trap

*Bind the volume too early and you can create it in a place the Pod cannot be
scheduled.*

| Mode | Binds when | Risk |
|---|---|---|
| `Immediate` | As soon as the PVC is created | The volume may land in a zone or on a node where the Pod cannot run — **deadlock** |
| **`WaitForFirstConsumer`** | Only once a **Pod using the PVC is scheduled** | The provisioner knows the node and zone, and creates the volume there |

The failure `Immediate` produces is genuinely circular: the volume is created in
zone A, the volume is zonal so the Pod must run in zone A, but zone A has no
capacity — and the Pod stays Pending forever while the storage sits unused.

`WaitForFirstConsumer` inverts the order: **schedule first, then provision.** On
any cloud where disks are zonal — which includes EBS — this is the correct
setting, and it is why the mode exists.

### 1.8 Access modes

*`ReadWriteOnce` means one node, not one Pod. This is the most-missed fact in the
whole storage domain.*

| Mode | Short | Meaning |
|---|---|---|
| `ReadWriteOnce` | **RWO** | Read-write by **one node**. Several Pods **on that same node** can all use it |
| `ReadOnlyMany` | **ROX** | Read-only, by many nodes |
| `ReadWriteMany` | **RWX** | Read-write, by many nodes |
| `ReadWriteOncePod` | **RWOP** | Read-write by **exactly one Pod**, cluster-wide. Introduced v1.22, **GA v1.29**, CSI only |

RWOP exists precisely because RWO's guarantee was weaker than everyone assumed.
If you need "only one writer, ever" — a database that corrupts under concurrent
writers — RWO does **not** give you that; RWOP does.

**What the storage can actually do is a property of the backend, not the YAML.**
Requesting `ReadWriteMany` from a block device does not make it shareable — the
claim simply will not bind, or the mount will fail. Block storage (EBS, GCE PD)
is RWO/RWOP; shared filesystems (NFS, EFS, CephFS) can do RWX.

### 1.9 Reclaim policy, and the PV lifecycle

*When the claim goes away, does the data go with it? The default answer is yes.*

| Policy | On PVC deletion | Use when |
|---|---|---|
| **`Delete`** | PV **and the real disk** are deleted. Data gone | **The default for dynamic provisioning** |
| **`Retain`** | PV kept, data kept, PV marked `Released` | The data matters more than the tidiness |

PV phases, and the one that surprises people:

| Phase | Meaning |
|---|---|
| `Available` | Free, waiting for a claim |
| `Bound` | Matched to a PVC |
| **`Released`** | The PVC is gone, **the data is still there — and the PV is NOT reusable** |
| `Failed` | Automatic reclamation failed |

**`Released` is not `Available`.** A `Retain` PV whose claim was deleted will
never be picked up by a new PVC automatically, because it still carries a
reference to the old claim. An admin must clear that reference (or recreate the
PV) to make it bindable again. People delete a PVC, recreate it expecting the old
data back, and get a brand-new empty volume instead.

The combination to hold in mind: **dynamic provisioning defaults to `Delete`**,
so on a cloud, `kubectl delete pvc` can destroy a real disk and real data
immediately, with no confirmation.

### 1.10 CSI — the Container Storage Interface

*The same story as CRI and CNI: move the vendor code out of Kubernetes and define
an interface instead.*

Storage drivers used to live **inside the Kubernetes source tree** ("in-tree").
Every driver's bugs were Kubernetes' bugs, every fix waited for a Kubernetes
release, and the project maintained code for hardware it did not own.

**CSI** is a standard interface a storage vendor implements out-of-tree. The
driver ships and updates on its own schedule; Kubernetes calls it through the
interface. In-tree drivers have since been removed in favour of CSI equivalents.

| Interface | Between | Replaced |
|---|---|---|
| **CRI** (note 04 §1.7) | kubelet ↔ container runtime | in-tree runtime support (dockershim) |
| **CNI** (note 05 §1.3) | runtime ↔ network plugin | ad-hoc networking |
| **CSI** | Kubernetes ↔ storage driver | in-tree volume plugins |

Recognising this as one repeated pattern is worth more than memorising three
lists: **the interface is in-tree and stable; the implementation is out-of-tree
and swappable.**

### 1.11 Storage in a StatefulSet

*`volumeClaimTemplates` is a PVC factory: one claim per replica, named after the
Pod, and it outlives the Pod on purpose.*

From note 03 §1.6, this is the third StatefulSet guarantee. A Deployment with a
PVC gives every replica **the same** volume; a StatefulSet gives each replica
**its own**.

```
StatefulSet "db"  +  volumeClaimTemplates: [data]
        │
        ├─ Pod db-0  →  PVC data-db-0  →  PV  →  disk 0
        ├─ Pod db-1  →  PVC data-db-1  →  PV  →  disk 1
        └─ Pod db-2  →  PVC data-db-2  →  PV  →  disk 2
```

The PVC name is `<template-name>-<statefulset-name>-<ordinal>`. Because it is
derived from the **Pod name**, and Pod names are stable (note 03 §1.6), a
replaced `db-1` reclaims exactly `data-db-1`. Identity and storage are the same
mechanism seen twice.

**PVCs are not deleted with the StatefulSet by default.** Since **v1.32**,
`persistentVolumeClaimRetentionPolicy` makes this explicit with two independent
fields — `whenDeleted` and `whenScaled` — and **both default to `Retain`**,
preserving the historical behaviour. Deleting a StatefulSet therefore leaves its
data behind unless you opt in to deletion. This is deliberate: the alternative is
that one `kubectl delete statefulset` destroys a database.

### 1.12 Why a PVC stays `Pending`

*Same diagnostic shape as a Pending Pod: read the events and ask who was supposed
to act.*

| Cause | Tell |
|---|---|
| **No default StorageClass**, and the PVC named none | No provisioning event at all. The kubeadm default state |
| StorageClass named does not exist | `storageclass.storage.k8s.io "x" not found` |
| Static PV: **no PV matches** capacity, access mode or class | No matching PV in `kubectl get pv` |
| Access mode unsupported by the backend | Provisioner error in the events |
| `WaitForFirstConsumer` and **no Pod uses the PVC yet** | `waiting for first consumer to be created` — **not an error** |
| Provisioner/CSI driver not running | No events; the CSI Pods are absent from `kube-system` |

That fifth row matters: a PVC sitting `Pending` with
`waiting for first consumer` is **working correctly** and is waiting for you to
create a Pod. Treating it as a fault sends people down the wrong path.

And the chain upward: a Pending PVC means a Pending Pod, reported as
`pod has unbound immediate PersistentVolumeClaims` — so a storage problem
presents itself as a scheduling problem. Note 03 §1.12 lists the symptom; this
section is the cause.

---

## 2. Objects & Fields That Matter

| Object | Key fields | Default | Gotcha |
|---|---|---|---|
| Pod volume | `spec.volumes[]`, `spec.containers[].volumeMounts[]` | — | Both halves required: declare, then mount |
| `emptyDir` | `spec.volumes[].emptyDir.medium` | disk | `Memory` counts against the Pod memory limit |
| `configMap`/`secret` volume | `.items[]`, `.defaultMode` | all keys, read-only | **`subPath` mounts never auto-update** |
| PVC | `spec.accessModes`, `spec.resources.requests.storage`, `spec.storageClassName` | class = default SC | Omitting the class and having no default = `Pending` forever |
| PV | `spec.capacity`, `spec.accessModes`, `spec.persistentVolumeReclaimPolicy` | — | Cluster-scoped; `Released` ≠ `Available` |
| StorageClass | `provisioner`, `reclaimPolicy`, `volumeBindingMode`, `allowVolumeExpansion` | `Delete`, `Immediate` | `WaitForFirstConsumer` is what you want on zonal disks |
| Default SC | annotation `storageclass.kubernetes.io/is-default-class: "true"` | none on kubeadm | Only one should be default |
| StatefulSet | `volumeClaimTemplates[]`, `persistentVolumeClaimRetentionPolicy` | both fields `Retain` (GA v1.32) | PVCs survive deletion by design |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 2 (CKA, from 11 Sep).*

---

## 4. Hands-On Lab

On the 3-node kubeadm cluster. **Target: 25 minutes.** Your cluster has **no
StorageClass**, which makes steps 1 and 2 the honest experience.

```bash
# 1. Prove there is no default StorageClass                            (3 min)
kubectl get storageclass          # expect: No resources found
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: needy}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Gi}}
EOF
kubectl get pvc needy             # Pending, and it will stay that way
kubectl describe pvc needy | tail -5

# 2. Static provisioning: create the PV by hand, watch it bind         (8 min)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: manual-pv}
spec:
  capacity: {storage: 5Gi}         # 5Gi >= the 1Gi requested — it still binds
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath: {path: /mnt/data}
EOF
kubectl get pv,pvc                # needy goes Pending -> Bound. Note 4Gi is wasted

# 3. emptyDir shares files between containers in one Pod               (7 min)
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: shared}
spec:
  volumes: [{name: scratch, emptyDir: {}}]
  containers:
  - {name: writer, image: busybox:1.36, command: ["sh","-c","echo hola > /data/f; sleep 3600"],
     volumeMounts: [{name: scratch, mountPath: /data}]}
  - {name: reader, image: busybox:1.36, command: ["sh","-c","sleep 3600"],
     volumeMounts: [{name: scratch, mountPath: /data}]}
EOF
kubectl exec shared -c reader -- cat /data/f     # "hola" — written by the OTHER container

# 4. Released is not Available                                         (5 min)
kubectl delete pvc needy
kubectl get pv                    # manual-pv is Released, NOT Available
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: needy2}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 1Gi}}
EOF
kubectl get pvc needy2            # Pending — the Released PV is NOT reused

kubectl delete pvc needy2 --ignore-not-found; kubectl delete pod shared; kubectl delete pv manual-pv
```

---

## 5. Verification

```bash
kubectl get pvc                                    # STATUS must be Bound
kubectl get pv                                     # STATUS, CLAIM, RECLAIM POLICY
kubectl get storageclass                           # is there a default?
kubectl describe pvc <pvc> | grep -A10 Events      # the decisive output
kubectl get pod <p> -o jsonpath='{.spec.volumes}' | python3 -m json.tool
kubectl exec <pod> -- df -h /mount/path            # is it actually mounted?
```

`Bound` is the proof for a PVC. For the Pod, `df -h` inside the container is the
proof — a volume can be declared and never mounted.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| PVC `Pending`, no events | **No default StorageClass** | `kubectl get storageclass` | Install a provisioner, or create a PV by hand |
| PVC `Pending`, `waiting for first consumer` | `WaitForFirstConsumer`, no Pod yet | `kubectl describe pvc` | **Nothing.** Create the Pod |
| PVC `Pending`, `storageclass not found` | Typo in `storageClassName` | `kubectl get sc` | Fix the name |
| Pod `Pending`, `unbound immediate PersistentVolumeClaims` | The PVC is Pending | `kubectl get pvc` | Fix the PVC — the Pod is a symptom |
| PVC bound but the Pod will not start | Volume declared, not mounted; or wrong node for a zonal disk | `kubectl describe pod` | Add the `volumeMount`; use `WaitForFirstConsumer` |
| New PVC will not bind to an old `Retain` PV | PV is **`Released`**, not `Available` | `kubectl get pv` | Clear `spec.claimRef`, or recreate the PV |
| Data gone after deleting a PVC | `reclaimPolicy: Delete` — the default | `kubectl get pv -o wide` (too late) | Use `Retain` for anything that matters |
| Second Pod cannot mount an RWO volume | It is on a **different node** | `kubectl get pods -o wide` | Same node, or a RWX backend |
| ConfigMap changed, the file in the Pod did not | Mounted with **`subPath`** | `kubectl describe pod` | Mount the whole volume, not a subPath |
| Pod OOMKilled after heavy writes to `emptyDir` | `medium: Memory` — it is tmpfs | `kubectl describe pod` | Use disk-backed `emptyDir`, or raise the limit |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| Default StorageClass | `gp2`/`gp3` is there; a PVC binds within seconds and you never think about it | **No StorageClass exists at all.** Every PVC stays `Pending` until you install a provisioner or hand-write PVs |
| Provisioning | The EBS CSI driver creates a real disk on demand | **Nothing provisions anything.** Static PVs, `hostPath` or `local`, created by you |
| Zones | EBS volumes are **zonal** — a volume in `us-east-1a` pins the Pod to `us-east-1a`. `WaitForFirstConsumer` is essential | Single-zone lab, no topology. The whole class of failure is invisible until you meet it on a cloud |
| RWX | EBS **cannot** do it. You need EFS and a second CSI driver | Needs NFS or similar. Not available by default either |
| Deleting a PVC | `reclaimPolicy: Delete` destroys a **real EBS volume and real data**, billed until then | Deletes a PV object; `hostPath` data stays on the node's disk |
| CSI driver | An **add-on you must install** — not present by default in recent EKS versions | You install everything, and there is no "add-on" concept to forget about |

The habit to unlearn: on EKS, `PersistentVolumeClaim` behaves like a magic word
that produces a disk. That behaviour is the EBS CSI driver plus a default
StorageClass — two things AWS installed. Remove them and the PVC does what it
does on your lab cluster: nothing, silently, forever.

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 2.*

---

## 9. Objectives Covered

KCNA area **2.4 Storage** — tick only when explainable without looking.

- [ ] Why the container writable layer is not storage
- [ ] Ephemeral volumes: `emptyDir`, `configMap`, `secret`, `downwardAPI`
- [ ] PersistentVolume vs PersistentVolumeClaim; which is cluster-scoped
- [ ] The binding criteria, and that binding is exclusive and permanent
- [ ] StorageClass and dynamic provisioning; the default-class annotation
- [ ] `volumeBindingMode` and why `WaitForFirstConsumer` exists
- [ ] Access modes RWO, ROX, RWX, RWOP — and that RWO means one **node**
- [ ] Reclaim policy `Retain` vs `Delete`; `Released` ≠ `Available`
- [ ] CSI: why it replaced in-tree drivers
- [ ] `volumeClaimTemplates` in a StatefulSet, and PVC retention

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "`ReadWriteOnce` means one Pod" | **One node.** Many Pods on that node can share it. `ReadWriteOncePod` is the one-Pod mode |
| "A PVC binds to any PV with enough space" | Access mode, StorageClass and volumeMode must match too |
| "A 100Gi PV can serve two 50Gi claims" | Binding is **1:1 and exclusive**. The remainder is wasted |
| "Deleting a PVC always keeps the data" | Dynamic provisioning defaults to **`Delete`** — the disk goes |
| "A `Released` PV is available for the next claim" | It is not. It still references the old claim |
| "`emptyDir` survives the Pod" | It survives **container restarts**, not the Pod |
| "PVs are namespaced" | **PVs are cluster-scoped.** PVCs are namespaced |
| "A Pod mounts a PV directly" | A Pod references a **PVC**. Never a PV |
| "StorageClass is required for a PVC to bind" | Static PVs bind without one — both sides just have to agree |
| "PVC `Pending` is always an error" | `waiting for first consumer` is correct behaviour |
| "Asking for RWX makes the volume shareable" | The **backend** decides. Block storage cannot do RWX |
| "Deleting a StatefulSet deletes its PVCs" | They are **retained** by default, by design |
| "ConfigMap volumes need a Pod restart to update" | They refresh automatically — **unless mounted with `subPath`** |
| "`emptyDir` with `medium: Memory` is free storage" | It is tmpfs and counts against the **memory limit** |
| "CSI is a Kubernetes component" | It is an **interface**; the driver is out-of-tree vendor code |

**X ≠ Y**

- **PV ≠ PVC** — the storage that exists vs the request for it
- **Cluster-scoped ≠ namespaced** — PV vs PVC
- **Ephemeral volume ≠ persistent volume** — dies with the Pod vs outlives it
- **`emptyDir` ≠ persistent** — survives restarts, not rescheduling
- **RWO ≠ RWOP** — one **node** vs one **Pod**
- **`Released` ≠ `Available`** — data kept, but not reusable
- **`Retain` ≠ `Delete`** — keep the disk vs destroy it
- **`Immediate` ≠ `WaitForFirstConsumer`** — bind now vs bind when scheduled
- **Static ≠ dynamic provisioning** — PVs made in advance vs made on demand
- **Volume mount ≠ volume declaration** — `volumeMounts` and `spec.volumes` are both required
- **CSI ≠ CNI ≠ CRI** — storage, networking, runtime; same out-of-tree pattern
- **ConfigMap volume ≠ Secret volume** — plain config vs tmpfs-backed credentials

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. Where does a container write if you mount no volume, and at which of three
   events does that data disappear?
2. Name the four ephemeral volume types and what each contains.
3. Does an `emptyDir` survive a container crash? A Pod rescheduling to another
   node? Explain the difference using its lifetime.
4. Two containers in one Pod need to exchange files. Why can they not just use
   the filesystem, and what do you use instead?
5. Which of PV and PVC is cluster-scoped, which is namespaced, and who writes
   each in a real organisation?
6. List the criteria a PV must satisfy to bind to a PVC.
7. A 100Gi PV and a 10Gi PVC. Do they bind? What happens to the other 90Gi?
8. What does a StorageClass do that static PVs do not, and which annotation
   marks one as default?
9. Your kubeadm cluster has no StorageClass. You create a PVC with no
   `storageClassName`. What happens, and for how long?
10. Explain `WaitForFirstConsumer` and the exact deadlock that `Immediate`
    causes on a cloud with zonal disks.
11. Name the four access modes with their abbreviations. What does RWO actually
    restrict?
12. Which access mode guarantees a single writer cluster-wide, and in which
    version did it reach GA?
13. Name the two reclaim policies, which is the default for dynamic
    provisioning, and what is destroyed in each case.
14. A PV has `Retain`. You delete its PVC, then create an identical one. Do you
    get your data back? Name the phase involved and why it blocks reuse.
15. What is CSI, what did it replace, and which two other interfaces follow the
    same pattern?
16. What does `volumeClaimTemplates` create, how is each PVC named, and why does
    that naming scheme work?
17. You delete a StatefulSet. What happens to its PVCs by default, and which
    field changes that?
18. A Pod is `Pending` with `unbound immediate PersistentVolumeClaims`. Is this a
    scheduling problem? Where do you look, and why is the Pod only a symptom?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — The database that came back empty

A PostgreSQL StatefulSet runs with `volumeClaimTemplates`, one 20Gi PVC per
replica, dynamically provisioned. Cleaning up a test namespace, someone deletes
the StatefulSet and its PVCs. They recreate the StatefulSet from the same YAML.
The Pods start, `db-0` gets the same name and the same PVC name — and the
database is empty.

a. Trace what was destroyed and in what order, from PVC deletion down to the
   real disk. Name the field that decided it.
b. The PVC name is identical. Why did that not bring the data back? What is the
   relationship between a PVC name and the data?
c. Deleting the StatefulSet alone would not have caused this. Explain what
   default behaviour protected them and which specific step defeated it.
d. Name two independent settings that would each have prevented total loss, and
   say what each costs.
e. On the kubeadm lab with a `hostPath` PV, would the outcome have been the
   same? Explain via the reclaim policy and what "delete the volume" means when
   there is no cloud API.
f. Rank by protective value: `reclaimPolicy: Retain`, `whenDeleted: Retain`, and
   volume snapshots. Defend the ordering.

### Drill 2 — Pending, three ways

Three PVCs in one namespace are all `Pending`.

- `alpha` — no events at all
- `beta` — `waiting for first consumer to be created`
- `gamma` — `storageclass.storage.k8s.io "fast-ssd" not found`

a. Diagnose each. Which one is not broken?
b. For `alpha`, name two distinct root causes that both produce zero events, and
   the command that separates them.
c. For `beta`, name the field responsible, and explain what it is protecting
   against — describe the failure it prevents.
d. A Pod mounts `gamma` and is also `Pending`. Which of the two objects do you
   fix, and what does that say about reading Pod events in isolation?
e. Your kubeadm cluster reproduces `alpha` for every PVC ever created. Why —
   and why does the same YAML work first time on EKS? Name the two things AWS
   installed.

### Drill 3 — One volume, two Pods

A 50Gi RWO volume is bound and mounted by `app-0` on node `w1`. A second Pod
`app-1` is created with the same PVC.

a. Under what condition does `app-1` mount successfully? Under what condition
   does it fail? Name the field that decides.
b. `app-1` is `Pending` with a volume-attachment error. What single fact about
   its placement explains it?
c. The team says "RWO means only one Pod, so this is expected". Correct them
   precisely, and name the access mode that would make their statement true.
d. They switch the PVC to `ReadWriteMany` and it still fails. Why did changing
   the YAML not change the behaviour?
e. They now need three replicas each with their own 50Gi. Name the workload
   object and the field, and explain why a Deployment cannot express this.
f. Explain the interaction between RWO and node affinity: how could a Pod become
   permanently unschedulable because of a volume, and which `volumeBindingMode`
   avoids it?

### Drill 4 — Config that will not update

An app reads `/etc/app/config.yaml`, mounted from a ConfigMap. The team edits the
ConfigMap. Nothing changes, even an hour later. A second app in the same
namespace mounts the *same* ConfigMap at `/etc/other/` and picks up the change
within a minute.

a. Name the single difference in how the two Pods mount it, and why one updates
   and the other does not.
b. Give two ways to fix the first app, and say which is a workaround and which
   is a real fix.
c. The same ConfigMap is also consumed as environment variables by a third Pod.
   Does that update? Explain the mechanism difference between env vars and
   mounted files.
d. They move a password from the ConfigMap into a Secret and mount it. Name the
   one storage-level difference in how that volume is backed, and what it
   protects against.
e. Which parts of this belong to note 07 rather than here? State the boundary in
   one sentence — what is a storage question and what is a security question?
