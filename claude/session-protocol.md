# session-protocol.md — How study sessions run

> Read this at the start of every study session.
> **Revision r3, 2026-10-19.** Moved from the claude.ai Project to Claude Code: the
> coach edits files in place and commits. Teach-first rewritten as **five stages**
> (§3). **No check questions while learning** — they slowed phase T down; testing
> moves to stages 4–5.
> Previous: 2026-09-16 (r2, teach-first) · 2026-08-23 (r1, KCNA only).

---

## 1. Sessions and continuity

- One Claude Code session per study block, opened in this repo. Name it after the
  domain: `CKA D1 — Cluster Architecture`.
- **Continuity lives in the files, never in chat history.** A new session must be
  able to resume from `plan.md §15`, `claude/mistakes.md` and the runbook alone.
- `D` is always the **domain number**, never the day.

---

## 2. Why the method exists — 16 Sep

The first CKA etcd session issued ten numbered tasks, forty commands and a blind
break at once. The learner — KCNA-level theory, little console practice — reported
executing blind: *"voy como aplicando ciego"*. Nothing was executed, and the
understanding came later, one step at a time, from bed on a phone.

**Conclusion:** for material that is new at the console, **understanding comes
before execution, and the command list comes last.** A timed drill of something not
understood measures nerves, not skill.

**19 Oct addendum:** a check question at the end of every teaching message broke
the flow and slowed learning. Learning and testing are now separate stages.

---

## 3. The five stages — CKA · CKAD · CKS

Never skip one, never merge two. The learner moves the session forward with
**`sigue`**; the coach never moves on alone.

### Stage 1 — Walkthrough (no terminal; a phone is fine)

The runbook section explained **literally, top to bottom**: what each part of the
document says and why it is there. The learner should finish knowing the whole map
before any detail. One message per numeral (`## 1.1 …`) if the section is long.

### Stage 2 — Shape

The `### The shape` table in words: what we do, why, in what order, and which steps
are 🎯 exam path vs 🔍 verification vs 📚 study only. **No commands.** An analogy if
it helps.

### Stage 3 — Whiteboard

**One step per message.** For each step:

- the **idea** in plain words;
- **every command, piece by piece** — flags in a table, every pipe, every `sudo`
  justified;
- the **verification** and what its output should look like;
- the **machine** it runs on (banner, `plan.md §8.2`);
- the **EKS delta**, if any;
- where it lives: kubernetes.io **search term** + **`kubectl explain`** path.

Separate **exam path** from **lab-only aids** (markers, extra checks, scaffolding)
so the learner knows what to drop in the exam.

At the end of stage 3 the **command card** (≤ 10 lines, one verb per line,
placeholders instead of values) is written into the runbook the same day. It is the
only thing open while executing.

**No check questions in stages 1–3.** Each message ends with the next step
(`→ next: step 4 · verify with auth can-i`). Ask only when genuinely blocked.

### Stage 4 — Solo (at the terminal, on the lab)

1. The learner memorises shape + whiteboard + card.
2. **Run 1** with the card open if the bullet is new; skip if not.
3. **Run 2 without the card, timed.** The coach takes the time (`date +%s` at
   `go` and at `done`) → `§7` row of the domain index.
4. **Break/fix blind**, only after run 2 passes.
5. Questions allowed from here: recall, "why", what breaks if a step is skipped.

### Stage 5 — Exam mode (short)

Run with `/exam`. Two to four tasks in CKA wording, weights and targets, from the
runbook's `## §9. Exam mode` when it exists.

- 🧪 **Setup** blocks are untimed and **base64-encoded**, so the learner cannot read
  the pre-seeded or broken state. Every setup starts with its reset line.
- 🔍 **Graders** are base64-encoded, run after the clock stops, print `PASS`/`FAIL`
  per check.
- **A FAIL is pasted, not fixed first.** Then debrief: root cause, mistakes row.

### Speed rule (26 Sep, hardened 16 Oct)

Stages 1–3 are for **new mechanisms only**. A bullet whose mechanism is already in a
recalled note starts at the card: the coach explains only what is unfamiliar, then
stage 4. Re-verification of a closed bullet goes straight to stage 4 or 5.

### Coach rules — every stage

- Never more than one step per message in stage 3.
- No unexplained command, ever. A command whose flags were not explained is a
  coach defect.
- Every command block carries its machine banner.
- Never state a tool is installed without checking (16 Sep: `crictl` was claimed
  present and was not).
- Questions in stages 4–5 must have a verified answer (16 Sep: a question assumed a
  peer certificate would be rejected; it probably is not). The same holds for
  graders.
- Hide nothing important in a comment (16 Sep: *"without `-0`"* was buried in one
  and cost a failed download).

---

## 4. Opening a session

```
/study <runbook> <bullet>      e.g. /study cka-D1-3 1.1
/exam  <domain>                e.g. /exam cka-D1
```

If the previous session ended mid-stage, say so: *"1.1 stage 3 done up to step 4."*

---

## 5. Closing a session — `cierre`, non-negotiable

1. **Hours studied and confidence 1–5** → `plan.md §15`, plus open questions carried
   to the next session.
2. **Every miss in stages 4–5** → `claude/mistakes.md`, with a code.
3. **Timed runs and exam-mode results** (Actual vs Target) → `§7` of the domain index.
4. **Practice scores** with the weakest domain → `mistakes.md` + `plan.md`.
5. The coach shows the diff, commits (`<exam> D<n> <bullet>: <what>`) and pushes.
   `git log -- <file>` answers "is this the latest version?".

---

## 6. Knowledge blocks (KCNA/KCSA) — r1 rules, kept

- Note written once per canonical domain, deepened, never duplicated per exam.
- Depth rules: `claude/depth-standard.md`. Templates: `claude/note-templates.md`
  (A for KCNA/KCSA, B for CKA/CKAD/CKS theory, C for runbooks).
- Session: read → §10 recall closed-book → MCQs to root cause → `mistakes.md`.

---

## 7. What belongs where

| Content | Home |
|---|---|
| Mechanisms, facts, EKS deltas (§7) | `notes/NN-*.md` — one per domain, shared by all exams |
| How it is done, under a clock, with a machine | `<exam>/<exam>-D<n>*.md` |
| Schedule, scope, decisions, progress log | `plan.md` |
| Errors and root causes | `claude/mistakes.md` |
| Official objectives + scoreboard | `<exam>/<exam>-curriculum.md` |
| How sessions run | this file |
| Lab build and snapshots | `lab/` + `cka/cka-D1.md §0.3` |

## 8. Vocabulary

- **Block** = a certification (Block 2 = CKA). **Note** = a canonical domain
  (note 02 = API & Objects). **Domain** = an exam's curriculum section (CKA D1).
- **Stages 1–5** = walkthrough / shape / whiteboard / solo / exam mode (§3).
  Old name in older files: phase T = stages 1–3, phase C = the card, phase E = stage 4.
