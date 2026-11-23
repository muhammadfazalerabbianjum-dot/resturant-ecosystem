# WHITE-LABEL PERF-1 SPEC - PERFECTION: REGISTER CODE-FIXES (RESEARCHED) + COVERAGE QUICK WINS

**Read `WHITE_LABEL_BATCHES.md` FIRST.** **Predecessor:** RELEASE-2R (register errata: class-(b) H-1..H-4 open). **Emulator-gated:** no. **Status: RESEARCHED — every fix below is pinned to verified file:line at main `39a709e`; no "verify at execution" remains.**

## The four fixes (exact, researched 2026-09-14)

### H-1 — silent sign-in/forgot error (repo-side rethrow, mirrors the signUp precedent)
- **Bug (verified):** `packages/core/lib/src/auth/auth_repository.dart:100` — `signInWithEmailAndPassword` catches, logs, then `throw Exception(FirebaseExceptionMapper.map(e))`; but the ONLY production caller `core_app/lib/features/auth/presentation/login_screen.dart:39-41` catches `on FirebaseAuthException` — the wrapped generic `Exception` NEVER matches, so the mapped message never reaches the UI and the typed exception never escapes (silent swallow; `finally` still clears loading). **Same seam at :114** for `sendPasswordResetEmail` whose caller `login_screen.dart:63` also catches typed.
- **Fix (the register's own preferred option):** in BOTH methods keep the `_logger.error(...)` call, replace `throw Exception(FirebaseExceptionMapper.map(e));` with `rethrow;` — mirroring `signUp` (:141-143) whose in-code comment states the contract: "We let the typed exception propagate so the caller shows a clean localized message for the AUTH failure." The screen's existing typed catches (:40-41, :63-67) then fire with the mapper's precise message. Screen files: UNCHANGED.
- **Contract updates (the "one assertion update" ×2):** T-7 (`auth_repository_error_contract_test.dart`) changes from asserting the wrap to asserting typed rethrow (mirror its signUp T-8). `login_error_paths_test.dart` re-verified (its mocks throw typed — unaffected).
- **Caller-safety mandate (record in addendum):** grep `signInWithEmailAndPassword|sendPasswordResetEmail` over all `lib/**` — sole production callers are `login_screen.dart:39` and `:57` (verified 2026-09-14). Any new caller found → treat as drift, record.
- **Do NOT widen the screen's catch instead:** the repo's wrapped message is already mapped, so a generic screen catch would double-map it into the mapper's generic fallback ("An unexpected error occurred…") — precision loss. Rationale recorded.

### H-2 — mapper gaps (verified by reading the switch)
- `packages/core/lib/src/error_logger/firebase_exception_mapper.dart` — `map(Object)` (generic-safe, fallback :41). Missing cases surfacing as "An unexpected server error occurred (<code>)": **`weak-password`, `too-many-requests`, `invalid-email`**.
- **Fix:** add three cases to the FirebaseException switch (house style, English literals — the mapper is core-side, pre-l10n by design): `weak-password` → 'That password is too weak. Please choose a stronger one.' · `too-many-requests` → 'Too many attempts. Please try again later.' · `invalid-email` → 'Please enter a valid email address.'

### H-3 — forged-negative loyalty display (clamp at the model, fail-closed at parse)
- **Bug (verified):** `loyalty_screen.dart:35` renders `loyalty.totalPoints` verbatim; `LoyaltyModel.fromJson` (:41-42) delegates to generated code with no clamp, so a forged negative doc renders "-50 points" (tier stays Bronze — T-24/T-39 hold).
- **Fix:** clamp in the HAND-WRITTEN `fromJson` factory body (no freezed regen needed): parse via `_$LoyaltyModelFromJson`, then `copyWith(totalPoints: m.totalPoints < 0 ? 0 : m.totalPoints)`. CF delivered-hook only writes positive (index.ts:1593-1614) → legit data unaffected; forged data fails closed to 0 → Bronze. Chosen over display-side clamp: single source of truth, every consumer protected.

### H-4 — integer-cent precision (1 line)
- `loyalty_model.dart:11` `return (totalCentsSpent / centsPerPoint).floor();` → `return totalCentsSpent ~/ centsPerPoint;` — exact for ALL non-negative ints (double division lossy beyond ~2^53). Precedent: `cart_calculator.dart` L21 (deleted P9/T-5; pinned by `core_app/test/app/deleted_sources_pin_test.dart`) already `~/`. Behavior identical at realistic magnitudes; T-22/T-23 can only get greener.

## Coverage floors (same session)
`flutter test --coverage` per package + lcov LH/LF: `apps/halal_boyz` ≥ 80% (was 30/61) · `packages/core` ≥ 80% (was 560/750) · `packages/core_ui` ≥ 80% (was 939/1521). Aggregate → ≈67.7%.

## T-x table
| ID | Proof |
|---|---|
| T-1 | H-1 red/green: real repo, wrong-password → screen shows 'Incorrect email or password.' (was: nothing) |
| T-2 | forgot-path red/green: reset failure surfaces mapped message |
| T-3 | H-2: the 3 new codes map to the new strings; unknown code still falls back |
| T-4 | H-3: forged negative doc → renders 0 (not −50); tier Bronze |
| T-5 | H-4: calculatePoints exactness at 2^53 and 2^53+100 (integer-exact) |
| T-6 | Coverage floors ×3 packages (lcov numbers in addendum) |
| T-7 | Register re-run: H-1..H-4 → FIXED; zero new anomalies |

## Gates + cadence
Gate Set U green (0 fail/0 skip) · format 0 changed · addendum + commit + push (§3.5.3). **Residuals expected:** core_app 80% = PERF-2's campaign; §12 operator items untouched.

**END OF PERF-1 SPEC.**