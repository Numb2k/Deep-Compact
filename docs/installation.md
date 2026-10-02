# Installation

Deep Compact is a Claude Code **skill**: a `SKILL.md` plus a small bash helper (`scripts/dc.sh`). Any install method just has to put that folder where Claude Code looks for skills.

## Requirements

- Claude Code (CLI, desktop app Code tab, or an IDE extension).
- `bash`. macOS and Linux have it. On Windows, Claude Code runs shell commands through Git Bash or WSL, which is what the helper uses.
- `git` is optional.

## Method 1: plugin marketplace

```text
/plugin marketplace add Numb2k/Deep-Compact
/plugin install deep-compact@deep-compact
```

Terminal equivalents:

```bash
claude plugin marketplace add Numb2k/Deep-Compact
claude plugin install deep-compact@deep-compact
```

Update later with `claude plugin update deep-compact` (or through the `/plugin` menu). Uninstall with `claude plugin uninstall deep-compact`.

The repository is both a marketplace and a plugin (`.claude-plugin/marketplace.json` points at `./`, and the skill lives in `skills/deep-compact/`).

## Method 2: `skills` CLI

```bash
npx skills add Numb2k/Deep-Compact --global --yes
```

This copies the skill into your user skills folder. (It relies on the repo layout `skills/<name>/SKILL.md`, which this repo follows.)

## Method 3: manual

| OS | Copy `skills/deep-compact` to |
|---|---|
| macOS / Linux | `~/.claude/skills/deep-compact` |
| Windows | `%USERPROFILE%\.claude\skills\deep-compact` |

Or run the included installers, which also back up an existing copy:

```bash
bash install/install.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

Set `CLAUDE_HOME` first if your Claude config folder is not the default `~/.claude`.

### Project-only install

To use it in one project only, copy the folder to `<project>/.claude/skills/deep-compact` instead. Note that the handoff files are still written to your home folder, never to the project.

## Where it works

| Surface | Works? |
|---|---|
| Claude Code CLI | Yes |
| Claude desktop app, **Code** tab | Yes (same `~/.claude` folder) |
| VS Code / JetBrains extensions | Yes (same `~/.claude` folder) |
| claude.ai web chat | Not designed for it: needs a local filesystem and bash |

## Check that it is installed

Start a new Claude Code session and type `/deep-compact`. It should appear in the slash-command list. If it does not, see below.

## Troubleshooting

- **The command does not appear.** Start a new session after installing. Confirm that `SKILL.md` exists at `~/.claude/skills/deep-compact/SKILL.md` (or that the plugin shows as enabled in `/plugin`).
- **"helper is missing" message.** The `scripts/` folder was not copied. Re-run an install method; the skill needs `scripts/dc.sh` next to `SKILL.md`.
- **`bash: command not found` on Windows.** Install Git for Windows (Git Bash) or enable WSL, then restart Claude Code.
- **"LOCKED: another deep-compact run is writing to this project".** A parallel session is running the skill, or a previous run crashed. Locks older than 10 minutes are replaced automatically.
- **Custom config folder.** If you use a non-default Claude config location, install into its `skills/` folder and set `DEEP_COMPACT_HOME` if you also want the handoffs stored elsewhere.
