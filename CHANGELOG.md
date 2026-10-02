# Changelog

## 1.0.0

First public release.

- Handoff written to `~/.claude/session-state/<project-id>/` (never inside the project).
- Nine structured sections, one cumulative `latest.md` plus a timestamped snapshot per run.
- Helper script `dc.sh`: project id, lock, atomic install, archive (newest 10 snapshots stay), verify, status, consolidation check.
- Mandatory consolidation over 500 lines, guarded so that no Key Decisions line can be lost.
- Works without git (no repo, no commits, no upstream).
- Final report (status, verify result, `/compact` command, resume sentence) always appears as plain text.
