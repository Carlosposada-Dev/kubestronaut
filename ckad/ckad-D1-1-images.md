---
domain: D1 — Application Design and Build
group: 1 — Build the Image
bullets: [1.1]
exams: [CKAD]
index: ckad-D1.md
theory: notes_04
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D1.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D1 · Group 1 — Build the Image (bullet 1.1)

> Index, drill table and scoreboard: **`ckad-D1.md`**. Session: **Mon 16 Nov** (`plan.md §10`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> One sub-session: the image the application runs. The only numeral worked with `podman` instead of `kubectl`.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 1.1 Define, build and modify container images

---

## 1.1 Define, build and modify container images ✍️

**Runs on: the task's host (lab: cp1, podman from `lab/build/ckad-addons.sh`).** ·
**Theory →** notes_04 §1.10, §1.12 · **Docs →** not on kubernetes.io: `podman --help`,
`podman save --help` · **Target: 5:00** · **Reported: R1**

Must contain: reading a Dockerfile and changing one instruction (`FROM`, `RUN`,
`COPY`, `ENV`, `USER`, `CMD` vs `ENTRYPOINT`); build with a name **and tag**; list;
run detached with a name; logs; **save the image** to a tar in the format the task
names; **export a container**; tag and push to the registry the task names.

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
podman build -t NAME:TAG -f DIR/Dockerfile DIR          # the last argument is the build context
podman images | grep NAME                               # 🔍
podman run -d --name CTR NAME:TAG ; podman ps -a ; podman logs CTR
podman save -o /PATH/img.tar NAME:TAG                   # image → tar (add --format oci-archive if OCI is asked)
podman export -o /PATH/ctr.tar CTR                      # container filesystem → tar (same as: export CTR > file)
podman tag NAME:TAG REGISTRY/NAME:TAG ; podman push REGISTRY/NAME:TAG
```

To measure in the guided pass: whether `podman` needs `sudo` on the lab; short image
names (`FROM nginx`) vs fully qualified (`docker.io/library/nginx`); the default
`save` format and what `--format oci-archive` changes; the error for a missing tag;
`docker` accepts the same verbs (the task names the tool).

**The distinction R1 turns on:** `save` ↔ `load` move an **image** (layers + metadata);
`export` ↔ `import` move a **container's flattened filesystem** (no history, no CMD).
The task says which object and which file — the verb follows from that.

⚠️ **EKS:** day to day the image is built by a pipeline and pushed to ECR; the local
build → save → load path never appears.

```
(your runbook here)
```

---

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
