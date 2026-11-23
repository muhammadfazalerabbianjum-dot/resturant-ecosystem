<#
.SYNOPSIS
  FIX-B10 Pre-Commit / Pre-Push / CI Hygiene Guard (AUD4-C12-05)

.DESCRIPTION
  Enforces monorepo hygiene policies on staged (or specified) files.
  The bracket label is emitted VERBATIM in every violation message, and this
  docblock is the single source of truth for those labels (AUD2R-01: the
  auditor-territory check used to emit [RULE 4], the root-litter label, so two
  behaviours shared one number):

    [RULE 1] *.log files outside tool_audit/*/receipts/
    [RULE 2] *.info files anywhere in the repo
    [RULE 3] tool_audit/*/scratch/** files
    [RULE 4] root litter (*_out.txt, *_err.txt, *.iml, the literal `_`,
             potato*.md, perf2_*, and the listed scratch names)
    [RULE 5] auditor territory (a commit touching tool_audit/** may carry
             only tool_audit/**, tool_fix/** and .gitignore)
    [RULE 6] dart format --output=none --set-exit-if-changed on Dart files

  tool_guard/guard_selftest.ps1 proves each label fires on a broken input and
  stays silent on a correct tree, and greps this docblock for every label the
  code can emit.

.PARAMETER StagedOnly
  Inspects only git staged files (default for pre-commit hook).

.PARAMETER Files
  Explicit list of relative file paths to inspect (used for testing).

.PARAMETER SkipFormat
  Skips running dart format (used when testing file-rejection rules).
#>
[CmdletBinding()]
param(
  [switch]$StagedOnly,
  [string[]]$Files,
  [switch]$SkipFormat
)

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

$Violations = [System.Collections.Generic.List[string]]::new()

# Gather files to inspect
if ($Files -and $Files.Count -gt 0) {
  $TargetFiles = $Files
} elseif ($StagedOnly) {
  $TargetFiles = git -C $RepoRoot diff --cached --name-only --diff-filter=ACMR
} else {
  $TargetFiles = git -C $RepoRoot diff --cached --name-only --diff-filter=ACMR
  if (-not $TargetFiles) {
    # If nothing staged, inspect uncommitted tracked changes
    $TargetFiles = git -C $RepoRoot diff --name-only --diff-filter=ACMR
  }
}

if (-not $TargetFiles) {
  Write-Host '[GUARD] No files to inspect. Clean.' -ForegroundColor Green
  exit 0
}

# Auditor allowlist check (if any staged file is in tool_audit/, ONLY tool_audit/** or tool_fix/** is permitted)
$HasAuditFiles = $TargetFiles | Where-Object { $_ -match '^tool_audit/' }
if ($HasAuditFiles) {
  $ForeignFiles = $TargetFiles | Where-Object { $_ -notmatch '^(tool_audit/|tool_fix/|\.gitignore$)' }
  if ($ForeignFiles) {
    $Violations.Add("[RULE 5] Auditor territory violation: commit touches tool_audit/ but also touches foreign files: $($ForeignFiles -join ', ')")
  }
}

foreach ($f in $TargetFiles) {
  $norm = $f.Replace('\', '/')

  # Rule 1: Rejects new *.log outside tool_audit/*/receipts/
  if ($norm -match '\.log$') {
    if ($norm -notmatch '^tool_audit/[^/]+/receipts/.*\.log$') {
      $Violations.Add("[RULE 1] Forbidden log artifact: '$norm' (logs only allowed under tool_audit/*/receipts/)")
    }
  }

  # Rule 2: Rejects *.info anywhere
  if ($norm -match '\.info$') {
    $Violations.Add("[RULE 2] Forbidden lcov/info artifact: '$norm' (*.info files must never be committed)")
  }

  # Rule 3: Rejects tool_audit/*/scratch/**
  if ($norm -match '^tool_audit/[^/]+/scratch/') {
    $Violations.Add("[RULE 3] Forbidden audit scratch artifact: '$norm' (scratch files must never be committed)")
  }

  # Rule 4: Root-level litter
  if ($norm -match '^(core_.*|halal_.*|pkg_.*|test_.*)_out\.txt$') {
    $Violations.Add("[RULE 4] Forbidden root output artifact: '$norm'")
  }
  if ($norm -match '^(core_.*|halal_.*|pkg_.*|test_.*)_err\.txt$') {
    $Violations.Add("[RULE 4] Forbidden root error artifact: '$norm'")
  }
  if ($norm -match '\.iml$') {
    $Violations.Add("[RULE 4] Forbidden IDE module artifact: '$norm'")
  }
  if ($norm -eq '_') {
    $Violations.Add("[RULE 4] Forbidden orphan artifact: '$norm'")
  }
  if ($norm -match '^potato.*\.md$') {
    $Violations.Add("[RULE 4] Forbidden temporary potato document: '$norm'")
  }
  if ($norm -match '^perf2_') {
    $Violations.Add("[RULE 4] Forbidden perf2 temporary artifact: '$norm'")
  }
  if ($norm -in @('analytics_calls.txt', 'checks_usage.txt', 'config_test_refs.txt', 'dead_tests.txt', 'screen_matrix.csv', 'skip_findings.txt', '_screen_matrix.ps1')) {
    $Violations.Add("[RULE 4] Forbidden scratch litter artifact: '$norm'")
  }
}

if ($Violations.Count -gt 0) {
  Write-Host '[GUARD] Hygiene violations found:' -ForegroundColor Red
  foreach ($v in $Violations) {
    Write-Host "  - $v" -ForegroundColor Red
  }
  exit 1
}

# Rule 6: dart format check
if (-not $SkipFormat) {
  Write-Host '[GUARD] Running dart format check...' -ForegroundColor Cyan
  $dartFiles = $TargetFiles | Where-Object { $_ -match '\.dart$' }
  if ($dartFiles) {
    $fmtResult = dart format --output=none --set-exit-if-changed $dartFiles
    if ($LASTEXITCODE -ne 0) {
      Write-Host '[RULE 6] Unformatted Dart files found! Run dart format on staged files.' -ForegroundColor Red
      exit 1
    }
  }
}

Write-Host '[GUARD] All hygiene checks passed.' -ForegroundColor Green
exit 0
