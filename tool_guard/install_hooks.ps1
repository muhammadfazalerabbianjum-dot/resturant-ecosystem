<#
.SYNOPSIS
  FIX-B10 — install the hygiene guard as a git pre-commit hook in THIS worktree.

.DESCRIPTION
  `.git/hooks/**` is never version-controlled, so the hook itself cannot be committed.
  This script is the committed, re-runnable half: run it once per worktree to wire
  `tool_guard/check_hygiene.ps1` into `pre-commit` (and a `pre-push` mirror).

  It is idempotent: re-running overwrites the hook with the same bytes.

.PARAMETER Repo
  Worktree root. Defaults to the parent of this script's folder.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool_guard\install_hooks.ps1
#>
[CmdletBinding()]
param([string]$Repo = '')

if (-not $Repo) { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

# Linked worktrees (this repo uses several) resolve hooks from the COMMON git dir,
# and `.git` may be a FILE rather than a directory - so ask git itself.
$HookDir = (& git -C $Repo rev-parse --git-path hooks 2>$null)
if (-not $HookDir) { throw "not a git worktree (no git dir): $Repo" }
$HookDir = (Resolve-Path $HookDir).Path
if (-not (Test-Path $HookDir)) { New-Item -ItemType Directory -Force -Path $HookDir | Out-Null }
Write-Host "[install_hooks] hooks dir: $HookDir"

$HookBody = @'
#!/bin/sh
# FIX-B10 hygiene guard (AUD4-C12-05). Installed by tool_guard/install_hooks.ps1.
# Bypass deliberately with: git commit --no-verify
#
# NOTE: this hook lives in the COMMON git dir, so it is shared by every worktree of
# this repo. A worktree that does not (yet) carry tool_guard/check_hygiene.ps1 is
# skipped with a notice rather than blocked - the guard travels with the branch.
root=$(git rev-parse --show-toplevel)
guard="$root/tool_guard/check_hygiene.ps1"
if [ ! -f "$guard" ]; then
  echo "[GUARD] skipped: $guard not present in this worktree (pre-B10 branch)"
  exit 0
fi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$guard" -StagedOnly
exit $?
'@

foreach ($name in @('pre-commit', 'pre-push')) {
  $path = Join-Path $HookDir $name
  # LF endings: the hook is executed by sh (Git for Windows).
  [System.IO.File]::WriteAllText($path, ($HookBody -replace "`r`n", "`n"))
  Write-Host "[install_hooks] wrote $path"
}

Write-Host "[install_hooks] guard: $Repo\tool_guard\check_hygiene.ps1"
Write-Host '[install_hooks] done.'
