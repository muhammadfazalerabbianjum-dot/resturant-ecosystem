# Carnama Integration Test Runner (p34 T-1: E2E-DEVICE lane)
# Usage:
#   .\tool\run_integration_tests.ps1            -> prep + full e2e run + cleanup
#   .\tool\run_integration_tests.ps1 -PrepOnly -> adb tunnels + Firebase emulators + readiness (no tests)
# Non-interactive: no Read-Host, no hardcoded device. Emulator is detected,
# never assumed. Firebase project is demo-carnama (Law: never production).

param(
    [switch]$PrepOnly,
    [string]$TestPath = 'integration_test/',
    [int]$ReadyTimeoutSec = 180,
    # Opt-in: build the emulator-lane debug APK (with the SAME dart-defines the
    # test lane uses) instead of running flutter test. For reproducible manual
    # on-device probes; the flutter test lane compiles in-process and needs no
    # separate build. Defaults to the proven x86_64 emulator lane; override.
    [switch]$BuildApk,
    [string]$TargetPlatform = 'android-x64'
)

$ErrorActionPreference = 'Stop'

# p34 T-4/R4: anchor to the member root. The test/build lanes use RELATIVE
# paths (integration_test/, bare flutter), so launching the runner from any
# other CWD used to die instantly with 'Failed to load
# <repo>\integration_test: Does not exist' (battery receipt
# green_r2_full_battery_r1_cwdred.txt). One Set-Location makes every
# invocation CWD-independent.
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host '=== Carnama Integration Test Runner ===' -ForegroundColor Cyan

# STEP 1: Detect an attached device/emulator (first row whose state is 'device')
# p34 T-4: retry with deadline - a cold or restarted adb daemon needs a few
# seconds for the emulator to re-register. The single-shot check raced it and
# reported 'no device' TWICE right after a verified boot (receipt
# green_r2_full_battery_r2_devicered.txt).
Write-Host '[1/6] Detecting device...' -ForegroundColor Yellow
$deviceRows = @()
$deviceDeadline = (Get-Date).AddSeconds([Math]::Min($ReadyTimeoutSec, 60))
do {
    $deviceRows = @((adb devices) -split "`n" | Where-Object { $_ -match "^\S+\s+device$" })
    if ($deviceRows) { break }
    Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deviceDeadline)
if (-not $deviceRows) {
    Write-Host 'ERROR: no device attached. Launch one first:' -ForegroundColor Red
    Write-Host '  flutter emulators --launch Medium_Phone_API_36.1' -ForegroundColor Red
    exit 1
}
$deviceId = (($deviceRows[0] -split '\s+')[0]).Trim()
Write-Host "PASS: device $deviceId" -ForegroundColor Green

# STEP 2: Idempotent reverse tunnels (re-running replaces the mapping; device
# side reaches host services through 127.0.0.1:8080/9099 - Law 30).
Write-Host '[2/6] adb reverse tunnels (idempotent)...' -ForegroundColor Yellow
adb reverse tcp:8080 tcp:8080 | Out-Null
adb reverse tcp:9099 tcp:9099 | Out-Null
$rules = (adb reverse --list) -join "`n"
if (($rules -notmatch 'tcp:8080') -or ($rules -notmatch 'tcp:9099')) {
    Write-Host "ERROR: tunnels missing after setup: $rules" -ForegroundColor Red
    exit 1
}
Write-Host "PASS: $rules" -ForegroundColor Green

# STEP 3: Firebase emulators - demo-carnama ONLY (production is unreachable by
# design here). Reuse an already-running instance; otherwise start one and poll
# its readiness. Exits 0 only when both ports accept TCP.
$firestoreUp = (Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -WarningAction SilentlyContinue).TcpTestSucceeded
$authUp = (Test-NetConnection -ComputerName 127.0.0.1 -Port 9099 -WarningAction SilentlyContinue).TcpTestSucceeded
$emulatorProcess = $null
if ($firestoreUp -and $authUp) {
    Write-Host '[3/6] Firebase emulators already running - reusing.' -ForegroundColor Green
} else {
    Write-Host '[3/6] Starting Firebase emulators (firestore,auth,functions / demo-carnama)...' -ForegroundColor Yellow
    $logPath = Join-Path $PSScriptRoot 'firebase_emulators.log'
    if (Test-Path $logPath) { Remove-Item $logPath -Force }
    $emulatorProcess = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList "/c cd /d `"$PSScriptRoot\..`" && firebase emulators:start --only firestore,auth,functions --project demo-carnama > `"$logPath`" 2>&1" `
        -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds($ReadyTimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if ((Test-Path $logPath) -and ((Get-Content $logPath -Raw) -match 'All emulators ready')) { break }
        if ($emulatorProcess.HasExited) { break }
    }
    $firestoreUp = (Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -WarningAction SilentlyContinue).TcpTestSucceeded
    $authUp = (Test-NetConnection -ComputerName 127.0.0.1 -Port 9099 -WarningAction SilentlyContinue).TcpTestSucceeded
    if (-not ($firestoreUp -and $authUp)) {
        Write-Host "ERROR: Firebase emulators not ready within ${ReadyTimeoutSec}s (8080=$firestoreUp 9099=$authUp). Log: $logPath" -ForegroundColor Red
        exit 1
    }
}
Write-Host 'PASS: emulators ready (firestore 8080, auth 9099).' -ForegroundColor Green

if ($PrepOnly) {
    Write-Host '=== PrepOnly done. Exit 0 ===' -ForegroundColor Cyan
    exit 0
}

# STEP 4: Optional logcat window (best-effort; never blocks the lane)
Start-Process -FilePath 'cmd.exe' -ArgumentList '/k adb logcat -s Flutter' -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null

# STEP 5: Run the integration tests on the detected device.
# STRIPE_PUBLISHABLE_KEY: debug boot guard at core_app/lib/app_bootstrap.dart:731
# asserts a non-empty value; pk_test_FAKE is the sanctioned placeholder (never
# charged - checkout_honesty_test pins that it is never USED).
# FIREBASE_ANDROID_API_KEY: core_app/lib/firebase_options.dart:75 _requireEnv
# fails CLOSED on an empty value (Law 16 - no key in source). The emulator
# suite never validates it (Firestore/Auth bind to the adb-reverse loopback),
# so the lane falls back to a documented non-secret placeholder; export
# FIREBASE_ANDROID_API_KEY in the environment to override. Same shape as the
# Stripe pk_test_FAKE precedent.
# USE_EMULATORS (plural): the consumed gate at core_app/lib/app_bootstrap.dart:635.
$androidApiKey = $env:FIREBASE_ANDROID_API_KEY
if ([string]::IsNullOrWhiteSpace($androidApiKey)) { $androidApiKey = 'emulator-lane-key-not-a-secret' }
# p34 T-1: the emulator project id the lane boots against. It is NOT a secret
# (Law 16) - the sanctioned emulator namespace - so it is safe to bundle here.
# It satisfies the --dart-define layer of the documented precedence
# (`.env -> --dart-define -> config`) that AppConfig now reads (app_config.dart
# FIREBASE_PROJECT_ID). Without it, projectId resolved to '' and the Firebase
# chain was withheld, wedging every app-boot suite (red_r2_first_run.txt).
$emulatorProjectId = $env:FIREBASE_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($emulatorProjectId)) { $emulatorProjectId = 'demo-carnama' }

# SINGLE SOURCE OF TRUTH: the emulator-lane dart-defines (per-key rationale in
# the comment block above). BOTH the opt-in -BuildApk lane and the flutter test
# lane splat the SAME array, so a hand-built emulator APK can never drift from
# the suite that runs on it — the exact defect where a keyless
# `flutter build apk --debug` cold-launch-crashed via firebase_options.dart
# _requireEnv() (Law 16 fail-closed on an empty FIREBASE_ANDROID_API_KEY).
$emulatorDartDefines = @(
    '--dart-define=USE_EMULATORS=true',
    "--dart-define=FIREBASE_ANDROID_API_KEY=$androidApiKey",
    "--dart-define=FIREBASE_PROJECT_ID=$emulatorProjectId",
    '--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_FAKE',
    # p34 T-2: app_bootstrap STEP 03 skips the ErrorWidget.builder swap under
    # this flag — the test binding fails any test whose boot leaves it
    # modified (binding.dart:1799; green_r2_admin_navfix4.txt).
    '--dart-define=INTEGRATION_TEST=true'
)

# STEP 4b (opt-in -BuildApk): build the emulator-lane debug APK with the SAME
# defines the test lane uses, then exit. Gives reproducible manual on-device
# probes without re-deriving the API key by hand (the recurring defect). Default
# OFF — never touches the existing test lane.
if ($BuildApk) {
    Write-Host "[4b] Building emulator-lane debug APK ($TargetPlatform)..." -ForegroundColor Yellow
    flutter build apk --debug --target-platform $TargetPlatform @emulatorDartDefines
    $buildExitCode = $LASTEXITCODE
    if ($buildExitCode -eq 0) {
        Write-Host 'PASS: emulator-lane debug APK built (same defines as the test lane).' -ForegroundColor Green
    } else {
        Write-Host "FAIL: APK build failed with exit code $buildExitCode" -ForegroundColor Red
    }
    exit $buildExitCode
}

Write-Host '[5/6] Running integration tests...' -ForegroundColor Yellow
# p34: --ignore-timeouts is REQUIRED for this lane. The default 12:00
# TimeoutException is the suite-LOADING timeout (build+install+driver-connect),
# which `--timeout` does NOT govern. A 197MB core_app debug APK on a software-GL
# emulator exceeds 12 min to compile, so the watchdog killed every run before a
# single test executed. `flutter test --help`: --ignore-timeouts is "useful when
# testing a big application that requires a longer time to compile (e.g. running
# integration tests)". Confirmed empirically: with it, the driver connects and
# tests run (device_rules_v13_findings.txt).
#
# NOTE: --no-dds is deliberately NOT in this lane. performance_timeline_test's
# IntegrationTestWidgetsFlutterBinding.enableTimeline needs it (red evidence:
# green_r2_full_battery_v4.txt "Failed to connect to VM Service"), but a trial
# run proved it breaks the LANE: with it the app installs+launches and then the
# driver hangs forever waiting for the VM service (green_r2_full_battery_
# final.txt — zero test progress, dart idle at 0 CPU; the app process is not
# even alive). The lane runs WITH DDS; the timeline suite is verified in an
# isolated --no-dds run instead (see p34_e2e_findings.md).
flutter test $TestPath `
    @emulatorDartDefines `
    -d $deviceId --reporter expanded --ignore-timeouts
$testExitCode = $LASTEXITCODE
if ($testExitCode -eq 0) {
    Write-Host 'PASS: All integration tests passed.' -ForegroundColor Green
} else {
    Write-Host "FAIL: Integration tests failed with exit code $testExitCode" -ForegroundColor Red
}

# STEP 6: Cleanup - only the emulators WE started; do not kill an operator's
# long-running emulator session. p34 C-fix: tunnels are LEFT IN PLACE — STEP 2
# re-creating them is idempotent, and `adb reverse --remove-all` here used to
# rip the tunnels out from under any CONCURRENT run (its okhttp calls then died
# with 'unexpected end of stream' and the suite froze: green_v13_ignoretimeout).
Write-Host '[6/6] Cleaning up...' -ForegroundColor Yellow
if ($emulatorProcess -and -not $emulatorProcess.HasExited) {
    Stop-Process -Id $emulatorProcess.Id -Force -ErrorAction SilentlyContinue
    adb reverse --remove-all | Out-Null
    Write-Host 'PASS: Firebase emulators we started are stopped (tunnels removed).' -ForegroundColor Green
} else {
    Write-Host 'PASS: emulators left running (not ours to stop); tunnels kept (idempotent).' -ForegroundColor Green
}

Write-Host ''
Write-Host "=== Done. Exit code: $testExitCode ===" -ForegroundColor Cyan
exit $testExitCode
