# Limits and FAQ

## Limits

- **Manual only.** Claude Code can compact automatically when the context is nearly full. Deep Compact cannot intercept that. Run `/deep-compact` yourself, then `/compact`, before the window fills.
- **You run `/compact`.** Claude cannot invoke built-in commands, so the skill prints the exact command.
- **A new session needs a pointer.** A fresh session does not know the handoff exists. Paste the resume sentence the skill prints.
- **After `/compact` there is no automatic status.** The skill is finished by then. Run `/deep-compact` again to see an updated status.
- **Local only.** Files stay in your home folder and are not synced.
- **bash required.** macOS, Linux, or Git Bash / WSL on Windows. Windows is not yet tested.
- **Not for claude.ai web chat.** It needs a local filesystem and bash.
- **Not measured.** No claims are made about cost, token use or speed.

## FAQ

**Why is the handoff stored outside my project?**
So it can never end up in Git, a Docker image, or a deploy, and so the project stays clean. The trade-off is that it is tied to one machine.

**What if my folder is not a git repo?**
It works. The project id uses the current directory, and the Git State section says that git was skipped. A repo with no commits, or without a remote, is reported the same way.

**Can two sessions run it at once?**
They will not corrupt each other: a lock makes the second run stop with a clear message, and files are written atomically.

**Will `latest.md` grow forever?**
No. Past 500 lines it is consolidated automatically; Key Decisions lines are always kept verbatim, and older snapshots remain in `archive/`.

**Could consolidation lose a decision?**
It is guarded: the candidate is rejected if any Key Decisions line from the original is missing. Other sections are condensed by a model, so the backup in `archive/` and the full snapshots remain available.

**Does it send my data anywhere?**
No. The helper only reads and writes local files. (Your normal Claude Code session processes the conversation as usual.)

**Does `/compact` normally accept instructions?**
Yes, and the generated command uses that. Deep Compact adds a durable, structured, verified file for the command to point at.

**How do I remove it?**
Plugin: `claude plugin uninstall deep-compact`. Manual: delete `~/.claude/skills/deep-compact`. Your handoff files in `~/.claude/session-state/` are yours to keep or delete.
