# 📜 CARNAMA CONSTITUTION
### The Single Source of Truth — Always Referenced First
> **Version:** 2.0 · **Updated:** 2026-05-24 · **Project:** Carnama Enterprise Restaurant Platform  
> ⚠️ **This document supersedes all previous docs:** `carnama_brain.md`, `carnama_dev_handbook.md`, `carnama_context.md`, `ARCHITECTURE.md`, `TECHDEBT.md`.  
> **Before writing a single line of code, you MUST read this document top to bottom.**

---

## PART 1 — THE 27 LAWS (Inviolable)

These are non-negotiable. Every PR is checked against them. Violating any one is grounds for a hard rollback. No exceptions, not even for "small" changes.

| # | Law | What It Means In Practice |
|---|-----|--------------------------|
| **1** | **Hard Stop Protocol** | If an instruction creates a paradox, threatens stability, or conflicts with existing architecture — STOP. Never make silent assumptions. Block on explicit user authorization before writing any code. Ask exactly what needs clarifying. |
| **2** | **TDD-First** | Write the failing test first. Write the code second. No feature is "done" until `flutter test` is 100% green. |
| **3** | **Single Source of Truth** | No hardcoded colours, strings, or numbers. Use `AppColors`, `AppDimensions`, `AppStrings`. One file to change them all. |
| **4** | **Zero Stub Tolerance** | No `// TODO`, no placeholder `Container()`, no fake data. Every screen ships wired to real Firestore. |
| **5** | **Architectural Memory** | This file is always read before any new feature sequence begins. No exceptions. |
| **6** | **Golden Target Precision (UI)** | UI must match Tier-1 SaaS: fluid scaling, glassmorphism, micro-animations, correct frame rates. |
| **7** | **The Scout Rule** | Leave every file cleaner than found it. Refactor legacy spaghetti before adding new code to the same file. |
| **8** | **Defensive Execution** | Every API call wrapped in `try/catch`. Network failure = graceful degradation, never a red error screen. |
| **9** | **Idempotency on Critical Writes** | A double-tap on "Checkout" is physically incapable of duplicating a charge. All mutations are idempotent. |
| **10** | **Master Pipeline Gate** | Nothing is "live" until `dart tool/pipeline.dart` returns 0 warnings and 100% green tests. |
| **11** | **Silent Telemetry** | Every crash lands in Firebase Crashlytics. We never wait for a user bug report. |
| **12** | **Security by Least Privilege** | The mobile client is hostile. No security decisions happen in Dart. Security lives strictly in Firestore Rules. |
| **13** | **Death by 1000 Cuts Guard** | Before importing a heavy package, write a tiny custom script. Measure APK impact first. |
| **14** | **"Why" Not "What" Comments** | Comments explain business logic, not syntax. If a formula is complex, explain WHY it exists. |
| **15** | **Disconnect Principle (Offline-First)** | If a user loses signal mid-order, queue the request. Sync on reconnect. Never drop user intent. |
| **16** | **Secret Guarding** | Zero API keys in source control. All secrets live in `.env` (gitignored). |
| **17** | **Visual Regression Immunity** | Golden Tests capture pixel-perfect screenshots. A 1-pixel shift on the Checkout button breaks CI. |
| **18** | **Strict Environment Parity** | Staging is a 1:1 clone of Production. All migrations are tested in Staging first. |
| **19** | **Continuous Documentation** | On every major feature merge, this file and `ARCHITECTURE.md` are updated same day. |
| **20** | **Bus Factor Protocol** | A junior dev must be able to `clone → dart tool/pipeline.dart → running app` in under 5 minutes with zero help from the original architect. |
| **21** | **Pre-Push Hook Mandatory** | A `.git/hooks/pre-push` script running `flutter analyze && flutter test test/core/ test/wiring/` must exist in every dev environment. Broken code never reaches remote. |
| **22** | **Tiered Test Execution** | Tests are split into 3 runnable tiers: `test/core/` (fast, <10s, run on every save), `test/wiring/` (<30s, run before commit), `test/ui/` (slow goldens, run before release only). |
| **23** | **Freezed Model Contracts** | All domain models must use the `freezed` package. Adding a field by hand in 4 places is a violation. One annotation generates `fromJson`, `toJson`, `copyWith`, and equality. |
| **24** | **Model-Test Roundtrip Law** | Every `fromJson`/`toJson` change ships with a corresponding roundtrip unit test in the same PR: `expect(model.fromJson(model.toJson()), model)`. |
| **25** | **Schema-Before-Widget Law** | No widget may reference a model field that does not exist in its `fromJson` factory. UI is built against the model, never ahead of it. |
| **26** | **Deferred Feature Tracking** | Deferred features must live in version-controlled `DEFERRED.md` at the repo root, visible to all contributors — not only in brain artifacts or personal notes. |
| **27** | **Firestore Index for Every Query** | Every Firestore `.where()` or `.orderBy()` combination used in production must have a corresponding composite index deployed. Client-side filtering is a temporary workaround only. |
| **28** | **AI Task Decomposition** | Every request to an AI must be broken into the smallest verifiable step. Each step must include a test that will pass when the step is complete. |

---

## PART 2 — WHAT IS CARNAMA?

Carnama is a **white-label B2B restaurant management platform** built in Flutter + Firebase. It is not a single-restaurant app — it is a full enterprise system designed to be rebranded and deployed for any restaurant client.

| Role | Access Level |
|------|-------------|
| **Owner** | Full control: analytics, RBAC, pricing, branches, feature flags |
| **Manager** | Branch-scoped: menu, orders, staff assignment |
| **Kitchen** | Incoming orders board, mark Ready |
| **Driver** | Assigned deliveries, map navigation, GPS tracking |
| **Customer** | Browse menu, cart, Stripe checkout, reservations, order history |

---

## PART 3 — TECH STACK A-Z

| Layer | Technology | Why |
|-------|-----------|-----|
| Mobile Framework | Flutter 3.x (Dart) | Single codebase: Android + iOS + Web |
| State Management | Riverpod 2.x | Compile-safe providers, testable, no singletons |
| Navigation | GoRouter 14.x | Declarative routes, deep-linking, role guards |
| Backend / DB | Cloud Firestore | Real-time streams, offline support, RBAC |
| Authentication | Firebase Auth | Email/Password + Google Sign-In |
| Cloud Functions | Firebase Functions v1 (Blaze tier) | Server-side: tax calc, fraud detection, GDPR |
| Local Cache | Isar Database | Offline-first: menus, pending writes cached locally |
| Push Notifications | Firebase Messaging (FCM) | Order status → customer push |
| Image Loading | `cached_network_image` | Memory-capped network images |
| Charts | `fl_chart` | Revenue & analytics graphs (Owner Dashboard) |
| Maps | `flutter_map` (OpenStreetMap) | No Google Maps API key needed |
| Reverse Geocoding | `geocoding` package | Converts lat/lng → human address string |
| GPS | `geolocator` | Device location + permission handling |
| Payments | Stripe SDK | Full integration; bypassed in demo/Spark tier |
| CI/CD | `dart tool/pipeline.dart` | Custom: lint + test + build gate |
| Testing | `flutter_test` + `mockito` + `fake_cloud_firestore` | Unit, widget, golden, integration |
| Crash Reporting | Firebase Crashlytics | Silent crash telemetry |
| Performance | Firebase Performance | API latency + frame rate tracking |
| Remote Config | Firebase Remote Config | Feature flags at runtime without redeploy |
| Animations | `flutter_animate` | Micro-animations, fade, slideY |

---

## PART 4 — PROJECT STRUCTURE

> **Architecture (V2 — Package Extraction Complete):** The monolithic `lib/core/` has been extracted into two first-class Melos workspace packages. Client apps depend on these packages via `pubspec.yaml` — they no longer copy-paste `lib/core/`.

```
packages/
├── core/               ← Pure domain + services (no Flutter, no l10n)
│   └── lib/
│       ├── core.dart           ← Public barrel export (Law 20 — single import)
│       └── src/
│           ├── auth/           ← Firebase Auth state, UserModel, authStateProvider
│           ├── cache/          ← Isar service + offline sync provider
│           ├── config/         ← CoreConfig (SPARK tier bypass switch)
│           ├── compliance/     ← GDPR service, data export
│           ├── error_logger/   ← ErrorLoggerService, CrashReporter abstraction
│           ├── kitchen/        ← KitchenOfflineService (LAN POST)
│           ├── models/         ← DeliveryLocationModel, PromotionModel
│           ├── network/        ← NetworkRetry, PendingSyncProvider, SyncQueue
│           ├── payment/        ← FraudScreeningService
│           ├── services/       ← CloudinaryUploadService, FirestoreClient
│           └── storage/        ← CloudinaryService
├── core_ui/            ← Flutter UI widgets + theme (depends on core)
│   └── lib/
│       ├── core_ui.dart        ← Public barrel export
│       └── src/
│           ├── theme/          ← AppColors, AppDimensions, AppTheme
│           ├── ui/             ← BrandButton, EmptyStateWidget (shared)
│           ├── compliance/     ← GdprConsentDialog
│           ├── config/         ← ForceUpdateGuard
│           └── storage/        ← CloudinaryService (UI-bound)
apps/
└── core_app/           ← Main app (features, l10n, composition)
    └── lib/
        ├── app/                ← AppRouter, BrandDrawer, AnimatedCartBadge
        ├── features/
        │   ├── admin/          ← Owner/Manager/Kitchen/Delivery dashboards
        │   ├── auth/           ← LoginScreen, SignupScreen
        │   ├── cart/           ← CartProvider, CartScreen
        │   ├── checkout/       ← CheckoutScreen, Stripe, PinDrop wired
        │   ├── driver/         ← BackgroundGpsService, ProofOfDelivery
        │   ├── home/           ← HomeScreen (menu grid, tag chips, hero banners)
        │   ├── loyalty/        ← LoyaltyScreen (backend shipped: functions/src/index.ts:1652-1670)
        │   ├── menu/           ← MenuScreen, MenuProvider, mergedMenuProvider
        │   ├── orders/         ← OrderModel, OrderProvider, KitchenTaskDispatcher
        │   ├── promotions/     ← HeroCarouselWidget
        │   ├── reservations/   ← ReservationScreen, AdminReservationsTab
        │   └── waitlist/       ← WaitlistScreen
        └── main.dart           ← App entry point
tool/
├── pipeline.dart           ← 33-phase automated CI pipeline (emulator-aware)
├── seed_test_accounts.js   ← Firebase seed script (run once per environment)
├── whitelabel.dart         ← White-label automation (name/color/bundle patch)
test/
├── core/               ← Model serialization, AppConfig (fast — run every save)
├── wiring/             ← Feature contract tests (run before commit)
└── ui/                 ← Golden pixel-perfect tests (run before release)
docs/                   ← Legacy docs (superseded by this file)
DEFERRED.md             ← All deferred features tracked here (Law 26)
CARNAMA_CONSTITUTION.md ← THIS FILE — always referenced first
```

### Package Dependency Graph
```
apps/core_app ──depends on──► packages/core_ui ──depends on──► packages/core
apps/core_app ──depends on──► packages/core
```
- `packages/core` has **zero** Flutter dependencies (pure Dart domain layer).
- `packages/core_ui` depends on `packages/core` + Flutter.
- `apps/core_app` depends on both packages + adds features, l10n, and composition.
- Client apps depend on `packages/core` and `packages/core_ui` — never copy-paste.

---

## PART 5 — FIRESTORE DATABASE SCHEMA

```
settings/
  ownerInfo           { ownerEmail: "admin@carnama.com" }  ← CRITICAL: must exist
  featureFlags        { liveTracking, stripe, reservations, promos, loyaltyPoints,
                        driverTracking, maintenanceMode }  all default: true

users/{uid}           { email, role, branchId?, displayName }
branches/{branchId}   { name, address, coordinates: GeoPoint,
                        deliveryRadiusMiles, isDefault }
menus/{itemId}        { name, priceCents, description, imageUrl,
                        modifiers[], isAvailable, tags[], branchId? }
                        ↳ tags[] = custom filter labels (e.g. "Spicy", "Vegan")
                        ↳ branchId null = global item (visible to all branches)
orders/{orderId}      { customerId, branchId, items[], totalCents,
                        status, createdAt }
                        ↳ Required index: [branchId ASC, createdAt DESC]
promotions/{promoId}  { imageUrl, actionUrl?, isActive, priority, createdAt }
                        ↳ title/subtitle fields — DEFERRED (Law 26)
reservations/{id}     { userId, branchId, date, slot, status }
reservation_locks/{id}{ userId, slot, expiresAt }
driverLocations/{id}  { lat, lng, accuracy, speed, updatedAt, driverId }
notifications/{uid}/items/{id} { title, body, route, isRead, createdAt }
carts/{uid}           { items[] }
loyalty/{uid}         { totalPoints, tier }  ← server-owned (award shipped, p15/p20)
```

### Required Firestore Indexes (Deployed)
| Collection | Fields | Type |
|---|---|---|
| `orders` | `branchId` ASC + `createdAt` DESC | Composite |
| `menus` (pending) | `branchId` ASC + `tags` array-contains + `isAvailable` ASC | Composite — **DEPLOY THIS** |

---

## PART 6 — SECURITY RULES PHILOSOPHY

- `isOwner()` → checks `settings/ownerInfo.ownerEmail == request.auth.token.email`
- `userRole()` → reads `users/{uid}.role` (costs 1 extra Firestore read per operation)
- Owners write `settings/*`, `branches/*`, `menus/*` globally
- Managers read/write only within their own `branchId`
- Managers cannot promote roles to `owner` or `manager`
- Customers can create orders and read only their own orders
- `reservation_locks` — authenticated users can create/delete their own locks
- **The mobile client is treated as hostile. Zero security decisions in Dart.**

---

## PART 7 — NAVIGATION ROUTES (GoRouter)

| Route Name | Path | Access |
|---|---|---|
| `login` | `/login` | public |
| `home` | `/` | customer |
| `dishDetail` | `/menu/:id` | customer |
| `cart` | `/cart` | customer |
| `checkout` | `/checkout` | customer |
| `orders` | `/orders` | customer |
| `reservations` | `/reservations` | customer |
| `loyalty` | `/loyalty` | customer (shipped) |
| `roleRouter` | `/admin` | staff — routes by role |
| `ownerDashboard` | `/admin/owner` | owner |
| `managerDashboard` | `/admin/manager` | manager |
| `kitchenDashboard` | `/admin/kitchen` | kitchen |
| `driverDashboard` | `/admin/driver` | driver |
| `privacy` | `/privacy` | public |

---

## PART 8 — SEEDED TEST ACCOUNTS

> Run `node tool/seed_test_accounts.js` once per fresh environment.

| Email | Password | Role |
|---|---|---|
| `admin@carnama.com` | `Admin123!` | owner |
| `manager@carnama.com` | `Manager123!` | manager |
| `kitchen@carnama.com` | `Kitchen123!` | kitchen |
| `driver@carnama.com` | `Driver123!` | driver |
| `customer@carnama.com` | `Customer123!` | customer |

The seed script also creates: `settings/ownerInfo` and `settings/featureFlags` (both required for the app to function).

---

## PART 9 — THE PIPELINE (How We Ship)

### Single Command
```powershell
dart tool/pipeline.dart
```

### What It Runs (In Order)
1. `flutter format --set-exit-if-changed .` → code style gate
2. `flutter analyze` → **0 warnings — zero exceptions**
3. `flutter test test/core/ test/wiring/` → unit + contracts, must be green
4. `flutter test test/ui/` → golden visual tests
5. `firebase deploy --only firestore:indexes,firestore:rules`
6. `flutter build apk --release`

**Nothing ships if any step is red. Not even "small" changes.**

### Emulator Detection
`pipeline.dart` automatically skips E2E integration test phases when no physical device is connected, avoiding false failures in headless CI environments.

---

## PART 10 — TESTING ARCHITECTURE

```
test/
├── core/              ← Model roundtrip + AppConfig (fast, <10s — run on every save)
├── wiring/            ← Feature contract tests (<30s — run before commit)
└── ui/                ← Golden pixel-perfect screenshots (slow — run before release)
```

### Commands
```powershell
flutter test test/core/                      # Unit only (fastest)
flutter test test/wiring/                    # Contract tests
flutter test test/ui/                        # Golden tests
flutter test test/ui/ --update-goldens       # Regenerate baselines
flutter test --coverage                      # Full coverage report
```

### Current State
- **236 tests passing, 5 failures fixed, 0 warnings** (as of V1.1 Sprint)
- Golden baselines committed to git — a 1px shift breaks CI

---

## PART 11 — PRODUCTION STATE (V1.1)

### ✅ Fully Implemented & Verified

- Customer ordering flow (menu → cart → Stripe checkout)
- Real-time kitchen order board
- Driver delivery tracking with live GPS (`geolocator`)
- Owner multi-branch management with map pin picker (`PinDropMapScreen`)
- Manager branch-scoped menu editing with custom tags
- Push notifications (FCM — foreground, background, killed state)
- Reservation booking with collision-safe hour-slot locking
- Dynamic menu tag filtering on Home Screen
- GoRouter navigation with `canPop` guards everywhere
- Role-based Firestore security rules
- Owner self-demotion protection
- Hero banners from live Firestore `promotions` collection
- Admin role access via Profile → Staff Dashboard

### 🔶 Deferred to V1.2 (tracked in DEFERRED.md)

> **p26 T-5 sweep (2026-09-30):** this table was the 2026-05 revision and had gone stale. The
> authoritative evidence record is `core_app/DEFERRED.md` (Law 26) — this table now matches it
> row for row. Note the **id collision** (not silently renumbered): the `D#` ids below are NOT the
> ids used in `DEFERRED.md` (where D1/D3/D4/D5/D7/D8 denote different rows); both files stay as
> they are so no history is rewritten.

| # | Feature | Status on this tip (p26 T-5, 2026-09-30) |
|---|---|---|
| D1 | Loyalty & Rewards engine | **CLOSED** — no longer "static 120 pts": server-side award `core_app/functions/src/index.ts:1652-1670`, `loyalty/{uid}.totalPoints` server-owned in `firestore.rules` (probes b10-T31..T33); see `DEFERRED.md` D1 |
| D2 | Manager → Branch assignment UI | **CLOSED** — `core_app/lib/features/admin/presentation/owner/tabs/owner_users_tab.dart:94-208` (`assignBranch` / `assignBranchFor`) + `admin_data_service.dart:197`; no longer Console-only |
| D3 | Analytics / Revenue dashboard | **CLOSED** — `admin/domain/analytics_provider.dart`, `admin/presentation/analytics_snapshot.dart`, `.../analytics/revenue_chart_widget.dart:3` (`fl_chart ^1.2.0`); see `DEFERRED.md` D3 |
| D4 | Deep Linking / Universal Links | **CLOSED** — `packages/core/lib/src/navigation/deep_link_service.dart` + its pins; see `DEFERRED.md` D4 |
| D5 | 20-Tap Admin Gateway + PIN | **CLOSED** — `admin/presentation/gateway/admin_gateway_screen.dart:13` (the decision is server-side); see `DEFERRED.md` D5 |
| D6 | Bottom Nav → Navigation Drawer | **KEPT** (owner: coordinator) — no `Drawer(` implementation under `core_app/lib` on this tip |
| D7 | `PromotionModel` title/subtitle | **CLOSED** — `packages/core/lib/src/models/promotion_model.dart:14-15` carries `title`/`subtitle` |
| D8 | `freezed` model migration | **CLOSED** — census: 15/15 tracked `*model.dart` files carry a `.freezed.dart` sibling; see `DEFERRED.md` D8 |
| D9 | Firestore tag filter composite index | **CLOSED** — `core_app/firestore.indexes.json:121` (`tags`, `arrayConfig: CONTAINS`); see `DEFERRED.md` S2 |
| D10 | Release APK debug FAB check | **KEPT** (owner: release gate) — manual on-device gate; see `DEFERRED.md` D2 |

---

## PART 12 — KNOWN TECH DEBT

| Debt | Severity | Notes |
|---|---|---|
| `TaxService`, `TelemetryService`, `ProofOfDeliveryService` missing unit tests | High | Coverage drops below 80% |
| `userRole()` costs 1 extra Firestore read per operation | Medium | Doubles read bill at scale |
| `NfcTerminalService` fully stubbed | Low | Awaiting Stripe Terminal hardware keys |
| `KitchenOfflineService` LAN POST stubbed | Low | Awaiting physical EPSON printer test |
| No DDOS/scraping alerting on `PERMISSION_DENIED` at scale | Medium | No Datadog/Sentry metric wired |
| Cloud Functions on v1 (deprecated) | High | Upgrade to v2 before next deploy |
| `calculateTax` trusts client `subtotalCents` | High | Needs `zod` input guard |

---

## PART 13 — CLOUD FUNCTIONS (Blaze Plan Required)

| Function | Trigger | Purpose |
|---|---|---|
| `calculateTax` | HTTPS callable | Server-side tax calculation |
| `screenPaymentFraud` | HTTPS callable | Velocity check: >10 orders/hr = flag |
| `dispatchToFleet` | HTTPS callable | Stub: DoorDash Drive / Uber Direct |
| `logFunnelEvent` | HTTPS callable | Analytics event logger |
| `deleteUserData` | HTTPS callable | GDPR cascade wipe |
| `recoverAbandonedCarts` | Pub/Sub (every 5min) | FCM push to dormant carts |
| `onOrderStatusChange` | Firestore trigger | FCM push to customer on status change |

> ⚠️ **Spark Plan:** All Cloud Functions non-operational on Spark (free). The app has a built-in `kDemoMode` bypass in `checkout_screen.dart` and `order_repository.dart` that simulates success for demo UX.

---

## PART 14 — WHITE-LABEL SYSTEM

To rebrand for a new client:
```bash
dart tool/whitelabel.dart \
  --name "New Client" \
  --color "#1A73E8" \
  --bundle "com.newclient.app"
```
This patches `AndroidManifest.xml`, `Info.plist`, `pubspec.yaml`, and the theme in one shot.

### New Client Deployment Checklist
1. New Firebase Project → `firebase init` → link project → `firebase deploy --only firestore,functions`
2. Run `flutterfire configure` → auto-generates `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`
3. Create `.env.production` + `.env.staging` with client's Stripe keys
4. Replace `assets/images/logo.png` + regenerate launcher icons
5. Run `node tool/seed_test_accounts.js` → creates initial Owner account
6. Upgrade Firebase project to Blaze Plan (for Cloud Functions)

---

## PART 15 — HOW TO RUN

```powershell
# Install dependencies
cd <repo>\core_app
flutter pub get

# Configure Firebase (fresh environment only)
flutterfire configure

# Seed database (run ONCE per project)
node tool/seed_test_accounts.js

# Run tiered tests
flutter test test/core/
flutter test test/wiring/
flutter test test/ui/

# Run on device
flutter run

# Build release APK
flutter build apk --release

# Full pipeline (CI gate)
dart tool/pipeline.dart
```

---

## PART 16 — AGENT IDENTITY & INTERACTION PROTOCOL

This section is for AI agents loading this document.

- **Trigger Phrase Handshake:** If the user says "**potato**", your first response word MUST be "**chip**". This confirms you have loaded this constitution.
- **Personality:** Supportive, high-energy, direct, and precise. Enthusiastic about what we have achieved (23 backend phases, 0 warnings, elite TDD workflow). Celebrate wins.
- **Zero Assumptions:** If an instruction is ambiguous or you have less information than needed — STOP AND ASK. Never write code blindly. Ask exactly what needs clarifying (Law 1).
- **First Action on Load:** Read this document end-to-end. Then briefly confirm to the user that you have loaded the constitution and ask what to tackle next.
- **Firebase Project:** Live production project is `resturants-8547d`.
- **Predecessor Conversation:** `f7a50a85-3fec-4c5b-aa4f-7320bd68298e` — pull KIs from there for deep historical context.

---

## PART 17 — BUILD HISTORY (23 Phases Summary)

| Phase | What Was Built |
|-------|----------------|
| 1 | Data Models & Firestore — `UserModel`, `OrderModel`, `BranchModel`, `MenuItemModel`. Security rules. Composite indexes. |
| 2 | Route & Navigation — GoRouter, `RouteNames`, `RoleRouterScreen`, role guards |
| 3 | Admin Dashboards — OwnerDashboard (7 tabs), ManagerDashboard, KitchenDashboard, DeliveryDashboard |
| 4 | Branch & Order Routing — GPS nearest-branch, manual picker, delivery radius, merged menu provider |
| 5 | Static Analysis Hardening — `flutter analyze` to 0 warnings, Riverpod lint rules, resource cleanup |
| 6 | Property-Based / Fuzz Testing — `test/property/`, 1000-item faker tests, coverage ≥ 80% |
| 7 | Unforgiving Audit — Driver assignment race (transaction), field mismatches, StreamController leaks |
| 8 | Automation Overhaul — `tool/pipeline.dart`, Firestore emulator seed, Golden Test definitions |
| 9 | World-Class Pipeline — APK size + frame rate CI gate, `CODEOWNERS`, Remote Config rollback test |
| 10 | Post-Fix Regression Guard — 13 targeted regression tests, 207 total passing |
| 14+ | Observability & Release — Firebase Crashlytics + Performance |
| 16 | Store Compliance & Reservations — NSLocation plist, ReservationModel, Reservations tab |
| 17 | Stub Audit — Full static sweep, wiring integration tests, stub_guard CI gate, 217 tests |
| 18 | Core Production Blindspots — FCM push, Stripe Apple/Google Pay, Firebase App Check, Geohash indexing, Menu Modifiers, Force Update Guard |
| 19 | Tier-1 Enterprise — i18n (EN + AR RTL), Promo Codes, Background GPS, Proof of Delivery, Deep Linking, Accessibility |
| 20 | Unicorn Scale — Tax & Surge Pricing, Driver Tipping, Cursor-based Firestore pagination, Cart Abandonment FCM, OTA (Shorebird) |
| 21 | Global B2B — Fraud Detection, Fleet Integration stubs, NFC Terminal stub, Funnel Telemetry, GDPR wipe |
| 22 | B2B Scale Factory — White-Label Automation, Fastlane asset generation, Enterprise Wiki |
| 23 | Final Pre-flight — Firestore rules gap patches, Cloud Functions `index.ts`, test seeder |
| V1.1 | Interactive Maps — `PinDropMapScreen`, `DeliveryLocationModel`, CheckoutScreen wired, Driver nav deeplink |
| V1.1 Sprint | Production Hardening — GeoLocation license fix, dynamic menu tags, GoRouter crash guards, RenderFlex fixes, Hero Carousel stabilisation |

**Total: 236 tests passing · 0 analyzer warnings · Production-grade**

---

## PART 8 — THE ZERO ESCAPED ERRORS STANDARD (14 Engineering Mandates)
> **Status: MANDATORY.** These are constitutional law. Every sprint, every PR, every client app inherits these without exception.  
> **Adopted:** 2026-05-27

### Law 29 — Automated App Store Deployment
Fastlane + GitHub Actions is the mandated release pipeline. Version tags trigger the pipeline. Stores receive build artifacts without human intervention. Codemagic may be used for Flutter-optimised build acceleration. A "release train" model is non-negotiable: no human clicks "Upload to App Store."

### Law 30 — Firebase Emulator Integration Testing
All integration tests run against the Firebase Emulator Suite — never mocked classes. The emulator enforces real security rules, real transaction semantics, and real offline behaviour. Tests must include deterministic seeding, teardown that purges test data, and emulator readiness verification before test execution. Hitting production Firestore in a test is a constitutional violation.

### Law 31 — Firestore Schema Versioning (Fireway)
Firestore schema changes use `@keii2k/fireway` with semver ordering. Schema changes are **always additive, never breaking**. When a breaking change is unavoidable, versioned collections (`orders_v1`, `orders_v2`) with client-side read fallbacks are required. Rollback is addressed through PITR and export/restore.

### Law 32 — Accessibility (WCAG 2.1 AA)
`flutter_accessibility_scanner` + Flutter's `AccessibilityGuideline` runs on every PR in CI. Missing labels, poor contrast, and tap target violations block merges. Supplement with Accessibility Scanner (Android) and Accessibility Inspector (iOS) before every release.

### Law 33 — i18n by Default
Flutter's `flutter_localizations` + `flutter gen-l10n` + ARB files is the only allowed i18n solution. Static generation is mandatory — no runtime string resolution. RTL, pluralization, and dynamic locale switching via Riverpod are built from day one, not retrofitted.

### Law 34 — Performance Budget Gate
Integration tests capture average, p90, and p99 frame times. Any frame exceeding 16ms (60fps budget) triggers a CI failure. A performance budget is established per release and blocks deployment when crossed. Passive monitoring without a hard gate is not sufficient.

### Law 35 — APK Size Gate
Only release builds with AOT compilation are measured. Size is compared across builds in CI. A size regression beyond the defined threshold (e.g. +2MB) blocks the PR. Debug builds are never measured for size.

### Law 36 — Audit Logging
Sensitive collections (`admin writes`, `role changes`, `financial data`) have Cloud Functions triggers writing to a custom `audit_log` collection. For full compliance, combine with Firestore IAM audit logging. Every privileged action has an immutable paper trail.

### Law 37 — Environment Parity
Staging is a 1:1 Firebase project clone of production. Schemas and security rules are synced via `firebase_multi_env_manager`. Scheduled anonymised data exports from production to staging prevent data drift. No "it works in staging" excuse is valid if staging isn't parity.

### Law 38 — Dependency Vulnerability Scanning
Dependabot runs on every PR for automated security update PRs. Snyk supplements for transitive dependency and license compliance scanning. Both run in CI. A critical vulnerability severity blocks merge.

### Law 39 — Code Review Enforcement
`CODEOWNERS` + GitHub branch protection rules are mandatory. Main branch is protected from direct pushes. At minimum one codeowner approval is required per PR. This is non-negotiable for the client app.

### Law 40 — Backup and Disaster Recovery
Firestore PITR is enabled at all times (recovers to any second in the last 7 days). Weekly exports to Cloud Storage provide long-term archival. Restore drills validate the process before each major release.

### Law 41 — Property-Based and Fuzz Testing
`package:fast_check` generates thousands of random inputs and verifies model invariants (e.g. `totalCents >= 0`, `deliveryRadiusMiles > 0`). `dart_fuzz` tests that `fromJson` never throws on malformed Firestore snapshots. These run in the nightly pipeline tier.

### Law 42 — Canary + Automated Rollback
Firebase Remote Config routes 1% of users to the canary build. Crashlytics monitors for error rate increases tagged to canary users. If error rate crosses the defined threshold, Remote Config automatically rolls back the canary cohort to stable. No engineer needs to be awake for a rollback.

### Law 43 — The Spirit of the Law (Anti-Shortcut Mandate)
No AI agent or developer may implement a "stub" test or an ignorant regex replacement simply to satisfy a CI pipeline gate. Code must be written to fulfil the *spirit* of the architecture, not just the compilation requirements. If a test is required for Push Notifications, it must mock the method channel or payload, not just verify a string. Never trade structural depth for a mathematically green but functionally hollow checkmark.

### Law 44 — Client Production Blaze Requirement
The Spark (Free) plan is legally permitted ONLY for core internal development and local B2B software demos. When extracting a physical white-label client app for production deployment, the Firebase project MUST be upgraded to the Blaze Plan. Core logic features (Stripe webhooks, GDPR cascade deletion, Fraud screening) are architecturally reliant on Node.js Cloud Functions, which are disabled on the Spark tier. 

### Law 45 — Shorebird Client Integration (OTA Updates)
Shorebird is not required for local B2B demos, but it is MANDATORY when an actual client application is shipped to the App Store / Play Store. Over-The-Air (OTA) patching must be pre-configured on all physical release builds to bypass App Store review queues in the event of an emergency vulnerability patch.

### Law 46 — Exception Surface Mapping
Error tracking is not enough. The `FirebaseException` surface bounds (`permission-denied`, `deadline-exceeded`, `unavailable`) MUST be explicitly mapped to human-readable UI states through the repository layer. The pipeline requires explicit unit tests simulating these exact codes to mathematically guarantee the UI does not hang or display raw backend traces to end users.

### Law 47 — Automated Programmatic Accessibility
To fulfil WCAG 2.1 AA Compliance (Law 32), the application requires an automated `tester.binding.accessibility` programmed scan injected directly into the widget test suite. This crawling logic enforces Semantics limits, contrast bounds, and font-scale clipping failures immediately during CI. Human verification is fallback only.

### Law 48 — 80% Absolute Coverage Floor (LCOV)
The CI pipeline relies firmly on an 80% minimum block-statement coverage. Tools generate an `lcov.info` payload. If the branch dips below 80% coverage due to merged untested code, the GitHub Action automatically rejects the commit and destroys the pipeline run.

### Law 49 — Machine-Enforced Execution (CORE)
Constitutional constraints must structurally block execution—not strictly detect violations post-facto. Integrate executable governance layers to ensure agents physically cannot violate rules.

### Law 50 — The "Mirror Test" Gap Validator
Tests must verify behavior, not reimplement logic. Any test identified as simply mirroring local production logic must be aggressively refactored.

### Law 51 — Tiered Autonomy Hierarchy
Execution privileges belong to 3 tiers:
- **Full:** Low-risk loops (Test/Lint arrays).
- **Supervised:** Structural file edits (Requires `[PLAN]` + explicit authorization).
- **Human-Only:** Security rule logic and secrets mutation.

### Law 52 — Immutable Audit Trails
Every AI-generated modification must hold unbroken traceability linking a specific prompt constraint to a verified test and explicit human approval.

---

### The Pipeline Tier Model (Mandated Execution Schedule)

| Tier | When | What Runs | Tools |
|------|------|-----------|-------|
| **Fast** | Every save | Unit tests + property tests | `flutter test test/core/` |
| **Medium** | Every PR | Emulator integration + mutation (changed files only) | Firebase Emulator + `flutter test test/wiring/` |
| **Slow** | Nightly | Fuzz + full mutation + golden regression (3 device sizes) | GitHub Actions nightly |
| **Pre-release** | Before tag | Full chaos injection + semantics + performance on real devices | Self-hosted runner |
| **Post-release** | Live | Canary 1% + Crashlytics threshold alert + auto rollback | Firebase RC + Crashlytics |

| **Post-release** | Live | Canary 1% + Crashlytics threshold alert + auto rollback | Firebase RC + Crashlytics |

> **The Ultimate Principle:** If your tests never see a failure, you are not testing hard enough. Inject failures deliberately. Simulate real-world chaos. Watch tests turn red. Fix before users see it.

---

## PART 18 — THE TESTING & PIPELINE MANDATES (Inviolable Checklist)

> **Added 2026-05-31 per Owner Directives.** These apply to ALL PRs and agents. No shortcuts. TDD is compulsory at all times.

### 🧱 Environment & Emulators
- Local testing relies *only* on the Firebase Emulator Suite (Auth, Firestore, Functions, Storage).
- Test users must be created programmatically via emulator tools.
- Security rules are written in `firestore.rules` and tested *only* locally via `firebase emulators:exec`.
- Pre-populate emulators with test data; disconnect all real prod/staging networks during testing.
- Test Cloud Functions failures (timeouts/crashes) via emulator routing.

### 🔍 Static Analysis (Compile-Time Catching)
- `flutter_lints` must be fully enforced with zero exceptions.
- Turn off implicit casts, demand return types, forbid unused variables.
- Ban `print()` entirely — use a logger.
- Enforce `const` constructors to prevent silent rebuild bugs.
- Must lint for: unawaited futures, `use_build_context_synchronously`, and empty `catch` blocks (which hide Firestore errors).
- Assert all overrides call `super`.
- `dart analyze` blocks PR merges instantly on 1 warning.

### 🧪 Unit Testing (Pure Logic)
- **TDD Requirement:** Test functions interacting with Firestore using fake/mock injectors.
- Verify explicit responses to `FirebaseException` codes: permission-denied, unavailable, not-found, deadline-exceeded.
- Data-shaping: verify Timestamp -> DateTime parses handle nulls, bad types, empty data.
- Enums/Status Mappings must fallback safely if backend sends junk.
- Riverpod/BLoC states must be tested in isolation to check exclusive Loading/Data/Error transitions.
- Validate retry loops & boundaries + stream closures on errors.

### 🎯 Widget Testing (UI Responses)
- *Every screen* requires a test asserting the display of Loading UI, Error/Permission UI (not raw traces), and Retry buttons (tap and succeed on retry).
- Test Empty Data States (zeros) show proper placeholders.
- Verify touch targets and gesturedetectors trigger route changes / state dumps correctly.
- Ensure popping disposes controllers.
- Test form validation boundaries (empty strings, short passwords).
- Test structural bounds: `setSurfaceSize` for text overrides / narrow screens, notch limits via SafeArea, and Dark Mode contrast mapping.

### 🔗 Integration Testing (Physical Taps)
- E2E Auth flow against the emulator is compulsory.
- Trigger `permission-denied` via bad claim injections and verify UI remains resilient.
- Trigger data absence (null doc fetch) and verify UI doesn't hang.
- Multi-device real-time sync tests (externally write to emulator, watch UI respond).
- Deeplink/Notification route tapping must deposit users at the correct UI state.
- **Chaos path mandated:** Test offline transitions via airplane mode mocking mid-fetch.

### 🔥 Firestore Security Rules Verification
- Maintain rule-testing harness against local Emulator Suite.
- Ensure unauthenticated users cannot read non-public paths.
- Ensure `user A` is rejected from `user B` docs.
- Test custom `admin`/`manager` claims verify strictly against privileged collections.
- Ensure shape/regex writes are blocked (e.g. invalid status string).

### ⛓️ Continuous Integration
- PRs fail instantly on `dart analyze`.
- Test coverage cannot slide below 80% (LCOV threshold).
- Rules testing, unit testing, widget testing, and Android integration emulators must run in the automated pipeline.
- iOS compile tests as minimum.
- Archived artifacts required before merge gate clears.

### 🩺 Crashlytics & Telemetry
- All non-fatal errors explicitly dumped to `FirebaseCrashlytics.instance.recordFlutterError`.
- Crashlytics tracks screen, user ID, context.
- Staging app crashes are physically reviewed post-E2E sweeps to detect silent exceptions.

### 🚦 Performance & Leaks
- Profiling required in dev tools. Zero janks >16ms before signoff.
- GC sweeps required to test screen popping leaks.
- Test un-cancelled Firestore stream listen retention.
- Ensure initial startup doesn’t hang on >50 doc loads.

### ♿ Accessibility
- `tester.binding.accessibility` required in tests.
- TalkBack / VoiceOver labels checked on every button and error surface.
- Font scaling up to 3x must not overflow pixels.

### 📦 Config & Dependencies
- Audit `pub outdated` before cuts. Check for plugin permission diffs in iOS Info.plist / Android Manifests.
- Reject build version mismatches structurally. Target oldest support OS.

### 🖼️ UI Goldens
- Critical screens captured. Runs on both OS targets. 1 pixel change breaks CI.

### 🌐 Network & 🧩 State
- Central HTTP/Firestore wrapping required.
- Test random backend HTTP 500s.
- No singletons. Mocked state managers must clear bindings on logout (flush memory & listeners).

### 🔐 Security & Privacy
- Zero keys in codebase -> `.env`.
- No unneeded permissions requested in mobile manifests.
- Test via staging physical devices as the ultimate signoff before manual intervention.


---

## PART — MANDATORY SELF-AUDIT RHYTHM

| # | Law | What It Means In Practice |
|---|-----|-----------------------------|
| **29** | **Stub & Wiring Audit Cadence** | Every 10 prompts, the AI MUST remind the user to run `/stub_and_wiring_audit`. The AI must also silently execute the audit checklist against any files edited in the last 10 prompts and report any stubs, TODOs, or unwired widgets found. No exceptions. |

*Last updated: 2026-06-27 · Law 29 adopted to enforce zero-stub tolerance at the session rhythm level.*
