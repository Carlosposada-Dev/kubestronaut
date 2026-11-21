---
domain: D1 — Application Design and Build
group: 1 — Build the Image
bullets: [1.1]
exams: [CKAD]
index: ckad-D1.md
theory: notes_04
k8s_version: v1.37
status: 'r2 — Template C, measured on ckad-v137 (21 Nov 2026): podman 4.9.3 rootless on cp1'
revision: '2026-11-21 (r2 — Template C: shape in the 29 Oct format, whiteboard with measured outputs, command card, traps, EKS, §9 Set 1 with verified graders) · 2026-11-13 (r1 — skeleton split out of ckad-D1.md)'
---

# D1 · Group 1 — Build the Image (bullet 1.1)

> Index, execution locations (§0), drill table and scoreboard: **`ckad-D1.md`**.
> Objectives and the reported-task list (R#): `ckad-curriculum.md`. Dates: `plan.md §10`.
>
> The only numeral of the CKAD worked with **`podman`** instead of `kubectl`. Nothing in
> it touches the cluster: the image lives in podman's own store on one host. Every
> output below was measured on `cp1` (snapshot `ckad-v137`) on 21 Nov 2026.

---

## Legend — what to type in the exam, what is only for learning

| Mark | Meaning | In the exam |
|---|---|---|
| 🎯 | **Exam path** — the task is not done without it | type it |
| 🔍 | **Verification** — proves the task worked | type it, once, at the end |
| ⏱ | **Waiting** — fixed machine time | start another task, come back |
| 📚 | **Study only** — teaches the mechanism, scores nothing | skip |
| 🧪 | **Scaffolding** — exists because this is a home lab | never appears in the exam |

**Rule that outranks the marks:** whatever the task statement spells out — an image
name, a tag, a path, a format, a registry — is literal. 🎯 blocks show defaults, not orders.

Card index: **1.1** define, build and modify container images.

---

## 1.1 Define, build and modify container images ⚙️

**Runs on:** the host the task names (exam: `ssh <host>` from base) · lab: **cp1**, as
`ubuntu`, podman rootless · **Theory →** notes_04 §1.10, §1.12, §1.14 · **Docs →** not on
kubernetes.io — `podman <verb> --help` on the host (`podman save --help`, `podman push --help`) ·
**`kubectl explain`** → none (the consumer side is `pod.spec.containers.image`) ·
**Target: 5:00** (R1) · **Reported: R1**

### The shape

**The idea in one sentence.** Turn a Dockerfile into a named, tagged image, prove it
runs, and move it out of the host — as a file or to a registry — in exactly the form the
task names. It does **not** cover using that image in a Pod (any bullet) nor registry
credentials for Pods (`imagePullSecrets`, D4 4.5).

**The analogy — a bakery.** The **Dockerfile is the recipe**. **Building** bakes a loaf
and puts it on the shelf with a **label** (`name:tag`); the bakery's own shelf is called
`localhost/`. **Running** serves a slice on a plate (a container); the **logs** are what
the customer says about it. **`save`** vacuum-packs the *loaf* with its label and recipe
card (layers + metadata: it can be served again exactly the same). **`export`** is a
photo of the *plate as served* — only the crumbs, no recipe card (no `CMD`, `ENV`,
`USER`, no history). **Tag + push** writes a second address label and ships the loaf to
another bakery (a registry).

| # | Step | What it does | Why (the failure it prevents) | Watch out | Exam? |
|---|---|---|---|---|---|
| 1 | **Read / edit the Dockerfile** | Changes the recipe: `FROM`, `ENV`, `USER`, `COPY`, `CMD` | "Modify the image" is always *edit the Dockerfile and rebuild* — never patching a running container | `COPY` sources are relative to the **build context**, not to the Dockerfile; `FROM` with a short name may not resolve | 🎯 |
| 2 | **Build with `name:tag`** | Bakes and labels the loaf | An untagged build is labelled `:latest` and the grader looks for the tag the task named | The **last argument is the context directory**; the image lands as `localhost/<name>:<tag>` | 🎯 |
| 3 | **List the image** | Shows the shelf | Proves the label is exactly the literal before anything is built on it | `localhost/` prefix is normal, not an error | 🔍 |
| 4 | **Run detached, with a name** | Serves a slice | `export` and `logs` need a **container**, and the task names it | A second `run` with the same name fails; a stopped container still holds the name | 🎯 |
| 5 | **Logs, to a file if asked** | Reads what the container printed | Tasks ask for the logs *written to a path* | `podman logs CTR > file` — the redirect is the deliverable | 🎯 |
| 6 | **Save the image** | Image → tar, with layers and metadata | The task names a format; default is **docker-archive**, "OCI" means `--format oci-archive` | Saving onto an **existing** file fails; the source is an **image**, not a container | 🎯 |
| 7 | **Export the container** | Container's flattened filesystem → tar | Only when the task says *container* or *filesystem* | Loses `CMD`/`ENV`/`USER`; a failed export still leaves a **0-byte file** | 🎯 |
| 8 | **Tag + push** | New name = registry address, then upload | The registry path *is* the name — push takes no destination argument | An HTTP-only registry needs `--tls-verify=false` | 🎯 |
| 9 | **Load / import back** | Tar → image again | Proves the file is what was asked | `load` reads `save`; `import` reads `export` — never crossed | 📚 / 🔍 |

**How it connects — symptom → the step that was skipped or done wrong**

| What you see | Look at step |
|---|---|
| `short-name "…" did not resolve to an alias and no unqualified-search registries are defined` | 1 — `FROM` needs a fully qualified name (`docker.io/library/…`) |
| `COPY …: no such file or directory` | 2 — wrong build context (the last argument) |
| `podman images` shows `<name>:latest`, the task asked `:v2` | 2 — `-t` without the tag |
| `the container name "…" is already in use` | 4 — an old container holds the name (`podman rm -f`, or `--replace`) |
| `docker-archive doesn't support modifying existing images` | 6 — the target file already exists |
| `no command or entrypoint provided, and no CMD or ENTRYPOINT from image` when running an imported image | 7 — `export`/`import` was used where `save`/`load` was meant |
| `http: server gave HTTP response to HTTPS client` | 8 — HTTP registry without `--tls-verify=false` |
| Pod in `ImagePullBackOff` for `localhost/<name>:<tag>` | not this bullet — podman's store is not the cluster's (see the whiteboard, step 9) |

**What is what**

| 🎯 Type in the exam | 🔍 Check | 📚 Understanding only |
|---|---|---|
| `podman build -t`, `run -d --name`, `logs > file`, `save -o [--format oci-archive]`, `export -o`, `tag`, `push [--tls-verify=false]` | `podman images`, `podman ps -a`, `tar tf FILE \| head`, `podman inspect -f`, `curl …/v2/_catalog` | rootless store path, `history`, `import --change`, archive internals, why Pods can't see podman images |

**Mnemonic for the order — R B V R L S E P:** *"**R**eal **B**akers **V**erify
**R**ecipes; **L**azy **S**ervers **E**at **P**izza."* Read → Build → Verify → Run →
Logs → Save → Export → Push.
**Why this order:** each step consumes the previous one's product — `run` needs the
image, `logs` and `export` need the container, `save` and `push` need the exact tag.
Verifying at step 3 catches a wrong tag before three more files are built on it.

### The whiteboard — measured on `ckad-v137`, cp1, podman 4.9.3, 21 Nov

#### Step 0 · where the image lives (📚, but it explains two traps)

```bash
# ▶▶ cp1 — ubuntu@cp1
podman info --format '{{.Host.Security.Rootless}} {{.Store.GraphRoot}}'
# true /home/ubuntu/.local/share/containers/storage
sudo podman images
# REPOSITORY  TAG  IMAGE ID  CREATED  SIZE        ← empty: root has a SEPARATE store
```

- Rootless podman keeps images under **your** home. `sudo podman` looks at root's
  store and sees **nothing** you built. Run every step as the same user; never switch
  to `sudo` half-way. In the exam, use whichever user the task hands you, consistently.
- The cluster's runtime (containerd) has its own store too. A Pod asking for an image
  that exists only in podman fails — measured: `Failed to pull image
  "localhost/myapp:1.0": … dial tcp [::1]:443: connect: connection refused` →
  `ImagePullBackOff`. To use a home-built image in a Pod, it must go through a registry
  (step 8).

#### Step 1 · the Dockerfile — what each instruction becomes

| Instruction | When it acts | Becomes, in Kubernetes terms |
|---|---|---|
| `FROM` | build | the base layers |
| `RUN` | build | a new layer (its files stay, even if a later `RUN rm` hides them) |
| `COPY src dst` | build | a layer; `src` is relative to the **context** |
| `WORKDIR` | build + run | default directory (`workingDir`) |
| `ENV K=V` | build + run | default environment (Pod `env` overrides it) |
| `USER 2000` | run | default UID (`securityContext.runAsUser` overrides it) |
| `ENTRYPOINT` / `CMD` | run | `command` / `args` in the Pod spec |

Lab Dockerfile used for every measurement:

```dockerfile
FROM docker.io/library/busybox:1.36
ENV GREETING=hello
COPY index.html /www/index.html
USER 1000
CMD ["sh","-c","echo $GREETING from $(id -u); sleep 3600"]
```

**Short names.** `FROM busybox:1.36` built, because Ubuntu's
`/etc/containers/registries.conf.d/shortnames.conf` aliases common names. A name not in
that list failed:

```
Error: creating build container: short-name "nginxinc/nginx-unprivileged:1.29-alpine" did not
resolve to an alias and no unqualified-search registries are defined in "/etc/containers/registries.conf"
```

Fix = write the registry: `docker.io/nginxinc/nginx-unprivileged:1.29-alpine`. Leave the
task's `FROM` alone unless it fails.

**Modifying** = edit the line, rebuild with the **new** tag the task names. Measured:
`GREETING=hello` → `bonjour`, rebuilt as `myapp:2.0`, `podman run --rm myapp:2.0 sh -c
'echo $GREETING; id -u'` → `bonjour` / `1000`. The old tag keeps the old image.

#### Step 2 · build 🎯

```bash
# ▶▶ cp1 🎯
podman build -t myapp:1.0 app                 # app/ = the directory holding the Dockerfile and index.html
# STEP 1/5: FROM docker.io/library/busybox:1.36 … STEP 5/5: CMD …
# Successfully tagged localhost/myapp:1.0
```

| Piece | Meaning |
|---|---|
| `-t myapp:1.0` | name **and** tag. `-t myapp` alone → `localhost/myapp:latest` (measured) |
| `-f PATH` | the Dockerfile, when it is not `CONTEXT/Dockerfile` (or `Containerfile`) |
| `app` (last) | the **build context**: the only directory `COPY` can read from |

Wrong context, measured — Dockerfile given with `-f`, context `.` one level too high:

```bash
podman build -t ctxbad -f app/Dockerfile .
# Error: building at STEP "COPY index.html /www/index.html": … stat: "/index.html": no such file or directory
```

#### Step 3 · verify 🔍

```bash
# ▶▶ cp1 🔍
podman images
# REPOSITORY                 TAG   IMAGE ID      CREATED                 SIZE
# localhost/myapp            1.0   147122a75480  Less than a second ago  4.65 MB
# docker.io/library/busybox  1.36  b116e1550744  3 years ago             4.66 MB
```

`localhost/` is podman's name for "built here". You can still type `myapp:1.0` everywhere.

#### Step 4 · run 🎯

```bash
# ▶▶ cp1 🎯
podman run -d --name web myapp:1.0
podman ps -a --format '{{.Names}} {{.Status}} {{.Image}}'
# web Up 2 seconds localhost/myapp:1.0
```

Same name twice, measured:
`Error: … the container name "web" is already in use by 92865d97c0bc… You have to remove
that container to be able to reuse that name … or use --replace`.

#### Step 5 · logs 🎯

```bash
# ▶▶ cp1 🎯
podman logs web                     # hello from 1000     ← ENV and USER from the Dockerfile, live
podman logs web > /PATH/web.log     # when the task says "write the logs to …"
```

#### Step 6 · save the image 🎯 — `save` ↔ `load`

```bash
# ▶▶ cp1 🎯
podman save -o /PATH/img.tar myapp:1.0                          # default format: docker-archive
podman save --format oci-archive -o /PATH/img-oci.tar myapp:1.0 # when the task says OCI
```

| Format | `tar tf` shows (measured) | Ask for it when the task says |
|---|---|---|
| `docker-archive` (default) | `<sha>.tar` layers, `<sha>.json` config, `manifest.json`, `<dir>/layer.tar` | "save the image", "a tar", "docker format" |
| `oci-archive` | `index.json`, `oci-layout`, `blobs/sha256/…` | "OCI", "OCI format", "oci-archive" |

Measured edge cases:

| Action | Result |
|---|---|
| `save -o` onto an **existing** file | `Error: docker-archive doesn't support modifying existing images` → delete the file or use the exact new path |
| `podman save myapp:1.0 > img2.tar` | works (same 4 662 784 bytes) — the redirect form is fine |
| a tag that does not exist | `Error: myapp:9.9: image not known` |
| `podman load -i img.tar` / `-i img-oci.tar` | `Loaded image: localhost/myapp:1.0` — name and tag come back from both formats |

#### Step 7 · export the container 🎯 — `export` ↔ `import`

```bash
# ▶▶ cp1 🎯
podman export -o /PATH/ctr.tar web            # a CONTAINER name, not an image
tar tf /PATH/ctr.tar | grep -E '^www/|^etc/passwd$'
# etc/passwd  www/  www/index.html            ← just the filesystem
```

What `export` throws away, measured by importing it back:

```bash
# ▶▶ cp1 📚
podman import ctr.tar myapp-flat:1.0
podman inspect --format 'CMD={{.Config.Cmd}} ENV={{.Config.Env}} USER={{.Config.User}}' myapp:1.0 myapp-flat:1.0
# CMD=[sh -c echo $GREETING …] ENV=[PATH=… GREETING=hello] USER=1000     ← saved image
# CMD=[] ENV=[] USER=                                                    ← exported + imported
podman run --rm myapp-flat:1.0
# Error: no command or entrypoint provided, and no CMD or ENTRYPOINT from image
podman import --change 'CMD ["cat","/www/index.html"]' ctr.tar myapp-flat:1.1   # 📚 how to put one back
```

History also collapses to **one** `ADD file:…` layer. **Trap measured:** `podman export -o
ctr.tar web` with no container `web` printed `Error: no container with name or ID "web"
found` **and still created `ctr.tar` with 0 bytes** — a later `ls` "proves" a file that is
empty. Check with `tar tf`, not `ls`.

#### Step 8 · tag and push 🎯

```bash
# ▶▶ cp1 🎯
podman tag myapp:1.0 localhost:5000/team/myapp:1.0          # second label = registry/repo:tag
podman push localhost:5000/team/myapp:1.0
# Error: … pinging container registry localhost:5000: Get "https://localhost:5000/v2/":
#        http: server gave HTTP response to HTTPS client
podman push --tls-verify=false localhost:5000/team/myapp:1.0
# … Writing manifest to image destination
```

- **`localhost` is not treated as insecure** — measured, same error as with `cp1:5000`.
  Plain-HTTP registry → `--tls-verify=false`, every time.
- Push takes **no destination argument** in this form: the name *is* the address. Tag
  first, push the new name.
- 🔍 `curl -s localhost:5000/v2/_catalog` → `{"repositories":["team/myapp"]}`;
  `curl -s localhost:5000/v2/team/myapp/tags/list` → `{"name":"team/myapp","tags":["1.0"]}`.
- 🧪 The lab registry: `podman run -d --name reg -p 5000:5000 docker.io/library/registry:2`.
  In the exam it is already running.

#### Step 9 · cleaning up — the two that bite (📚)

| Command | Measured effect |
|---|---|
| `podman rm web` (running) | `Error: cannot remove container … as it is running` → `rm -f` |
| `podman rmi myapp:1.0` (a container uses it) | `Error: image used by … image is in use by a container` |
| `podman rmi -f myapp:1.0` | **also deletes every container built from it** — `web` vanished, and the next `export` failed |

**Docker instead of podman.** The verbs are the same (`build -t`, `run -d --name`,
`logs`, `save -o`, `export -o`, `tag`, `push`, `load -i`, `import`). Not measured here:
the lab has no Docker. If the task host offers only `docker`, read `docker save --help`
before choosing a format flag.

### Command card — 1.1

```
BUILD    podman build -t NAME:TAG [-f DOCKERFILE] CONTEXT
CHECK    podman images | grep NAME
RUN      podman run -d --name CTR NAME:TAG
LOGS     podman logs CTR > /PATH/FILE
SAVE     podman save [--format oci-archive] -o /PATH/IMG.tar NAME:TAG     # image; file must not exist
EXPORT   podman export -o /PATH/FS.tar CTR                                 # container
PUSH     podman tag NAME:TAG REG/REPO:TAG && podman push [--tls-verify=false] REG/REPO:TAG
PROVE    tar tf FILE | head · podman inspect -f '{{.Config.User}} {{.Config.Env}}' NAME:TAG
```

### Traps

| Error | Cause |
|---|---|
| `short-name "…" did not resolve to an alias` | `FROM` without a registry, not in `shortnames.conf` → write `docker.io/…` |
| `COPY …: no such file or directory` | wrong build context (the last argument) |
| image is `:latest`, the grader wants `:v2` | `-t NAME` without `:TAG` |
| `sudo podman images` is empty | rootless store is per user — never mix `sudo` and non-`sudo` |
| `the container name "…" is already in use` | an old (even stopped) container holds the name |
| `docker-archive doesn't support modifying existing images` | `save -o` onto a file that already exists |
| OCI asked, file has `manifest.json` and no `oci-layout` | default `save` format (docker-archive) |
| imported image: `no command or entrypoint provided` | `export`/`import` used where `save`/`load` was meant |
| export file exists but is 0 bytes | the export failed (wrong container name) — `ls` lies, `tar tf` doesn't |
| `server gave HTTP response to HTTPS client` | HTTP registry → `--tls-verify=false` (also for `localhost`) |
| container gone after `rmi -f` | `rmi -f` removes the containers that use the image |
| Pod `ImagePullBackOff` on `localhost/NAME:TAG` | podman's store is not containerd's — push to a registry |

⚠️ **EKS:** day to day the image is built by CI and pushed to **ECR**; nodes pull with the
**node IAM role** (no `imagePullSecrets`), and nodes run containerd — there is no podman
and no `save`/`load` step anywhere. The exam's "build on a host, save to a file" path has
no EKS equivalent; the tag-and-push half is what your pipeline already does.

---

## §9. Exam mode — Set 1 · 3 tasks · 12 min

Wording as the CKAD phrases it. **Runs on cp1** (in the exam the task names the host:
`ssh` there first). Setup is untimed and encoded so you cannot read it; it starts with its
own reset line and needs internet (it pulls `registry:2` and `busybox:1.36`). Graders run
**after** the clock stops. A FAIL is pasted, not fixed first.

**Graders verified 21 Nov** on `ckad-v137` against three states: setup only (every check
FAIL), a correct solution (all PASS) and a typical wrong one — default `save` format, no
log file, `save` instead of `export`, `push` without `--tls-verify=false` (each caught).

🧪 Setup — run once for all three tasks:

```bash
# ▶▶ cp1 🧪
echo 'cG9kbWFuIHJtIC1mIHdlYmFwcC10ZXN0IHdlYmFwcC12MyByZWcxMSA+L2Rldi9udWxsIDI+JjE7IHBvZG1hbiBybWkgLWYgbG9jYWxob3N0L3dlYmFwcDp2MiBsb2NhbGhvc3Qvd2ViYXBwOnYzIGxvY2FsaG9zdDo1MDAwL3RlYW0vd2ViYXBwOnYyID4vZGV2L251bGwgMj4mMTsgcm0gLXJmIH4vY2thZC1kMTEKbWtkaXIgLXAgfi9ja2FkLWQxMS9zcmMKY2F0ID4gfi9ja2FkLWQxMS9zcmMvRG9ja2VyZmlsZSA8PCdERicKRlJPTSBkb2NrZXIuaW8vbGlicmFyeS9idXN5Ym94OjEuMzYKRU5WIE1PREU9ZGV2CldPUktESVIgL2FwcApDT1BZIG1vdGQudHh0IC9hcHAvbW90ZC50eHQKQ01EIFsic2giLCAiLWMiLCAiZWNobyBzdGFydGVkIGluICRNT0RFOyBjYXQgL2FwcC9tb3RkLnR4dDsgc2xlZXAgMzYwMCJdCkRGCmVjaG8gIkNLQUQtRDExLU1PVEQiID4gfi9ja2FkLWQxMS9zcmMvbW90ZC50eHQKcG9kbWFuIHJ1biAtZCAtLW5hbWUgcmVnMTEgLXAgNTAwMDo1MDAwIGRvY2tlci5pby9saWJyYXJ5L3JlZ2lzdHJ5OjIgPi9kZXYvbnVsbCAyPiYxCmVjaG8gInNldHVwIGRvbmUiCg==' | base64 -d | bash
```

```
Task 1  (weight 6%)                                           target 5 min
Host: cp1

Using podman, build an image from the Dockerfile in /home/ubuntu/ckad-d11/src.
The image must be named webapp with the tag v2.

Run a detached container named webapp-test from that image and write the
container's logs to /home/ubuntu/ckad-d11/webapp-test.log.

Save the image webapp:v2 in OCI archive format to
/home/ubuntu/ckad-d11/webapp-v2.tar.
```

```
Task 2  (weight 5%)                                           target 5 min
Host: cp1

Modify the Dockerfile in /home/ubuntu/ckad-d11/src so that the image sets the
environment variable MODE to production and runs as user ID 2000.
Build it as webapp:v3. The image webapp:v2 must remain unchanged.

Start a container named webapp-v3 from the new image and export the
container's filesystem to /home/ubuntu/ckad-d11/webapp-v3-fs.tar.
```

```
Task 3  (weight 3%)                                           target 2 min
Host: cp1

A container registry is running at localhost:5000. It serves plain HTTP.
Push the image webapp:v2 to this registry as localhost:5000/team/webapp:v2.
```

🔍 Graders — one per task, after the clock:

```bash
# ▶▶ cp1 🔍 Task 1
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CkQ9fi9ja2FkLWQxMQpvayAiJChwb2RtYW4gaW1hZ2UgZXhpc3RzIGxvY2FsaG9zdC93ZWJhcHA6djIgJiYgZWNobyB5ZXMpIiB5ZXMgImltYWdlIHdlYmFwcDp2MiBleGlzdHMiCm9rICIkKHBvZG1hbiBpbnNwZWN0IC1mICd7ey5TdGF0ZS5SdW5uaW5nfX0nIHdlYmFwcC10ZXN0IDI+L2Rldi9udWxsKSIgdHJ1ZSAiY29udGFpbmVyIHdlYmFwcC10ZXN0IGlzIHJ1bm5pbmciCm9rICIkKHBvZG1hbiBpbnNwZWN0IC1mICd7ey5JbWFnZU5hbWV9fScgd2ViYXBwLXRlc3QgMj4vZGV2L251bGwpIiBsb2NhbGhvc3Qvd2ViYXBwOnYyICJ3ZWJhcHAtdGVzdCBydW5zIHdlYmFwcDp2MiIKb2sgIiQoZ3JlcCAtYyBDS0FELUQxMS1NT1REICREL3dlYmFwcC10ZXN0LmxvZyAyPi9kZXYvbnVsbCkiIDEgImxvZ3Mgd3JpdHRlbiB0byB3ZWJhcHAtdGVzdC5sb2ciCm9rICIkKHRhciB0ZiAkRC93ZWJhcHAtdjIudGFyIDI+L2Rldi9udWxsIHwgZ3JlcCAtY3hFICdvY2ktbGF5b3V0fGluZGV4Lmpzb24nKSIgMiAid2ViYXBwLXYyLnRhciBpcyBhbiBPQ0kgYXJjaGl2ZSIK' | base64 -d | bash
# ▶▶ cp1 🔍 Task 2
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9CkQ9fi9ja2FkLWQxMQplbnZfb2YoKXsgcG9kbWFuIGluc3BlY3QgLWYgJ3t7cmFuZ2UgLkNvbmZpZy5FbnZ9fXt7cHJpbnRsbiAufX17e2VuZH19JyAiJDEiIDI+L2Rldi9udWxsOyB9Cm9rICIkKHBvZG1hbiBpbnNwZWN0IC1mICd7ey5Db25maWcuVXNlcn19JyBsb2NhbGhvc3Qvd2ViYXBwOnYzIDI+L2Rldi9udWxsIHwgY3V0IC1kOiAtZjEpIiAyMDAwICJ3ZWJhcHA6djMgcnVucyBhcyB1c2VyIDIwMDAiCm9rICIkKGVudl9vZiBsb2NhbGhvc3Qvd2ViYXBwOnYzIHwgZ3JlcCAtYyAnXk1PREU9cHJvZHVjdGlvbiQnKSIgMSAid2ViYXBwOnYzIHNldHMgTU9ERT1wcm9kdWN0aW9uIgpvayAiJChlbnZfb2YgbG9jYWxob3N0L3dlYmFwcDp2MiB8IGdyZXAgLWMgJ15NT0RFPWRldiQnKSIgMSAid2ViYXBwOnYyIHVuY2hhbmdlZCAoTU9ERT1kZXYpIgpvayAiJChwb2RtYW4gaW5zcGVjdCAtZiAne3suSW1hZ2VOYW1lfX0nIHdlYmFwcC12MyAyPi9kZXYvbnVsbCkiIGxvY2FsaG9zdC93ZWJhcHA6djMgImNvbnRhaW5lciB3ZWJhcHAtdjMgcnVucyB3ZWJhcHA6djMiCm9rICIkKHRhciB0ZiAkRC93ZWJhcHAtdjMtZnMudGFyIDI+L2Rldi9udWxsIHwgZ3JlcCAtYyAnXmFwcC9tb3RkLnR4dCQnKSIgMSAiZXhwb3J0IGhvbGRzIHRoZSBjb250YWluZXIgZmlsZXN5c3RlbSIKb2sgIiQoaWYgWyAtcyAkRC93ZWJhcHAtdjMtZnMudGFyIF07IHRoZW4gdGFyIHRmICREL3dlYmFwcC12My1mcy50YXIgfCBncmVwIC1jRSAnbWFuaWZlc3QuanNvbnxvY2ktbGF5b3V0fGluZGV4Lmpzb24nOyBlbHNlIGVjaG8gbWlzc2luZzsgZmkpIiAwICJleHBvcnQsIG5vdCBhbiBpbWFnZSBzYXZlIgo=' | base64 -d | bash
# ▶▶ cp1 🔍 Task 3
echo 'b2soKXsgWyAiJDEiID0gIiQyIiBdICYmIGVjaG8gIlBBU1MgICQzIiB8fCBlY2hvICJGQUlMICAkMyAoZ290ICckMScsIHdhbnQgJyQyJykiOyB9Cm9rICIkKGN1cmwgLXMgLW0gMyBsb2NhbGhvc3Q6NTAwMC92Mi90ZWFtL3dlYmFwcC90YWdzL2xpc3QpIiAneyJuYW1lIjoidGVhbS93ZWJhcHAiLCJ0YWdzIjpbInYyIl19JyAidGVhbS93ZWJhcHA6djIgaXMgaW4gdGhlIHJlZ2lzdHJ5IgpvayAiJChjdXJsIC1zIC1tIDMgLW8gL2Rldi9udWxsIC13ICcle2h0dHBfY29kZX0nIC1IICdBY2NlcHQ6IGFwcGxpY2F0aW9uL3ZuZC5vY2kuaW1hZ2UubWFuaWZlc3QudjEranNvbixhcHBsaWNhdGlvbi92bmQuZG9ja2VyLmRpc3RyaWJ1dGlvbi5tYW5pZmVzdC52Mitqc29uJyBsb2NhbGhvc3Q6NTAwMC92Mi90ZWFtL3dlYmFwcC9tYW5pZmVzdHMvdjIpIiAyMDAgIm1hbmlmZXN0IHRlYW0vd2ViYXBwOnYyIHJldHJpZXZhYmxlIgo=' | base64 -d | bash
```

**Variations to expect** (same mechanism, new wording): save in the *default* format ·
`load` an image from a given tar and run it · "export the image" (read twice: image →
`save`, container → `export`) · the Dockerfile in a directory whose name differs from the
context · a `CMD` → `ENTRYPOINT` change · `docker` instead of `podman`.

### Run log

| Date | Task | With | Time | Grader | Errors / notes |
|---|---|---|---|---|---|
| | | | | | |
