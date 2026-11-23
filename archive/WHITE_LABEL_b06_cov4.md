# WHITE-LABEL COV-4 SPEC - COVERAGE: AUTH + LOYALTY (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2.**

## COV-4 - COVERAGE: AUTH + LOYALTY

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `core_app/test/features/{auth,loyalty}/` + read-only source.

### Problems (verified this session)

| Area | Current test files | Gap |
|---|---|---|
| auth | 4 (autofill, login, signup, ToS) | No role-gate integration, no sign-out FCM-token cleanup test (RULES-2's deliverable), no error-path tests |
| loyalty | 3 (calculator, provider, screen) | No edge-case points math (zero-cent, negative-attack clamping — wiring suite has some), no tier-transition tests |

### Acceptance contract
1. auth: signOut clears fcmToken (RULES-2 T-1 pattern extended), role-gate integration (wrong role → NoPermissionRedirect), login error paths (wrong password, network), signup validation.
2. loyalty: points edge cases, tier transitions, provider invalidation on order events.
3. Real bugs found = fix with proof or record as handoff.

### Tests / Gates
- New test files per territory; U-ANALYZE + U-TESTS + U-FORMAT + U-GREPS; full suite green; 0 skips.

**END OF COV-4 SPEC.**