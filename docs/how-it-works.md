# How it works

## Files

State for each project lives in `~/.claude/session-state/<project-id>/` (override the root with `DEEP_COMPACT_HOME`):

```text
<project-id>/
├─ latest.md                      the single cumulative handoff (used to resume)
├─ 2026-01-15-0930-handoff.md     timestamped snapshot, one per run (newest 10 kept)
└─ archive/                       older snapshots, moved here, never deleted
```

`<project-id>` is `<folder name>-<first 8 hex chars of sha256(path)>`, using the git root if you are inside a repository and the current directory otherwise.

## A run, step by step

1. **Lock.** `dc.sh lock` creates a lock folder; a second run is refused. Locks older than 10 minutes are treated as stale and replaced.
2. **Consolidate (only if needed).** If `latest.md` is over 500 lines, the model first backs it up into `archive/`, then a cheaper subagent that sees *only the file* (not your conversation) writes a shorter candidate under strict rules. `dc.sh consolidate-check` accepts the candidate only if every section exists, **no Key Decisions line was lost**, and it is actually shorter.
3. **Audit and merge.** The session model re-reads the whole conversation, extracts the nine sections, and merges them into the (possibly consolidated) `latest.md`. The result has exactly one set of sections.
4. **Install.** The merged file is written atomically to `latest.md` and copied to a new timestamped snapshot.
5. **Archive.** Snapshots beyond the newest 10 move to `archive/`. Other files in the folder (for example your own notes) are never touched.
6. **Verify.** `dc.sh verify` fails if a section is missing and warns about missing listed paths, a stale recorded commit, or a file that needs consolidation.
7. **Unlock** and **report**: status, verify result, the `/compact` command and the resume sentence, as plain text.

## The helper script

`skills/deep-compact/scripts/dc.sh` holds the deterministic parts so they are testable:

| Command | What it does |
|---|---|
| `id` / `dir` | Prints the project id / creates and prints the state folder |
| `lock` / `unlock` | Per-project lock |
| `git` | Read-only git state (handles: no repo, no commits, no upstream, detached HEAD) |
| `install FILE` | Atomic write of `latest.md` plus a snapshot (requires the lock) |
| `archive` | Moves old snapshots to `archive/` |
| `verify [FILE]` | Structural and consistency checks |
| `backup-latest` | Copies `latest.md` into `archive/` before consolidation |
| `consolidate-check BEFORE AFTER` | Guard for consolidation |
| `status` | The status block shown to you |

It writes only under the state folder. It never writes inside your project and never runs a git command that changes anything (it uses `git --no-optional-locks status`).

## Which model does what

Deep Compact is model-agnostic. The audit and merge need your live conversation, so they run on whatever model your session uses. Only consolidation, which needs nothing but the file, is delegated to a cheaper subagent, and its output is checked deterministically before use.

## Resuming and searching history

To restore context in a fresh session, point Claude at `latest.md`. `latest.md` contains an `Archive:` line, so if you ask about something older that it does not cover, Claude can search the folder and `archive/`. That only works when `latest.md` was loaded in that session.
