# Platform Expansion Plan — multi-role restaurant operations

**Status:** proposal, awaiting `[PLAN]` approval. No code has been written.
**Evidence:** every claim about the current code lives in
`docs/PLATFORM_EXPANSION_EVIDENCE.md` with `file:line`. Where this document
says UNVERIFIED, it means the assessment did not test it.
**Scope:** feasibility + phased plan. Also covers the later Pentagi
vulnerability-scanning phase (§9) and the white-label fleet impact (§8).

---

## 1. Verdict

**Yes, this is feasible — and it is an extension, not a rewrite — but three
things must change before any new surface is built, and one of them is a
genuine decision rather than a task.**

What is genuinely strong and should not be touched:

- The money path is already server-authoritative and idempotent
  (`createChargeIntentCore` re-prices from `menus`, derives tax/promo/currency
  server-side, one metadata builder, one idempotency key). A POS bolted onto
  this inherits real fraud resistance for free.
- Permission enforcement is real, not decorative: 811 lines of Firestore
  rules with per-role shape locks, JWT role claims minted by a trigger, and
  fail-closed server gates.
- The white-label factory works. A generated client is a thin
  `initCarnamaApp` shell over one shared app body, with its own Firebase
  project and its own copied rules. Adding a surface does not mean N forks.
- `flutter analyze` on `core_app` is clean (my run: no issues, 137 s), and
  there are 433 test files plus a real rules-emulator harness.

What blocks the target system, in order of severity:

| # | Blocker | Why it blocks | Size |
|---|---|---|---|
| B1 | One `role` per user (`UserRole` enum has no `counter`/`waiter`) | Owner who also covers the counter; manager who waits tables. Every rule, claim and screen assumes exactly one role. | Medium — schema + claims + rules helper + migration |
| B2 | One `branchId` per user; one owner email per project | Multi-branch requires staff scoped to a *set* of branches and an owner that can see all of them. | Medium — same migration as B1 |
| B3 | No staff-created order path | `createOrder` requires a succeeded Stripe PaymentIntent bound to the caller's uid. A cashier cannot ring up a walk-in, and cash cannot exist at all. | Large — new callable reusing the pricing core |
| B4 | No `tables`, `transactions`, `inventory` anywhere | Greenfield, but that is good news: nothing to unwind. | Medium (schema from day one, build later) |
| B5 | All order mutation is client-direct with `hasOnly` shape locks | Per-item ready flags, payments, reversals and table state cannot be expressed this way. Authority must move into callables. | Large — this is the architectural pivot |
| B6 | Source cannot compile for web (`dart:io` in 8 files, Isar, workmanager) | "iPad-first web, one codebase" is impossible until this is ported. | Medium, bounded — but must be spiked, not assumed |
| B7 | Layout is phone-only (one `LayoutBuilder` in the whole app) | iPad kitchen/counter surfaces are new UI, not a reskin. | Expected — they are new screens anyway |

**Is the app "good enough"?** For the customer-ordering core: yes, better than
most codebases at this stage. For the operations expansion: not yet, because
of B1/B3/B5. None of those is a rewrite; all three are "decide the authority
model, then build behind it".

**The one decision that is not a task:** where the staff surfaces run (B6).
§6.1 treats it as a two-day, evidence-gated spike with a pre-agreed fallback,
because committing to Flutter-web before proving the port would be exactly the
kind of unverified promise this project's rules forbid.

---

## 2. Target system vs. what exists

| Capability | Today | Target | Gap type |
|---|---|---|---|
| Roles | one of 5, single value | owner, manager, counter, waiter, kitchen, customer; users may hold several | schema + claims + rules |
| Branch scope | one `branchId` | staff scoped to a set; owner sees all | schema + claims |
| Owner dashboard | today's aggregate: revenue sum + count, top dishes over a 200-doc cap, no channel or branch dimension | mobile-first, per-branch, per-channel, time-series, staff activity, from a server rollup | new domain + new UI |
| Counter/POS | none | iPad web: menu grid, cart, table/walk-in, cash or card, receipt | new surface + B3 |
| Waiter | none | iPad/phone web: table map, open tab, send to kitchen, request bill | new surface + tables |
| Kitchen | phone list, status-only, 8 px gaps | wall/arm's-length surface, per-item ready, delay with reason, chime | rebuild of one screen |
| Ledger | none (orders only) | append-only `transactions` with reversals, one row per money event | new domain |
| Realtime | Firestore snapshots + `presence/` | same transport, plus append-only `order_events` for activity | small |
| Inventory | none | ingredients, recipes, stock moves, deduction on sale | schema now, build phase 4 |
| Payments | Stripe card only, customer-initiated | same processor: card in-app, card-present via Terminal, cash; no card data server-side | extend, don't fork |

---

## 3. Assumptions (stated so they can be corrected, not silently baked in)

1. ~~One Firebase project per client stays the model.~~ **SUPERSEDED by the
owner: there is ONE Firebase project for all tenants.** Tenancy, its blast
radius, and the rules/index rewrite it forces are specified in
`docs/ORCHESTRATOR_BRIEF.md` §1.1 and §8. Branch scoping in this document is
still correct and is nested inside tenant scoping.
2. **The customer app is not rebuilt.** It gains `channel`-aware reads and
   keeps its current routes.
3. ~~Stripe Terminal is out of scope for v1.~~ **SUPERSEDED by the owner:
   card-present Terminal is required in the POS.** The proven server-driven
   plan replaces this item — see `docs/ORCHESTRATOR_BRIEF.md` §9. The D7 note
   below about reusing `createChargeIntentCore` still holds, with a
   `card_present` mode added.
4. **Receipts.** The owner states thermal printing is done, but no such code
   exists in any branch or worktree (see `ORCHESTRATOR_BRIEF.md` §1.3). Until
   the implementation is identified, this plan assumes on-screen plus
   browser/system print only.
5. **Localisation is a gate, not an afterthought**: every new string lands in
   both `app_en.arb` and `app_ar.arb` (the English arb has 749 quoted string
   entries; there is a plural completeness test).
6. **No new runtime dependency** (no Realtime DB, no sockets server, no
   Postgres) unless a phase explicitly proves Firestore cannot carry the load.
   §4 D6 explains why it can.

---

## 4. Architectural decisions

Each decision states the choice, the reason, and what it costs. These are the
items that need `[PLAN]` approval before implementation.

### D1 — Roles become a set; the JWT claim becomes the rules' source of truth

`users/{uid}.roles: string[]` becomes authoritative (e.g.
`['manager','waiter']`), with `role` retained as the derived primary for
back-compat. The `syncUserRoleClaims` trigger writes `roles` **and**
`branchIds` into the custom claims.

Rules stop calling `get(users/{uid})` per evaluation and read
`request.auth.token.roles` instead. That is both cheaper and the only shape
that supports "several roles" without nested conditions.

*Cost:* a token-claim cutover (existing sessions carry the old claim until
refresh). Mitigation is explicit and temporary: `hasRole(r)` prefers the claim
and falls back to the `users` document only while a `rulesVersion` flag in
`settings/` says the backfill is incomplete; the fallback is deleted in the
next phase. This is the one place where "temporary dual-read" is allowed, and
it is scoped to a single helper.

*Rejected:* keeping `get()` per rule and nesting `role == 'a' || role == 'b'`.
It multiplies rule cost by reader count and cannot express capability sets.

### D2 — Branch scope becomes a set; the owner is not a special case

`users/{uid}.branchIds: string[]`, `branchId` retained as primary. Rules helper
`inBranch(bid)`. Owner capability resolves to all branches of the project
(there is still exactly one owner identity — `settings/ownerInfo.ownerEmail`);
manager/counter/waiter/kitchen resolve to their `branchIds`.

*Cost:* staff assignment UI (owner invites a user, picks roles + branches).
Invites already half-exist through the admin gateway + role claim path; this
makes it explicit and auditable.

### D3 — Order mutation authority moves into callables (the pivot)

Direct client writes to `orders` shrink to **customer-safe** operations only
(cancel while `pending`, nothing else). Everything a staff surface does becomes
a callable:

| Callable | Effect | Capability |
|---|---|---|
| `createStaffOrder` | channel `counter`/`waiter`/`phone`, cash or card-verified; server-priced | `order.create` |
| `transitionOrder` | status state machine + branch/role check + event row | `order.transition` |
| `setItemReady` | per-line ready/held + event row | `order.item_ready` |
| `addOrderItems` | appends lines to an open ticket, server-priced | `order.create` |
| `closeTicket` | payment + ledger + table release, atomic | `payment.take` |
| `reverseTransaction` | ledger reversal, never a delete | `ledger.reverse` |
| `openTable` / `seatTable` / `clearTable` | table state, optimistic version | `table.manage` |
| `adjustStock` / `receiveStock` | phase 4 | `inventory.write` |

Every callable: App Check enforced, `assertStaffRoles` + `assertBranchScope`,
zod-validated input, idempotency key where money moves, and a transaction that
writes the domain change **and** its `order_events` row together.

Rules then simply deny client writes to `orders` fields outside the customer
allowlist, and deny `transactions`, `order_events`, `stock_moves`, `alerts`
entirely (`allow write: if false` — the pattern already used for `audit_log`).

*Cost:* the richest single change in the plan, plus the rules-emulator suite
must grow a case per callable. *Benefit:* one permission gate instead of
~30 rule clauses per role, and the combinatorial explosion never happens.

### D4 — Dine-in is an order, not a parallel "tab" entity

An open table ticket **is** an `orders/{id}` document with
`isOpenTab: true`, `tableId`, `channel: 'waiter'`, `customerId: null`,
`guestName` optional. Adding items appends lines via `addOrderItems`; the
kitchen sees real kitchen tickets immediately; `closeTicket` takes payment,
flips `isOpenTab` false, writes the ledger row and releases the table — all in
one transaction.

*Why:* the kitchen stream, the printer, the status machine and analytics all
already key off `orders`. A separate `tabs` collection would force every one of
them to learn a second source.

*Cost:* `OrderStatus` gains no new state; the "open" concept is a boolean plus
`totals` that grow. Analytics must exclude `isOpenTab: true` from revenue
(it has no captured payment yet) — enforced by only counting `transactions`.

### D5 — Ledger is append-only, derived at write time, never recomputed

`transactions/{txId}` is written by `closeTicket` / `createStaffOrder` /
the existing customer `createOrder` path, in the same transaction as the order
state change. Reversals are new rows with `reversalOf`, not edits and not
deletes. A row snapshots item names and prices, so a menu price change never
rewrites history.

Rules: `allow read` for owner/manager scoped by branch; `allow write: if false`.
The only writer is the Admin SDK inside a callable.

*Cost:* one extra document write per money event. *Benefit:* the owner
dashboard, the Z-report and any future export read one immutable collection
instead of reconstructing money from mutable orders.

### D6 — Firestore snapshots stay the transport; add one append-only event stream

The existing mechanism (branch-scoped order listeners, `presence/` documents,
`deliveries/{orderId}`) does not need replacing. A single restaurant branch is
tens of listeners and hundreds of writes a day; the composite indexes for
`branchId + status + createdAt` already exist in `firestore.indexes.json`.

What is missing is a change feed the surfaces can react to (kitchen chime,
"table 4 sent 2 more items", "cash drawer opened"). Add
`order_events/{eventId}`, append-only, CF-written, one row per meaningful
change, with a per-branch composite index on `branchId + at`.

**Explicit non-goal:** no WebSocket server, no Pub/Sub-to-client hop, no
Realtime Database. The smallest viable upgrade is "one collection plus one
index", and nothing in the target workload justifies more.

### D7 — Payments: extend the core, never fork it

`createChargeIntentCore` is already the one place money is derived. POS card
payment reuses it unchanged (`createdBy` = the staff uid, which is exactly what
`createOrder`'s ownership check wants). Cash never creates a PaymentIntent:
`createStaffOrder` computes the same totals with the same helpers
(`verifyMenuPricing`, `resolveChargeTaxAndPromo`, `computeAmountCents`,
`validateDeliveryFee`) and writes the ledger row with
`paymentMethod: 'cash'`, `paymentRef: {receivedCents, changeCents}`.

The extraction required is small and safe: move the pricing/tax/promo
composition out of `createChargeIntentCore` into a shared
`priceCartCore(items, ctx)` used by both paths, so the POS cannot drift from
the customer app. The existing `order_create_payload_contract_test.dart` and
the MONEY-1 cross-check tests are the regression net for that move.

*Guardrails on the cash path:* staff claim required, branch-scoped, positive
amount, no negative or zero totals, server-recomputed discount cap, and an
idempotency key so a double-tap cannot double-write a ledger row.

---

## 5. Data model (additive; nothing below exists today)

Existing collections keep their shape. New fields on `orders` and `users` are
**server-written only**.

```text
users/{uid}
  roles: string[]            # NEW authoritative, e.g. ['manager','waiter']
  branchIds: string[]        # NEW
  role: string               # legacy, derived = roles[0]
  branchId: string           # legacy, derived = branchIds[0]
  activeBranchId: string     # NEW UI preference only — never an auth input
  staffStatus: 'active'|'invited'|'disabled'

orders/{orderId}
  # existing: branchId, customerId, items[], totals, status, createdAt, ...
  channel: 'app'|'counter'|'waiter'|'phone'|'kiosk'|'platform'      # NEW
  staffId: string|null        staffRoles: string[]|null            # NEW audit
  tableId: string|null        tableLabel: string|null              # NEW
  guestName: string|null      isOpenTab: bool                      # NEW
  paymentMethod: 'card'|'cash'|'external'|'unpaid'|'comp'          # NEW
  paymentRef: map|null                                             # NEW
  items[].lineId, .readyAt, .readyBy, .course, .notes              # NEW
  kitchen: {acceptedAt, acceptedBy, readyAt, delayReason, delayNote} # NEW

order_events/{eventId}        # append-only, CF-only
  orderId, branchId, type: 'created'|'items_added'|'item_ready'|
    'status'|'delay'|'payment'|'closed'|'reversed',
  from, to, lineId, actorUid, actorRoles, channel, at, meta{}

transactions/{txId}           # append-only ledger, CF-only
  orderId, orderNumber, branchId, channel, staffId, staffRoles,
  customerId|null, guestName|null, tableId|null,
  itemsSubtotalCents, taxCents, tipCents, discountCents,
  deliveryFeeCents, totalCents, currency,
  paymentMethod, paymentRef, providerFeeCents|netCents,
  items[]  # immutable name/qty/unitPriceCents/lineTotalCents snapshot
  occurredAt, recordedAt, status: 'captured'|'reversed',
  reversalOf|null, reversalReason|null, idempotencyKey, schemaVersion

tables/{tableId}
  branchId, label, zone, seats,
  status: 'free'|'seated'|'ordering'|'served'|'bill_requested'|'needs_cleaning',
  currentOrderId|null, assignedWaiterId|null, openedAt|null,
  version  # optimistic lock, updatedAt

staff_shifts/{branchId}_{uid}_{yyyymmdd}
  branchId, uid, roles, clockInAt, clockOutAt,
  ordersCount, salesTotalCents        # phase 3, feeds owner "who's on"

daily_rollups/{branchId}_{yyyyMMdd}   # CF-maintained, idempotent
  branchId, date, currency,
  revenueByChannel{app,counter,waiter,phone,platform},
  ordersCount, avgTicketCents, refundsCents,
  topItems[{menuItemId, name, qty, revenueCents}],
  staffActivity{uid:{orders, revenueCents}}, updatedAt, version

ingredients/{ingredientId}      # phase 4 - schema created in phase 1
  name, unit 'g'|'kg'|'ml'|'l'|'each', sku, costPerUnitCents,
  parLevel, lowStockThreshold, allergens[], isActive, supplier

recipes/{menuItemId}            # phase 4
  menuItemId, lines[{ingredientId, qty, unit}], yieldQty, version

branches/{branchId}/stock/{ingredientId}   # phase 4, per-branch quantity
  qty, updatedAt, lastCountAt

stock_moves/{moveId}            # append-only journal, CF-only
  branchId, ingredientId,
  type: 'order_deduction'|'receipt'|'waste'|'adjustment'|'reversal',
  qtyDelta, unit, orderId|null, actorUid, at, note

alerts/{alertId}                # CF-written
  branchId, type: 'low_stock'|'order_delayed'|'cash_variance',
  ingredientId|null, orderId|null, severity,
  createdAt, acknowledgedAt, acknowledgedBy
```

Note on `daily_rollups`: Firestore aggregates cannot `GROUP BY`, so without a
rollup the owner dashboard costs one aggregate query per branch per metric.
That is acceptable for a handful of branches but useless for a 12-month chart.
Writing a rollup row per branch per day is ~365 writes per branch per year and
removes the whole class of dashboard latency problems. It is worth doing in
phase 1, not later.

---

## 6. Where the staff surfaces run (the one decision to make early)

### 6.1 The options, honestly stated

| Option | What it costs | What it risks |
|---|---|---|
| **A. Port to Flutter web, add `/staff` routes in the same app** | 8 `dart:io` files become conditional; a `WebSyncQueue implements SyncQueue`; workmanager/Crashlytics/Isar no-ops on web; `flutter create --platforms=web`; responsive layout shell for the new screens | One shared codebase, one theme engine, one l10n set, one PWA per client. Risk: `isar_community` and its transitive deps may still break a web compile, and the app may pull in more native surface than the census shows |
| **B. Separate web frontend (React/Next) sharing Firestore + callables** | A second UI codebase; theme tokens and `client_config.json` semantics must be re-implemented; a second l10n pipeline | Fastest path to iPad today; but white-label theming is the product, and duplicating it invites exactly the drift this repo fights |
| **C. iPad native (iOS build of the existing app)** | Nothing new to port; App Store or MDM distribution per client | Contradicts the stated "responsive web first"; slow per-client install; still phone-shaped until the layout work is done anyway |

**Recommendation: A, gated by a spike.** Reason: A is the only option that
keeps per-client theming, strings and config in one place, and the port is
bounded to an enumerated set of files. B is the fallback if the spike fails,
and it is a real fallback — the backend, rules and callables are identical
either way, so choosing B later costs only the staff chrome, not the domain.

### 6.2 The spike (timeboxed: 2 days, phase 1, produces evidence not opinion)

Success criteria, all of which must hold:

1. `flutter build web` completes for an entrypoint that imports `core_app`'s
   shared body.
2. The built app boots to a route with `kIsWeb` true, Firebase initialised,
   and `presence/` writing disabled.
3. `WebSyncQueue` drains a queued kitchen status update against the emulator.
4. A golden-free smoke test renders one admin screen at 1024×768 without
   overflow (this is where the phone-shaped layout gets exposed).

If any criterion fails after the timebox, the decision is **B**, recorded in
`DECISIONS_LOG.md`, and phase 2 is built on it. Do not extend the spike
silently.

### 6.3 Shared consequences either way

- Staff surfaces are **routes in the same deployed artifact**, role-gated at
  the router and again on the server. A separate `staff.` subdomain is a
  hosting decision, not an architecture one.
- iPad installability needs a per-client web manifest (name, icons from
  `app.icon`, theme colour) generated by the whitelabel tool, not hand-written.
- Safari specifics: no `window.print`-dependent receipt flow without a visible
  fallback, and no assumption that a PWA can stay in the foreground — the
  kitchen surface must survive a reload mid-service.

---

## 7. Phased plan

Every phase ends demoable, ends with green gates, and leaves the fleet
generatable. Estimates assume one developer and are given in working weeks;
they are planning figures, not commitments.

Gate definition used below (applies to every phase):
`flutter analyze` clean · new/changed Dart tests pass · rules-emulator suite
green including one new case per changed collection · `npm test` in
`core_app/functions` green · generator dry-run still clean for an existing
client config · `docs/` updated with what actually shipped.

### Phase 1 — Roles & permissions foundation, ledger, owner dashboard v1 (3 weeks)

**Track A — identity and authority**

1. `permissions.ts` (pure, unit-tested): capability map
   `owner → *`, `manager → order.*, payment.take, table.manage, report.read,
   ledger.read, menu.write`, `counter → order.create, order.item_ready,
   payment.take`, `waiter → order.create, order.item_ready, table.manage`,
   `kitchen → order.transition, order.item_ready`,
   `customer → own orders only`. No Firestore imports in this module so it is
   cheap to test exhaustively.
2. `assertStaffRoles`, `assertBranchScope`, `assertCapability` in `access.ts`,
   replacing the single-role gate; existing callables migrate to them.
3. `users.roles` / `users.branchIds` + claims + backfill script
   (`tool/migrate_roles.js`, idempotent, dry-run first, reports counts).
4. Rules helpers `hasRole()` / `inBranch()` reading claims, with the temporary
   `rulesVersion` fallback described in D1, plus emulator cases for
   multi-role, wrong-branch and stale-claim.
5. Router and `RoleRouterScreen` learn the new roles; `UserRole` gains
   `counter` and `waiter` with presentation-only capabilities (the existing
   pattern already separates UX affordances from access decisions — keep it).

**Track B — money truth**

6. `transactions` collection + `writeTransactionCore` used by the existing
   customer `createOrder` path first (so the ledger is correct before POS
   exists). Reversal callable + seller-side reason codes.
7. `daily_rollups` writer: a Firestore trigger or scheduled function that
   recomputes one branch-day from `transactions` idempotently
   (`version` compare-and-set).

**Track C — owner dashboard v1**

8. Mobile-first dashboard over `daily_rollups`: today/7d/30d revenue, order
   count, average ticket, revenue by channel, top items, per-branch
   comparison, refunds. Responsive from the start (the first place breakpoints
   are introduced deliberately).
9. Staff activity from `presence/` (who is online, which branch) — read-only
   in v1.

**Track D — web spike** (§6.2), 2 days, decision recorded.

**What now exists:** multi-role staff accounts scoped to branch sets; a server
authority layer that every later callable uses; an append-only ledger written
for every money event including the existing customer flow; an owner dashboard
that reports revenue by branch and channel from rollups.

**What I can demo on camera:**

- One account holding `manager` + `waiter` opens the app and sees both
  surfaces; a second account with `waiter` only is refused the manager route
  *and* refused by the server (show the 403 from the callable, not just the
  hidden button).
- A customer order placed in the app appears in the ledger with channel
  `app`, then in the owner dashboard's revenue-by-channel within the rollup
  window; a reversal of it appears as a second row, not a deletion.
- Owner dashboard on a phone at 390 px and on an iPad at 1024 px, three
  branches, branch switcher.
- The spike result: either a web build booting, or a written decision to take
  option B.

**What's next:** counter and kitchen surfaces on the chosen platform, plus the
staff-order path they need.

### Phase 2 — Counter (POS) and kitchen (3 weeks)

**PR-1: the staff order path (do this before any POS pixel)**

1. Extract `priceCartCore()` from `createChargeIntentCore`; both the customer
   and staff paths call it. Regression net: the existing contract and MONEY-1
   tests.
2. `createStaffOrder` — channel, branch, cash or card (card verifies the
   PaymentIntent exactly as `createOrder` does today), `customerId: null`,
   `guestName`, `staffId`, `paymentMethod`, atomic `transactions` row,
   `order_events` row, idempotency key.
3. `transitionOrder` / `setItemReady` callables; rules shrink to deny client
   order writes outside the customer cancel allowlist.
4. `openTable` / `seatTable` / `closeTicket` / `clearTable` with optimistic
   `version`; table release inside the same transaction as the ledger row.

**Counter surface**

5. iPad-first layout: category rail, menu grid with 64 px+ tap targets, cart
   rail, quantity/bulk actions, discount with server-side cap, tip, tender
   (cash with change calculation, card via PaymentIntent), receipt with a
   print/searchable-order-number fallback.
6. Walk-in, phone order, and "assign to table" as first-class choices.
7. Offline posture: the POS may *queue* a cash order when connectivity drops
   (reusing the existing `SyncQueue` abstraction) but must never show a
   captured payment that the server has not confirmed. If a queued order is
   ultimately rejected server-side, the UI must surface a visible exception
   list, not a silent drop.

**Kitchen surface**

8. Replace `kitchen_dashboard.dart`'s phone list with an arm's-length board:
   columns by status, per-line ready toggles, per-line held/out-of-stock,
   per-order delay with a reason (writes `alerts`), elapsed timer, chime on
   `order_events` insert, and a "reprint" affordance deferred to H2.
9. Item-level ready must not change `OrderStatus`; it writes `items[].readyAt`
   and an event. Order-level `ready` stays the manager's/counter's decision.

**What now exists:** staff can ring up a walk-in for cash or card without a
customer account; counter and kitchen share one order in real time; every sale
lands in the immutable ledger; the kitchen can mark individual dishes done and
flag delays.

**What I can demo on camera:**

- Cash sale on an iPad: menu → cart → cash tendered → change → receipt, and
  the ledger row on the owner dashboard seconds later.
- Card sale through the existing Stripe flow with `createdBy` = staff, and the
  server reject a tampered price (change a line price in the client and show
  the `failed-precondition`).
- Kitchen on a second device: the counter order appears without refresh;
  mark one line ready, delay the other with a reason; the counter sees both.
- Denial demo: a `kitchen`-only account calling `createStaffOrder` is refused
  by the server (403, shown live), even though the button is never rendered
  for that role; a `counter` account calling `reverseTransaction` is refused
the same way.

**What's next:** waiter floor work and multi-branch drill-down.

### Phase 3 — Waiter surface and multi-branch owner view (2 weeks)

1. Table map per branch (zones, seats, status colour, version-guarded drag),
   assign/transfer waiter, merge and split a ticket where the kitchen allows.
2. Waiter flow: seat → send items → add rounds → request bill → counter closes.
3. `staff_shifts` clock-in/out, feeding owner "who is on the floor now" and
   per-staff sales in rollups.
4. Owner dashboard: branch drill-down, day-of-week/hour heatmap from rollups,
   staff leaderboard, refunds and voids with reasons, export (CSV) as a
   server-generated file, not a client loop.

**What now exists:** a full dine-in loop (table → kitchen → bill), staff
accountability, and multi-branch reporting that survives a year of data.

**What I can demo on camera:** open a table on a phone, send two rounds from
the waiter view, watch the kitchen board update, close the bill at the counter,
see the table free and the branch revenue update; switch branches in the owner
dashboard and show the per-branch split.

**What's next:** inventory — schema already shipped, behaviour added here.

### Phase 4 — Inventory (3 weeks)

1. Ingredients CRUD (owner/manager), units and cost, par levels, allergens.
2. Recipes per menu item; versioned so historical deduction stays explainable.
3. Deduction on order commit inside the existing transaction; `stock_moves`
   journal; idempotent against replayed events (deduction keyed by order line).
4. Receiving, waste, stock-count adjustment with reason.
5. Low-stock alerts and a "what ran out today" view; optional: auto-disable a
   menu item at zero stock (must be a deliberate opt-in, never silent).

**What now exists:** stock moves when food sells, with a journal that can
answer "why is the walk-in short" without guesswork.

**What I can demo on camera:** set a recipe, sell the dish, watch stock drop
and the journal row appear, then trip the low-stock alert; reverse the sale and
show the stock come back via a compensating move (never an edited row).

**What's next (not in this plan):** purchasing/POs, supplier portal, multi-
project SaaS control plane, Stripe Terminal, thermal printing.

---

## 8. White-label fleet impact (the detail that decides whether this ships)

The factory is the product. Every phase must be gated not only on `core_app`
being green but on **a freshly generated client still working**.

### 8.1 The mechanism, as it exists

- `core_app/tool/whitelabel.dart --config <path>` creates
  `apps/<packageName>/` with a thin `main.dart`, a `GeneratedApp`, per-project
  `firebase_options.dart`, config loader, and a `backend/` folder containing
  **copies** of `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
- `backend/firebase.json` points functions at the shared
  `../../core_app/functions`, so function changes reach every client on the
  next `firebase deploy`; **rules and indexes do not** — a copy is a snapshot.
  Verified today: `apps/halal_boyz/backend/firestore.rules` is byte-identical
  to `core_app/firestore.rules`. That will stop being true the moment phase 1
  edits rules, unless the fleet is handled deliberately.

### 8.2 What every phase must therefore add to the factory

| Item | Why | Where it lands |
|---|---|---|
| Rules/index parity gate | copied rules silently go stale per client | a test asserting each `apps/*/backend/*` equals `core_app/*`, or a `--refresh-backend` generator mode plus that test |
| New rules + indexes for every new collection | `tables`, `transactions`, `order_events`, `stock_moves`, `alerts`, `daily_rollups` are useless if a client's deployed rules deny them | `core_app/firestore.rules`, `core_app/firestore.indexes.json`, regenerated into each client |
| New config keys in **both** validators | the runtime gate and the generator gate are pinned together by tests | `AppConfig` + `ClientConfig.validate()` + schema fixtures |
| New strings in `en` and `ar` | 749-line arb sets, plural completeness test exists | `core_app/lib/l10n/*` |
| Web manifest/icons per client | iPad installability is per brand | generator output next to `flutter_launcher_icons.yaml` |
| Per-client deploy runbook update | new functions + new rules must be deployed per project | `backend/DEPLOY.md` template in the generator |

### 8.3 Per-phase fleet gate (in addition to the code gates)

1. `dart run tool/whitelabel.dart --config <existing client> --dry-run` — no
   new validation errors.
2. Generate a scratch client into a temp package name from the Halal Boyz
   config and run the generator's own post-gates (`flutter test`, debug APK).
   This is the factory's own definition of "works" (exit 72/73) and it is the
   cheapest possible regression test for fleet breakage.
3. Delete the scratch client; the fleet gate must never leave a stray app.

### 8.4 The honest cost

N clients × new surfaces means N Firebase projects each needing a functions
deploy and a rules deploy on every release. That is already true today; this
plan does not make it worse, but it does add collections to deploy. If the
client count grows past a handful, the generator should emit a single
`deploy_all.sh` that iterates `.firebaserc` files — a small, later addition.

---

## 9. Pentagi phase — vulnerability scanning (later, phased as its own gate)

### 9.1 What it is and what it needs

PentAGI is self-hosted, runs as a Docker Compose stack (2 vCPU / 4 GB RAM /
25 GB disk / internet), needs at least one LLM provider key, exposes a web
console on `https://localhost:8443`, and runs each "flow" in its own sandbox
container with 20+ tools (nmap, sqlmap, Metasploit, a browser scraper). It
plans, executes and reports; it is authorised-testing-only software.

Sources: <https://pentagi.com/get-started>,
<https://pentagi.com/docs/concepts/architecture>,
<https://pentagi.com/docs/getting-started/first-flow/>.

### 9.2 What it can and cannot tell us about *this* system

| Surface | Pentagi value | Why |
|---|---|---|
| Staff web app (PWA) | **High** | real HTTP surface, sessions, forms, file/print flows, IDOR on order IDs |
| Callable HTTPS endpoints | **High** | each callable is an HTTP endpoint; auth/claim handling and input validation are exactly what it probes |
| Flutter mobile app | Low | not a browsable target; binary analysis is out of scope |
| `firestore.rules` | **Low — do not expect coverage** | rules are enforced by the Firebase backend for SDK clients; a generic web pentest never exercises them. The existing emulator suite (`core_app/test/rules/*`) remains the authority for rules, and must grow a case per new collection and per new callable |
| Stripe / payment correctness | Low | server-side pricing must be proven by contract tests, not by a scanner |

So Pentagi is a **complement** to the rules emulator and the money contract
tests, not a replacement. That distinction is the difference between a security
phase and security theatre.

### 9.3 Preconditions (all must be true before the first flow)

1. A **staging** Firebase project with seeded users for every role and branch —
   never production, never a client's live project.
2. Written authorisation naming the exact hosts in scope, and an outbound
   network note: the sandbox publishes callback ports 28000–29999 on every
   docker-host interface by default, so the host must be firewalled or
   dedicated (`https://pentagi.com/docs/getting-started/manual-installation/`
   documents this; it is the single most common self-host mistake).
3. Seeded data only — no real customer PII, no live Stripe keys. Test-mode keys
   only.
4. An LLM key supplied by you (the stack needs one to reason).

### 9.4 Scope of the first flow (written as a prompt, reusable)

> Target: the staff PWA and callable endpoints on the staging project only.
> Objective: authentication and authorisation weaknesses — privilege escalation
> between roles, cross-branch access, IDOR on order/table/transaction IDs,
> tampering with prices, quantities, payment method and totals, replay of
> idempotency keys, and injection into any field that reaches Firestore or a
> query. Stay inside the named hosts; report only reproducible findings with
> the exact request sequence.

### 9.5 How findings get handled (so the phase produces fixes, not a PDF)

1. Triage each finding into: real / needs-repro / by-design. A finding without
   a reproduction is not accepted.
2. Real findings get a failing test first — for callables, an emulator test;
   for the web surface, a rules/contract test or a targeted case in the
   `core_app/test` suite — then the fix.
3. Re-run the same flow against the fixed staging build to confirm closure.
4. Anything that cannot be closed before launch becomes a `DEFERRED.md` row
   with an owner and an expiry — the register's existing discipline.

---

## 10. Risks, and what would change the plan

| Risk | Likelihood | Effect | Mitigation baked into this plan |
|---|---|---|---|
| Web port fails or is far larger than the census suggests | Medium | Phase 2 shape changes | timeboxed spike in phase 1 with a written fallback (option B) and an identical backend either way |
| Moving order writes into callables breaks the customer app | Medium | regression in the one flow that earns money | do it in phase 1/2 *before* POS exists, behind contract tests that already exist (`order_create_payload_contract_test.dart`, MONEY-1 cases) |
| Claims cutover leaves stale-role sessions | High | a demoted manager keeps rights for up to an hour | explicit temporary `rulesVersion` fallback + force-refresh callable on role change (the `syncUserRoleClaims` trigger already fires; add `revokeRefreshTokens` on demotion) |
| Rules copies diverge per client | High if forgotten | a client ships with old rules | parity test / `--refresh-backend` (§8.2) |
| Scope creep into purchasing/POs/native | High | the plan never finishes | §11 lists what is deliberately out of scope |
| Inventory deduction gets out of step with sales | Medium | silent stock drift | deduction inside the same transaction as the ledger row, journal-only corrections, idempotent per order line |
| Solo-founder operational load (N clients × deploys) | Medium | launches slip | per-phase fleet gate makes deploy cost visible early, not at launch |

What would make me revise this plan: if the spike shows Flutter web needs more than
the 8 enumerated files plus adapters, option B is chosen and phase 2 keeps its
scope but changes platform; if the rules-emulator suite cannot express a
callable-only write model cheaply, D3 is revisited in favour of a per-collection
CF proxy with a narrower rules surface.

---

## 11. Deliberately out of scope

- Multi-tenant SaaS control plane (one dashboard provisioning many client
  Firebase projects). Compatible with this plan; not part of it.
- ~~Stripe Terminal~~ — now in scope (`ORCHESTRATOR_BRIEF.md` §9).
- ~~Thermal printing~~ — owner states it exists; evidence contradicts; pending
  clarification (`ORCHESTRATOR_BRIEF.md` §1.3).
- Purchasing, supplier portal, POs, wastage forecasting.
- Payroll, scheduling, timeclock beyond the minimal `staff_shifts` needed for
  "who is on the floor".
- Loyalty changes beyond what exists.
- Migrating Firestore to SQL, or introducing a realtime broker.

---

## 12. Sequencing at a glance

```text
Phase 1 (3w)  roles+claims+branch sets ─┬─ ledger + rollups ─┬─ owner dash v1
                                        └─ web spike (2d, decision)
Phase 2 (3w)  priceCartCore ─ createStaffOrder ─ transition/item-ready
              ─ tables/closeTicket ─┬─ POS iPad ─┬─ kitchen board
Phase 3 (2w)  table map + waiter flow + shifts + branch drill-down
Phase 4 (3w)  ingredients + recipes + deduction + journal + alerts
```

Phase 2 cannot start before Phase 1's authority layer lands, because every POS
callable depends on `assertCapability` and on the ledger being correct. Phase 4
can start later without schema shame because its collections and rules are
created in Phase 1 (empty, denied to clients, with zero UI).

---

## 13. Decisions needed from you before implementation

1. **Platform for staff surfaces** — approve the two-day spike with option B as
   the pre-agreed fallback (§6.1).
2. **Cash handling** — confirm cash is in scope for v1 POS (it is the single
   biggest driver of the new staff-order path).
3. **Who may reverse money** — owner only, or manager too with a reason code?
   The plan assumes owner + manager-with-reason.
4. **Menu write authority during service** — can a counter user 86 an item
   (mark unavailable) without a manager? The plan assumes yes, via
   `menu.availability` capability, because a sold-out item must be actionable
   at the till.
5. **Whether `daily_rollups` may be recomputed from scratch at any time** (it
   should be treated as a cache, never as the record) — confirm, because it
   decides whether the dashboard can ever disagree with the ledger.

---

## 14. Status of this document

- Written against HEAD `7c139d5c` on `cline/p32-golden-gates`, dirty working
  tree, 11 worktrees.
- No code, rules, schema or config was modified to produce it.
- Claims about current behaviour are evidenced in
  `docs/PLATFORM_EXPANSION_EVIDENCE.md`; anything not tested there is marked
  UNVERIFIED and should not be repeated as fact.
- This is a `[PLAN]`. Implementation waits for approval, per the constitution
  in `<other-project>\AGENTS.md`.

