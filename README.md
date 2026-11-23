# Carnama — a multi-tenant, white-label restaurant ordering platform

One shared codebase that ships a customer ordering app, a staff operations
surface and a server-authoritative money path — re-branded per restaurant from a
single validated JSON file. Flutter (mobile + a thin web shell) on the client,
TypeScript Cloud Functions and locked-down Firestore rules on the backend.

**Status: pre-release, built and measured locally.** Nothing is deployed. This
is not a live service.

> **Read the full technical deep dive: [`docs/DEEP-DIVE.md`](docs/DEEP-DIVE.md)**
> — architecture, data model, the money path, the tenancy proof, every backend
> function, the gate system, and an honest list of what is *not* proven yet.
> This README is the summary; that file is the detail.

---

## What it does

A customer opens the app, browses a menu with allergen and dietary badges, builds
a cart, applies a promo, pays, and tracks the order. The kitchen sees it appear
and advances it. A driver claims it, travels to it, and captures proof of
delivery. The owner watches revenue, branches and channels. Every one of those
steps is tenant-scoped: two restaurants sharing one Firebase project cannot see
each other's rows, and that claim is tested against the real security rules, not
mocked.

## Features

### Customer app

| Feature | What it gives you |
| --- | --- |
| Onboarding, login, signup, terms | First-run flow with a guided product tour and a terms-of-service gate |
| Menu and dish detail | Categories, modifiers, sold-out state, merged remote + override menus, search |
| Allergen and dietary layer | 13 declaration codes, 6 dietary codes, badges on every item, a 13-code allergen sheet, three dietary filter chips, expired certifications render nothing |
| Cart | Persisted cart, per-line validation against the live menu, price and availability guards |
| Checkout and promo codes | Server-priced checkout, promo application with usage accounting, Stripe payment intent |
| Orders and tracking | Order history, a three-stage delivery timeline, contact-the-driver handoff, one-tap reorder, offline-safe order payloads |
| Reservations and waitlist | Dine-in reservation requests with a concurrency-safe counter, plus a joinable queue |
| Loyalty | Points balance and loyalty screen, flag-gated |
| Locations | Branch list with addresses and opening hours, a pin-drop map address picker, and per-branch menus |
| Profile and account deletion | Profile surface plus a self-service account deletion request that feeds the DSAR pipeline |
| Notifications | FCM push with a per-tenant channel, a queued delivery path, and copy centralised server-side |

### Staff and operations

| Feature | What it gives you |
| --- | --- |
| Role router | One binary routes to owner, manager, kitchen or delivery surfaces from signed claims |
| Kitchen display service | Live order queue per branch, status advancement, task dispatch |
| Delivery dashboard | Assignments, delivery status, driver presence |
| Driver app | Claimed deliveries, GPS pings, proof of delivery captured to Firestore and Storage |
| Admin panel | Menu editing, branches, reservations tab, delivery, kitchen, analytics, setup, gateway |
| Owner dashboard | Revenue, branch/channel breakdown, day-level analytics feed (panel built; mount is a tracked open item) |
| Emergency pause switch | A single owner-controlled flag that stops ordering without a deploy |
| Audit trail | Append-only `audit_log` / `audit_logs` rows on settings and role changes |

### Money and backend

| Feature | What it gives you |
| --- | --- |
| Server-authoritative pricing | Every line is re-priced from `menus` on the server; the client's price is a stale-ticket guard, never the charged amount |
| Atomic ledger | An order and its ledger row commit in **one** Firestore transaction, keyed by an idempotency key scoped to the caller |
| Cash sales (counter/POS) | `createCashOrder` / `voidCashSale`: cash has a real server path, with change, idempotent replay, and reversal rows instead of deletes |
| Refunds and reversals | Negative ledger rows, never mutation of history; earned back only by a new row |
| Processor adapter seam | Stripe sits behind a `ProcessorAdapter` interface, so the provider is swappable without touching money logic |
| Stripe webhook | Signature-verified, bounded event replay, no trust in client-sent amounts |
| Platform ingestion | Uber Eats and Delivery Hero order pushes: HMAC verification, namespaced idempotency, mapper, re-priced total, dead-letter record on failure |
| Fraud screening | Pre-payment risk scoring callable |
| Tax and rounding | Integer minor units end to end, one rounding rule, tax resolved from tenant settings |
| DSAR / GDPR | Data export callable with a row cap, and an erase pipeline that anonymises ledger rows rather than deleting financial history |

### Platform engineering

| Feature | What it gives you |
| --- | --- |
| White-label factory | `dart run tool/whitelabel.dart --config client_config.json` generates a complete app from one validated config: naming, bundle ids, palette, typography, radii, tabs, routes, feature flags |
| Multi-tenancy | A tenant claim resolved from `settings/<tenant>_ownerInfo`; 32 of 32 rule paths tenant-active; every list read carries the constraint **in the query** |
| Cross-tenant test generator | Tests generated from the rules themselves, so a new collection cannot silently skip the tenancy check |
| Security rules | 958 lines of Firestore rules with per-role field allowlists, plus 111 lines of Storage rules |
| 12-gate quality battery | Analyse, fast tests, functions build, rules emulator, white-label dry run, stub scan, tenant generator, coverage, backend parity, tenant emulator, rules harness, licence-claim scan — each proven to go red on a planted failure |
| Rules harness | 173 passing cases against the real emulator, with a recorded baseline so a regression inside it is visible |
| Bilingual UI | English and Arabic with full RTL, golden tests at multiple widths |
| Offline cache | Isar-backed local cache behind a required interface, with a no-op implementation for the web shell |
| Thin web shell | A separate web entrypoint over the same domain, with a mechanical import-boundary checker (no Isar, no core barrel) |

## Architecture at a glance

```
carnama/
├─ core_app/          the full Flutter app (customer + staff, Android/iOS/web/windows)
│  ├─ lib/features/   19 feature slices: menu, cart, checkout, orders, admin, …
│  ├─ lib/shell/      thin web entrypoint, Isar-free
│  ├─ functions/      7,340 lines of TypeScript Cloud Functions
│  ├─ firestore.rules 958 lines · storage.rules 111 lines
│  └─ test/           511 Dart test files
├─ packages/core/     domain: models, money, tax, auth, cache, network, compliance
├─ packages/core_ui/  design system: theme tokens, widgets, money renderers
├─ apps/halal_boyz/   a generated white-label client (the reference tenant)
├─ tool/              gate runner, rules harness, tenancy generator, proofs
├─ checkpoints/       evidence receipts — one per completed card
├─ docs/              DEEP-DIVE, DECISIONS, INCIDENT_LEDGER, runbooks
└─ archive/           historical batch records (audits, fix rounds) — not current
```

Dependencies point one way: `core_app` → `packages/core` and `packages/core_ui` →
Flutter. `packages/core` never imports `core_app`. The web shell may import core
*modules* but never the core barrel, and a checker enforces it.

**Measured inventory** (each number has a command behind it in the deep dive):
288 Dart library files / 60,235 lines · 7,340 lines of TypeScript · 511 Dart test
files / 3,525 test declarations · 24 Cloud Functions test suites · 31 top-level
Firestore collections plus one nested subcollection · 49 recorded decisions.

## Running it locally

```bash
flutter pub get                      # workspace root (melos 8.x, Dart ^3.11)
cd core_app
flutter test --tags gate_fast        # fast lane
flutter run                          # app against the Firebase emulators
```

Backend:

```bash
cd core_app/functions && npm ci && npm run build && npm test
cd core_app && firebase emulators:start --only firestore,auth,functions,storage
```

Whole battery:

```bash
node tool/gate.mjs check             # 12 gates, writes a receipt to checkpoints/
```

## Licence

**Proprietary — viewing only — no rights granted.** This is not open source and
not "source-available": the single act permitted is reading this repository.
Copying, cloning, forking, deploying, modifying, redistributing or training on
any part of it requires prior written permission — see [`LICENSE`](LICENSE).
Security reports: [`SECURITY.md`](SECURITY.md).
