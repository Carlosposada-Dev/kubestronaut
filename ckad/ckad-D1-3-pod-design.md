---
domain: D1 — Application Design and Build
group: 3 — Shape the Pod
bullets: [1.3, 1.4]
exams: [CKAD]
index: ckad-D1.md
theory: notes_03, notes_04, notes_06
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D1.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D1 · Group 3 — Shape the Pod (bullets 1.3, 1.4)

> Index, drill table and scoreboard: **`ckad-D1.md`**. Session: **Wed 9 Dec** (`plan.md §10.2`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these two: what goes *inside* one Pod — how many containers share it (1.3) and where its data lives (1.4). The shared `emptyDir` of 1.3 is the first volume of 1.4.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.3 Multi-container Pod design patterns · 1.4 Utilize persistent and ephemeral volumes

---

## 1.3 Multi-container Pod design patterns ✍️

**Runs on: cp1.** · **Theory →** notes_03 §1.4, notes_04 §1.4 · **Docs →** search
`init containers` / `sidecar containers` · **Target: 6:00** · **Reported: R14 (the
init half)**

Must contain: an init container that prepares a file in a shared `emptyDir`; a
sidecar that reads what the main container writes (log tailer); the native sidecar
form (an `initContainers` entry with `restartPolicy: Always`); `-c` on `logs` and
`exec`; reading `Init:0/1`, `Init:Error`, `PodInitializing` in `get pods`.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS run P --image=IMG $do -- sh -c 'CMD' > p.yaml   # one container generated…
vim p.yaml                                              # …volumes + initContainers / second container by hand
k -n NS logs P -c CONTAINER ; k -n NS exec P -c CONTAINER -- ls /SHARED
```

```yaml
spec:
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: init
    image: busybox:1.36
    command: ["sh","-c","echo ok > /work/ready"]
    volumeMounts: [{name: shared, mountPath: /work}]
  containers:
  - name: app
    image: nginx:1.29
    volumeMounts: [{name: shared, mountPath: /work}]
```

A Pod's containers cannot be added or removed in place: existing Pod →
`k get pod P -o yaml > p.yaml`, edit, `k replace --force -f p.yaml`. In a Deployment
the template is editable and rolls.

To measure: `get pods` STATUS through the init phases; the `replace --force` output;
the default container chosen by `logs` without `-c`.

```
(your runbook here)
```

---

## 1.4 Utilize persistent and ephemeral volumes ✍️

**Runs on: cp1.** · **Theory →** notes_06 §1.3–1.5, §1.8, §1.12 · **Docs →** search
`persistent volume pod` → "Configure a Pod to Use a PersistentVolume for Storage" ·
**Target: 7:00** · not in the reported list — still 1 of 4 bullets of a 20% domain

Must contain: `emptyDir` (and `medium: Memory`); a `hostPath` PV + a PVC that binds
to it + a Pod that mounts it; the three fields that must agree for a bind
(`storageClassName`, `accessModes`, capacity ≥ request); `subPath`; a ConfigMap /
Secret as a volume (home: `ckad-D4-1-config.md` 4.4 / 4.5).

**Nothing here is imperative.** No `create pv`, no `create pvc`. The path is the docs
page above: three YAML blocks (PV, PVC, Pod), copy and change the literals — the
drill is finding that page in 20 s.

To measure: a PVC `Pending` because of a `storageClassName` mismatch (the event
text); the lab has no default StorageClass; what `get pv` shows in `CLAIM` once bound.

⚠️ **EKS:** a `gp2`/`gp3` default class provisions the PV for you; here a PVC with no
class binds only to a pre-created PV with no class.

```
(your runbook here)
```

---

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
