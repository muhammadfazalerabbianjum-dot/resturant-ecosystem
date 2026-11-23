# WHITE_LABEL_p03_perf3.md — PERF-3 (post-PERF-2 anomaly wave 1)

Status: PLANNED · Predecessor: PERF-2 (DONE, `d780249`) · Emulator: not required
Territory: the four anomaly classes the PERF-3 research sweep proved on the `d780249` tree
(2026-09-15). Executed per `WHITE_LABEL_BATCHES.md` §3.7.1 (ANOM batch through the standard machine).

## 1. PROVEN PROBLEMS (each verified on the current tree; commands in the research record)

| # | Problem | Proof |
|---|---|---|
| P-1 | 17 vacuous `expect(true, isTrue)` asserts (10 `telemetry_service_test.dart`, 4 `cart_provider_test.dart`, 2 `driver_location_service_test.dart`, 1 `sync_queue_auto_trigger_test.dart`) — they prove "didn't crash", nothing else. The REAL telemetry consent-gate proof (`TelemetryService.forTest` seam, W9.8 T-1) already exists elsewhere, so the vacuous ones are redundant shells. | grep sweep 2026-09-15; `telemetry_service.dart:35-44` (forTest seam) |
| P-2 | Dead duplicate admin-PIN config surface: `app_config.dart:66,135,270-272,421` parse/hold `devAdminPin` with **zero consumers** — the real gate is `AdminAccessService` (dart-define `ADMIN_PIN` in debug / Remote Config `admin_pin` in release, both fail-closed). A future dev could mistake the dead surface for a working PIN path. | grep: only definition sites, no reads |
| P-3 | `test/e2e/**` (2 files, 5 tests, real assertions) runs **nowhere in CI**: path-excluded by `test/dart_test.yaml` in the standard tier, and untagged so Tier 7's `--tags needs-emulator` skips them too. (They pass standalone — proven `+17 All tests passed!`.) | CI Tier 7 command vs file headers |
| P-4 | **AMENDED DURING EXECUTION (pre-edit re-verification falsified the original finding):** "ForceUpdateGuard dormant, no checker, English-only" described `packages/core_ui/lib/src/config/force_update_guard.dart` — a **DEAD duplicate**. The production guard is the core_app-local copy (`core_app/lib/app/config/force_update_guard.dart`, imported at `app_bootstrap.dart:58`; core_ui's is `hide`d at :38), fully wired via `forceUpdateStatusProvider` → `ForceUpdateService.activate()+check()` (Remote Config; version compare `force_update_service.dart:66`), fail-open by contract, LOCALIZED (`loc.updateRequired`/`loc.forceUpdateBody`), brand-driven, covered by 3 test files. The dead copy's `ForceUpdateChecker`/`_FailOpenForceUpdateChecker` have ZERO external references and no tests; core_ui's only `url_launcher` use is this file. A dead duplicate of a security-adjacent surface is the P-2 hazard class. | grep: self-references only; `app_bootstrap.dart:38,58,721`; `force_update_guard.dart:57-72` (live) |

Non-goals (recorded, each with a named home — nothing dies in a footnote):
- CF deployment → PERF-4 + operator runbook (code+tests exist and pass 75/75 at `d780249`).
- UI layout-variant system → PERF-5 proposal.
- ~~Force-update lock screen English-only copy~~ **SUPERSEDED**: the live core_app lock screen IS localized (`loc.updateRequired`/`loc.forceUpdateBody`); the English-only copy belonged to the dead duplicate T-4 deletes. Accepted residual instead: core_ui's `url_launcher` dep becomes unused after T-4 (left in place — a pubspec/lock change is outside this batch's territory and risks version churn).
- core_app code-only coverage 79.97% (2 lines shy of 80) → operator-accepted at PERF-2 close (aggregate mode is the Law 48 metric; all four packages ≥ 80% proven 2026-09-15).
- Reactive badge-stream deterministic harness (open PERF-1 handoff, `FIX_VERIFICATION.md:5090`) → the streams are already exercised by the QUEUE-1 DLQ widget suite through the same provider graph; the deterministic-coverage harness defers to the §3.7.1 ANOM harvest, which mechanically sweeps handoff lines into batches.

## 2. ACCEPTANCE CONTRACT

1. Zero `expect(true` in `core_app/test/**` — every replaced with a behavioral assertion (consent-gate short-circuit via `forTest` + FakeFirebaseFirestore; cart state transitions; driver-tracking observable state; queue-trigger op count).
2. `app_config.dart` exposes no PIN surface; a drift-guard test asserts the `devAdminPin` symbol is gone (source-scan: read `lib/app/config/app_config.dart` and expect zero matches — the `checkout_honesty_test.dart` file-reading precedent; Dart mirrors are unavailable); `AdminAccessService` remains the single PIN authority (its tests stay green).
3. Both `test/e2e/*.dart` files carry `@Tags(['needs-emulator'])` and pass under `flutter test --tags needs-emulator` locally (proving CI Tier 7 now executes them).
4. The dead duplicate `packages/core_ui/lib/src/config/force_update_guard.dart` is DELETED (any barrel export removed with it); a drift-guard test in `packages/core_ui/test` asserts the package source contains no `ForceUpdateGuard`/`ForceUpdateChecker` symbol; the LIVE core_app guard and its 3 test files stay green (untouched).
5. Gate Set U green (analyze `--fatal-infos` core_app + packages touched, format 0-changed, full `flutter test --coverage`, 0 skip/TODO) + per-package coverage floors ≥ 80% + `npm test` in `core_app/functions` exit 0 (regression guard on untouched money code).
6. Addendum appended to `FIX_VERIFICATION.md` with before/after per file and honest residuals.

## 3. T-x TABLE

| T-x | Action | Files |
|---|---|---|
| T-1 | Rewrite 17 vacuous asserts as behavioral proofs (P-1) | `test/core/analytics/telemetry_service_test.dart`, `test/features/cart/presentation/cart_provider_test.dart`, `test/features/tracking/data/driver_location_service_test.dart`, `test/app/sync_queue_auto_trigger_test.dart` |
| T-2 | Delete dead `devAdminPin` surface + drift-guard test (P-2) | `lib/app/config/app_config.dart`, new `test/app/config/app_config_no_pin_test.dart` |
| T-3 | Tag e2e files `needs-emulator` (P-3) | `test/e2e/checkout_e2e_test.dart`, `test/e2e/reservation_e2e_test.dart` |
| T-4 | Delete the dead core_ui guard duplicate + drift-guard test (P-4 amended) | delete `packages/core_ui/lib/src/config/force_update_guard.dart`; `packages/core_ui/lib/core_ui.dart` (export line only, if present); new `packages/core_ui/test/config/no_dead_force_update_guard_test.dart` |
| T-5 | One-line stale-comment fix (the file's assertions are real and passing); one-line disposition comment for the font-manifest test notice (proven benign — the graceful fallback at `app_theme.dart:232`, `_fontManifestFailed` flag) | `test/core/theme/app_dimensions_test.dart`, `test/flutter_test_config.dart` (comment only) |

## 4. PROOF GATES
`flutter analyze --fatal-infos` (core_app, packages/core) · `dart analyze` (packages touched) · `dart format --output=none --set-exit-if-changed .` · `flutter test --coverage` (all four packages, floors ≥80%) · `grep expect(true` → 0 · `npm test` (functions) exit 0 · e2e under `--tags needs-emulator`.

## 5. FOLLOW-ON BATCHES (proposed, one per session)
- **PERF-4** — CF deploy lane: CI job for `npm run lint && npm test` + deploy runbook (Blaze, `stripe.secret_key` in functions env, App Check enforcement) — the O-gate row's operator half.
- **PERF-5** — UI variant system: validated config vocab (`screens.<name>Variant`) → screen-variant registry in the shared body (extends the TOKENS pattern); enables two clients with structurally different screens from config alone.
