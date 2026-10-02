#!/usr/bin/env bash
# Self-contained tests for skills/deep-compact/scripts/dc.sh. Uses temp dirs only; never touches ~/.claude.
# Run:  bash tests/run-tests.sh
set -u

DC="$(cd "$(dirname "$0")/.." && pwd)/skills/deep-compact/scripts/dc.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export DEEP_COMPACT_HOME="$T/home"
pass=0; fail=0

ok()   { pass=$((pass + 1)); echo "  ok   - $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL - $1"; }
has()  { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
check() { # name, haystack, needle
  if has "$2" "$3"; then ok "$1"; else bad "$1 (expected to contain: $3 | got: $2)"; fi
}

mkdoc() { # writes a valid 9-section file to $1, referencing $2 as a path
  { printf '# Session Handoff\nWritten: x\nArchive: none\n'
    for h in "Mission" "Key Decisions" "Files & Code State" "Commands & Environment" "Errors & Resolutions" "Open Threads" "User Constraints & Preferences" "Immediate Next Step" "Git State"; do
      printf '\n## %s\nline for %s `%s`\n' "$h" "$h" "$2"
    done; } > "$1"
}

echo "project id"
mkdir -p "$T/plain folder"
id="$(cd "$T/plain folder" && bash "$DC" id)"
check "id uses folder name + 8 hex chars" "$id" "plain folder-"

echo "git state"
out="$(cd "$T/plain folder" && bash "$DC" git)"
check "no git repository is handled" "$out" "Not a git repository"
mkdir -p "$T/empty" && (cd "$T/empty" && git init -q)
out="$(cd "$T/empty" && bash "$DC" git)"
check "repo without commits is handled" "$out" "none (no commits yet)"
mkdir -p "$T/withgit" && (cd "$T/withgit" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m first && echo x > f.txt)
out="$(cd "$T/withgit" && bash "$DC" git)"
check "repo without upstream is handled" "$out" "no remote tracking branch"
check "untracked file is listed" "$out" "?? f.txt"

echo "lock"
cd "$T/plain folder"
bash "$DC" lock >/dev/null
out="$(bash "$DC" lock 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "second lock is refused" || bad "second lock is refused"
check "refusal explains why" "$out" "LOCKED"
bash "$DC" unlock >/dev/null
d="$(bash "$DC" dir)"; mkdir "$d/.lock"; echo 1 > "$d/.lock/started"
out="$(bash "$DC" lock)"
check "stale lock is replaced" "$out" "stale lock"
bash "$DC" unlock >/dev/null

echo "install, archive, verify, status"
mkdoc "$T/doc.md" "$T/plain folder/exists.txt"; : > "$T/plain folder/exists.txt"
out="$(bash "$DC" install "$T/doc.md" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "install without lock is refused" || bad "install without lock is refused"
bash "$DC" lock >/dev/null
out="$(bash "$DC" install "$T/doc.md")"
check "install writes latest.md" "$out" "latest.md"
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do echo "old $i" > "$d/2026-01-$i-0900-handoff.md"; done
echo "keep" > "$d/2026-01-05-0900-stop.md"
out="$(bash "$DC" archive)"
check "older snapshots are archived" "$out" "kept newest 10"
[ -f "$d/2026-01-05-0900-stop.md" ] && ok "stop notes are never moved" || bad "stop notes are never moved"
[ -f "$d/archive/2026-01-01-0900-handoff.md" ] && ok "archived file exists in archive/" || bad "archived file exists in archive/"
out="$(bash "$DC" verify)"
check "verify passes on a valid file" "$out" "verify: OK"
rm -f "$T/plain folder/exists.txt"
out="$(bash "$DC" verify)"
check "verify warns about a missing path" "$out" "WARN: path in Files & Code State not found"
grep -v '^## Open Threads' "$T/doc.md" > "$T/broken.md"
out="$(bash "$DC" verify "$T/broken.md")"; rc=$?
[ "$rc" -ne 0 ] && ok "verify fails when a section is missing" || bad "verify fails when a section is missing"
check "failure names the section" "$out" "missing section '## Open Threads'"
bash "$DC" unlock >/dev/null
out="$(bash "$DC" status)"
check "status shows handoff counts" "$out" "Handoffs:"

echo "consolidate-check"
cat > "$T/before.md" <<'EOF'
## Mission
m
## Key Decisions
D1 keep
D2 keep
## Files & Code State
f
## Commands & Environment
c
## Errors & Resolutions
e
## Open Threads
o
## User Constraints & Preferences
u
## Immediate Next Step
n
## Git State
g
extra
extra2
EOF
sed '/^extra/d' "$T/before.md" > "$T/after_ok.md"
sed 's/D2 keep/D2 changed/' "$T/after_ok.md" > "$T/after_lost.md"
out="$(bash "$DC" consolidate-check "$T/before.md" "$T/after_ok.md")"; rc=$?
[ "$rc" -eq 0 ] && ok "shorter file with all decisions passes" || bad "shorter file with all decisions passes"
out="$(bash "$DC" consolidate-check "$T/before.md" "$T/after_lost.md")"; rc=$?
[ "$rc" -ne 0 ] && ok "a changed decision line is rejected" || bad "a changed decision line is rejected"
out="$(bash "$DC" consolidate-check "$T/before.md" "$T/before.md")"; rc=$?
[ "$rc" -ne 0 ] && ok "a file that is not shorter is rejected" || bad "a file that is not shorter is rejected"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
