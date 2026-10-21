---
name: study
description: Start a CKA/CKAD/CKS study session on one runbook bullet with the five-stage method (walkthrough, shape, whiteboard, solo, exam mode).
argument-hint: <runbook> <bullet>   e.g. cka-D1-3 1.1
disable-model-invocation: true
---

Study session for: **$ARGUMENTS**

## Before the first message

1. Read `claude/session-protocol.md` — it is the method. Follow §3 exactly.
2. Read `plan.md` §3–§6 and the last rows of §15 (where am I, what is owed).
3. Read the domain index (`<exam>/<exam>-D<n>.md`: §7 drill table, §8 scoreboard)
   and the runbook named in the arguments, at the bullet named.
4. Read the rows of `claude/mistakes.md` that touch this bullet or domain.
5. If the runbook references a theory note (`Theory → notes_NN §x`), read that
   section too.

If the arguments are missing or ambiguous, list the runbooks in `cka/` with their
bullets and ask which one — that is the only question allowed before stage 1.

## First message

Short status, then start:

- Bullet, target time, status in §7/§8, last time it was worked, open mistakes rows.
- Where this sits against `plan.md §6.2` today — one line, blunt if behind.
- Which stage we start at, applying the speed rule (session-protocol §3): new
  mechanism → stage 1; already recalled → the card, then stage 4; closed bullet
  under re-verification → stage 4 or 5.
- Then stage 1 (or the chosen starting stage) for real.

## While running

- Stages 1–3: no check questions, no closing question. End every message with
  `→ next: <stage/step>` and wait for `sigue`.
- Stage 3: one step per message, every flag in a table, machine banner on every
  block, verification with expected output, EKS delta, docs search term +
  `kubectl explain` path.
- End of stage 3: write or update the command card in the runbook (Template C,
  ≤ 10 lines). Show the diff.
- Stage 4: time run 2 with `date +%s` when I say `go` and when I say `done`.
  Questions are allowed from here on.
- Stage 5: hand over to `/exam` for the domain, or run 2–3 tasks from the runbook's
  `## §9. Exam mode` the same way `/exam` does.
- Any miss in stages 4–5 → note it for `claude/mistakes.md` at `cierre`.

At `cierre`: follow `claude/session-protocol.md §5`.
