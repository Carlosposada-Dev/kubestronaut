---
domain: D1 — Application Design and Build
weight: 20%
exams: [CKAD]
theory: notes_03, notes_04, notes_06
k8s_version: v1.37
status: 'runbooks written and measured (21 Nov) — 0 / 4 bullets drilled'
revision: '2026-11-21 (r3 — §0 execution location and ckad-v137 snapshot; content files rewritten in Template C, measured) · 2026-11-13 (r2 — split into index + 3 content files) · r1 2026-11-13 skeleton'
---

# D1 — Application Design and Build (20%)

> Operational layer. Theory lives in notes_03 (workloads), notes_04 (images) and
> notes_06 (volumes) — **not repeated here**. ✍️ = worked in the lab, then rewritten
> from memory. A bullet closes when done twice in a row under target **without looking**.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
> Per-host setup at 0:00 of every session: `plan.md §13`.
>

**What unites these four.** Everything that is decided *before* the application is
deployed: the image it runs (1.1), the controller that owns it (1.2), how many
containers share its Pod (1.3) and where its data lives (1.4).

> **This file is the index.** It holds what belongs to the whole domain: the
> content map, where every command runs (§0), the drill table and the scoreboard.
> It does not grow.
> The runbooks live in the content files below — **one file = one sub-session**.

## Content map — where every topic lives

| File | Bullets | Covers | Session |
|---|---|---|---|
| **`ckad-D1-1-images.md`** | 1.1 | Define, build and modify container images | Tue 8 Dec |
| **`ckad-D1-2-workloads.md`** | 1.2 | Choose and use the right workload resource | Tue 1 Dec |
| **`ckad-D1-3-pod-design.md`** | 1.3, 1.4 | Multi-container Pod design patterns · Utilize persistent and ephemeral volumes | Wed 9 Dec |

> The content files follow **Template C** (`claude/note-templates.md`): per numeral
> `The shape` (29 Oct format) → `The whiteboard` (outputs measured on `ckad-v137`) →
> `Command card` → `Traps` → `EKS`, and one `§9 Exam mode` per file with encoded
> setups and verified graders. Written in full on 21 Nov, before the reading weeks
> reach them — stage 1 reads the finished runbook, not a skeleton.

---

## §0. Exam environment and execution location

### §0.1 The per-host line — same as CKA (`plan.md §13`)

Every exam SSH host ships `kubectl`, the `k` alias and completion; nothing you export
survives an `exit`. On **every host where you will write YAML**, from memory, 10 s:

```bash
export do="--dry-run=client -o yaml"; printf 'set ts=2 sw=2 et ai\n' > ~/.vimrc
```

Then, per task: **read the host and the namespace in the task header first.**
`kubectl` tasks → `k config use-context <ctx>` if one is given, and `-n <ns>` on every
command (or put it in a variable). The podman task (1.1) → `ssh` to the host it names.

### §0.2 Where every command of this domain runs

| Layer | Prompt (lab) | Runs here in D1 | Exam equivalent |
|---|---|---|---|
| Lab host | `cposada@…` | **multipass only** — restore, start, stop | does not exist |
| **cp1** | `ubuntu@cp1` | **everything**: `kubectl` (1.2–1.4), `podman` (1.1), `curl` to the lab registry | the host the task names (`ssh <host>` from base) |
| w1 / w2 | `ubuntu@w1` | only to *look at* a `hostPath` directory on the node a Pod landed on (1.4), via `ssh w1` from cp1 | `exit` to base, then `ssh <node>` |

The host runs `multipass` and nothing else. Every command block in the D1 files carries
a `▶▶` banner; a block without one is a defect — report it, do not run it.

```
# ▶▶ HOST — the lab host (runs multipass only)
# ▶▶ cp1  — ubuntu@cp1
# ▶▶ w1   — ubuntu@w1   (from cp1: ssh w1)
```

**podman is rootless and per user** (1.1, measured): `sudo podman images` sees none of
your images. Never mix `sudo` and non-`sudo` in one task.

### §0.3 🧪 Snapshot — `ckad-v137` for every CKAD drill (`plan.md §8.1`)

`ckad-v137` = `lab-v137` + podman on cp1 + ingress-nginx (IngressClass `nginx`, NodePort
30080) + metrics-server. Built by `SNAPSHOT=yes lab/build/ckad-addons.sh`.

```bash
# ▶▶ HOST 🧪 — restore (all three, stopped, together)
multipass stop cp1 w1 w2
for n in cp1 w1 w2; do multipass restore $n.ckad-v137 --destructive; done
multipass start cp1 w1 w2
```

Wait ~90 s for every Pod to be `Running`, ~60 s more for `kubectl top`. Discard the first
`get nodes`. **Never run the CKA Helm drill H1 on `ckad-v137`** (it installs a second
metrics-server). Restore time never counts in a drill. Each drill uses its own namespace
and deletes it at the end, so a restore is needed only after a break/fix.

---

## §7. Drill table

Each row is a task of the file's `§9 Exam mode` (setup + verified grader there). Targets
are first estimates from the 21 Nov measurements — no human run has timed them yet.
A row closes at **Actual ≤ Target twice in a row, without looking.**

| # | Task | Bullet | §9 | Target | A1 | A2 | A3 | ✅ |
|---|---|---|---|---|---|---|---|---|
| 1 | Build an image with podman, run it, logs to a file, save it as OCI archive (R1) | 1.1 | -1 T1 | 5:00 | | | | |
| 2 | Modify the Dockerfile (`ENV`, `USER`), build a new tag, export a container's filesystem | 1.1 | -1 T2 | 5:00 | | | | |
| 3 | Tag and push an image to a plain-HTTP registry | 1.1 | -1 T3 | 2:00 | | | | |
| 4 | CronJob `*/30` with completions, parallelism, backoff, deadline; run it once by hand (R3) | 1.2 | -2 T1 | 6:00 | | | | |
| 5 | Job from an existing CronJob + logs to a file (R5) | 1.2 | -2 T2 | 2:00 | | | | |
| 6 | DaemonSet from a Deployment manifest, on every node including the control plane | 1.2 | -2 T3 | 4:00 | | | | |
| 7 | Headless Service + StatefulSet, `pod-0.<svc>` resolves | 1.2 | -2 T4 | 5:00 | | | | |
| 8 | Init container writes into a shared `emptyDir` + `exec` readiness probe (R14) | 1.3 | -3 T1 | 6:00 | | | | |
| 9 | Native sidecar added to an existing Deployment | 1.3 | -3 T2 | 7:00 | | | | |
| 10 | PV + PVC + Pod, data written and read back | 1.4 | -3 T3 | 8:00 | | | | |
| 11 | `emptyDir` with `medium: Memory` and `sizeLimit` | 1.4 | -3 T4 | 3:00 | | | | |

## §8. Objectives scoreboard — D1

| Bullet | Performed from memory, timed, verified |
|---|---|
| 1.1 Container images | ☐ |
| 1.2 Workload resources | ☐ |
| 1.3 Multi-container patterns | ☐ |
| 1.4 Volumes | ☐ |
| **Total** | **0 / 4** |
