# kubestronaut

Study notes, runbooks and a kubeadm lab for **CKA, CKAD and CKS** (2026), worked with
Claude Code as a coach. KCNA passed Sep 2026.

| Folder | What's inside |
|---|---|
| `notes/` | Theory, one note per Kubernetes domain, shared by all exams |
| `cka/` | CKA runbooks per curriculum domain: shape → whiteboard → command card → traps → exam mode |
| `kcna/` | KCNA curriculum and derived objectives |
| `lab/` | Building the 3-node kubeadm lab on multipass |
| `claude/` | How study sessions run, note templates, error log |
| `tools/` | Cross-reference checkers for the notes |
| `plan.md` | Schedule, decisions, progress log |

## Set up on a new machine

Works on any Linux, including WSL on Windows.

```bash
# git, gh, python3 (Ubuntu / WSL)
sudo apt update && sudo apt install -y git gh python3

gh auth login --hostname github.com --git-protocol https --web
git config --global user.name  "<name>"
git config --global user.email "<id>+<login>@users.noreply.github.com"

mkdir -p ~/projects && cd ~/projects
gh repo clone Carlosposada-Dev/kubestronaut
cd kubestronaut && claude
```

- **WSL:** clone inside the Linux filesystem (`~/projects`), not under `/mnt/c/` —
  it is much faster, and file modes and line endings stay correct.
- **One machine at a time.** Pull before studying, push when done — `/study` and
  `/exam` pull for you, and `cierre` pushes.
- **The lab lives on one machine** (multipass VMs). From a machine without it, the
  learning stages (walkthrough, shape, whiteboard) still work; timed runs and exam
  mode need the lab.

## Study commands (Claude Code)

```
/study cka-D1-3 1.1     # one bullet, five stages: walkthrough → shape → whiteboard → solo → exam
/exam  cka-D1 3         # three exam-mode tasks: encoded setup, timed, grader after the clock
cierre                  # close: log hours, mistakes and times, commit, push
```
