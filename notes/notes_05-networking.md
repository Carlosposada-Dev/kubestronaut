---
exams: [KCNA, CKA, CKAD, CKS]
domain: Networking
kcna_domains: 2.1 Networking
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: kubernetes.io/docs/concepts/services-networking/ (service, dns-pod-service, ingress, ingress-controllers, gateway, network-policies, endpoint-slices, cluster-ip-allocation), /concepts/cluster-administration/networking, github.com/containernetworking/cni (CNI spec), gateway-api.sigs.k8s.io, glossary.cncf.io (service mesh)
template: B
language: en
scope: KCNA ONLY — CKA/CKAD/CKS layers appended from 11 Sep
status: draft
written: 2026-09-02
format: per claude/depth-standard.md AMENDMENT 2026-09-01 — plain-language opener per section, reading-time target, tables by default
k8s_version_checked_against: v1.37 (released 2026-08-26). Ingress-NGINX retirement verified against kubernetes.io/blog/2026/01/29 and kubernetes.dev/blog/2025/11/12. Gateway API GA Oct 2023.
closes_mistakes: rows 23 (DNS FQDN), 24 (Service with no endpoints), 27 (Pod-to-Pod vs localhost)
---

# Networking

*How a packet gets from anywhere to the right container — and why the Pod IP you
are looking at will not exist in ten minutes.*

KCNA area 2.1 is the largest sub-area of Domain 2 and worth roughly **8–10 of
the 60 questions**. It is also where three logged errors live, so this note
closes them explicitly.

---

## 1. Core Concepts

### 1.1 The Kubernetes network model

*Kubernetes does not implement networking. It writes down four rules and makes
someone else obey them.*

The model is a **contract**, not an implementation. Any network that satisfies
it is a valid Kubernetes network:

| # | Rule | Consequence |
|---|---|---|
| 1 | Every Pod gets **its own unique IP**, cluster-wide | No port conflicts between Pods — two nginx Pods both use port 80 |
| 2 | Pods communicate with **all** Pods on **all** nodes **without NAT** | A Pod sees the real source IP of the Pod that called it |
| 3 | Agents on a node (kubelet, daemons) can reach all Pods on that node | Health checks and probes work |
| 4 | Pods in the host network namespace can reach all Pods on all nodes | Host-network DaemonSets work |

**"Without NAT" is the load-bearing phrase.** It means the cluster is a **flat
address space**: no port mapping, no address translation between Pods, and the
IP a Pod sees is the IP the sender actually has. This is the opposite of Docker's
default bridge networking, and it is why Kubernetes needed a plugin system rather
than reusing what Docker did.

**The model says nothing about how.** Overlay, BGP, cloud-native routing, eBPF —
all valid, as long as the four rules hold. That gap is exactly what CNI fills.

### 1.2 Pod networking — one IP per Pod

*`localhost` works between containers in the same Pod. Between different Pods it
does not, whether they share a node or not.*

**This closes `mistakes.md` row 27.** The distinction:

| Scope | How they reach each other | Mechanism |
|---|---|---|
| **Containers inside ONE Pod** | `localhost:<port>` | They share the **network namespace** (note 03 §1.4) — same IP, same port space |
| **Pod → Pod, same node** | The other Pod's **IP** | Routed by the CNI. Never `localhost` |
| **Pod → Pod, different node** | The other Pod's **IP** | Same mechanism. **Identical from the Pod's point of view** |

The rule to memorise: **same node vs different node makes no difference to a
Pod.** That is the whole point of rule 2. If Pod-to-Pod worked one way on a node
and another way across nodes, every application would have to know where it was
running.

**Two containers in the same Pod cannot both bind port 8080** — one port space.
Two Pods can, even on the same node, because they have separate namespaces and
separate IPs.

**Pod IPs are ephemeral.** A Pod that restarts gets a new IP. A Deployment
rolling out replaces every IP it had. Nothing should ever be configured with a
Pod IP — which is the entire reason Services exist (§1.4).

### 1.3 CNI — the spec, and the plugins

*CNI is a job description; Calico and Cilium are the employees who show up.*

**CNI (Container Network Interface)** is a CNCF specification
(`github.com/containernetworking/cni`) defining a contract: *given a container's
network namespace, give it an IP and connect it, and clean up afterwards.* It is
deliberately tiny — `ADD`, `DEL`, `CHECK`.

The sequence when a Pod starts:

```
kubelet → container runtime → creates the pause container's netns
                            → calls the CNI plugin (ADD)
                                 ├─ IPAM: allocate an IP from the pod CIDR
                                 ├─ create a veth pair, one end in the netns
                                 └─ write routes so other nodes can reach it
                            → application containers join that same netns
```

**No CNI plugin installed = no Pod networking.** The node reports `NotReady`, and
every Pod sits in `ContainerCreating`. On a fresh `kubeadm init` this is the
normal state until you install one — it is not a fault.

| Plugin | How it moves packets | NetworkPolicy? | Note |
|---|---|---|---|
| **Calico** | Native L3 routing, BGP; optional overlay | **Yes** | The lab choice. Policy support is why |
| **Cilium** | **eBPF** in the kernel, can replace kube-proxy | **Yes**, plus L7 | The modern high-performance option |
| **Flannel** | VXLAN **overlay** — packets wrapped inside packets | **No** | Simplest; cannot do NetworkPolicy alone |
| **AWS VPC CNI** | Pods get **real VPC IPs** from the subnet | Yes (recent versions) | The EKS default. See §7 |

**Flannel's missing NetworkPolicy support is a real exam-shaped fact:** you can
write a `NetworkPolicy` object, the API server will accept it, and **nothing will
enforce it**. The object exists; the enforcement does not. Silent failure.

### 1.4 Why Services exist

*Pods are a moving target. A Service is the stable address you point at instead.*

Three problems, one object:

| Problem | What a Service does |
|---|---|
| Pod IPs change on every restart | Gives a **stable virtual IP** and a **stable DNS name** for the group |
| There are N replicas, not one | **Load balances** across all healthy backing Pods |
| You do not know which Pods exist | Tracks them **by label selector**, automatically |

A Service is a **level-4 (TCP/UDP) load balancer defined by labels**. It does not
know or care which Deployment produced the Pods — only whether their labels match
`spec.selector` (note 03 §1.4: the same label-based, not ownership-based, logic).

### 1.5 The four Service types

*They are cumulative: each type is the one before it, plus one more way in.*

| Type | Reachable from | Mechanism | Gotcha |
|---|---|---|---|
| **ClusterIP** | **Inside the cluster only** | A virtual IP that exists only as forwarding rules | **The default.** No interface anywhere holds this IP |
| **NodePort** | Outside, via `<anyNodeIP>:<port>` | ClusterIP **plus** a port opened on **every** node | Port range **30000–32767**. Opens on all nodes, even those running no backing Pod |
| **LoadBalancer** | Outside, via an external LB | NodePort **plus** a cloud provider provisioning a real load balancer | **Stays `Pending` forever on kubeadm** — there is no cloud controller to answer |
| **ExternalName** | — | Returns a **CNAME** in DNS | **No proxying, no selector, no endpoints.** Pure DNS aliasing to an external host |

```
LoadBalancer  ⊃  NodePort  ⊃  ClusterIP
   (cloud LB)     (node port)   (virtual IP)

ExternalName — outside this hierarchy. DNS only, no traffic passes through it.
```

**The `Pending` LoadBalancer is the classic EKS-to-vanilla trap.** On EKS it
works because a controller is watching for it. On your kubeadm cluster nothing
is, so the `EXTERNAL-IP` column stays `<pending>` indefinitely. That is correct
behaviour, not a bug. MetalLB is what fills the gap on bare metal.

### 1.6 Headless Service

*A normal Service gives you one shared IP for the group; a headless one gives you
a DNS name per individual Pod.*

Created by setting **`clusterIP: None`**. There is then no virtual IP and no load
balancing — DNS returns the **Pod IPs directly**, one A record per ready Pod.

| | Normal Service | Headless Service |
|---|---|---|
| `clusterIP` | An allocated virtual IP | **`None`** |
| DNS returns | One IP (the Service's) | **All Pod IPs** |
| Load balancing | Yes, by kube-proxy | **No** — the client chooses |
| Reach one specific Pod? | No | **Yes**, by name |

This is what `spec.serviceName` in a StatefulSet requires (note 03 §1.6). Without
it there would be no way to address `web-0` specifically, and the StatefulSet's
whole promise of stable identity would be unusable.

Use it when the **client** needs to pick — database replicas, Kafka brokers, any
peer-to-peer system where "any healthy one" is the wrong answer.

### 1.7 How a Service finds its Pods — EndpointSlice

*The Service is a label query. The EndpointSlice is the answer to that query,
recalculated continuously.*

**This closes `mistakes.md` row 24.** The chain:

```
Service (spec.selector)  +  Pods (metadata.labels, and Ready)
            │
            ▼   endpointslice-controller watches both
      EndpointSlice  ──► every matching Pod, each flagged ready true/false
                         kube-proxy programs rules for the READY ones only
```

A Pod is **listed** if its labels match `spec.selector`. Whether traffic reaches
it is a **second, separate** question, and conflating the two is the trap here:

| Situation | In the EndpointSlice? | Gets traffic? |
|---|---|---|
| Labels match, Pod **Ready** | **Yes**, `conditions.ready: true` | **Yes** |
| Labels match, Pod **not Ready** | **Yes — still listed**, `conditions.ready: false` | **No** — kube-proxy skips it |
| Labels **do not match** | **No, absent entirely** | No |

**A failing readiness probe does not remove the Pod from the EndpointSlice — it
marks it `ready: false`.** The entry stays, with its IP visible; kube-proxy
simply excludes it when programming the node's rules. (Not-ready entries are
listed deliberately: headless Services and StatefulSets need to resolve Pods that
are not yet serving.)

That distinction is what separates the **two causes of a dead Service**, and they
need different fixes:

| Cause | EndpointSlice shows | Fix |
|---|---|---|
| **Selector matches nothing** — a label typo | **No entries at all** | Fix the selector or the labels |
| **Pods match but are not Ready** | Entries present, all `ready: false` | Fix the readiness probe or the app |

The symptom is identical from outside — timeout or connection refused, with the
Service looking perfectly healthy — so the condition is the only thing that tells
them apart.

```bash
# Are the Pods listed at all? (absent = selector problem)
kubectl get endpointslice -l kubernetes.io/service-name=<svc>

# Listed but not serving? Check the CONDITION, not the count:
kubectl get endpointslice -l kubernetes.io/service-name=<svc> \
  -o jsonpath='{.items[*].endpoints[*].conditions.ready}{"\n"}'

# Shorter: describe shows ONLY the ready endpoints
kubectl describe svc <svc> | grep -i endpoints

kubectl get pods --show-labels     # do labels match the selector?
kubectl get pods                   # READY 1/1?
```

`EndpointSlice` replaced the older `Endpoints` object, which put every backend in
one object and did not scale. EndpointSlice went **GA in v1.21** and splits
backends across multiple objects; the `Endpoints` API was **deprecated in v1.33**.

### 1.8 kube-proxy — how a virtual IP actually works

*Nothing holds a ClusterIP. It is a rule in the kernel that rewrites the
destination address as the packet leaves.*

kube-proxy runs as a **DaemonSet on every node** (note 03 §1.5 — one per node,
node-level infrastructure). It watches Services and EndpointSlices, and programs
the node's kernel so that traffic to a ClusterIP is rewritten to a real Pod IP.

**It does not carry the traffic.** It writes rules; the kernel forwards. If
kube-proxy dies, existing rules keep working — new Services just stop being
programmed. Same shape as the scheduler dying in note 03 §1.1.

| Mode | How | Scaling |
|---|---|---|
| **iptables** | A chain of rules, evaluated **sequentially**; random selection for balancing | **The default.** Rule evaluation grows linearly — slow at thousands of Services |
| **IPVS** | Kernel L4 load balancer with **hash-table** lookup, real algorithms (rr, lc, sh) | O(1) lookup, built for large clusters |
| **nftables** | The modern replacement for iptables | Newer mode, better scaling than iptables |

For KCNA: **iptables is the default; IPVS exists for scale and offers real
balancing algorithms.** That contrast is the question.

The end-to-end path, which is worth being able to recite:

```
Pod A  →  10.96.0.50:80 (ClusterIP)
             │  kernel rules written by kube-proxy on Pod A's node
             ▼  DNAT: rewrite destination to a chosen backend
          10.244.2.7:8080 (Pod B's real IP)
             │  CNI routing
             ▼
          Pod B
```

Note where the decision happens: **on the sending Pod's node, before the packet
leaves.** There is no central proxy in the path.

### 1.9 CoreDNS and the FQDN

*Every Service gets a predictable DNS name, and the format is memorisable because
it never varies.*

**This closes `mistakes.md` row 23.** The format:

```
<service-name>.<namespace>.svc.cluster.local
       │            │        │        └── cluster domain (configurable, this is the default)
       │            │        └── "svc" — it is a Service (Pods use "pod")
       │            └── the Service's namespace
       └── the Service's name
```

So a Service `api` in namespace `prod` is **`api.prod.svc.cluster.local`**.

**CoreDNS** is the cluster DNS server — a Deployment in `kube-system`, fronted by
a ClusterIP Service (conventionally `10.96.0.10`). It became the default,
replacing kube-dns, in **v1.13**. The kubelet writes its address into every Pod's
`/etc/resolv.conf`, along with **search domains** — which is why short names work:

| From a Pod in namespace `prod`, writing… | Resolves to | Because |
|---|---|---|
| `api` | `api.prod.svc.cluster.local` | Search domain completes it — **same namespace only** |
| `api.staging` | `api.staging.svc.cluster.local` | Search domain completes the rest |
| `api.prod.svc.cluster.local` | itself | Fully qualified, no completion needed |

**The trap:** the short name only works **within the same namespace**. Calling
`api` from a different namespace fails — and this is a very common real-world
bug, because it works in dev where everything shares a namespace.

**Headless Services and StatefulSets** get per-Pod records:
`web-0.<service>.<namespace>.svc.cluster.local`.

### 1.10 Ingress and the Ingress Controller

*A Service gets you to a port. Ingress gets you to a URL — one entry point that
routes by hostname and path.*

Without Ingress, exposing ten HTTP apps means ten LoadBalancers (ten cloud LBs,
ten bills) or ten NodePorts on strange high ports. Ingress gives you **one**
entry point that routes at **layer 7**:

| Ingress does | Ingress does NOT do |
|---|---|
| Route by **hostname** (`api.example.com`) | Handle non-HTTP protocols |
| Route by **path** (`/api` → service A, `/web` → service B) | Replace Services — it routes **to** them |
| Terminate **TLS** | Do anything by itself |

**The critical mechanic:** an Ingress object is **only a set of rules**. Creating
one does nothing unless an **Ingress Controller** is running to read it and
configure a real proxy. No controller, no traffic — and no error either, which is
what makes it confusing.

```
Ingress object (rules)  ← read by →  Ingress Controller (a real proxy Pod)
                                            │
                                            ▼  routes to
                                     Service → EndpointSlice → Pods
```

`IngressClass` selects which controller owns a given Ingress when several are
installed.

**Current status, and this matters in 2026:** the widely used community
controller **Ingress-NGINX was retired in March 2026** — no releases, no bug
fixes, no security patches. The Kubernetes Steering and Security Response
Committees recommend migrating to Gateway API or another maintained controller.
Two clarifications the exam and the internet both blur:

- **Ingress-NGINX** (`kubernetes/ingress-nginx`, community) is the retired one.
  **NGINX Ingress Controller** (`nginxinc/kubernetes-ingress`, F5) is a different
  project and is unaffected. Similar names, different things.
- **The Ingress API itself is not deprecated.** It remains GA and existing
  objects keep working — but it is **feature-frozen**, with all new development
  happening in Gateway API.

### 1.11 Gateway API

*The redesign of Ingress, split so that the cluster operator and the app team can
each own their own piece.*

Ingress tried to express everything in one object, and every controller extended
it with vendor-specific **annotations** — which is why two Ingress controllers
never behaved the same way. Gateway API replaces that with several typed objects
and clear ownership. It reached **GA in October 2023**.

| Object | Owned by | Says |
|---|---|---|
| **GatewayClass** | Infrastructure provider | "This kind of gateway is available" |
| **Gateway** | Cluster operator | "Listen on this port, with this TLS certificate" |
| **HTTPRoute** | Application team | "Send `/api` to my Service" |

| | Ingress | Gateway API |
|---|---|---|
| Protocols | HTTP/HTTPS | HTTP, HTTPS, TCP, UDP, gRPC, TLS |
| Extensibility | Vendor **annotations** | Typed fields in the API |
| Ownership | One object, one owner | **Split by role** |
| Status | GA, **feature-frozen** | GA, actively developed |

For KCNA, know that **Gateway API is the successor to Ingress**, that it is
role-oriented, and that it handles more than HTTP.

### 1.12 NetworkPolicy

*By default every Pod can talk to every other Pod. The first policy that selects
a Pod flips it to deny-by-default — for that Pod only.*

**The default is allow-all**, in every direction, across every namespace. A
NetworkPolicy is a namespaced object that changes this for the Pods its
`podSelector` matches.

The rule that produces most confusion:

| State | Behaviour |
|---|---|
| Pod selected by **no** policy | **Everything allowed** |
| Pod selected by a policy with `policyTypes: [Ingress]` | **All inbound denied except what the policy allows.** Outbound still unrestricted |
| Pod selected by a policy with `policyTypes: [Ingress, Egress]` | Both directions deny-by-default |
| Pod selected by **several** policies | The rules are **additive (OR)** — a connection allowed by any one of them is allowed. Policies never deny; they only carve out allowances |

Three things that catch people:

- **Policies are namespaced**, but selecting traffic from other namespaces needs
  a `namespaceSelector` — a bare `podSelector` only matches within the policy's
  own namespace.
- **`podSelector: {}` selects every Pod in the namespace** — the standard way to
  write a default-deny.
- **Enforcement is the CNI's job.** With Flannel, the object is accepted and
  ignored (§1.3).

Both directions have a naming trap worth fixing now: **ingress** here means
inbound traffic to the Pod and has nothing to do with the **Ingress** object in
§1.10. Same word, unrelated concepts.

### 1.13 Service mesh — concepts only

*A layer that moves retries, encryption and telemetry out of your application and
into a proxy beside it.*

*Scope note: `plan.md §2` puts Istio out of scope until 1 Dec. KCNA asks what a
service mesh is, not how to run one. Concepts only.*

The problem: in a microservice system, every service needs mTLS, retries,
timeouts, circuit breaking, and tracing. Implementing that in each service means
doing it once per language, inconsistently.

The solution: put a **proxy next to every Pod** and let it handle all of it.

| Plane | What it is | Does |
|---|---|---|
| **Data plane** | The **proxies** — one per Pod, as a sidecar container | Carries every packet. Applies mTLS, retries, timeouts, collects metrics |
| **Control plane** | The central **management** component | Configures the proxies. **Carries no application traffic** |

The distinction is a near-guaranteed question: **the control plane configures,
the data plane carries.** Also note the vocabulary collision — this is the same
"control plane / data plane" wording as note 01, but a completely different
thing. Kubernetes' control plane is the API server and friends; a mesh's control
plane is mesh configuration. `mistakes.md` already logs one wording slip here.

**What a mesh gives you:** mTLS between services with no application change,
traffic splitting for canaries, retries and circuit breaking, and uniform
golden-signal metrics.

**What it costs:** a proxy per Pod (memory, latency), and substantial operational
complexity. Examples: Istio, Linkerd, Cilium Service Mesh.

---

## 2. Objects & Fields That Matter

| Object | Key fields | Default | Gotcha |
|---|---|---|---|
| Service | `spec.type`, `spec.selector`, `spec.ports` | `ClusterIP` | No selector = no endpoints, silently |
| Service (headless) | `spec.clusterIP: None` | — | Required by StatefulSet's `serviceName` |
| Service (NodePort) | `spec.ports[].nodePort` | auto from **30000–32767** | Opens on **every** node |
| Service (ExternalName) | `spec.externalName` | — | DNS CNAME only; selector is ignored |
| EndpointSlice | `endpoints[].addresses`, `.conditions.ready` | — | Generated, not written by you |
| Ingress | `spec.rules[].host/.http.paths`, `spec.ingressClassName`, `spec.tls` | — | Inert without a controller |
| NetworkPolicy | `spec.podSelector`, `spec.policyTypes`, `ingress`/`egress` | allow-all until selected | `podSelector: {}` = all Pods in the namespace |
| Pod DNS | `spec.dnsPolicy` | `ClusterFirst` | `hostNetwork` Pods need `ClusterFirstWithHostNet` |
| CoreDNS | Deployment + Service in `kube-system` | ClusterIP `10.96.0.10` by convention | If it is down, names fail but IPs still work |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 2 (CKA, from 11 Sep) with
`kubectl expose`, `kubectl create ingress` and the imperative Service paths.*

---

## 4. Hands-On Lab

On the 3-node kubeadm cluster. **Target: 25 minutes.**

```bash
# 1. Pod IPs are per-Pod and ephemeral                                 (5 min)
kubectl create deployment web --image=nginx --replicas=3
kubectl get pods -o wide                    # three distinct IPs, spread over nodes
kubectl delete pod <one-of-them>
kubectl get pods -o wide                    # the replacement has a NEW IP

# 2. A Service is a stable name in front of that churn                 (5 min)
kubectl expose deployment web --port=80
kubectl get svc web                          # a ClusterIP appears
kubectl get endpointslice -l kubernetes.io/service-name=web   # three backends

# 3. Break it the way it breaks in production                          (7 min)
kubectl label pod <one> app=web --overwrite   # note current labels first
kubectl edit svc web                          # change selector to app=wrong
kubectl get endpointslice -l kubernetes.io/service-name=web   # EMPTY — the row-24 failure
kubectl edit svc web                          # put it back

# 4. DNS, from inside the cluster                                      (5 min)
kubectl run dnstest --rm -it --image=busybox:1.36 --restart=Never -- sh
  nslookup web                                # short name works in-namespace
  nslookup web.default.svc.cluster.local      # the FQDN
  cat /etc/resolv.conf                        # CoreDNS IP + search domains
  exit

# 5. Prove LoadBalancer has nobody to answer it                        (3 min)
kubectl expose deployment web --port=80 --type=LoadBalancer --name=web-lb
kubectl get svc web-lb                        # EXTERNAL-IP stays <pending>. Correct.

kubectl delete svc web web-lb && kubectl delete deployment web
```

---

## 5. Verification

```bash
kubectl get svc -o wide                                    # TYPE, CLUSTER-IP, SELECTOR
kubectl get endpointslice -l kubernetes.io/service-name=<svc>   # THE decisive command
kubectl get pods --show-labels                             # do they match the selector?
kubectl describe svc <svc> | grep -i -A3 endpoints
kubectl get pods -n kube-system -l k8s-app=kube-dns        # is CoreDNS alive?
kubectl get networkpolicy -A
```

A Service object looking healthy proves nothing. **A non-empty EndpointSlice is
the proof.**

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| Service reachable but connection refused/times out | **EndpointSlice empty** — selector typo or Pods not Ready | `kubectl get endpointslice -l kubernetes.io/service-name=<svc>` | Fix the selector, or fix the readiness probe |
| Short DNS name fails, FQDN works | Calling **across namespaces** | `nslookup <name>` inside a Pod | Use `<svc>.<ns>` or the full FQDN |
| All DNS fails, IPs still work | CoreDNS down or unreachable | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | Restart CoreDNS; check its Service |
| `EXTERNAL-IP` stuck `<pending>` | LoadBalancer with no cloud controller | `kubectl get svc` | Expected on kubeadm. Use NodePort or MetalLB |
| Every Pod `ContainerCreating`, nodes `NotReady` | **No CNI plugin installed** | `kubectl get nodes`; `ls /etc/cni/net.d` | Install Calico |
| NetworkPolicy written, nothing enforced | CNI does not support it (Flannel) | `kubectl get networkpolicy` shows the object | Use Calico or Cilium |
| Ingress created, nothing responds | **No Ingress Controller running** | `kubectl get pods -A \| grep -i ingress` | Install a controller; set `ingressClassName` |
| Traffic blocked right after the first NetworkPolicy | Selecting a Pod flips it to deny-by-default | `kubectl describe networkpolicy` | Add explicit allow rules — including DNS to CoreDNS |
| Two containers in one Pod, one will not start | Both bound the **same port** — one namespace | `kubectl logs <pod> -c <container>` | Change one port |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| Pod IPs | **Real VPC IPs** from your subnet, routable across the whole VPC. Pod count per node is capped by the **instance type's ENI limit** | Pod CIDR from an overlay (`10.244.0.0/16`), **not routable outside the cluster**. No ENI cap |
| `type: LoadBalancer` | Provisions a real NLB/ALB through the AWS Load Balancer Controller | **`<pending>` forever.** No cloud controller exists to answer |
| Ingress | Usually an ALB via the AWS Load Balancer Controller, configured with annotations | You install a controller yourself — and **Ingress-NGINX retired in March 2026**, so the choice matters now |
| CNI | VPC CNI is pre-installed as a DaemonSet you never wrote | **Nothing is installed.** No CNI means `NotReady` nodes and zero Pod networking |
| NetworkPolicy | Enforced by VPC CNI (recent versions) or an added Calico | Whatever your CNI supports. Calico was chosen for exactly this |
| Typical failure | **IP exhaustion** — subnet out of addresses, or max-pods-per-node reached | **DNS, selectors and missing controllers.** IP exhaustion is not a thing you will see |

The habit to unlearn: on EKS, a Pod IP is a VPC IP that AWS routes for you, and
`type: LoadBalancer` just works. Neither is true on the exam, and neither is
Kubernetes — both are AWS controllers doing work that vanilla leaves undone.

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 2.*

---

## 9. Objectives Covered

KCNA area **2.1 Networking** — tick only when explainable without looking.

- [ ] The network model: one IP per Pod, no NAT between Pods
- [ ] CNI: what the spec is, what a plugin does (Calico, Cilium, Flannel)
- [ ] Service types: ClusterIP, NodePort, LoadBalancer, ExternalName
- [ ] Headless Service and what requires it
- [ ] How a Service finds Pods: selector → EndpointSlice → kube-proxy
- [ ] kube-proxy: iptables vs IPVS
- [ ] CoreDNS and the FQDN `<svc>.<ns>.svc.cluster.local`
- [ ] Ingress vs Service; the Ingress Controller; Ingress-NGINX retirement
- [ ] Gateway API as the successor to Ingress
- [ ] NetworkPolicy: default allow, and what the first policy changes
- [ ] Service mesh: control plane vs data plane, sidecar, mTLS

---

## KCNA — Traps & Distractors

*Temporary. Delete after the exam; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "Pods on the same node talk over `localhost`" | Only **containers inside one Pod** do. Pod→Pod is always by IP |
| "Pod-to-Pod across nodes needs NAT" | Rule 2 forbids NAT. Same-node and cross-node are identical |
| "Kubernetes implements the cluster network" | It defines a **model**; a **CNI plugin** implements it |
| "A ClusterIP is assigned to an interface somewhere" | It is a **virtual IP** — forwarding rules only. Nothing holds it |
| "NodePort opens the port only on nodes running the Pod" | On **every** node in the cluster |
| "`type: LoadBalancer` works anywhere" | Needs a cloud controller. `<pending>` on bare kubeadm |
| "ExternalName load balances to an external host" | **DNS CNAME only.** No traffic passes through it |
| "kube-proxy forwards the packets" | It **writes kernel rules**; the kernel forwards |
| "A failing readiness probe removes the Pod from the EndpointSlice" | It is **still listed**, flagged `ready: false`. kube-proxy skips it |
| "An empty EndpointSlice is the only Service failure mode" | Entries present but all `ready: false` is the other, and needs a different fix |
| "IPVS is the default kube-proxy mode" | **iptables** is. IPVS is opt-in, for scale |
| "The short DNS name works from any namespace" | Only within the **same** namespace |
| "Creating an Ingress object exposes the app" | Inert without an **Ingress Controller** |
| "The Ingress API was deprecated in 2026" | **Ingress-NGINX the controller** retired. The **API** is GA, just feature-frozen |
| "NetworkPolicy defaults to deny-all" | Defaults to **allow-all** until a policy selects the Pod |
| "One NetworkPolicy can deny traffic another allows" | Policies are **additive**. They only allow; they never deny |
| "Writing a NetworkPolicy guarantees enforcement" | The **CNI** enforces. Flannel silently ignores it |
| "The mesh control plane proxies application traffic" | The **data plane** carries traffic; the control plane only configures |

**X ≠ Y**

- **`localhost` in a Pod ≠ Pod-to-Pod** — shared namespace vs routed IPs
- **Network model ≠ CNI plugin** — the contract vs the implementation
- **ClusterIP ≠ Pod IP** — a stable virtual IP vs an ephemeral real one
- **Service ≠ Ingress** — L4 by labels vs L7 by host and path
- **Ingress (object) ≠ Ingress Controller** — the rules vs the proxy that obeys them
- **Ingress-NGINX ≠ NGINX Ingress Controller** — community, retired vs F5, alive
- **NetworkPolicy `ingress` ≠ the Ingress object** — inbound direction vs L7 routing
- **Headless ≠ ClusterIP** — per-Pod DNS vs one virtual IP
- **`Endpoints` ≠ `EndpointSlice`** — the old single object vs the scalable replacement
- **Absent from the EndpointSlice ≠ listed as `ready: false`** — selector problem vs readiness problem
- **CoreDNS ≠ kube-proxy** — resolves names vs programs forwarding rules
- **Mesh control plane ≠ Kubernetes control plane** — same words, unrelated things
- **Flannel ≠ Calico** — no NetworkPolicy vs NetworkPolicy

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. State the four rules of the Kubernetes network model. Which one forbids NAT,
   and what does that guarantee the receiver sees?
2. Two containers in one Pod, and two Pods on one node. Which pair uses
   `localhost` and which uses IPs? Why?
3. Does Pod-to-Pod communication differ when the Pods are on different nodes?
   Justify from the model, not from experience.
4. What is CNI, and what exactly does a plugin do when a Pod is created?
5. Name three CNI plugins and the one meaningful difference between them for
   this study plan.
6. You apply a NetworkPolicy on a Flannel cluster. What happens, and what is the
   symptom?
7. Name the four Service types and what each adds to the one before it.
8. What is the NodePort range, and on which nodes does the port open?
9. You create `type: LoadBalancer` on your kubeadm cluster. What happens and
   why? Is it a fault?
10. How do you create a headless Service, what does DNS return, and which
    workload object requires one?
11. What puts a Pod **in** a Service's EndpointSlice, and what separately decides
    whether it **receives traffic**? What does a failing readiness probe change?
12. A Service exists, has a ClusterIP, and connections fail. Name the **two**
    distinct causes, the field that tells them apart, and the different fix each
    one needs.
13. What does kube-proxy actually do — and what happens to existing traffic if
    it dies?
14. Name the two main kube-proxy modes, which is the default, and why the other
    exists.
15. Write the FQDN of a Service `payments` in namespace `billing`. Name each of
    the four parts.
16. From a Pod in `default`, `nslookup payments` fails but the FQDN works. Why?
17. You create an Ingress and nothing responds. What is missing? And what is the
    difference between Ingress-NGINX and the Ingress API in 2026?
18. What is the default NetworkPolicy behaviour, what changes when the first
    policy selects a Pod, and what happens when two policies select it?

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — The Service that resolves but never answers

`kubectl get svc api` shows a ClusterIP. `nslookup api.prod.svc.cluster.local`
from another Pod returns that IP. Every connection times out. The three backing
Pods are `Running`.

a. DNS works but traffic does not. What does that already rule out, and what
   does it point at?
b. Name the one command that decides this, and both possible causes for the
   result you expect.
c. `kubectl get pods` shows `1/1 Running` for all three, yet the result in (b)
   is still empty. Which cause is it, and how can a Pod be Running and still be
   excluded?
d. A colleague suggests restarting kube-proxy. Explain why that cannot help,
   using what kube-proxy reads.
e. The Service is fixed. Trace a packet from the client Pod to a backend,
   naming every component and where the destination address is rewritten.

### Drill 2 — Fresh cluster, nothing works

You finish `kubeadm init`. `kubectl get nodes` shows the control-plane node
`NotReady`. Every Pod in `kube-system` is `Running` except CoreDNS, which is
`Pending`.

a. Give the single missing component and explain why the node reports
   `NotReady` because of it.
b. Why is CoreDNS `Pending` while other `kube-system` Pods are `Running`? What
   is different about the ones that started? (Note 03 §1.13 is relevant.)
c. You install Calico. In what order do things recover, and why does CoreDNS
   have to come after the CNI rather than before?
d. Why was Calico chosen over Flannel for this cluster? Name the specific
   capability and the exam that needs it.
e. Once healthy, you create a `type: LoadBalancer` Service and it stays
   `<pending>`. Is this the same class of problem as (a)? Justify — what is
   missing in each case, and is either one fixable by installing something?

### Drill 3 — The policy that broke DNS

A namespace runs an app and a database. You apply your first NetworkPolicy: a
default-deny on the app Pods, plus an allow rule for traffic to the database on
port 5432. The database connection now works. Every other outbound call from the
app fails, including name resolution.

a. Before the policy, what could the app Pods reach? State the default.
b. The policy allows 5432 to the database. Why did DNS break — what does the app
   need to reach that the policy does not mention?
c. Which namespace does CoreDNS live in, and why does that make the fix
   different from the database rule you already wrote?
d. The app can reach the database by IP but not by name. Which layer is broken
   and which is fine — and what does that tell you about where to look first in
   any similar outage?
e. A second policy is added allowing all egress. Does that override the
   default-deny, or conflict with it? Explain using how multiple policies
   combine.
f. Would any of this have happened on a Flannel cluster? Explain what you would
   have observed instead, and why that is more dangerous than the failure here.

### Drill 4 — Exposing an app four ways

A team runs `web` (3 replicas) and must expose it. Evaluate each option on your
kubeadm cluster and on EKS.

a. `type: ClusterIP` — who can reach it, and what is it useful for?
b. `type: NodePort` — give the port range, say which nodes open the port, and
   explain what happens to a request arriving at a node with no `web` Pod on it.
c. `type: LoadBalancer` — outcome on kubeadm vs on EKS. Name the component whose
   presence or absence decides it.
d. An Ingress with a host rule — what else must exist, and what happens if it
   does not? Name a 2026-specific complication in choosing that component.
e. The team wants ten apps on one hostname with different paths. Which option is
   correct and why are the other three wrong?
f. They now need to expose a PostgreSQL database to an external client. Which of
   the four still works, which stops working, and why?
