# WHITE-LABEL COV-1 SPEC - COVERAGE: KITCHEN + SPLASH + PROMO_CODE (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2.**

## COV-1 - COVERAGE: KITCHEN + SPLASH + PROMO_CODE

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `core_app/test/features/{kitchen,splash,promo_code}/` + the source files they test (read-only unless a test finds a real bug — then fix in-territory with proof).

### Problems (verified this session)

| Area | Current test files | Gap |
|---|---|---|
| kitchen | 3 (dashboard ×2, offline service) | No order-status flow tests, no queue-replay integration |
| splash | 1 (screen only) | No config-load, fail-closed gate, or force-update tests |
| promo_code | 1 (property test) | No service-level redemption tests |

### Acceptance contract
1. kitchen: order-status transition tests (using `canTransitionTo`), queue replay on flaky write (STAFF-QUEUE pattern), dashboard stream subscription test (STATE-2 family pattern).
2. splash: config-load success/malformed/missing, fail-closed gate, force-update parallel future, first-frame non-blocking (STATE-3 pattern).
3. promo_code: service-level apply/redemption, invalid code, expired code, already-used code.
4. All tests red-today/green-after is NOT required (this is coverage, not bug-fix) — but any REAL bug found must be fixed with proof or recorded as a handoff.

### Tests / Gates
- New test files in the 3 territories; each asserts real behavior (Rule 2).
- U-ANALYZE + U-TESTS + U-FORMAT + U-GREPS (index §1).
- Full core_app suite green; no skip markers.

### Honest residuals
- If a test requires the emulator (e.g. real Firestore stream), record it and mock per existing patterns (fake_cloud_firestore) — this batch is NOT emulator-gated.

**END OF COV-1 SPEC.**