# ORCHESTRATOR HANDOFF — read this first, assume nothing

**This document is self-contained.** It assumes the reader has never seen this
project, this repository, or this technology stack. It explains the business,
the product, every term used, what the code does today, what is missing, what
the owner has decided, and what must be built. Everything here was measured in
the working tree at `<repo>` unless tagged otherwise.

**This supersedes `docs/ORCHESTRATOR_BRIEF.md`.** Two appendices carry
line-level detail:

- `docs/PLATFORM_EXPANSION_EVIDENCE.md` — measurements with `file:line`.
- `docs/PLATFORM_EXPANSION_PLAN.md` — long-form design rationale.

## How to read the tags

| Tag | Meaning |
|---|---|
| **[PROVEN]** | Measured in the tree. Backed by a command, a diff, or `file:line`. |
| **[DECIDED]** | The owner stated it. Not open to redesign; consequences are listed. |
| **[OPEN]** | Needs a ruling. A recommendation is given, never silently defaulted. |
| **[UNVERIFIED]** | Plausible, not tested here. Must not be repeated as fact. |

---

# PART 1 — The business

## 1.1 What this company actually sells

**Carnama** builds **white-label restaurant apps**.

"White-label" means the software is built once and shipped under a restaurant's
own brand: their name, their logo, their colours, their own app-store listing,
their own Firebase backend. The restaurant's customers see "Halal Boyz", not
"Carnama". Carnama is invisible in the product.

The repository contains the **factory**, not one app: one shared codebase plus
a generator that produces a branded app from a JSON config file.

**[PROVEN]** The working example is `apps/halal_boyz` — "Halal Boyz", a real
demo client whose Firebase project is `demo-tenant`. It is 7 Dart source
files, because the entire app body is shared. Generating it is
`dart run tool/whitelabel.dart --config <client_config.json>` in `core_app`.

**[PROVEN]** Business model, pricing, contracts and customer count are **not**
recorded anywhere in the repository. Do not infer them. If they matter to a
decision, ask.

## 1.2 What the current product does (customer-facing only)

A person installs the restaurant's app and can:

- browse the menu (categories, tags, options, availability),
- add items to a cart with modifiers and quantities,
- check out and pay by card through **Stripe**,
- track the order status (pending → confirmed → preparing → cooking → ready →
  picked up / delivered),
- watch a delivery driver's position on a map,
- book a table or join a waitlist (slot/ticket based),
- earn loyalty points,
- receive push notifications,
- delete their account and export their data (GDPR).

The restaurant side, today, is a staff login that shows: a kitchen list of
orders, a delivery board, and an analytics screen with today's revenue.

## 1.3 What restaurant operators need that the app does not do

This is the whole reason for the expansion. A restaurant that sells through the
app **still runs its business on something else**, because:

| Real-world need | Today |
|---|---|
| A walk-in customer at the counter pays cash and takes food away | impossible — every order requires a card payment from a customer account |
| A waiter takes an order at table 4, adds a second round, brings the bill | impossible — no table concept exists |
| The kitchen marks one dish of a three-dish order as done | impossible — only whole-order status exists |
| The owner knows what each branch took today, by channel | impossible — one blended number, one branch concept, no channel dimension |
| The owner knows food cost and what is about to run out | impossible — no inventory at all |
| A manager covers a shift at the counter and also waits tables | impossible — one role per user |

The expansion turns a **customer ordering app** into a **restaurant operations
system**: counter (POS), waiter, kitchen, owner, with a real money ledger,
multi-branch reporting, and inventory.

## 1.4 Why this is commercially important

**[DECIDED, stated by the owner]** Generating client apps and *proving they
work* is the crucial capability. Every new surface must be generated per
client, not hand-installed. A feature that cannot be shipped to all clients
through the factory is not finished.

---

# PART 2 — The product to be built

## 2.1 Six roles

| Role | Who they are | What they do all day |
|---|---|---|
| `owner` | owns one or more branches | checks revenue, staff, refunds, menu, stock |
| `manager` | runs one branch | covers gaps, takes payments, adjusts menu, handles problems |
| `counter` | till staff | takes walk-in and phone orders, takes money, hands over food |
| `waiter` | floor staff | seats people, takes orders at the table, adds rounds, brings the bill |
| `kitchen` | kitchen staff | sees tickets, marks dishes done, flags delays |
| `customer` | the public | orders through the branded app (unchanged) |

A person may hold **several roles at once** (this is a hard requirement: small
restaurants have one person doing counter + floor). A person may work at
**several branches**; an owner may see **all** branches.

## 2.2 Four new staff surfaces

| Surface | Device | What it must do | What it must survive |
|---|---|---|---|
| **Counter / POS** | iPad in landscape, laptop fallback | pick items fast, take cash or card-present, open a table, print/show a receipt | a rush-hour queue; a browser reload mid-sale; the card reader dropping off |
| **Kitchen display** | wall tablet, arm's length | ticket queue, per-dish done, per-order delay with reason, audible alert on new ticket | glare, gloves, a 12-hour shift without reload |
| **Waiter** | phone (primary), iPad | table map, open a ticket, send rounds, request the bill | one-handed use while walking, patchy wifi |
| **Owner dashboard** | phone first, iPad second | revenue by branch and channel, top items, refunds, staff activity | being read on a train |

These are **web apps running in Safari**, installable to the iPad home screen
(a PWA). Native iPad apps are not the plan; the reason is deployment: a web
app updates instantly for every client, an App Store app does not.

## 2.3 The invariants (non-negotiable rules of the system)

1. No card data ever touches our servers — including card-present. The reader
   handles the card; we only ever receive a payment identifier.
2. Prices and totals are computed on the server from the menu. A client-sent
   price is never trusted, in any channel.
3. The money ledger is **append-only**. Corrections are new reversal rows.
   Nothing is deleted or edited to fix money.
4. Every staff action that changes state is authorised **on the server** and
   attributed to a user id.
5. Hiding a button is never security. Permissions are enforced server-side.
6. One client's data is never visible to another client.
7. Every new data collection ships with access rules, an index if it is
   queried, an automated test, and client writes of money state denied.

---

# PART 3 — Glossary: every term this project uses

Skip nothing here; the rest of the document assumes it.

## 3.1 Language and app framework

| Term | What it means here |
|---|---|
| **Dart** | The programming language. Version 3.11 in this repo. |
| **Flutter** | Google's UI toolkit that compiles Dart to Android, iOS, Windows and **web**. One codebase, several targets. Version 3.41.2 here. |
| **Widget** | A Flutter UI element. Screens are composed of widgets. |
| **Riverpod** | The state-management and dependency-injection library. `Provider`s are declared and read; this is how services are injected instead of being constructed inline. |
| **GoRouter** | The navigation library. Routes are declared in one file. |
| **freezed** | A code generator for immutable data classes. A `*.model.dart` has a generated `*.freezed.dart` sibling. |
| **`*.arb`** | Localisation files. `app_en.arb` / `app_ar.arb` hold every user-visible string. A missing key fails a test. |
| **PWA** | Progressive Web App: a website that can be installed to a home screen and run without browser chrome. |

## 3.2 Repository mechanics

| Term | What it means here |
|---|---|
| **Monorepo / workspace** | Several Dart packages in one repository, resolved together. Root `pubspec.yaml` declares the members; there is no separate `melos.yaml` file despite the Melos tooling being used. |
| **Package** | A reusable library. Four matter: `core_app` (the app itself, package name `labs`), `packages/core` (domain + services), `packages/core_ui` (design system), `apps/<client>` (a generated shell). |
| **Worktree** | A second checkout of the same git repo on a different branch, in a different folder. This repo has **11**, which is why "where is the latest code" is not obvious. |
| **Golden test** | A UI test that compares a rendered screen against a committed PNG. Catches visual regressions. |

## 3.3 Backend

| Term | What it means here |
|---|---|
| **Firebase** | Google's backend platform. This app uses five parts: Auth, Firestore, Cloud Functions, Cloud Messaging, App Check. |
| **Firestore** | A document database. Data lives in **collections** (like tables) containing **documents** (JSON objects). Example: `orders/{orderId}`. Documents can have subcollections. |
| **Firebase Auth** | Sign-in (email/password etc.) issuing ID tokens. |
| **Security rules** | A server-side policy file (`core_app/firestore.rules`, 811 lines) evaluated by Firebase on **every** read and write from an app. This is the real access authority for direct database access — not the app code. |
| **Cloud Functions** | Server-side TypeScript (`core_app/functions/src/index.ts`, 2,282 lines). |
| **Callable** | A Cloud Function invoked from the app like a remote method. Carries the caller's auth automatically, and needs App Check. This is where privileged logic lives. |
| **Trigger** | A Cloud Function that runs because something happened: a document written, a schedule fired, an auth user created. |
| **Custom claims** | Extra fields baked into a user's ID token, e.g. `role`. Readable by rules without a database lookup. Changing them requires a token refresh. |
| **App Check** | Firebase's proof that a request comes from the genuine app, not a script. |
| **FCM** | Firebase Cloud Messaging, for push notifications. |
| **Emulator** | A local Firebase instance for testing rules and functions without touching a real project. Rules tests run here. |

## 3.4 Payments

| Term | What it means here |
|---|---|
| **Stripe** | The payment processor. |
| **PaymentIntent** | Stripe's object representing one payment attempt, with an amount, a currency and metadata. The server creates it; the client confirms it. |
| **Client secret** | A one-time string that lets a client complete a specific PaymentIntent without seeing the secret key. |
| **Webhook** | An HTTP call from Stripe to our server saying "this payment succeeded". Already implemented. |
| **Stripe Terminal** | Stripe's in-person card product: physical readers (WisePOS E, S700/S710, T600, Verifone) plus an API. |
| **Reader / Location** | A registered card terminal, and the Stripe record of where it physically is (one per branch). |
| **Server-driven integration** | A Terminal mode where our **server** calls the Stripe API and the reader talks to Stripe directly. No device SDK, no Bluetooth, no local network requirement. This is the mode this project needs — see §9. |
| **`card_present`** | Stripe's payment-method type for a card read by a physical terminal, as opposed to `card` typed into a form. |

## 3.5 Project-specific vocabulary

| Term | Meaning |
|---|---|
| **Tenant** | One restaurant client (e.g. Halal Boyz). **As of the owner's decision, all tenants share one Firebase project** and are separated by a `tenantId` field. |
| **Branch** | One physical location of one tenant, e.g. "Halal Boyz — Camden". A tenant has many branches. |
| **Channel** | How an order arrived: `app`, `counter`, `waiter`, `phone`, `kiosk`, `platform` (third-party marketplace). |
| **Ticket / tab** | A dine-in order that is still open and can receive more items before it is paid. |
| **Ledger** | The append-only record of money events (`transactions`). The single source of truth for revenue. |
| **Reversal** | A compensating ledger row that cancels another row. Never an edit, never a delete. |
| **Rollup** | A pre-computed daily summary per branch (`daily_rollups`), treated as a cache that can always be rebuilt from the ledger. |
| **Capability** | A named permission (`order.create`, `payment.take`) checked on the server. Roles map to capability sets. |
| **86 / 86ing** | Restaurant slang: an item has run out and must be marked unavailable. |
| **Z-report** | The end-of-day sales summary a restaurant reconciles against the till. |
| **Whitelabel generator** | `core_app/tool/whitelabel.dart` (4,863 lines): turns a JSON config into a branded, buildable client app plus its backend folder. |

---

# PART 4 — The repository, from zero

## 4.1 Layout

```text
<repo>
├─ pubspec.yaml             workspace root: lists the member packages
├─ core_app/                THE APP (package name "labs") — the shared body
│  ├─ lib/app_bootstrap.dart       the one boot sequence every app uses
│  ├─ lib/main.dart                the template app's entry point
│  ├─ lib/app/app_router.dart      42 routes (customer + staff)
│  ├─ lib/features/                auth, orders, checkout, admin, driver, loyalty…
│  ├─ lib/l10n/                    app_en.arb (749 strings) + app_ar.arb
│  ├─ functions/                   server-side TypeScript
│  ├─ firestore.rules              access authority (811 lines)
│  ├─ firestore.indexes.json       23 composite indexes
│  ├─ test/                        433 Dart test files + rules emulator suites
│  └─ tool/whitelabel.dart         the client generator
├─ apps/halal_boyz/         one generated client — 7 Dart files, 23 files total
├─ packages/core/          domain models + services (114 files)
├─ packages/core_ui/       design system, theme tokens, shared widgets (95 files)
├─ docs/                   runbooks + this handoff
└─ tool_uilib/             per-phase specs and receipts (p32, p33…)
```

**[PROVEN]** 4,016 tracked files. Platforms configured: android, ios,
windows. **There is no `core_app/web/` directory** — the web target has never
been created.

## 4.2 What each part is for

| Path | Responsibility | Why it is separate |
|---|---|---|
| `packages/core` | Models (`UserModel`, `OrderModel`, `CartModel`), services (auth, sync queue, presence, payment), Firestore access | Must be reusable by every client app and testable without a UI |
| `packages/core_ui` | Theme, tokens, shared widgets, skeletons | The brand is data; the widgets are shared |
| `core_app` | Composition: boot, routing, screens, features, server code, rules | The actual product |
| `apps/<client>` | A generated shell: `main.dart` + `GeneratedApp` + that client's Firebase options + its `backend/` folder of rules copies | Client identity lives only here |

## 4.3 The files that matter most for this work

| File | What it does | Why it matters |
|---|---|---|
| `core_app/lib/app_bootstrap.dart` | The 16-step boot chain (demo guard → FCM background handler → error widget → error handler → bindings → env → config load → fonts → DI holder → logger → gates → Firebase init → Isar → runApp) | Any new platform or surface enters here; the gates must keep failing closed |
| `core_app/lib/app/app_router.dart` | Every route, including `/owner`, `/manager`, `/kitchen`, `/delivery`, `/role-router`, `/admin-gateway` | New surfaces are new routes here |
| `packages/core/lib/src/auth/user_model.dart` | `enum UserRole { owner, manager, kitchen, delivery, customer }` and a **single** `role` + **single** `branchId` | The model that must grow roles and branch sets |
| `core_app/functions/src/access.ts` | `STAFF_ROLES` + `assertStaffRole()` (fails closed on the JWT claim) | The single server-side permission gate to generalise |
| `core_app/functions/src/index.ts` | All callables and triggers, including `createChargeIntentCore`, `createOrder`, `cancelOrder`, `syncUserRoleClaims` | Money and roles are implemented here |
| `core_app/firestore.rules` | Per-collection, per-role rules with field-shape locks | Must become tenant-aware without exploding |
| `core_app/lib/features/admin/domain/kitchen_service.dart` | Kitchens stream the branch queue (cap 200) and update status via a transaction + queued sync | The template for every new staff surface |
| `core_app/lib/features/admin/domain/analytics_provider.dart` | Today's revenue via a Firestore aggregate; top dishes by grouping 200 docs in the client | Shows exactly why a ledger + rollups are needed |
| `packages/core/lib/src/presence/presence_service.dart` | Writes `presence/{uid} {isOnline,lastSeen,branchId,role}` | Free building block for "who is on the floor" |
| `packages/core/lib/src/network/sync_queue.dart` | `abstract class SyncQueue` (line 60), `IsarSyncQueue` (line 80) | An existing seam for an offline queue on any platform |
| `core_app/tool/whitelabel.dart` | The generator | Every feature must survive generation |

---

# PART 5 — How the system works today, end to end

## 5.1 Booting an app

Every app — the template and every generated client — calls one function,
`initCarnamaApp()`, with its own inputs. The chain is deliberately ordered and
fail-closed: a placeholder Firebase key or an invalid client config produces a
blocking screen **before** Firebase initialises, rather than a broken app.
Generated clients additionally pass a Firebase-error screen builder, which
makes boot fail closed instead of degrading silently.

## 5.2 Signing in and knowing who you are

A user signs in through Firebase Auth. Their profile lives in `users/{uid}`
with `role` and `branchId`. A trigger (`syncUserRoleClaims`) copies the role
into the user's JWT claim. The app routes by role: `/role-router` switches to
the owner, manager, kitchen or delivery dashboard; `RoleGate` adds a client-side
check, and `NoPermissionRedirect` handles the refusal. The server separately
checks the claim, so a tampered client cannot escalate.

## 5.3 Ordering and paying (the money path — the strongest part)

```text
customer taps pay
   → app calls createPaymentIntent
       → server re-prices EVERY line from the menus collection
       → server derives tax, promo discount, delivery fee, currency
       → server creates a Stripe PaymentIntent (amount, metadata, idempotency key)
       → returns a client secret
   → app confirms the card with Stripe (card data never reaches us)
   → Stripe webhook: payment_intent.succeeded
   → app calls createOrder
       → server requires a SUCCEEDED intent whose metadata.createdBy == caller
       → server re-verifies tax/discount against the intent
       → server writes the order document (customerId = caller)
   → kitchen stream picks it up; status changes flow back to the customer
```

Two properties matter: the server never trusts a client price, and the order
cannot be created without a real, owned payment.

**The consequence for the expansion:** this path is why a walk-in cash order is
impossible today. There is no code path that creates an order *without* a card
payment bound to the caller's account.

## 5.4 Kitchen, today

Kitchen staff open `/kitchen`, which streams orders for their branch filtered
by status, ordered by creation time, capped at 200. Tapping "next status" runs
a Firestore transaction and queues a status update. The screen is a phone list:
8-pixel gaps, 24-pixel icons. It is not usable at arm's length, in gloves, on a
wall.

## 5.5 Owner analytics, today

One number for revenue today: a Firestore aggregate (`sum(totalCents)` plus a
count). Top dishes are computed by fetching up to 200 orders and grouping them
in the client. There is no per-branch breakdown, no channel dimension, no time
series, and no server-side rollup. Firestore cannot `GROUP BY`, so this cannot
be fixed by a bigger query — it needs pre-computed summaries.

## 5.6 Presence

Staff with a branch get a `presence/{uid}` document updated on app lifecycle:
`isOnline`, `lastSeen`, `branchId`, `role`. It is best-effort telemetry that
can never crash the app.

## 5.7 Generating a client (the factory, today)

```bash
dart run tool/whitelabel.dart --config apps/halal_boyz/assets/client_config.json
```

It validates the config (and refuses on placeholder credentials), creates the
app directory, writes a thin `main.dart` + `GeneratedApp`, copies the client's
Firebase options, writes `assets/client_config.json`, copies fonts and icons,
creates a `backend/` folder with **copies** of `firestore.rules`,
`storage.rules`, `firestore.indexes.json`, `.firebaserc` and a `firebase.json`
that points functions at the **shared** `core_app/functions`, then runs
post-gates: branding tools, `flutter test`, a debug APK build, and a
fail-closed Firebase configuration check. Those exits are 75 / 72 / 73 / 74.

So: **functions are shared by path; rules and indexes are per-client copies.**
**[PROVEN]** today `apps/halal_boyz/backend/firestore.rules` is byte-identical
to `core_app/firestore.rules`. The moment this project edits rules, every
existing client's copy goes stale unless the factory is handled deliberately.

## 5.8 What "real-time" means here

There is no socket server and no message broker. Real-time = Firestore
listeners: the app subscribes to a query and Firebase pushes document changes.
Kitchen listens to a branch queue; delivery tracking listens to
`deliveries/{orderId}`. Composite indexes for these queries already exist.

---

# PART 6 — What is proven working, and what is proven missing

## 6.1 Working (do not rebuild)

| Capability | Evidence |
|---|---|
| Server-authoritative pricing | `createChargeIntentCore`: re-prices every line via `verifyMenuPricing`, derives tax/promo/currency via `resolveChargeTaxAndPromo`, clamps the delivery fee, one metadata builder, idempotency key |
| Order ownership binding | `createOrder` requires a succeeded PaymentIntent with `metadata.createdBy === uid` and re-verifies totals |
| Role claim + server gate | `syncUserRoleClaims` trigger; `assertStaffRole()` fails closed on the token claim |
| Rules with field-shape locks | 811 lines; per-role `affectedKeys().hasOnly([...])`; `audit_log` writes are `false` |
| White-label factory | generator validates config, emits a shell + backend, runs four post-gates that build and test the result |
| Thin client shell | `apps/halal_boyz/lib/main.dart` → `initCarnamaApp`; `app.dart` → `const CoreApp()`; no forked body |
| Fail-closed boot | 16-step chain with config-schema and Firebase-key gates before Firebase init |
| Presence | `presence/{uid}`, staff-only, injected, cannot crash the lifecycle |
| Realtime + indexes | Firestore snapshots; `branchId+status+createdAt` composites already present |
| Offline queue seam | `SyncQueue` interface with an Isar implementation |
| Static health | `flutter analyze --no-pub` in `core_app`: **No issues found**, 137 s, exit 0 (**my run**) |
| Test assets | 433 Dart test files, rules emulator suites, contract tests, goldens, `npm test` = `tsc` + `node --test` |

## 6.2 Missing, stubbed, or contradictory

| Gap | Evidence |
|---|---|
| `counter` / `waiter` roles | `UserRole` enum has neither |
| Several roles per user | `UserModel.role` is a single string; the claim is a single `role` |
| Several branches per user | `UserModel.branchId` is a single value; `userBranch()` in rules is single |
| A second owner | `isOwner()` compares one `settings/ownerInfo.ownerEmail` |
| Tenancy in rules | `grep -c clientId core_app/firestore.rules` → **0** |
| Staff-created orders / cash | `createOrder` requires a card PaymentIntent bound to the caller's uid |
| `tables`, `transactions`, `ingredients`, `recipes`, `stock` | absent from a full `collection('…')` census of the whole repo |
| Per-dish state | `OrderStatus` is whole-order only; kitchen queue payload is `{id,status}` |
| `channel`, `staffId`, `tableId`, `paymentMethod` on orders | not in the rules create allowlist; `orderSource` is server-owned |
| Branch/channel reporting | one aggregate over the whole collection; top dishes over a 200-doc client-side cap |
| Stripe Terminal | only `nfc_terminal_service.dart`, a placeholder with `TODO_DEPLOY` |
| Thermal printing | **zero** hits for thermal/ESC-POS/printing across all ~30 branches and all 11 worktrees; no printing dependency in any pubspec; `DEFERRED.md` H2 still says "Unstarted" — yet the owner says it is done (see Part 7.3) |
| Web target | no `core_app/web/`; 8 library files import `dart:io` unconditionally; Isar and workmanager are mobile-only |
| Responsive layout | exactly **one** file in `core_app/lib` uses `LayoutBuilder`/`MediaQuery.size` (`checkout_screen.dart`) |
| Kitchen-proof UI | `kitchen_dashboard.dart` is a phone list (8 px gaps, 24 px icons) |

---

# PART 7 — The owner's decisions, and what each one costs

## 7.1 **[DECIDED] One Firebase project for everything**

Today each client has its own Firebase project. That is now reversed: a single
project serves all tenants, separated by `tenantId`.

This is the most expensive decision in the programme and it must not be
glossed over:

| Consequence | Detail |
|---|---|
| Every document needs `tenantId` | all collections, old and new |
| Every rule path must check it | a single missed check leaks one client's data to another — the highest-severity risk in the project |
| All 23 indexes need the tenant field | `firestore.indexes.json` is rewritten |
| One shared user pool | a customer of tenant A can sign in to tenant B's app; membership must be explicit and checked at sign-in |
| Claims grow | `tenantId`, `roles[]`, `branchIds[]` |
| Owner identity becomes per-tenant | today it is one email for the whole project |
| Notifications need namespacing | one sender; a token must belong to one tenant |
| App Check | enforced project-wide; each web client needs its own reCAPTCHA site key for its own domain |
| Deployment | **simpler** (one deploy reaches everyone) and **riskier** (a rules regression ships to everyone at once) |

## 7.2 **[DECIDED] Stripe Terminal (card-present) is required in the POS**

Not deferred. Today only a placeholder exists. The important finding is that
the obvious integration path does not exist:

- Stripe has **no official Flutter Terminal SDK**. Flutter is not among their
  supported platforms (iOS, Android, React Native, JS, .NET, Java).
- The third-party `stripe_terminal` pub package is Android-Bluetooth only and
  lists its own missing features.
- Stripe recommends **server-driven** integration for smart readers. The JS SDK
  requires POS and reader on the same LAN with working local DNS, and Chrome
  142+ requires an explicit local-network permission.

So card-present is implemented **server-side** (§9). It therefore does not
depend on which platform the staff surfaces use — which removes the coupling
between two large decisions.

## 7.3 **[DECIDED] Thermal printing is done — but the tree disagrees**

The owner states it is done. Measurements say otherwise: no implementation on
any branch, no uncommitted files in any worktree, no printing dependency in any
pubspec, and `core_app/DEFERRED.md` H2 still records it as unstarted.

This is recorded as a contradiction, not a correction of the owner: the code
may live outside this repository, or on a device via a vendor app, or the
register was never updated. Until the implementation is identified, receipts
are planned as unbuilt (on-screen + system print + Stripe email receipt).
Writing "thermal printing works" into a plan would be fabrication.

## 7.4 **[DECIDED] Localisation is a gate**

`app_en.arb` has 749 quoted strings, an Arabic set exists, and a plural
completeness test enforces parity. Every new string lands in both, in the same
commit.

---

# PART 8 — Target architecture

## 8.1 The decisions an orchestrator must ratify

| ID | Decision | Recommendation | Status |
|---|---|---|---|
| A1 | How tenancy is enforced: flat collections + `tenantId` field, or paths rooted at `tenants/{tenantId}/…` | flat + field, enforced by one rules helper on every match block, proven by a generated per-collection cross-tenant denial test | **[OPEN Q1]** |
| A2 | Whether the existing client's project migrates into the shared project | fresh shared project, Halal Boyz as tenant #1, old project read-only for a settling period | **[OPEN Q2]** |
| A3 | Roles become a set | `users.roles[]` authoritative; `role` stays as a derived legacy field; claims carry `roles`, `branchIds`, `tenantId`; rules read claims instead of a per-rule document `get()` | ready |
| A4 | Order mutation authority | moves into callables; client-direct order writes shrink to "customer cancels while pending"; money collections become `write: false` | ready |
| A5 | Dine-in model | an open table ticket **is** an `orders` document with `isOpenTab: true` + `tableId` — not a parallel collection | ready |
| A6 | Ledger | append-only `transactions`, written in the same transaction as the order change; reversals are new rows | ready |
| A7 | Real-time | keep Firestore snapshots; add an append-only `order_events` feed for chimes and activity; no broker | ready |
| A8 | Staff surface platform | Flutter web in the same codebase, gated by a 2-day spike with a pre-agreed fallback | **[OPEN Q6]** |
| A9 | Card-present | server-driven Terminal from Cloud Functions; a `card_present` mode on the existing intent core | ready |
| A10 | Receipts | on-screen + system print + Stripe email until the thermal implementation is identified | **[OPEN Q3]** |
| A11 | Reporting | CF-maintained `daily_rollups` per branch-day, treated as a rebuildable cache | ready |
| A12 | Inventory | schema, rules and empty UI in Phase 1; behaviour in Phase 4 | ready |

## 8.2 Why authority moves into callables (the structural pivot)

Today the app writes order fields directly to Firestore, and rules constrain
*which* fields each role may touch, e.g. kitchen may change only `status` and
`updatedAt`. That works for whole-order status.

It does not work for the target system, because the target needs: per-dish
ready flags, adding items to an open ticket, splitting a bill, taking cash,
recording a ledger row, releasing a table, flagging a delay. Expressing each of
those as a field-shape rule for each role is a combinatorial explosion, and it
still cannot enforce "the total must equal the sum of the lines".

So: staff actions become **server calls** that validate capability, branch,
tenant, payload and money, write the domain change and the event/ledger rows in
one transaction, and rules shrink to "deny everything except the customer-safe
allowlist". That is fewer rules, one permission gate, and an audit trail by
construction.

## 8.3 Data model (additive; none of the new collections exist today)

```text
# EVERY document in EVERY collection
tenantId: string

# users
roles: string[]          # authority
branchIds: string[]      # authority
tenantIds: string[]       # membership in the shared project
role: string             # legacy, derived
branchId: string         # legacy, derived
activeBranchId: string   # UI preference only, never an authorisation input

# orders (existing doc + new server-written fields)
channel: 'app'|'counter'|'waiter'|'phone'|'kiosk'|'platform'
staffId, staffRoles, tableId, tableLabel, guestName, isOpenTab
paymentMethod: 'card'|'card_present'|'cash'|'external'|'unpaid'|'comp'
paymentRef: map
items[].lineId, .readyAt, .readyBy, .course, .notes
kitchen: {acceptedAt, acceptedBy, readyAt, delayReason, delayNote}

transactions/{txId}    # APPEND-ONLY LEDGER, written only by the server
  orderId, orderNumber, tenantId, branchId, channel, staffId, staffRoles,
  customerId|null, guestName|null, tableId|null,
  itemsSubtotalCents, taxCents, tipCents, discountCents, deliveryFeeCents,
  totalCents, currency, paymentMethod, paymentRef,
  items[]              # immutable snapshot of names and prices
  occurredAt, recordedAt, status: 'captured'|'reversed',
  reversalOf|null, reversalReason|null, idempotencyKey, schemaVersion

order_events/{eventId} # append-only change feed
  orderId, tenantId, branchId, type, from, to, lineId,
  actorUid, actorRoles, channel, at, meta

tables/{tableId}
  tenantId, branchId, label, zone, seats,
  status: 'free'|'seated'|'ordering'|'served'|'bill_requested'|'needs_cleaning',
  currentOrderId|null, assignedWaiterId|null, openedAt|null, version

terminals/{id}         # Stripe readers
  tenantId, branchId, stripeReaderId, serial, label, status, lastSeenAt

branches: + terminalLocationId, timezone

staff_shifts/{branchId}_{uid}_{yyyymmdd}
  clockInAt, clockOutAt, roles, ordersCount, salesTotalCents

daily_rollups/{branchId}_{yyyyMMdd}   # cache, rebuildable from transactions
  revenueByChannel{}, ordersCount, avgTicketCents, refundsCents,
  topItems[], staffActivity{}, updatedAt, version

ingredients/{id}       # Phase 4
  name, unit, sku, costPerUnitCents, parLevel, lowStockThreshold,
  allergens[], isActive, supplier
recipes/{menuItemId}   # Phase 4
  lines[{ingredientId, qty, unit}], yieldQty, version
branches/{branchId}/stock/{ingredientId}
  qty, updatedAt, lastCountAt
stock_moves/{moveId}   # append-only journal
  type: 'order_deduction'|'receipt'|'waste'|'adjustment'|'reversal',
  qtyDelta, unit, orderId|null, actorUid, at, note
alerts/{alertId}
  type: 'low_stock'|'order_delayed'|'cash_variance', severity,
  createdAt, acknowledgedAt, acknowledgedBy
```

## 8.4 Migration mechanics (must be scripted, idempotent, gated)

1. `migrate_v004_tenancy` — stamp `tenantId` everywhere; dry-run first; report
   per-collection counts; refuse on conflicting existing values.
2. `migrate_v005_roles` — `roles = [role]`, `branchIds = [branchId]`,
   `tenantIds = [tenantId]`; then write claims (`revokeRefreshTokens` on any
   privilege change).
3. Rules deploy is **gated behind** a passing emulator suite that includes a
   cross-tenant denial case for **every** collection.
4. The old per-client project is never mutated in place by a script: export →
   import → verify counts → switch the generated client's Firebase options →
   leave the old project read-only.

---

# PART 9 — Proposed solutions, written against this codebase

## 9.1 Tenancy

| Piece | Where | Shape |
|---|---|---|
| Tenant identity | `apps/*/lib/app/core_config_adapter.dart` + `ClientCoreConfig` | `tenantId` is a required config key derived from the bundle id at boot, failing the existing schema gate if absent — never defaulted |
| Query surface | new `packages/core/lib/src/network/tenant_firestore.dart` | `TenantFirestore` wraps the Firestore instance; `collection(name)` injects `where('tenantId','==',t)` so the ~297 call sites cannot forget it by construction |
| Writes | same wrapper | `doc()`/`set()` stamp `tenantId` from injected config, never from a caller argument |
| Rules | `core_app/firestore.rules` | one `tenantOk()` helper applied to **every** match block; `settings/ownerInfo` moves under the tenant root so owners are per-tenant |
| Claims | `functions/src/index.ts` | extend `syncUserRoleClaims` to `tenantId` + `roles[]` + `branchIds[]`; revoke refresh tokens on any change |
| Sign-in | `packages/core/lib/src/auth/auth_repository.dart` | after sign-in, verify tenant membership; otherwise fail closed with an explicit screen |
| Notifications | `packages/core/lib/src/notifications/fcm_service.dart` | topics prefixed per tenant; token documents keyed by tenant |
| Indexes | `firestore.indexes.json` | tenant field prepended to all 23 composites, regenerated by script to avoid hand-editing |

## 9.2 Roles and capabilities

| Piece | Where | Shape |
|---|---|---|
| Role set | `packages/core/lib/src/auth/user_model.dart` | add `counter`, `waiter`; add `roles[]`/`branchIds[]` with derived legacy getters to keep the blast radius small |
| Capability table | new `functions/src/permissions.ts` | pure TS, no imports: `Record<Role, Capability[]>` + `can()`, with an exhaustive cartesian test so a new role cannot ship undefined |
| Server gate | `functions/src/access.ts` | `assertCapability` + `assertBranchScope` + `assertTenant`, replacing `assertStaffRole`; one `withStaffGuard(cap, handler)` wrapper so no callable hand-rolls checks |
| Client affordances | `role_gate.dart`, `role_router_screen.dart` | keep presentation-only (the existing split is correct); the router switches on role **sets** |
| Routes | `core_app/lib/app/app_router.dart` | `/counter`, `/waiter` added beside the existing staff routes |

## 9.3 Orders, ledger, dine-in

| Piece | Where | Shape |
|---|---|---|
| Extract pricing | `functions/src/index.ts` | move the menu cross-check + tax/promo/fee composition into `priceCartCore()`; both customer and staff paths call it. Guarded by the existing `order_create_payload_contract_test.dart` and MONEY-1 cases |
| Staff orders | new `functions/src/staff_orders.ts` | `createStaffOrder`, `addOrderItems`, `transitionOrder`, `setItemReady`, `closeTicket`, `reverseTransaction` — each with App Check, capability, branch, tenant, zod schema, idempotency key, and one transaction over order + ledger + event |
| Ledger | new `functions/src/ledger.ts` | one `appendTransaction()` used by every money path, including today's customer `createOrder`, so a ledger row has exactly one birthplace |
| Rules | `firestore.rules` | order writes shrink to the customer-cancel allowlist; `transactions`, `order_events`, `stock_moves`, `alerts` become `write: false` (the existing `audit_log` pattern) |
| Dine-in | `orders` only | `isOpenTab` + `tableId`; `KitchenService` and analytics keep one source |
| Rollups | new `functions/src/rollups.ts` | recompute one branch-day from the ledger, compare-and-set on `version`; a test asserts rollup == from-scratch rebuild |

## 9.4 Card-present (Terminal)

| Piece | Where | Shape |
|---|---|---|
| Intent mode | `functions/src/index.ts` | `createChargeIntentCore` gains `paymentMethodTypes: ['automatic'|'card_present']`; `automatic_payment_methods` stays for the app |
| Charging | new `functions/src/terminal.ts` | `processTerminalPayment` → create PI → `terminal.readers.processPaymentIntent(readerId, {payment_intent})`; returns ids only, never a client secret |
| Status | same file | `getTerminalPaymentStatus` (bounded poll) + `terminal.reader.action_succeeded/failed` webhooks into `order_events` |
| Confirmation | existing `stripeWebhook` | already resolves the order by `metadata.orderId`; Terminal rides it unchanged |
| Registry | `terminals/{id}` + `branches.terminalLocationId` | registration is a callable so a reader cannot be claimed by the wrong branch |
| Client | new `core_app/lib/features/pos/domain/terminal_reader.dart` | no SDK, no Bluetooth: a callable client plus a state machine `idle → amountShown → cardPresented → approved|declined|timeout` |

## 9.5 Web reach (if A8 is approved)

The port is an enumerated list, not a mystery:

| File | Change |
|---|---|
| `app_bootstrap.dart:35` | conditional import; the web branch skips Isar/workmanager/Crashlytics and keeps App Check (FCM via web push or an explicit degradation) |
| `packages/core/.../logger_service.dart:2` | conditional sink: file on mobile, console + buffer on web |
| `packages/core_ui/.../app_theme.dart:2` | `Platform.isIOS` → `defaultTargetPlatform` (already web-safe) — a one-line fix |
| `cache/isar_service.dart`, `kitchen/kitchen_offline_service.dart` | `WebSyncQueue implements SyncQueue` (memory + IndexedDB) selected by `kIsWeb`; the interface already exists at `sync_queue.dart:60` |
| `force_update_guard.dart`, `data_export_service.dart`, `proof_of_delivery_service.dart` | conditional stubs that fail loudly rather than silently doing nothing |
| platform folder | `flutter create --platforms=web .`; per-client web manifest + icons emitted by the generator |
| layout | a `core_ui` breakpoint helper (`compact <600 ≤ medium <1024 ≤ expanded`) and staff screens built responsive from the first commit |

## 9.6 Fleet factory

1. `ClientConfig` gains `tenantId`; both validators (runtime gate + generator) updated together — they are pinned by tests.
2. Backend parity: `--refresh-backend` or a parity test, because per-client rules copies are byte-identical **today** and will not stay that way.
3. Web manifest and icons in generated output for iPad installability.
4. `DEPLOY.md` template gains the single-project deploy order: functions → rules → indexes → client config.

---

# PART 10 — Phases, with acceptance criteria

Durations assume one developer and are planning figures. A phase is done when
the criteria are demonstrably true, not when tasks are ticked.

## Phase 1 — Foundation: tenancy, roles, ledger, owner dashboard (4 weeks)

Tenancy work is what makes this four weeks instead of three; the one-project
decision touches every collection.

**Acceptance criteria**

- [ ] `flutter analyze` clean; existing Dart suite green; functions `npm run build` clean.
- [ ] Rules emulator: a tenant-A user reading **any** tenant-B collection is denied — proven by a generated test that enumerates collections, not a hand-picked few.
- [ ] `roles: ['manager','waiter']` passes both capability checks; a `waiter`-only user is denied `payment.take` **by the server**, with a test asserting the error code.
- [ ] Backfill scripts are idempotent: a second run changes zero documents.
- [ ] Every money event from the existing customer flow writes exactly one ledger row; a reversal writes a second row and the original is byte-identical afterwards.
- [ ] A rollup equals a from-scratch rebuild from the ledger (asserted in a test).
- [ ] Owner dashboard renders at 390 px and 1024 px with no overflow, showing branch and channel breakdown.
- [ ] Generator dry-run clean for an existing client; a scratch client generates and passes its own post-gates.

**Demoable:** multi-role sign-in with a live server-side denial; ledger rows from a real order; reversal as an append; per-branch revenue; the web-spike verdict.

## Phase 2 — Counter (POS) and kitchen, cash and card-present (4 weeks)

- [ ] Cash sale writes one order, one ledger row, one event; a double-tap on tender produces **one** row (idempotency proven by test).
- [ ] Card-present sale: intent → reader → webhook → paid order → ledger row, using Stripe's simulated reader.
- [ ] A tampered client price is rejected on the POS path exactly as on the app path (same helper, one test each).
- [ ] Kitchen: per-dish ready and per-order delay write events; a reload mid-service loses no state; a chime fires on new events.
- [ ] Offline cash queue drains without duplicating; server rejections surface in a visible exception list.
- [ ] Rules deny client writes to ledger, events and order state outside the customer-cancel allowlist.

**Demoable:** walk-in cash sale; reader sale; per-dish completion and a delay with reason; tamper rejection; role denial on `payment.take`.

## Phase 3 — Waiter and multi-branch (3 weeks)

- [ ] Two devices cannot seat the same table twice (the second write fails on `version`).
- [ ] An open ticket accepts items from another device and closes at the counter with a matching ledger row.
- [ ] Staff shifts clock in/out and feed per-staff sales.
- [ ] Owner switches branch and sees figures that reconcile to the ledger.

## Phase 4 — Inventory (3 weeks)

- [ ] Selling a dish decrements stock by its recipe in the same transaction as the ledger row.
- [ ] A reversal restores stock through a compensating `stock_moves` row; the original is unchanged.
- [ ] Replaying an order event deducts once (idempotency keyed on the order line).
- [ ] Low-stock alert fires at threshold; `alerts` is client-read-only.

---

# PART 11 — Verification gates (every phase)

```bash
(cd core_app && flutter analyze --no-pub)
(cd core_app && flutter test)
(cd core_app/functions && npm run build && node --test)
(cd core_app && firebase emulators:exec --only firestore,storage \
   "flutter test test/firestore_emulator_rules_test.dart")
(cd core_app && dart run tool/whitelabel.dart \
   --config ../apps/halal_boyz/assets/client_config.json --dry-run)
```

The last one is the fleet gate: it proves the factory still validates an
existing client after the change.

**[UNVERIFIED]** Only `flutter analyze` was actually run in this assessment.
The other four commands are the intended definition of green, not a report of
current status.

---

# PART 12 — Security model, and the later Pentagi phase

## 12.1 Required posture after tenancy

| Control | Requirement |
|---|---|
| Tenant isolation | deny-by-default per collection, proven by a generated test |
| Capability checks | every callable: capability + branch + tenant, before touching data |
| Money writes | client writes to ledger/events/stock denied; Admin SDK only, inside callables |
| Role changes | force token refresh on change, never wait for expiry |
| App Check | on every callable |
| Idempotency | required for every money-moving call |
| Audit | actor, roles, branch, channel, before/after on every staff state change |
| Blast radius | one project = one compromise distance; the controls above are mandatory |

## 12.2 Pentagi

PentAGI is a self-hosted Docker stack (2 vCPU, 4 GB RAM, 25 GB disk, one LLM
provider key, console on `https://localhost:8443`) that runs each engagement in
an isolated sandbox with nmap/sqlmap/Metasploit/a browser, and reports
findings.

- **High value:** the staff web app and the callable HTTP endpoints — privilege
escalation, cross-tenant access, IDOR on order/table/transaction ids, price and
payment-method tampering, idempotency-key replay.
- **Low value:** `firestore.rules`. Rules are enforced by Firebase for SDK
clients; a web crawl never exercises them. The **emulator suite remains the
authority** for rules and must grow a case per collection and per callable.
- **No value:** the Flutter mobile binary.

Preconditions: a staging project (never a client's live one), seeded users for
every role and tenant, test-mode Stripe, no real personal data, written
authorisation for the exact hosts, and a firewalled host — the sandbox
publishes callback ports 28000–29999 on every interface by default, which is
the most common self-hosting mistake.

---

# PART 13 — Quality report on the codebase

Scored for this expansion's purposes, not abstract beauty.

| Area | Score | Reasoning |
|---|---|---|
| Money correctness | **9/10** | Server re-prices from the menu, derives tax/promo/fee, one metadata builder, idempotent, order re-verifies the intent. Most POS backends trust the client and reconcile later; this refuses the order. The missing point is the documented residual: `calculateTax` trusts a client subtotal |
| Access-control design | **7/10** | Real rules with shape locks, CF-only audit writes, claim-based gate. But one role, one branch, no tenancy, and a document `get()` per rule evaluation: the pattern is sound, the model is too small |
| Access-control coverage | **6/10** | Deny-by-default where it matters, but the order create allowlist is narrower than the product needs and there is no tenant test to extend. The emulator suites are the saving grace |
| Architecture / modularity | **7/10** | Clean layering, real dependency injection (services take injected Firestore + logger; no inline `FirebaseFirestore.instance`), 15/15 freezed models. Docked for phone-only layout and mobile-only dependencies |
| White-label engineering | **8/10** | The factory is real and its post-gates build the result. Docked for per-client rules **copies** (a drift trap) and a generator with no multi-surface or multi-tenant concept |
| Test infrastructure | **7/10** | 433 test files, goldens, rules emulator suites, contract tests, wiring tests. Docked because the suite's green state is unverified here, as is the claimed coverage floor |
| Observability / operability | **7/10** | Structured logger with a tested boot isolation, Crashlytics wiring, presence, audit collections, real runbooks. No server-side business metrics or queue-depth visibility |
| Real-time design | **8/10** | Uses the platform properly, no premature broker, indexes already present. Docked for having no change feed, so nothing can react to "what just happened" without diffing documents |
| UI craft | **6/10** | Tokens, goldens, real design work — but one `LayoutBuilder` in the whole app and a kitchen screen built for a phone |
| Documentation truth | **4/10** | `PROJECT_STATUS.md` and `FINAL_HANDOVER.md` are two months stale and at least one headline claim is provably false. `DEFERRED.md` is the honourable exception: re-verified, with owners |
| Repo hygiene | **4/10** | 11 worktrees, ~30 branches, dirty tree, agent-config sprawl at the root |
| **Overall** | **7/10** | A disciplined codebase in its money and access layers, held back by a single-role/single-tenant model, a phone-only UI, and documentation that no longer describes the code |

## 13.1 Better than it looks

1. **The money path** — server-authoritative pricing is the hard part and it is done.
2. **DI and error discipline** — injected services, wrapped lifecycle calls; new surfaces inherit safety for free.
3. **`DEFERRED.md`** — a deferral register re-verified against code, with owners. Rare, and exactly what a multi-phase build needs.

## 13.2 Will hurt if not fixed first

1. **Rules copied per client** — identical today, divergent the moment Phase 1 lands. Fix the parity gate before touching rules.
2. **Stale status docs** — any newcomer reading `PROJECT_STATUS.md` will believe a false picture.
3. **Worktree sprawl** — "where is current truth" has no answer. Consolidate before Phase 1.

## 13.3 Quality risk this expansion introduces

| Risk | Mitigation |
|---|---|
| Rules complexity explosion (tenant × role × branch × shape) | keep rules thin; move authority into callables |
| Callable sprawl with hand-rolled auth | one `withStaffGuard(cap, handler)` wrapper; none may bypass it |
| Dart models drifting from TS handlers | one source for schemas, or contract tests like the existing order payload test |
| A new collection shipping without tenancy | generated isolation test that fails when a collection appears without a case |
| Two receipt paths built twice | resolve the thermal question before Phase 2 |

---

# PART 14 — Open questions, each with a recommendation

| # | Question | Recommendation |
|---|---|---|
| Q1 | Tenancy by flat `tenantId` field, or by path-rooted `tenants/{id}/…`? | flat + field, one helper on every match block, generated cross-tenant test. Path-rooting is structurally stronger but is a monorepo-wide query refactor with no proven-green suite |
| Q2 | Migrate the existing client's project, or start fresh? | fresh project, Halal Boyz as tenant #1, old project read-only until sign-off. Moving live orders is where data is lost and it buys nothing for one pilot client |
| Q3 | Where is the thermal printing implementation the owner says exists? | produce the path/repo before Phase 2, or accept the §9 receipt order |
| Q4 | Who may reverse money? | owner always; manager with a mandatory reason code, visible on the dashboard |
| Q5 | May counter staff 86 an item without a manager? | yes — a sold-out item must be actionable at the till, attributed and reported |
| Q6 | Approve the 2-day Flutter-web spike with a pre-agreed fallback? | approve. Card-present no longer depends on it, so the fallback costs staff chrome only |
| Q7 | Which reader, and is Terminal supported in the target market? | account-level facts that must be confirmed before any card-present demo |

---

# PART 15 — What must never be claimed without proof

Not run during this assessment, therefore not claimed: `flutter test`,
`npm test`, the Firestore/storage emulator suites, `flutter build apk`,
`flutter build web`, any deploy, any behaviour against a live Firebase project,
Stripe account, reader or iPad. The single proven health fact is
`flutter analyze` clean on `core_app` (137 s, exit 0).

Not verified, not to be repeated: coverage percentage, test counts from
`PROJECT_STATUS.md`, screen and route counts, the contents of
`archive/WHITE_LABEL_p29_security_debt.md`, and anything in the p33/`cline-*` worktrees
beyond the file census and the printing search.

---

# PART 16 — How to work in this repository

From the project constitution (`<other-project>\AGENTS.md`, read in
full):

1. **No stubs and no fabricated success.** Something works when a command
proves it. Placeholders are failures.
2. **Evidence before claim.** `file:line` or a command output, every time.
3. **Plan before editing.** Architectural change and schema migration require a
   supervised `[PLAN]`.
4. **Scope discipline.** Build what was asked; everything else goes into
   `core_app/DEFERRED.md` with an owner.
5. **Tests first** for domain logic; analyze clean; rules emulator green;
   functions build clean.
6. **Never commit or push** unless explicitly instructed.
7. **One codebase per surface family** — theming, strings and config come from
   one place or the fleet drifts.
8. **Both locales** for every new string.
9. **New config keys must satisfy both validators**, which are pinned by tests.

## 16.1 What the orchestrator should return

1. An approved `[PLAN]` for Phase 1, with the acceptance criteria above turned
   into tasks, each carrying its own test.
2. Rulings on Q1–Q7, recorded in `DECISIONS_LOG.md` with the accepted
   consequence.
3. A ruling on whether the tenancy change ships as one migration or two (data,
   then rules), given that a rules regression now affects every client at once.
4. Confirmation of the receipt path so Phase 2 does not build it twice.

## 16.2 Baseline facts for orientation

Branch `cline/p32-golden-gates`, HEAD `7c139d5c`, working tree dirty, 11
worktrees, ~30 branches. Flutter 3.41.2, Dart 3.11.0, Node v24.13.1.
4,016 tracked files. Dart files: `core_app/test` 433, `core_app/lib` 142,
`packages/core` 114, `packages/core_ui` 95, `core_app/integration_test` 30,
`apps/halal_boyz` 23, `core_app/tool` 19.

