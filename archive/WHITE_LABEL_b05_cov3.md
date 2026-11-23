# WHITE-LABEL COV-3 SPEC - COVERAGE: HOME + WAITLIST + LOCATION (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there). Gap analysis: `PROJECT_STATUS.md` §5-Gap2.**

## COV-3 - COVERAGE: HOME + WAITLIST + LOCATION

**Predecessor:** RELEASE-2. **Emulator-gated:** no. **Territory:** `core_app/test/features/{home,waitlist,location,locations}/` + read-only source.

### Problems (verified this session)

| Area | Current test files | Gap |
|---|---|---|
| home | 2 (service, screen) | No hero promo, category filter, search, or cloudinary thumbnail tests (STATE-3 helper) |
| waitlist | 2 (repository, screen) | No queue-position stream, branch-scoping, or join/leave flow tests |
| location(s) | 4 (map, repo, model, screen) | No pin-drop flow, branch selection → menu re-scope (ROUTER-2 pattern) |

### Acceptance contract
1. home: category filter, search filtering, cloudinaryThumb helper (double-insert guard, signed passthrough — STATE-3's pure function), promo card render.
2. waitlist: joinWaitlist (counter transaction pattern), queue position stream, branch scoping (rules-not-filters), leave flow.
3. location(s): pin-drop flow, branch selection updates `currentBranchIdProvider`, menu re-scopes (ROUTER-2's T-2 pattern).
4. Real bugs found = fix with proof or record as handoff.

### Tests / Gates
- New test files per territory; U-ANALYZE + U-TESTS + U-FORMAT + U-GREPS; full suite green; 0 skips.

**END OF COV-3 SPEC.**