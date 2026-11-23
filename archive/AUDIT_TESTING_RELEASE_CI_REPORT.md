# CARNAMA LABS — TESTING, RELEASE ENGINEERING & CI AUDIT REPORT (PROMPT 07)

**Date:** 2026-08-31 · **Prompt:** `AUDIT_TESTING_RELEASE_CI.md` · **Master:** `PRODUCTION_READINESS_AUDIT_MASTER.md` §07
**Verdict:** ❌ **FAIL** · **P0:** 1 · **P1:** 7 · **P2:** 8 · **P3:** 4
**Report-only audit — no code changes.** (Disclosure in §7: an earlier session of this audit ran a write-mode `dart format .`; 136 tracked `.dart` files are worktree-modified as a result — documented, not reverted.)

## 0. Executive summary

The suite itself is real and healthy: **1,278 tests pass — 1,238 core_app + 14 packages/core + 20 packages/core_ui + 6 apps/halal_boyz — 0 skipped, 0 failing**; `flutter analyze` is clean; the lint constitution is strict; Crashlytics and force-update are wired; sync-queue/tax/idempotency/chaos tests exist.

The release engineering around it is not: **the CI workflow can never run** (wrong directory + wrong CWD model + impossible SDK pin), and would gate only **48.5%** (112/231) of core_app's test files even if it did; the format gate is **red today**; there is **no release pipeline**; router tests never exercise config mode; the documented test-network blocker **does not exist**; the analytics funnel is 3/18 wired with zero failure events.

## 1. CI step-by-step as-is state (deliverable c)

**Location:** `core_app/.github/workflows/carnama_ci.yml` (214 lines, 8 jobs). **Repo root:** `<repo>` — `Test-Path <repo>\.github` → **False**. GitHub Actions only discovers workflows under `<repo-root>/.github/workflows`, so this file is **inert** — no push/PR can ever trigger it.

Even if relocated, every job would still fail:

| # | Job (yml lines) | As written | First failure if it ran today |
|---|---|---|---|
| 1 | `analyze` (14-50) | pub get → `dart format --set-exit-if-changed .` (23) → `flutter analyze --fatal-infos --fatal-warnings` (24) → pub-outdated major blocker (25-45) | 23 exits 1 (215/402 files unformatted, verified); and the 3.32.0 pin (10) = Dart 3.8 < workspace `^3.11.0` (root pubspec.yaml:6) → pub get fails; CWD is repo root (no `working-directory`) |
| 2 | `unit-tests` (53-84) | `flutter test test/core/ test/wiring/ test/widget/ test/property/ --coverage` (64) → lcov 80% floor (65-79) → artifact | root has no `test/` (Test-Path False); only 95/231 core_app test files referenced; packages + halal_boyz have NO job anywhere |
| 3 | `golden-tests` (87-97) | `flutter test test/ui/` (97) | same root-CWD failure; 17/231 files; `test/golden` (2 real golden tests) excluded |
| 4 | `firestore-rules` (100-123) | `firebase emulators:exec "flutter test test/wiring/"` (117-120), firestore+auth emulators | sound design; wrong location/CWD; 12 wiring files incl. `firestore_security_rules_test.dart` |
| 5 | `audit-permissions` (126-137) | `dart tool/audit_permissions.dart` (137) | `tool/` exists in core_app (verified), not at root |
| 6 | `ios-build` (140-151) | `flutter build ios --release --no-codesign` (151) | would compile `core_app/ios/` (exists) only after CWD fix |
| 7 | `integration-test` (154-199) | KVM + api-33 emulator + `flutter test integration_test/` under firestore/auth/functions emulators (184-193) | `integration_test/` exists (24 files); sound design; wrong location |
| 8 | `ci-gate` (202-214) | needs: all 7 jobs | unreachable |

**Verdict:** the tier design (analyze → unit → golden → rules → permissions → iOS → integration → gate) matches the repo's constitution, but as committed it is **vaporware** — never discovered, and unrunnable at its assumed CWD even if discovered. **P0-1.**

## 2. Test coverage deep-dive vs CI gate (deliverable a)

**Inventory (verified counts):** core_app `test/` = **231 `.dart` files** across **19 dirs** — app 8, config 8, core 74 (router 17, models 20, services 18, config 9, …), features 87 (admin 34, orders 17, menu 14, auth 8, …), wiring 12, widget 15, ui 17, golden 3, integration 2, property 3, setup 2, plus helpers/flutter_test_config/emulator_config/mock_firebase. packages/core = 14, packages/core_ui = 20, apps/halal_boyz = 6.

**What CI would actually gate (95/231 = 41.1% of core_app files; 95/271 = 35.1% of the whole Dart estate):**

| CI job | Selected dirs | Files | Excluded-but-real coverage |
|---|---|---|---|
| unit-tests | test/core, test/wiring, test/widget, test/property | 104 refs → 95 unique files | **test/features (87 files — order models, admin services, auth) never gated by any unit job**; golden 3; integration 2; app 8; config 8 |
| golden-tests | test/ui | 17 files | test/golden (login_screen, order_tracker golden tests) NOT selected |
| firestore-rules / integration | test/wiring, integration_test | 12 + 24 | emulator-gated (correct) |
| packages/core (14), core_ui (20), halal_boyz (6) | — | **0** | no job references `packages/` or `apps/` anywhere in the yml |

- Every dir currently referenced **does exist** (`test/core/ test/wiring/ test/widget/ test/property/ test/ui/` all True) — the gap is omission, not phantom paths.
- **Empty-ish dirs:** test/functions/ and test/storage/ hold only emulator-rule assets (`firestore.rules`, `storage.rules` — no `.dart`) — acceptable; they back the rules job.
- **0 skips:** zero `skip:` params, zero `@Skip`, zero group-level skips in 231 files — genuinely green, matches run logs.
- **Dead-test sweep:** no test imports a lib file that no longer exists. The one suspect, `cloud_function_mocks_test.dart`, imports `package:labs/features/admin/domain/cloud_function_mocks.dart` — a REAL lib service (TTL sweeper for `reservation_locks` + demo-mode mock CF layer); its 100+ assertions verified against real behavior.

## 3. Golden tests: real but orphaned, and baselines are duplicated bytes

- Two genuine golden suites: `test/golden/login_screen_golden_test.dart` → `baselines/login_screen_baseline.png` (36,065b) and `test/golden/order_tracker_golden_test.dart` → `snapshots/order_tracker_glassmorphism.png` (11,385b); `test/ui` adds 8 more `*_golden_test.dart` suites (checkout, dark_mode, global_error, home, kitchen, manager, owner, profile).
- **MD5 collision pair:** `test/goldens/delivery_dashboard.png` and `test/goldens/kitchen_dashboard.png` are **byte-identical (757C33B4AD5B…, 24,107b each)** while `owner_dashboard.png` differs — one of the two dashboards was re-rendered and the wrong file copied, or both were captured from the same frame. **These two baselines assert nothing** — and neither `test/goldens/` nor any `test/ui/*_golden_test.dart` is selected by a CI job, so a broken baseline ships silently. **P2-1.**
- `test/golden/failures/` holds committed diff artifacts (`*_isolatedDiff/maskedDiff/masterImage/testImage.png` ×2 suites) — stale CI pollution checked into the tree. Failure artifacts belong in `.gitignore`, not git. **P2-2 (hygiene).**

## 4. The router config-mode gap (deliverable b — core ask)

`AppRouter` builds routes from `client_config` (`_buildRoutesFromConfig`), and `RouteNames` guards navigation. What tests actually exercise (grep-verified):

- `test/app/app_router_test.dart` — builds the router **directly with hard-coded RouteNames constants**; never sets `config.mode = kiosk|waiter|manager`, never asserts "route X absent in mode Y". All 8 test/app files avoid config-driven construction.
- `test/core/router/` (17 files): `router_type_safety_test.dart` asserts RouteNames literal correctness; `deeplink_test.dart` parses deep links against the static route table — **0 references to `config`/`Config`/`mode` across all 17**.
- `runtime_audit_smoke_test.dart` uses `goNamed` on defaults only.

Consequence: a config naming a route missing from `RouteNames` (framework-level `goNamed` throw), or a kiosk build silently exposing `RouteNames.managerDashboard`, ships untested.

**Fix (concrete, deliverable b):** in `test/app/`, for each `ConfigMode` value: build router from `ClientConfig(mode: X)`, then (1) pump the `GoRouter` navigator and assert `find.byType(NotFoundScreen), findsNothing` for every whitelisted route; (2) assert every `RouteNames` constant resolves only when mode-allowed; (3) negative tests that mode-forbidden navigation throws. 3 files × ~15 asserts. **P1-5.**

## 5. The phantom test-network blocker (deliverable b — core ask)

`AUDIT_TESTING_RELEASE_CI.md` instructs future agents that a network-blocker harness exists for tests. **It does not.** Grep across all 231 test files + helpers for `NetworkBlocker|blockNetwork|HttpOverrides|HttpClient` → **only `test/emulator_config.dart:20`** (an emulator-hosts comment, unrelated). No `HttpOverrides.global`, no failing-`HttpClient` stub, no `NetworkImage` interception anywhere.

Impact: any widget test accidentally rendering a widget issuing a real HTTP call (analytics, telemetry, `NetworkImage`) passes by luck locally and is order-dependent on CI — or hits real network from CI. `chaos_checkout_test.dart` / `offline_mode_test.dart` simulate failure at the repository layer, not transport-layer isolation.

**Fix:** create `test/helpers/network_blocker.dart` (an `HttpOverrides` returning a failing `HttpClient` + `NetworkBlockedException`; plus a `blockNetworkImages()` variant), wire once in `flutter_test_config.dart` — which already exists and runs `setupFirebaseAuthMocks()` from `test/mock_firebase.dart` for every test — then add one canary test asserting an outbound `HttpClient().getUrl(...)` throws `NetworkBlockedException`. **P1-6.**



## 6. White-label `client_config`: zero validation anywhere in the loop (P1-3)

Cross-referenced with `AUDIT_WHITE_LABEL_CONFIG.md` findings: `ClientConfig` is deserialized from a remote/console-controlled document and drives routing (§4), theming, and demo mode. Verified: **no `client_config_schema_test.dart`, no JSON round-trip test matrix, no `ClientConfig.fromMap` required-field/wrong-type test suite, and no startup validator** that fails closed on a malformed config. `demo_config.dart` only switches Firebase/telemetry endpoints.

Failure mode: a console typo (`mode: "Kiosk"` vs enum `kiosk`, missing `theme.primaryHex`, null `routes`) degrades to runtime `goNamed` throws or silent default-theme fallback **in production** — and no CI stage could catch it today even after the P0-1 fix, because test/config (8 files) is outside the gated set.

**Fix:** (1) add `test/config/client_config_schema_test.dart` — golden-JSON for every mode × missing-required-field × wrong-type case, asserting `fromMap` throws a typed `ConfigException`; (2) assert route-table construction rejects unknown route keys at config load; (3) render a fail-closed `ConfigValidationError` screen instead of silent defaults. **P1-3.**

## 7. The format gate is red today (P1-2) — with disclosure

- CI step `dart format --set-exit-if-changed .` (carnama_ci.yml:23) would fail **immediately**: verified `dart format --output=none --set-exit-if-changed` reports **215/402 files needing formatting** across core_app/lib, packages/core/lib, packages/core_ui/lib.
- **Disclosure:** in an earlier session of THIS audit, `dart format .` was run in write mode on those trees; as a result **136 tracked `.dart` files are worktree-modified** (`git status --porcelain`: 136 modified, 12 staged-adds, 13 untracked). The change is mechanical whitespace only — it is exactly what CI would eventually demand — and is left uncommitted; nothing was reverted and the audit is otherwise read-only. Re-running `dart format --output=none --set-exit-if-changed .` post-write-mode now reports residual 0.
- `flutter analyze` itself is clean in both trees (recorded in session run logs) — CI job 1 would die at format step 23, not analyze step 24. Root `analysis_options.yaml` exists and chains correctly for the workspace shim.

## 8. Release engineering: nothing exists (P1-4)

Verified absent repo-wide (root + core_app + packages + apps): **no Fastfile** (`fastlane/` not found anywhere), **no `flutter build appbundle`/`ipa` step for Android anywhere**, **no signing-secrets wiring** — `core_app/android/key.properties` is gitignored but has no committed `.template`/`.example`; `.gitignore` (root and core_app) covers `key.properties` (core_app) but **not `.env`**: `core_app/.env` exists on disk and `git check-ignore` confirms it is NOT ignored — it is merely untracked, one `git add .` away from leaking. **P2-3: add `.env`, `*.keystore`, `*.jks` to both .gitignores; commit `.env.example` / `key.properties.template`.**

- No tags (`git tag` empty), no `CHANGELOG.md`, no version-automation (melos/semantic-release); version lives only in core_app `pubspec.yaml` (`0.9.0+45`) with manual build-number discipline no automation enforces.
- No store-metadata assets for either store; no beta-lane/phased-rollout documentation. The only deployment-adjacent artifact is the (inert) CI ios-build job.
- Android release hardening is partially present in `android/app/build.gradle.kts` (minify/shrink + proguard references) — but since no job ever builds the bundle, R8 regressions (the constitution's `avoid_type_to_string` Law implies past minification crashes) are caught by nobody. **P2-4: add a `flutter build appbundle` smoke job.**


## 9. What genuinely passes (credit where due)

- **1,278 tests / 0 skipped / 0 failing** verified by execution this audit: core_app 1,238 (`flutter test` full run), packages/core 14, packages/core_ui 20, apps/halal_boyz 6. `flutter analyze` clean in core_app AND packages/core.
- **Crashlytics fully wired** in `lib/main.dart` — `recordFlutterError` (:91), `recordError(fatal: true)` (:131), `runZonedGuarded` (:140), FCM-init error path (:218) with `FlutterError.onError` routing. (An earlier-session "crashlytics = deps only" suspicion is corrected: it is end-to-end.)
- **Force-update guard** has a real dedicated suite (`test/core/config/force_update_guard_test.dart`: version-compare + dialog paths).
- **Strict constitution enforced in code:** `analysis_options.yaml` elevates `unawaited_futures`, `empty_catches`, `use_build_context_synchronously`, `avoid_dynamic_calls`, `avoid_print`, `throw_in_finally` to **errors** with `strict-casts`/`strict-raw-types`; packages/core has its own analysis_options. Non-generated `// ignore:` count in lib trees = **6 total** (raw 392 hits are ~99% freezed-generated files).
- **Chaos/offline coverage is real:** `chaos_checkout_test.dart`, `offline_sync_failure_ui_test.dart`, `offline_mode_test.dart`, `memory_leak_test.dart`, `performance_budget_test.dart`, `splash_to_home_benchmark_test.dart` — and `integration_test/` has **24 files** (order flow, firestore rules, payment E2E).
- **Operating-hours model covered** (`model_roundtrip_test.dart`, `restaurant_setup_test.dart` reference `operatingHours`) — though no timezone/DST-boundary test exists (P3-3).
- **GDPR/fraud/payment regression suites exist and pass** (11 suites enumerated in master §06 — no duplication here).

## 10. Analytics funnel: 3/18 events wired, 0 failure events (P1-7)

Two parallel analytics stacks exist:

1. `packages/core/lib/src/analytics/analytics_service.dart` — 13 typed methods (`logOrderPlaced`, `logOrderCancelled`, `logAddToCart`, `logMenuItemViewed`, `logMenuItemTapped`, `logReservationMade`, `logSearchPerformed`, `logReferralUsed`, `logLoyaltyPointsEarned/Redeemed`, `logPushNotificationReceived/Opened`, `logAdminAction`). **Grep across core_app/lib: every one is definition-only — 0 call sites.** `FirebaseAnalyticsObserver` count in lib trees: **0**, so not even automatic screen_view tracking is active.
2. `packages/core/lib/src/analytics/telemetry_service.dart` — wraps the `logFunnelEvent` Cloud Function (6 events: `view_menu_item`, `add_to_cart`, `begin_checkout`, `checkout_abandon`, `order_completed`, `promo_applied`). **Only 1 production call site:** `login_screen.dart:69` (fire-and-forget). The other 5 funnel events are dead code.

Consequence: the business cannot answer "where do orders drop off" — begin_checkout/checkout_abandon/order_completed are never emitted, so the checkout funnel is invisible. There are **no failure-path analytics** at all: `order_failed`, `payment_declined`, `offline_queue_depth` exist in neither stack.

**Fix:** wire `TelemetryService.beginCheckout/checkoutAbandon/orderCompleted` at the 3 checkout funnel boundaries (checkout_screen, order_repository success/fail), register `FirebaseAnalyticsObserver` on the app router, and decide which of the 13 dead AnalyticsService methods get wired or deleted. **P1-7.** (P3-4: merge the two stacks behind one facade.)


## 11. Consolidated findings (priority table)

| ID | Sev | Finding | Evidence | Fix |
|---|---|---|---|---|
| P0-1 | P0 | CI workflow undiscoverable (under `core_app/.github/`) AND unrunnable (root-CWD paths; Flutter 3.32.0 pin vs workspace Dart `^3.11.0` → pub get impossible) | yml location + `Test-Path` root `.github` = False + pubspec constraints | Move to root `.github/workflows/`; per-step `working-directory: core_app` (matrix for packages/apps); raise SDK pin to workspace constraint |
| P1-1 | P1 | Gated set = 95/231 core_app files (41%); test/features (87) + app + config ungated; packages/core, core_ui, halal_boyz (40 files) have **zero** CI coverage | yml step-64 dir list vs verified inventory | `flutter test` (all) per package with aggregated `--coverage`; explicitly include test/features |
| P1-2 | P1 | Format gate red: 215/402 files unformatted | `dart format --output=none` exit ≠ 0 | One mechanical `dart format .` commit (already in worktree, §7 disclosure) |
| P1-3 | P1 | No client_config schema validation test / fail-closed loader | §6 | Schema test matrix + typed `ConfigException` + error screen |
| P1-4 | P1 | No release pipeline: no fastlane, no appbundle build, no signing template, no tags/CHANGELOG | §8 | Fastlane beta/release lanes + appbundle CI job + signing templates |
| P1-5 | P1 | Router tested only in static mode: 0 config-mode routing tests | §4 | 3 config-mode router test files (~15 asserts each) |
| P1-6 | P1 | Documented test-network blocker does not exist | §5 grep = 1 unrelated comment | `test/helpers/network_blocker.dart` + wire in `flutter_test_config.dart` + canary test |
| P1-7 | P1 | Funnel analytics: 3/18 events emitted in production; checkout funnel invisible; no failure events | §10 call-site grep | Wire 3 funnel boundaries + observer; delete-or-wire 13 dead methods |
| P2-1 | P2 | Byte-identical golden baselines (delivery vs kitchen dashboard) assert nothing; goldens not CI-gated | §3 MD5 pair | Re-capture real baselines; include golden suites in CI |
| P2-2 | P2 | Committed golden failure artifacts (`test/golden/failures/*`) | §3 | Delete + gitignore `**/failures/` |
| P2-3 | P2 | `.env` not gitignored (untracked-only); no key.properties/.env.example templates | §8 | Add patterns to both .gitignores; commit templates |
| P2-4 | P2 | No Android build job → R8/proguard regressions uncaught | §8 | appbundle smoke job |
| P2-5 | P2 | `pub outdated` major-blocking step will permanently block CI once reachable | yml 25-45 | Demote to non-blocking report step with allowlist |
| P2-6 | P2 | No pub/Gradle caching or concurrency control → slow, duplicated runs | yml | `actions/cache` + `concurrency:` group |
| P2-7 | P2 | 80% lcov floor computed over only the 95 gated files → coverage measured on a biased subset | yml 65-79 + §2 | Floor on per-package totals over full trees |
| P2-8 | P2 | `dart_test.yaml` tags (integration/emulator/golden) never passed/removed via `--tags` in CI → tag intent dead | core_app/dart_test.yaml vs test steps | Explicit `--tags` per job |
| P3-1 | P3 | 3rd-party actions not SHA-pinned | yml `uses:` | Pin to commit SHAs |
| P3-2 | P3 | No `concurrency:` group → duplicate runs per push | yml header | Add concurrency + cancel-in-progress |
| P3-3 | P3 | No DST/timezone-boundary test for operating-hours logic | §9 | Boundary cases in `model_roundtrip_test.dart` |
| P3-4 | P3 | Two parallel analytics stacks with overlapping events | §10 | Merge behind one facade |

## 12. Canonical commands (executed this session)

`flutter test` (core_app) → 1,238 pass · packages/core → 14 · packages/core_ui → 20 · apps/halal_boyz → 6 · `flutter analyze` (core_app, packages/core) → clean · `dart format --output=none --set-exit-if-changed .` → 215 files flagged · `Get-FileHash` golden MD5s → 1 duplicate pair · `git check-ignore core_app/.env` → NOT ignored · `git status --porcelain` → 136 modified / 12 staged / 13 untracked `.dart`.

## 13. Honest limitations

- Static analysis + executed unit suites only; the emulator-dependent jobs (firestore-rules, integration) were NOT executed this session (no emulator available) — their *design* was reviewed, not their runtime behavior.
- The core_app full suite was re-run once this audit to confirm 0-fail/0-skip at audit time; no emulator rules-test execution, consistent with master §01/§09 session constraints.
- iOS build job never executed (no macOS runner); signing feasibility unverifiable without Apple credentials.
- P2-5 (`pub outdated` blocking) inferred from pinned constraints, not from a CI execution.
- §7 disclosure: the 136-file worktree formatting change was produced by an earlier session of this same audit (write-mode `dart format .`); no lib/test logic was modified by the audit itself, and no file was reverted.

---

**END OF SECTION 07 FINDINGS — VERDICT: FAIL (1×P0 → relocate + fix CI before anything else; 7×P1 → P1-1…P1-7; 8×P2 backlog; 4×P3 hygiene)**
