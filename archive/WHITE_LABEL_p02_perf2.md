# WHITE-LABEL PERF-2 SPEC - PERFECTION: CORE_APP COVERAGE CAMPAIGN → 80% AGGREGATE (MEASURED)

**Read `WHITE_LABEL_BATCHES.md` FIRST.** **Predecessor:** PERF-1. **Emulator-gated:** no. **Status: MEASURED — the gap map below is from a fresh `flutter test --coverage` run at main `39a709e` (+1701 passed), lcov parsed per directory.**

## The measured gap map (core_app: 5857/9069 = 64.58%)

| Dir | Hit/Total | % | Uncovered |
|---|---|---|---|
| **app_bootstrap.dart** | 37/209 | **17.7** | **172** ← ARCH-2's own init chain, barely tested |
| **l10n (generated)** | 387/1467 | **26.4** | 1080 — cover via the l10n PARITY suite (below), not bare touches |
| features/driver | 39/89 | 43.8 | 50 |
| features/loyalty | 51/90 | 56.7 | 39 |
| **features/checkout** | 351/613 | 57.3 | **262** |
| features/orders | 194/295 | 65.8 | 101 |
| features/menu | 378/539 | 70.1 | 161 |
| **features/admin** | 1882/2620 | 71.8 | **738** |
| features/reservations | 256/356 | 71.9 | 100 |
| features/cart | 253/337 | 75.1 | 84 |
| app | 698/866 | 80.6 | — |
| features/auth | 328/406 | 80.8 | — |
| features/{location,tracking,home,locations,compliance,splash,waitlist,onboarding,tour} | — | 78–100 | small |

## The honest math
Aggregate after PERF-1 ≈ 7717/11401 = **67.7%**. 80% aggregate = 9121 covered ⇒ **core_app must reach 7255/9069 ⇒ +1398 covered lines**. Both accounting modes are tracked in every session addendum: (a) including generated `l10n` (the 80% target), (b) code-only excluding generated (7602 lines → 80% = 6082 ⇒ +612 — the conservative floor if (a)'s parity suite under-delivers).

## The 4-session plan (bounded, per the decision gate)
- **S1 — app_bootstrap (172) + small dirs (driver 33, loyalty 21, orders 42):** the 16-step init chain is highly failable (boot completer, zone guards, fail-closed gates) — test its states with the established fake seams; ≈ +268 → ~70.6% aggregate.
- **S2 — checkout (139) + admin (214):** the two biggest feature masses; existing suite patterns (COV-5 integration shape) extend; ≈ +353 → ~74%.
- **S3 — l10n PARITY suite (target ≈ +800 of 1080):** a REAL regression guard, not gaming: every getter returns a non-empty string for BOTH en and ar; key-parity between locales; ≥20 spot-checked canonical strings. This is the missing-translations detector the app never had.
- **S4 — remainder + decision gate:** menu/reservations/cart top-ups as needed; then the gate below.

## Acceptance contract
1. **Bounded: max 4 sessions.** Each session: re-measure per-dir lcov → write real tests for the largest surfaces → Gate Set U → commit+push (an unpushed session is NOT done).
2. **No coverage-gaming:** every test asserts real behavior (no line-touch-only, no `@Skip`, no tautologies). The l10n suite MUST assert parity + spot values to count.
3. **Decision gate:** aggregate ≥ 80% → DONE. After 4 sessions short of it: record the honest floor + NAMED uncovered surfaces with why (never silent); operator decides accept-or-continue.
4. Final addendum: per-dir before/after table (this spec's table = the "before"), both accounting modes, register still at fixed point.

**END OF PERF-2 SPEC.**