# CARNAMA LABS — TESTING, RELEASE ENGINEERING & CI AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify test integrity, CI gates, build
pipeline, signing/versioning, release safety nets (force-update), and the ABSENT iOS platform
in the Carnama Labs template (`core_app`) and domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Tests pass" must mean the suite that RUNS is
   meaningful — skipped tests, empty tests, and mock-only suites are FINDINGS.
3. **No hallucination.** Every claim cites `file:line` or command output.
4. **Completeness.** Every test file, every CI step, every build config. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** The UI wiring audit found router tests do NOT exercise
   config mode while the app RUNS config mode — that class of blind spot is the target here.

---

## 1. SCOPE

### 1.1 Test Suite Integrity (the anti-hallucination gate)

**Files to audit:**
- `core_app/test/**` and `packages/core/test/**` — EVERY test file
- `pubspec.yaml` dev_dependencies (flutter_test, mocktail/mockito, integration_test)
- Any `dart_test.yaml` / test configuration

**Verify:**
- [ ] Run `flutter test` (both packages) — capture pass/fail/skip counts. Any SKIP = FINDING
  with file:line and justification verdict (a skip without a linked issue = P1)
- [ ] List every test that asserts NOTHING (no expect/matchesGoldenFile) = dead test
- [ ] Router tests: do they exercise CONFIG MODE (the mode main.dart actually uses)? The UI
  wiring audit says NO — verify, then list which navigation paths have ZERO coverage
- [ ] Deep-link tests: cold-start AND warm-start? invalid paths? unauthorized role paths?
- [ ] Golden/widget tests: which screens have ANY widget test? Produce the screen × test
  matrix (all 33 screens from the UI wiring audit)
- [ ] Cloud Function mocks (`cloud_function_mocks.dart`): do mocks match the REAL functions'
  request/response shapes? (mock drift = tests prove nothing about production)
- [ ] Does any test cover sync-queue retry/DLQ behavior? payment idempotency? tax math?
  operating-hours timezone logic? List domain logic with NO test coverage

### 1.2 CI Gates & Quality Automation

**Files to audit:**
- Any CI config: `.github/workflows/**`, `codemagic.yaml`, `bitrise.yml`, scripts at repo root
- `core_app/analysis_options.yaml`, `packages/*/analysis_options.yaml`

**Verify:**
- [ ] If NO CI exists: P0 finding with a minimal-gate proposal (analyze + test + config-schema
  check + build) — do not invent files, document absence
- [ ] If CI exists: every step enumerated; does it run BOTH packages? enforce `--fatal-infos`?
  block on test failure? upload coverage?
- [ ] Lint rules: current `analysis_options.yaml` contents — flutter_lints version, any
  `// ignore:` comment abuse (grep and list every suppression with verdict)
- [ ] `flutter analyze --fatal-infos` current output: 0 issues or list them (the UI wiring
  audit's run showed 122 pre-existing infos/warnings — capture the CURRENT state)
- [ ] Format check (`dart format --set-exit-if-changed .`) in gates?
- [ ] Config-schema validation gate: does ANY automated step validate `client_config.json`
  files against expected keys/types? (UI wiring audit P0-1 root cause — this gate would
  have caught it)

### 1.3 Build & Release Engineering

**Files to audit:**
- `core_app/android/app/build.gradle*` (applicationId, versioning, signing, minSdk/targetSdk)
- `apps/halal_boyz/**` build configs (what overrides the template?)
- iOS: CONFIRM the ios/ folder is ABSENT — document as P0 for App Store releases, enumerate
  everything missing (Runner project, Info.plist permissions, entitlements, privacy manifest,
  icons, signing)
- `core_app/lib/app/config/force_update_guard.dart` + `minimumVersion` config plumbing
- Flavor/dart-define strategy per client (how does halal_boyz get its bundle ID?)

**Verify:**
- [ ] Versioning: strategy (manual pubspec vs CI-injected); can two client apps version
  independently?
- [ ] Signing: keystore/provisioning present? gitignored? any secret committed to the repo
  (grep for base64 blobs / password strings in build files)
- [ ] `minSdk`/`targetSdk`/`compileSdk` vs plugin minimums (isar, geolocator, firebase) —
  document actual values and compatibility
- [ ] R8/ProGuard rules for release; `--obfuscate` + `--split-debug-info` documented anywhere?
- [ ] Force-update guard: enforced BEFORE any API call? bypass flag for dev? what happens if
  the version endpoint is unreachable (fail-open = FINDING)?
- [ ] Release build installable? (attempt a release-variant build only if permitted; otherwise
  mark NOT PROVEN)
- [ ] App size budget: measure release APK; flag anomalies (unused template assets)

### 1.4 Operational Safety Nets

**Files to audit:**
- Crashlytics init in `main.dart` (ZonesErrorHandler + FirebaseAnalyticsObserver confirmed)
- Any remote logging/feature-flag service
- `packages/core/lib/src/network/chaos_firestore.dart` (chaos testing — used in CI or dead?)

**Verify:**
- [ ] Crashlytics: dSYM upload story for iOS (absent iOS = blocked), PII scrubbing
- [ ] Error breadcrumbs: do caught exceptions (log + rethrow pattern) reach Crashlytics with
  context (screen name, orderId)? verify `FirebaseCrashlytics.recordError` call sites
- [ ] Chaos Firestore: wired into tests/CI or dead code? verdict with citations
- [ ] Staged rollout story: any docs/scripts for percentage rollout, rollback plan?
- [ ] Backend contract tests: are app-side models verified against live Functions in any
  environment (staging)? absence = FINDING for the ops risk list
- [ ] Analytics funnel: order events (checkout_started, order_placed, order_failed, payment
  events) instrumented with parameters — list every `logEvent`/`FirebaseAnalytics` call site;
  if NONE exists, P1 finding (conversion cannot be measured)
- [ ] Screen-view tracking strategy documented (manual vs `FirebaseAnalyticsObserver`) and
  applied consistently; per-client separation possible for white-label reporting

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). Include: (a) screen × test coverage matrix, (b) complete SKIP/dead-test list,
(c) CI step-by-step as-is state, (d) iOS absence impact list.

**Report ONLY. No code changes. No fixes.** Running `flutter test` / `flutter analyze` IS
permitted and required (read-only commands); building installers is NOT required.

---

## 3. PROMPT SELF-CHECK before submission

- [ ] Test run output captured (counts, not impressions)?
- [ ] Every skipped/dead test itemized?
- [ ] CI presence/absence established with directory evidence?
- [ ] iOS absence impact fully enumerated (permissions, signing, privacy manifest, dSYMs)?
- [ ] Every release-safety claim (force update, crashlytics) proven at call sites?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.** Running `flutter test` / `flutter analyze` IS
permitted and required (read-only commands); building installers is NOT required.

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**