# session-protocol.md — How chats and sessions work

> Read this first if you are a new chat in this project.
> **Revision r2, 2026-09-16.** Adds the **teach-first method** (§3), which governs
> every performance block: **CKA, CKAD, CKS**. The KCNA rules (§6) are kept for
> the conditional KCSA block. Folder layout moved to `plan.md §13`.
> Previous: 2026-08-23 (r1, KCNA only).

---

## 1. One chat per DOMAIN (performance blocks)

One chat per curriculum domain, held open for that domain's days
(`plan.md §7.3`). Continuity lives in the project files, never in chat history.

```
CKA D1 — Cluster Architecture    ·  CKAD D1 — …  ·  CKS D1 — …
```

`D` is always the **domain number**, never the day.

---

## 2. Why the method changed — 16 Sep

The first CKA etcd session issued ten numbered tasks, forty commands and a blind
break at once. The learner — KCNA-level theory, little console practice — reported
executing blind: *"voy como aplicando ciego"*. Nothing was executed, and the
understanding came later, one step at a time, from bed on a phone.

**Conclusion:** for material that is new at the console, **understanding comes
before execution, and the command list comes last.** A timed drill of something not
understood measures nerves, not skill.

---

## 3. The teach-first method — CKA · CKAD · CKS

Every coach lab runs in **three phases**. Never skip one, never merge two.

### Phase T — Teach (no terminal needed; a phone is fine)

1. **Big picture first, zero commands.** What the lab does, why, and the
   numbered list of steps as a table (step · what · why). An analogy if it helps.
2. **One step per message.** For each step:
   - the **idea** in plain words;
   - **every command, piece by piece** (flags in a table, every pipe, every
     `sudo` justified);
   - the **verification** and what its output should look like;
   - the **machine** it runs on (`plan.md §8.2`);
   - the **EKS delta**, if any;
   - **one check question.**
3. **Wait for the learner's "entendido"** before the next step. The learner asks
   in Spanish; the coach explains in Spanish; the material and the card are in
   English.
4. Correct wrong answers precisely: say what was right, what was wrong, and the
   exact correction. Every miss becomes a `mistakes.md` row the same day.
5. Separate **exam path** from **lab-only learning aids** (markers, extra
   verification, scaffolding) in a table, so the learner knows what to drop in the
   exam.

### Phase C — Card (once, at the end of T)

The **command card**: the whole procedure in ≤ 10 lines, English, one verb per
line. It is written into the runbook (`cka-D<n>-*.md`) the same day. **This is the
only thing the learner looks at while executing.**

### Phase E — Execute (at the terminal, on the lab cluster)

1. Boot block (`cka-D1.md §0`) from memory, timed.
2. **Run 1** looking at the card. Paste verification output to the coach.
3. **Run 2** without the card, timed → `§7` row of the domain file.
4. **Break/fix blind** — only after run 2 passes.
5. Close-out (§5).

**Phase T may happen on a different day or device from phase E.** A step is not
closed until it has been *executed* — understanding alone never produces a ✅.

### Coach rules that apply in every phase

- Never more than one step per message in phase T.
- No unexplained command, ever. A command whose flags were not explained is a
  coach defect.
- Every command block carries its machine banner.
- Never state a tool is installed without checking (16 Sep: `crictl` was
  claimed present and was not).
- Check questions must have a verified answer (16 Sep: a question assumed a
  peer certificate would be rejected; it probably is not).
- Hide nothing important in a comment (16 Sep: *"without `-0`"* was buried in
  one and cost a failed download).

---

## 4. Opening prompt — performance blocks

```
Read plan.md, claude/session-protocol.md, claude/mistakes.md,
<exam>/<exam>-curriculum.md, <exam>/<exam>-D<n>.md and today's content file.
Today is <DATE>, <EXAM> W<n> — <topic>.
Teach-first (§3): big picture without commands, then one step per message
with every command explained, a verification and one check question; wait for
my "entendido". Command card at the end, written into the runbook.
Then I execute: run 1 with the card, run 2 timed without it, break/fix blind.
At close: §7/§8 of the D file, mistakes.md, progress log.
```

If yesterday ended in phase T, say so: *"Phase T done for <topic>; start at
phase E."*

---

## 5. End-of-session ritual — non-negotiable

1. **Hours studied and confidence 1–5** → `plan.md §11`.
2. **Every wrong or partial check answer** → `claude/mistakes.md`, with a code.
3. **Timed runs** (Actual vs Target) → `§7` of the domain file.
4. **Practice scores** with the weakest domain → `mistakes.md` + `plan.md`.
5. **Open questions carried to the next session**, listed at the bottom of the
   progress-log row.

The coach cannot write to the project. Updated files are delivered as
attachments; files whose local copy may be newer (`plan.md`, `mistakes.md`) are
delivered as **patch blocks to append**, never as full replacements.

---

## 6. Knowledge blocks (KCSA) — r1 rules, kept

- Note written once per canonical domain, deepened, never duplicated per exam.
- Depth rules: `claude/depth-standard.md`. Templates: `claude/note-templates.md`
  (A for KCNA/KCSA, B for CKA/CKAD/CKS).
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
- **Phase T / C / E** = teach / card / execute (§3).
