# ROADMAP

Owner-facing state of every unfinished batch. A batch is only `DONE` when its
acceptance evidence exists in this tree and was produced by a command in the
same session it claims.

Read this with `HANDOFF.md` (how to start) and `docs/DECISIONS.md` (why things
are the way they are).

---

## P1 — Foundation (tenancy, roles, ledger, owner dashboard)

Status: **COMPLETE** — cards P1-1 … P1-8 all DONE.

| Card | Evidence | Status |
| --- | --- | --- |
| P1-1 capability spine | `checkpoints/P1-01.md` | DONE |
| P1-2 ledger (atomic order + row) | `checkpoints/P1-02.md` | DONE |
| P1-2a worktree prune | `checkpoints/P1-02a.md`, `docs/WORKTREES.md` | DONE |
| P1-3 reversal + rollups | `checkpoints/P1-03.md` | DONE |
| P1-4 tenancy | `checkpoints/P1-04-STEP7.md`, brief `docs/ORCHESTRATOR-BRIEF-P1-04.md` | DONE — 32/32 rule paths ACTIVE, 0 PENDING |
| P1-5 claims | `checkpoints/P1-05.md` | DONE |
| P1-6 backfills v004/v005 | `checkpoints/P1-06.md` | DONE (dry-run proof; live run is owner-only) |
| P1-7 owner dashboard | `checkpoints/P1-07.md` | DONE — panel built, not yet mounted on the dashboard |
| P1-8 generator dry-run | `checkpoints/P1-08.md` | DONE |

### P1 boundary

Reached. The boundary report is `checkpoints/P1-04-STEP7.md` plus
`docs/ORCHESTRATOR-BRIEF-P1-04.md`. Nothing is pushed; nothing is deployed.

---

## Carry — open items with acceptance criteria

| # | Item | Acceptance | Status |
| --- | --- | --- | --- |
| C-1 | `hasAppId()` may be effectively always-false in production | One real ID token through the rules emulator shows `isAppVerified()` true, or the helper is corrected | BLOCKED — needs a human-held token |
| C-2 | Live migration never executed against a real project | `migrate_v004_tenancy` dry-run then apply on a scratch project; second run plans zero | BLOCKED — owner-only action |
| C-3 | 56 known harness failures | Each either fixed or replaced by a named, justified expectation; baseline reaches 0 | OPEN — see `core_app/test/rules/known_failures.txt` |
| C-4 | 3 pre-existing Dart failures (`restaurant_setup_tax_tab_test` ×2, `feature_flags_test` ×1) | Fail at HEAD, fixed at cause, not skipped | **DONE** — both causes were stale fixtures, not product code: the flags fixture omitted the required `tenantId` so the W6.5 schema rejected the whole load (the test was measuring a schema failure, not orphan tolerance), and the tax-tab test seeded/asserted the retired unprefixed `settings/taxRates` with no tenant claim. Now `settings/<tenant>_taxRates` + `FixedTenantClaim`; 11/11 pass (was 8 pass / 3 fail) |
| C-5 | Legacy unprefixed settings writes retired in services; some Dart fakes still seed old paths | Fakes seed the tenant-keyed documents the app actually reads | OPEN |
| C-6 | P1-7 owner panel not mounted (placement ruled 2026-11-13, D-048) | Mounted in the admin panel's **Analytics** tab (`OwnerDashboard` → `AnalyticsSnapshot`), fed by a **bounded, tenant-scoped** `transactions` read (date window + limit — never an unbounded stream), reusing `BranchChannelBreakdown.fromRows`; widget tests at 390 px and 1024 px plus the empty day; `RoleGate` stays owner-only unless widened by a separate ruling | OPEN — placement ruled, mount not started |
| C-7 | Deploy ordering (claim-callable → guest boot claim → migrate → rules LAST) encoded but never rehearsed | One dry rehearsal on the scratch project with the script's own log | BLOCKED with C-2 |
| C-9 | **Ledger rows are invisible to DSAR erasure and export** (D-059, found while authoring P2-1) | Erasure gains `anonymiseLedgerRows(uid)`: rows where `customerId`, `staffId` or `actorUid` is the uid get those fields nulled plus `anonymisedAt`, amounts and ids untouched; it is idempotent, bounded, and invoked from `runErase` after `eraseRefs`. The Art.15/20 export (`collectUserData`) includes the caller's own rows. Proven by a unit lane over a fake store plus one emulator round-trip: erase a user, read the row, amounts identical and identifiers gone | OPEN — required by D-059 |
| C-8 | **Whole-tree suboptimal-engineering audit** (owner instruction 2026-11-13: "after some time we will audit for suboptimal engineering throughout") | Run after P2-1 lands. A written audit over the modules touched since P1 naming concrete suboptimalities — duplicated logic, weak invariants, unnecessary abstraction, dead code, unbounded reads, money-path shortcuts — each entered here with its own acceptance criterion. Not a restyle pass: a finding with no failing check and no named invariant is an opinion, and does not belong in the result | SCHEDULED — not started |

---

## Phase 2 — Operations surfaces

Queue: `docs/queue-P2.md`. First card is the approved Flutter-web spike
(P2-0 = **DONE, verdict written, waiting on the owner**); its verdict returns to
the owner before any staff-UI card starts.

Status: **P2-0 DONE, RULED — option B** (thin shell, D-049/D-050). The spike
(`checkpoints/P2-00.md`) measured the web build **failing** in dart2js: the
`packages/core` barrel exports `isar_community`, which declares no web platform,
plus two int64 sentinels in the money renderers. The owner chose the A8 fallback.
**P2-1a (thin shell foundation) is DONE** (`checkpoints/P2-01a-BOUNDARY.md`:
BUILD_EXIT=0, FCP 519 ms warm, emulator trace `claim: tenant_shell` +
`read: 2 row(s)`, and an unconstrained read measured **403 PERMISSION_DENIED**,
D-057/D-058). **P2-1 (Counter/POS, cash first) is BLOCKED on an owner money ruling**
(`docs/P2-01-CASH-DECISION.md`): `createOrder` hard-requires a Stripe intent and
the ledger requires a non-null `paymentIntentId` + `customerId`, so cash has no
server path. **Human action: answer Q1–Q3 there.** **P2-3 (Kitchen Display) is
next** because it is not money; P2-2 follows P2-1.

---

## Standing debt policy

No TODO-shaped debt. Anything unfinished enters this file with an acceptance
criterion, or it does not exist. A batch that cannot be proven is reported as
BLOCKED with the missing evidence named, never as done.

---

## P6 candidates — owner-listed 2026-11-13 (NOT authorised, NOT scheduled)

Seven features the owner asked to keep on the record. Detail, sizes and the
standing law each must satisfy live in `docs/BACKLOG-P5.md` §P6. **None is a card
until it appears above with an acceptance criterion** — this table is a register,
not a queue.

| # | Feature | Owner size | Note |
| --- | --- | --- | --- |
| 1 | Daily Owner Digest (7am WhatsApp/email rollup) | S — flagged early | Needs a provider (RESEARCH DRAFT first) and a consent surface distinct from ADR-P5-1's customer gate |
| 2 | Halal/dietary trust layer (badges, allergens, cross-contamination) | S — flagged early | **P6-1 DONE** (2026-11-14) — `checkpoints/P6-01-MODEL-UI.md` (+ rules: `P6-01-RULES.md`). Model + vocabulary + validation on both projections, badges with expired-claim suppression, 3 dietary chips + 13-code allergen sheet, owner-only halal editor, 29 l10n keys in en/ar. Codegen works with `--build-filter` (D-055); the tag-based Vegan chip is superseded (D-054). Follow-up: tags→codes backfill needs owner consent |
| 3 | Kiosk mode (counter iPad self-order) | S–M | Depends on the shell + P2-1; same `createOrder`, no new money path |
| 4 | Google Business Profile "Order" link | S | A link, not an aggregator integration; owner changes their own listing |
| 5 | Arabic/Urdu localisation | S (Gulf) | `ur` is new and RTL — must enter the l10n parity gate |
| 6 | Waitlist/reservations, dine-in only | M — later | Depth on existing screens, not a greenfield build; owner-deprioritised |
| 7 | Offline mode for the POS | M (Canada) | Needs the browser cache seam; safe only because `sale_<orderId>` makes replay idempotent (D-030) |
