# WHITE-LABEL COV-5 SPEC - COVERAGE: ADMIN DASHBOARDS INTEGRATION (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2.**

## COV-5 - COVERAGE: ADMIN DASHBOARDS INTEGRATION

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `core_app/test/features/admin/` (22 existing test files — this batch adds INTEGRATION-level tests) + read-only source.

### Problems (verified this session)

admin already has 22 test files (densest area) — but they are unit/widget level. Missing: cross-service integration coverage that mirrors real staff workflows.

### Acceptance contract
1. Owner dashboard: user-branch update flow end-to-end (mounted-guard + provider invalidation from STATE-1), role change propagation.
2. Manager dashboard: capped history stream (24h window + limit 200, STATE-2), revenue chart provider with error branch.
3. Kitchen + delivery: the update path with `updatedAt` allowed by RULES-1's shape locks (rules harness parity).
4. Panic switch: orders-accepting toggle behavior.
5. Real bugs found = fix with proof or record as handoff.

### Tests / Gates
- New integration test files under `test/features/admin/`; U-ANALYZE + U-TESTS + U-FORMAT + U-GREPS; full suite green; 0 skips.

**END OF COV-5 SPEC.**