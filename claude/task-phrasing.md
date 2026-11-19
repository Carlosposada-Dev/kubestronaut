# task-phrasing.md — exam wording I misread or had to look up

> Grows only from real misses in stages 4–5 and killer.sh (rule of 18 Nov,
> `claude/session-protocol.md §3`). One row per phrase. Re-read it the day before
> every exam. The seed rows below come from the CKA misses before 18 Nov.

| Phrase in the task | What it actually asks | Where it was missed |
|---|---|---|
| "record the change cause … so that it appears in the rollout history" | `kubernetes.io/change-cause` annotation on the Deployment, set **before** the change it describes | `cka-D2-1-workloads.md` 2.1 (8 Nov) |
| "no Pod is ever unavailable" · "at most N additional Pods" | `maxUnavailable: 0` · `maxSurge: N` | `cka-D2-1-workloads.md §9` R1 |
| "roll back to the revision that runs image X" | find the revision by its image, not by number — `undo` renumbers | `cka-D2-1-workloads.md` 2.1 |
| "can read the logs of Pods" | resource `pods/log` (singular) | `cka-D1-3-access.md` 1.1 (7 Nov) |
| "install the release named X" | the release name is literal and ≠ the chart name | `cka-D1-3-access.md` H1 (8 Nov) |

**Words to stop on:** *ensure* (state, verified) · *must not* · *at most / at least* ·
*only* · *without modifying* · *in namespace* · *write … to /path* (the file is the
answer) · *existing* (edit it, do not recreate) · *all / every*.
