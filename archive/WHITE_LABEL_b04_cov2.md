# WHITE-LABEL COV-2 SPEC - COVERAGE: DRIVER + ONBOARDING + TOUR (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2.**

## COV-2 - COVERAGE: DRIVER + ONBOARDING + TOUR

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `core_app/test/features/{driver,onboarding,tour}/` + read-only source.

### Problems (verified this session)

| Area | Current test files | Gap |
|---|---|---|
| driver | 2 (POD service, POD test) | No delivery dashboard integration, no GPS lifecycle tests |
| onboarding | 2 (logic, screen) | No tour integration or completion-persistence tests |
| tour | 2 (logic, overlay) | No overlay rendering or dismiss-persistence tests |

### Acceptance contract
1. driver: delivery dashboard integration (assignToMe, markDelivered with state-machine guard from STATE-1), GPS start/stop lifecycle (single-subscription, STATE-1 P-2 pattern), driverId stamping on deliveries (MONEY-3).
2. onboarding: completion persistence, skip behavior, first-run detection, tour trigger wiring.
3. tour: overlay rendering, dismiss persistence (shared-prefs), re-show rules.
4. Real bugs found = fix with proof or record as handoff.

### Tests / Gates
- New test files per territory; U-ANALYZE + U-TESTS + U-FORMAT + U-GREPS; full suite green; 0 skips.

**END OF COV-2 SPEC.**