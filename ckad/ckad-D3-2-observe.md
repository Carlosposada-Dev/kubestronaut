---
domain: D3 — Application Observability and Maintenance
group: 2 — Read What It Says
bullets: [3.3, 3.4, 3.5]
exams: [CKAD]
index: ckad-D3.md
theory: notes_08, notes_09
k8s_version: v1.37
status: r1 skeleton — draft paths unmeasured
revision: 2026-11-13 (r1 — split out of `ckad-D3.md` the day it was written; migrated to Template C the day each bullet is worked)
---

# D3 · Group 2 — Read What It Says (bullets 3.3, 3.4, 3.5)

> Index, drill table and scoreboard: **`ckad-D3.md`**. Session: **Tue 17 Nov** (`plan.md §10`).
> Objectives and the reported-task list (R#): `ckad-curriculum.md`.
> Legend, typing conventions: `cka/cka-D1-2-lifecycle.md` (reference implementation).
>
> What unites these three: nothing is created — something is read from a running application and, usually, written to a file the task names. 3.5 is the ladder that uses the other two.
>
> **Draft path** blocks are the expected exam path, **not yet run on the lab**. The
> guided pass replaces each one with the measured whiteboard, card and traps.

## Legend
🎯 exam path · 🔍 verification · ⏱ fixed machine wait · 📚 study only · 🧪 lab scaffolding
Whatever the task statement spells out is literal; 🎯 blocks show defaults, not orders.
Card index: 3.3 Use built-in CLI tools to monitor applications · 3.4 Utilize container logs · 3.5 Debugging in Kubernetes

---

## 3.3 Use built-in CLI tools to monitor applications ✍️

**Runs on: cp1 (needs metrics-server — Helm install as in `cka-D1-3-access.md` 1.6).** · **Theory →**
notes_09 §1.7 · **Docs →** `k top -h` · **Target: 2:00**

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k top pods -A --sort-by=memory | head                   # or --sort-by=cpu
k -n NS top pod P --containers
k top nodes
k -n NS get events --sort-by=.lastTimestamp | tail
k -n NS get pods -l app=X -o wide --show-labels
```

The task is usually "write the name of the Pod using the most CPU to /path/file":
the answer is one word in one file — `echo NAME > /path/file`, then `cat` it.

To measure: `top` right after a Pod starts (`metrics not available yet`); `--sort-by`
with `-A`.

---

## 3.4 Utilize container logs ✍️

**Runs on: cp1.** · **Theory →** notes_08 §1.8 · **Docs →** `k logs -h` · **Target: 2:00**

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS logs P -c CONTAINER > /PATH/file                # the file is the answer
k -n NS logs P --previous                               # the container that crashed
k -n NS logs deploy/D --all-containers --tail=20
k -n NS logs -l app=X --prefix --since=10m
```

To measure: `logs` on a multi-container Pod without `-c` (which one, which message);
`--previous` with no previous container.

---

## 3.5 Debugging in Kubernetes ✍️

**Runs on: cp1.** · **Theory →** notes_08 §1.1–1.4, §1.7, §1.10 · **Docs →** search
`debug running pods` / `debug service` · **Target: 6:00 to find + fix** · **Reported: R9**

Must contain the ladder, always in this order — the STATUS column picks the rung:

| `get pods` says | Look at | Usual cause in a CKAD task |
|---|---|---|
| `Pending` | `describe pod` → Events | quota, unbound PVC, nodeSelector, no resources |
| No Pod at all | `describe rs` / `get events` | ResourceQuota or LimitRange rejected it; bad ServiceAccount |
| `ErrImagePull` / `ImagePullBackOff` | Events | image name or tag typo |
| `CrashLoopBackOff` / `Error` | `logs --previous`, exit code | wrong command, missing env / ConfigMap key |
| `CreateContainerConfigError` | Events | ConfigMap / Secret / key does not exist |
| `Running` but `0/1` | `describe` → readiness | probe path / port wrong |
| `Running` `1/1`, no traffic | `get endpointslices`, selector, ports | Service selector / targetPort (`ckad-D5-1-services-ingress.md` 5.2) |

```bash
# ▶▶ cp1 🎯 — draft path, unmeasured
k -n NS get pods -o wide ; k -n NS describe pod P | tail -20
k -n NS run tmp --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- -T2 SVC:PORT
k -n NS exec -it P -- sh
k -n NS debug -it P --image=busybox:1.36 --target=CONTAINER
```

To measure: one broken object per rung, built by the setup of §9.

```
(your runbook here)
```

---

## §9. Exam mode

> Tasks in CKAD wording with 🧪 setup and 🔍 grader (base64, verified against setup
> alone / correct / typical wrong) are written the day each bullet is worked.
