# BATCH 4 — REPLACE SKIPPED TESTS (ZERO SKIP ESCAPES) · Major

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST.

## PROBLEM
- `core_app/test/e2e/checkout_e2e_test.dart:2` `@Skip('Requires patrol device and emulator')` + `:17 skip:true`.
- `core_app/test/e2e/reservation_e2e_test.dart:2` `@Skip(...)` + `:16 skip:true`.
- `flutter test` (core_app) reports `+1235 ~8: 8 skipped tests`.
- Zero-skip gate violated. These two flows (checkout, reservation) have NO always-run test.

## SOLUTION — record the owner decision (A or B); both must END at zero skips
1. **Option A — make them real patrol/emulator E2E runs.** Run against the Firebase emulators
   (firestore/auth/functions) so the flows EXECUTE for real in CI (past-time reservation
   rejection, double-booking capacity, checkout payment-failure honesty). Remove the
   `@Skip`/`skip:true`. Must run green headlessly.
2. **Option B — replace with real always-run emulator integration tests** (delete the two @Skip
   files and their `skip:true`, then add STANDARD runnable tests that exercise the same
   behaviors through the real providers + emulator):
   - checkout flow: builds order, calls `createPaymentIntent` with a payment that fails (or the
     honest no-key path) and asserts the UI/flow FAILS CLOSED (no fake "Order placed!");
     asserts money-equality path is honored.
   - reservation flow: past-time rejection; double-booking lock returns false on second attempt
     ON THE EMULATOR (uses B0's real `reservation_counters`/`reservation_locks` rules); waitlist
     idempotent join + queue position on the emulator.
   These run in the standard `flutter test` emulator path (no `@Skip`, no `skip:`).
3. **Either way, after this batch:** `Select-String` for `@Skip|skip: true|skip:true|
   markTestSkipped` across `core_app/test`, `apps/*/test`, `packages/*/test` (dart files) → 0.

## TESTS
| Test | Asserts |
|---|---|
| T-S1 | checkout flow fails closed (payment not confirmed → no order created; failure surfaced) |
| T-S2 | reservation past-time rejected; double booking same slot → false (capacity/lock honored) |
| T-S3 | waitlist idempotent (re-join = alreadyJoined, 1 doc) + queue position correct |

## GATES (must ALL pass)
- [ ] `flutter test` (core_app) reports **0 skipped** (`+N ~0`).
- [ ] `Select-String -Recurse -Path core_app/test,apps,packages -Pattern '@Skip|skip:\s*true|markTestSkipped'` (dart files) → **0 matches**.
- [ ] `flutter analyze --fatal-infos` → clean.
- [ ] FN-TEST + RULES-EMUL still green (U-NOBREAK).
- [ ] B4 addendum appended recording which option (A or B) and the command outputs.

## RESIDUALS (honest)
- If a flow genuinely requires a physical device (hardware NFC / real payment sheet), record it
  in the B6 not-provable matrix rather than silently skipping it.

**END OF BATCH 4.** Not closed until Gates green + addendum appended.