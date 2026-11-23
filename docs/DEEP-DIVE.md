# Carnama — technical deep dive

> **Status of this document.** Written 2026-11-21 and checked against the source
> tree at commit `03b78d24` (branch `cline/p32-golden-gates`). Every number in
> §2 was produced by a command in §2.1, not recalled. Where this document and the
> code disagree, the code wins — and §18 lists the places where the code does
> *not* yet do what the broader project documentation says.
>
> Companion documents in this repository: [`DECISIONS.md`](DECISIONS.md) (49
> recorded rulings, each with the rejected alternative), [`INCIDENT_LEDGER.md`](INCIDENT_LEDGER.md)
> (failure classes), `ROADMAP.md` (unfinished work with acceptance criteria) and
> `HANDOFF.md` (session entrypoint). The short public summary is [`../README.md`](../README.md).
>
> **Paths.** References like `core_app/...` or `tool/...` point into the private
> source repository and are cited rather than linked. In the published copy only
> `archive/README.md`, `LICENSE`, `SECURITY.md`, `docs/DEEP-DIVE.md`,
> `docs/DECISIONS.md`, `docs/INCIDENT_LEDGER.md` and `docs/PUBLISHING.md` exist;
> internal files (`HANDOFF.md`, `ROADMAP.md`, `checkpoints/*`) are named, not
> linked, and are deliberately not published.

---

## 1. What this is, and what it is not

**It is** a multi-tenant restaurant ordering platform: a Flutter customer app, a
set of staff surfaces (owner, manager, kitchen, delivery), a TypeScript
serverless backend, locked-down Firestore security rules, and a white-label
factory that re-brands the whole product from one validated JSON file.

**It is not** any of these, despite what an older audit file in the tree may
claim:

- not a live service — nothing is deployed, and no production Firebase project
  has been migrated (§18);
- not a scraper, a crawler or an aggregator bot — the only inbound integration
  is a *verified webhook* receiver for platform order pushes (§6.6);
- not thermal-printing-capable — no ESC/POS, Epson, Star or Micronics code
  exists in the tree (verified by grep across `core_app/lib`, `packages/` and
  `core_app/functions/src`); the POS path prints nothing;
- not open source — see [`../LICENSE`](../LICENSE);
- not a single-restaurant app that happens to have a "tenant" column: tenancy is
  enforced in the rules, in the query, and by a generated test suite (§4).

The product is organised so that the *shared body* (domain, money, rules, UI
system) is one thing, and each restaurant is a **config + a generated app
shell**. `apps/halal_boyz` is the reference tenant and is itself generated from
`apps/halal_boyz/assets/client_config.json`.

---

## 2. Measured inventory

| Fact | Value |
| --- | --- |
| Workspace | `carnama_monorepo`, Dart SDK `^3.11.0`, melos `^8.2.2` |
| Workspace members | `core_app`, `apps/halal_boyz`, `packages/core`, `packages/core_ui` |
| Dart library files | 288 |
| Dart library lines | 60,235 |
| TypeScript Cloud Functions source | 7,340 lines across `core_app/functions/src` |
| Cloud Functions test suites | 24 files under `core_app/functions/test` |
| Dart test files | 511 |
| Dart `test` / `testWidgets` declarations | 3,525 |
| Firestore rules | 958 lines, 31 top-level collection blocks + 1 nested subcollection |
| Storage rules | 111 lines |
| Recorded decisions | 49 (`## D-0NN` headings in `docs/DECISIONS.md`) |
| Incident classes | 9 (`## ` headings in `docs/INCIDENT_LEDGER.md`) |
| Quality gates defined | 11, all `active` in `gate_config.json` |
| Tracked files | 4,480 |
| Customer-app feature slices | 17 (`core_app/lib/features/*` minus `admin` and `driver`) |
| Total feature slices | 19 |
| Supported UI languages | 2 (`en`, `ar`) with RTL goldens |
| Allergen declaration codes | 13 |
| Dietary suitability codes | 6 |
| Import/money/tenancy gates last green | receipt `checkpoints/gate-20261115T084733Z.md` (PASS, 11 ran, 0 failed) |

### 2.1 How to reproduce each number

```bash
# workspace shape
cat pubspec.yaml

# Dart inventory
find core_app/lib packages/core/lib packages/core_ui/lib apps/halal_boyz/lib -name '*.dart' | wc -l
find core_app/lib packages/core/lib packages/core_ui/lib apps/halal_boyz/lib -name '*.dart' | xargs wc -l | tail -1

# backend
find core_app/functions/src -name '*.ts' | xargs wc -l | tail -1
find core_app/functions/test -type f -name '*.test.*' | wc -l

# tests
find core_app/test packages/core/test packages/core_ui/test apps/halal_boyz/test -name '*_test.dart' | wc -l
grep -rhE '^\s*(test|testWidgets)\(' --include='*_test.dart' core_app/test packages/core/test packages/core_ui/test apps/halal_boyz/test | wc -l

# feature slices
ls core_app/lib/features | wc -l

# rules
wc -l core_app/firestore.rules core_app/storage.rules
grep -oE 'match /[a-zA-Z0-9_{}$/-]+' core_app/firestore.rules | sort -u

# decisions and gates
grep -cE '^## D-[0-9]{3}' docs/DECISIONS.md
node -e "require('./gate_config.json').gates.forEach(g=>console.log(g.id,g.label,g.active))"

# the whole battery
node tool/gate.mjs check
```

---

## 3. Architecture

### 3.1 The dependency rule

```
apps/halal_boyz  ──┐
                   ├──►  packages/core_ui  ──►  Flutter
core_app ──────────┤
                   └──►  packages/core     ──►  Flutter + Firebase SDKs
```

- `packages/core` owns domain logic: models, money, tax, auth, cache, network,
  compliance, delivery, kitchen, location, notifications, payment, presence,
  providers, schemas, services, validation. It never imports `core_app`.
- `packages/core_ui` owns the design system: theme tokens, shared widgets,
  money renderers, compliance surfaces. It does not import `core_app` either.
- `core_app` is the application: routing, screens, feature wiring, Firebase
  bootstrap.
- `core_app/lib/shell/` is a **second entrypoint** for the web. It may import
  individual `package:core/src/...` modules but never the barrel
  `package:core/core.dart`, because the barrel re-exports the Isar cache and
  Isar has no web platform. `core_app/tool/check_shell_imports.dart` walks the
  shell's import graph and fails on the barrel, Isar, `dart:io` and
  `path_provider`. The check was proven failing on purpose before it was trusted
  (D-056).

Why a shell at all: `flutter build web` on the full app fails in dart2js
(`isar_community` declares no web platform, plus two int64 sentinels in the
money renderers). The measured verdict is `checkpoints/P2-00.md`; the ruling is
option B, a thin shell over the *same* domain (D-049/D-050). The shell builds
(`main.dart.js` 2.4 MB, FCP 519 ms warm), boots, signs in and performs one
tenant-constrained read (`checkpoints/P2-01a-BOUNDARY.md`).

### 3.2 State, routing, storage

| Concern | Choice |
| --- | --- |
| State management | Riverpod 2 (`flutter_riverpod`), providers per feature slice |
| Routing | `go_router` 14, declarative table; the route list itself comes from the client config |
| Local persistence | Isar Community 3.3 behind `LocalCache`, which is a **required** constructor parameter of `AuthRepository` — mobile passes `IsarLocalCache`, the web shell passes `NoOpLocalCache` |
| Remote data | Cloud Firestore 6 + Cloud Functions 6 callables |
| HTTP | Dio 5 with an interceptor chain, plus `http_interceptor` |
| Push | FCM 16 + `flutter_local_notifications` 17 |
| Payments | `flutter_stripe` 11.5 on the client, Stripe Node SDK server-side, behind `ProcessorAdapter` |
| Maps | `flutter_map` 8 + `geolocator` 13 + `geoflutterfire_plus`; the map UI is the pin-drop address picker, and the tracker itself is a status timeline rather than a live map |
| Crash/perf | Crashlytics 5, Performance 0.11, Remote Config 6, App Check 0.4 |
| Over-the-air | Shorebird code push (configured, not exercised) |

### 3.3 Repository layout

```
core_app/
  lib/
    app/            bootstrap, config, tenancy, compliance, theme, router
    features/       19 slices, each with data/ domain/ presentation/
    shell/          thin web entrypoint (main, config, session)
    services/       app-level services
    l10n/           en + ar ARB files and generated localisations
  functions/        TypeScript backend (src/, test/, scripts/, migrations)
  firestore.rules   authoritative access control
  storage.rules     upload path and size rules
  test/             511 files: unit, widget, golden, rules, emulator, e2e
  tool/             check_shell_imports, whitelabel, tenant test generator
packages/core/      domain library
packages/core_ui/   design system
apps/halal_boyz/    generated reference tenant
tool/               gate runner, rules harness, emulator probes, proof harnesses
checkpoints/        one evidence receipt per completed card
docs/               decisions, incident ledger, research drafts, runbooks
archive/            historical batch records (audits, fix rounds) — not current truth
```

The root of the repository also carries a large number of *historical* batch
documents (`AUDIT_*`, `FIX_*`, `PRODUCTION_FIX_*`, `WHITE_LABEL_*`). They are
records of past sessions, not current truth. Where they conflict with
`HANDOFF.md`, `ROADMAP.md` or the source, they lose. This is why the public
showcase publishes only `archive/README.md`, `LICENSE`, `SECURITY.md` and this file.

---

## 4. Multi-tenancy

Tenancy is the single most interesting engineering decision in the repository,
so it is documented first.

### 4.1 The model

A tenant is a restaurant brand. Its identity lives in
`settings/<tenantId>_ownerInfo`; the `<tenantId>` prefix *is* the tenancy key.
There is no separate `tenants` collection, and the legacy unprefixed
`settings/taxRates` style documents are **retired** — the services require a
claim rather than falling back to them.

A signed-in staff or customer session carries a tenant claim. Client code
resolves it through one reader (`core_app/lib/app/tenancy/tenant_claim.dart`).
If the claim is missing, tenant-scoped reads **throw** rather than returning an
empty board — a misconfigured session must be visible, not silent.

### 4.2 The query rule (D-057)

> Every tenant-scoped list read must carry the tenant constraint **in the
> Firestore query**, not filter it after the fact.

That pass is complete across `analytics_provider.dart`, `admin_data_service.dart`,
`kitchen_service.dart`, `delivery_service.dart`, `revenue_chart_widget.dart` and
`data_export_service.dart` (including the GDPR export's reservations and
waitlist). Per-subtree measurements from that pass: admin 342/342, kitchen 58/58,
delivery 21/21, driver 29/29, export + profile 12/12, analytics 13/13, rules
contract 20/20, ticket goldens 4/4.

### 4.3 The driver-document exception (D-047)

`deliveries` and `proof_of_delivery` have **no** `tenantId` field. Their tenant
is derived from the ORDER. The reason is mechanical: the GPS ping writes are
`hasOnly`-shaped, so any extra field is erased by the first ping. Storing tenant
on the document would have produced a document that loses its tenant the moment
a driver moves.

### 4.4 How isolation is proven, not asserted

Three independent mechanisms:

1. **Generated tests.** `core_app/tool/gen_tenant_isolation_tests.dart` reads
   `firestore.rules` and emits a cross-tenant test per path, so a newly added
   collection cannot silently skip the check. Gate (i) runs it with `--check`:
   the generated suite must match the rules.
2. **A real emulator probe.** Gate (j) creates two tenants and a decoy and
   asserts that a constrained read returns only the caller's rows and that an
   unconstrained read is denied (`403 PERMISSION_DENIED`).
3. **A rules harness.** `node tool/rules_harness.mjs` executes the rules against
   the Firestore emulator, with a recorded baseline of known failures.

Current state: **32 of 32 rule paths ACTIVE, 0 PENDING-TENANCY** (28 top-level +
4 nested, per the tenancy registry). Harness: **173 passed, 56 in baseline, 0
new** at the last recorded run. The 56-entry baseline is a known blind spot and
is tracked as C-3 in `ROADMAP.md` — it is not presented as green.

### 4.5 Where tenancy is *not* yet perfect

- Some Dart fakes still seed unprefixed settings documents (C-5).
- The live migration (`migrate_v004_tenancy`) has been dry-run only, never
  applied to a real project (C-2, owner-only).
- `hasAppId()` — the App Check helper used in some rules paths — may be
  effectively always-false in production until one real ID token is observed
  (C-1).

---

## 5. Identity, roles and capabilities

- **Auth:** Firebase Auth. Email/password, Google Sign-In and Sign in with Apple
  are wired on the client (`google_sign_in`, `sign_in_with_apple`,
  `sign_in_with_apple` + `app_tracking_transparency` for iOS).
- **Staff roles:** `owner | manager | kitchen | delivery`, defined once in
  `core_app/functions/src/access.ts` as `StaffRole`. Role claims are synced from
  `users/{uid}` by the `syncUserRoleClaims` trigger.
- **Capability table:** authority is decided by `assertCapability`, not by role
  name scattered through handlers. For money: `payment.take` = owner / manager /
  counter; `payment.reverse` = owner / manager.
- **Role router:** `/role-router` sends a signed-in user to `/owner`, `/manager`,
  `/kitchen` or `/delivery`; `RoleGate` guards each surface, and the owner gate
  is owner-only.
- **Admin gateway:** `/admin-gateway` sits in front of the admin panel so the
  panel is not reachable by a stray deep link.
- **Panic switch:** an owner-controlled flag that stops new orders without a
  deploy (`panic_switch_service.dart`, rules-enforced).

---

## 6. The money path

This is the part of the system where a mistake is expensive, so it is built
around one rule: **the client never tells the server what something costs.**

### 6.1 Order creation

`createOrder` (callable):

1. authenticates and resolves the tenant claim;
2. re-prices **every line** from `menus` (`verifyMenuPricing`);
3. takes tax and currency from the same resolution the cash path uses
   (`resolveChargeTaxAndPromo`), tenant-aware;
4. commits the order **and** its ledger row in one transaction, under an
   idempotency key scoped to the caller.

`verifyMenuPricing` requires the unit price the counter displayed, so lines carry
`priceCents` as a **stale-ticket guard** only. The charged amount always comes
from the menu. A replay with the same key returns the same order with
`idempotent: true` and creates nothing new.

### 6.2 Cash sales (counter/POS)

Cash previously had no server path — `createOrder` hard-requires a Stripe intent
and the ledger requires a non-null `paymentIntentId` + `customerId`. That gap is
closed:

- `createCashOrder` re-prices lines, resolves tax, and commits the order plus a
  `sale_<orderId>` ledger row in one transaction under an idempotency key.
- `voidCashSale` commits a reversal row (`rev_sale_…`, negative amount) **and**
  the order cancellation together, patching with `update` (never delete), so the
  original money and lines stay intact and a second void is refused.
- Ledger rows are **retained and anonymised** on a DSAR erase, never deleted
  (D-059), because financial history is not the customer's to erase.

Measured on the emulator by `node tool/cash_proof.mjs`: **34/34 checks, `CASH
PROOF OK`** — one create produces `#0002`, total 2436 ¢ (2250 subtotal + 186 tax
at 8.25 %), change 564 ¢, exactly one order and one `sale_` row; replay is
idempotent; a cross-tenant void returns `not-found`; void leaves the order
`cancelled` with money and lines intact and refuses a second void.

### 6.3 Ledger invariants

- The ledger lives in `transactions`. Rows are append-only.
- An order and its row share a transaction, so there is no moment where one
  exists without the other.
- Corrections are new rows, never mutations. A refund is a negative row.
- Rollups (`rollups.ts`) derive totals; they are not the source of truth.
- `sale_<orderId>` as the document id is what makes offline replay safe (D-030):
  a duplicate write cannot create a second sale.

### 6.4 Provider seam

`core_app/functions/src/payments/processor_adapter.ts` puts Stripe behind an
interface. D-017 states the invariant: *the adapter moves money, it never decides
it*. Swapping to another PSP touches the adapter, not the ledger, the pricing or
the rules.

### 6.5 Stripe webhook

`stripeWebhook` is an `onRequest` handler that verifies the signature, bounds the
event replay (`MAX_WEBHOOK_EVENTS = 20`), and never trusts a client-sent amount.
A client can request an intent (`createPaymentIntent`, idempotent per cart) but
cannot declare that it was paid.

### 6.6 Platform order ingestion

`ingestPlatformOrder` accepts pushes from `uber_eats` and `delivery_hero`:

1. per-platform HMAC verification (`createHmac` + `timingSafeEqual`);
2. idempotency key namespaced by platform (`uber_eats:ORDER123`);
3. a mapper per platform (`platform_mappers/`);
4. **re-pricing through the existing money path** — the platform's total is
   recorded as `platformClaimedTotalCents` for reference and is never charged;
5. persistence with `orderSource: platform:<id>` and no Carnama user id, so a
   platform order can never surface in a consumer's own history but the kitchen
   still sees it;
6. a dead-letter record on every failure — never a guessed order, never a silent
   drop.

Amounts are parsed by `parseMinorUnitsStrict`: an integer is minor units; a
string is major units and must be exact to two decimals; a float like `24.5` or
a third decimal fails closed to `null`.

### 6.7 Tax and rounding

Integer minor units end to end. One rounding rule, applied once. Tax rates are
per-tenant settings (`settings/<tenant>_taxRates`), and the renderers share a
single guard `isMinInt` instead of a dart2js-hostile literal (D-056). Regression
tests cover the rounding boundary and the formatter.

---

## 7. Security rules

`core_app/firestore.rules` is 958 lines and is the real access-control layer;
client checks are UX. What it does:

- **Default deny.** No collection is readable just because it exists.
- **Per-role field allowlists.** Privileged updates use
  `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`, so a
  role cannot smuggle in `totalCents` or `paymentMethod` on an order update.
  This was a real defect: the owner branch of `allow update` on `orders` was the
  one clause without an allowlist. It now carries the union of the five real
  client writers in both rule files, and was proven both ways — the contract test
  went red naming exactly `['owner']`, and harness cases `OWN2`/`OWN3` went red
  with the lock removed (D-061).
- **Tenant derivation** from the order for driver documents (D-047).
- **Shape validation** on settings writes, including a "panic switch" read path
  that had to move into the generic block — keeping a literal `settings/*` rule
  after the rename would have kept authorising the old document and failed
  **open**.
- **App Check** checks on selected paths (`hasAppId()` / `isAppVerified()`),
  with C-1 tracking the production uncertainty.

`storage.rules` (111 lines) bounds upload paths and sizes for menu images and
proof-of-delivery photos.

Collections covered (measured from `match` blocks):

`admins`, `analyticsEvents`, `audit_log`, `audit_logs`, `branches`, `carts`,
`config`, `deletion_requests`, `deliveries`, `driverLocations`, `locations`,
`loyalty`, `menu_overrides`, `menus`, `notification_queue`, `notifications`
(+ `notifications/{userId}/items`), `orders`, `presence`, `promoCodes`,
`promo_usage`, `promotions`, `proof_of_delivery`, `reservation_counters`,
`reservation_locks`, `reservations`, `settings`, `transactions`, `users`,
`waitlist`, `waitlist_counters`, `waitlist_meta`.

---

## 8. Data model

Derived from the rules, the models and the callables — each document is named
with its purpose and its tenancy key.

| Collection | Purpose | Tenant key |
| --- | --- | --- |
| `users/{userId}` | profile, role, contact, consent flags | `tenantId` field |
| `admins/{doc}` | staff allowlist / admin metadata | `tenantId` |
| `menus/{itemId}` | menu items: price, category, modifiers, allergens, dietary | `tenantId` |
| `menu_overrides/{itemId}` | per-branch availability/price overrides | `tenantId` |
| `branches/{branchId}` | branch records, hours, geo | `tenantId` |
| `locations/{id}` | customer-facing picker entries | `tenantId` |
| `carts/{userId}` | persisted cart | owner-scoped |
| `orders/{orderId}` | orders, status, lines, totals, `orderSource` | `tenantId` |
| `transactions/{rowId}` | append-only ledger v2 (`sale_`, `rev_sale_`) | `tenantId` + order |
| `deliveries/{orderId}` | driver assignment, status | from the ORDER (D-047) |
| `proof_of_delivery/{poid}` | photo/signature evidence | from the ORDER (D-047) |
| `driverLocations/{driverId}` | last known GPS | driver + tenant |
| `presence/{userId}` | online state for staff and drivers | `tenantId` |
| `promoCodes/{code}` | promo definitions and limits | `tenantId` |
| `promo_usage/{usageId}` | per-user redemption accounting | `tenantId` |
| `promotions/{promoId}` | merchandising promotions | `tenantId` |
| `loyalty/{userId}` | points, tier | `tenantId` |
| `reservations/{resId}` | dine-in reservation requests | `tenantId` |
| `reservation_counters/{key}` | monotonic sequence per branch/day | `tenantId` |
| `reservation_locks/{lockId}` | concurrency guard for slot allocation | `tenantId` |
| `waitlist/{entryId}` | queue entries | `tenantId` |
| `waitlist_counters/{branchId}` | queue numbering | `tenantId` |
| `waitlist_meta/{docId}` | queue metadata (open/closed, ETA) | `tenantId` |
| `settings/{doc}` | per-tenant settings, `<tenantId>_` prefixed | `<tenantId>_` prefix |
| `config/{configDoc}` | public runtime config (safe before sign-in) | global |
| `audit_log`, `audit_logs` | append-only admin/settings/role audit | `tenantId` |
| `notification_queue/{id}` | outbound push work queue | `tenantId` |
| `notifications/{userId}` (+ `items`) | in-app notification inbox | recipient |
| `analyticsEvents/{eventId}` | funnel events | `tenantId` |
| `deletion_requests/{userId}` | DSAR erase pipeline state | `tenantId` |

---

## 9. Customer features

Each slice lives in `core_app/lib/features/<name>/{data,domain,presentation}`.

| Slice | Files of note | Behaviour |
| --- | --- | --- |
| `splash` | splash screen | boot gating, session restore |
| `onboarding` | onboarding screen | first-run value proposition |
| `auth` | `login_screen`, `signup_screen`, `terms_of_service_screen` | sign-in, sign-up, terms gate |
| `home` | `home_service`, `home_feed_showcase` | restaurant landing feed |
| `menu` | `menu_repository`, `menu_item_model`, `menu_modifier_model`, `dietary_codes`, `dietary_filter`, `dietary_badges`, `dish_detail_screen` | category browse, text search (`_query` filter), modifiers, sold-out state, dietary/allergen layer |
| `cart` | `cart_repository`, `cart_model`, `cart_validator_service`, `cart_provider` | persisted cart, per-line validation against live menu |
| `checkout` | `checkout_service`, `promo_code_service`, `checkout_screen` | server-priced checkout, promo application, Stripe payment sheet |
| `orders` | `order_repository`, `order_model`, `order_number_service`, `order_token`, `order_offline_payload`, `order_tracker_screen` | history, tracking steps, offline-safe payload, per-order tokens |
| `tracking` | `driver_location_service`, `delivery_tracker_screen` | three-stage delivery timeline derived from one status (no invented timestamps), driver contact, reorder replay; the driver-location service publishes GPS to `driverLocations` |
| `loyalty` | `loyalty_model`, `loyalty_provider`, `loyalty_screen` | config-driven tiers, points clamped at zero |
| `reservations` | `reservations_repository`, `reservation_model`, `reservation_screen`, `admin_reservations_tab` | book a table; admin tab to manage |
| `waitlist` | `waitlist_repository`, `waitlist_screen` | join the queue, position and ETA |
| `locations` | `location_repository`, `location_model`, `location_screen` | branch picker with address and hours |
| `profile` | `profile_screen` | account details, settings entry points |
| `compliance` | `delete_account_screen` | self-service erase request (feeds DSAR) |
| `tour` | `tour_manager`, `tour_overlay` | guided product tour, flag-gated |
| `location` | `pin_drop_map_screen` | interactive map (flutter_map) for pin-drop address selection, plus permission handling |

Money is never formatted ad hoc: `packages/core_ui` exposes `moneyCents`, and
both the coin and text renderers share the same min-int guard.

---

## 10. Staff and operations

| Surface | Code | What it does |
| --- | --- | --- |
| Role router | router + `RoleGate` | sends a signed-in user to the right dashboard |
| Admin panel | `features/admin/presentation/{analytics,delivery,gateway,kitchen,manager,owner,setup}` | menu editing, branches, reservations, delivery, kitchen, setup |
| Kitchen display | `features/admin/domain/kitchen_service.dart` | live queue per branch, status advance, ticket numbering |
| Delivery board | `delivery_service.dart`, `deliveries` | assignment and status |
| Driver app | `features/driver/proof_of_delivery_service.dart`, `features/tracking` | claim, navigate, GPS ping, capture proof |
| Owner dashboard | `features/admin/presentation/owner` | revenue, branch/channel split, day analytics |
| Admin gateway | `admin-gateway` route | keeps the panel off any stray deep link |
| Panic switch | `panic_switch_service.dart` | owner-only ordering halt, rules-enforced |
| Audit | `auditSettingsChanges`, `auditRoleChanges` triggers | append-only trail on settings and role changes |

Order status changes fan out through `onOrderStatusChange`, which writes
notification work and kitchen tasks rather than doing work inline in the client.

---

## 11. Dietary and allergen trust layer

The only feature built from a researched regulatory vocabulary, and it is
deliberately two axes:

- **`allergens: string[]`** — what the item declares it *contains*. 13 codes:
  `eggs`, `milk`, `mustard`, `peanuts`, `crustaceans`, `molluscs`, `fish`,
  `sesame`, `soybeans`, `sulphites`, `tree_nuts`, `wheat_triticale`, `gluten`.
- **`dietary: string[]`** — who the item *suits*. 6 codes: `vegan`, `vegetarian`,
  `halal`, `gluten_free`, `dairy_free`, `nut_free`.

Why two axes: one combined list would make "hide what contains milk" and "show
only vegan" the same operation, and an item can be vegan *and* contain sesame.
`wheat_triticale` and `gluten` stay separate because wheat is a priority allergen
while gluten is a declaration covering five grains — collapsing them tells a
coeliac nothing about barley. `celery` and `lupin` were removed as EU obligations
that are not Canadian ones.

Enforcement and rendering:

- validated at the **write boundary**, on both the client and staff projections;
- badges render on menu items, and an **expired certification renders nothing**;
- the filter is three dietary chips plus a 13-code allergen sheet (`show more`
  is not the UX for an allergy);
- the halal claim is owner-only, gated in the editor **and** in the rules;
- 29 localisation keys in `en` and `ar`.

This is voluntary trust, not a legal claim: the federal duty in Canada applies to
prepackaged labels, not to restaurant menus. `docs/DIETARY-VOCABULARY.md` states
that boundary explicitly, and `docs/RESEARCH-DRAFT-dietary-regulatory.md` carries
the citations.

---

## 12. Privacy and compliance

- **Export (Art. 15/20):** `exportMyData` callable, capped at
  `kExportRowCap = 500` rows, including the caller's own reservations, waitlist
  entries and ledger rows.
- **Erase:** `deleteUserData` → `runErase` → `eraseRefs` → ledger anonymisation.
  Ledger rows where `customerId`, `staffId` or `actorUid` match the uid get those
  fields nulled plus `anonymisedAt`; amounts and document ids are untouched, so
  the books still balance. Idempotent and bounded.
- **Retry:** `deleteUserDataRetry` scheduled function drains failed erase jobs.
- **Requests:** `deletion_requests/{userId}` records pipeline state.
- **No silent deletion of financial history** — D-059 makes that a standing rule,
  and C-9 in `ROADMAP.md` is the acceptance criterion for the anonymisation lane.

---

## 13. Notifications, presence, offline

- **Push:** FCM with a per-tenant channel; copy is centralised in
  `notification_copy.ts` so a message is never assembled in a client.
- **Queue:** `notification_queue` decouples "an event happened" from "a push was
  sent", so a failed send is retryable and visible.
- **In-app inbox:** `notifications/{userId}` with an `items` subcollection.
- **Presence:** `presence/{userId}` plus `packages/core/src/presence`, used by the
  delivery board.
- **Offline:** Isar-backed `LocalCache` for menu, cart and order payloads;
  `order_offline_payload.dart` makes a queued order replay-safe because the
  ledger document id is `sale_<orderId>` (D-030).

---

## 14. The white-label factory

`core_app/tool/whitelabel.dart` generates a working app in `apps/<name>` from one
JSON file:

```bash
dart run tool/whitelabel.dart --config apps/halal_boyz/assets/client_config.json
dart run tool/whitelabel.dart --config <file> --template minimal|modern|classic
dart run tool/whitelabel.dart --config <file> --dry-run      # gate (e) runs this
```

The config schema (`client_config_schema_20260814/`, plus the live example at
`apps/halal_boyz/assets/client_config.json`) covers, measured from the live file:

| Section | Contents |
| --- | --- |
| `_meta` | schema version, constitution version, generation date |
| `tenantId` | the tenancy key written into the app |
| `app` | name, icon, bundle id, store URLs, FCM channel description |
| `currency` | code and symbol |
| `environment` | Cloudinary cloud/preset, kitchen LAN endpoint, Stripe publishable key, Firebase client keys, dev admin PIN |
| `firebase` | project id, Android/iOS app ids, sender id, storage bucket, iOS client id |
| `features` | flag source and defaults (`smartReorder`, `loyaltyPoints`, `tourMode`, `waitlist`, `deliveryTracking`, `promoCode`), unknown-flag default |
| `theme` | injection mode, typography (family, heading, body, sizes), shape radii, component colours, backgrounds, 20 semantic colours, dark theme, signature style, confetti palette, spacing scale |
| `navigation` | entry point, 5 tabs, 10 hidden routes, 30 named routes |
| `screens` | 26 screen declarations |

The generator writes the app, its theme, its router and its feature gating; gate
(e) proves that a *real* config still validates end to end without writing
anything. Removing a required key from the config is the planted failure that
proves the gate bites.

**What still needs a human for a new brand:** creating the Firebase project,
registering the Android/iOS/web apps, downloading `google-services.json` /
`GoogleService-Info.plist`, adding App Check, and provisioning Stripe. No script
can do those, and the runbook (`docs/CLIENT_BACKEND_RUNBOOK.md`) says so.

---

## 15. Backend function catalogue

From `core_app/functions/src/index.ts` (7,340 lines of source across the module).

**Callables**

| Function | Purpose |
| --- | --- |
| `createOrder` | server-priced order + ledger row, idempotent |
| `createCashOrder` | cash/POS sale with change and `sale_` row |
| `voidCashSale` | reversal row + cancellation in one transaction |
| `createPaymentIntent` | Stripe intent, idempotent per cart/key |
| `cancelOrder` | customer/staff cancellation with schema validation |
| `applyPromo` | promo validation and usage accounting |
| `calculateTax` | tax resolution for a cart (schema exported for tests) |
| `screenPaymentFraud` | pre-payment risk scoring |
| `dispatchToFleet` | hand an order to a delivery fleet |
| `logFunnelEvent` | analytics funnel event |
| `exportMyData` | DSAR export, bounded |
| `deleteUserData` | DSAR erase pipeline |

**Triggers and schedules**

| Function | Trigger |
| --- | --- |
| `onOrderStatusChange` | `orders/{orderId}` updated |
| `syncUserRoleClaims` | `users/{uid}` written |
| `onFirestorePermissionDenied` | permission-denied audit capture |
| `syncMenuAvailability` | menu item written |
| `onReservationCreated` | `reservations/{resId}` created |
| `auditSettingsChanges` | `settings/{docId}` written |
| `auditRoleChanges` | `users/{uid}` written |
| `recoverAbandonedCarts` | every 5 minutes |
| `deleteUserDataRetry` | scheduled erase retry |

**HTTP endpoints**

| Function | Purpose |
| --- | --- |
| `stripeWebhook` | signature-verified payment events, bounded replay |
| `ingestPlatformOrder` | Uber Eats / Delivery Hero order push |

Supporting modules: `access.ts` (capabilities), `claims.ts`, `idempotency.ts`,
`ledger.ts`, `ledger_privacy.ts`, `payment.ts` (pricing and intent), `payments/`,
`platform_ingestion.ts`, `platform_availability.ts`, `platform_mappers/`,
`notification_copy.ts`, `permissions.ts`, `rollups.ts`, `ddos.ts`,
`migrations/` (`v001` seeds branches, `v002` admin user, `v003` owner info,
`v004` tenancy backfill, `v005` roles backfill, plus `plans.ts`).

---

## 16. The quality system

Twelve gates, defined in `gate_config.json` and run by `node tool/gate.mjs check`
(`gate.cmd check` is a thin wrapper that contains no logic — D-001).

| Id | Gate | What it proves |
| --- | --- | --- |
| a | `dart-analyze` | static analysis over the whole app package |
| b | `gate-fast-tests` | the `gate_fast` smoke set: config schema, money formatting, payment payload contracts |
| c | `functions-build` | `tsc` compiles the Cloud Functions source |
| d | `emulator-rules` | the rules compile and are enforced in the real Firestore emulator (one allowed read, one denied read) |
| e | `whitelabel-dry-run` | a real client config still validates end to end without writing |
| f | `stub-scan` | no placeholder markers or unimplemented throws in code files |
| g | `functions-coverage` | c8 coverage against a per-file floor registry |
| h | `backend-parity` | the client and server agree on schemas and contracts |
| i | `tenant-isolation-generator` | the generated cross-tenant suite matches the rules |
| j | `tenant-isolation-emulator` | a constrained read returns only the tenant's rows; an unconstrained read is `PERMISSION_DENIED` |
| k | `rules-harness` | the rule suite runs against the emulator with a recorded baseline |
| l | `licence-claim-scan` | no doc or licence file claims the project is open source, source-available or MIT-licensed |

Design rules that make the gates trustworthy:

- **Only a gate that ran and failed is red.** `UNAVAILABLE` and `NOT-ACTIVE` do
  not pass and do not fail the run (D-002); they are printed separately so a
  missing tool cannot masquerade as green.
- **Every gate carries a `plant`:** the specific breakage that must turn it red.
  A gate that cannot fail is a defect.
- **Receipts.** Each run writes `checkpoints/gate-<timestamp>.md` with per-gate
  output, so a claim of "green" names a file.
- **Ports come from the OS.** `tool/emulator_probe.mjs` asks the OS for a free
  port because unrelated software held the conventional ones (D-018).
- **Bounded scope.** Gate scope is proportional to the change (D-010); the battery
  is the floor, not the proof — the proof for a card is its checkpoint.

Beyond the gates there are purpose-built proof harnesses:

- `node tool/shell_proof.mjs up|verify|down` — spins a seeded tenant plus a
  decoy, then asserts isolation from a real web shell session.
- `node tool/cash_proof.mjs` — the 34-check money round trip.
- `node tool/rules_harness.mjs` — the rule suite with a baseline file
  (`core_app/test/rules/known_failures.txt`).
- `node tool/emulator_probe.mjs` — two-sided rule probe.

Testing layers present under `core_app/test`: unit, widget, golden (including RTL
goldens at multiple widths), property tests, rules contract tests, emulator
integration, e2e, and a `wiring` group that checks features are actually mounted
rather than merely written.

---

## 17. Localisation, theming, accessibility

- **Languages:** `en` and `ar`, both ARB files in `core_app/lib/l10n`, generated
  localisations checked in. RTL is covered by dedicated goldens and a plural
  completeness test.
- **Theming:** every colour, radius, font and spacing value is injected from the
  client config, so a brand change is a config change. A dark theme block exists
  in the schema and is exercised.
- **Accessibility:** semantic labels on money and status widgets, minimum tap
  targets, and contrast checks recorded in `archive/AUDIT_A11Y_L10N_UX.md` (historical
  record — treat as a snapshot, not a live guarantee).

---

## 18. What is *not* proven, and where this document corrected the record

This section exists because a deep dive that only lists strengths is marketing.
These are the project's own tracked gaps (`ROADMAP.md` §Carry):

| Id | Gap | Consequence |
| --- | --- | --- |
| C-1 | `hasAppId()` may be effectively always-false in production | App Check rule paths may not be doing what they look like they do until one real ID token is observed |
| C-2 | The live tenancy migration was never executed | Dry-run proof only; applying it is an owner-only action |
| C-3 | 56 harness baseline failures | The harness cannot see a regression *inside* that set |
| C-5 | Some Dart fakes still seed unprefixed settings documents | Fakes can pass against documents the app no longer reads |
| C-6 | The owner dashboard panel is built but not mounted | Placement is ruled (Analytics tab, bounded tenant-scoped read); the mount is not started |
| C-7 | Deploy ordering is encoded but never rehearsed | Claim callable → guest boot claim → migrate → rules last |
| C-8 | Whole-tree suboptimal-engineering audit | Scheduled, not started |
| C-9 | Ledger rows invisible to DSAR (now ruled) | Anonymisation must be wired and proven |

Also true and worth stating plainly:

- **Nothing is deployed.** No production project has these rules, functions or
  migrations applied.
- **The web shell's signed-in pixels were never photographed** — the browser
  window was minimised for that run, so the evidence is a console trace and an
  HTTP probe, not a screenshot. Second-account isolation in a browser is also
  unverified there.
- **Blind spot in the harness** is the same C-3 item: "green that cannot see its
  own failure".
- **`flutter build web` on the full app still fails** by design of the Isar
  dependency; only the thin shell is web-buildable.
- **No thermal printing exists.** Older audit documents claim it was done; it was
  not, and the claim is corrected here and in `HANDOFF.md`.

Corrections made while fact-checking this document against the source:

1. Earlier project documents said 9 gates; the config defines **12** — the
   tenancy generator, tenant emulator and rules harness were added later, and the
   licence-claim scan after the licence was narrowed to viewing only.
2. Earlier documents described the rules harness as "165 passed / 56 known"; the
   last recorded run after the owner-update lock is **173 passed / 56 baseline /
   0 new**.
3. `packages/core/LICENSE` was the Flutter template placeholder, which reads as
   an unstated licence. It now points at the root `LICENSE`, which is the only
   licence: proprietary, viewing only, no rights granted.
4. `apps/halal_boyz/README.md` and `packages/core/README.md` are unedited
   `flutter create` stubs. They are not descriptions of this project and were
   deliberately left untouched (renaming or rewriting them is a code change, not
   a documentation change).

---

## 19. Honest summary

What is strong here: a money path that re-prices on the server and cannot
double-charge; tenancy enforced in rules, queries and generated tests rather than
in convention; a security-rules layer with per-role field allowlists and a real
emulator harness behind it; a white-label factory that turns a config into an
app; and a quality battery where every gate has a named way to go red.

What is unfinished: deployment, one live migration, 56 recorded harness
failures, an unmounted owner panel, and an App Check helper whose production
behaviour is unmeasured. Those are listed with acceptance criteria rather than
hidden, which is the point of the `ROADMAP.md` discipline this repository runs on.
