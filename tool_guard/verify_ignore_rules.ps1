<#
.SYNOPSIS
  FIX-B10 T-4  -  re-runnable proof that `.gitignore` classifies each artifact class
  the way the contract requires (AUD4-C12-05).

.DESCRIPTION
  `git check-ignore` is deliberately NOT used as the oracle here: with a NEGATIVE
  pattern (`!tool_audit/*/receipts/*.log`) git still exits 0 and prints the negation,
  so the exit code cannot distinguish "ignored" from "explicitly un-ignored".
  Ground truth is `git status --ignored`: `!!` = ignored, `??` = untracked (wanted).

  For every probe path it writes nothing into the tree except throwaway zero-byte
  files under directories that are themselves disposable, then removes them again.

.PARAMETER Repo
  Worktree root. Defaults to the parent of this script's folder.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool_guard\verify_ignore_rules.ps1
#>
[CmdletBinding()]
param([string]$Repo = '')

if (-not $Repo) { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Repo

# probe path -> expected classification
$expect = [ordered]@{
  'coverage/lcov.info'                        = 'ignored'
  'core_app/coverage/lcov.info'               = 'ignored'
  'packages/core/coverage/lcov.info'          = 'ignored'
  'node_modules/express/index.js'             = 'ignored'
  'functions/node_modules/index.js'           = 'ignored'
  'tool_perf2/probe.info'                     = 'ignored'
  'probe.info'                                = 'ignored'
  'perf2_root.md'                             = 'ignored'
  'perf2_probe.log'                           = 'ignored'
  'potato.md'                                 = 'ignored'
  'potato4_b2.md'                             = 'ignored'
  'potato9.md'                                = 'ignored'
  'analytics_calls.txt'                       = 'ignored'
  'checks_usage.txt'                          = 'ignored'
  'config_test_refs.txt'                      = 'ignored'
  'dead_tests.txt'                            = 'ignored'
  'screen_matrix.csv'                         = 'ignored'
  'skip_findings.txt'                         = 'ignored'
  'test_assert_gaps.csv'                      = 'ignored'
  'test_assert_gaps2.txt'                     = 'ignored'
  'melos_carnama_monorepo.iml'                = 'ignored'
  'core_probe_out.txt'                        = 'ignored'
  'core_probe_err.txt'                        = 'ignored'
  '_'                                         = 'ignored'
  '_screen_matrix.ps1'                        = 'ignored'
  'tool_audit/aud1/scratch/probe_test.dart'   = 'ignored'
  'tool_perf2/probe_receipt.log'              = 'ignored'
  'tool_archive/probe_dump.tar.gz'            = 'ignored'
  # explicit exemptions - these MUST stay addable
  'tool_audit/aud1/receipts/probe_receipt.log' = 'untracked'
  'tool_audit/aud3/receipts/probe_receipt.log' = 'untracked'
  'tool_fix/b7/probe_receipt.txt'              = 'untracked'
  'packages/core/lib/probe_source.dart'        = 'untracked'
  # AUD2R-02: these archives are COMMITTED (batch B10, `git ls-files
  # tool_archive` = 3 tarballs). Expecting 'untracked' made this verifier
  # impossible to pass; 'tracked' is the honest classification, and the
  # un-ignored rule that keeps them addable is still exercised by them.
  'tool_archive/perf2_litter.tar.gz'           = 'tracked'
  'tool_archive/perf2_judge_litter.tar.gz'     = 'tracked'
  'tool_archive/aud4_scratch.tar.gz'           = 'tracked'
}

# AUD2R-02: a COMMITTED probe is invisible to `status` (it is neither ignored
# nor untracked), so it needs its own oracle: the index. Computed BEFORE the
# probes are written, because a tracked probe must never be created  -  writing a
# zero-byte file over a committed archive would corrupt the tree.
$trackedSet = @{}
foreach ($line in (git -C $Repo ls-files -- tool_archive tool_audit tool_fix packages)) {
  if ($line) { $trackedSet[$line] = $true }
}

# --- create probes -----------------------------------------------------------
# `_` is the only 1-char oddity: write it as an empty file.
$missingTracked = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $expect.Keys) {
  if ($trackedSet.ContainsKey($rel)) {
    if (-not (Test-Path (Join-Path $Repo $rel))) { $missingTracked.Add($rel) }
    continue
  }
  $full = Join-Path $Repo $rel
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not (Test-Path $full)) { Set-Content -LiteralPath $full -Value 'b10 probe' -Encoding ascii }
}
if ($missingTracked.Count -gt 0) {
  Write-Host "[verify_ignore_rules] RESULT: FAIL (tracked probe(s) absent from the worktree: $($missingTracked -join ', '))" -ForegroundColor Red
  exit 1
}

$statusLines = git -C $Repo status --porcelain --ignored -uall
$ignoredSet = @{}
$untrackedSet = @{}
foreach ($line in $statusLines) {
  $code = $line.Substring(0, 2)
  $p = $line.Substring(3).Trim()
  if ($code -eq '!!') { $ignoredSet[$p] = $true }
  elseif ($code -eq '??') { $untrackedSet[$p] = $true }
}

# AUD2R-02: a COMMITTED probe is invisible to `status` (it is neither ignored
# nor untracked), so it needs its own oracle: the index.
$trackedSet = @{}
foreach ($line in (git -C $Repo ls-files -- tool_archive tool_audit tool_fix packages)) {
  if ($line) { $trackedSet[$line] = $true }
}

# --- classify ---------------------------------------------------------------
$fail = 0
$report = [System.Collections.Generic.List[string]]::new()
$probePaths = @($expect.Keys)

foreach ($rel in $probePaths) {
  $norm = $rel.Replace('\', '/')
  if ($ignoredSet.ContainsKey($norm)) { $actual = 'ignored' }
  elseif ($untrackedSet.ContainsKey($norm)) { $actual = 'untracked' }
  elseif ($trackedSet.ContainsKey($norm)) { $actual = 'tracked' }
  else { $actual = 'missing-from-status' }

  $wanted = $expect[$rel]
  if ($actual -ne $wanted) {
    $fail++
    $report.Add(("FAIL  {0,-45} wanted={1,-9} actual={2}" -f $rel, $wanted, $actual))
  } else {
    $report.Add(("ok    {0,-45} {1}" -f $rel, $actual))
  }
}

# --- cleanup (leave no probe behind, and delete any now-empty probe dirs) -----
Remove-Item -LiteralPath (Join-Path $Repo '_') -Force -ErrorAction SilentlyContinue
foreach ($rel in $probePaths) {
  if ($trackedSet.ContainsKey($rel)) { continue }
  $full = Join-Path $Repo $rel
  if (Test-Path $full -PathType Leaf) {
    Remove-Item -LiteralPath $full -Force
  }
}
foreach ($d in @('node_modules/express', 'node_modules', 'functions/node_modules', 'functions',
                 'coverage', 'tool_audit/aud1/scratch', 'tool_audit/aud3/receipts',
                 'tool_audit/aud1/receipts', 'tool_audit/aud1', 'tool_audit/aud3')) {
  $full = Join-Path $Repo $d
  if ((Test-Path $full) -and -not (Get-ChildItem -LiteralPath $full -Force)) {
    Remove-Item -LiteralPath $full -Force
  }
}

$report | ForEach-Object { Write-Host $_ }
if ($fail -gt 0) {
  Write-Host "[verify_ignore_rules] RESULT: FAIL ($fail of $($probePaths.Count) probes misclassified)" -ForegroundColor Red
  exit 1
}
Write-Host "[verify_ignore_rules] RESULT: PASS ($($probePaths.Count) probes, 0 misclassified)" -ForegroundColor Green
exit 0

