# WHITE-LABEL CORE-COV SPEC - PACKAGES/COVERAGE: CORE + CORE_UI SERVICES (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2 + this session's module audit (20 src modules, 51 source files, 6 test files total).**

## CORE-COV - PACKAGES/COVERAGE: CORE + CORE_UI SERVICES

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `packages/core/test/` + `packages/core_ui/test/` (new test files ONLY — the src modules are read-only unless a test finds a real bug, then fix with proof).

### Problems (verified this session — the numbers are exact)

`packages/core/lib/src/` has **20 modules / 51 source files** with services the ENTIRE app depends on (auth, payment, network retry, compliance, error logging, tax, notifications, presence). Only **6 test files** cover any of it — and 14 of 20 modules have **ZERO** direct tests:

| Module | src files | Direct tests | What it does |
|---|---|---|---|
| auth | 3 | **0** | auth_repository (RULES-2's FCM sign-out fix lives here) |
| payment | 2 | **0** | payment client-side contract |
| compliance | 2 | **0** | gdpr_service (MONEY-3/UX-3 logic) |
| analytics | 2 | **0** | analytics/telemetry (UX-4's funnel) |
| error_logger | 6 | **0** | error scrubbing + Crashlytics (UX-3's P-6) |
| notifications | 1 | **0** | FCM service |
| presence | 2 | **0** | presence lifecycle |
| cache | 2 | **0** | isar_service (STATE-4's productionization) |
| kitchen | 2 | **0** | kitchen_offline_service (PUSH-1) |
| config | 1 | **0** | core config |
| navigation | 1 | **0** | — |
| schemas | 1 | **0** | — |
| tax | 1 | **0** | — |
| utils | 1 | **0** | — |
| services | 2 | **0** | — |
| location | 1 | **0** | — |
| network | 7 | 1 | network_retry (QUEUE-2's classification) |
| admin | 2 | 1 | — |
| models | 6 | 1 | — |
| providers | 2 | 1 | — |

`packages/core_ui/lib/src/` has **17 source files** (theme engine incl. BrandColors/AppTheme, widgets, compliance copy, config copy) with **6 test files**.

### Acceptance contract
1. **Tier-1 (must test):** auth (sign-in/out, FCM token cleanup — extends RULES-2's T-1), payment (client contract, fail-closed), compliance (gdpr_service erase/export shape), error_logger (scrubPii/RedactedError — UX-3), analytics (telemetry consent gate — UX-3/UX-4), network (isRetryable classification — QUEUE-2).
2. **Tier-2 (should test):** cache (IsarService.shared lazy-open + schema-gate from STATE-4), kitchen (heartbeat scheduler empty-endpoint guard from PUSH-1), notifications (init never prompts — PUSH-2), presence, tax, models serialization round-trips.
3. **core_ui:** BrandColors fallback chain (COLOR-1), AppTheme.buildTheme config consumption (WL-1 typography guard), theme extensions.
4. All tests: pure Dart/widget tests, mocktail/fake patterns per existing suites, no emulator, no new deps.
5. Real bugs found = fix with proof + ledger entry (fail-closed).

### Tests / Gates
- New test files under `packages/core/test/` + `packages/core_ui/test/`; every module with 0 tests gets at least 1 real behavior test (Tier-1 gets full coverage).
- U-ANALYZE ×4 + U-TESTS + U-FORMAT + U-GREPS; full repo suite green; 0 skips.

### Honest residuals
- Some modules (providers glue, navigation constants) gain little from tests — record any skipped module with a one-line justification (never silent).
- Firebase-dependent classes (FirebaseMessaging.instance etc.) are tested via existing mock seams; real-device verification remains a §12 item.

**END OF CORE-COV SPEC.**