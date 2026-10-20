# MIGRATION — claude.ai Project → Claude Code (2026-10-19)

This folder replaces both the claude.ai Project knowledge and `~/Downloads/k8/kubestronaut/`.
From here on it is the **only** place files are edited. Commit after every session.

## Where each file came from

Compared byte-for-byte (sha256): 31 local files vs 32 project docs.

| Result | Files | Version kept |
|---|---|---|
| Identical in both | 28 (all `cka/*`, all `notes/*`, `kcna-curriculum`, `lab-…tutorial`, `session-protocol`, `depth-standard`, `note-prompt-template`, `sources`) | either |
| `plan.md` | local = v4.3 (26 Sep) · project = **v5.0 (16 Oct)** | **project** |
| `claude/mistakes.md` | local `claude/mistakes.md` = rows 1–26, 57–81 (17 Sep) · project = **rows 1–26, 57–92** (same as local `cka/claude_mistakes.md`) | **project** |
| `claude/note-templates.md` | local = Templates A, B (17 Sep) · project = **A, B, C** (18 Sep) | **project** |
| `tools/checkrefs.py`, `tools/semcheck.py` | project only | project |

Moved: `plan.md` → repo root. `cka/claude_mistakes.md` + `claude/mistakes.md` (duplicates) → one file, `claude/mistakes.md`.

## Open gaps — exist in no file anywhere

1. **`mistakes.md` rows 27–56** (notes 03–08): missing from both copies. Treat as lost unless an old download turns up.
2. **`mistakes.md` rows 93–117**: written in chat "CKA D1-3: Access" (27–28 Sep) and never saved to any file.
   https://claude.ai/chat/41e60ed5-858c-40fb-b1a4-28743bc4a12d — rows 93–100 are visible in that chat as a table.
3. Same chat promised, at block close: `plan.md` log entries, `cka-D1.md` §7/§8 updates and `notes_07` amendments (§9.3).
   None reached the project or the local repo. `plan.md` v5.0 (16 Oct) supersedes the plan part; the other two are unverified.
4. `plan.md` progress log: no entries after 16 Oct.

## Rule from now on

- Edit in this repo only. The claude.ai Project is frozen as a read-only archive.
- `git log -- <file>` is the answer to "is this the latest version?".
