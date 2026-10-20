# Note templates — adapted from the AZ-104 format

> **AMENDMENT 2026-08-14 — read this before the table below.**
> The per-exam mapping ("KCNA/KCSA → A, CKA/CKAD/CKS → B") was written
> assuming one note set per certification. Notes are now organised against
> a **canonical taxonomy of 11 domains shared by all five exams**
> (`plan.md §8.1`). A shared file cannot be two templates, so the rule is:
>
> **A canonical file uses the template of the deepest exam it serves.**
>
> - Files 01–10 → **Template B**, from day one. During the KCNA block fill
>   only §1, §2, §7 and §9; leave §3 *Speed Patterns* and §8 *Timed Drills*
>   empty until the CKA/CKAD block, where they are **added**, not rewritten.
> - File 11 (`cloud-native-architecture.md`) → **Template A**. No
>   performance exam will ever touch it.
> - Template A's §5/§6 (Exam Intelligence, Exam Traps) are genuinely useful
>   for KCNA. In a Template B file used for KCNA, add a temporary
>   `## KCNA — Traps & Distractors` section. Delete it after 29 Aug 2026;
>   anything still true migrates into §6 *Failure Modes*.
>
> The table below is kept because the *reasoning* behind the A/B fork is
> still correct — it just applies per file, not per certification.





---

The AZ-104 format is good and should be kept. But it was designed for a
**multiple-choice** exam, and only two of the five Kubernetes exams are
multiple choice. So it forks into **three** templates — two for notes, one for runbooks.

| File | Template | Why |
|---|---|---|
| `notes/11` — knowledge-only domains | **A — Knowledge** | MCQ. Recognition, keywords, distractors. Nearly identical to the AZ-104 doc |
| `notes/01–10` — the canonical notes | **B — Performance note** | What a thing *is* and how it behaves. Mechanisms, fields, failure modes, EKS deltas. Shared by all five exams |
| `<exam>/<exam>-D<n>*.md` — the operational runbooks | **C — Runbook** *(added 17 Sep)* | What you *do*, on which machine, in what order, under a clock. One per exam domain, never shared |

**B and C are not alternatives, they are layers.** Note 01 explains what etcd
is; `cka-D1-2-lifecycle.md` is how you back it up in five minutes. Template B
files stay one-per-canonical-domain and are tagged with the exams they serve, so
nothing is written twice.

---

# TEMPLATE A — Knowledge notes (KCNA, KCSA)

```markdown
---
exams: [KCNA]
domain: Cloud Native Architecture (12%)
curriculum_version: <date from the CNCF curriculum>
status: draft | reviewed | mastered
---

# <Domain>

## 1. Core Concepts
Prose. Define the thing, then immediately anchor it to something already
known (AWS/EKS equivalent). The AZ-104 doc did this well — keep it.

## 2. Key Components
| Component | Function | When used | Limits / gotchas |
|---|---|---|---|

## 3. Operational Patterns
Decision flows. "Need X? → use Y." Diagrams as ASCII trees.

## 4. Hands-On
Minimal for MCQ exams, but write the 3–5 commands that make the concept
concrete. Recognition is stronger when it was once typed.

## 5. Exam Intelligence
- Keyword → answer mappings
- What the exam asks *directly* vs what it only implies

## 6. Exam Traps
- Classic distractors and why they're wrong
- X ≠ Y confusions

## 7. EKS / AWS Equivalency Map
| Kubernetes concept | EKS behaviour | AWS analogue | Key difference |
|---|---|---|---|

## 8. Objectives Covered
Tick against the official curriculum bullets.

## 9. Practice Questions
5 questions, exam-style, each with an explanation of *why the other
options are wrong* — not just why the right one is right.
```

---

# TEMPLATE B — Performance notes (`notes/01–10`, served to CKA, CKAD, CKS)

What changed and why:

- **§5/§6 replaced.** There are no distractors in a hands-on exam. What
  kills candidates instead is slowness and not verifying their own work.
- **Speed patterns added.** Imperative `kubectl` one-liners with
  `--dry-run=client -o yaml` are the single highest-value thing to drill.
- **Verification added.** Every task must end with a command that proves
  it worked. Marks are awarded on cluster state, not intent.
- **Timed drills replace practice questions.** With a target time.
- **Failure modes added.** CKA's largest domain is troubleshooting (30%).

```markdown
---
exams: [KCNA, CKA, CKAD]
domain: Workloads & Scheduling
kcna_domains: 1.3 Scheduling
curriculum_version: <date from the CNCF curriculum>
template: B
status: draft | drilled | timed-clean
---

# <Domain>

## 1. Core Concepts
Short. Only what's needed to reason during a task. No essays.

## 2. Objects & Fields That Matter
| Object | Key fields | Default | Gotcha |
|---|---|---|---|
Field paths matter more than prose here — `spec.template.spec.nodeSelector`,
not "you can select nodes".

## 3. Speed Patterns  ← the most valuable section
LEAVE EMPTY DURING THE KCNA BLOCK. Filled in Block 2.
The fastest path to a correct object. Imperative first, YAML only when
imperative can't express it.

    # generate, don't type
    kubectl create deploy web --image=nginx --replicas=3 \
      --dry-run=client -o yaml > web.yaml

    # what CANNOT be done imperatively (must hand-edit):
    # - volumes, initContainers, probes, affinity, tolerations

    # docs bookmark for this topic:
    # https://kubernetes.io/docs/...

## 4. Hands-On Lab
A build-it task on the real cluster. Then **break it deliberately** and
fix it — that is what the troubleshooting domain actually tests.

## 5. Verification
    kubectl get ... -o wide
    kubectl describe ... | grep -A5 Events
    kubectl -n <ns> logs <pod> --previous
Never move on from a task without a command that proves the state is right.

## 6. Failure Modes
| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
e.g. Pod Pending → no schedulable node / taint / insufficient resources /
unbound PVC → `kubectl describe pod` Events → ...

## 7. EKS vs Vanilla
| Behaviour | On EKS | On kubeadm (exam) |
|---|---|---|
The highest-value section for this specific background. Every place EKS
does something automatically is a place the exam expects it done by hand.

## 8. Timed Drills
LEAVE EMPTY DURING THE KCNA BLOCK. Filled in Block 2.
| # | Task | Target | Actual | Date |
|---|---|---|---|---|
| 1 | Create a deployment, expose it, scale, verify | 3:00 | | |
Re-run until Actual ≤ Target twice in a row.

## 9. Objectives Covered
Tick against the official curriculum bullets.

## KCNA — Traps & Distractors
TEMPORARY. Delete after 29 Aug 2026; migrate survivors into §6.
| Distractor | Why it's wrong |
|---|---|
**X ≠ Y**
```

**Template B is unchanged by the 17 Sep amendment.** It describes *what a thing
is*; the doing moved out to Template C below. Its §3 *Speed Patterns* and §8
*Timed Drills* stay — but when a runbook already holds the timed version of a
task, §8 points at that runbook's `§7` instead of repeating the numbers.

---

# TEMPLATE C — Runbooks (`<exam>/<exam>-D<n>*.md`) — added 17 Sep 2026

Proven on `cka/cka-D1-2-lifecycle.md` r5, which is the reference implementation.
**Every numeral uses this order, in every exam block. No exceptions.**

| # | Section | Content | Rule |
|---|---|---|---|
| 1 | **The shape** | numbered table `# · what we do · why`, plus an `Exam?` column marking 🎯🔍📚 where useful. **No commands** | The declarative summary. Written first; re-read before every timed run |
| 2 | **The whiteboard** | the mechanism: phases, command blocks with their machine banner, verification, the one analogy or diagram that makes it stick | The only section allowed to be long |
| 3 | **Command card** | the whole procedure in ≤ 10 lines, one verb per line, placeholders instead of values | The only thing open while executing |
| 4 | **Traps** | two columns: **error · cause**. Nothing else | A trap that needs a paragraph is a mechanism — move it to the whiteboard |
| 5 | **EKS** | one short block, or a row per difference | Omit when there is no difference |
| 6 | **Exam mode** | once per file, at the end: tasks worded as the exam words them, with weights, targets and variations | Never inside a numeral |

```markdown
---
domain: D<n> — <name>
exams: [CKA]
theory: notes_NN
index: <exam>-D<n>.md
status: draft | drilled | timed-clean
revision: <date> (r<n> — <what changed>)
---

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: <numeral> · <numeral> · …

## <numeral> <title> ⚙️
**Runs on: <machine>.** · **Theory →** notes_NN §x · **Docs →** search `<term>` · **Target: <m:ss>**

### The shape
| # | What we do | Why | Exam? |

### The whiteboard
<phases, command blocks with ▶▶ banners, verification>

### Command card — <numeral>
<≤ 10 lines, one verb per line>

### Traps
| Error | Cause |

⚠️ EKS: <differences>

## §9. Exam mode — Set <n> · <k> tasks · <m> min
<exam wording, weights, targets, variations>
```

**Two standing rules that keep a runbook from growing:**

- **Discarded approaches are deleted, not documented.** When a shortcut is proven
  wrong, it leaves the file. Its consequence survives as one trap row; the
  evidence lives in `claude/mistakes.md` and the `plan.md` log.
- **Targets and times live in `<exam>-D<n>.md §7`**, never duplicated per numeral
  beyond the one-line header.

**Migration:** applied to each file **the day it is worked**, never in bulk —
`cka-D1.md`, `cka-D1-1-install.md`, `cka-D1-3-access.md`, `cka-D2…D5` — and used
from the first line in `ckad/` and `cks/`.

---

## Practical notes

- **Write in Markdown, not .docx, during the study phase.** It greps, it
  diffs in git, and commands paste into a terminal without smart-quote
  mangling (the AZ-104 doc has curled quotes in the `az` commands — those
  break if pasted). Export to .docx at the end for a polished artifact.
- **Do not duplicate across certifications.** Pods, services and RBAC are
  written once and tagged `exams: [CKA, CKAD, CKS]`. Duplication is the
  main way a 15-week plan runs out of weeks.
- **Pin the curriculum version** in the front matter. CNCF curricula shift,
  CKS most of all.
- Personal notes are **not** usable during the exam — only kubernetes.io
  and a few allowed subdomains are permitted. Their value is entirely in
  the writing and the drilling.
- **KCNA has no fine-grained official bullets** — only 4 domains and 13
  sub-areas. The derived objective checklist lives in `kcna-curriculum.md`.
  CKA/CKAD/CKS *do* publish detailed bullets; tick against those directly.
