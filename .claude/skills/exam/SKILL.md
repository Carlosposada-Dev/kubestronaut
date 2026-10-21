---
name: exam
description: Run a short exam-mode drill for a CKA/CKAD/CKS domain — exam wording, base64-encoded setup and grader, timed, results logged.
argument-hint: <domain> [n tasks]   e.g. cka-D1 3
disable-model-invocation: true
---

Exam-mode drill for: **$ARGUMENTS** (default 3 tasks).

## Prepare (before showing anything)

0. Run `git pull --ff-only` (stop if it fails) and
   `command -v multipass && multipass list`. No lab reachable from this machine →
   stop: exam mode needs the cluster. Say which machine has it.
1. Read `claude/session-protocol.md §3` (stage 5) and `plan.md §13` (exam environment).
2. Read the domain index (`<exam>/<exam>-D<n>.md` §7) and every runbook of the domain.
3. Read `claude/mistakes.md` rows for the domain.
4. Pick the tasks:
   - Prefer tasks from the runbooks' `## §9. Exam mode` sections and their
     variations.
   - Weight toward bullets that are ◐/🔴 in §7/§8 and toward open mistakes rows.
   - Never a bullet that has not been through stage 4 at least once — tell me which
     ones are not ready instead.
   - If a runbook has no §9 yet, write new tasks in CKA wording and add them to that
     runbook's §9 at `cierre`.

## Each task

Present it exactly in this shape:

````
```
Task <X>  (weight <n>%)                                       target <m> min
Context: k8s-lab

<task text, worded as the real exam words it — literal names, namespaces, paths>
```

🧪 Setup — untimed (reset first: `<reset line>`):
```bash
# ▶▶ cp1
echo '<base64 of the setup script>' | base64 -d | bash
```
````

- **Setup and grader are base64-encoded** so I cannot read the pre-seeded or broken
  state. Never show their plain text before the grader has run.
- Setup scripts are idempotent, silence their output and end with `echo "setup done"`.
- Hold the grader back until I say `done`.

## Clock

- When I say `go`: run `date +%s` and keep the value.
- When I say `done`: run `date +%s`, report Actual vs Target, then give me the grader:

```bash
# ▶▶ cp1
echo '<base64 of the grader>' | base64 -d | bash
```

- Graders print one `PASS  <check>` / `FAIL  <check> (got '…', want '…')` line per
  check, testing the outcome (e.g. `kubectl auth can-i … --as=…`), not my exact
  commands. Include negative checks (what must NOT be allowed or present).
- Before encoding, re-read every grader check against the task text: a wrong grader
  is a coach defect. If I report a FAIL that looks wrong, check the grader first.

## After each task

- A FAIL is pasted, not fixed first. Then debrief: root cause, the fix, the code
  (`EKS` `CONF` `GAP` `SPEED` `READ` `LIT` `PREC`).
- Questions and "why" probes are welcome here.

## At the end

Summary table: task · target · actual · PASS/FAIL · code. Then at `cierre`:
results → domain index §7, misses → `claude/mistakes.md`, new tasks → runbook §9,
log row → `plan.md §15` (`claude/session-protocol.md §5`).
