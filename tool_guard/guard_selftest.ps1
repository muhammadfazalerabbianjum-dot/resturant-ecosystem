<#
.SYNOPSIS
  FIX-B10 rule-hygiene self-test (UI-14 / p25 T-5, law L-P4).

.DESCRIPTION
  L-P4: a verifier that can never fail is noise. This harness proves BOTH
  tool_guard verifiers are still falsifiable after the AUD2R-01 / AUD2R-02
  repairs:

    A. check_hygiene.ps1  - every rule label it can emit ([RULE 1]..[RULE 6])
       must FIRE on a broken input, exit 0 on a correct one, and be listed in
       the script's own docblock (the docblock is the label oracle, so it can
       never drift from the code again).
    B. verify_ignore_rules.ps1  - must PASS on this tree, and a copy with ONE
       probe expectation flipped must FAIL (proving the pass is not vacuous).

  Exits non-zero if any step is wrong; writes a receipt when -Receipt is given.

.PARAMETER Repo
  Worktree root. Defaults to the parent of this script's folder.

.PARAMETER Receipt
  Optional path for the receipt file.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool_guard\guard_selftest.ps1 -Receipt tool_uilib\p25\guard_selftest.txt
#>
[CmdletBinding()]
param([string]$Repo = '', [string]$Receipt = '')

if (-not $Repo) { $Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$hygiene = Join-Path $PSScriptRoot 'check_hygiene.ps1'
$verify = Join-Path $PSScriptRoot 'verify_ignore_rules.ps1'
$log = [System.Collections.Generic.List[string]]::new()
$fail = 0

function Add-Line([string]$text) {
  Write-Host $text
  $log.Add($text)
}

# Runs a guard in a CHILD process (the guards call `exit`, which would kill this
# session) and returns its exit code plus combined output.
function Invoke-Guard([string]$script, [string[]]$scriptArgs) {
  $out = Join-Path $env:TEMP ("p25_guard_" + [guid]::NewGuid().ToString('N') + '.out')
  $err = "$out.err"
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script,
    '-Repo', $Repo) + $scriptArgs
  $p = Start-Process powershell -PassThru -Wait -WindowStyle Hidden `
    -ArgumentList $argList `
    -RedirectStandardOutput $out -RedirectStandardError $err
  $text = ''
  foreach ($f in @($out, $err)) {
    if (Test-Path $f) { $text += (Get-Content -Raw $f) }
  }
  Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
  return @{ Exit = $p.ExitCode; Text = $text }
}

# check_hygiene.ps1 takes -Files as an ARRAY, which `powershell -File` cannot
# express, so those probes run through -Command.
function Invoke-Hygiene([string[]]$files, [switch]$SkipFormat) {
  $out = Join-Path $env:TEMP ("p25_hyg_" + [guid]::NewGuid().ToString('N') + '.out')
  $list = '@(' + (($files | ForEach-Object { "'$_'" }) -join ',') + ')'
  $cmd = "& '$hygiene' -Files $list" + $(if ($SkipFormat) { ' -SkipFormat' } else { '' })
  $p = Start-Process powershell -PassThru -Wait -WindowStyle Hidden `
    -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "`"$cmd`"" `
    -RedirectStandardOutput $out -RedirectStandardError "$out.err"
  $text = (Get-Content -Raw $out) + (Get-Content -Raw "$out.err" -ErrorAction SilentlyContinue)
  Remove-Item -LiteralPath $out, "$out.err" -Force -ErrorAction SilentlyContinue
  return @{ Exit = $p.ExitCode; Text = $text }
}

Add-Line '=========================================================='
Add-Line 'UI-14 (p25) T-5 guard self-test (L-P4)'
Add-Line ("utc  : " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
Add-Line ("repo : " + $Repo)
Add-Line '=========================================================='
Add-Line 'A. check_hygiene.ps1  - every emitted label must fire on a broken input'


# rule label -> probe files that must trigger it
$ruleProbes = [ordered]@{
  '[RULE 1]' = @{ Files = @('perf2_probe.log'); SkipFormat = $true }
  '[RULE 2]' = @{ Files = @('coverage/lcov.info'); SkipFormat = $true }
  '[RULE 3]' = @{ Files = @('tool_audit/aud1/scratch/probe_test.dart'); SkipFormat = $true }
  '[RULE 4]' = @{ Files = @('core_probe_out.txt'); SkipFormat = $true }
  '[RULE 5]' = @{
    Files = @('tool_audit/aud1/probe.txt', 'core_app/lib/main.dart')
    SkipFormat = $true
  }
  # RULE 6 needs the real thing: a deliberately unformatted Dart file.
  '[RULE 6]' = @{ Files = @('tool_uilib/p25/_rule6_probe.dart'); SkipFormat = $false }
}

$rule6Probe = Join-Path $Repo 'tool_uilib/p25/_rule6_probe.dart'
Set-Content -LiteralPath $rule6Probe -Value "void  main( ){  final x = 1;}" -Encoding ascii

foreach ($label in $ruleProbes.Keys) {
  $spec = $ruleProbes[$label]
  $res = Invoke-Hygiene -files $spec.Files -SkipFormat:([bool]$spec.SkipFormat)
  $fired = ($res.Exit -ne 0) -and ($res.Text -match [regex]::Escape($label))
  if ($fired) {
    Add-Line ("  ok    {0} fires on {1} (exit {2})" -f $label, ($spec.Files -join ' + '), $res.Exit)
  } else {
    $fail++
    Add-Line ("  FAIL  {0} did NOT fire on {1} (exit {2})" -f $label, ($spec.Files -join ' + '), $res.Exit)
    Add-Line ("        output: " + ($res.Text -replace '\s+', ' ').Trim())
  }
}
Remove-Item -LiteralPath $rule6Probe -Force -ErrorAction SilentlyContinue

# The docblock must name every label the code emits (AUD2R-01 regression guard).
$hygieneText = Get-Content -Raw $hygiene
foreach ($label in $ruleProbes.Keys) {
  if ($hygieneText -match ('    ' + [regex]::Escape($label) + ' ')) {
    Add-Line ("  ok    docblock names {0}" -f $label)
  } else {
    $fail++
    Add-Line ("  FAIL  docblock does NOT name {0} (label drift)" -f $label)
  }
}

# A correct tree must stay silent.
$clean = Invoke-Hygiene -files @('core_app/lib/main.dart') -SkipFormat
if ($clean.Exit -eq 0) {
  Add-Line ("  ok    clean input passes (exit 0): " + ($clean.Text -replace '\s+', ' ').Trim())
} else {
  $fail++
  Add-Line ("  FAIL  clean input rejected (exit " + $clean.Exit + "): " + ($clean.Text -replace '\s+', ' ').Trim())
}

Add-Line ''
Add-Line 'B. verify_ignore_rules.ps1  - must pass here, and FAIL when a probe lies'

$verifyRun = Invoke-Guard -script $verify -scriptArgs @()
if ($verifyRun.Exit -eq 0 -and $verifyRun.Text -match 'RESULT: PASS') {
  $pass = ([regex]::Match($verifyRun.Text, 'RESULT: PASS \([^)]*\)')).Value
  Add-Line ("  ok    correct tree passes: " + $pass)
} else {
  $fail++
  Add-Line ("  FAIL  correct tree rejected (exit " + $verifyRun.Exit + ")")
  Add-Line ("        " + ($verifyRun.Text -replace '\s+', ' ').Trim())
}

# Broken input: flip ONE probe expectation in a throwaway copy of the verifier.
# A verifier that still passes with a lying expectation is not verifying anything.
$broken = Join-Path $env:TEMP 'p25_verify_ignore_rules_broken.ps1'
(Get-Content -Raw $verify).Replace(
  "'tool_audit/aud1/receipts/probe_receipt.log' = 'untracked'",
  "'tool_audit/aud1/receipts/probe_receipt.log' = 'ignored'"
) | Set-Content -LiteralPath $broken -Encoding utf8
$brokenRun = Invoke-Guard -script $broken -scriptArgs @()
if ($brokenRun.Exit -ne 0 -and $brokenRun.Text -match 'RESULT: FAIL') {
  $detected = ([regex]::Match($brokenRun.Text, 'FAIL  tool_audit/aud1/receipts/probe_receipt\.log[^\r\n]*')).Value
  Add-Line ("  ok    lying probe detected: " + $detected.Trim())
} else {
  $fail++
  Add-Line ("  FAIL  lying probe NOT detected (exit " + $brokenRun.Exit + ") - the pass above is vacuous")
}
Remove-Item -LiteralPath $broken -Force -ErrorAction SilentlyContinue

Add-Line ''
if ($fail -gt 0) {
  Add-Line "[guard_selftest] RESULT: FAIL ($fail step(s) wrong)"
  if ($Receipt) { Set-Content -LiteralPath $Receipt -Value $log -Encoding utf8 }
  exit 1
}
Add-Line '[guard_selftest] RESULT: PASS (labels fire, docblock matches, verifier falsifiable)'
if ($Receipt) { Set-Content -LiteralPath $Receipt -Value $log -Encoding utf8 }
exit 0




