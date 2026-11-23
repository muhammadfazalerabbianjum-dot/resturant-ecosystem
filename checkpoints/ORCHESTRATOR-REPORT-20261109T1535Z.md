# ORCHESTRATOR REPORT — 2026-11-09 15:35Z

- Repo: `<repo>` · Branch `cline/p32-golden-gates` @ `7c139d5c` · nothing committed.
- **Verdict: P0 closed (12/12) · P1 at 1/8 · all nine gates PASS as of this report.**
- Phase 1 is one card in, not one quarter in. The capability spine exists; no
  money row has been written yet.

## 1. Programme position

| Phase | Scope | State | Evidence |
|---|---|---|---|
| P0 | hygiene, gates, baseline (12 cards) | **DONE** | `docs/queue-P0.md` 12 DONE / 0 TODO; `checkpoints/P0-01…P0-12.md`; full gate 9/9 PASS `gate-20261109T135306Z.md` |
| P1 | Foundation: capabilities, ledger, tenancy, claims, backfills, dashboard, factory (8 cards) | **1/8 DONE** | `docs/queue-P1.md`; `checkpoints/P1-01.md` |
| P2 | Counter POS + kitchen, cash + card-present | not started | blocked on Q-001, Q-002 |
| P3 | Waiter + multi-branch | not started | depends on P1 claims/tenancy |
| P4 | Inventory | not started | A12 schema comes in P1 |

## 2. Gate truth

Every gate below was executed **in this session, after the P1-1 change**, as a
separate `--only` invocation. There is no single full-suite receipt for this
state: the full suite was last run as one command at 13:53Z, before P1-1. A Dart
tool file was newer than that receipt, so a/b were re-run rather than assumed.

| Gate | Name | Result | Duration | Receipt |
|---|---|---|---|---|
| a | dart-analyze | PASS | 269.0s | `gate-20261109T152112Z.md` |
| b | gate-fast-tests | PASS | 300.0s | `gate-20261109T153152Z.md` |
| c | functions-build | PASS | 7.3s | `gate-20261109T150023Z.md` |
| d | emulator-rules | PASS | 24.3s | `gate-20261109T151907Z.md` |
| e | whitelabel-dry-run | PASS | 5.2s | `gate-20261109T151932Z.md` |
| f | stub-scan | PASS | 0.0s (29 files) | `gate-20261109T151938Z.md` |
| g | functions-coverage | PASS | 9.3s | `gate-20261109T150037Z.md` |
| h | backend-parity | PASS | 1.1s | `gate-20261109T151942Z.md` |
| i | tenant-isolation-generator | PASS | 1.0s | `gate-20261109T151944Z.md` |

Deltas worth noting: stub-scan now scans **29** files (was 25) because P0-11's
tool files and P1's new modules joined the surface. Functions coverage floor
covers **15** files; `access.ts` and `permissions.ts` are both at 100%.

Test counts: **2541 Dart** (gate-fast subset green), **193 functions**
(178 before P1-1). Total functions coverage 60.14%; `src/index.ts` remains the
drag at 22.3% over 2282 lines — deliberate, it is the untested wiring.

## 3. What P1-1 delivered

- `src/permissions.ts`: 7 roles, 17 capabilities, one table, pure functions
  (`can`, `canAny`, `grantsFor`), zero imports.
- `src/access.ts`: `assertCapability` (roles[] with legacy `role` fallback,
  fail-closed) and `capabilityDenialCode` (named reason → `permission-denied`).
- `src/index.ts`: `dispatchToFleet` gates on `fleet.dispatch`; identical holder
  set today, moved through the new seam.
- 17 new tests, including the Phase 1 acceptance case: waiter-only is denied
  `payment.take`, allowed `table.open`.
- Recorded as **D-020**, grade CONSTRAINED, with the Phase 2 narrowing of
  `fleet.dispatch` named as its verification step.

Honest limit: the denial is proven at the gate, not through a live POS
callable — that surface does not exist until Phase 2. The Phase 1 criterion is
therefore **partially** met until a staff callable calls this gate.

## 4. Phase 1 acceptance scoreboard

| # | Criterion | State |
|---|---|---|
| 1 | analyze clean, Dart suite green, functions build clean | **MET** (gates a, b, c) |
| 2 | Cross-tenant read denied for *every* collection, generated | OPEN — P1-4, blocked on A1 |
| 3 | `roles:['manager','waiter']` passes both checks; waiter denied `payment.take` by server | **PARTIAL** — gate proven, no callable yet |
| 4 | Backfills idempotent: second run changes zero docs | OPEN — P1-6 |
| 5 | Every customer money event writes exactly one ledger row; reversal appends, original byte-identical | OPEN — P1-3 (the next card) |
| 6 | Rollup equals from-scratch rebuild, asserted | OPEN — P1-3 |
| 7 | Dashboard at 390 px and 1024 px, branch + channel breakdown | OPEN — P1-7 |
| 8 | Generator dry-run clean for existing client; scratch client passes its gates | OPEN — P1-8 |

## 5. Decisions only the owner can make

| ID | Question | Blocks | Default I would use if forced |
|---|---|---|---|
| A1 | Tenancy by flat collection + `tenantId`, or `tenants/{id}/…` subpaths | P1-4 and all of Phase 3 | flat + field (P0-8's generator and registry already assume it; reversing later is a rules/migration change, not a data move) |
| A2 | Migrate the live Halal Boyz project into the shared project | Phase 2 go-live, not code | fresh project, Halal Boyz as tenant #1 |
| A8 | Flutter web for staff surfaces vs alternative | Phase 2 start | 2-day spike with the pre-agreed fallback |
| A10 / Q-001 | Where the thermal printing implementation actually is | Phase 2 receipts | on-screen + system print + Stripe email |
| Q-002 | Which Stripe reader, which market | Phase 2 card-present | none — hardware cannot be emulated |
| D-013 | `terminalLocationId` flat or nested | Phase 2 | accept both (already implemented, grade ASSUMED) |
| — | 8 branches SAFE-PRUNE, 2 worktrees REVIEW (`<repo>-shots`, `<repo>-p33`) | nothing functional | nothing deleted; the two REVIEW worktrees hold work that exists nowhere else |

## 6. Risks

1. **No ledger yet.** Today's `createOrder` writes the order document and no
   money row. That is the single largest correctness gap in the product, and it
   is P1-2's whole job — including atomicity with the order write.
2. **Transaction proof needs an emulator, not a unit test.** A pure builder
   test cannot show "exactly one row on double-submit". P1-2 must extend the
   rules probe or drive the admin SDK against the emulator, or it is unproven.
3. **Rules are still wide.** `transactions` must be `write: false` from day one;
   adding a collection also means a registry row, or gate i fails.
4. **121 dirty entries, nothing committed.** All P0/P1 output is uncommitted on
   purpose (L4: no card says `COMMIT: yes`). A machine failure loses it.
5. **`index.ts` coverage 22.3%.** The capability gate is tested, the callable
   that will use it is not.

## 7. Next five

1. **P1-2** ledger: `ledger.ts` (deterministic doc id per order, pure row
   builder), order + row in one Firestore transaction, `transactions` denied to
   clients, rules-probe proof of the denial, coverage row.
2. **P1-3** reversal appends; original read back byte-identical; `daily_rollups`
   rebuild equality test.
3. **P1-5** claims `tenantId`/`roles[]`/`branchIds[]` + revocation on privilege
   change (does not need A1, only A3 which is ready).
4. **P1-4** tenancy rules + `TenantFirestore` + flip the generated suite ACTIVE —
   the moment A1 must be answered.
5. **P1-6** backfills, dry-run first, second-run-changes-zero assertion.

## 8. Five-line truth

1. P0 is closed and every gate passes right now; P1 is 1 of 8.
2. The capability table is real, enforced server-side, and 100% covered.
3. No ledger row exists yet — money is still written once, untrailered.
4. Tenancy (P1-4) cannot move without A1; nothing else in P1 needs the owner.
5. Nothing is committed; the tree is the only copy.
