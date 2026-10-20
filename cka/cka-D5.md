---
domain: D5 — Troubleshooting
weight: 30%
exams: [CKA, CKAD]
theory: notes_08, notes_09, notes_01, notes_05, notes_06
k8s_version: v1.35
status: draft | drilled | timed-clean
window: W3 — Thu 1 to Sat 3 Oct + both Sundays
---

# D5 — Troubleshooting (30%)

> **The largest domain, and the one that cannot be studied first.** D5 is the
> other four domains examined backwards: you are shown a broken thing and asked
> what is missing. That is why it is last.
>
> Theory in notes_08 (recalled 71%→94%) and notes_09. ⚙️ pre-written ·
> ✍️ you write it. §0 drill: `cka-D1.md` §0.

**The method, before any bullet.** Under a clock, guessing is the enemy. Three
steps, in this order, every single time:

1. **`kubectl describe`** the object and read the **Events** verbatim. Most CKA
   troubleshooting tasks are solved by the last event line.
2. **Where does it break?** control plane → node → Pod → container. Answer that
   before touching anything.
3. **Fix one thing, then re-verify.** Two changes at once and you no longer know
   what worked.

The 8-minute rule matters most here: a D5 task you cannot see into after 8
minutes is a flag-and-move, not a fight.

---

## 5.1 Troubleshoot clusters and nodes ⚙️ — pre-written

**Theory →** notes_08 §3.x, notes_01 · **Docs →** search
`debug cluster` / `debug running pod` · **Target: 8 min**

**The decision that splits the whole bullet: is the kubelet talking to the API
server?** Everything else follows from it.

| Node condition | Meaning | Where to look |
|---|---|---|
| `Ready=False` | kubelet **is** reporting, and reports a problem | The condition message: disk, memory, PID, CNI not ready |
| `Ready=Unknown` | kubelet has **stopped reporting** | The node itself: is kubelet running at all? |
| `NotReady` + CNI missing | No network plugin | `ls /etc/cni/net.d/` |

```bash
kubectl get nodes
kubectl describe node <n>            # Conditions + Events, read them fully
kubectl get node <n> -o jsonpath='{.status.conditions}' | jq

# --- on the node itself ---
sudo systemctl status kubelet
sudo journalctl -u kubelet -f --no-pager        # the single most useful command here
sudo journalctl -u kubelet -n 100 --no-pager
sudo systemctl status containerd
sudo crictl ps -a                    # containers the kubelet sees, API server or not

# kubelet config, in order of how often it is the answer
/var/lib/kubelet/config.yaml         # kubelet's own config
/etc/kubernetes/kubelet.conf         # kubeconfig it uses to reach the API server
/var/lib/kubelet/pki/                # its rotating client cert
```

**Verify the fix:** `kubectl get nodes` → `Ready`, then
`kubectl -n kube-system get pods -o wide --field-selector spec.nodeName=<n>`
to prove workloads actually land there again.

**Most frequent real causes, in order:** kubelet service stopped or masked ·
swap turned back on · wrong `--container-runtime-endpoint` / containerd dead ·
expired kubelet client cert · CNI config removed · disk pressure.

⚠️ **EKS:** a `NotReady` node is usually replaced by the node group rather than
repaired, and you read the answer from CloudWatch. Here nobody replaces it — you
fix it by hand. This is the single largest gap between your day job and D5.

---

## 5.2 Troubleshoot cluster components ⚙️ — pre-written

**Theory →** notes_01 §1.x, notes_08 · **Docs →** search
`kubeadm troubleshooting` · **Target: 8 min**

The control plane runs as **static Pods**: the kubelet watches
`/etc/kubernetes/manifests/` and restarts whatever changes on disk. You do not
`kubectl edit` them — you edit the file, and the kubelet acts.

```bash
ls /etc/kubernetes/manifests/        # etcd, kube-apiserver, kube-controller-manager, kube-scheduler
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml     # save = restart

# when kubectl itself is dead, kubectl logs is not available. Use the runtime:
sudo crictl ps -a | grep apiserver
sudo crictl logs <container-id>
sudo journalctl -u kubelet -n 50 --no-pager   # the kubelet reports why the static Pod fails

# when kubectl works, the component logs are normal Pod logs:
kubectl -n kube-system logs kube-apiserver-cp1
kubectl -n kube-system logs kube-controller-manager-cp1 --previous
```

**The trap that defines this bullet:** a typo in a static Pod manifest means the
API server never comes up, so `kubectl` returns "connection refused" — and
people then debug `kubectl`. The manifest is on disk; go read it. A YAML that
fails to parse is worse than one that is wrong: the kubelet logs it and the
container is never created, so `crictl ps -a` shows nothing at all.

**Component → symptom map:**

| Broken | Symptom |
|---|---|
| kube-apiserver | `kubectl` refuses to connect at all |
| kube-scheduler | Pods stay `Pending` forever, no scheduler event |
| kube-controller-manager | Deployments create no ReplicaSets; nodes never get cleaned up |
| etcd | API server up but erroring; nothing persists |
| kubelet | Node goes `Unknown`; static Pods on that node stop |

**Verify:** `kubectl get --raw='/readyz?verbose'` ·
`kubectl -n kube-system get pods` · `kubectl get componentstatuses` (deprecated
but still answers).

**Restore rule for your lab:** every break/fix session starts from
`clean-v135`. If a fix takes more than 20 minutes, restore and redo the break —
you are learning the failure, not the archaeology.

---

## 5.3 Monitor cluster and application resource usage ✍️

**Theory →** notes_09 §2.x · **Docs →** search `resource metrics pipeline` ·
**Target: 4 min**

Must contain: installing metrics-server on a kubeadm cluster (and the flag it
needs there — self-signed kubelet certs), `kubectl top nodes`, `kubectl top pods`
with `--containers` and `-A`, and sorting to find the heaviest consumer.

**Trap:** `kubectl top` failing is not a monitoring problem, it is a
metrics-server problem — and an HPA on CPU depends on the same pipeline
(cross-reference `cka-D2.md` 2.3).

```
(your runbook here)
```

---

## 5.4 Manage and evaluate container output streams ✍️

**Theory →** notes_09 §3.x · **Docs →** search `logging architecture` ·
**Target: 3 min**

Must contain: `logs` with `-c`, `--previous`, `-f`, `--tail`, `--since`,
`-l <selector>`, and where the files actually live on the node
(`/var/log/pods/`, `/var/log/containers/`) for when the API server is down.

**The literal that matters:** `--previous` reads the **crashed** container.
For a `CrashLoopBackOff` the current container's logs are usually empty — the
evidence is in the previous one. Forgetting this flag turns a solvable task into
a dead end.

```
(your runbook here)
```

---

## 5.5 Troubleshoot services and networking ✍️

**Theory →** notes_05, notes_08 · **Docs →** search `debug service` ·
**Target: 6 min**

Must contain the ladder from `cka-D3.md` 3.1 plus the Service-specific checks:
endpoints populated? selector matches Pod labels? `targetPort` matches the
container port? readiness probe passing? CoreDNS resolving?

**Amendments landing here:**
- A not-ready Pod **stays** in the EndpointSlice with `ready: false` — it is not
  removed, so "the endpoint exists" is not proof it serves traffic.
- `CreateContainerConfigError` happens **after** a successful image pull — it is
  a missing ConfigMap/Secret reference, not a registry problem.

```
(your runbook here)
```

---

## §6. Pod status → first move (memorise this table)

| Status | First thing you check |
|---|---|
| `Pending` | `describe pod` → scheduler event: resources, taint, no node, PVC unbound |
| `ImagePullBackOff` / `ErrImagePull` | Image name/tag, registry auth (`imagePullSecrets`) |
| `CreateContainerConfigError` | Missing ConfigMap or Secret named in the spec |
| `CrashLoopBackOff` | `logs --previous`, then the command/args and probes |
| `Running` but not `Ready` | Readiness probe — `describe` shows the failure |
| `Terminating` forever | Finalizer, or the node is gone |
| `OOMKilled` | `describe` → last state; the memory limit, not the request |
| `Evicted` | Node pressure — `describe node` conditions |

---

## §7. Drill table — the break/fix set

Each one: coach breaks it, you diagnose **blind**, fix, verify.

| # | Break | Target | A1 | A2 | A3 | Date | ✅ |
|---|---|---|---|---|---|---|---|
| 1 | Typo in `kube-apiserver.yaml` static Pod | 8:00 | | | | | |
| 2 | Wrong `--etcd-servers` on the API server | 8:00 | | | | | |
| 3 | kubelet stopped on w1 | 5:00 | | | | | |
| 4 | swap re-enabled on w2 | 5:00 | | | | | |
| 5 | CNI config removed from a node | 6:00 | | | | | |
| 6 | Expired control-plane cert | 8:00 | | | | | |
| 7 | Service with a selector that matches nothing | 4:00 | | | | | |
| 8 | Pod referencing a non-existent Secret | 4:00 | | | | | |
| 9 | CrashLoopBackOff — answer is in `--previous` | 5:00 | | | | | |
| 10 | CoreDNS Corefile broken | 6:00 | | | | | |
| 11 | metrics-server down, `kubectl top` fails | 5:00 | | | | | |
| 12 | PVC Pending — no default StorageClass | 4:00 | | | | | |

## §8. Objectives scoreboard — D5

| Bullet | Performed from memory, timed, verified |
|---|---|
| 5.1 Clusters and nodes | ☐ |
| 5.2 Cluster components | ☐ |
| 5.3 Resource usage monitoring | ☐ |
| 5.4 Container output streams | ☐ |
| 5.5 Services and networking | ☐ |
| **Total** | **0 / 5** |
