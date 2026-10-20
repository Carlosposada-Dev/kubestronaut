---
name: note-prompt-template
description: The opening prompt to paste at the start of every note-writing chat. Supersedes the shorter prompt in claude/session-protocol.md.
created: 2026-09-01
applies_to: notes 05–11 (KCNA block). Notes 01–04 keep their existing format and are NOT rewritten.
---

# Note generation prompt — KCNA notes 05–11

## How to use

Paste the block below at the start of each new note chat, changing only the
two values on the `Today is` / `Today's note is` line. Nothing else is edited.

The rules encoded here came from a working session on 2026-09-01, after
reading notes 03 and 04. Three findings drove them:

1. **Length was never the real problem.** Notes 03 (616 lines) and 04 (640)
   read fine; a 970-line note did not. What separated them was not size.
2. **The blocker was the opening sentence of each section.** Sections that
   opened with the mechanism required a chat question to unblock; the same
   content opened with one plain sentence did not.
3. **Tables and ASCII cost lines but save reading time.** Counting lines
   punishes exactly the format that works best.

---

## The prompt

```
Read plan.md, claude/mistakes.md, claude/session-protocol.md,
claude/depth-standard.md and claude/sources.md.

Today is <DATE>. Today's note is <NN-name>.

=== SCOPE ===
KCNA-ONLY. No CKA/CKAD/CKS material, no reading map, no scope banners.
Everything in the file is in scope; read top to bottom.
Cover the KCNA curriculum sub-area for this note as listed in
claude/kcna-curriculum.md. Source discipline per claude/sources.md.

=== LENGTH — THIS REPLACES THE 250-400 LINE RULE ===
The limit is READING TIME, not line count: the note must be readable in
45-60 minutes, matching the slot in plan.md §7. Tables and ASCII read
fast and cost lines; prose reads slow and saves lines. Optimise for the
clock, not the line counter. Expect ~500-700 lines when table-heavy.
Never pad, never cut a curriculum bullet to hit a number.

=== EXPLANATION STYLE — THE MAIN CHANGE ===
Every ### section opens with ONE italic line in plain language, before
any mechanism. Analogy or plain restatement. Then the mechanism.

  ### 1.7 Tolerations
  *A toleration is a VIP list at a bar: it lets you in if you go there,
  it does not take you there.*
  [then the mechanism, fields, defaults]

Rules for that line:
- One line. Never a paragraph.
- Concrete over abstract. No "essentially" or "basically".
- If the concept has no honest analogy, restate it plainly instead of
  inventing a bad one. A forced analogy is worse than none.

The rest of the section stays at full mechanism depth — the depth test in
claude/depth-standard.md still applies. This adds a doorway, it does not
lower the ceiling.

=== TABLES ===
Default format for: comparisons, defaults, field references, symptom ->
cause -> fix, X vs Y. Prefer a table over a paragraph whenever three or
more things are being compared on the same axes.

=== ASCII DIAGRAMS ===
Use ONLY for:
- sequence chains (kubelet -> containerd -> shim -> runc)
- ownership hierarchies (Deployment -> ReplicaSet -> Pod)
- decision trees choosing between related objects
Never for a single isolated concept. If it does not show a RELATIONSHIP
between several things, use a table or prose instead.

=== STRUCTURE ===
Template B per note-templates.md. §3 Speed Patterns and §8 Timed Drills
stay as one-line placeholders. §7 EKS vs Vanilla: 4-6 rows.
§10 Active Recall: 15-20 questions. §11 Scenario Drills: 3-4.
Never write drill answers inline.
Close explicitly any open item in claude/mistakes.md that belongs to
this note's domain.

=== PRE-DELIVERY CHECKS — run these before attaching the file ===
1. CROSS-REFERENCES. Extract every `note NN §X.Y` and verify §X.Y exists as a
   real heading in that note's file. Never cite a section number from memory.
   Also sanity-check that the target section is about the right TOPIC — a
   number that exists but points at the wrong subject is a worse error,
   because no automated check catches it.
2. LAB COMMANDS. For each command, state what output it produces and confirm
   the comment matches. Specifically:
   - `--restart=Never` produces `State:`, NOT `Last State:` (no prior run).
     Use `--restart=Always` when the point is a restart or a backoff.
   - An EndpointSlice LISTS not-ready Pods with `conditions.ready: false`.
     It is not empty. Only a selector mismatch produces an empty slice.
3. DRILL ARITHMETIC. Any drill that states numbers — replica counts, Pod
   totals, percentages, timings — must be COMPUTED, not composed. Work the
   scenario forward step by step and confirm the stated state is reachable.
   A drill premise that cannot exist costs the learner more time than a
   missing drill, because they will assume their own arithmetic is wrong.
   Watch rounding: maxSurge rounds UP, maxUnavailable rounds DOWN.
4. CURRICULUM PHRASING. Re-read the sub-area bullets in
   claude/kcna-curriculum.md and confirm each is answerable from the note
   USING THE CURRICULUM'S OWN WORDING, not just in substance. KCNA asks in
   its own vocabulary.

=== DELIVERY ===
Filename MUST start with notes_ : notes_NN-name.md
Deliver as a file attachment.
State plainly if you cannot write to the project, so I upload it myself.
Then give me the session breakdown, and tell me bluntly if I am behind.
```

---

## Worked example of the opening line

The test is whether the line would have prevented a real question asked
during the 1 Sep session. All five below did come up as blockers.

| Section | Opening line that would have unblocked it |
|---|---|
| Toleration | *A VIP list at a bar: it lets you in if you go, it does not take you there.* |
| Headless Service | *A normal Service gives one shared IP; a headless one gives a DNS name per Pod, so you can call `web-0` specifically.* |
| `parallelism` | *How many Pods run at once inside ONE Job — not how many Jobs run at once.* |
| Mirror Pod | *A photo of the real container, published so `kubectl` can see it. Deleting the photo does not touch the container.* |
| `nodeSelectorTerms` | *Between the dashes it is OR; inside one dash it is AND.* |

## Why the pre-delivery checks exist

Added 2026-09-05, after review of notes 05–09 found four defect classes that a
careful read of the note alone would not have caught:

| Defect | Found | Root cause |
|---|---|---|
| **7 broken cross-references** across notes 07, 08 and 09, all citing `note 03 §1.14`/`§1.15` | By the learner, then a script found 5 more | Note 03 was compressed after drafting; §1.16 and §1.17 merged into **§1.11**. The generator kept the pre-compression numbering |
| Semantically wrong reference — `note 03 §1.5` cited for the ownership chain, but §1.5 is DaemonSet | By the learner | **A script cannot catch this.** The number exists; it points at the wrong topic |
| Lab command whose output could not match its comment (`--restart=Never` + `Last State:`) | By the learner | Command written from the concept, never mentally executed |
| A factual imprecision repeated across two notes (EndpointSlice "empty" when not-ready) | By the learner | The simplification was made once and propagated |
| **A drill premise that was arithmetically impossible** — 6 Pods stated for a `replicas: 4` Deployment whose ceiling is 5 | By the learner | Numbers were composed to look plausible instead of being computed. **No script catches this class** |

The lesson generalises: **the errors that survive review are the ones where the
prose is fluent and only the detail is wrong.** Fluency is not evidence of
accuracy, and a cross-reference is the cheapest thing in a note to get wrong and
the most expensive to discover mid-exam.

## What this prompt does NOT change

- The depth test. Mechanism, not job titles. Shallow notes are still a defect.
- Template B section structure.
- The canonical taxonomy: one file per domain, never per certification.
- Source discipline in `claude/sources.md`, including the blacklist.
- The end-of-session ritual in `claude/session-protocol.md`.
