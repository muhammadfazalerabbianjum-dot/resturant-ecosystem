> **SUPERSEDED.** Use `docs/ORCHESTRATOR_HANDOFF.md` instead — it is
> self-contained and assumes no prior knowledge. This file is kept for the
> extra detail in its §1 and §9.

# ORCHESTRATOR BRIEF — Carnama restaurant operations platform

**Purpose.** This is the complete handoff: what the repo is, what is proven,
what is missing, what the owner has decided, and what must be established.
An orchestrator reads this and issues instructions; an implementer executes
them. It contains no speculation presented as fact.

**How to read the tags.** Every material statement carries one:

| Tag | Meaning |
|---|---|
| **[PROVEN]** | Measured in this working tree. Carries `file:line`, a command, or a diff. |
| **[DECIDED]** | The owner stated it. Not up for redesign; consequences are listed. |
| **[OPEN]** | Needs an owner or orchestrator decision. A recommendation is given, not a default. |
| **[UNVERIFIED]** | Plausible, not tested here. Must not be repeated as fact until proven. |

**Authority order when instructions conflict:** (1) the constitution in
`<other-project>\AGENTS.md`, (2) this brief's **[DECIDED]** items,
(3) `docs/PLATFORM_EXPANSION_PLAN.md` for design detail, (4)
`docs/PLATFORM_EXPANSION_EVIDENCE.md` for measurements, (5) everything else
(including `PROJECT_STATUS.md`, `FINAL_HANDOVER.md`, which are stale).

**Baseline:** branch `cline/p32-golden-gates`, HEAD `7c139d5c`, working tree
dirty, 11 git worktrees, ~30 branches. Flutter 3.41.2 / Dart 3.11.0 /
Node v24.13.1. **[PROVEN]**

---

## 1. Owner decisions, and what each one actually costs

These four change the design in `PLATFORM_EXPANSION_PLAN.md`. They are
recorded here with their consequences because three of them are not
cosmetic.

### 1.1 **[DECIDED] One Firebase project**

Not one project per client. A single Firebase project serves every tenant.

*Current state:* **[PROVEN]** each generated client gets its own project
(`apps/halal_boyz/backend/.firebaserc` → `demo-tenant`), its own copied
rules and indexes, and functions shared by path from
`../../core_app/functions`. There is **zero tenancy in the rules** —
`grep -c clientId core_app/firestore.rules` returns `0`.

*What must be built:*

| Concern | Consequence |
|---|---|
| Data isolation | every document in every collection needs `tenantId`; every rule path must check it; every query must filter on it |
| Rules | 811 lines become tenant-aware. A single missed check leaks one client's data to another — this is the highest-severity risk in the whole programme |
| Indexes | all 23 composite indexes need `tenantId` prepended; `firestore.indexes.json` is rewritten |
| Auth | one shared user pool: a customer of tenant A can sign in to tenant B's app. Membership must be explicit (`users/{uid}.tenantIds[]` or `members` subcollection) and checked at sign-in |
| Claims | JWT gains `tenantId` (single, from the app the user signed in through) plus `roles` and `branchIds` |
| Owner identity | `settings/ownerInfo.ownerEmail` is project-global today; it becomes per-tenant (`tenants/{tenantId}/settings/ownerInfo` or a `tenants/{tenantId}` root doc) |
| FCM | one sender; topics and token→tenant mapping must be tenant-namespaced or notifications cross clients |
| App Check | enforced project-wide; each web client needs its own reCAPTCHA site key for its own domain |
| Deployment | **simpler**: one `firebase deploy` reaches all clients. Also **riskier**: a rules regression ships to everyone at once |
| Blast radius | one project = one compromise distance. Compensating controls: deny-by-default per collection, CF-only writes for money, a cross-tenant denial test per collection in CI |

*Recommended enforcement shape* **[OPEN — see §14 Q1]**: keep collections
flat and add a mandatory `tenantId` field (single-line change at each of the
~297 `collection('orders')`-style call sites plus one `where` clause), with
rules helpers `sameTenant(doc)` / `claimsTenant()` applied on **every** match
block, rather than restructuring every path under `tenants/{tenantId}/…`.
Rationale: the flat model preserves 23 existing indexes' shape, keeps the
297 call sites a mechanical edit, and is provable by an emulator test that
enumerates every collection and asserts a cross-tenant read is denied.
Path-rooting is structurally safer but is a multi-week mechanical refactor of
every query in the monorepo with high regression risk on a codebase whose only
safety net is its tests. Either way the acceptance test is the same; the
choice is cost vs. structure and it is the orchestrator's call.

*Migration of the existing client* **[OPEN — §14 Q2]**: does `demo-tenant`
get migrated into the shared project (data export/import, users re-created,
Stripe keys moved) or does the shared project start fresh with Halal Boyz as
tenant #1 and the old project retired read-only?

### 1.2 **[DECIDED] Stripe Terminal is required for POS**

Card-present is in scope for v1, not deferred. **[PROVEN]** the repo has only
a placeholder: `packages/core/lib/src/payment/nfc_terminal_service.dart` is
stubbed with `TODO_DEPLOY` and an injectable `fetchConnectionToken`, and there
is no server endpoint, no reader registration and no `card_present` usage
anywhere (`git grep -i "connectionToken|card_present|TerminalLocation"`
returns only that file and its test).

*Proven integration path* — this matters because the obvious one does not
exist:

- Stripe ships **no official Flutter Terminal SDK**. The pub.dev package
  `stripe_terminal` is third-party and limited to Bluetooth readers on
  Android (it lists the missing features itself).
- Stripe's own guidance for smart readers (WisePOS E, S700/S710, T600,
  Verifone) is the **server-driven integration**: the POS never talks to the
  reader directly; our Cloud Functions call the Stripe API and the reader
  talks to Stripe over the internet.
- The JavaScript SDK is the alternative, but Stripe documents that it
  requires POS and reader on the same LAN with working local DNS, and that
  Chrome 142+ (Oct 2025) requires an explicit local-network permission —
  which is precisely why server-driven is recommended for smart readers.

Consequence: **card-present does not depend on the staff-surface platform.**
It works identically whether the POS is Flutter web or native, because the
integration is server-side. That removes the single biggest argument that the
web-port decision and the payment decision are coupled.

*What must be built:* a `terminals` collection and `branches.terminalLocationId`;
a connection-token endpoint (only if the SDK path is chosen); a
`processTerminalPayment` callable that creates the PaymentIntent with
`payment_method_types: ['card_present']` and calls
`terminal.readers.processPaymentIntent`; reader action status via webhook or
poll; and a `card_present` variant of the existing intent core, because
`automatic_payment_methods` (used today) is not the right shape for Terminal.
Full task list in §9 below, which supersedes the Terminal deferral in
`PLATFORM_EXPANSION_PLAN.md`.

*Known limitations to design around* **[PROVEN from Stripe docs]**: no offline
payments with server-driven Terminal; no Bluetooth readers; one SDK
connection per reader at a time; the PaymentIntent amount is fixed before the
reader collects, so tip must be decided in the POS cart, not adjusted
afterwards by a hidden step.

### 1.3 **[DECIDED] Thermal printing is done — **[contradicted by the tree]**

The owner states it is done. The tree says otherwise, and this is the one item
where I could not reconcile the statement with evidence:

- `git grep -i "thermal|escpos|esc/pos"` across **all ~30 branches** →
  zero hits in `.dart`, `.ts`, `.kt`, `.swift`, `.java`.
- `git grep -i "printer|printing\.|esc_pos"` across tracked Dart → zero hits.
- No printing dependency in `core_app/pubspec.yaml`, `packages/core/pubspec.yaml`
  or `apps/halal_boyz/pubspec.yaml` (no `printing`, `esc_pos_utils`,
  `sunmi_*`, `star_*`).
- No uncommitted file matching `thermal|escpos|print` in **any of the 11
  worktrees** (`git status --porcelain -uall` per worktree).
- `core_app/DEFERRED.md` still records **H2 Kitchen LAN Thermal Printing** as
  "Unstarted — KEPT … there is no implementation in the tree".

**This is not a challenge to the owner, it is a missing input.** Three
possibilities: it lives in a repo/path outside `<repo>`; it was done on
a device (e.g. a Sunmi terminal's built-in printer app) rather than in this
code; or the deferral row was never updated. **[OPEN — §14 Q3]** Until the
owner points at the implementation, the POS receipt path must be planned as
unbuilt, and any claim that thermal printing works would be fabrication.

### 1.4 **[DECIDED] Localisation stays a gate**

**[PROVEN]** `core_app/lib/l10n/app_en.arb` has 749 quoted string entries,
an Arabic set exists, and `core_app/test/l10n_plural_completeness_test.dart`
enforces plural completeness. Every new surface adds keys to both locales in
the same commit; a missing Arabic key fails the gate.

---

## 2. Repo map (what exists, measured)

```text
<repo>
├─ pubspec.yaml            workspace root (members inline; no melos.yaml)
├─ core_app/               package "labs" — the shared app body (142 lib files)
│  ├─ lib/app_bootstrap.dart      16-step boot chain, all fleet apps enter here
│  ├─ lib/app/app_router.dart     42 routes incl. /owner /manager /kitchen /delivery
│  ├─ lib/features/               auth, orders, admin, checkout, driver, loyalty …
│  ├─ lib/l10n/                   en + ar arb files
│  ├─ functions/                  TypeScript, 2,282 lines in src/index.ts
│  ├─ firestore.rules             811 lines — the access authority
│  ├─ firestore.indexes.json      23 composites
│  ├─ test/                       433 Dart test files + rules emulator suites
│  └─ tool/whitelabel.dart        4,863-line client generator
├─ apps/halal_boyz/        generated client shell — 7 Dart files, 23 total
├─ packages/core/          domain + services (114 files), isar/network/auth/payment
├─ packages/core_ui/       design system + theme tokens (95 files)
├─ docs/                   runbooks (CLIENT_BACKEND_RUNBOOK, RELEASE_RUNBOOK) + this brief
└─ tool_uilib/             per-phase receipts and specs (p32 etc.)
```

**[PROVEN]** counts: 4,016 tracked files; Dart files — `core_app/test` 433,
`core_app/lib` 142, `packages/core` 114, `packages/core_ui` 95,
`core_app/integration_test` 30, `apps/halal_boyz` 23, `core_app/tool` 19.
Platforms: android, ios, windows. **`core_app/web/` does not exist.**

---

## 3. What is proven working (do not rebuild these)

| Capability | Evidence | Why it matters for the target |
|---|---|---|
| Server-authoritative pricing | `createChargeIntentCore` in `core_app/functions/src/index.ts` re-prices every line via `verifyMenuPricing`, derives tax/promo/currency via `resolveChargeTaxAndPromo`, clamps delivery fee, one metadata bag via `buildChargeIntentMetadata`, idempotency key | the POS must reuse this, not fork it |
| Order ownership binding | `createOrder` requires a succeeded PaymentIntent with `metadata.createdBy === request.auth.uid`, re-verifies tax/discount against stored order | the card path already resists replay and tampering |
| Role claims | `syncUserRoleClaims` trigger writes the JWT claim; `assertStaffRole()` in `functions/src/access.ts` fails closed | extend to `roles[]` + `branchIds[]` + `tenantId` |
| Rules with shape locks | 811 lines, per-role allowlists using `affectedKeys().hasOnly([...])`, `audit_log` writes `false` | the *pattern* is right; the *granularity* is what fails for item-level state |
| White-label factory | `tool/whitelabel.dart`: `--config/--dry-run/--regenerate`, config validation, per-client `backend/`, post-gates (branding 75, tests 72, debug APK 73, flutterfire 74) | new surfaces must be generated, not hand-installed per client |
| Thin client shell | `apps/halal_boyz/lib/main.dart` calls `initCarnamaApp(CarnamaBootstrap(...))`; `app.dart` returns `const CoreApp()`; zero forked app body | a new surface is one codebase, N configs |
| Boot chain | `app_bootstrap.dart` 16 documented steps, fail-closed gates for config schema and Firebase keys | a second platform must enter through the same chain |
| Presence | `packages/core/lib/src/presence/presence_service.dart` → `presence/{uid} {isOnline,lastSeen,branchId,role}`, staff-only, DI-injected | feeds "who is on the floor" without new infra |
| Realtime | Firestore snapshots; `KitchenService.streamOrders(branchId,statuses)` capped 200; composite indexes for `branchId+status+createdAt` already exist | sufficient for one branch; no broker needed |
| Kitchen offline queue | `SyncQueue` is an interface (`packages/core/lib/src/network/sync_queue.dart:60`) with `IsarSyncQueue` (`:80`) | a web/in-memory adapter is an implementation, not a rewrite |
| Static health | `flutter analyze --no-pub` in `core_app` → **No issues found**, 136.9 s, exit 0 (my run) | a clean baseline to protect |
| Test assets | 433 Dart test files; rules emulator suites (`core_app/test/rules/firestore_rules_test.js`, `storage_rules_test.js`); functions `npm test` = `tsc` + `node --test` | the only credible guard for a rules rewrite |

## 4. What is proven absent or stubbed

| Gap | Evidence | Blocks |
|---|---|---|
| `counter` and `waiter` roles | `enum UserRole { owner, manager, kitchen, delivery, customer }` in `packages/core/lib/src/auth/user_model.dart` | every staff surface |
| Multiple roles per user | `UserModel.role` is a single string; claim is a single `role` | owner-covers-counter, manager-waits-tables |
| Multiple branches per user | `UserModel.branchId` single; rules `userBranch()` single | multi-branch operations |
| Second owner | `isOwner()` compares `settings/ownerInfo.ownerEmail` — one identity per project | per-tenant owners in a shared project |
| Tenancy in rules | `grep -c clientId core_app/firestore.rules` → `0` | the entire one-project decision |
| Staff-created orders | `createOrder` demands a succeeded PaymentIntent bound to the caller's uid; no cash path | POS, waiter, phone orders |
| `tables` collection | absent from a full `collection('…')` census | waiter surface, dine-in |
| `transactions` / ledger | absent | owner dashboard truth, Z-reports, refunds |
| `ingredients` / `recipes` / `stock` | absent | inventory |
| Per-item order state | `OrderStatus` enum only; `buildKitchenStatusUpdatePayload` emits `{id,status}` | kitchen precision |
| `channel`, `staffId`, `tableId`, `paymentMethod` on orders | not in the rules create allowlist; `orderSource` is server-owned | channel reporting, POS |
| Branch breakdown in analytics | `fetchTodayAnalytics` = one aggregate over the collection; `fetchTopDishes` groups client-side over a 200-doc cap | multi-branch dashboard |
| Stripe Terminal | only `nfc_terminal_service.dart` placeholder with `TODO_DEPLOY` | card-present |
| Thermal printing | zero hits on all branches and worktrees (§1.3) | POS receipts |
| Web target | `core_app/web/` absent; 8 files import `dart:io` unconditionally; Isar + workmanager | iPad web surfaces |
| Responsive layout | exactly **one** file in `core_app/lib` uses `LayoutBuilder`/`MediaQuery.size` (`checkout_screen.dart`) | iPad surfaces |
| Kitchen-proof UI | `kitchen_dashboard.dart` is a phone list, 8 px separators, 24 px icons | wall/arm's-length kitchen |

## 5. The system we are establishing

### 5.1 Roles and who may do what

**[DECIDED]** roles: `owner`, `manager`, `counter`, `waiter`, `kitchen`,
`customer`. A user may hold several; scoping is per branch set. Capabilities
are enforced server-side — never by hiding a button.

| Capability | owner | manager | counter | waiter | kitchen | customer |
|---|---|---|---|---|---|---|
| `order.create` (any channel) | ✓ | ✓ | ✓ | ✓ | — | own, app only |
| `order.transition` | ✓ | ✓ | ✓ | — | ✓ (kitchen states) | cancel while pending |
| `order.item_ready` | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| `payment.take` (cash/card-present) | ✓ | ✓ | ✓ | — | — | card, prepaid |
| `ledger.read` | ✓ all branches | ✓ own branches | — | — | — | — |
| `ledger.reverse` | ✓ | ✓ with reason **[OPEN §14 Q4]** | — | — | — | — |
| `table.manage` | ✓ | ✓ | ✓ | ✓ | — | — |
| `menu.write` | ✓ | ✓ | availability only **[OPEN §14 Q5]** | — | availability only | — |
| `staff.manage` | ✓ | invite, no owner | — | — | — | — |
| `inventory.write` | ✓ | ✓ | — | — | — | — |
| `report.read` | ✓ all | ✓ own | own shift | own shift | — | — |

### 5.2 Surfaces

| Surface | Primary device | Must survive | First release |
|---|---|---|---|
| Counter / POS | iPad, landscape, laptop fallback | a queue at rush hour; a reload mid-sale; reader disconnection | cash + card-present + optional pre-paid app orders |
| Kitchen | wall tablet, arm's length, greasy hands | glare, gloves, a 12-hour shift without reload | per-item ready, delay with reason, chime |
| Waiter | phone + iPad | one-handed, walking, spotty wifi | table map, open ticket, add rounds, request bill |
| Owner | phone first, iPad second | reading on a train | revenue by branch/channel, top items, staff activity |
| Customer | existing phone app | unchanged | same app, new channels reported |

### 5.3 Invariants that must never be violated

1. No card data touches our servers, in any surface, including Terminal (the
   reader handles the PAN; we only ever see a PaymentIntent).
2. Money totals are computed server-side from `menus`; a client-supplied price
   is never trusted, in any channel.
3. The ledger is append-only. Reversals are new rows. Nothing is deleted to
   "fix" money.
4. Every staff action that changes state is authorised by a server-side
   capability check and is attributable to a uid.
5. Permissions are enforced server-side; UI affordances are convenience only.
6. A tenant can never read or write another tenant's data (one-project model).
7. Every new collection ships with rules, an index where queried, an emulator
   test, and a deny-by-default posture for client writes of money state.

---

## 6. Hard constraints (house rules, not preferences)

From `<other-project>\AGENTS.md` (read in full) plus what the codebase
enforces:

1. **No stubs, no fabricated success.** A thing works when a command proves
   it. `TODO`, placeholder screens and "should be fine" are failures.
2. **Evidence before claim.** Every statement about behaviour needs
   `file:line` or a command output.
3. **Plan before editing.** Architectural change and schema migration need a
   supervised `[PLAN]`. This brief is the input to that approval.
4. **Scope discipline.** Build what was asked; file the rest in
   `core_app/DEFERRED.md` with an owner.
5. **TDD / verification gates.** Tests first for domain logic; `flutter
   analyze` clean; rules emulator green; `npm run build` clean.
6. **Never commit or push** unless explicitly instructed.
7. **One codebase per surface family** — white-label theming, strings and
   config come from one place or the fleet drifts.
8. **Both locales** for every new string.
9. **New config keys must satisfy both validators** (runtime `AppConfig` and
   generator `ClientConfig.validate()`), which are pinned together by tests.

---

## 7. Architecture decisions required (the orchestrator's agenda)

Each is a decision the implementer cannot make alone. Detail and alternatives
are in `PLATFORM_EXPANSION_PLAN.md` §4.

| ID | Decision | Recommendation | Status |
|---|---|---|---|
| **A1** | Tenancy mechanism in a single project: flat collections + `tenantId` field, or path-rooted `tenants/{tenantId}/…` | flat + field, enforced by one helper on every match block, proven by a per-collection cross-tenant denial test | **[OPEN §14 Q1]** |
| **A2** | Existing client migration into the shared project: big-bang or fresh-with-tenant-1 | fresh project, Halal Boyz as tenant #1, old project read-only for a settling period | **[OPEN §14 Q2]** |
| **A3** | Roles as a set | `users.roles[]` authoritative, `role` derived for back-compat, claims carry `roles`/`branchIds`/`tenantId`; rules read claims, not `get()` | ready |
| **A4** | Order mutation authority | moves into callables; client-direct order writes shrink to customer-cancel-while-pending; `transactions`/`order_events`/`stock_moves` become `write: false` | ready |
| **A5** | Dine-in model | an open table ticket **is** an `orders` doc with `isOpenTab: true` + `tableId`, not a parallel `tabs` collection | ready |
| **A6** | Ledger | append-only `transactions`, written in the same transaction as the order change; reversals are new rows with `reversalOf` | ready |
| **A7** | Real-time | keep Firestore snapshots; add `order_events` for change feed + chime; no broker | ready |
| **A8** | Staff surface platform | Flutter web in the same codebase, gated by a 2-day spike with a pre-agreed fallback (separate web frontend, same backend) | **[OPEN §14 Q6]** |
| **A9** | Card-present | Stripe **server-driven** Terminal integration from Cloud Functions (no Flutter SDK exists); `card_present` intent variant; reader per branch location; tip decided in cart | ready, pending reader hardware choice |
| **A10** | Receipts | browser/system print in v1; thermal only once the owner identifies the existing implementation (§1.3) | **[OPEN §14 Q3]** |
| **A11** | Multi-branch reporting | CF-maintained `daily_rollups` per branch-day, treated as a cache recomputable from `transactions` | ready |
| **A12** | Inventory timing | schema + rules + empty UI in Phase 1; behaviour in Phase 4 | ready |

---

## 8. Data model delta

Every new/derived collection is **tenant-scoped** (per A1) and carries
`tenantId`. Full field lists are in `PLATFORM_EXPANSION_PLAN.md` §5; the
additions the one-project decision forces are:

```text
# on EVERY document in EVERY collection (existing included)
tenantId: string            # immutable, == client slug from client_config

# on users/users-in-tenant
roles: string[]             # replaces single role as authority
branchIds: string[]         # replaces single branchId as authority
tenantIds: string[]          # membership: which tenants this uid may enter
activeBranchId: string      # UI preference only, never an auth input

# new root docs
terminals/{id}              # stripe reader {branchId, serial, label, status}

# branches gains
terminalLocationId: string  # stripe.terminal.locations id per branch
```

New collections introduced by the target system (all absent today —
**[PROVEN]** by the census): `transactions`, `order_events`, `tables`,
`staff_shifts`, `daily_rollups`, `ingredients`, `recipes`,
`stock_moves`, `alerts`, `terminals`.

### 8.1 Migration mechanics (must be scripted, idempotent, reversible)

1. `tool/migrate_v004_tenancy.ts` — stamps `tenantId` on every existing
   document, dry-run first, reports per-collection counts, refuses to run if
   any document already has a conflicting value.
2. `tool/migrate_v005_roles.ts` — `roles = [role]`, `branchIds = [branchId]`,
   `tenantIds = [tenantId]`; writes claims after the data change.
3. Rules deploy is **gated behind** a passing emulator suite that includes
   cross-tenant denial for every collection.
4. The old per-client projects are never migrated in place by a script that
   writes to production; migration is export → import into the shared project
   → verify counts → switch `firebase_options` in the generated client → keep
   the old project read-only.

---

## 9. Card-present: the proven Terminal plan (replaces the old deferral)

### 9.1 Why this shape

**[PROVEN]** There is no official Stripe Terminal SDK for Flutter. Stripe's
documented options are: mobile SDKs (iOS, Android, React Native), JavaScript,
desktop (.NET, Java), and **server-driven**. Flutter is not in that list. The
third-party `stripe_terminal` pub package supports Bluetooth readers on
Android only and openly lists missing features.

**[PROVEN]** Stripe recommends server-driven integration for smart readers
(WisePOS E, S700/S710, T600, Verifone), while the JavaScript SDK requires the
POS and reader on the same LAN with working local DNS, and notes Chrome 142+
requires an explicit local-network permission.

**Therefore:** server-driven integration from Cloud Functions. It is
platform-agnostic — it survives A8 going either way, and it needs no native
plugin, no Bluetooth permission, and no LAN assumptions on the iPad.

### 9.2 The flow, end to end

```text
POS (iPad)                Cloud Functions                     Stripe / Reader
    |  POST createStaffOrder (channel=counter, cash=false)
    |------------------------->| priceCartCore (menus re-price)
    |                          | paymentIntents.create(
    |                          |   payment_method_types:['card_present'],
    |                          |   amount, tax, tip, metadata{orderId,createdBy,tenantId,branchId})
    |                          | terminal.readers.processPaymentIntent(readerId, pi)
    |                          |---------------------------------->| reader shows amount
    |                          |                                   | customer taps/inserts
    |                          |<--------- webhook: payment_intent.succeeded
    |                          | transaction: order.status += paid
    |                          |              transactions/{txId} appended
    |                          |              order_events/{id} appended
    |  stream order (already paid) <----- Firestore snapshot
    |  receipt
```

### 9.3 Concrete work items

1. **`terminals/{id}`** collection: `{tenantId, branchId, stripeReaderId,
   serial, label, status, lastSeenAt}`; owner/manager register a reader by
   serial (Stripe: register at a Location).
2. **`branches.terminalLocationId`**: create once per branch via
   `terminal.locations.create` (idempotent, stored, never recomputed).
3. **`processTerminalPayment` callable**: capability `payment.take`, branch
   scoped, idempotency key, creates the PI then calls
   `terminal.readers.processPaymentIntent(readerId, {payment_intent: pi.id})`.
   Returns `{paymentIntentId, status}` — never a client secret to the browser.
4. **`card_present` intent variant**: `/cart_model.dart`-driven pricing stays
   the same; only `payment_method_types` and capture semantics change. **This
   is the one place the existing `automatic_payment_methods` call must be
   parameterised.** Do not fork `createChargeIntentCore`; add a mode.
5. **Webhook confirmation**: the existing `payment_intent.succeeded` handler
   resolves the order by `metadata.orderId` **[PROVEN]** — Terminal payments
   ride the same path, so order confirmation is already implemented once.
6. **Reader action status**: server-driven means no SDK connection state.
   Provide `getTerminalPaymentStatus(paymentIntentId)` (poll, 1 s, bounded)
   and/or consume `terminal.reader.action_succeeded` /
   `terminal.reader.action_failed` webhooks into `order_events`.
7. **Failure UX**: reader offline, card declined, wrong reader connected,
   timeout. Each must be a distinct, actionable message on the POS, and a
   failed attempt must leave **no** ledger row and no `paid` order.
8. **Cash remains**: reader unavailable must never block a cash sale.

### 9.4 Hardware and account prerequisites (owner inputs)

- A Stripe account with Terminal enabled and readers registered. Reader
  choice determines nothing in the code (server-driven covers all smart
  readers), but it does determine cost and counter footprint.
- Terminal is country-gated; confirm the target market is supported before
  promising it in a demo.
- Test mode first: `STRIPE_SECRET_KEY` in test mode, simulated reader.
  Stripe provides a simulated reader for exactly this.

---

## 10. Receipts and thermal printing

**Current, proven state:** no thermal implementation exists in this repo
(§1.3). What exists is a POS that will need *some* receipt path.

Order of work until the owner identifies the existing implementation:

1. **On-screen receipt** with an order number and a searchable order lookup —
   always available, works on every device, no hardware.
2. **System/browser print** to an A4 or 80 mm page as a stopgap.
3. **Stripe-hosted email receipt** for card payments — already wired in
   `createChargeIntentCore` via `receipt_email`.
4. **Thermal ESC/POS** only once §14 Q3 is answered. If it must be built:
   network (LAN) printers over raw TCP 9100 are the least fragile on iPad;
   Bluetooth ESC/POS is the most fragile; Sunmi/Star have vendor SDKs that
   are Android-only.

If the owner's implementation is real but outside this tree, the orchestrator
should obtain it before Phase 2 so the POS does not ship two receipt paths.

---

## 11. Phases with acceptance criteria

Durations are planning figures for one developer. Acceptance criteria are the
approval test — a phase is done when they are demonstrably true, not when the
tasks are ticked.

### Phase 1 — Foundation: tenancy, roles, ledger, owner dashboard (4 weeks)

Scope grew from 3 to 4 weeks because the one-project decision adds tenancy to
every collection.

**Acceptance criteria**

- [ ] `flutter analyze` clean; existing Dart suite green; `npm run build` in
      `functions` clean.
- [ ] Rules emulator: a user of tenant A reading any collection of tenant B is
      **denied**, proven per collection by a generated test that enumerates
      collections rather than a hand-picked few.
- [ ] A user with `roles: ['manager','waiter']` passes both capability checks;
      a `waiter`-only user is denied `payment.take` **by the server**, with a
      test that asserts the error code.
- [ ] Backfill scripts are idempotent: a second run changes zero documents.
- [ ] Every money event from the existing customer flow writes exactly one
      `transactions` row; a reversal writes a second row and the original is
      byte-identical afterwards.
- [ ] `daily_rollups` for a branch-day equals a from-scratch recomputation
      from `transactions` (assert equality in a test, not by eye).
- [ ] Owner dashboard renders at 390 px and 1024 px with no overflow, and
      shows branch + channel breakdown.
- [ ] Generator dry-run for an existing client is clean; a scratch client
      generates and passes its own post-gates.

**Demoable:** multi-role sign-in with server-side denial shown live; ledger
rows appearing from a real order; reversal as an append; per-branch revenue;
web-spike verdict.

### Phase 2 — Counter (POS) + kitchen, cash and card-present (4 weeks)

**Acceptance criteria**

- [ ] Cash sale on an iPad writes one order, one ledger row, one event, and
      releases the drawer state; a double-tap on "tender" produces **one**
      row (idempotency proven by test).
- [ ] Card-present sale through Terminal: intent → reader → webhook → paid
      order → ledger row, with a simulated reader in test mode.
- [ ] A tampered client price is rejected by the server on the POS path
      exactly as on the app path (same helper, one test each).
- [ ] Kitchen board: per-item ready and per-order delay write events; a
      reload mid-service loses no state; a chime fires on new events.
- [ ] Offline cash queue drains without duplicating, and any server rejection
      surfaces in a visible exception list.
- [ ] Rules: client writes to `transactions`, `order_events`, and order state
      outside the customer-cancel allowlist are denied.

**Demoable:** walk-in cash sale; reader sale; kitchen per-item completion and
a delay with reason; tamper rejection; role denial on `payment.take`.

### Phase 3 — Waiter + multi-branch (3 weeks)

- [ ] Table map with optimistic locking: two devices cannot seat the same
      table twice (test asserts the second write fails on `version`).
- [ ] Open ticket can be added to across devices and closed at the counter;
      the ledger row matches the ticket total.
- [ ] Staff shifts clock in/out and feed per-staff sales.
- [ ] Owner can switch branch and see per-branch and per-staff figures that
      reconcile to `transactions`.

### Phase 4 — Inventory (3 weeks)

- [ ] Selling a dish decrements stock by its recipe, in the same transaction
      as the ledger row.
- [ ] A reversed sale restores stock via a compensating `stock_moves` row;
      the original row is unchanged.
- [ ] Replaying the same order event twice deducts once (idempotency keyed on
      the order line).
- [ ] Low-stock alert fires at threshold; `alerts` is client-read-only.

---

## 12. Verification gates (every phase, no exceptions)

```bash
# static + unit
(cd core_app && flutter analyze --no-pub)
(cd core_app && flutter test)
# backend
(cd core_app/functions && npm run build && node --test)
# rules (emulator; requires the firebase CLI and Java)
(cd core_app && firebase emulators:exec --only firestore,storage \
   "flutter test test/firestore_emulator_rules_test.dart")
# fleet
(cd core_app && dart run tool/whitelabel.dart --config ../apps/halal_boyz/assets/client_config.json --dry-run)
```

**[UNVERIFIED]** in this assessment: `flutter test`, `npm test`, the emulator
suites and any build. Only `flutter analyze` was actually run. The gates above
are the intended definition of green, not a report of current status.

---

## 13. Security model and the Pentagi phase

### 13.1 What the security posture must be after the tenancy change

| Control | Requirement |
|---|---|
| Tenant isolation | deny-by-default per collection, proven by a generated per-collection test, not by inspection |
| Capability checks | every callable runs `assertCapability` + `assertBranchScope` + tenant match before touching data |
| Money writes | client writes to `transactions`, `order_events`, `stock_moves`, `alerts` are `false`; only the Admin SDK inside a callable writes them |
| Role changes | claim refresh forced on change (`revokeRefreshTokens` on demotion), not left to token expiry |
| App Check | enforced on every callable (the pattern exists: `enforceAppCheck` is used on the current callables) |
| Idempotency | every money-moving callable requires a key; a retry must be a no-op |
| Audit | actor uid, roles, branch, channel and before/after on every staff state change |
| Blast radius | one project means one compromise distance — compensating controls above are mandatory, not optional |

### 13.2 Pentagi (later phase, but prepare now)

PentAGI is a self-hosted Docker stack (2 vCPU / 4 GB / 25 GB, one LLM
provider key, console on `https://localhost:8443`) that runs each flow in an
isolated sandbox with nmap/sqlmap/Metasploit/browser tools. It is a
network-facing pentester.

What that means for *this* system **[PROVEN from Stripe/Firebase model]**:

- **High value:** the staff PWA (once it exists) and the callable HTTPS
  endpoints. Privilege escalation, cross-tenant access, IDOR on
  order/table/transaction IDs, tampering with price/quantity/method, replay
  of idempotency keys.
- **Low value:** `firestore.rules`. Rules are enforced by Firebase for SDK
  clients; a generic web crawl never exercises them. The **emulator suite is
  and remains the authority** for rules, and it must grow a case per new
  collection and per callable.
- **No value:** the Flutter mobile binary.

Preconditions before the first flow: a **staging** project (never a client's
live one), seeded users for every role and tenant, test-mode Stripe only, no
real PII, written authorisation for the exact hosts, and a firewalled host —
the sandbox publishes callback ports 28000–29999 on every interface by
default, which is the most common self-host mistake.

Handling: triage to real / needs-repro / by-design; every real finding gets a
failing test first, then a fix, then a re-run of the same flow to prove
closure; anything unclosed before launch becomes a `DEFERRED.md` row with an
owner and an expiry.

---

## 14. Open questions — answer these before implementation starts

Each has a recommendation; none is silently defaulted.

**Q1 — Tenancy mechanism.** Flat collections + `tenantId` field, or
path-rooted `tenants/{tenantId}/…`?
*Recommendation:* flat + field, with one rules helper on every match block and
a generated per-collection cross-tenant denial test. Cost: ~300 mechanical
query edits, 23 index rewrites. Path-rooting is structurally stronger but is a
monorepo-wide refactor with no test suite proven green in this assessment.

**Q2 — Existing client migration.** Does `demo-tenant` move into the
shared project, or does the shared project start fresh with Halal Boyz as
tenant #1?
*Recommendation:* fresh, Halal Boyz as tenant #1, old project read-only until
the new build is signed off. Export/import of live orders is where data loss
happens and it buys nothing for a single pilot client.

**Q3 — Thermal printing.** Where is the implementation the owner says is
done? No such code exists in any branch or worktree (§1.3).
*Recommendation:* produce the path/repo before Phase 2, or accept the
receipt order in §10 and keep thermal out of scope.

**Q4 — Who may reverse money.** Owner only, or manager-with-reason?
*Recommendation:* owner always; manager with a mandatory reason code and the
reversal visible on the owner dashboard.

**Q5 — 86ing an item.** May counter staff mark an item unavailable without a
manager?
*Recommendation:* yes — a sold-out item must be actionable at the till, with
the change attributed and shown on the dashboard.

**Q6 — Staff surface platform.** Approve the 2-day spike for Flutter web with
option B (separate frontend, same backend) as the pre-agreed fallback?
*Recommendation:* approve. Card-present no longer depends on this answer
(§9), so the spike is low-risk and the fallback costs staff chrome only.

**Q7 — Reader hardware and market.** Which reader, and is Terminal supported
in the target country? Both are account-level facts that gate any
card-present demo.

---

## 15. What the orchestrator should return

1. An approved `[PLAN]` for Phase 1 with the acceptance criteria in §11 turned
   into tasks, each with its own test.
2. Answers to Q1–Q7, recorded in `DECISIONS_LOG.md` with the consequence
   accepted.
3. A ruling on whether the tenancy change is one migration or two (data then
   rules, or both in one deploy window), given that a rules regression now
   affects every client at once.
4. Confirmation of the receipt path (§10) so Phase 2 does not build twice.

---

## 16. What this brief does not claim

Not run, therefore not claimed: `flutter test`, `npm test`, the Firestore or
storage emulator suites, `flutter build apk`, `flutter build web`, any deploy,
any behaviour against a live project, Stripe account, reader or iPad. The one
health fact proven here is `flutter analyze` clean on `core_app` (136.9 s,
exit 0).

Not verified and not repeated as fact: coverage percentage, test counts from
`PROJECT_STATUS.md`, screen and route counts, the contents of
`archive/WHITE_LABEL_p29_security_debt.md`, and anything in the p33/`cline-*`
worktrees beyond the file census and the printing search.

---

Sources for the Terminal statements in §1.2 and §9:
<https://docs.stripe.com/terminal/payments/setup-integration>,
<https://docs.stripe.com/extensibility/terminal-for-pos-partners>,
<https://docs.stripe.com/terminal/payments/collect-card-payment>,
<https://support.stripe.com/questions/terminal-server-driven-integration>,
<https://pub.dev/packages/stripe_terminal> (third-party, Android Bluetooth
only).

---

## 17. Proposed solutions, written against this codebase

Not generic architecture: each item names the file it lands in and the shape
it takes in *this* tree.

### 17.1 Tenancy (one project, many tenants)

| Piece | Where | Shape |
|---|---|---|
| Tenant resolution | `apps/*/lib/app/core_config_adapter.dart` + `ClientCoreConfig` | `tenantId` becomes a required config key, derived from `app.bundleId` at boot exactly as `clientId` is today; a missing/placeholder value fails the existing schema gate rather than defaulting |
| Query surface | new `packages/core/lib/src/network/tenant_firestore.dart` | `TenantFirestore` wrapping `FirebaseFirestore` with `collection(name)` that injects `where('tenantId','==', t)`; ~297 call sites become one-line changes and *cannot* forget the filter, because the wrapper is the only entry point |
| Writes | same wrapper | `doc()` / `set()` stamp `tenantId` from the injected config, not from caller arguments — a client cannot write a foreign tenant id |
| Rules | `core_app/firestore.rules` | one `function tenantOk() { return request.auth.token.tenantId == resource.data.tenantId; }` plus a create variant on `request.resource.data`; applied on **every** match block; `settings/ownerInfo` moves to `tenants/{tenantId}/settings/ownerInfo` so owner identity is per tenant |
| Claims | `functions/src/index.ts` `syncUserRoleClaims` | extend to write `tenantId`, `roles[]`, `branchIds[]` — and `revokeRefreshTokens` on any role/branch change (see §13.1) |
| Auth | `packages/core/lib/src/auth/auth_repository.dart` | after sign-in, verify `users/{uid}.tenantIds` contains the app's tenant; otherwise fail closed with a clear screen (a shared user pool means identity alone is not authorisation) |
| FCM | `packages/core/lib/src/notifications/fcm_service.dart` | topics prefixed `t_<tenantId>_`; token docs keyed by tenant so a push for tenant A can never address tenant B's device |
| Indexes | `core_app/firestore.indexes.json` | `tenantId` prepended to all 23 composites; a script regenerates them so the ordering cannot be hand-edited wrong |

### 17.2 Roles and capabilities

| Piece | Where | Shape |
|---|---|---|
| Role set | `packages/core/lib/src/auth/user_model.dart` | add `counter`, `waiter` to `UserRole`; add `List<UserRole> roles` and `List<String> branchIds` with `role`/`branchId` derived getters so the 142-file blast radius stays small; `UserRoleConverter` keeps its fail-closed `customer` fallback for *unknown* values |
| Capability table | new `core_app/functions/src/permissions.ts` | pure TS, zero imports: `CAPABILITIES: Record<Role, Capability[]>` + `can(roles, capability)`. Exhaustive test over the cartesian product so a new role cannot ship with an undefined policy |
| Server gate | `core_app/functions/src/access.ts` | replace `assertStaffRole` with `assertCapability(roles, cap)` + `assertBranchScope(branchIds, branchId)` + `assertTenant(claimTenant, docTenant)`; every existing callable migrates |
| Client mirror | `core_app/lib/features/admin/presentation/role_gate.dart` | keeps its current job (defence-in-depth redirect) and stays presentation-only — the existing `UserRolePresentationCapabilities` split is already correct and must not become an access decision |
| Routing | `core_app/lib/app/app_router.dart` + `role_router_screen.dart` | `/counter`, `/waiter` routes; the switch gains role-set evaluation (`roles.contains(...)`), not `switch (role)` |
| Migration | new `core_app/tool/migrate_v005_roles.ts` | idempotent, dry-run, per-collection counts, refuses on conflicting pre-existing values |

### 17.3 Order authority, ledger, dine-in

| Piece | Where | Shape |
|---|---|---|
| Extract pricing | `functions/src/index.ts` | move the menu cross-check + tax/promo/fee composition out of `createChargeIntentCore` into `priceCartCore(items, ctx)`; both the customer and staff paths call it. This is a **refactor of one function**, guarded by the existing `order_create_payload_contract_test.dart` and MONEY-1 cases |
| Staff order | new `functions/src/staff_orders.ts` | `createStaffOrder` (channel, cash|card-present, `customerId: null`, `guestName`), `addOrderItems`, `transitionOrder`, `setItemReady`, `closeTicket`, `reverseTransaction` — each: App Check, capability, branch, tenant, zod schema, idempotency key, transaction over order + `transactions` + `order_events` |
| Ledger | new `functions/src/ledger.ts` | one `appendTransaction(tx, {...})` used by every money path (including the existing customer `createOrder`), so there is literally one place a ledger row is born |
| Rules | `core_app/firestore.rules` | order writes shrink to the customer-cancel allowlist; `transactions`, `order_events`, `stock_moves`, `alerts` become `allow write: if false` — the `audit_log` pattern that already exists |
| Dine-in | `orders` only | `isOpenTab: true` + `tableId`; no new `tabs` collection, so `KitchenService.streamOrders` and `analytics_provider` keep working on one source |
| Rollups | new `functions/src/rollups.ts` | scheduled + triggered recompute of one branch-day from `transactions`, compare-and-set on `version`; a test asserts rollup == from-scratch recomputation |

### 17.4 Card-present (Stripe Terminal)

| Piece | Where | Shape |
|---|---|---|
| Intent mode | `functions/src/index.ts` | `createChargeIntentCore` gains `paymentMethodTypes: ['automatic'|'card_present']`. Terminal needs `card_present`; `automatic_payment_methods` stays for the app |
| Reader registry | `terminals/{id}` | `{tenantId, branchId, stripeReaderId, serial, label, status, lastSeenAt}`; registration is a callable so a reader cannot be claimed by the wrong branch |
| Location | `branches.terminalLocationId` | created once per branch, idempotent, stored |
| Charge | new `functions/src/terminal.ts` | `processTerminalPayment` → create PI → `terminal.readers.processPaymentIntent(readerId, {payment_intent})`; returns ids only, never a client secret |
| Status | same file | `getTerminalPaymentStatus` (bounded poll) + `terminal.reader.action_succeeded/failed` webhooks appended to `order_events` |
| Confirmation | existing `stripeWebhook` | already resolves by `metadata.orderId`; Terminal rides it unchanged |
| Client | new `core_app/lib/features/pos/domain/terminal_reader.dart` | no SDK, no Bluetooth: a thin callable client + state machine `idle → amountShown → cardPresented → approved|declined|timeout` |

### 17.5 Web reach (if A8 is approved)

The port is a known list, not a mystery:

| File | Change |
|---|---|
| `app_bootstrap.dart:35` | `dart:io` → conditional import; web branch skips Isar/workmanager/Crashlytics, keeps App Check + FCM (web push) or degrades explicitly |
| `packages/core/.../logger_service.dart:2` | file sink behind a conditional import; web sink = console + Crashlytics-free breadcrumb buffer |
| `packages/core_ui/.../app_theme.dart:2` | `Platform.isIOS` → `defaultTargetPlatform` (already web-safe) — a one-line fix |
| `cache/isar_service.dart`, `kitchen/kitchen_offline_service.dart` | `WebSyncQueue implements SyncQueue` (memory + IndexedDB), selected by `kIsWeb`; the `SyncQueue` interface already exists at `sync_queue.dart:60` |
| `force_update_guard.dart`, `data_export_service.dart`, `proof_of_delivery_service.dart` | conditional stubs that fail loudly rather than silently no-op |
| platform folder | `flutter create --platforms=web .` in `core_app`; per-client web manifest + icons emitted by `tool/whitelabel.dart` next to `flutter_launcher_icons.yaml` |
| layout | new `core_ui` breakpoint helper (`compact <600 ≤ medium <1024 ≤ expanded`) and staff screens built responsive from the first commit — not retrofitted |

### 17.6 Fleet factory changes

1. `ClientConfig` gains `tenantId`; both validators updated together (the runtime gate and the generator are pinned by tests).
2. `--refresh-backend` (or a parity test) so each client's copied `firestore.rules` / `firestore.indexes.json` cannot silently drift — today they are byte-identical and that will not survive Phase 1.
3. Web manifest + icons in the generated output for iPad installability.
4. `DEPLOY.md` template gains the one-project deploy order: functions → rules → indexes → clients' config.

---

## 18. Quality report on the codebase

Judgement, area by area, with the evidence that supports it. Scores are for
*this* expansion's purposes, not abstract beauty.

| Area | Score | Why |
|---|---|---|
| Money correctness | **9/10** | Server re-prices from `menus`, derives tax/promo/currency, clamps fees, one metadata builder, idempotency keys, and `createOrder` re-verifies the intent. This is better than most production POS backends. The 1 point is the documented residual: `calculateTax` still trusts a client `subtotalCents` (`DEFERRED.md` C1) |
| Access control design | **7/10** | Real rules with shape locks and CF-only audit writes; but one role, one branch, no tenancy, and `get()` per rule evaluation. The *pattern* is sound; the *model* is too small for the target |
| Access control coverage | **6/10** | Deny-by-default in the right places, but the order create allowlist is narrower than the product needs and there is no per-collection tenant test to extend. Emulator suites exist — that is the saving grace |
| Architecture / modularity | **7/10** | Clean layering (`core` domain/services, `core_ui` design system, `core_app` composition), DI discipline (`firestoreProvider`, injected logger, no `FirebaseFirestore.instance` in services like `presence_service.dart`), freezed models with a 15/15 sibling census. Docked for the phone-only layout and the mobile-only dependency set |
| White-label engineering | **8/10** | The factory is real: thin shells, shared body, per-client config, post-gates that actually build. Docked for per-client rules **copies** (a drift trap) and for a generator that predates any multi-surface or multi-tenant concept |
| Test infrastructure | **7/10** | 433 test files, golden harness, rules emulator suites, contract tests, wiring tests, a documented boot-chain truth test. Docked because I could not verify the suite is green, and coverage is unverified against a claimed 53 % floor |
| Observability / operability | **7/10** | Structured logger with a tested boot isolation, Crashlytics wiring, `presence/`, audit collections, runbooks (`CLIENT_BACKEND_RUNBOOK.md` has 11 concrete steps). No server-side business metrics, no queue-depth visibility |
| Real-time design | **8/10** | Uses the platform properly (snapshots + composite indexes already present), no premature broker. Docked for no change feed, so nothing can react to "what just happened" without diffing documents |
| UI/UX craft | **6/10** | Tokens, goldens, glassmorphism receipts — real design work — but one `LayoutBuilder` in the entire app and a kitchen screen built for a phone. Every tablet surface is net-new |
| Documentation truth | **4/10** | `PROJECT_STATUS.md` / `FINAL_HANDOVER.md` are two months stale and at least one headline claim is provably false. `DEFERRED.md` is the exception: re-verified, `file:line`, owners. This is the single biggest process debt |
| Repo hygiene | **4/10** | 11 worktrees, ~30 branches, dirty tree, agent config sprawl at the root. Work is preserved but provenance is unclear; that is a real risk for a multi-week build |
| **Overall** | **7/10** | A genuinely solid, unusually disciplined codebase in its money and access layers, held back by a single-role/single-tenant data model, a phone-only UI, and documentation that no longer describes the code |

### 18.1 Three things that are better than they look

1. **The money path.** Most "POS" codebases trust the client and reconcile later. This one re-prices server-side and refuses the order. That is the hard part, and it is done.
2. **The DI and error-handling discipline.** Services take injected `FirebaseFirestore` + `LoggerService`; presence cannot crash the app lifecycle because every call is wrapped and logged. Expansion surfaces inherit that for free.
3. **`DEFERRED.md`.** A deferral register that is re-verified against code with owners is rarer than it should be, and it is exactly the artefact a multi-phase programme needs.

### 18.2 Three things that will hurt if not fixed first

1. **Rules copied per client.** Byte-identical today, divergent the moment Phase 1 lands. Fix the parity gate before touching rules, not after.
2. **Stale status docs.** Any new contributor (human or agent) reading `PROJECT_STATUS.md` will believe a false picture. The three docs in `docs/` now supersede them; say so in the file headers.
3. **Worktree sprawl.** Eleven trees with uncommitted work means "where is the current truth" has no answer. Consolidate before Phase 1, not during.

### 18.3 Quality risk introduced by this expansion

| Risk | Watch for | Mitigation |
|---|---|---|
| Rules complexity explosion | tenant × role × branch × shape locks in one file | keep rules thin by moving authority into callables (A4); deny-by-default for money state |
| Callable sprawl | 15+ callables each re-implementing auth | one `withStaffGuard(capability, handler)` wrapper in `access.ts`; no callable may hand-roll checks |
| Schema duplication | Dart models and TS handlers drifting | generate the TS zod schemas from one source, or pin them with contract tests like `order_create_payload_contract_test.dart` |
| Silent cross-tenant leak | an index/rule added without the tenant field | generated per-collection isolation test that fails when a new collection appears without a case |
| Two receipt paths | print + thermal built twice | resolve §14 Q3 before Phase 2 |

