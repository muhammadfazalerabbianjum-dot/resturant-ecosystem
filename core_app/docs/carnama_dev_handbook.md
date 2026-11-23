# Carnama Enterprise Platform — Developer Handbook
**Version:** 1.1 · **Status:** Production-Active · **Last Updated:** 2026-05-19

> This document is the complete A-Z guide to the Carnama Enterprise codebase. A new developer who reads this end-to-end should be able to clone the repo, understand every decision, and contribute immediately.

---

## Chapter 1 — What Is Carnama?

Carnama is a **white-label B2B restaurant management platform** built in Flutter + Firebase. It is not a single-restaurant app — it is a full enterprise system designed to be rebranded and deployed for any restaurant client.

**Key Stakeholders:**
| Role | Access |
|------|--------|
| Owner | Full control: analytics, RBAC, pricing, branches |
| Manager | Branch-level: menu, orders, staff |
| Kitchen | Incoming orders, mark ready |
| Driver | Assigned deliveries, map navigation |
| Customer | Browse menu, place order, track delivery |

---

## Chapter 2 — The 20 Laws (Inviolable Rules)

These are non-negotiable. Every PR is checked against them. Violating any one of them is grounds for a hard rollback.

| # | Law | What It Means In Practice |
|---|-----|--------------------------|
| 1 | **Hard Stop Protocol** | If an instruction creates a paradox or threatens stability, stop and block on user authorization. No silent assumptions. |
| 2 | **TDD-First** | Write the failing test FIRST. Write the code second. No feature is "done" until `flutter test` is 100% green. |
| 3 | **Single Source of Truth** | No hardcoded colors, strings, or numbers. Use `AppColors`, `AppDimensions`, `AppStrings`. One file to rule them all. |
| 4 | **Zero Stub Tolerance** | No `// TODO`, no placeholder containers, no fake data. Every screen ships wired to real Firestore. |
| 5 | **Architectural Memory** | `docs/carnama_brain.md` is always read before any new feature sequence begins. |
| 6 | **Golden Target Precision** | UI must match Tier-1 SaaS: fluid scaling, glassmorphism, micro-animations, correct frame rates. |
| 7 | **The Scout Rule** | Leave every file cleaner than found. Refactor legacy spaghetti before adding new code to the same file. |
| 8 | **Defensive Execution** | Every API call is in a `try/catch`. Network failure = graceful degradation, never a red error screen. |
| 9 | **Idempotency on Critical Writes** | A double-tap on "Checkout" must be physically incapable of duplicating a charge. All mutations are idempotent. |
| 10 | **Master Pipeline Gate** | Nothing is "live" until `dart tool/pipeline.dart` returns 0 warnings and 100% green tests. |
| 11 | **Silent Telemetry** | Every crash lands in Firebase Crashlytics. We never wait for a user bug report. |
| 12 | **Security by Least Privilege** | The mobile client is treated as hostile. No security decisions happen in Dart. Security lives in Firestore Rules. |
| 13 | **Death by 1000 Cuts Guard** | Every new dependency bloats the APK. Write a small custom script before importing a heavy package. |
| 14 | **"Why" Not "What" Comments** | Comments explain the business logic, not the syntax. If a formula is complex, say WHY it exists. |
| 15 | **Disconnect Principle (Offline-First)** | If a user loses signal mid-order, queue the request. Sync on reconnect. Never drop user intent. |
| 16 | **Secret Guarding** | Zero API keys in source control. All secrets live in `.env` (excluded from Git). |
| 17 | **Visual Regression Immunity** | Golden Tests capture pixel-perfect screenshots. A 1-pixel shift on the Checkout button breaks CI. |
| 18 | **Strict Environment Parity** | Staging is a 1:1 clone of Production. All migrations are tested in Staging first. |
| 19 | **Continuous Documentation** | On every major feature merge, `carnama_brain.md` and `ARCHITECTURE.md` are updated. |
| 20 | **Bus Factor Protocol** | A junior dev must be able to `clone → dart tool/pipeline.dart → running app` in under 5 minutes, with zero help from the original architect. |

---

## Chapter 3 — Tech Stack A-Z

| Layer | Technology | Why |
|-------|-----------|-----|
| Mobile Framework | Flutter 3.x (Dart) | Single codebase, Android + iOS + Web |
| State Management | Riverpod 2.x | Compile-safe providers, testable, no singletons |
| Navigation | GoRouter 14.x | Declarative routes, deep-linking, role guards |
| Backend Database | Cloud Firestore | Real-time streams, offline support, RBAC |
| Authentication | Firebase Auth | Email/Password + Google Sign-In |
| Cloud Functions | Firebase Functions v1 (Blaze tier required) | Server-side: tax calc, fraud detection, GDPR |
| Local Cache | Isar Database | Offline-first: menus, pending writes cached locally |
| Push Notifications | Firebase Messaging (FCM) | Order status → customer push |
| Image Loading | `cached_network_image` | Efficient memory-capped image loading |
| Charts | `fl_chart` | Revenue & analytics graphs in Owner Dashboard |
| Maps | `flutter_map` (OpenStreetMap) | No Google Maps API key needed for map tiles |
| Reverse Geocoding | `geocoding` package | Converts lat/lng to human address string |
| GPS | `geolocator` | Device location acquisition with permission handling |
| Navigation Deeplink | `url_launcher` | Opens `google.navigation:q=lat,lng` in native Maps |
| Payments | Stripe SDK (bypassed on Spark tier) | Full integration ready, bypassed in demo/Spark mode |
| CI/CD | `dart tool/pipeline.dart` | Custom pipeline: lint + test + build gate |
| Testing | `flutter_test` + `mockito` + `fake_cloud_firestore` | Unit, widget, golden, integration |
| Crash Reporting | Firebase Crashlytics | Silent crash telemetry |
| Performance | Firebase Performance | API latency and app frame rate tracking |
| Remote Config | Firebase Remote Config | Feature flags at runtime without a redeploy |

---

## Chapter 4 — Architecture Overview

```
lib/
├── core/
│   ├── auth/           ← Firebase Auth state + UserModel
│   ├── cache/          ← Isar service + offline sync provider
│   ├── config/         ← demo_config.dart (SPARK tier bypass switch)
│   ├── models/         ← DeliveryLocationModel (typed location)
│   ├── navigation/     ← GoRouter config + RouteNames + DeepLinkService
│   ├── network/        ← NetworkRetry, PendingSyncProvider
│   ├── theme/          ← (WIP) AppColors, AppDimensions, AppStrings
│   └── ui/             ← Shared widgets: EmptyStateWidget, etc.
├── features/
│   ├── admin/          ← Owner, Manager, Kitchen, Driver dashboards
│   ├── auth/           ← LoginScreen, SignUpScreen
│   ├── cart/           ← CartProvider, CartScreen
│   ├── checkout/       ← CheckoutScreen (with map picker integration)
│   ├── home/           ← HomeScreen, SearchTab, PendingSyncBanner
│   ├── location/       ← PinDropMapScreen (GPS → geocoding → DeliveryLocationModel)
│   ├── menu/           ← MergedMenuProvider (Firestore + local cache)
│   ├── orders/         ← OrderModel, OrderRepository, OrderHistoryScreen
│   └── profile/        ← ProfileScreen (Staff Dashboard CTA)
└── main.dart           ← App entry: Firebase init + Riverpod + GoRouter
```

---

## Chapter 5 — RBAC (Role-Based Access Control)

Every user has a `role` field in their Firestore `users/{uid}` document.

| Role | Value | Dashboard |
|------|-------|-----------|
| Owner | `"owner"` | OwnerDashboard |
| Manager | `"manager"` | ManagerDashboard |
| Kitchen | `"kitchen"` | KitchenDashboard |
| Driver | `"delivery"` | DeliveryDashboard |
| Customer | `"customer"` | HomeScreen (no Staff CTA) |

**How it works:** The `RoleRouterScreen` is a Firestore `StreamBuilder` that reads `users/{uid}.role` in real-time. On role change, the user is instantly redirected to the correct dashboard — zero logout/login required.

**How to promote a user:** Owner Dashboard → Users tab → find account → change role dropdown.

---

## Chapter 6 — Firebase Architecture

### Collections
| Collection | Documents | Who Reads | Who Writes |
|-----------|-----------|-----------|-----------|
| `users/{uid}` | UserModel | Owner, Manager, self | Owner, Manager, self |
| `orders/{orderId}` | OrderModel | All staff + customer | Kitchen, Driver, Owner + Cloud Functions |
| `branches/{branchId}` | BranchModel | All authenticated | Owner only |
| `menus/{itemId}` | MenuItemModel | All authenticated | Owner, Manager |
| `carts/{uid}` | Cart items | Customer (self) | Customer (self) |
| `loyalty/{uid}` | Points balance | Customer (self) | Cloud Functions |
| `presence/{uid}` | Online/offline | Owner, Manager | Self (heartbeat) |
| `analyticsEvents/` | Funnel events | Owner | Cloud Functions |
| `settings/featureFlags` | Toggle map | All authenticated | Owner only |
| `settings/ownerInfo` | Owner email | Security Rules | Owner manually |

### Cloud Functions (Requires Blaze Plan)
| Function | Trigger | Purpose |
|----------|---------|---------|
| `calculateTax` | HTTPS callable | Server-side tax calculation |
| `screenPaymentFraud` | HTTPS callable | Velocity check: >10 orders/hr = flag |
| `dispatchToFleet` | HTTPS callable | Stub for DoorDash Drive / Uber Direct |
| `logFunnelEvent` | HTTPS callable | Analytics event logger |
| `deleteUserData` | HTTPS callable | GDPR cascade wipe |
| `recoverAbandonedCarts` | Pub/Sub (every 5min) | FCM push to dormant carts |
| `onOrderStatusChange` | Firestore trigger | FCM push to customer on status change |

> ⚠️ **Spark Plan Note:** All Cloud Functions are non-operational on the Spark (free) plan. The app has a built-in `kDemoMode` bypass in `checkout_screen.dart` and `order_repository.dart` that simulates success so the demo UX works perfectly without Blaze.

### Firestore Security Rules Philosophy
- Customers cannot read the driver queue, kitchen screen, or other users' data.
- Managers can only modify users/orders within their own `branchId`.
- Managers cannot promote users to `owner` or `manager` — only `kitchen`, `delivery`, `customer`.
- All writes to critical documents are validated server-side via Security Rules, not client-side.

---

## Chapter 7 — The Dev Pipeline (How We Ship)

### The Single Command
```powershell
dart tool/pipeline.dart
```
This runs in sequence:
1. `flutter format --set-exit-if-changed .` → code style gate
2. `flutter analyze` → **0 warnings allowed, zero exceptions**
3. `flutter test` → **100% green required**
4. `firebase deploy --only firestore:indexes,firestore:rules`
5. `flutter build apk --release`

**Nothing ships if any step is red. No exceptions. Not even "small" changes.**

### Pipeline Overhaul Origin
The pipeline replaced a fragile 14-phase "prompt-based" system. Key critique that drove the change:
- Prompt-bound CI required pasting 500-word prompts manually — brittle
- Tests ran against an empty database → false positives
- No visual regression detection
- `permission-denied` errors gave no context on *which* Firestore rule failed

The solution: port all validation from English prompts into deterministic code scripts (`tool/pipeline.dart`), deterministic data seeding, and Golden Tests.

---

## Chapter 8 — The 23-Phase Development History

Everything that was built, in the exact order it was built. This is the full project lineage.

| Phase | What Was Built |
|-------|----------------|
| **Phase 1** | Data Models & Firestore — `UserModel`, `OrderModel`, `BranchModel`, `MenuItemModel`, `PresenceModel`. Security rules. Composite indexes. Serialization tests. |
| **Phase 2** | Route & Navigation — GoRouter setup, `RouteNames`, `RoleRouterScreen`, role guards |
| **Phase 3** | Admin Dashboards — OwnerDashboard (7 tabs), ManagerDashboard (4 tabs), KitchenDashboard (Preparing + Ready), DeliveryDashboard (My Orders + Available Orders) |
| **Phase 4** | Branch & Order Routing — GPS nearest-branch, manual picker dialog, `isManualBranch` flag, delivery radius check, merged menu provider, order placement with auto `branchId` |
| **Phase 5** | Static Analysis Hardening — `flutter analyze` to 0 warnings, Riverpod lint rules, `.autoDispose` provider audit, resource cleanup (dispose/cancel), remove all `debugPrint` |
| **Phase 6** | Property-Based / Fuzz Testing — `test/property/`, 1000-item faker tests, code coverage ≥ 80% |
| **Phase 7** | Unforgiving Audit Fixes — Driver assignment race (TDD + Transaction), field name mismatch `userId` vs `customerId`, StreamController leak, StreamProvider-in-build fix, unbounded reads, menu merge key, public menu rules, delivery radius, Manager role escalation |
| **Phase 8** | Automation Overhaul — `tool/pipeline.dart` master runner, Firestore emulator seed, Golden Test definitions, headless log pipeline for permission-denied traces |
| **Phase 9** | World-Class Pipeline Additions — APK size + frame rate CI gate, `CODEOWNERS` file, Remote Config kill switch rollback smoke test |
| **Phase 10** | Post-Fix Regression Guard — 13 targeted regression tests, 207 total tests passing |
| **Phase 14+** | Observability & Release — Firebase Crashlytics + Performance natively wired |
| **Phase 16** | Store Compliance & Reservations — `NSLocation` iOS plist, `ReservationModel`, Reservations tab |
| **Phase 17** | Stub Audit — Full static sweep, fix all stubs, wiring integration tests, stub_guard CI gate, 217 tests passing |
| **Phase 18** | Core Production Blindspots — `createOrder` Cloud Function anti-spoofing, FCM push wiring, Stripe Apple/Google Pay, UTC timezone normalization, Firebase App Check (`PlayIntegrity`/`AppAttest`), form state restoration, `cached_network_image`, inventory quantity atomicity, Geohash spatial indexing, Kitchen Printer (deferred V2), Menu Modifiers, 120-second order cancellation grace period, Force Update Guard (Remote Config), PII scrubber in Crashlytics, Fastlane CI/CD scaffolding |
| **Phase 19** | Tier-1 Enterprise — Multi-language i18n (EN + AR RTL), Promo Code Engine (Firestore-backed, atomic, replay-proof), Background GPS streaming (driver location even when app is killed), Proof of Delivery (camera → Firebase Storage), Deep Linking, Accessibility (Semantics labels, ADA/EAA compliance) |
| **Phase 20** | Unicorn Scale — Tax & Surge Pricing (callable Cloud Function, per-state rates), Delivery Driver Tipping widget (0–25%), Kitchen Offline LAN Fallback (workmanager), Cursor-based Firestore pagination (eliminates RAM bombs), Cart Abandonment Recovery (Pub/Sub FCM), OTA patches (Shorebird) |
| **Phase 21** | Global B2B Platform Layer — Fraud Detection (velocity check, account flagging), Third-Party Fleet Integration (DoorDash Drive / Uber Direct stub), NFC Terminal Service (Stripe Terminal contract), Funnel Telemetry (typed analytics events → BigQuery), GDPR Right-to-be-Forgotten (cascade wipe Cloud Function) |
| **Phase 22** | B2B Scale Factory — White-Label Automation Pipeline (`tool/whitelabel.dart`), Fastlane asset generation, Enterprise Architecture Wiki (`ARCHITECTURE.md`, `DEPLOYMENT_GUIDE.md`) |
| **Phase 23** | Final Pre-flight — Firestore rules gap (5 missing collections patched), Cloud Functions compilation (`functions/index.ts` authored), automated test seeder (`tool/seed_test_accounts.js`) |
| **V1.1 Sprint** | Interactive Maps — `DeliveryLocationModel`, `PinDropMapScreen` (OpenStreetMap + GPS + debounced geocoding), CheckoutScreen wired, Driver navigation deeplink |

**Total tests across all phases: 226 passing, 0 warnings.**

---

## Chapter 9 — Location & Maps Feature

**Completed in V1.1 Sprint.**

**Flow:**
1. Customer taps the address field in `CheckoutScreen`.
2. `PinDropMapScreen` opens full-screen.
3. OpenStreetMap tiles load via `flutter_map`.
4. GPS acquires user's live location (with permission handling).
5. User drags the map — the center reticle pin stays fixed.
6. After 600ms of no movement (debounce), `geocoding` resolves the lat/lng to a human address string.
7. User taps "Confirm Location" → a typed `DeliveryLocationModel` is returned to `CheckoutScreen`.
8. The address is displayed in the checkout form.

**Driver Navigation:**
- Driver taps "Navigate" on an assigned order in `DeliveryDashboard`.
- `url_launcher` fires `google.navigation:q={lat},{lng}` which opens Google Maps turn-by-turn natively.
- Fallback for non-Google Maps devices: `https://maps.google.com/?q=lat,lng`.

---

## Chapter 10 — Testing Architecture

```
test/
├── core/              ← Model serialization, AppConfig
├── location/          ← DeliveryLocationModel (9 tests), PinDropMapScreen widget (4 tests)
├── golden/            ← Visual regression: pixel-perfect UI screenshots
│   ├── golden_test_helper.dart      ← Deterministic theme wrapper (no HTTP)
│   ├── login_screen_golden_test.dart
│   └── baselines/     ← auto-generated PNG files (committed to git)
└── features/          ← Widget tests per feature
```

**Commands:**
```bash
flutter test                              # Run all tests
flutter test test/golden/ --update-goldens # Regenerate golden baselines
flutter test --coverage                   # Coverage report
```

---

## Chapter 11 — White-Label System

The app has a built-in white-label engine at `tool/whitelabel.dart`.

**Current locked config (Carnama Labs):**
- App Name: `Carnama Labs`
- Bundle ID: `com.carnama.labs`
- Primary Color: `#FF6B00` (orange)

### 1. Automated Rebranding
To rebrand for a new client, run the central script:
```bash
dart tool/whitelabel.dart \
  --name "New Client" \
  --color "#1A73E8" \
  --bundle "com.newclient.app"
```
This patches `AndroidManifest.xml`, `Info.plist`, `pubspec.yaml`, and the theme file in one shot.

### 2. Manual Client Checklist (A-Z)
To completely detach and launch a new client platform, you must physically replace the following external dependencies:

1. **Firebase Project Initialization:**
   - Create a new Firebase Project via the Firebase Console.
   - Run `flutterfire configure`. This will automatically generate the new `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and `lib/firebase_options.dart`.
2. **Environment & Payment Secrets:**
   - Create new `.env.production` and `.env.staging` files.
   - Inject the new client's Stripe `Publishable Key` and `Secret Key`.
3. **Native Assets:**
   - Replace `assets/images/logo.png` and `assets/images/logo_dark.png`.
   - Update `flutter_launcher_icons` config in `pubspec.yaml` and regenerate the Android/iOS app icons.
   - Update `flutter_native_splash` config and rebuild the native OS launch screens.
4. **Backend Deploy (Firebase CLI):**
   - Run `firebase login` and `firebase use <new-project-id>`.
   - Upgrade the project to the Blaze Plan (required for Node.js Cloud Functions).
   - Run `firebase deploy --only firestore,functions`.
5. **Initial Seeding:**
   - Download the new Service Account Key from Firebase Project Settings.
   - Inject it into `tool/seed_test_accounts.js` and run node to create the initial Owner account.

---

## Chapter 12 — Known Pending Work

| Item | Priority | Notes |
|------|----------|-------|
| Upgrade to Firebase Functions v2 | Pre-launch | Current v1 syntax is deprecated in 2024+ |
| Input validation on Cloud Functions | Pre-launch | `calculateTax` trusts client `subtotalCents` — needs `zod` guard |
| Blaze plan upgrade | Pre-launch | Activates all 7 Cloud Functions for production |
| Kitchen Printer Integration (ESC/POS) | V2 | Deferred — Bluetooth/Network thermal printer for order tickets |
| Background Offline Replay | V2 | `workmanager` for Isar queue replay when app process is killed |

