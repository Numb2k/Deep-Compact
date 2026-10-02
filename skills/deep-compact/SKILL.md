---
name: deep-compact
description: Use whenever the user wants to compact, summarize-before-compacting, or "save context before /compact" on a long Claude Code session — including direct mentions of "/compact", "compact this session", "prep for compact", or "I don't want to lose context". Writes an exhaustive, structured session-state handoff to disk (outside the project), checks it, then hands the user a ready-made /compact command that points at it. Minimizes context loss beyond what compaction's internal summary retains, and lets a brand-new session restore full context by reading the handoff file. Manual use only — it cannot protect against automatic compaction.
---

# Deep Compact

Goal: compact the session with minimal loss of anything a competent engineer resuming
this work would need — by writing durable state to disk *before* compacting, not
relying on compaction's internal summarizer alone.

## Read first: how it is used, and its limits

- **Manual only.** Run `/deep-compact` yourself when the context is getting full, *then*
  run `/compact`. This skill cannot intercept Claude Code's automatic compaction. If the
  user asks about protecting against auto-compaction: a `PreCompact` hook can run a script
  before it, but a hook runs shell scripts only — it cannot run this skill's smart summary.
  Do not set up hooks unless asked; never edit settings without explicit approval.
- **Claude cannot run `/compact` itself.** Step 3 prints the exact command for the user to run.
- **Requirements:** `bash` (macOS/Linux; on Windows use WSL or Git Bash) and the helper
  `scripts/dc.sh` next to this file. `git` is optional — without it the Git State section
  just says so.
- **Writes only under `~/.claude/session-state/`.** Never inside the project, never stages,
  commits or modifies anything in the repo.
- **A new session does not know about the handoff by itself.** The user must point Claude at
  `latest.md` (Step 4 prints the exact sentence). Archived history is searched only when
  `latest.md` has been loaded in that session.
- **Two sessions on the same project:** protected by a lock; the second run waits/aborts.

## Setup — locate the helper

When this skill loads, Claude Code states its "Base directory for this skill". The helper lives
at `scripts/dc.sh` inside that directory, so use it (works for personal-skill installs and for
plugin installs alike):

```
DC="<base directory>/scripts/dc.sh"
bash "$DC" id      # prints the project id
```

Only if no base directory was stated, try `$HOME/.claude/skills/deep-compact/scripts/dc.sh`.
If the helper is missing, stop and tell the user the install is incomplete. Do not improvise.

The project id is `<repo-or-folder-name>-<8-char sha256 of the repo root path>` (git root if
inside a repo, otherwise the current directory), so projects that share a folder name never
collide. State lives at `~/.claude/session-state/<project-id>/`.

## Step 1 — Audit the full session before touching /compact

Re-read the entire conversation (not just the last few turns) and extract, verbatim
where possible — do not paraphrase away specifics like exact paths, flag names,
version numbers, or error text:

1. **Mission** — the original goal(s), and how the goal evolved if it did (state both
   the original framing and the current one).
2. **Key decisions** — every non-trivial decision, the reasoning behind it, and any
   alternative that was considered and rejected (and why).
3. **Files & code state** — every file created, read, or modified: full path (in backticks),
   and a precise description of the change (not "updated auth" — say what changed, in
   which function, and why).
4. **Commands & environment** — installs, migrations, config/env changes, and their
   outcomes.
5. **Errors & resolutions** — every error hit, its root cause once diagnosed, and the
   fix. These are expensive to rediscover — never compress this section.
6. **Open threads** — anything started but unfinished, anything deferred, any
   unanswered question.
7. **User constraints & preferences** — explicit instructions the user gave about
   scope, style, or things to avoid.
8. **Immediate next step** — the single next action, precise enough to act on
   without re-reading anything.
9. **Git state** — run `bash "$DC" git` and paste its output verbatim. It is read-only and
   handles every case (no git, no commits, no upstream, detached HEAD).

Do not omit an item for seeming minor. Omission is the exact failure mode this skill
exists to prevent.

## Step 2 — Write the handoff OUTSIDE the project

State is **always under the user's home directory, never under the project's own
directory** — nothing may be placed inside the git working tree, staged, added to
`.gitignore`, or otherwise touch the project's tracked files. No exceptions.

Two kinds of files live in `~/.claude/session-state/<project-id>/`:

1. **`latest.md`** — the single cumulative, always-current handoff: a merged rollup of
   everything still relevant from every prior compact in this project. This is the only
   file used to resume work.
2. **`<YYYY-MM-DD-HHmm>-handoff.md`** — a timestamped snapshot written at every run, as an
   audit trail. The 10 newest stay in the folder; older ones are moved (never deleted) to
   `archive/`. Other files in the folder (for example `*-stop.md` notes) are never touched.

Procedure — always release the lock at the end, even if something fails:

1. `bash "$DC" lock` — if it fails, tell the user another run is in progress and stop.
2. Read the existing `latest.md`, if any. If it is **over 500 lines**, do Step 2.5 first —
   consolidation is a separate pass, never mixed into the same edit as adding new information.
3. Merge: build the new content from the (possibly consolidated) `latest.md` plus Step 1.
   - Carry forward everything still relevant. Default to KEEPING information — drop an item
     only if it is explicitly resolved or superseded and has no future value. Architectural
     decisions, rationale, and unresolved threads are never dropped to save space.
   - The result has **exactly one set** of the 9 sections. Do not stack earlier handoffs
     below it as "Previous handoff" blocks — earlier versions already live in the snapshots.
   - Use the 9 headers verbatim as `##` sections: `## Mission`, `## Key Decisions`,
     `## Files & Code State`, `## Commands & Environment`, `## Errors & Resolutions`,
     `## Open Threads`, `## User Constraints & Preferences`, `## Immediate Next Step`,
     `## Git State`.
   - Start the file with:
     ```
     # Session Handoff — <project-id>
     Written: <timestamp>
     Archive: ~/.claude/session-state/<project-id>/archive/ — older snapshots; grep here when asked about older work not covered below
     ```
4. Write the merged content to a scratch file (the session scratchpad if one is listed, else
   `mktemp`), then `bash "$DC" install <scratch-file>` — it writes `latest.md` atomically and
   creates the timestamped snapshot.
5. `bash "$DC" archive` (moves snapshots beyond the newest 10 into `archive/`), then
   `bash "$DC" verify` (checks all 9 sections, that listed paths exist, and that the recorded
   commit matches HEAD). Fix any FAIL and re-install; report WARNs honestly.
6. `bash "$DC" unlock`.

### Step 2.5 — Consolidation (mandatory when latest.md is over 500 lines)

Purpose: keep `latest.md` short enough that loading it stays cheap and focused. Because
snapshots keep full history, consolidating loses nothing permanently.

1. `bash "$DC" backup-latest` (copies the current file into `archive/` first).
2. Spawn a subagent (Agent tool, `model: "sonnet"`, general-purpose) that sees ONLY the file
   path, not the conversation. If that is unavailable, do it yourself. Give it these rules
   verbatim and have it write a candidate to a scratch file, never editing the original:
   - Output has exactly one set of the 9 sections.
   - **Key Decisions: every line is kept verbatim** (it may be moved and merged under the
     single heading). Never shorten, rephrase or drop a Key Decisions line.
   - Anything still open, and anything architecturally significant, stays in full detail.
   - Fully resolved entries in Errors & Resolutions, Files & Code State and Open Threads
     collapse into one-line historical notes, e.g. "Auth bug in `login.ts` — fixed
     2026-03-01, full detail in snapshot <file>".
   - Legacy "## Previous handoff (...)" blocks are folded into the single set under these
     same rules; point to the matching snapshot file name where one exists in the folder.
   - Keep the metadata block and the `Archive:` line.
3. `bash "$DC" consolidate-check <original> <candidate>` — it fails if any section is
   missing, any Key Decisions line was lost, or the candidate is not shorter. On OK, use the
   candidate as the base for the merge. On FAIL, discard the candidate, keep the original,
   tell the user, and continue with a normal merge.

## Step 3 — Hand the user the /compact command

Claude cannot run `/compact`. Put this block in the final reply text (together with the Step 4
report) for the user to run, with the real project id:

```
/compact Preserve exactly the content of ~/.claude/session-state/<project-id>/latest.md —
treat it as ground truth. Under no circumstances summarize it further; carry its
9 sections forward into the compacted context in full. On the next user message, first
re-read that file to restore full detail. Everything else in the transcript not captured in
that file can be compressed normally.
```

## Step 4 — Report (mandatory, written in the reply text)

Tool output is collapsed in the user's view, so running a command is NOT the same as
showing it. Your final reply must contain, as plain text copied from the command output
(not just run in a tool call), in this order:

1. **Status** — the output of `bash "$DC" status`: how many handoff files exist for this
   project, where they live, total size, `latest.md` length, any warning.
2. **Verify result** — the `bash "$DC" verify` line, plus every WARN in plain words.
   Mention anything you fixed after a first failed or warned verify.
3. **The `/compact` command** from Step 3.
4. **The resume sentence** for a new session:

```
Read ~/.claude/session-state/<project-id>/latest.md and resume from "Immediate Next Step".
```

Run `status` again after the final install/archive/unlock so the numbers shown are current.
Do not end the turn before all four items are in the reply. After the user runs `/compact`,
no further status is produced automatically — to see it again, run `/deep-compact` again.

## Models

The skill is model-agnostic: Steps 1–2 need the live conversation, so they run on whatever
model the session uses. Only Step 2.5 (works from a file alone) is delegated to a cheaper
subagent, guarded by the deterministic `consolidate-check`.

## Resuming and searching history

To restore context in a brand-new session, point Claude at `latest.md` (sentence above).
If the user asks about something older that `latest.md` does not cover, `grep` the folder
and its `archive/` subfolder for it and read only the matching parts. Never use snapshots
as the starting point to resume — always `latest.md`.
