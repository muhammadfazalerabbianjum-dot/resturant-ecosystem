# ORCHESTRATOR REPORT — P1 boundary — 2026-11-11

Branch `cline/p32-golden-gates` · HEAD `c603d77e` · nothing pushed · working tree clean.

**P1 cannot close 8/8: P1-4 is blocked on owner decision Q-004.** Everything else
in Phase 1 is DONE and green. This report is the boundary stop the handoff asks
for.

## Gate battery (final, one run, on the committed tree)

```
[a] dart-analyze                 PASS   433.2s
[b] gate-fast-tests              PASS   398.4s
[c] functions-build              PASS    10.8s
[d] emulator-rules               PASS    20.0s
[e] whitelabel-dry-run           PASS     1.9s
[f] stub-scan                    PASS     0.0s
[i] tenant-isolation-generator   PASS     1.3s
[g] functions-coverage           PASS    16.8s
[h] backend-parity               PASS     1.3s
GATE RESULT: PASS  (9 ran, 0 failed, 0 unavailable, 0 not-active)
```

Receipt: newest `checkpoints/gate-*.md`. `functions` tests: 231 pass. Coverage
floors: 21 files at or above floor.

## Cards

| Card | State | Commit | Evidence |
|---|---|---|---|
| P1-1 | DONE | (P0 snapshot `0859bb79`) | `checkpoints/P1-01.md` |
| P1-2 | DONE | `09aa31bd`, plus `c603d77e` | `checkpoints/P1-02.md` |
| P1-2a | DONE | `e8c3ca08`, `77173547` | `checkpoints/P1-02a.md` |
| P1-3 | DONE | `2e51ccbe` | `checkpoints/P1-03.md` |
| P1-4 | **BLOCKED** | — | Q-004 + missing emulator bootstrap |
| P1-5 | DONE | `f0e78a1b` | `checkpoints/P1-05.md` |
| P1-6 | DONE | `dee3dd16` | `checkpoints/P1-06.md` |
| P1-7 | DONE | `4c79d4db`, `42532a61` | `checkpoints/P1-07.md` |
| P1-8 | DONE | `d5f7d655` | `checkpoints/P1-08.md` |

## What changed in P1, in one paragraph each

**Money.** `createOrder` now writes the order and exactly one append-only ledger
row (`sale_<orderId>`) in one transaction; a replay keeps the original, a poisoned
row rolls both back, and `transactions` denies client writes (proven against the
emulator, including a real 403 on GET and POST). Reversals append `rev_<rowId>`
with negated amounts and never touch the original; `daily_rollups` is rebuilt from
rows and the rebuild is asserted equal to a from-scratch fold. The rollup reports
refunds separately and never drops a sale from `ordersCount`.

**Tenancy and authority.** Claims now carry `tenantId`, `roles[]`, `branchIds[]`
from one `buildUserClaims`; a privilege change bumps `claimsVersion` *and* revokes
refresh tokens, and a stale claim fails `assertCapability` with `stale_claims`.
The v004/v005 backfills derive from existing fields, are dry-run by default, treat
a foreign-tenant document as a conflict rather than reassigning it, and are proven
to change zero documents on a second run.

**Owner visibility.** The branch × channel breakdown derives from ledger rows with
the same arithmetic as `rollups.ts`, renders without overflow at 390 px and
1024 px (an overflow would fail the test, not just print), and shows money and
order counts only — channel values stay as stored.

**Factory.** An existing client's dry-run exits 0 without writing. A scratch
client generated from scratch clears format, `analyze --fatal-infos`, 49 tests and
a debug APK, with the Stripe key passed as a build-time define and never written
to the generated tree; the scratch app and its config were deleted afterwards.

## Defects the gates found this session (all fixed)

1. **Gate (a):** an unbraced `if` in `tool/gen_tenant_isolation_tests.dart` left
   by my own generator change. Invisible to gates (c)/(d)/(f)/(i). Fixed in
   `4c79d4db`.
2. **Gate (h):** `apps/halal_boyz/backend/firestore.rules` had drifted from the
   canonical rules and lacked the `transactions` deny block — a deployment from
   that copy would have opened the ledger to client writes. Refreshed in
   `c603d77e`.
3. **P1-8:** an interrupted generation leaves hash-named files in Android
   `res/values{,-night}/`, which fails the next APK gate; the fix is deleting the
   app directory, not `--regenerate`. Recorded in the checkpoint for the runbook.

## Blocked: P1-4 (tenancy rules)

Two items, and only one needs the owner:

1. **Q-004 (owner ruling needed).** Where does an *unauthenticated* menu/branch
   read get its tenant? The provisional answer is design 1: guest clients carry a
   tenant claim and no collection is exempt from `tenantOk()`. Flipping rules to
   design 1 without the answer would be a guess on the widest surface in the app.
2. **Harness (mine to build once Q-004 is answered).**
   `test/security/tenant_isolation_support.dart` has no emulator bootstrap and no
   sign-in, so setting the 28 registry rows to ACTIVE before building it yields 56
   red tests. The harness must exist first, then the rows flip, then the rules
   change lands behind a green generated suite.

Deploy ordering remains binding (D-032/D-033): v004 → v005 → claims trigger →
P1-4 rules. Nothing in this phase deployed anything, reached real Firebase or
Stripe, or pushed a commit.

## What I would do next, in order

1. Owner answers Q-004.
2. Build the auth-emulator bootstrap in the tenant-isolation harness, green with
   all rows still PENDING-TENANCY (proves the harness, changes no rule).
3. Flip rows per collection to ACTIVE, one collection per commit, each with a
   passing cross-tenant denial.
4. Then P1-4's `tenantOk()` rules change, last, with the suite green.

Everything else in P1 is finished; P2 does not need to wait on Q-004 if the owner
prefers to start the web spike (A8) in parallel.
