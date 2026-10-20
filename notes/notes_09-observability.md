---
exams: [KCNA, CKAD, CKS]
domain: Observability
kcna_domains: 4.1 Observability
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: prometheus.io/docs (introduction/overview, concepts/metric_types, prometheus/latest/querying/basics, alerting/latest/overview), opentelemetry.io/docs (concepts/signals, collector), jaegertracing.io, fluentbit.io, kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline, grafana.com/docs (shallow — visualisation layer only), opencost.io
template: B
language: en
scope: KCNA ONLY — CKAD/CKS layers appended later
status: draft
revised: 2026-09-06 rev3 — 9 amendments from the note 09 recall session (§1.1, §1.2, §1.4, §1.5, §1.9) plus 6 new traps. SUPERSEDES rev2.
prior_revision: 2026-09-05 rev2 — 3 stale cross-refs into note 03 corrected to §1.11.
written: 2026-09-05
format: per claude/depth-standard.md AMENDMENT 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). CNCF maturity verified this session — **OpenTelemetry GRADUATED 21 May 2026** (it was incubating for seven years; sources older than mid-2026 still say incubating). Prometheus graduated 2018, Fluentd 2019, Jaeger 2019.
---

# Observability

*Monitoring tells you the thing you already knew to watch is broken.
Observability lets you ask a question you did not think of in advance.*

KCNA area 4.1 sits in Domain 4 (Cloud Native Architecture, 12%) and is worth
roughly **4–5 of the 60 questions**. It is heavily vocabulary-driven — the exam
asks what each tool *is* far more than how to run it.

---

## 1. Core Concepts

### 1.1 Observability is not monitoring

*Monitoring answers questions you wrote down beforehand. Observability lets you
ask new ones without shipping new code.*

| | Monitoring | Observability |
|---|---|---|
| Answers | **Known unknowns** — "is CPU above 80%?" | **Unknown unknowns** — "why are only Canadian users on the new build slow?" |
| Set up by | Predefining dashboards and alerts | Emitting rich, high-cardinality telemetry |
| Question shape | Fixed, decided in advance | Arbitrary, decided during the incident |
| Fails when | Something breaks that nobody predicted | The data was never emitted |

**Observability is a property of the system, not a product you install.** A
system is observable if its external outputs let you infer its internal state.
Monitoring is one *activity* you perform on an observable system.

The exam framing is usually the phrase "known unknowns versus unknown unknowns" —
that pairing is the giveaway for this question.

**Same stack, opposite outcome.** Two teams run identical Prometheus + Grafana on
the same application version. Team A answers "why are payments failing only on
Android?" in two minutes. Team B needs three days. The difference is not the
tooling — it is whether the application was already emitting `payment_method`,
`platform`, `region` and `build_version`. Tools consume telemetry; they never
create it.

**The telemetry has to have been emitted before the incident.** If answering the
new question requires adding instrumentation and deploying, the system was not
observable — and the real cost is not the code change, it is **waiting for the
failure to happen again** in order to see it. Observability is lost at design
time, not during the investigation.

**Instrumentation richness is not the same as cardinality.** Richness is *how
many attributes you emit*; cardinality is *how many distinct series those
attributes produce* (§1.2). High cardinality is what makes a system observable —
but only in logs and traces. Pushed into metric labels it destroys Prometheus,
which is the subject of the next section.

### 1.2 The three pillars

*Metrics say something is wrong. Logs say what happened. Traces say where in the
system it happened.*

| Pillar | Is | Answers | Cost | Cardinality |
|---|---|---|---|---|
| **Metrics** | **Numbers over time**, aggregated | "**Is** something wrong? How much, how often?" | **Cheap** — pre-aggregated | Must stay **low** |
| **Logs** | **Discrete events**, usually text | "**What** happened, exactly?" | **Expensive** — volume grows with traffic | Arbitrary |
| **Traces** | **One request's path** across services | "**Where** did the time go, and which hop failed?" | Expensive — usually **sampled** | High |

The normal incident flow uses all three in order:

```
Metric alert fires        "error rate is 12%, up from 0.1%"      → SOMETHING is wrong
      │
      ▼
Trace a failing request   "of 9 hops, checkout→payments took 8s" → WHERE it is wrong
      │
      ▼
Logs from that service    "connection pool exhausted at 09:14"   → WHAT is wrong
```

**Cardinality is the concept that separates metrics from the other two.** Every
distinct label combination is a separate time series, so putting a user ID or a
request ID in a metric label creates millions of series and destroys the
database. Those identifiers belong in **logs and traces**, which are built for
them. This is the single most common architectural mistake in the domain.

**Why the cost behaves differently.** In metrics, cardinality is
**multiplicative**: `status` (5) × `method` (4) × `endpoint` (50) = 1,000 series,
and adding `user_id` with a million values makes a billion — each held in memory
permanently, queried or not. In logs and traces the cost is **linear with
volume**: a log line carrying `user_id` is one more line, creating nothing
permanent. That asymmetry is why unique identifiers belong in logs and traces.

**Logs do not substitute for traces**, even with logs from every service. Log
lines are **not correlated across services** — nothing in them says two lines
belong to the same request — and they record the *time of an event*, not the
*duration of each hop*. A trace carries a shared **trace ID** through every
service (§1.9) and measures each hop as a span.

**Volume, unlike cardinality, is what you tune in logs and traces:**

| Lever | Effect |
|---|---|
| **Sampling** (traces) | Keep a fraction — 1 in 100. The canonical answer for traces |
| **Log levels** | `INFO` in production, `DEBUG` only while investigating |
| **Retention** | Metrics months, logs 7–30 days, traces days |
| **Collector filtering** | Fluent Bit / OTel Collector drop noise before the backend bills for it |
| **Structured logging** (JSON) | Does not shrink volume, but makes it queryable |

**Sampling is why traces cannot answer about one specific customer.** At 1%, a
complaint about one payment at 09:14 will almost certainly have no trace. Logs
keep every occurrence, so they are the signal for the individual case — provided
they carry the identifier to filter on.

### 1.3 Prometheus and the pull model

*Prometheus goes and fetches your metrics on a schedule. Your application does
not send them anywhere.*

**Prometheus** is a CNCF **graduated** project — the second ever to graduate,
after Kubernetes, in 2018 — and it is the de facto metrics system for Kubernetes.

**Pull, not push.** Prometheus **scrapes** an HTTP endpoint, conventionally
`/metrics`, on each target at a fixed interval. The application merely exposes
current values and never knows who is reading them.

| Pull (Prometheus) | Push (StatsD, many SaaS agents) |
|---|---|
| The server decides when to collect | The client decides when to send |
| **Scrape failure is itself a signal** — the target is down | A silent client is indistinguishable from a healthy quiet one |
| Targets found by **service discovery** | Every client must be configured with a destination |
| Easy to run a target by hand: `curl localhost:9100/metrics` | Harder to inspect in isolation |

**The exception that proves the rule:** a Job or CronJob (note 03 §1.7) may
finish before any scrape happens. For those, the **Pushgateway** exists — a
holding area a short-lived job pushes to and Prometheus scrapes. It is the
documented exception, not an alternative style.

### 1.4 The Prometheus architecture

*A scraper with a time-series database, a query language, and a separate
component whose only job is to send the alert somewhere.*

```
     ┌── service discovery (Kubernetes API: pods, services, nodes)
     │
     ▼
┌────────────┐  scrapes /metrics   ┌─────────────────────────────┐
│ Prometheus │ ──────────────────► │ targets: apps, exporters    │
│  server    │                     │ node-exporter, kube-state-… │
│  + TSDB    │                     └─────────────────────────────┘
└─────┬──────┘◄── PromQL queries ── ┌──────────────┐
      │                             │   Grafana    │  visualisation only
      │ evaluates alerting rules    └──────────────┘  — stores nothing
      ▼
┌──────────────┐   grouping, dedup, silencing, routing
│ Alertmanager │ ──────────────────────────────► email, Slack, PagerDuty
└──────────────┘
```

| Component | Does |
|---|---|
| **Prometheus server** | Scrapes, stores in its **local TSDB**, evaluates rules |
| **Exporters** | Translate something that does not speak Prometheus into `/metrics` |
| **Alertmanager** | **A separate process.** Receives fired alerts and handles grouping, deduplication, silencing and routing |
| **Service discovery** | Asks the **Kubernetes API** what to scrape, so new Pods are picked up automatically |
| **Grafana** | Dashboards. Queries Prometheus; holds no data |

**Alertmanager being separate is exam-relevant.** Prometheus decides *whether* an
alert fires by evaluating a rule; Alertmanager decides *who is told, how often,
and whether to stay quiet*. Two responsibilities, two processes.

**Exporters worth naming:**

| Exporter | Exposes | Runs as |
|---|---|---|
| **node-exporter** | Host-level metrics: CPU, memory, disk, network | A **DaemonSet** — one per node (note 03 §1.5) |
| **kube-state-metrics** | The **state of Kubernetes objects**: replicas desired vs ready, Pod phase, job status | A **Deployment** — one instance is enough |
| blackbox-exporter | Probes endpoints from outside | A Deployment |

### 1.5 The four metric types

*Two are single numbers; two are distributions. The split that matters is
counter versus gauge.*

| Type | Behaviour | Example | Use |
|---|---|---|---|
| **Counter** | **Only ever increases**, or resets to 0 on restart | `http_requests_total` | Rates — "requests per second" |
| **Gauge** | Goes **up and down** | `memory_bytes`, `queue_depth`, temperature | Current value at a moment |
| **Histogram** | Counts observations into **buckets**; quantiles computed **server-side** | `http_request_duration_seconds` | Latency distributions, aggregatable |
| **Summary** | Quantiles calculated **client-side** | Same shape | When the client must decide the quantiles |

**Counter vs gauge is the near-guaranteed question.** A counter never goes down,
so its raw value is meaningless — what you want is its *rate of change*. A gauge
is meaningful as-is.

**Histogram vs summary** comes down to where the quantile is computed. Histogram
buckets can be **added together across instances**; client-computed summary
quantiles **cannot** be averaged meaningfully. That makes histograms the default
choice in a distributed system.

**Why a quantile cannot be averaged — with numbers.** Three replicas:

| Replica | Requests in window | Its p95 |
|---|---|---|
| A | 1,000, all fast | 100 ms |
| B | 1,000, all fast | 100 ms |
| C | 10, all slow (odd traffic) | 5,000 ms |

Averaging the three p95s gives **1,733 ms**. The true p95 over all 2,010 requests
is about **100 ms** — 10 slow requests are nowhere near the top 5%. The average is
not approximate, it corresponds to nothing. Weighting by request count does not
fix it: a percentile depends on the whole distribution, and replica A destroyed
its distribution the moment it collapsed 1,000 requests into one number.

A histogram collapses nothing. Each replica reports raw bucket counts, the counts
**add up legitimately** ("how many requests under 0.5 s across the service"), and
the server computes the quantile **once, over the real combined distribution** —
which is exactly what `histogram_quantile(0.99, sum(rate(..._bucket[5m])) by (le))`
does.

| | Histogram | Summary |
|---|---|---|
| Quantile computed | **Server-side** | **Client-side** |
| Aggregatable across instances | **Yes** | **No** |
| Accuracy | **Approximate** — interpolated within pre-chosen buckets | Exact, for that one instance |
| Default in a distributed system | **Yes** | No |

The histogram is *less* accurate per instance and still the right answer in
Kubernetes, because there is always more than one replica.

**The pattern that follows:** a metric tells you **how many** bad cases there
were; logs and traces tell you **who** they were. To alert on "any payment over
30 s" you do not need `user_id` — you need a bucket at `le="30"`. Ten series
instead of a million.

### 1.6 PromQL, at the level KCNA asks

*You will not write queries in the exam. You should recognise what these do.*

```promql
up                                          # 1 or 0 per target — is it being scraped?
container_memory_usage_bytes                # a gauge, raw
rate(http_requests_total[5m])               # per-second rate of a COUNTER over 5 min
sum(rate(http_requests_total[5m])) by (pod) # that rate, aggregated per pod
histogram_quantile(0.95, sum(rate(
  http_request_duration_seconds_bucket[5m])) by (le))   # p95 latency
```

The one to internalise is **`rate()` applied to a counter**. Because counters only
climb, you almost never graph one directly — `rate()` converts "total ever" into
"per second right now", and it also handles the reset to zero when a Pod
restarts.

### 1.7 metrics-server vs Prometheus vs kube-state-metrics

*Three things that produce numbers about a cluster, constantly confused. Only one
of them powers `kubectl top`.*

| | **metrics-server** | **Prometheus** | **kube-state-metrics** |
|---|---|---|---|
| Provides | **Current** CPU/memory of Pods and nodes | Full metrics platform | **Object state** as metrics |
| Storage | **In memory only. No history** | TSDB on disk | None — it is an exporter |
| Powers | **`kubectl top`** and the **HPA** | Dashboards, alerts, analysis | Scraped *by* Prometheus |
| Answers | "How much CPU is this Pod using **now**?" | "What was it last Tuesday?" | "How many replicas are desired vs ready?" |
| Installed by default? | **No** — not on kubeadm | No | No |

Three consequences:

- **`kubectl top` fails with "Metrics API not available" until metrics-server is
  installed.** On your kubeadm cluster it is not there. That error is a missing
  component, not a broken cluster.
- **The HPA depends on metrics-server**, so autoscaling on CPU does not work
  without it either.
- **kube-state-metrics is not about resource usage at all.** It reports the
  *state of API objects* — Deployment replicas, Pod phase, Job completion. It is
  how you alert on "a Deployment has had 0 ready replicas for 5 minutes", which
  no amount of CPU data would tell you.

### 1.8 Logs

*Kubernetes keeps whatever the container wrote to stdout, on the node, until the
container is gone. That is not a logging system.*

Note 08 §1.8 covered reading logs. The architectural problem is what happens
after: container logs live on the node's disk, are rotated, and **vanish with the
container**. Anything longer-lived needs shipping elsewhere.

The standard pattern is a **collector DaemonSet** — one per node, reading every
container's log files and forwarding them to a backend.

| Tool | Note |
|---|---|
| **Fluentd** | CNCF **graduated** (2019). Feature-rich, Ruby, heavier |
| **Fluent Bit** | Lighter C rewrite, now the usual choice on Kubernetes |
| Logstash, Vector | Common non-CNCF alternatives |

Backends store and index: Elasticsearch/OpenSearch, Loki, or a cloud service.

**Applications should log to stdout/stderr, not to files.** A file inside the
container is invisible to `kubectl logs` and to the collector, and it dies with
the writable layer (note 04 §1.10). This is one of the twelve-factor principles
that note 11 covers.

### 1.9 Traces

*A trace follows one request across every service it touches, so you can see
which hop consumed the time.*

Metrics and logs are both per-service. In a microservice system the interesting
question — *where did those 8 seconds go?* — spans services, and neither can
answer it.

| Term | Is |
|---|---|
| **Trace** | The whole journey of one request |
| **Span** | **One operation** within it — one service call, one query |
| **Trace ID** | A shared identifier carried by every span of that request |
| **Context propagation** | Passing the trace ID **in headers** between services, so the spans join up |

```
Trace  (trace_id=abc123, total 8.2s)
├── span: api-gateway            120ms
│   └── span: checkout-service   8000ms   ◄── the culprit
│       ├── span: payments-api   7900ms
│       └── span: cache-lookup      3ms
└── span: response                80ms
```

**Context propagation is what makes tracing work, and it is the part that fails.**
If one service does not forward the trace headers, the trace **breaks at that
hop**. What comes after does not vanish — it arrives with a fresh trace ID and
shows up as **orphan traces**, disconnected from the request that caused them.
The symptom is *fragmented* traces, not missing ones, which is harder to notice:
everything looks fine until you realise no trace reaches the far end of the path.
The headers are `traceparent` (W3C) or the older `b3-*`.

**Propagation is the application's job, not the infrastructure's.** A proxy or
sidecar sees requests entering and leaving the Pod but cannot know which outbound
call was caused by which inbound one — that link exists only inside the
application process. The app must copy the trace context headers from the inbound
request onto every outbound call, even when it emits no spans of its own. That is why an instrumentation standard
matters more than any particular backend.

**Jaeger** is the CNCF **graduated** (2019) tracing backend — collects, stores and
visualises traces. Sampling is normal: tracing every request is prohibitively
expensive.

### 1.10 OpenTelemetry

*One vendor-neutral standard for producing all three signals, so changing your
analysis tool does not mean re-instrumenting your code.*

Before OTel, every observability vendor shipped its own instrumentation
libraries. Switching tools meant rewriting instrumentation across every service —
a lock-in problem, not a technical one.

**OpenTelemetry (OTel)** was formed by merging **OpenTracing and OpenCensus**, and
covers **metrics, logs and traces** in one specification. It **graduated in CNCF
on 21 May 2026**, and has the **second-highest project velocity in CNCF after
Kubernetes**.

| Part | Does |
|---|---|
| **Specification** | Defines the signals and semantic conventions |
| **SDKs / APIs** | Per-language libraries your code calls |
| **Collector** | A separate process that **receives, processes and exports** telemetry to any backend |
| **OTLP** | The wire protocol |

The division of labour is the exam point:

> **OpenTelemetry produces and transports telemetry. Prometheus, Jaeger and
> Grafana store and display it.** They are complementary, not competing —
> instrument once with OTel, export to whichever backend you like.

### 1.11 Grafana

*The dashboard layer. It queries other systems and stores nothing itself.*

Grafana visualises data from Prometheus, Loki, Jaeger, Elasticsearch, SQL
databases and more, in one place. **It is not a database** and does not collect
anything — a distractor sometimes claims Grafana stores metrics, and it does not.

It is also **not a CNCF project** (Grafana Labs maintains it), unlike almost
everything else in this note.

### 1.12 SLI, SLO, SLA and error budgets

*A measurement, a target, and a contract — in that order of increasing
consequence.*

| Term | Is | Example |
|---|---|---|
| **SLI** — Service Level **Indicator** | The **measurement** | "99.3% of requests succeeded in the last 30 days" |
| **SLO** — Service Level **Objective** | The **internal target** | "99.9% of requests must succeed" |
| **SLA** — Service Level **Agreement** | The **contract with a customer**, with **financial consequences** | "99.5%, or you get a refund" |

```
SLI  = what you MEASURE      (a number)
SLO  = what you AIM for      (a target, internal)
SLA  = what you PROMISE      (a contract, with penalties)

SLO is normally STRICTER than the SLA — you want to notice trouble
before it becomes a refund.
```

**The error budget is the derived idea and the reason SLOs are useful:**

```
error budget = 100% − SLO
99.9% SLO  →  0.1% budget  →  ≈ 43 minutes of failure per 30 days
```

Budget remaining is permission to take risk. Plenty left, ship the risky release;
spent, freeze features and fix reliability. It converts "how careful should we
be?" from an argument into a number.

**Distinguishing the three is a near-guaranteed KCNA question.** The mnemonic
that survives pressure: **I**ndicator = what **I** measure, **O**bjective = the
**O**bjective we aim at, **A**greement = the **A**greement someone can sue over.

### 1.13 FinOps and cost management

*Cloud cost is an engineering metric, and the exam does ask about it.*

FinOps is the practice of making cloud spend **visible, attributable and
optimisable** — a collaboration between engineering, finance and business rather
than a tool.

| Phase | Means |
|---|---|
| **Inform** | Visibility and **allocation** — who spent what |
| **Optimise** | Rightsizing, autoscaling, spot instances, removing waste |
| **Operate** | Continuous improvement, ownership, governance |

Kubernetes makes cost allocation genuinely hard: many teams share nodes, so the
bill arrives per instance, not per team. **OpenCost** is the CNCF project that
allocates cluster cost down to namespace, Deployment and Pod.

The Kubernetes-specific lever is **requests and limits** (note 03 §1.11). The
scheduler reserves capacity based on **requests**, so requests set far above real
usage mean you pay for nodes that sit nearly idle. Rightsizing requests is the
single largest cost lever in most clusters — and it is invisible without metrics,
which is why this belongs in the observability domain at all.

---

## 2. Objects & Fields That Matter

| Thing | Note |
|---|---|
| `/metrics` | Conventional scrape endpoint. Plain text |
| `kubectl top pods` / `top nodes` | **Requires metrics-server.** Not installed by default |
| Metrics API | `metrics.k8s.io` — served by metrics-server, consumed by `kubectl top` and the HPA |
| node-exporter | **DaemonSet** — host metrics |
| kube-state-metrics | **Deployment** — object-state metrics |
| Alertmanager | Separate process: grouping, dedup, silencing, routing |
| OTel Collector | Receives, processes, exports. Runs as a DaemonSet or Deployment |
| Trace context | Propagated in **HTTP headers** |
| Error budget | `100% − SLO` |

---

## 3. Speed Patterns

*Empty during the KCNA block.*

---

## 4. Hands-On Lab

**Target: 20 minutes.** Mostly reading real endpoints rather than installing a
stack — a full Prometheus install is out of scope for KCNA.

```bash
# 1. kubectl top fails, and the error names the reason                 (3 min)
kubectl top nodes            # "Metrics API not available" — metrics-server absent

# 2. Look at a real /metrics endpoint                                  (7 min)
kubectl get --raw /metrics | head -40          # the API server's own metrics
kubectl get --raw /metrics | grep "^# TYPE" | head -20   # counter/gauge/histogram

# 3. Find a counter and a gauge and tell them apart                    (5 min)
kubectl get --raw /metrics | grep "^# TYPE.*counter" | head -5
kubectl get --raw /metrics | grep "^# TYPE.*gauge"   | head -5
# ask of each: could this number ever go DOWN?

# 4. Prove logs are ephemeral and node-local                           (5 min)
kubectl run noisy --image=busybox:1.36 --restart=Never \
  -- sh -c 'for i in 1 2 3 4 5; do echo "line $i"; sleep 1; done'
sleep 8
kubectl logs noisy                     # visible now
kubectl delete pod noisy
kubectl logs noisy                     # gone forever. THIS is why collectors exist
```

---

## 5. Verification

```bash
kubectl top nodes; kubectl top pods -A          # needs metrics-server
kubectl get --raw /metrics | head
kubectl get apiservices | grep metrics          # is the Metrics API registered?
kubectl get pods -n kube-system | grep -i metrics
kubectl logs <pod> --timestamps
```

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `kubectl top` → "Metrics API not available" | **metrics-server not installed** | `kubectl get apiservices \| grep metrics` | Install metrics-server |
| HPA shows `<unknown>` for CPU | Same missing component | `kubectl describe hpa` | Install metrics-server |
| Prometheus target `DOWN` | Endpoint unreachable, wrong port, NetworkPolicy | Prometheus Targets page | Fix the service/port; note 05 §1.12 |
| Prometheus running out of memory | **High-cardinality labels** — IDs used as labels | Check series count | Move identifiers to logs/traces |
| A graph of a counter looks meaningless | Graphing the raw total | — | Wrap it in `rate()` |
| Logs gone after a Pod is deleted | Container logs are node-local and ephemeral | `kubectl logs <deleted pod>` | Ship them with a collector DaemonSet |
| App runs but `kubectl logs` is empty | It writes to a file, not stdout | `kubectl exec -- ls /var/log` | Log to stdout |
| A trace stops halfway | **Context not propagated** by one service | Inspect trace headers | Instrument that service |
| Alerts fire correctly but nobody is paged | Alertmanager misrouted or silenced | Alertmanager UI | Fix routing — it is a separate component |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| `kubectl top` | Also needs metrics-server, but it is a one-click **add-on** and usually already there | **Nothing is installed.** `kubectl top` fails until you install it yourself |
| Logs | Often shipped to **CloudWatch** automatically, retained for weeks | `kubectl logs` only, node-local, **dies with the container** |
| Metrics stack | Managed Prometheus (AMP) and Managed Grafana, or CloudWatch Container Insights | **You run Prometheus, Alertmanager and Grafana yourself**, including storage |
| Control plane metrics | You **cannot scrape** the API server, scheduler or etcd — control plane logging to CloudWatch is opt-in | You scrape their `/metrics` endpoints directly. **The control plane is yours to observe** |
| Cost attribution | Cost Explorer, tags, per-instance billing | **OpenCost** or nothing. Nobody sends you a bill for your lab |

The habit to unlearn: on EKS, telemetry mostly exists before you ask for it, and
the control plane is a black box you can only receive logs from. On kubeadm
nothing exists until you install it — and in exchange, every control plane
component will answer `/metrics` if you ask.

---

## 8. Timed Drills

*Empty during the KCNA block.*

---

## 9. Objectives Covered

KCNA area **4.1 Observability**.

- [ ] The three pillars: metrics, logs, traces — and what each answers
- [ ] Observability ≠ monitoring; known vs unknown unknowns
- [ ] Prometheus: the **pull** model, exporters, Alertmanager, service discovery
- [ ] Metric types: counter, gauge, histogram, summary
- [ ] Basic PromQL: `rate()` on a counter, `up`
- [ ] Grafana as the visualisation layer, storing nothing
- [ ] OpenTelemetry: one standard for all three signals; **graduated May 2026**
- [ ] Jaeger; Fluentd / Fluent Bit
- [ ] **metrics-server vs Prometheus vs kube-state-metrics**; `kubectl top`
- [ ] SLI / SLO / SLA and error budgets
- [ ] FinOps and cost management; OpenCost

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "Observability is a tool you install" | It is a **property of the system**. Monitoring is an activity |
| "Prometheus receives metrics pushed by apps" | It **pulls** — it scrapes `/metrics`. Pushgateway is the exception for short jobs |
| "Grafana stores your metrics" | **Visualisation only.** It queries other systems |
| "Grafana is a CNCF project" | It is not. Prometheus, Jaeger, Fluentd and OpenTelemetry are |
| "`kubectl top` comes from Prometheus" | From **metrics-server**, via the Metrics API |
| "metrics-server keeps history" | **In memory, current values only** |
| "kube-state-metrics reports CPU and memory" | It reports **object state** — replicas, phases, job status |
| "A counter can go down" | Only up, or **reset to 0** on restart |
| "Graph the counter directly" | Use **`rate()`**. The raw total is meaningless |
| "Summary quantiles can be averaged across instances" | They cannot. **Histograms** aggregate; summaries do not |
| "Put the request ID in a metric label" | **Cardinality explosion.** IDs belong in logs and traces |
| "Alertmanager decides when an alert fires" | **Prometheus** evaluates the rule. Alertmanager routes and silences |
| "OpenTelemetry replaces Prometheus" | OTel **produces and transports**; Prometheus **stores and queries** |
| "OpenTelemetry is still incubating" | **Graduated 21 May 2026** |
| "SLA is the internal target" | That is the **SLO**. The SLA is the customer contract with penalties |
| "The error budget is the SLO" | It is **100% − SLO** |
| "Container logs persist after the Pod is deleted" | They are node-local and ephemeral. Ship them or lose them |
| "kube-state-metrics runs as a DaemonSet" | **Deployment, one replica.** Every replica reads the same API and duplicates every series — `sum()` would return 3× the truth |
| "kube-state-metrics reads etcd" | It reads the **Kubernetes API**. Only the API server talks to etcd |
| "Installing Prometheus/Grafana/Jaeger gives you observability" | Tools **consume** telemetry. If the app never emitted the attribute, no dashboard invents it |
| "`kubectl top` fails, so metrics-server crashed" | On kubeadm it was **never installed**. A missing component, not a broken one |
| "The trace ID is the span" | A **span is one operation**; the trace ID is what joins spans into a trace |
| "Error budget for a 99.9% SLO is 0.01%" | **0.1%** — about **43 minutes per 30 days** |

**X ≠ Y**

- **Observability ≠ monitoring** — unknown unknowns vs known unknowns
- **Metrics ≠ logs ≠ traces** — is it wrong / what happened / where it happened
- **Pull ≠ push** — the server scrapes vs the client sends
- **Counter ≠ gauge** — only up vs up and down
- **Histogram ≠ summary** — quantiles server-side (aggregatable) vs client-side
- **metrics-server ≠ Prometheus** — current values for `kubectl top` vs a full TSDB
- **metrics-server ≠ kube-state-metrics** — resource usage vs object state
- **Prometheus ≠ Alertmanager** — evaluates rules vs routes notifications
- **Grafana ≠ a data store** — dashboards only
- **OpenTelemetry ≠ Jaeger** — the standard vs a tracing backend
- **SLI ≠ SLO ≠ SLA** — measurement vs target vs contract
- **Trace ≠ span** — the whole journey vs one operation in it
- **Fluentd ≠ Fluent Bit** — the heavier original vs the lightweight C rewrite
- **Instrumentation richness ≠ cardinality** — how many attributes you emit vs how many series they produce
- **Cardinality ≠ volume** — multiplicative and fatal in metrics; linear and tunable in logs and traces
- **DaemonSet ≠ Deployment for exporters** — node-local data vs cluster-wide data read from the API

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. Define observability and distinguish it from monitoring using the "unknowns"
   framing.
2. Name the three pillars and the question each one answers.
3. Which pillar must keep cardinality low, why, and where do request IDs belong
   instead?
4. Walk an incident through all three pillars in order, saying what each
   contributes.
5. Does Prometheus pull or push? Name one advantage of that choice that the other
   model cannot give you.
6. What is the Pushgateway for, and which Kubernetes workload type makes it
   necessary?
7. Name four components of a Prometheus setup and what each does.
8. Which component decides that an alert fires, and which decides who is
   notified?
9. node-exporter and kube-state-metrics: what does each expose, and which
   workload object does each run as? Why the difference?
10. Name the four metric types. Which can decrease, and which two describe
    distributions?
11. Why do you almost never graph a counter directly, and which function do you
    use?
12. Histogram or summary for latency across 50 replicas? Justify by where the
    quantile is computed.
13. Distinguish metrics-server, Prometheus and kube-state-metrics. Which powers
    `kubectl top`?
14. `kubectl top nodes` fails on your cluster. Why, and what else stops working
    for the same reason?
15. What does Grafana do, what does it not do, and is it a CNCF project?
16. Define trace, span, trace ID and context propagation. What breaks if one
    service does not propagate?
17. What is OpenTelemetry, which two projects merged to form it, which signals
    does it cover, and what is its current CNCF maturity level?
18. Define SLI, SLO and SLA, say which is normally stricter, and compute the
    error budget for a 99.9% SLO over 30 days.

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — The alert that was never useful

A team alerts on "CPU above 80% for 5 minutes" on every Pod. During a real
outage — checkout failing for 40% of users — the alert never fired. CPU was
normal throughout.

a. Explain why a resource alert missed a user-facing outage. Which pillar was
   being used, and what was it actually measuring?
b. Which SLI should they have been measuring instead? Write it as a sentence
   with a number in it.
c. Turn that SLI into an SLO and compute the error budget over 30 days. State
   what the budget authorises when it is full and when it is spent.
d. During the incident they need to know *which service* was slow. Which pillar
   answers that, and which specific concept lets it cross service boundaries?
e. One service was written by another team and does not forward trace headers.
   Describe exactly what the trace looks like and what becomes invisible.
f. They propose adding `user_id` as a metric label so they can see which users
   are affected. Explain the failure that causes and name the correct home for
   that data.

### Drill 2 — Three tools, one confusion

A team wants to know: (i) how much CPU a Pod uses right now, (ii) whether any
Deployment has had zero ready replicas for 5 minutes, (iii) what memory usage
looked like last Tuesday at 03:00.

a. Name the component that answers each, and explain why no single one answers
   all three.
b. For (ii), explain why CPU and memory data could never answer it, and what
   *kind* of metric is required.
c. `kubectl top pods` returns an error. Name the missing component, the API it
   serves, and one other cluster feature that stops working without it.
d. They install Prometheus and expect `kubectl top` to start working. Explain why
   it does not, being precise about which API `kubectl top` calls.
e. Which of the three runs as a DaemonSet and which as a Deployment? Justify each
   from what it collects.
f. On EKS `kubectl top` worked without anyone installing anything. What had AWS
   done, and what does that say about a component you now have to think about?

### Drill 3 — The logs that were not there

An incident at 03:00. At 09:00 the on-call engineer looks for the logs of the Pod
that crashed. `kubectl logs` returns nothing, the Pod no longer exists, and the
namespace events are empty too.

a. Explain why the logs are gone, using the container writable layer and where
   container logs actually live.
b. Explain why the events are gone as well. Name the mechanism and its default.
   (Note 08 §1.7.)
c. What architecture would have preserved the logs? Name the workload object,
   why that object type, and where the logs would have gone.
d. The app writes to `/var/log/app.log` instead of stdout. Name two independent
   consequences — one for `kubectl logs`, one for the collector.
e. The Pod restarted before being deleted. Which single flag would have retrieved
   the crashed instance's output, and why does it only work before deletion?
f. Rank by what each would have contributed here: a log collector DaemonSet,
   longer event TTL, tracing. Defend the ordering.

### Drill 4 — Cost lands on the platform team

Finance reports the cluster costs three times its budget. Nodes average **11% CPU
utilisation** and the cluster autoscaler still adds nodes regularly.

a. Explain how nodes at 11% utilisation can be full enough to trigger scaling.
   Name the exact field the scheduler reads. (Note 03 §1.11.)
b. State the mismatch in one sentence, and name the metric you would compare
   against `requests` to prove it.
c. Which component would you need installed to gather the "actual usage over
   time" half of that comparison, and why is metrics-server not sufficient?
d. Name the CNCF project that attributes cluster cost per namespace, and explain
   why per-instance cloud billing cannot answer "which team spent this".
e. Map your remediation to the three FinOps phases, one action each.
f. Lowering requests risks eviction under pressure. Explain the trade-off using
   QoS classes (note 03 §1.11), and say which class you would target for a
   latency-critical service versus a batch Job.
