# plan.md — CKA · CKAD · CKS by 30 Nov 2026

> Living document. Update STATUS after every exam, the progress log after every
> session. **Last updated: Fri 16 Oct 2026 (v5.0 — calendar re-cut after 10 days
> with zero hours: CKA moved Sun 18 Oct → Sat 7 Nov · CKAD Sat 21 Nov · CKS Sun 29 Nov
> · expiration of all three confirmed 30 Nov · go/no-go rule rewritten for the wall
> · practice week 31 Oct – 6 Nov conditional on the Fri 30 Oct checkpoint ·
> D1 re-verification Sat 17 Oct replaces the §6.3 rotation).**
> Previous: 26 Sep (v4.3 — D1-1 session, CNI sim 3:24, sims A/B); 26 Sep (v4.2 — exam
> environment verified); 17 Sep (1.4b proven); 16 Sep (teach-first); 12 Sep (KCNA 88%).

**File integrity, 16 Oct — unchanged since 26 Sep.**
`claude/mistakes.md` in the project stops at **row 81** — rows **82–88** (17 Sep) and
**27–56** (notes 03–08) are missing. Re-upload the local copy.
`plan-patch-2026-09-11.md` retired. `cka-D1-3-access.md` exists in the project
(2 Oct) — its status is confirmed at the Sat 17 Oct assessment.

---

## 1. Hard constraints

| Item | Value |
|---|---|
| Targets | **CKA, CKAD, CKS.** KCNA ✅ 88% (11 Sep). **KCSA dropped 26 Sep** → Kubestronaut is not reachable in 2026 |
| Hard deadline | **30 Nov 2026** — **confirmed 16 Oct in My Portal: CKA, CKAD and CKS all expire 30 Nov.** Last day any exam can be *sat*. Retakes share it |
| Priority order (16 Oct) | **CKA first, at the first attempt. Then CKAD. CKS gets whatever is left** and is sat only as a free shot — it never takes an hour from CKAD |
| Study time | **Sat + Sun committed.** Mon–Fri: 3 h target, as paid work allows. A weekday may shrink to 1 h (§7.2); **zero hours is not a plan state** — a zero-hour weekday moves its bullet to the weekend, never off the list |
| Retakes | 1 free per exam. ~48 h latency (24 h result + booking) |
| Reschedule | Impossible within **24 h** of exam time |
| Exam Simulator | killer.sh, **2 attempts per exam**, 36 h each. **Both attempts contain the same questions** → attempt 1 diagnoses, attempt 2 decides |

**Weekend/weekday rule (26 Sep, pre-committed).** Weekends carry what cannot
survive being cut short: phase T of a new runbook, break/fix, mocks, simulator,
anything needing a snapshot restore. Weekdays carry what still counts if it
shrinks to 1 h: spaced reviews, phase E re-runs, timed drills, rewrite-from-memory,
literals.

---

## 2. Profile

- DevOps/platform, new in the role. Terraform on **EKS** daily. Linux desktop,
  Ryzen 5 3600, 48 GB, Ubuntu 24.04 — PSI exam from this desktop.
- **#1 Vanilla internals** (kubeadm, etcd, static Pods, upgrades, kubelet, CNI).
  D1 + D5 = 55% of CKA.
- **#2 Console fluency and speed.** Good concepts from KCNA, many commands new.
  CKA: 120 min, ~17 tasks.
- **#3 Schedule slippage** — 14 days lost in August; W1 ran ~1 week long;
  **~10 days lost 6–16 Oct** (paid obligations). Three slips in three months →
  the calendar now carries explicit "if the day is lost" rules instead of hope.
- **#4 `LIT`** — mechanisms reliable, exact strings not. 6 of 7 rows on 17 Sep.
- **#5 `READ`** — answers the consequence of X when asked X.
- **#6 Wrong-machine execution** — commands typed on the host (§8.2).
- **Pattern confirmed 16–17 Sep:** every mechanism right when taught one step at a
  time; misses are literals. Diagnosed the watch-cache failure himself.

**Out of scope until 1 Dec:** Istio, Kyverno, ArgoCD, service mesh, Terraform,
OPA/Gatekeeper internals. Helm and Kustomize are **in**.

**Governing principle (1 Sep):** learning properly outranks any single date, but
30 Nov is contractual, and "depth wins" covers deliberate trade-offs only — never
days with zero hours.

---

## 3. Exam calendar

| Exam | Study window | Exam | STATUS |
|---|---|---|---|
| KCNA | — | 11 Sep | ✅ **88%** |
| **CKA** | Sat 17 Oct – Mon 9 Nov | **Tue 10 Nov** (moved 27 Oct; plan B Sun 15 Nov) · killer.sh A1 Thu 5 Nov | ◐ active |
| CKAD | Sun 8 Nov – Fri 20 Nov (13 days) | **Sat 21 Nov** | ☐ **book now** (free to move) |
| CKS | Sun 22 Nov – Sat 28 Nov (7 days) | **Sun 29 Nov** | ☐ **book now**; cancel Sun 22 Nov if the chain broke |
| Buffer | Sun 22 – Mon 30 Nov | — | absorbs exactly **one** failure (§5) |

> **31 Oct:** CKA date is now Tue 10 Nov (learner's call, 27 Oct). §3 scenarios, §5
> and §6.2 below still assume Sat 7 Nov — **re-cut owed**. Goal unchanged: CKA + CKAD
> before 30 Nov, CKS as a free shot.

**Why these dates.** Saturday exams: the result (24 h) lands on Sunday, the next
decision is made before Monday. CKAD reuses ~60% of CKA and is a speed exam →
13 days is enough if CKA is clean. CKS with 7 days is a lottery ticket: ~70% of its
content is new (Falco, AppArmor, seccomp, Trivy, kube-bench, audit logging, PSA).
It is sat because the registration dies on 30 Nov anyway — not because it is expected
to pass.

**What the 9-day buffer covers:**

| Scenario | Outcome |
|---|---|
| CKA ✅ 7 Nov · CKAD ✅ 21 Nov | CKS Sun 29 Nov as a free shot |
| CKA ✅ · CKAD ❌ 21 Nov | result Sun 22 → CKAD retake **Sat 28 Nov**. CKS cancelled |
| CKA ❌ 7 Nov | result Sun 8 → CKA retake **Sat 14 Nov** → CKAD **Sat 28 Nov** (13 days intact). CKS cancelled |
| CKA ❌ twice | 2026 is over for CKAD too |

The buffer covers one failure, never two. The whole plan is built around **CKA at
the first attempt**.

**Booking rule change (16 Oct).** v4.3 said "book CKAD/CKS after the CKA result".
With the wall, an unbooked slot is the only way to lose an exam — book all three
now; moving is free until 24 h before.

---

## 4. CKA status on 16 Oct — honest read

Nothing has been touched since ~5 Oct. Everything marked closed before that is
**unverified** until the Sat 17 Oct assessment (§6.2 Week 0).

| Domain | Weight | Verified closed | Unverified (assess 17 Oct) | Not started |
|---|---|---|---|---|
| D1 Cluster Architecture | 25% | — | **1.2 · 1.3 · 1.4 (upgrade, etcd, certs, 1.4c) · 1.5 read · 1.7** · **1.1 RBAC · 1.6 Helm/Kustomize · 1.8 CRDs** (27 Sep, learner does not recall the state) | — |
| D2 Workloads | 15% | — | — | 5/5 |
| D3 Networking | 20% | — | possibly some of 3.1/3.3/3.6 (28 Sep – 5 Oct, to confirm) | up to 6/6 |
| D4 Storage | 10% | — | — | 3/3 |
| D5 Troubleshooting | 30% | — | — | 5/5 |
| **Total** | | **0/27 verified** | 8 to re-verify | 19 |

**What that means.** 14 study days (17–30 Oct) for the D1 re-verification plus 19
new bullets → **~1.4 bullets per day**, phase C/E only, cut list already applied
(§5). The practice week (31 Oct – 6 Nov) exists **only** if the Fri 30 Oct checkpoint
passes. D1 is still the strongest domain on paper; the assessment decides whether
that is true.

**Cut list — applied from 16 Oct, not waiting for a trigger:** 1.5 HA stays
read-only · 1.8 CRDs recognise-and-explain only · 3.4 Gateway API happy path only
· D4 compressed to one session. **D5 is never cut.**

---

## 5. Switch triggers — pre-committed (v5)

| Trigger | Response |
|---|---|
| **Assessment Sat 17 Oct: any D1 item 🔴** (cannot do it) | Phase C re-read the same day, E run on Sun 18. Nothing else in D1 gets phase T |
| **Checkpoint Sun 25 Oct: D1 ✅ + D3 6/6 + D5 5.1/5.2/5.4/5.5 touched?** If not | Second cut: 2.3 HPA imperative only · 3.5 Ingress happy path only · 1.1 RBAC verbs/resources drill only. D5 still never cut |
| **Checkpoint Fri 30 Oct: all 27 bullets touched?** If not | **Sat 31 Oct becomes a bullet day.** Mock A → Tue 3 Nov. killer.sh A1 stays Sun 1 Nov |
| **killer.sh A2 (Wed 4 Nov) ≥ 60%** | **Sit the CKA Sat 7 Nov. No discussion.** Thu–Fri on the weakest domain. (Rationale: moving to 14 Nov gives the same date a failed 7 Nov retake would, costs the 7 Nov shot and kills CKS either way; killer.sh is harder than the real paper) |
| **killer.sh A2 < 60%** | **Reschedule Wed 4 or Thu 5 Nov** (must be > 24 h before exam time) to **Sat 14 Nov**. CKAD → Sat 28 Nov. CKS cancelled. Below 60% is not courage, it is spending the free retake on a probable fail |
| **CKA fails 7 Nov** | Retake **Sat 14 Nov**. CKAD → **Sat 28 Nov**. CKS cancelled Sun 8 Nov |
| **CKAD not clean by Thu 19 Nov** (A2 < 75% or > 105 min) | Sit it 21 Nov anyway; its retake fits Sat 28 Nov. CKAD never eats CKS days — but CKS is cancelled the moment a CKAD retake is needed |
| **CKAD fails 21 Nov** | Retake Sat 28 Nov. CKS cancelled Sun 22 Nov |
| **Two weekend days lost in one week** | Learner reports it **that Sunday**; the coach re-cuts on Monday. Bullets move into weekday slots; reviews are dropped, never bullets |
| **Zero-hour weekday** | Next weekday carries the review only; the bullet moves to the weekend |

---

## 6. CKA — Block 2

### 6.1 Resource roles

| Resource | Role | When | Never |
|---|---|---|---|
| **Coach lab on the kubeadm cluster** | The exam surface. C/E for everything with a note; T only for new mechanisms; break/fix blind, every EKS delta written the same day | Every session | On EKS · without a verification · from the host (§8.2) |
| **Coach sims in exam wording** | Untimed setup block (breaks base64-encoded) → timed task → self-verification. Real-exam scenarios | Weekends from 18 Oct; practice week daily | As a substitute for the simulator |
| **KodeKloud CKA** — section labs | Reps in a disposable cluster | Weekdays, when a bullet's runbook is closed | In the practice week |
| **KodeKloud CKA** — video | Vocabulary, **only** for a topic with no runbook and no note | Rare | Whole course · 1× speed · topics already closed |
| **KodeKloud mock exams** | First timed full paper | **Mock A Sat 31 Oct** · Mock B optional Tue 3 Nov | Two in one day |
| **Exam Simulator** (killer.sh, from the LF portal) | Go/no-go, and the only rehearsal of the PSI remote desktop | **A1 Sun 1 Nov · A2 Wed 4 Nov** | Opened before 1 Nov. Same questions both times — memorising A1 makes A2 worthless |

Killercoda is **cut** (26 Sep): there is no free weekend slot for it.

### 6.2 Day by day — Sat 17 Oct → Sat 7 Nov

`W` = weekend, full session · `d` = weekday, may shrink to 1 h · `R:` = spaced
review from §6.3, first 20 min after the per-host line.

**Week 0 — reset (assessment, not re-teaching)**

| Day | | Content |
|---|---|---|
| **Sat 17 Oct** | W | **PSI system check** on the Ubuntu desktop (first 10 min). Then the **assessment**: every item below, card closed, keyboard clock, in this order. Three buckets: ✅ under target without the card → enters §6.3 at R1 · 🟡 over target or card consulted → restarts at R1, one `mistakes.md` row · 🔴 cannot do it → phase C re-read today, E run tomorrow. Items: **etcd save 5:00 / restore 10:00** · **certs renew + kubeconfig 6:00** · **upgrade cp1 + w1 from `lab-v134`, keyboard ≤ 4:00** · **1.3 join + decommission on `w3` 3:00** · **CNI sim B on `w3` 6:00** · **1.1 RBAC** (Role/RoleBinding/SA + `auth can-i`) **4:00** · **1.6 Helm install + Kustomize overlay 5:00** · **1.8 CRDs** recognise-and-explain, 5 min read. Rebuild the §6.3 rotation table from the results |
| Sun 18 | W | R: yesterday's 🔴 items (E run) · **sim A** API-server-down with a **new** encoded break, 6:00 · **D5 5.1** node break/fix + **5.2** control-plane break/fix (`cka-D5.md`) · book CKAD 21 Nov + CKS 29 Nov if not done |

**Week 1 — D3 + D5 core**

| Day | | Content |
|---|---|---|
| Mon 19 | d | R: **etcd** · **3.3 Services + EndpointSlices** |
| Tue 20 | d | R: **certs** · **3.1 Pod connectivity + 3.6 CoreDNS** (note 05 amendments) |
| Wed 21 | d | **3.2 NetworkPolicy** — no imperative path, docs-page drill on the Calico cluster |
| Thu 22 | d | R: **upgrade** (keyboard clock) · **3.4 Gateway API** happy path only |
| Fri 23 | d | **3.5 Ingress** (controller via Helm) |
| Sat 24 | W | **Set 1 exam mode** (upgrade + etcd + drain), timed · **D5 break/fix set** (`cka-D5.md §7`, as many of 12 as fit) · **5.4 logs `--previous`** + **5.5 service/network troubleshooting** (note 08 amendments) |
| Sun 25 | W | **D4 4.1–4.3** in one session (note 06 amendments) · **D2 2.1 rollouts + 2.2 ConfigMaps/Secrets** · **CHECKPOINT (§5): D1 ✅ · D3 6/6 · D5 4/5 touched?** |

**Week 2 — close D2, touch everything**

| Day | | Content |
|---|---|---|
| Mon 26 | d | **2.3 HPA** + **5.3** metrics-server / `kubectl top` |
| Tue 27 | d | R: **etcd** · **2.4 probes + PDB** (note 03 PDB block) |
| Wed 28 | d | **2.5 scheduling** — affinity, taints, requests/limits, quota vs LimitRange |
| Thu 29 | d | R: **certs** · timed imperative drill, all object types · leftovers |
| Fri 30 | d | R: **upgrade** · leftovers · **CHECKPOINT (§5): 27/27 touched?** → decides whether Sat 31 is practice or bullets |

**Week 3 — practice week (earned on Fri 30)**

| Day | | Content |
|---|---|---|
| Sat 31 Oct | W | **KodeKloud Mock A**, timed 2 h → root cause every miss · **D5 break/fix set 2** |
| Sun 1 Nov | W | **Exam Simulator A1**, timed → root-cause every miss (36 h window runs into Tue) |
| Mon 2 | d | Every A1 miss redone on your cluster, from memory |
| Tue 3 | d | **Set 1 + Set 2 exam mode** · coach sims (exam wording, encoded breaks) on the weakest domain by evidence · Mock B optional |
| **Wed 4** | d | **Exam Simulator A2 — go/no-go: ≥ 60% sit · < 60% reschedule tonight to Sat 14 Nov** (§5) |
| Thu 5 | d | A2 misses · weakest domain · `mistakes.md` full pass |
| Fri 6 | d | Literals only · restore `lab-v137` · **no new material** · sleep early |
| **Sat 7** | | **CKA** — check in 30 min early · `use-context` first · 8-minute rule |

**Done when — all three:** A2 ≥ 60% (target 75%) · upgrade and etcd restore from
memory within target · D5 break/fix ≥ 10/12.

### 6.3 Spaced review — how closed runbooks stay closed

A bullet that was right on 17 Sep and never touched again is gone by 7 Nov — the
10-day gap proved it. **Every closed runbook enters a review rotation:**

| Review | When | Mode |
|---|---|---|
| R1 | +2 days after closing | From memory, timed, card closed |
| R2 | +5 days after R1 | Same |
| R3 | +10 days after R2 | Same, in exam-mode wording |
| Final | Practice week | Inside Set 1 / Set 2 or the simulator misses |

**Fail a review** (look at the card, or miss the target) → that item restarts at R1.
Every miss is a `mistakes.md` row. **One review per weekday, max 20 min**; reviews
needing a snapshot restore go to weekends or to a day with no new bullet.

**Rotation — rebuilt Sat 17 Oct from the assessment.** The v4.3 table is void.
Items that pass the assessment enter at R1 on the dates below; items that fail
enter at R1 two days after their phase E run.

| Item | Code | Target (keyboard clock) | R1 | R2 | Final |
|---|---|---|---|---|---|
| etcd save + restore | E | save 5:00 · restore 10:00 | Mon 19 Oct | Tue 27 Oct | Set 1 (Tue 3 Nov) |
| Certificates renew + kubeconfig | C | 6:00 | Tue 20 Oct | Thu 29 Oct | Practice week |
| Upgrade cp1 + 1 worker | U | keyboard ≤ 4:00 · wall ≤ 12:00 | Thu 22 Oct | Fri 30 Oct | Set 1 (Tue 3 Nov) |
| Node prep (1.2) | P | 10:00 | Sat 24 Oct if time | — | Set 2 |
| CNI install (1.3, sim B) | N | 6:00 | Sun 25 Oct if time | — | Set 2 |
| API server down (1.7, sim A) | A | 6:00 | Sun 18 Oct (new break) | Sat 24 Oct (D5 set) | Simulator |
| RBAC (1.1) | B | 4:00 | Thu 29 Oct (imperative drill) | — | Simulator |
| Helm + Kustomize (1.6) | H | 5:00 | Fri 23 Oct (Ingress via Helm) | — | Simulator |

**New bullets join automatically:** closed on day X → R1 on X+2, R2 on X+7. The
coach proposes the day's review at the start of each session from this table and
`cka-D<n>.md §7`.

---

## 7. Daily session — performance blocks

### 7.1 Method: five stages (`claude/session-protocol.md §3`, r3 19 Oct)

**1 Walkthrough** — the runbook section explained top to bottom. **2 Shape** — the
concepts, no commands. **3 Whiteboard** — one step per message, every flag explained,
command card written into the runbook. **No check questions in 1–3**; the learner
says `sigue`. **4 Solo** — run 1 with the card, run 2 without it and timed, break/fix
blind. **5 Exam mode** — short encoded set via `/exam`.

**Speed rule (26 Sep, hardened 16 Oct):** stages 1–3 are for **new mechanisms only**.
A bullet whose mechanism is already in a recalled note (most of D2, D3, D4) starts at
the card — the coach explains only what is unfamiliar, and moves to stage 4.
Re-verification of D1 items never gets stages 1–3; a 🔴 gets the card.

| Run | Mode |
|---|---|
| 1st | Card open, explained where needed |
| 2nd | Card closed, timed |
| 3rd+ | Spaced reviews (§6.3). Two in a row under target → ✅ |

### 7.2 The 3 hours

| Time | Activity |
|---|---|
| 0:00–0:05 | `multipass shell cp1` → **per-host line** (§13, target 10 s) + **one docs-map lookup** (§13.1, target 30 s) |
| 0:05–0:25 | **Spaced review** of the day (§6.3). Weekend: skip if a restore is needed later |
| 0:25–2:15 | New bullet: (T →) C → E. Break/fix blind at the end |
| 2:15–2:35 | Timed imperative drill on today's objects |
| 2:35–2:45 | Literals from `mistakes.md` `LIT` rows, written from memory |
| 2:45–3:00 | Rewrite today's card from memory → diff → `mistakes.md` · `cka-D<n>.md §7/§8` · hours + confidence |

A weekday cut to 1 h = per-host line + review + rewrite. Nothing else.

**Every task:** `use-context` first · **8-minute rule** · **every command block
states its machine** (§8.2). **Measure the keyboard clock, not the wall clock**:
`apt-get`, `kubeadm upgrade apply` and control-plane restarts carry 2–6 min of fixed
machine time — in the exam, leave the task while it waits.

### 7.3 Sessions (Claude Code, from 19 Oct)

One Claude Code session per study block, opened in this repo and named after the
domain: `CKA D1 — Cluster Architecture` · `CKA D3 — Services & Networking` ·
`CKA D4 — Storage` · `CKA D2 — Workloads` · `CKA D5 — Troubleshooting` ·
`CKA Simulator` (practice week). Opener: `/study` or `/exam`
(`claude/session-protocol.md §4`). Continuity lives in the files, not the chat.

---

## 8. Lab environment

| Item | Value |
|---|---|
| Lab host | **Two, same build (`lab/build/`), either one works:** laptop — WSL Ubuntu 24.04, multipass 1.17 on nested KVM, `.wslconfig` caps WSL at 6 threads / 16 GB (since 29 Oct) · desktop — Ubuntu, multipass 1.17, 12 threads / 45 GB (rebuilt 1 Nov; old `lab-v134`/`lab-v135` deleted). IPs differ per host — each host records its own in `lab/build/lab-ips.env` (gitignored) |
| Cluster | multipass/QEMU-KVM · `cp1` (2 vCPU / 4 GB) `w1` `w2` (2 vCPU / 3 GB) · kubeadm **v1.37.2** (`lab-v137`) · Calico **v3.33.0** via tigera-operator + `Installation` CR |
| Disposable node | **`w3`** (laptop `10.97.0.241` · desktop `10.167.152.248`) (2 vCPU / 3 GB) — snapshots **`cleanw3`** = bare Ubuntu (1.2 target) and **`prep137`** = node prep done on 1.37.2, held, tools, never joined (1.3 / 1.7 start here). Every install/reset/init runs there, never on cp1/w1/w2 |
| Control-plane IP | **Laptop:** `10.97.0.61` · w1 `10.97.0.146` · w2 `10.97.0.213` (rebuilt 31 Oct — **w2 now has cp1's old IP**) · **Desktop:** cp1 `10.167.152.197` · w1 `.100` · w2 `.11` · w3 `.248` |
| Pod / Service CIDR | `10.244.0.0/16` · `10.96.0.0/12` |
| Exam version | **v1.37** (LF page, checked 29 Oct — see §13) |

### 8.1 Snapshot inventory

| Snapshot | Version | SSH cp1→workers | `k` + completion in `.bashrc` | Tools | Use |
|---|---|---|---|---|---|
| **`lab-v137`** | 1.37.2 | ✅ | ✅ 3 nodes | crictl + yq 3 nodes · etcdctl/etcdutl **3.7.0** + helm 3.22.1 on cp1 | **Default — everything except upgrade** |
| **`lab-v136`** | 1.36.6 | ✅ | ✅ 3 nodes | crictl + yq 3 nodes · etcdctl/etcdutl **3.6.8** + helm 3.22.1 on cp1 | **Upgrade runs only** (→ 1.37.x) |
| `w3.cleanw3` | — | — | — | — | 1.2 (bare node) |
| `w3.prep137` | 1.37.2 held, not joined | — | ✅ | crictl + `crictl.yaml` + yq | 1.3 join · CNI sim B · 1.7 |

**Naming rule:** `lab-v<minor>` — the version says the purpose: **v136 = upgrade
source, v137 = everything else** (the exam's minor). `lab-v137` was built by
upgrading `lab-v136` with `kubeadm upgrade` (it is its child snapshot). The drill
line (`$do` + `.vimrc`) is **not** in either — it is typed per host, as in the exam
(§13). Holds on kubeadm/kubelet/kubectl present in both. Build scripts: **`lab/build/`**
in this repo (31 Oct; README there). Versions are resolved at build time = the
newest patch of each minor that an unpinned `apt-get install` gives that day — so
a later 1.2 run on `cleanw3` installs a newer patch than the cluster: **pin to the
cluster's version**.

**When the exam moves to the next minor** (LF aligns 4–8 weeks after each
Kubernetes release), change the two minors in `lab/build/build-lab.sh` and
`build-w3.sh`, then `CONFIRM=yes ./build-lab.sh && CONFIRM=yes ./build-w3.sh && ./verify-lab.sh`.

**Rules:** all three VMs, stopped, together — **for `snapshot`, `restore` and
`delete` alike** (a running VM locks its disk: `Failed to get shared "write" lock`).
A snapshot freezes what was installed before it — restoring an older one removes
tools. Before any snapshot: `rm -f ~/.vimrc && history -c && rm -f ~/.bash_history`.
Cycle **3 min + ~90 s convergence**; discard the first `get nodes`. Restore time
never counts in a drill. Commands: `cka-D1.md §0.3`.

**Traps, all hit for real:** restoring only cp1 · dots in snapshot names ·
multipass socket error for ~10 s after a restart · `busybox:1.36` NXDOMAIN on
short names → use **`busybox:1.28`** · `-w` hangs a timed drill · `apt upgrade` on a
node is forbidden · x509 "not yet valid" after a restore = **clock skew**, not certs
(expect this on Sat 17 Oct after 10 days stopped — `sudo systemctl restart
systemd-timesyncd` or wait).

### 8.2 Host isolation — non-negotiable (12 Sep)

**The host runs `multipass` and nothing else.** Every Kubernetes command is typed
inside a VM (`multipass shell cp1`); workers are reached **from cp1 by SSH**,
mirroring the exam. Every command block carries a banner — a block without one is
a defect, not a judgement call:

```
# ▶▶ HOST — cposada@cposada
# ▶▶ cp1  — ubuntu@cp1
# ▶▶ w1   — ubuntu@w1   (from cp1: ssh w1)
```

Guard before any `sudo` from a runbook: **`hostname`**. The host carries `kubectl`
1.36 (two minors out of skew) and a static `~/.kube/config` — both unused by rule.
Violated twice (13 Sep · 26 Sep). Full table: `cka-D1.md §0.1`.

Build runbook: `lab/lab-kubeadm-3-nodos-tutorial.md`. **Never practise on EKS.**

---

## 9. Files and notes

### 9.1 Layout (`§14` below) and roles

| Content | Home |
|---|---|
| Mechanisms, facts, EKS deltas | `notes/notes_01…11` — shared by all exams, read-only for CKA |
| How it is done, under a clock, with a machine | `cka/cka-D<n>*.md` — Template C |
| Schedule, decisions, progress | `plan.md` |
| Errors, practice scores | `claude/mistakes.md` |

### 9.2 CKA runbook files

| File | Bullets | Status |
|---|---|---|
| `cka-D1.md` | index: per-host line §0, scaffolding §0.1–0.4, drill table §7, scoreboard §8 | **r11 (26 Sep)** — §8 to be rewritten from the 17 Oct assessment |
| `cka-D1-1-install.md` | 1.2 · 1.3 · 1.7 | **r5 (26 Sep)** — all three ◐ until re-verified |
| `cka-D1-2-lifecycle.md` | 1.4 (upgrade, etcd, certs) · 1.4c · 1.5 read | **r7 (26 Sep)** — ◐ until re-verified |
| `cka-D1-3-access.md` | 1.1 · 1.6 · 1.8 | **in the project since 2 Oct, revision unknown** — learner confirms at the assessment whether it is a skeleton or a worked runbook |
| `cka-D2.md` … `cka-D5.md` | by official bullet | skeletons (12 Sep) — migrated to Template C the day each is worked |

⚙️ pre-written (commands not guessable) · ✍️ learner writes in the lab · a bullet
closes when done **twice in a row under target without looking**.
**Discarded approaches are deleted, not documented.**

### 9.3 Amendment queues from Block 1 — applied the day the bullet is worked

| Note | Applied with | Items |
|---|---|---|
| 07 | 1.1 RBAC — verify at the 17 Oct assessment whether applied on 27 Sep | `apiGroups: [""]` is an empty **string** · ResourceQuota (namespace aggregate) vs LimitRange (per container) · `create pods` ≈ read every Secret |
| 05 | 3.1/3.3/3.6 — Mon 19–Tue 20 Oct | per-Service rule table · inside/outside the Pod network + `hostNetwork` · veth + routes = no NAT · kubelet runs readiness, endpointslice controller copies it · no readiness probe ⇒ Ready at start |
| 06 | D4 — Sun 25 Oct | process death ≠ container deletion · `hostPath` defined · empty-matches-empty · no default class vs no CSI driver (events) · RWO per node, RWOP · `volumeClaimTemplates` = one PVC per replica · PID ns shared, mount ns not |
| 03 | 2.4 — Tue 27 Oct | PDB block |
| 08 | 5.4/5.5 — Sat 24 Oct | `CreateContainerConfigError` is after a successful pull · not-ready Pod stays in the EndpointSlice with `ready: false` · NotReady table around "is the kubelet talking" |
| 11 | — | KCSA-only; parked indefinitely |

### 9.4 Language

Every artefact in **English**. Questions may be in Spanish. Technical terms are
never translated. Files are edited **in place in this repo** and committed at
`cierre` (from 19 Oct; before that, delivered as attachments to the claude.ai Project).

---

## 10. CKAD (Sun 8 Nov – Fri 20 Nov), exam Sat 21 Nov

- Sun 8 Nov: CKA result lands; if ✅, open the CKAD chat the same day. Days 1–6:
  multi-container patterns, Jobs/CronJobs, probes, SecurityContext,
  ServiceAccounts, requests/limits, Deployments strategies.
- Days 7–13: blue/green and canary, Helm, Kustomize, API deprecations, speed drills.
- **Simulator A1 Sun 15 Nov · A2 Thu 19 Nov.**
- Done when: A2 ≥ 75% **and** ≥ 15 min to spare. Below that, sit it anyway (§5) —
  the retake fits Sat 28 Nov.
- Files: `ckad/ckad-D<n>.md`, Template C from line one. One spaced review per
  week for CKA D1 upgrade/etcd (CKS needs them, if CKS happens).

## 11. CKS (Sun 22 Nov – Sat 28 Nov), exam Sun 29 Nov — free shot

Sat only if **both** CKA (7 Nov) and CKAD (21 Nov) passed at the first attempt.
Cancelled the day any retake is needed. Seven days cannot cover the syllabus; the
week is spent on the highest-weight, most mechanical items so the shot is not blind:

- Cluster setup & hardening (15%): kube-bench run + fix the flagged API server /
  kubelet flags, NetworkPolicy default-deny, Ingress TLS.
- Cluster hardening (15%): RBAC least privilege, ServiceAccount token
  automount off, upgrade (already closed).
- Minimise microservice vulnerabilities (20%): PSA labels, SecurityContext,
  Secrets encryption at rest (`EncryptionConfiguration`), RuntimeClass/gVisor.
- Supply chain (20%): Trivy scan, image allow-list via admission, Dockerfile
  hardening.
- Monitoring/runtime (20%): Falco rules + output, audit policy, immutable
  containers (`readOnlyRootFilesystem`).
- **Simulator A1 Thu 26 Nov** (A2 not needed — the decision is already "sit").
- Files: `cks/cks-D<n>.md` + theory notes 12–14 (written only if the week exists).
- Re-read the CKS allowed-docs list (Falco, etcd, Cilium, …) on Sun 22 Nov.

---

## 12. Risks

| Risk | Status | Mitigation |
|---|---|---|
| **CKA pace** — 0/27 verified on 16 Oct, 21 days left | 🔴 | ~1.4 bullets/day; phase T banned for D1 re-verification; cut list pre-applied; checkpoints Sun 25 + Fri 30 Oct |
| **Repeat of the 6–16 Oct gap** (paid work) | 🔴 new | Zero-hour rule §1/§5; two lost weekend days reported that Sunday |
| **Closed runbooks decayed** during the gap | 🔴 | Assessment Sat 17 Oct; rotation rebuilt §6.3 |
| **Practice week not earned** | 🟠 | Fri 30 Oct checkpoint; Sat 31 falls back to bullets |
| **CKS** — 7 days, no retake | 🔴 accepted | Free shot only; never takes CKAD hours |
| **D1 + D5 = 55% on EKS-invisible material** | 🟠 | D5 break/fix Sun 18, Sat 24, Sat 31 |
| **Simulator burned early** | 🟡 | Same questions in both attempts — nothing opened before 1 Nov |
| **`LIT` / `READ` under a clock** | 🟠 | 10-min literals daily; read the task twice, state the verification before starting |
| **Wrong-machine execution** | 🟡 | §8.2 banners + `hostname` guard |
| **`mistakes.md` rows 27–56 and 82–88 missing** | 🔴 | Re-upload local copy |
| **Scope drift** (Istio, Kyverno, ArgoCD, Terraform) | 🟡 | Out until 1 Dec |

---

## 13. Exam environment and shell setup — verified 26 Sep against the LF page

Source: *Important Instructions: CKA and CKAD* (docs.linuxfoundation.org,
updated mid-Sep 2026). Re-read it the week of the exam.

**What the exam gives you.** Every task runs on a **designated SSH host** named in
the task's infobox. Every SSH host ships **`kubectl` with the `k` alias and Bash
completion already configured**, plus `yq`, `curl`/`wget` and man pages. The
**base** system (hostname `base`) has **none** of these. You `ssh <host>`, work,
and **`exit` back to base**. **Nested ssh is not supported.** `sudo -i` gives root
on any host. The CKA environment runs **v1.37** (*"The CKA environment is currently
running Kubernetes v1.37"* — LF page, checked 29 Oct; it was v1.35 on 26 Sep).

**Which upgrade the task asks for — inference, not official.** The LF does not
publish it. Candidate reports say the upgrade task hands you a cluster **one minor
below the exam** and asks for the exam's minor — today **1.36 → 1.37**. It is
consistent with kubeadm's own rule (*"Skipping MINOR versions when upgrading is
unsupported"*) and with the current upgrade page on kubernetes.io (1.36.x → 1.37.x).
The mechanism is identical across minors (repo → kubeadm → `upgrade apply`/`node` →
drain → kubelet + kubectl → uncordon); what changes are the **literals**: the minor in
the `.list` URL, the apt versions and the etcd image. Drill it from `lab-v136`.

**Rule: setup per host, not per exam.** Nothing survives an `exit`: your exports
and `~/.vimrc` die with the session. So:

| When | What |
|---|---|
| At exam start, on `base` | **Nothing.** No kubectl there; setup is wasted |
| Entering a host where you will **generate or edit YAML** | one line, target **10 s**: `export do="--dry-run=client -o yaml"; printf 'set ts=2 sw=2 et ai\n' > ~/.vimrc` |
| Purely imperative task (scale, label, set image, drain, upgrade, etcd) | **skip the setup** |
| Verify | `k run t --image=nginx $do \| head -3` prints `apiVersion: v1` |

`k` and completion are **never typed in the exam** — they are preconfigured.
The lab mirrors the exam: alias and completion live permanently in `~/.bashrc` on
**all three** nodes; only the per-host line is drilled.

**Nested ssh changes the multi-node procedures.** From cp1, `ssh w1` is nested. In
the exam: finish on the CP host → `exit` to base → `ssh w1` → work → `exit` → back
to the CP host for `uncordon`. The runbooks say this explicitly.

**Keyboard and desktop.** `Ctrl+Alt+W`, never `Ctrl+W` · terminal copy/paste
`Ctrl+Shift+C / V`, other apps `Ctrl+C / V` · **INSERT key is prohibited** — enter
insert mode in vim with `i` · never reboot `base` · docs live in a **Firefox inside
the remote desktop**, so local bookmarks do not exist · Firefox `Ctrl+F` finds in
page · zoom with the PSI toolbar `+`/`−`.

**Allowed docs (CKA):** kubernetes.io/docs and its search box (no external search
results), the Kubernetes blog, Helm docs, the task's Quick Reference links, and
**Gateway API docs (CKA only)**. The CKS list differs (Falco, etcd, Cilium, …) —
re-read it before CKS.

### 13.1 Docs keyword map — the substitute for bookmarks

Drill: pick one at random, time from typing in the search box to the YAML block on
screen (`Ctrl+F` inside the page). **Target 30 s.** Part of the warm-up.

| Search box | Page to open |
|---|---|
| `etcd backup` | Operating etcd clusters for Kubernetes |
| `kubeadm upgrade` | Upgrading kubeadm clusters |
| `static pod` | Create static Pods |
| `network policy` | Network Policies |
| `persistent volume pod` | Configure a Pod to Use a PersistentVolume for Storage |
| `rbac` | Using RBAC Authorization |
| `csr` | Certificates and Certificate Signing Requests |
| `taints` | Taints and Tolerations |
| `node affinity` | Assigning Pods to Nodes |
| `ip_forward` | Container Runtimes (sysctl prerequisites) |
| `cheatsheet` | kubectl Quick Reference |

Extend it the day each domain is worked; one row per page you actually needed.

**Other exam rules kept:** no `$now` (a forced delete destroys evidence) · no
`kubectx`/`kubens` · no alias you have not drilled.

---

## 14. Folder layout (adopted 16 Sep)

```
kubestronaut/
├── plan.md
├── claude/   session-protocol, mistakes, depth-standard, sources, note-templates, note-prompt-template
├── notes/    notes_01–11 (+12–14 only if CKS week happens) — shared by all exams
├── kcna/     kcna-curriculum.md                               ✅ closed
├── cka/      cka-curriculum.md, cka-bashrc.sh, cka-D1 (+ -1/-2/-3), cka-D2…D5
├── ckad/     created Sun 8 Nov
├── cks/      created Sun 22 Nov, if at all
├── lab/      lab-kubeadm-3-nodos-tutorial.md
└── tools/    checkrefs.py, semcheck.py
```

`kcsa/` will not be created. Local repo and project hold the same tree; **the local
copy wins on conflict.**

---

## 15. Progress log

| Date | Block | Hours | What was done | Conf |
|---|---|---|---|---|
| 08-14 → 09-10 | KCNA | ~— | Notes 01–11 written + recalled (67–100%); cluster built 31 Aug; 14 days lost in Aug. Detail: git history | — |
| **09-11** | **KCNA** | — | **PASSED, 88%** | — |
| 09-12 (s1–s3) | CKA | — | Plan B′; resource roles; `cka-D1…D5` created; lab audited, host isolation §8.2, snapshot mechanics; shell block fixed | — |
| 09-14 | CKA | — | D1 split into index + 3 content files; upgrade runs A1 35:00 · A2 18:00; `base-v134` lesson | — |
| 09-16 | CKA | — | **Teach-first adopted.** etcd phase T; tools installed; folder layout | — |
| 09-17 | CKA | 3.0 | **1.4b proven** (safe path); in-place variant **discarded** (watch cache, diagnosed by learner); upgrade A3 24:00 (3 nodes); rows 82–88 | — |
| 09-18 → 22 | CKA | _owed_ | **`cka-D1-2-lifecycle.md` completed** — upgrade, etcd save/restore, certificates | _owed_ |
| 09-19 | CKA | ~3.0 | **§C executed** (`renew apiserver` then `renew all`, restart, re-copy `admin.conf`) · **1.4c executed** on w2 · **1.5 read** · boot block A1 1:20 vs 0:45 · handwritten rehearsal: structure perfect, 11 literals | — |
| 09-23 | CKA | _owed_ | **1.2 closed** — node prep rebuilt after two runs on `w3`; `cka-D1-1-install.md` r2 | _owed_ |
| **09-26** | CKA | — | **D1-1 session on `w3`.** 1.2 A1 9:33 · 1.3 decommission < 3:00, join 0:56 · stale `/etc/cni/net.d/` after `kubeadm reset` · `kubeadm init` + Calico 9:26 · **CNI sim B blind 3:24** · Pod CIDR three sources (`describe node` = the node's `/24` slice) · 1.7 `crictl`, conflist `type` → binary, `/opt/cni/bin` ≠ CNI in use · sim A solved after coaching · host-isolation slip #2 | — |
| **09-26** | CKA | — | **Lab bases rebuilt:** `lab-v135` (1.35.9) and `lab-v134` (1.34.11); inventory `lab-v134` · `lab-v135` · `cleanw3` | — |
| **09-26** | CKA | — | **Upgrade R2: 18:00** (3 nodes); held-package flag removes the holds → runbook r9 re-holds per node; 8 literals (row 91); kubelet restart typo masked by `needrestart` (row 92) | — |
| **09-26** | CKA | — | **Exam environment verified** against the LF page: `k` + completion preconfigured per SSH host, none on `base`, nested ssh unsupported → setup per host; docs keyword map §13.1 | — |
| **09-26** | CKA | — | **Upgrade R1** from `clean-v134` → 1.35.9, cp1 + w1: 20:00 wall vs 12:00 | — |
| **09-26** | CKA | — | **CKA → Sun 18 Oct. KCSA dropped.** Plan v4 | — |
| 09-27 | CKA | _owed_ | D1-3 session: **1.1 RBAC · 1.6 Helm + Kustomize · 1.8 CRDs** worked (learner-reported 27 Sep; state not recalled on 16 Oct → re-verify 17 Oct). `cka-D1-3-access.md` uploaded 2 Oct | _owed_ |
| 09-28 → 10-05 | CKA | _unknown_ | Possibly some D3 (3.1/3.3/3.6). To confirm at the assessment | — |
| **10-06 → 10-16** | — | **0** | **~10 days with zero hours** — higher-priority paid obligations. CKA 18 Oct not sat. Mock A (10 Oct) and killer.sh A1/A2 (11/14 Oct) did not happen | — |
| **10-16** | plan | — | **CKA rescheduled → Sat 7 Nov.** CKAD Sat 21 Nov, CKS Sun 29 Nov (free shot). **Expiration of CKA, CKAD, CKS confirmed 30 Nov** (open item since 1 Sep closed). Go/no-go rewritten: A2 ≥ 60% sit, < 60% move to 14 Nov. Practice week 31 Oct – 6 Nov conditional on Fri 30 Oct. **Plan v5.0** | — |
| **10-29** | lab | — | **Exam now v1.37** (LF page). Lab moved to the laptop (WSL) and **rebuilt**: `lab-v136` (1.36.5, upgrade source) + `lab-v137` (1.37.1, default), Calico 3.33.0, yq added (exam ships it); 1.34 reached EOL 27 Oct. Old `lab-v134`/`lab-v135` retired. **Literal refresh owed** in `cka-D1-2-lifecycle.md` (drill still 1.34 → 1.35.8) | — |
| **10-31** | CKA | _owed_ | **D1-1 session (laptop, `w3` + cp1).** Stage-2 shape format adopted. **1.2:** run 2 no card **9:11** (target 10:00) · blind break/fix **3:59** (4:00) · recall 1/3 (rows 96–98) · runbook r6. **1.3:** stages 1–4 on v1.37 + Calico 3.33 — join 5:33 ❌ → **2:42 ✅** (+ desktop run ✅) · decommission **3:10 ✅** → join and decommission closed · CNI with a hidden CIDR: config 3:46 but declared done without `tigerastatus` (row 106) · Calico ready only at 16:16 on a 2-CPU node. **1.7:** stages 1–3 + card; sim A coached ×2 on cp1 (cert path typo 10:27 · YAML indent). Measured: v3.33 operator installs its own CRDs; `Ready` = CNI conflist exists; `kubeadm reset` keeps images; cri-dockerd v0.4.10 `.deb` inspected. **Lab rebuilt** (`lab/build/`): `lab-v136` 1.36.6 · `lab-v137` 1.37.2 · `w3.prep137`; new IPs (§8). Next: 1.7 clean blind sim A · cri-dockerd sim (docker.io on `w3`, then restore `prep137`) · §9 Set 2 · R1 Mon 2 Nov (1.2 + CNI with proof) · D1-2 / D1-3 in their own sessions | _owed_ |
| **11-01** | lab | — | **Versions re-verified against official sources:** LF pages — CKA **v1.37**, CKAD v1.37, CKS v1.35; `cncf/curriculum` CKA v1.37 PDF (15 Oct) **text identical to v1.35**; newest patches 1.36.6 / 1.37.2 (no 1.38 yet); etcd 3.6.8 / 3.7.0 (kubeadm constants). **Literal refresh done:** `cka-D1-2-lifecycle.md` r10 (drill 1.36.6 → 1.37.1 from `lab-v136`), `cka-D1.md` r13, D2–D5, curriculum. **Desktop lab rebuilt** with `lab/build/` (same versions as the laptop) — 3 runs: acceptance raced DNS, then `tigerastatus` (fast host); fixed with a DNS retry and `kubectl wait … tigerastatus/calico`. `w3` IP no longer hardcoded | — |

**Owed:** hours + confidence for 14–23 Sep and 27 Sep; the 18–23 Sep drill times for
`cka-D1.md §7`; the 28 Sep – 5 Oct record (what, if anything, was done).
