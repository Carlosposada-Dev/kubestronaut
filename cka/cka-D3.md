---
domain: D3 — Services and Networking
weight: 20%
exams: [CKA, CKAD, CKS]
theory: notes_05
k8s_version: v1.37
status: draft | drilled | timed-clean
window: W2 — Mon 21 to Thu 24 Sep
---

# D3 — Services and Networking (20%)

> Operational layer. Theory in notes_05 (recalled 67% — the weakest of the
> eleven; its 5 queued amendments are applied Thu 24 Sep).
> ⚙️ pre-written · ✍️ you write it. §0 drill: `cka-D1.md` §0.

---

## 3.1 Connectivity between Pods ✍️

**Theory →** notes_05 §1.1–1.3 · **Docs →** search `cluster networking` ·
**Target: 4 min to diagnose**

Must contain the debugging ladder, in this order — it is the same ladder D5
asks for under a different name:

1. Pod → Pod by **IP**, same node
2. Pod → Pod by **IP**, across nodes (if 1 works and 2 does not, it is the CNI)
3. Pod → **Service ClusterIP**
4. Pod → **Service DNS name**

Your throwaway client, and the flag that stops it from lingering:
`kubectl run tmp --image=busybox:1.36 --rm -it --restart=Never -- sh`

**Amendments from Block 1 that land here:** veth pairs + routes mean **no NAT**
between Pods · `hostNetwork: true` puts the Pod in the node's namespace (and its
ports on the node) · inside vs outside the Pod network is the first question, not
the last.

⚠️ **EKS:** VPC CNI gives every Pod a real VPC IP from an ENI, capped per
instance type — Pods are routable from the VPC and you can exhaust IPs. Calico
here is an overlay: the Pod CIDR (`10.244.0.0/16`) is invisible outside the
cluster. Opposite failure modes.

```
(your runbook here)
```

---

## 3.2 Define and enforce NetworkPolicy ✍️

**Theory →** notes_05 §3.x · **Docs →** search `network policies` → copy the
example YAML · **Target: 7 min**

**This one cannot be created imperatively at all.** There is no
`kubectl create networkpolicy`. The fastest path is the docs example + edit —
so the drill is *finding that page fast*, not typing.

Must contain: default-deny ingress for a namespace, then opening exactly one
path; `podSelector: {}` (all Pods) vs a label selector; the three peer types
(`podSelector`, `namespaceSelector`, `ipBlock`); and the YAML shape that costs
people the task:

- `- podSelector: {...}` **and** `namespaceSelector` in ONE list item = AND
- two separate list items = OR

Verification is not `kubectl get netpol`. It is a curl from a Pod that **should**
be blocked and one that **should** pass. Both directions, every time.

**Trap:** a NetworkPolicy is only enforced if the CNI implements it. Calico does.
Flannel does not — the object is accepted and silently ignored.

```
(your runbook here)
```

---

## 3.3 ClusterIP, NodePort, LoadBalancer and endpoints ✍️

**Theory →** notes_05 §2.x · **Docs →** search `service` ·
**Target: 3 min**

Must contain: `expose` and `create service` imperative lines for all three
types, the meaning of `port` vs `targetPort` vs `nodePort`, and the **endpoint
check as the first diagnostic**:

`kubectl get endpointslice -l kubernetes.io/service-name=<svc>`

Empty endpoints = the selector does not match the Pod labels, or no Pod is
ready. That single check answers most "the Service does not work" tasks.

**Traps:** `LoadBalancer` stays `<pending>` on your cluster forever — correct
behaviour, there is no cloud-controller-manager. Do not "fix" it · a headless
Service is `clusterIP: None` and returns Pod IPs from DNS · the kubelet runs the
readiness probe, the endpointslice controller only copies the result.

⚠️ **EKS:** `<pending>` resolves because the **AWS cloud-controller-manager**
(in-tree, CLB) or the **AWS Load Balancer Controller** (NLB/ALB) provisions it.
Name the component — "the cloud handles it" scores zero (`mistakes.md` row 75).

```
(your runbook here)
```

---

## 3.4 Use the Gateway API to manage Ingress traffic ⚙️ — NEW, pre-written

**Theory →** notes_05 §4.x (conceptual only) · **Docs →** search
`gateway api` · **Target: 8 min**

This replaced Ingress as the exam's forward-looking bullet and is the piece
least likely to exist anywhere in your experience. Three objects, three owners:

| Object | Owned by | Analogy to Ingress |
|---|---|---|
| `GatewayClass` | infrastructure provider | IngressClass |
| `Gateway` | cluster operator | the controller's listener |
| `HTTPRoute` | application team | the Ingress rules |

```bash
# CRDs are NOT in a default cluster — install them first, or nothing applies
kubectl get crd | grep gateway.networking.k8s.io
kubectl apply -f <gateway-api standard-install manifest>
kubectl get gatewayclass          # must exist before a Gateway can bind
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gw
  namespace: default
spec:
  gatewayClassName: <class>
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same          # Same | All | Selector
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gw            # binds to the Gateway
  hostnames:
  - "web.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix    # PathPrefix | Exact | RegularExpression
        value: /api
    backendRefs:
    - name: web-svc
      port: 80
```

**Verify:**
```bash
kubectl get gateway web-gw          # PROGRAMMED=True is the real signal
kubectl get httproute web-route -o wide
kubectl describe httproute web-route | grep -A5 Parents   # Accepted / ResolvedRefs
curl -H "Host: web.example.com" http://<gateway address>/api
```

**Traps:** `PROGRAMMED=False` usually means no controller implements the
`GatewayClass` · an HTTPRoute in another namespace is rejected unless the
Gateway's `allowedRoutes` permits it — the error is on the **route**, not the
Gateway · `backendRefs` points at a **Service**, not a Pod or Deployment ·
nothing is created imperatively here; it is all YAML from the docs.

---

## 3.5 Ingress controllers and Ingress resources ✍️

**Theory →** notes_05 §4.x · **Docs →** search `ingress` ·
**Target: 6 min**

Must contain: installing a controller (Helm — cross-reference `cka-D1.md` 1.6),
the imperative `create ingress` line with the `--rule` syntax, `ingressClassName`,
and path types (`Prefix`, `Exact`, `ImplementationSpecific`).

**Trap:** an Ingress object with no controller running is accepted by the API
server and does absolutely nothing. `ADDRESS` stays empty. Check the controller
Pod first, always.

```
(your runbook here)
```

---

## 3.6 Understand and use CoreDNS ✍️

**Theory →** notes_05 §5.x · **Docs →** search `dns pod service` /
`debugging dns resolution` · **Target: 5 min**

Must contain: the FQDN pattern `<svc>.<ns>.svc.cluster.local`, where the config
lives (`kubectl -n kube-system get cm coredns -o yaml` — the Corefile), how to
edit it, how to restart CoreDNS so the change takes, and the two-step diagnosis:
resolve from a Pod (`nslookup`), then check `/etc/resolv.conf` inside the Pod for
the nameserver and the `search` line.

**Traps:** `dnsPolicy: Default` means *the node's* resolver, not the cluster's —
the name is backwards from what it implies · after editing the Corefile you must
`kubectl -n kube-system rollout restart deploy coredns` · a headless Service
returns several A records, not one.

```
(your runbook here)
```

---

## §7. Drill table

| # | Task | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|
| 1 | Pod→Pod, Pod→ClusterIP, Pod→DNS ladder from a tmp Pod | 4:00 | | | | | |
| 2 | Default-deny + one allowed path, proved both ways | 7:00 | | | | | |
| 3 | Expose a Deployment as ClusterIP and NodePort | 3:00 | | | | | |
| 4 | Empty-endpoints diagnosis (label mismatch) | 3:00 | | | | | |
| 5 | Gateway + HTTPRoute + curl through it | 8:00 | | | | | |
| 6 | Ingress controller install + rule + curl | 6:00 | | | | | |
| 7 | Edit the Corefile, restart, prove resolution changed | 5:00 | | | | | |

## §8. Objectives scoreboard — D3

| Bullet | Performed from memory, timed, verified |
|---|---|
| 3.1 Pod connectivity | ☐ |
| 3.2 NetworkPolicy | ☐ |
| 3.3 Service types & endpoints | ☐ |
| 3.4 Gateway API | ☐ |
| 3.5 Ingress | ☐ |
| 3.6 CoreDNS | ☐ |
| **Total** | **0 / 6** |
