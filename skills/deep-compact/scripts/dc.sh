#!/usr/bin/env bash
# deep-compact helper. Deterministic file/git utilities for the deep-compact skill.
# Writes ONLY under $DEEP_COMPACT_HOME (default ~/.claude/session-state). Never writes inside a project or runs a git write command.
# Usage: dc.sh <id|dir|lock|unlock|git|status|archive|install FILE|verify [FILE]|backup-latest|consolidate-check BEFORE AFTER>
set -u

DC_HOME="${DEEP_COMPACT_HOME:-$HOME/.claude/session-state}"
KEEP_SNAPSHOTS=10
MAX_LINES=500
LOCK_STALE_SECS=600
HEADERS="Mission|Key Decisions|Files & Code State|Commands & Environment|Errors & Resolutions|Open Threads|User Constraints & Preferences|Immediate Next Step|Git State"

hash8() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | cut -c1-8
  elif command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum | cut -c1-8
  else printf '%s' "$1" | cksum | cut -d' ' -f1; fi
}

root_dir() {
  r="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$r" ]; then printf '%s' "$r"; else pwd; fi
}

project_id() { r="$(root_dir)"; printf '%s-%s' "$(basename "$r")" "$(hash8 "$r")"; }
state_dir() { printf '%s/%s' "$DC_HOME" "$(project_id)"; }
stamp() { date +%Y-%m-%d-%H%M; }

# All sections named $1 in file $2 (the file may hold several stacked sets), header line included.
sections() { awk -v h="## $1" '$0==h{p=1;print;next} /^## /{p=0} p' "$2"; }

cmd_id() { project_id; echo; }
cmd_dir() { d="$(state_dir)"; mkdir -p "$d" && printf '%s\n' "$d"; }

cmd_lock() {
  d="$(state_dir)"; mkdir -p "$d" || return 1
  lock="$d/.lock"
  if mkdir "$lock" 2>/dev/null; then echo "$(date +%s)" > "$lock/started"; echo "lock acquired"; return 0; fi
  now="$(date +%s)"; ts="$(cat "$lock/started" 2>/dev/null)"; ts="${ts:-0}"
  if [ $((now - ts)) -gt "$LOCK_STALE_SECS" ]; then
    rm -rf "$lock"; mkdir "$lock" && echo "$now" > "$lock/started"
    echo "stale lock (older than ${LOCK_STALE_SECS}s) replaced"; return 0
  fi
  echo "LOCKED: another deep-compact run is writing to this project ($((now - ts))s ago). Wait and retry." >&2
  return 1
}

cmd_unlock() { d="$(state_dir)"; rm -rf "$d/.lock"; echo "lock released"; }

cmd_git() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a git repository - git state skipped."; return 0
  fi
  br="$(git branch --show-current 2>/dev/null)"
  echo "Branch: ${br:-(detached HEAD)}"
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "Last commit: $(git log -1 --format='%H %s')"
  else
    echo "Last commit: none (no commits yet)"
  fi
  if up="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)"; then
    counts="$(git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null)"
    ahead="$(echo "$counts" | awk '{print $1}')"; behind="$(echo "$counts" | awk '{print $2}')"
    echo "Upstream: $up - ahead $ahead, behind $behind"
  else
    echo "Upstream: none (no remote tracking branch)"
  fi
  echo "Working tree (porcelain, first 200 lines):"
  git --no-optional-locks status --porcelain 2>/dev/null | head -200
}

cmd_status() {
  d="$(state_dir)"
  echo "deep-compact status - $(project_id)"
  echo "Folder:   $d"
  if [ ! -d "$d" ]; then echo "No handoff files yet."; return 0; fi
  n="$(cd "$d" && ls -1 *-handoff.md 2>/dev/null | wc -l | tr -d ' ')"
  a=0; [ -d "$d/archive" ] && a="$(ls -1 "$d/archive" | wc -l | tr -d ' ')"
  echo "Handoffs: $n active, $a archived"
  echo "Size:     $(du -sh "$d" | cut -f1) total"
  if [ -f "$d/latest.md" ]; then
    l="$(wc -l < "$d/latest.md" | tr -d ' ')"
    echo "latest.md: $l lines (consolidation threshold $MAX_LINES)"
    [ "$l" -gt "$MAX_LINES" ] && echo "WARNING: latest.md is over $MAX_LINES lines."
  else
    echo "latest.md: not written yet"
  fi
  [ "$n" -gt "$KEEP_SNAPSHOTS" ] && echo "WARNING: more than $KEEP_SNAPSHOTS active snapshots - older ones move to archive/ on the next run."
  return 0
}

cmd_archive() {
  d="$(state_dir)"; [ -d "$d" ] || { echo "nothing to archive"; return 0; }
  cd "$d" || return 1
  files="$(ls -1 *-handoff.md 2>/dev/null | sort)"
  count="$(printf '%s\n' "$files" | grep -c .)"
  if [ "$count" -le "$KEEP_SNAPSHOTS" ]; then echo "archive: nothing to move ($count snapshots, keeping $KEEP_SNAPSHOTS)"; return 0; fi
  mkdir -p archive
  moved=0
  for f in $(printf '%s\n' "$files" | head -n $((count - KEEP_SNAPSHOTS))); do
    mv -n "$f" "archive/$f" && moved=$((moved + 1))
  done
  echo "archive: moved $moved snapshot(s) to $d/archive/ (kept newest $KEEP_SNAPSHOTS)"
}

cmd_install() {
  src="${1:-}"; [ -n "$src" ] && [ -s "$src" ] || { echo "install: source file missing or empty" >&2; return 1; }
  d="$(state_dir)"
  [ -d "$d/.lock" ] || { echo "install: take the lock first (dc.sh lock)" >&2; return 1; }
  tmp="$d/.latest.md.tmp"
  cp "$src" "$tmp" && mv -f "$tmp" "$d/latest.md" || return 1
  snap="$d/$(stamp)-handoff.md"
  [ -e "$snap" ] && snap="$d/$(date +%Y-%m-%d-%H%M%S)-handoff.md"
  cp "$d/latest.md" "$snap" || return 1
  echo "wrote $d/latest.md"
  echo "wrote $snap"
}

cmd_backup_latest() {
  d="$(state_dir)"; [ -f "$d/latest.md" ] || { echo "no latest.md to back up"; return 0; }
  mkdir -p "$d/archive"
  b="$d/archive/latest-pre-consolidation-$(date +%Y-%m-%d-%H%M%S).md"
  cp "$d/latest.md" "$b" && echo "$b"
}

cmd_verify() {
  d="$(state_dir)"; f="${1:-$d/latest.md}"
  [ -f "$f" ] || { echo "FAIL: $f not found"; return 1; }
  fail=0; warn=0
  oldifs="$IFS"; IFS='|'
  for h in $HEADERS; do
    if ! grep -qxF "## $h" "$f"; then echo "FAIL: missing section '## $h'"; fail=1; fi
  done
  IFS="$oldifs"
  l="$(wc -l < "$f" | tr -d ' ')"
  [ "$l" -gt "$MAX_LINES" ] && { echo "WARN: $l lines (over $MAX_LINES) - consolidation due"; warn=1; }
  if [ -d "$d/archive" ] && ls "$d/archive"/* >/dev/null 2>&1 && ! grep -q '^Archive:' "$f"; then
    echo "WARN: archive/ exists but latest.md has no 'Archive:' line"; warn=1
  fi
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    rec="$(grep -m1 'Last commit' "$f" | grep -oE '[0-9a-f]{40}' | head -1)"
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      head_sha="$(git rev-parse HEAD)"
      if [ -z "$rec" ]; then echo "WARN: Git State records no commit hash but repo has commits"; warn=1
      elif [ "$rec" != "$head_sha" ]; then echo "WARN: recorded commit ${rec%"${rec#???????}"} differs from HEAD ${head_sha%"${head_sha#???????}"}"; warn=1; fi
    fi
  fi
  missing=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in *'*'*|*'?'*|*'<'*|*'>'*|*,*) continue ;; esac
    case "$p" in
      "~/"*) q="$HOME/${p#\~/}" ;;
      /*) top="${p#/}"; top="${top%%/*}"; [ -d "/$top" ] || continue; q="$p" ;;
      *) q="$p" ;;
    esac
    if [ ! -e "$q" ]; then
      missing=$((missing + 1))
      [ "$missing" -le 10 ] && echo "WARN: path in Files & Code State not found: $p"
    fi
  done <<EOF
$(sections "Files & Code State" "$f" | grep -oE '`[~/][^`]+`' | tr -d '`' | sort -u)
EOF
  [ "$missing" -gt 0 ] && { echo "WARN: $missing listed path(s) missing in total (may be intentionally deleted)"; warn=1; }
  if [ "$fail" -eq 0 ]; then echo "verify: OK ($l lines, $warn warning group(s))"; return 0; fi
  echo "verify: FAILED"; return 1
}

cmd_consolidate_check() {
  b="${1:-}"; a="${2:-}"
  [ -f "$b" ] && [ -f "$a" ] || { echo "consolidate-check: need BEFORE and AFTER files" >&2; return 1; }
  fail=0
  oldifs="$IFS"; IFS='|'
  for h in $HEADERS; do
    grep -qxF "## $h" "$a" || { echo "FAIL: AFTER missing '## $h'"; fail=1; }
  done
  IFS="$oldifs"
  tb="$(mktemp)"; ta="$(mktemp)"
  sections "Key Decisions" "$b" | sed 's/[[:space:]]*$//' | grep -v '^$' | sort -u > "$tb"
  sections "Key Decisions" "$a" | sed 's/[[:space:]]*$//' | grep -v '^$' | sort -u > "$ta"
  lost="$(comm -23 "$tb" "$ta" | wc -l | tr -d ' ')"
  if [ "$lost" -gt 0 ]; then echo "FAIL: $lost Key Decisions line(s) from BEFORE are missing in AFTER (first 5 below)"; comm -23 "$tb" "$ta" | head -5 | cut -c1-160; fail=1; fi
  rm -f "$tb" "$ta"
  lb="$(wc -l < "$b" | tr -d ' ')"; la="$(wc -l < "$a" | tr -d ' ')"
  [ "$la" -ge "$lb" ] && { echo "FAIL: AFTER ($la lines) is not shorter than BEFORE ($lb lines)"; fail=1; }
  if [ "$fail" -eq 0 ]; then echo "consolidate-check: OK ($lb -> $la lines, no Key Decisions line lost)"; return 0; fi
  return 1
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  id) cmd_id ;;
  dir) cmd_dir ;;
  lock) cmd_lock ;;
  unlock) cmd_unlock ;;
  git) cmd_git ;;
  status) cmd_status ;;
  archive) cmd_archive ;;
  install) cmd_install "$@" ;;
  verify) cmd_verify "$@" ;;
  backup-latest) cmd_backup_latest ;;
  consolidate-check) cmd_consolidate_check "$@" ;;
  *) echo "usage: dc.sh <id|dir|lock|unlock|git|status|archive|install FILE|verify [FILE]|backup-latest|consolidate-check BEFORE AFTER>" >&2; exit 2 ;;
esac
