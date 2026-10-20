---
name: depth-standard
description: Required depth and section structure for every canonical note. Read before writing any note.
---

# Note depth standard (set 2026-08-23)

The learner reviewed note 01 v1 and judged it **too shallow**. The bar below is
what v2 established and what every subsequent note must meet. Superficial notes
are a defect, not a style choice.

## Required sections, in addition to Template B

Every note ends with **three** sections, not one:

| Section | Content |
|---|---|
| `## KCNA — Traps & Distractors` | Distractor table + an `X ≠ Y` list. Temporary; deleted after the exam. |
| `## 10. Active Recall` | 20–36 closed-book questions. The memorisation engine. |
| `## 11. Scenario Drills` | **NEW, mandatory.** 5–6 integrated multi-part problems. |

## What §11 Scenario Drills must be

Not recall questions. Each drill is a **situation** that forces several concepts
from the note (and earlier notes) to be combined, with sub-questions a–g that
walk the full causal chain. The learner asked for these explicitly:

> "crear escenarios en donde se mezclen todos los conceptos y tenga que dar una
> solución… ese es el tipo de razonamiento al que quiero llegar."

Good drill shapes:
- A timed failure with clock times, asking *at what second* each thing happens
- A partial outage where the learner must **infer which component is broken**
  from what still works
- A trace: "follow this request end to end, name every component, say whether
  each reads or writes"
- A "you are locked out / it stopped after a year" recovery problem

Never give the answers inline. The drill is worthless once it is a worked example.

## Depth rules for §1 Core Concepts

- **Explain the mechanism, not the job title.** "The controller-manager runs
  controllers" is a failure. Name the process model, the loop steps, what it
  writes and to whom.
- **Every component gets an "if it dies" paragraph.** Blast radius is what the
  exam actually tests.
- **Ownership chains explicitly**: Deployment→ReplicaSet→Pod, CronJob→Job→Pod,
  Service+Pods→EndpointSlice.
- **Timelines get a diagram with real default values and the flag that sets each.**

## Depth rules for §2 Objects & Fields

- **Show real file contents, not paths.** A table of paths teaches nothing; an
  annotated YAML of what is inside each one teaches the concept. Where several
  files look alike, state plainly what *kind* of document each is
  (kubeconfig vs KubeletConfiguration vs Pod manifest).
- Annotate YAML with inline comments that answer *why this field exists*.

## Version accuracy is mandatory

Kubernetes defaults move. Before writing any number, verify it against current
docs or the CHANGELOG, and **state the version it changed in**. Facts already
caught drifting:

- `--node-monitor-grace-period`: 40s → **50s in v1.32**
- `--pod-eviction-timeout`: deprecated v1.26, **removed v1.27**
- kubeadm `admin.conf`: `system:masters` → **`kubeadm:cluster-admins` in v1.29**;
  `super-admin.conf` now holds `system:masters`
- Taint-based eviction: split into **`taint-eviction-controller` in v1.29**
- `kubelet.conf`: references a rotating `.pem`, does not embed cert data
- Ports 10251/10252: removed

Record the docs version checked against in the front matter
(`k8s_version_checked_against:`).

---

# AMENDMENT 2026-08-23 — scope tagging is mandatory

## The failure this fixes

Notes 01 and 02 were written to CKA depth with no marking of which parts serve
which exam. The learner reported them as "muy denso" and was right: he was
reading ~1700 lines, of which roughly **45% is KCNA scope**, nine days before an
entry-level 60-question multiple-choice exam.

Measured facts that set the ceiling:

- KCNA is **60 questions / 90 minutes / >75% to pass**, and CNCF describes it as
  *"not a production-focused exam"*, pre-professional level.
- Kubernetes Fundamentals is 44% → **~26 questions**, split across four
  sub-areas → **~6–7 questions per note** for notes 01–04.
- Notes 01 + 02 together are worth **~13 of 60 questions**.

Depth is still correct — the learner explicitly rejected the shallow v1, and the
canonical taxonomy exists precisely so a note is written once and deepened. What
was missing is the **signal**.

## The rule

**Every note opens with a `## ⚡ Reading map` immediately after the H1**, before
any content. It must contain:

1. One line stating how many exam questions this note is worth for the exam
   currently being studied.
2. A table with one row per section and a column per exam, marked:
   - ✅ **core** — read closely now
   - ✅ read — read once
   - ⚠️ partial / skim — read the named part only; the row says which
   - ❌ **skip now** — zero value for the current exam; prepay for a later one
3. A one-line **"path"**: the ordered list of sections to read for the current
   exam, plus a realistic time estimate.
4. Which §10 recall questions and which §11 scenarios are in scope now.
5. A closing line stating that ❌ material is not wasted and naming the date it
   becomes relevant.

When a later block starts (CKA on 3 Sep), the reading map is **updated, not
deleted** — the column for the new exam becomes the active one.

## Consequence for the remaining KCNA notes (03–11)

Write **KCNA-first**. The core sections come first, stay tight and complete;
CKA/CKAD/CKS depth goes into clearly fenced sections that the reading map marks
❌ for KCNA. Nine notes remain and nine study days remain — a 900-line note per
day does not fit and will not be read.

Target for notes 03–11 during Block 1: **400–550 lines**, of which the KCNA path
is **readable in 45–60 minutes**. Depth that does not fit goes in as a stub with
a `<!-- CKA: expand in Block 2 -->` marker rather than being written now.

## Scope banners go INLINE, under every heading — not only in the reading map

A reading map at the top of a 1000-line file is useless while you are reading
line 600. The learner's words: *"me confundo y es tedioso tener que volver al
principio… se vuelve un infierno en un documento tan largo."*

So **every `##` and `###` heading is immediately followed by a one-line
blockquote banner**, before any content:

```markdown
### 1.6 kube-controller-manager — the deep version

> 🟡 **KCNA · PARTIAL** — read the definition, the four loop steps and the
> ownership chains box. **Skip the 15-row controller table.**
```

The five banner types:

| Banner | Meaning |
|---|---|
| 🟢 **KCNA · READ CLOSELY** | Core exam material |
| 🟢 **KCNA · READ ONCE** | In scope, but one pass is enough — say what to take from it |
| 🟡 **KCNA · PARTIAL** | Read the named part only — **name it explicitly** |
| 🟡 **KCNA · SKIM** | Reduce to the one or two sentences that are in scope |
| 🔴 **KCNA · SKIP FOR NOW** | Zero value for this exam. **Always say when it becomes relevant.** |
| ⚪ **NOT AN EXAM SECTION** | Trackers, learner-owned sections, empty placeholders |

Rules:

- 🟡 and 🔴 banners must be **specific**. "Partial" alone is useless; "read the
  definition and the ownership chains, skip the 15-row table" is actionable.
- 🔴 must always name the date or block where the material becomes live, so it
  reads as deferred rather than wasted.
- §10 and §11 banners list **the exact question and scenario numbers** in scope.
- The reading map at the top stays as an index and time estimate, but the inline
  banners are what the learner actually uses.
- When a block changes (CKA on 3 Sep), banners are **rewritten** for the new
  exam, not deleted. `KCNA · SKIP FOR NOW` becomes `CKA · READ CLOSELY`.

Write banners **as the note is written**, not as a retrofit pass.

---

# AMENDMENT 2026-08-23 (2) — one exam per note version. Banners are retired.

## Decision

Notes 03–11 are written **for KCNA only**. No CKA material, no CKAD material,
no scope banners, no reading map. Everything in the file is in scope; if it is
written, it is read.

When Block 2 (CKA) starts on 3 Sep, each note is **reopened and extended** with
the CKA layer — new sections added, existing ones deepened. Same file, same
canonical domain, no duplication. That is exactly what `plan.md §8.1` always
intended: *written once, deepened, never rewritten.*

## Why this replaces the banner system

Banners were a patch on the wrong shape. The learner's objection is correct and
decisive:

> *"quiero que solo se cree lo relevante para kcna… para no tener que estar
> mirando una tabla y decir que debo leer y que no."*

Making the reader arbitrate scope on every section is work the note should have
done. A note whose job is to be studied under time pressure must be **entirely
studiable**. Mixed-scope notes moved that cost onto the reader, and did it while
he had nine days and nine notes left.

Notes 01 and 02 keep their banners — the CKA material in them is already written
and verified, and stripping it would destroy work. They are the exception, not
the pattern.

## What a KCNA-only note looks like

- **Length: 250–400 lines.** If it is longer, it contains CKA material.
- **No reading map, no banners.** Read it top to bottom.
- Sections that exist only for performance exams — §3 Speed Patterns,
  §8 Timed Drills — stay as one-line placeholders.
- §4 Hands-On Lab and §5 Verification stay **short**: 3–5 commands that make the
  concept concrete, marked as deferred until the cluster exists (30 Aug).
- §7 EKS vs Vanilla stays — 4–6 rows. It is the learner's declared blind spot and
  costs little.
- §10 Active Recall: **15–20 questions**, all in scope. Not 36.
- §11 Scenario Drills: **3–4 scenarios**, all answerable from this note plus
  earlier KCNA notes. Not 6.

## The depth test

Depth is still required — the shallow v1 of note 01 was correctly rejected.
The test is not *how much* but *whether the mechanism is explained*:

- ✅ "The scheduler writes `spec.nodeName`; the kubelet is watching and starts
  the Pod" — mechanism, one sentence, KCNA scope.
- ❌ "The scheduler assigns Pods to nodes" — a job title, explains nothing.
- ❌ A table of the 52 controller names, `--node-monitor-grace-period` defaults,
  or the contents of `/etc/kubernetes/pki/` — correct, but CKA.

**Ask of every paragraph: could this appear as one of 60 multiple-choice
questions on a pre-professional exam?** If not, it waits for September.

## Carry-forward for Block 2

When extending a note for CKA, append rather than restructure, and record the
date in front matter (`revised:`). The KCNA layer is what the learner already
knows; the new material must read as an addition to it, not a replacement.

---

# AMENDMENT 2026-09-01 — reading time replaces line count; sections open in plain language

## What this amendment changes

Two rules from the 2026-08-23 (2) amendment are **superseded**:

| Old rule | Replaced by |
|---|---|
| "Length: 250–400 lines. If it is longer, it contains CKA material." | **Reading time: 45–60 minutes**, matching the slot in `plan.md §7`. Line count is not a target. |
| (no rule on how a section opens) | **Every `###` section opens with one italic plain-language line** before any mechanism. |

Everything else in this file stands: the depth test, Template B structure,
the KCNA-only scope policy, version accuracy, and the ban on inline drill
answers.

## Why the line limit was wrong

It was set to stop notes being unreadable. It measured the wrong thing.

Evidence from Block 1:

| Note | Lines | Outcome |
|---|---|---|
| 03 Workloads & Scheduling | 616 | Read fully, recall 14/18 solid, mechanism understood |
| 04 Containers & Runtimes | 640 | Read fully, no complaint about density |
| (an earlier note, different chat) | 970 | Reported as too dense and tiring to read |

If 400 were the right ceiling, notes 03 and 04 would both have failed. They
did not. Something other than size separated the 970-line note from the
640-line one.

The mechanical problem: **line count punishes the format that works best.**
A ten-row comparison table costs twelve lines and reads in forty seconds.
The same content as prose costs six lines and takes three minutes. Counting
lines therefore pushes notes toward the slower format. Tables and ASCII
diagrams were explicitly requested by the learner as easier to memorise and
to relate concepts across — the metric was fighting the request.

**Operational consequence:** expect **~500–700 lines** for a table-heavy note.
That is a description of what 45–60 minutes looks like, **not a new limit**.
Never pad to reach it, and never drop a curriculum bullet to stay under it.
If a note genuinely cannot be read in an hour, the fix is to cut material
that fails the "could this be one of 60 MCQs?" test — not to compress the
material that passes it.

## Why sections must open in plain language

The 1 Sep session was the evidence. Reading note 03, the learner stopped and
asked for a simpler explanation at §1.4, §1.5, §1.9, §1.10 and §1.13 — five
of thirteen sections. In every case the chat explanation that unblocked him
was **not shorter than the note**. It opened with one plain sentence and then
gave the same mechanism the note already had.

So the failure was **ordering**, not volume. The notes opened with the
mechanism and left intuition to be reconstructed by the reader. Under exam
pressure that reconstruction does not happen.

### The rule

Every `###` section opens with **one italic line** in plain language, before
any mechanism, field name or default.

```markdown
### 1.7 Tolerations

*A toleration is a VIP list at a bar: it lets you in if you go there,
it does not take you there.*

A taint is `key=value:effect`... [mechanism continues at full depth]
```

Constraints on that line:

- **One line.** Never a paragraph. It is a doorway, not a summary.
- **Concrete over abstract.** No "essentially", "basically", "in a nutshell".
- **An honest restatement beats a forced analogy.** Not every concept has a
  good metaphor. `parallelism` does not need one — *"how many Pods run at once
  inside ONE Job, not how many Jobs run at once"* is plain enough and true.
  A bad analogy teaches a wrong model and costs more than it saves.

This **adds a doorway; it does not lower the ceiling.** The depth test above
still applies to everything after that line.

## Tables and ASCII diagrams

**Tables are the default** for comparisons, defaults, field references,
symptom → cause → fix, and any X vs Y. Whenever three or more things are
compared on the same axes, a table beats a paragraph.

**ASCII diagrams are narrow-purpose.** Use only for:

- sequence chains — `kubelet → containerd → containerd-shim → runc`
- ownership hierarchies — `Deployment → ReplicaSet → Pod`
- decision trees choosing between related objects

Never for a single isolated concept. If the diagram does not show a
**relationship between several things**, it is decoration: it costs a dozen
lines and teaches nothing. Use a table or prose instead.

## Scope of this amendment

**Applies to notes 05–11.** Notes 01–04 are **not** rewritten. Notes 01 and
02 keep their banners as already documented; notes 03 and 04 keep their
current format. All four have been read and worked through in chat, which is
where the material actually fixed — reformatting them would spend days from a
block that has none, for content that is already learned.

The generation prompt that encodes all of this lives in
`claude/note-prompt-template.md`.
