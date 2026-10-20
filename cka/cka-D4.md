---
domain: D4 — Storage
weight: 10%
exams: [CKA, CKAD]
theory: notes_06
k8s_version: v1.35
status: draft | drilled | timed-clean
window: W2 — Fri 25, Sat 26 Sep
---

# D4 — Storage (10%)

> Operational layer. Theory in notes_06 (recalled 78%; its **7** queued
> amendments are applied Sat 26 Sep — the biggest queue of any note).
> ⚙️ pre-written · ✍️ you write it. §0 drill: `cka-D1.md` §0.

**Smallest domain, and almost none of it is imperative.** There is no
`kubectl create pv`, no `create pvc`, no `create storageclass`. The fast path
here is *the docs example, edited* — so what you drill is finding the page and
knowing which four fields to change.

---

## 4.1 StorageClasses and dynamic provisioning ✍️

**Theory →** notes_06 §3.x · **Docs →** search `storage classes` ·
**Target: 5 min**

Must contain: the four fields that matter (`provisioner`, `parameters`,
`reclaimPolicy`, `volumeBindingMode`), how to mark a class default and how to
**un**-mark the previous one, and what happens to a PVC that names no class.

The annotation is a literal you will get wrong under pressure — write it out:
`storageclass.kubernetes.io/is-default-class: "true"` (the value is a **quoted
string**).

`volumeBindingMode`: `Immediate` binds as soon as the PVC exists;
`WaitForFirstConsumer` waits for a Pod to be scheduled, so the volume lands in
the right zone/node. The second is the answer whenever topology matters.

**Trap from your amendment queue:** "no default class" and "the CSI driver is
absent" produce a PVC stuck in `Pending` that looks identical. The events tell
them apart — `kubectl describe pvc` is the diagnostic, always.

⚠️ **EKS:** EBS CSI driver, `gp3`, zone-bound volumes (an EBS volume cannot cross
an AZ — that is why `WaitForFirstConsumer` is the norm there). On your kubeadm
cluster there is **no** dynamic provisioner unless you install one; static PVs
are the default reality.

```
(your runbook here)
```

---

## 4.2 Volume types, access modes and reclaim policies ✍️

**Theory →** notes_06 §1.x, §2.x · **Docs →** search `persistent volumes` ·
**Target: 5 min**

Must contain: `emptyDir` / `hostPath` / `nfs` / CSI and when each is correct;
the four access modes with what each actually permits; and the three reclaim
policies with what happens to the **data** in each.

Literals to get exactly right — RWO, ROX, RWX, **RWOP**
(`ReadWriteOncePod`, single Pod, not single node). Reclaim: `Retain`, `Delete`,
and `Recycle` which is deprecated and still shows up as a distractor.

**Amendments landing here:**
- Define `hostPath` properly: a directory **on the node**, so a Pod that lands on
  another node sees different data. Never a real multi-node solution.
- **RWO permits concurrent mounts by several Pods on the *same node*** — the
  restriction is per node, not per Pod. `RWOP` is the one that means one Pod.

```
(your runbook here)
```

---

## 4.3 Manage persistent volumes and claims ✍️

**Theory →** notes_06 §2.x · **Docs →** search `configure persistent volume
storage` · **Target: 6 min**

Must contain: a static PV + a PVC that binds to it + a Pod that mounts it, the
binding rules (capacity, access mode, class, selector), and the two-place mount
pattern people get wrong — `spec.volumes[]` names the claim,
`containers[].volumeMounts[]` names the volume and the path. Both, or nothing
mounts.

**Amendments landing here:**
- **Empty matches empty**: a PVC with no `storageClassName` binds to a PV with no
  `storageClassName`. `""` and *absent* are not the same thing.
- `volumeClaimTemplates` in a StatefulSet creates **one PVC per replica** —
  count the PVCs before answering "how many volumes".
- Deleting a StatefulSet does **not** delete its PVCs.

**Verification, every time:** `kubectl get pv,pvc` → `Bound` on both sides, then
write a file from inside the Pod and read it back after deleting the Pod. Bound
is not proof; surviving a Pod delete is.

```
(your runbook here)
```

---

## §7. Drill table

| # | Task | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|
| 1 | StorageClass + mark default + un-mark the old one | 5:00 | | | | | |
| 2 | Static PV + PVC + Pod, mounted and written to | 6:00 | | | | | |
| 3 | Diagnose a Pending PVC (3 causes, from events only) | 4:00 | | | | | |
| 4 | Change a PV's reclaim policy on a live cluster | 3:00 | | | | | |
| 5 | StatefulSet with volumeClaimTemplates, count the PVCs | 5:00 | | | | | |
| 6 | Prove data survives a Pod delete, dies with emptyDir | 4:00 | | | | | |

## §8. Objectives scoreboard — D4

| Bullet | Performed from memory, timed, verified |
|---|---|
| 4.1 StorageClasses & dynamic provisioning | ☐ |
| 4.2 Volume types, access modes, reclaim | ☐ |
| 4.3 PV & PVC management | ☐ |
| **Total** | **0 / 3** |
