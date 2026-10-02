# Installs the Deep Compact skill for your user by copying it into %USERPROFILE%\.claude\skills.
# Run from the repo root in PowerShell:  powershell -ExecutionPolicy Bypass -File install\install.ps1
# Note: the skill's helper script needs bash (Git Bash or WSL), the same bash Claude Code uses on Windows.
$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repo "skills\deep-compact"
$base = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE ".claude" }
$dest = Join-Path $base "skills\deep-compact"

if (-not (Test-Path (Join-Path $src "SKILL.md"))) { throw "Cannot find $src\SKILL.md - run this from a full clone of the repo." }

if (Test-Path $dest) {
  $backup = "$dest.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Move-Item $dest $backup
  Write-Host "Existing install moved to: $backup"
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $src "*") $dest
Write-Host "Installed to: $dest"
Write-Host "Open Claude Code and type /deep-compact (a new session may be needed the first time)."
