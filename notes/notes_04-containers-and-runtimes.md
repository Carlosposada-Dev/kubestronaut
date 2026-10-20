---
exams: [KCNA, CKS]
domain: Containers & Runtimes
kcna_domains: 1.4 Containerization
curriculum_version: KCNA curriculum as published 2026-08-14 (44/28/16/12)
sources: opencontainers.org (runtime-spec, image-spec, distribution-spec), kubernetes.io/docs/concepts/containers/, /concepts/architecture/cri, /setup/production-environment/container-runtimes/, /tasks/administer-cluster/migrating-from-dockershim/, containerd.io docs, cri-o.io docs
source_discipline: Docker documentation is used ONLY for §1.12 (Dockerfile and image build). KCNA is post-dockershim and runtime-agnostic — it asks about OCI, CRI, containerd and runc, not about Docker. See claude/sources.md blacklist.
template: B
language: en
scope: KCNA ONLY — CKS layer appended in Block 5 (from 26 Oct)
status: draft
written: 2026-09-01
k8s_version_checked_against: v1.37 (released 2026-08-26). Spec release dates verified against opencontainers.org and the Linux Foundation announcement of 19 Jul 2017; CNCF maturity dates verified against cncf.io project pages.
---

# Containers & Runtimes

What a container actually *is* at the kernel level, who runs it, and how the
image it comes from is built and shipped. KCNA area 1.4 ≈ 6–7 of the 60
questions. This is also the note where **Docker is a trap**: Docker is one
product built on these standards, and the exam asks about the standards.

---

## 1. Core Concepts

### 1.1 Container vs virtual machine

The one-line answer the exam wants: **a VM virtualises hardware and runs its own
kernel; a container is an isolated process that shares the host kernel.**

| | Virtual machine | Container |
|---|---|---|
| Isolation by | Hypervisor virtualising hardware | Kernel features (namespaces + cgroups) |
| Kernel | **Its own**, one per VM | **Shared** with the host |
| Guest OS | Full OS install | Only userspace — libraries and binaries |
| Boot | Seconds to minutes | Milliseconds — it is just `fork`/`exec` |
| Size | Gigabytes | Megabytes |
| Isolation strength | **Stronger** — a hardware boundary | **Weaker** — a shared kernel is a shared attack surface |
| Runs a different OS kernel? | Yes (Windows on Linux host) | **No** — Linux containers need a Linux kernel |

A container is **not** a lightweight VM. It is a normal Linux process that has
been lied to about what it can see (namespaces) and how much it can consume
(cgroups). `ps aux` on the host shows container processes as ordinary processes.

That shared kernel is the reason **sandboxed runtimes** exist — gVisor
(intercepts syscalls in userspace) and Kata Containers (runs each container in a
lightweight VM) trade performance for a real kernel boundary. KCNA only asks
that you know they exist and why.

### 1.2 Linux namespaces — what a container can *see*

A namespace partitions a global kernel resource so that processes inside see
their own private copy. Isolation, not limitation.

| Namespace | Isolates | Effect inside the container |
|---|---|---|
| `mnt` | Mount points | Its own filesystem tree and root |
| `pid` | Process IDs | Its main process is **PID 1**; host processes are invisible |
| `net` | Network stack | Own interfaces, IP, routes, ports, iptables |
| `ipc` | Shared memory, semaphores | Cannot reach host IPC objects |
| `uts` | Hostname, domain name | Own hostname |
| `user` | UID/GID mapping | Can be root (UID 0) inside, unprivileged outside |
| `cgroup` | cgroup root directory | Cannot see the host's cgroup hierarchy |
| `time` | Clock offsets | Own boot/monotonic clock (Linux 5.6+) |

**PID 1 matters.** The kernel treats PID 1 specially: it must reap orphaned
child processes and it does not get default signal handlers. An app that is not
written for PID 1 may ignore `SIGTERM` and get force-killed at the end of the
termination grace period.

### 1.3 cgroups — what a container can *consume*

Control groups limit and account for resources. Namespaces answer "what can I
see"; cgroups answer "how much can I use". They are separate kernel features and
the exam likes to test that you do not conflate them.

| Controller | Limits | Kubernetes field it comes from |
|---|---|---|
| `cpu` | CPU shares and quota | `resources.requests/limits.cpu` |
| `memory` | Memory ceiling, triggers OOM kill | `resources.limits.memory` |
| `pids` | Number of processes | Node-level `podPidsLimit` |
| `io` | Block device bandwidth | Not exposed as a Pod field |

**cgroup v1 vs v2:** v1 has a separate hierarchy per controller; **v2 uses one
unified hierarchy**, which is what makes consistent accounting possible.
Kubernetes support for cgroup v2 went **GA in v1.25**, and modern distributions
default to v2.

The kubelet writes these values; the runtime applies them. This is the machinery
behind note 03 §1.11 — a **CPU** limit becomes `cpu.max` and produces
**throttling**, a **memory** limit becomes `memory.max` and produces an
**OOMKill**.

### 1.4 What a Pod is, at this level

A Pod is not a kernel object. It is a **group of containers that share a subset
of namespaces**:

| Namespace | Shared across containers in a Pod? |
|---|---|
| `net` | **Yes** — one IP, one port space, they reach each other on `localhost` |
| `ipc` | **Yes** |
| `uts` | **Yes** — same hostname |
| `mnt` | **No** — each container has its own filesystem. Volumes are how they share files |
| `pid` | **No** by default; `spec.shareProcessNamespace: true` enables it |

The sharing is held together by the **pause container** (also called the sandbox
or infra container). It does nothing but sleep, and it exists to **own the
network namespace**: application containers join the namespace it holds, so a
crashing and restarting container does not change the Pod IP. It is also the
`pid 1` reaper when the PID namespace is shared. You will see it in `crictl ps`
but never in `kubectl get pods`.

### 1.5 OCI — the three specifications

The **Open Container Initiative** was founded in **June 2015** under the Linux
Foundation, when Docker donated its `libcontainer` runtime and image format so
that no single vendor would own the container format. It publishes **three**
specs — memorising which is which is a near-guaranteed KCNA question.

| Spec | Defines | Question it answers | v1.0.0 |
|---|---|---|---|
| **runtime-spec** | The **filesystem bundle** (`config.json` + `rootfs/`) and the lifecycle verbs create/start/kill/delete | *How do I run an unpacked container?* | Jul 2017 |
| **image-spec** | Image layout: manifest, config, layers, image index, media types | *What is an image made of?* | Jul 2017 |
| **distribution-spec** | The HTTP API for pushing and pulling from a registry | *How do images move over the network?* | 2021 |

The workflow that connects them: **pull an OCI image (distribution-spec) →
unpack it into a filesystem bundle (image-spec → runtime-spec) → run the bundle
with an OCI runtime.**

`runtime-spec` reached v1.1.0 in Jul 2023 and v1.2.0 in Feb 2024; `image-spec`
and `distribution-spec` both reached v1.1.0 in Feb 2024.

### 1.6 runc, and the two layers of "runtime"

The word *runtime* means two different things, and questions exploit it.

| Layer | Job | Examples |
|---|---|---|
| **High-level** (container runtime / CRI runtime) | Pulls images, manages storage and networking, talks to the kubelet over CRI, supervises containers | **containerd**, **CRI-O** |
| **Low-level** (OCI runtime) | Given a bundle on disk, makes the kernel calls that create namespaces and cgroups, then `exec`s the process | **runc**, crun, gVisor, Kata |

**runc** is the reference implementation of the runtime-spec. It is a binary,
not a daemon: it sets up the namespaces and cgroups, starts the process, and
**exits**. Because it exits, something must stay behind to hold the container's
stdout/stderr and report its exit code — that is the **shim** (`containerd-shim`,
`conmon` for CRI-O). The shim is also why restarting containerd does not kill
running containers.

The full chain on a kubeadm node:

```
kubelet → (CRI, gRPC over a unix socket) → containerd → containerd-shim → runc → your process
```

### 1.7 CRI — what it is and why it exists

The **Container Runtime Interface** is a **gRPC API** that the kubelet uses to
talk to whatever runtime is installed. The kubelet is the **client**; the
runtime is the **server**, listening on a unix socket
(`/run/containerd/containerd.sock`, `/var/run/crio/crio.sock`).

Two services:

| Service | Does |
|---|---|
| `RuntimeService` | Pod sandboxes, containers, start/stop, `exec`, `attach`, logs |
| `ImageService` | Pull, list, remove images; report disk usage |

**Why it exists** is the actual exam question. Before CRI (introduced in
**v1.5**), support for each runtime lived **inside the kubelet's own source
tree**. Adding a runtime meant patching Kubernetes; every runtime's bugs became
Kubernetes' bugs, and every runtime had to be maintained by the Kubernetes
project. CRI turns runtime support into a **contract**: implement the gRPC
interface and the kubelet can drive you, with no Kubernetes code changes at all.
It is the same pattern as CNI for networking and CSI for storage — **the
interface is in-tree, the implementation is out-of-tree.**

### 1.8 containerd and CRI-O

Both are CNCF **Graduated** projects, both implement CRI, both call **runc**
underneath. You will not be asked to choose; you will be asked what they are.

| | containerd | CRI-O |
|---|---|---|
| Origin | Split out of Docker Engine; donated to CNCF Mar 2017 | Born in the Kubernetes incubator 2016, by Red Hat |
| Graduated | **Feb 2019** | **Jul 2023** |
| Scope | General-purpose — used by Docker, Kubernetes, and standalone | **Kubernetes only**, deliberately minimal |
| Shim | `containerd-shim` | `conmon` |
| Default in | Most distributions, EKS, GKE, AKS | OpenShift |

### 1.9 dockershim — removed in v1.24

**The fact to memorise: dockershim was removed in Kubernetes v1.24 (May 2022).**

Docker Engine was written years before CRI and does not implement it. To keep
Docker working, the kubelet shipped an internal adapter called **dockershim**
that translated CRI calls into Docker API calls. It was the only in-tree
exception left after CRI existed, and it was maintained by the Kubernetes
project for a runtime it did not own.

The path was also absurd once containerd was split out of Docker:

```
before:  kubelet → dockershim → Docker Engine → containerd → runc
after:   kubelet → containerd → runc
```

**What did NOT break, and this is the distractor:** images built with `docker
build` still run perfectly. Docker produces **OCI-compliant images**, and the
image format was never the problem — only the *runtime API* was. Anyone who
needed Docker Engine specifically could install **cri-dockerd**, an
out-of-tree adapter maintained by Mirantis.

The practical consequence for you: **there is no `docker` CLI on a Kubernetes
node**, so `docker ps` is not a debugging command. The tool is **`crictl`**.

### 1.10 Image anatomy — layers, manifest, digest

An image is **not** a single file. It is a set of content-addressed blobs plus
JSON describing them.

| Piece | What it is |
|---|---|
| **Layer** | A tar archive of filesystem changes. Read-only |
| **Config** | JSON: env vars, entrypoint, working dir, user, and the ordered list of layer digests |
| **Manifest** | JSON pointing at the config and the layers, each by digest |
| **Image index** | Optional. Maps platforms (`linux/amd64`, `linux/arm64`) to manifests — this is how multi-arch works |

**Layers stack via a union filesystem** (usually overlayfs). Each instruction in
a build that changes the filesystem produces one layer. At run time the runtime
mounts the read-only layers and adds a **thin writable layer on top**;
modifications use **copy-on-write** — the file is copied up into the writable
layer, and the layer below is untouched. That writable layer is discarded when
the container dies, which is exactly why containers are ephemeral and why you
need volumes (note 06).

Layers are shared: ten images built `FROM ubuntu:22.04` store that base **once**
on the node, keyed by digest.

**Tag vs digest — high-yield:**

| | Tag | Digest |
|---|---|---|
| Looks like | `nginx:1.27` | `nginx@sha256:abc123...` |
| Is | A **mutable pointer** to a manifest | The **sha256 of the manifest itself** |
| Can it change? | **Yes** — the owner can re-push the same tag over new content | **No** — content-addressed. Different content, different digest |
| Reproducible? | No | **Yes** |

This is why "we deployed the same tag and got different behaviour" is a real
incident and not a mystery.

### 1.11 Registries and the pull path

A **registry** stores and serves images over the distribution-spec API: Docker
Hub, GHCR, Quay, Amazon ECR, or a private Harbor. A full reference is
`registry/namespace/repository:tag` — and when you write `nginx`, the missing
parts are defaulted (Docker Hub, `library` namespace, tag `latest`).

The kubelet asks the runtime (via `ImageService`) to pull; the runtime fetches
the manifest, then only the layers it does not already have. Private registries
need credentials, supplied as an `imagePullSecrets` reference on the Pod or
ServiceAccount, holding a `kubernetes.io/dockerconfigjson` Secret.

**`imagePullPolicy` — memorise the defaulting rule:**

| Value | Behaviour |
|---|---|
| `IfNotPresent` | Pull only if the image is not on the node. **The default** |
| `Always` | Check the registry every time the Pod starts |
| `Never` | Never pull; fail if the image is absent locally |

**The trap:** the default is `IfNotPresent` **except** when the tag is `latest`
or the tag is omitted entirely — then it silently becomes **`Always`**. This is
the mechanical reason `:latest` is discouraged, on top of the reproducibility
argument.

### 1.12 Dockerfile basics

*This is the only section where Docker documentation is the right source — the
build format is Docker's, the resulting image is OCI's.*

| Instruction | Does | Layer? |
|---|---|---|
| `FROM` | Base image. `FROM scratch` = empty | — |
| `RUN` | Execute a command **at build time** | **Yes** |
| `COPY` | Copy files from build context into the image | **Yes** |
| `ADD` | Like COPY, but also unpacks tars and fetches URLs. **Prefer COPY** | Yes |
| `WORKDIR` | Set the working directory | Metadata |
| `ENV` | Environment variable | Metadata |
| `USER` | Which UID the process runs as | Metadata |
| `EXPOSE` | **Documentation only** — publishes nothing | Metadata |
| `ENTRYPOINT` | The executable to run | Metadata |
| `CMD` | Default arguments, or the command if there is no ENTRYPOINT | Metadata |

**ENTRYPOINT vs CMD, and how Kubernetes overrides them** — this mapping is worth
memorising exactly:

| Dockerfile | Kubernetes field |
|---|---|
| `ENTRYPOINT` | `spec.containers[].command` |
| `CMD` | `spec.containers[].args` |

Setting `command` in a Pod **replaces** the image's ENTRYPOINT; setting `args`
replaces CMD.

**Multi-stage builds** are the single most important build technique for image
size: compile in a fat builder stage, then copy only the resulting binary into a
minimal final stage. The toolchain never ships.

```dockerfile
FROM golang:1.23 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/server

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app /app
USER 65532:65532
ENTRYPOINT ["/app"]
```

### 1.13 Minimal base images

Every binary in an image is attack surface and something to patch. Smaller
images also pull faster, which shortens Pod start time.

| Base | Contains | Shell? | Package mgr? | Trade-off |
|---|---|---|---|---|
| `ubuntu` / `debian` | Full userspace | Yes | Yes | Easy to debug, large, many CVEs |
| `alpine` | musl libc + BusyBox, ~5 MB | Yes | `apk` | Small, but **musl not glibc** — subtle DNS and compatibility bugs |
| **distroless** | Language runtime + CA certs only | **No** | **No** | Small attack surface; `kubectl exec` gives you no shell |
| `scratch` | **Nothing at all** | No | No | Smallest possible; needs a **statically linked** binary |

"No shell" is a security win and a debugging cost. The answer to that cost is
**ephemeral containers** (`kubectl debug`), covered in note 08.

### 1.14 Image hygiene

| Practice | Why |
|---|---|
| **Never `:latest`** | Not reproducible — the tag moves under you — and it silently flips `imagePullPolicy` to `Always` |
| **Pin by digest** in production | The only genuinely immutable reference |
| **Run as non-root** | `USER` in the Dockerfile, enforced by `securityContext.runAsNonRoot: true`. A container root that escapes the namespace is host root |
| **Minimal base image** | Fewer packages, fewer CVEs, faster pulls |
| **Multi-stage build** | Compilers and build secrets never reach the shipped image |
| **Scan images** | Trivy or similar, in CI |
| **Never bake secrets into a layer** | Deleting a file in a later layer does **not** remove it from the earlier layer — it is still in the image and readable |
| **Read-only root filesystem** | `securityContext.readOnlyRootFilesystem: true` |

That secrets row is a favourite: a layer is an immutable tar. `RUN rm secret.txt`
adds a *new* layer marking it deleted; the original bytes ship with the image.

---

## 2. Objects & Fields That Matter

| Object / concept | Key fields or paths | Note |
|---|---|---|
| Container image | `spec.containers[].image` | Tag or `@sha256:` digest |
| Pull behaviour | `spec.containers[].imagePullPolicy` | `IfNotPresent`, unless tag is `latest`/absent → `Always` |
| Private registry | `spec.imagePullSecrets`, Secret type `kubernetes.io/dockerconfigjson` | Can also be attached to the ServiceAccount |
| Entrypoint override | `spec.containers[].command` / `.args` | ENTRYPOINT / CMD respectively |
| Identity | `securityContext.runAsNonRoot`, `runAsUser` | Pod-level or container-level |
| PID sharing | `spec.shareProcessNamespace` | Default `false` |
| CRI socket | `/run/containerd/containerd.sock`, `/var/run/crio/crio.sock` | The kubelet's `--container-runtime-endpoint` |
| crictl config | `/etc/crictl.yaml` | Where `crictl` learns the socket |

---

## 3. Speed Patterns

*Empty during the KCNA block. Filled in Block 5 (CKS, from 26 Oct) with image
scanning, signing and runtime-class patterns.*

---

## 4. Hands-On Lab

On the 3-node kubeadm cluster. **Target: 20 minutes.** These run on the *node*,
not through `kubectl`.

```bash
# 1. Which runtime is actually installed?                              (2 min)
kubectl get nodes -o wide          # CONTAINER-RUNTIME column
cat /etc/crictl.yaml               # on a worker: the socket crictl will use

# 2. crictl is the replacement for the docker CLI                      (6 min)
sudo crictl ps                     # running containers
sudo crictl pods                   # POD SANDBOXES — a concept kubectl hides
sudo crictl images

# 3. Find the pause container that owns the network namespace          (4 min)
sudo crictl ps -a | grep -i pause  # may be filtered; then:
sudo ctr -n k8s.io containers list | grep -i pause

# 4. Prove the container is just a host process                        (4 min)
kubectl run demo --image=nginx
ps -ef | grep nginx                # visible on the host, ordinary PIDs
sudo crictl inspect $(sudo crictl ps -q --name nginx) | grep -i -A3 cgroup

# 5. Prove a tag is mutable and a digest is not                        (4 min)
kubectl get pod demo -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
# ^ note it reports a sha256 digest, not the tag you asked for

kubectl delete pod demo
```

---

## 5. Verification

```bash
kubectl get nodes -o wide                                  # runtime + version
kubectl get pod <p> -o jsonpath='{.spec.containers[0].image}{"\n"}'
kubectl get pod <p> -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
kubectl describe pod <p> | grep -A5 Events                 # Pulling / Pulled / Failed
sudo crictl images                                         # is the layer on this node?
sudo crictl logs <container-id>
```

The `imageID` digest is the proof of *what actually ran*. The `image` field is
only what you *asked for*.

---

## 6. Failure Modes

| Symptom | Likely cause | Command that confirms it | Fix |
|---|---|---|---|
| `ErrImagePull` → `ImagePullBackOff` | Typo, wrong registry, tag does not exist | `kubectl describe pod \| grep -A5 Events` | Fix the reference |
| `ImagePullBackOff` on a private registry | No/expired `imagePullSecrets` | Events say `unauthorized` / `denied` | Create a `dockerconfigjson` Secret and reference it |
| Old code running from a "new" deploy | Mutable tag + `IfNotPresent`, image cached on the node | Compare `imageID` digests across Pods | Use digests, or a real version tag |
| `exec format error` on start | Wrong architecture (arm64 image on amd64) | `crictl inspect`; check the image index | Build multi-arch or pin the platform |
| `CreateContainerConfigError` | Missing ConfigMap/Secret referenced by the container | `kubectl describe pod` | Create the missing object (note 07) |
| App ignores `SIGTERM`, always force-killed | Not written for PID 1, no signal handling | `kubectl describe pod` — 30s grace then kill | Add an init/`tini`, or handle the signal |
| `kubectl exec` fails: no shell | distroless or scratch base image | `kubectl exec ... -- /bin/sh` → not found | `kubectl debug` with an ephemeral container |
| Node fine but no Pod starts, kubelet errors on cgroups | containerd `SystemdCgroup = false` while the OS uses systemd | `journalctl -u kubelet` | Set `SystemdCgroup = true` in `/etc/containerd/config.toml`, restart |

---

## 7. EKS vs Vanilla

| Behaviour | On EKS | On kubeadm (the exam) |
|---|---|---|
| Installing the runtime | The AMI ships containerd pre-installed and pre-configured. You never touch it | **You install and configure containerd yourself.** Getting `SystemdCgroup = true` wrong is the classic kubeadm failure |
| The dockershim removal | Handled by AWS shipping new AMIs; invisible to you | Your choice of runtime, your problem. Nothing migrates itself |
| Registry authentication | ECR auth comes from the node's **IAM role** via a credential helper — no Secret exists | **`imagePullSecrets`** and a `dockerconfigjson` Secret, created by hand |
| Debugging containers | You rarely SSH to a node; you read CloudWatch | **`crictl` on the node is expected**, and `docker` does not exist |
| The `pause` image | Pulled from an AWS-owned ECR registry, configured in the AMI | Pulled from `registry.k8s.io`, configured in containerd's config |
| Image pull failures | Often IAM or VPC-endpoint problems | Almost always DNS, the tag, or a missing pull secret |

---

## 8. Timed Drills

*Empty during the KCNA block. Filled in Block 5.*

---

## 9. Objectives Covered

KCNA area **1.4 Containerization** — tick only when explainable without looking.

- [ ] Container vs virtual machine; where the kernel boundary is
- [ ] Linux namespaces — which eight, and what each isolates
- [ ] cgroups — what they limit, v1 vs v2, and the link to requests/limits
- [ ] Which namespaces the containers in a Pod share, and the pause container
- [ ] The three OCI specs and what each one defines
- [ ] runc as the low-level runtime; high-level vs low-level
- [ ] What CRI is and **why** it exists
- [ ] containerd and CRI-O
- [ ] dockershim removed in **v1.24**, and what did *not* break
- [ ] Image layers, union filesystem, copy-on-write
- [ ] Registries; tags vs digests; `imagePullPolicy` defaulting
- [ ] Dockerfile basics; ENTRYPOINT/CMD → command/args; multi-stage
- [ ] Minimal images: distroless, scratch, alpine
- [ ] Image hygiene: non-root, never `:latest`

---

## KCNA — Traps & Distractors

*Temporary. Delete after 9 Sep 2026; survivors migrate into §6.*

| Distractor | Why it's wrong |
|---|---|
| "A container is a lightweight VM" | No own kernel. It is a process with namespaces + cgroups |
| "Containers share the host kernel, so they can run any OS" | Linux containers require a Linux kernel |
| "Namespaces limit how much CPU a container gets" | Namespaces **isolate visibility**; **cgroups** limit consumption |
| "Removing dockershim broke Docker-built images" | Images are OCI-compliant and still run. Only the runtime API changed |
| "Kubernetes removed support for Docker images in 1.24" | It removed support for **Docker Engine as a runtime**, not for its images |
| "runc is a daemon that supervises containers" | It sets up and `exec`s, then **exits**. The **shim** supervises |
| "containerd talks to the kernel directly" | It calls **runc**, which makes the kernel calls |
| "CRI is a REST API" | **gRPC**, over a unix socket |
| "There are four OCI specs" | **Three**: runtime, image, distribution |
| "The image-spec defines how images are pushed and pulled" | That is the **distribution-spec** |
| "A tag uniquely identifies image content" | A tag is a **mutable pointer**. The **digest** is unique |
| "`imagePullPolicy` always defaults to `IfNotPresent`" | It becomes **`Always`** when the tag is `latest` or omitted |
| "`EXPOSE` in a Dockerfile publishes the port" | Documentation only. Kubernetes uses Services |
| "`CMD` maps to `command` in a Pod spec" | `CMD` → **`args`**; `ENTRYPOINT` → **`command`** |
| "Deleting a secret file in a later layer removes it from the image" | The bytes remain in the earlier layer |
| "`docker ps` is how you debug a node" | There is no Docker CLI. Use **`crictl`** |

**X ≠ Y**

- **Namespaces ≠ cgroups** — what you can see vs how much you can use
- **Container ≠ VM** — shared kernel vs own kernel
- **runtime-spec ≠ image-spec ≠ distribution-spec** — run it / what it is / move it
- **High-level runtime ≠ low-level runtime** — containerd/CRI-O vs runc
- **CRI ≠ OCI** — kubelet↔runtime API vs the container format standards
- **runc ≠ containerd** — makes the kernel calls vs manages images and lifecycle
- **Docker Engine ≠ Docker image** — a runtime that was dropped vs a format that was not
- **dockershim ≠ cri-dockerd** — removed in-tree adapter vs out-of-tree replacement
- **Tag ≠ digest** — mutable pointer vs content hash
- **`image` ≠ `imageID`** — what you asked for vs what actually ran
- **`ENTRYPOINT`/`command` ≠ `CMD`/`args`** — the executable vs its arguments
- **distroless ≠ scratch** — runtime and CA certs vs completely empty
- **alpine ≠ small glibc** — musl libc, and the incompatibilities that follow

---

## 10. Active Recall

Closed book, out loud. 18 questions.

1. In one sentence each, the difference between a container and a VM — and
   which one has a stronger isolation boundary, and why.
2. Name six of the eight Linux namespaces and what each isolates.
3. A container is limited to 500m CPU and 256Mi memory. Which kernel feature
   enforces that — and which kernel feature makes the container think it has its
   own hostname?
4. Which namespaces do containers in the same Pod share, and which one do they
   **not** share by default? How do they share files instead?
5. What is the pause container for, and why would the Pod IP be unstable
   without it?
6. Name the three OCI specifications and the question each one answers.
7. Walk the chain from `kubelet` to your running process, naming every component
   in order.
8. What does runc do, and why is a shim needed after it finishes?
9. What is CRI technically (protocol and transport), and what problem did it
   solve that did not exist before it?
10. Name two CRI implementations, and say which one is Kubernetes-only.
11. In which Kubernetes version was dockershim removed? Did images built with
    `docker build` stop working — and why or why not?
12. Why was dockershim's call path considered redundant? Draw the before and
    after.
13. What is an image layer, what makes it shareable between images, and what
    happens to the writable layer when the container dies?
14. `nginx:1.27` vs `nginx@sha256:abc...` — which can point at different content
    tomorrow, and why?
15. What is the default `imagePullPolicy`, and in which two cases does it change
    — to what?
16. A Dockerfile has `ENTRYPOINT` and `CMD`. Which Pod spec field overrides
    each?
17. What is in a distroless image and what is in `scratch`? What must be true of
    your binary to use `scratch`?
18. You `RUN rm /app/token` in a Dockerfile after copying it in. Is the token in
    the shipped image? Explain using the layer model.

---

## 11. Scenario Drills

Reason these out fully. Answers are deliberately not written down.

### Drill 1 — "It works on my machine, and on the old cluster"

A team deploys `internal-api:release` to a 3-node cluster. Two Pods serve the
new behaviour, one serves the old. All three are `Running`, all three show
`image: internal-api:release`, and nobody has changed the Deployment.

a. Explain how three Pods with an identical `image` field can be running
   different code. Name the two mechanisms that combine to produce this.
b. Which single field would you compare across the three Pods to prove it, and
   where does it come from?
c. Why did the third node behave differently from the other two? What was on it
   that they lacked?
d. Give two independent fixes — one that changes the manifest, one that changes
   the team's tagging practice. Which is stronger and why?
e. If the tag had been `internal-api:latest`, would this have happened? Explain
   via the defaulting rule, and say whether that makes `:latest` safer or more
   dangerous overall.

### Drill 2 — The node that runs nothing

You join a fresh worker to the kubeadm cluster. It reports `Ready`. You schedule
a Deployment onto it and every Pod sits in `ContainerCreating`. `journalctl -u
kubelet` shows repeated cgroup driver errors.

a. Name the misconfiguration and the exact file it lives in.
b. Why does this specific mismatch break container *creation* rather than
   scheduling? Which component rejects the request, and at which step of the
   chain in Q7 above?
c. The node still said `Ready`. What does `Ready` actually assert, and why was
   it not a lie?
d. `kubectl` gives you almost nothing here. Name the two node-level commands you
   would run and what each would tell you.
e. On EKS this class of failure essentially does not occur. Why not — and what
   does that imply about which node-level skills your day job is not building?

### Drill 3 — Tracing a syscall boundary

An application container in a Pod runs as UID 0. The Pod has no
`securityContext`. A colleague argues this is fine "because it is only root
inside the container".

a. Which namespace decides whether "root inside" is also "root outside", and
   what is its default state in a standard Pod?
b. The container is on a node with seven other Pods. Name the two kernel
   features that stand between this process and the other Pods' processes, and
   say what each one does *not* protect against.
c. Compare the blast radius of a kernel exploit here against the same exploit in
   a VM. Name the architectural reason for the difference.
d. Name two runtimes that would change this answer, and describe in one line how
   each achieves a stronger boundary.
e. Give the two image-level changes and the one Pod-level field that would
   reduce this risk without changing the runtime.

### Drill 4 — Shrinking an image

A Go service ships as a 1.1 GB image built `FROM ubuntu:22.04`, with the Go
toolchain, `git`, and `curl` installed by `RUN apt-get install`. It runs as
root. Pod startup takes 40 seconds on a cold node.

a. Explain the 40 seconds using the layer and registry model. Which part of the
   pull dominates, and why is the second Pod on the same node much faster?
b. Describe the multi-stage build that fixes it. What crosses the stage
   boundary, and what does not?
c. You choose `scratch` as the final base and the binary immediately fails to
   start. Give the most likely cause and the build flag that fixes it.
d. With `scratch`, `kubectl exec -- /bin/sh` no longer works. What replaced that
   debugging workflow, and why does it work when there is no shell in the image?
e. The build previously did `RUN git clone` with a token in the URL. The token
   was rotated but the old image is still in the registry. Is the token
   recoverable from it? Justify using the layer model, and say what the fix
   would have been.
f. Rank these four changes by security value: multi-stage, `USER 65532`,
   `readOnlyRootFilesystem`, pinning the base by digest. Defend your ordering.
