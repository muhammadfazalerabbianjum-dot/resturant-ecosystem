# BATCH 2 — GDPR ERASURE EMULATOR INTEGRATION GREEN · P0 RELEASE-BLOCKER

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST.

## PROBLEM
`core_app/test/functions/gdpr_erasure_test.js` (REAL production-module integration test:
`testEnv` from `@firebase/rules-unit-testing` + the compiled `functions/lib/index.js`) is RED
on a clean run. GDPR-EMUL → exit 1: `GDPR ERASURE (PROD CF CORE) - PASSED: 19 FAILED: 2`
- `T4 user docs were STILL erased before the auth failure (durable marker-first)` — undefined
- `T5 locks + waitlist erased too` — undefined

The 22 scoped assertions (query-key guard, per-user reservations/locks erasure, marker lifecycle
`in_progress → completed`, >500-doc chunked erase, hourly retrier completes only ≥1h owed,
`auth/user-not-found` idempotent) ALL pass. The 2 failures are whole-collection checks failing
because `testEnv.clearFirestore()` does not clear the admin-SDK client's namespace the CF writes
into (harness/namespace mismatch) — pre-seeded reservations/locks survive in THAT client's view.

## SOLUTION — fix the harness, do NOT weaken the assertions
1. **One namespace.** Seed + erase + assert must all run against the SAME admin-rules client the
   compiled CF uses. Choose one and record it in the addendum:
   (a) seed via the same `admin.firestore()` used by the module and assert across that namespace;
   (b) drop `initializeTestEnvironment(...).clearFirestore()` as sole reset and instead clear
       BOTH namespaces between scenarios (iterate + delete all docs in each collection the test
       touches);
   (c) name the test project so the admin client and `testEnv.firestore()` resolve to the same
       backend, then assert through `rules`-permitted reads.
2. **Keep EVERY existing assertion; never delete or weaken T4 / T5.** T4 (whole user set erased
   before the auth-failure point — i.e. durability ordering unaffected by the marker) and T5
   (>500 docs + locks + waitlist all gone) must PASS after the fix.
3. Re-run GDPR-EMUL → `PASSED: 24 FAILED: 0`, exit 0 (see Gate 1 below).

## TESTS
| Test | Asserts |
|---|---|
| T0-1..T0-3 | query-key guard (reservations by userId, locks scoped, users LAST) — keep green |
| T0-4 | marker-first durability: whole-set erased + marker lifecycle — now GREEN (was RED) |
| T0-5 | >500-doc chunked erase incl. locks + waitlist — now GREEN (was RED) |
| T0-6 | retrier completes only ≥1h owed; fresh markers left alone; auth not-found idempotent |

## GATES (must ALL pass)
- [ ] GDPR-EMUL → exit 0 + line `PASSED: 24 FAILED: 0`.
- [ ] Grep the test file for `testEnv.clearFirestore` — if still present, it must be complemented
      by namespace-inclusive clearing, not used as the sole reset.
- [ ] FN-TEST → green (regression).
- [ ] Gate set U (analyze, greps, zero skips); B2 addendum appended incl. chosen namespace option.

## RESIDUALS (honest)
- The fix targets the test harness; production erasure code is unchanged unless the harness
  uncovers a real gap — then fix the CODE, prove it, and re-run. Never paper over a real defect.

**END OF BATCH 2.** Not closed until Gates green + addendum appended.