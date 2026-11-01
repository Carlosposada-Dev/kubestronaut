# Lab build scripts

Rebuild and verify the multipass lab described in `plan.md §8`. Run from the lab host (any Linux or WSL
machine running multipass), as the normal user. Every script resolves versions at run time and can be re-run.

| Script | What it does |
|---|---|
| `build-lab.sh` | Delete and relaunch `cp1 w1 w2`, build `lab-v<n-1>` on the newest 1.36 patch, `kubeadm upgrade` to the newest 1.37 patch, snapshot `lab-v<n>`. `MODE=inplace` keeps the VMs instead |
| `build-w3.sh` | Restore `w3.cleanw3`, prep the node to the same patch as `lab-v<n>`, snapshot `prep<n>`. Never joined |
| `verify-lab.sh` | Tool matrix per node × snapshot, acceptance on `lab-v<n>`, IP / ssh / `/etc/hosts` checks. Leaves `lab-v<n>` + `prep<n>` running |
| `ssh-fix.sh` | Re-point ssh `cp1 → w1/w2` and the lab block in `/etc/hosts` at the current IPs |
| `upgrade.sh` | The official kubeadm upgrade, node by node. Skips nodes already on the target |
| `prep-node.sh` | Node prep inside a VM: swap, modules, sysctl, containerd, pinned + held packages, exam tools |
| `acceptance.sh` | Health gates + tutorial Phase 5 checks, inside cp1. Exits 1 on failure |
| `audit.sh` | One `tool version` line per check, inside a node |
| `wipe-node.sh` | Return a node to plain Ubuntu without recreating the VM (`MODE=inplace`) |
| `resolve-versions.sh` | Print the versions a build would use today |
| `common.sh` | Shared helpers, sourced by the others |

```bash
./build-lab.sh                       # dry run: prints the resolved versions only
CONFIRM=yes ./build-lab.sh && CONFIRM=yes ./build-w3.sh && ./verify-lab.sh
```

Pin a version with `BASE=1.36.6 NEXT=1.37.2 CALICO=v3.33.0 YQ=v4.54.1`. When the exam moves to the
next minor, change the two minors in `build-lab.sh` and `build-w3.sh`.

Traps already handled: snapshot delete needs the VM stopped · new VMs get new IPs (leases are bound to
the MAC) · cloud-init rewrites `/etc/hosts` from `/etc/cloud/templates/hosts.debian.tmpl` on boot ·
a stopped VM shows no IP (`lab-ips.env` records them) · the apiserver is briefly down after a kubelet
restart · Calico CRDs appear only after the operator starts.
