# QUEUE — P1 (Foundation: tenancy, roles, ledger, owner dashboard)

Authoritative spec: `docs/ORCHESTRATOR_HANDOFF.md` §10 Phase 1. One row per card;
a card is `DONE` only when its checkpoint exists and its `DONE WHEN` clause is
true. Gate discipline, laws and quality bar are unchanged from P0.

**Ordering rule:** capabilities (P1-1) before anything that authorises a staff
action; the ledger (P1-2/P1-3) before any new money entry point; tenancy rules
(P1-4) last, because they must be deployed only behind the generated
cross-tenant suite.

| Card | Deliverable | DONE WHEN | Status |
|---|---|---|---|
| P1-1 | Capability table + server gate: `functions/src/permissions.ts`, `assertCapability` in `access.ts`, wired into the existing staff callable, exhaustive tests | `npm test` green; new files ≥90% lines; a `waiter`-only caller is denied `payment.take` by the gate logic with a named reason, and the mapping to `permission-denied` is asserted | DONE (`checkpoints/P1-01.md`) |
| P1-2 | Ledger: `functions/src/ledger.ts` + `createOrder` writes exactly one row, atomically | Emulator-backed proof: order + one row in one transaction; a retry adds none; a poisoned row rolls both back; `transactions` client-write denied | DONE (`checkpoints/P1-02.md`) |
| P1-2a | Worktree prune (owner ruling D-029): merged-proof re-run, bundle-verified backups, `worktree remove` + `branch -d` only, REVIEW on refusal | 8 branches dispositioned in `docs/WORKTREES.md` with bundle paths; checkpoints/P1-02a.md proves the sequence | DONE — 8/8 pruned, bundles verified (`checkpoints/P1-02a.md`) |
| P1-3 | Reversal + rollups: reversal appends, original byte-identical; `daily_rollups` rebuild equals a from-scratch rebuild | Both asserted in one test file; rollup cache is never trusted as the source of truth | DONE (`checkpoints/P1-03.md`) |
| P1-4 | Tenancy: `tenantOk()` helper on every match block, `TenantFirestore` wrapper, generated suite ACTIVE per collection | Every collection has an ACTIVE cross-tenant denial case; 0 rows remain PENDING-TENANCY; rules emulator green | **DONE** — 32/32 rule paths ACTIVE (28 top-level + 4 nested), 0 PENDING; `checkpoints/P1-04-STEP7.md`, brief `docs/ORCHESTRATOR-BRIEF-P1-04.md` |
| P1-5 | Claims: `tenantId`, `roles[]`, `branchIds[]`; `revokeRefreshTokens` on privilege change | Claim shape tested; a stale claim cannot pass `assertCapability` after revocation | DONE (`checkpoints/P1-05.md`) |
| P1-6 | Backfill `migrate_v004_tenancy` + `migrate_v005_roles`, dry-run first, refuse conflicts | Second run changes zero documents (asserted, not observed once) | DONE (`checkpoints/P1-06.md`) |
| P1-7 | Owner dashboard: branch and channel breakdown at 390 px and 1024 px, no overflow | Widget test at both sizes; no overflow errors | DONE (`checkpoints/P1-07.md`) — panel built; not yet mounted on the dashboard (see checkpoint gaps) |
| P1-8 | Generator dry-run for an existing client + a scratch client passing its own post-gates | Both commands exit 0, evidence logged | DONE (`checkpoints/P1-08.md`) — dry-run 0, scratch build 0, APK built, artifacts deleted |

## Open decisions that shape P1

- **A1 (handoff §8.1)** — **RULED 2026-11-09 (D-021): flat collections +
  `tenantId`, one rules helper, generated cases ACTIVE.** P1-4 proceeds.
- **A2 / A8 / Q-001 / Q-002 / D-013** — all ruled 2026-11-09 (D-022…D-026);
  see `docs/DECISIONS.md`. No P1 card is blocked any more.
- **D-013** — `terminalLocationId` placement, `ASSUMED`; no reader exists before
  P2, so nothing consumes it yet.
