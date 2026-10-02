#!/usr/bin/env bash
# Installs the Deep Compact skill for your user (works for every project) by copying it into ~/.claude/skills.
# Run from the repo root:  bash install/install.sh        (set CLAUDE_HOME to use a non-default config dir)
set -eu

src="$(cd "$(dirname "$0")/.." && pwd)/skills/deep-compact"
dest="${CLAUDE_HOME:-$HOME/.claude}/skills/deep-compact"

[ -f "$src/SKILL.md" ] || { echo "Cannot find $src/SKILL.md - run this from a full clone of the repo." >&2; exit 1; }

if [ -e "$dest" ]; then
  backup="$dest.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$dest" "$backup"
  echo "Existing install moved to: $backup"
fi

mkdir -p "$dest"
cp -R "$src/." "$dest/"
echo "Installed to: $dest"
echo "Open Claude Code and type /deep-compact (a new session may be needed the first time)."
