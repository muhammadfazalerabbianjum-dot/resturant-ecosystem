# CLIENT APP HANDOFF DOCUMENT
> **Written:** 2026-05-27  
> **Context:** Carnama demo app (Spark plan) → Real client app (Blaze plan)  
> **Rule:** Do NOT implement deferred items until the client Firebase project is on a Blaze plan.

---

## Part 1 — What This Demo App Proves (Keep Forever)

This is not throwaway code. Every pattern here is the skeleton of the client app.

| System | Status | Notes |
|--------|--------|-------|
| Break-the-Loop Architecture | ✅ Locked | Guaranteed crash-free separation of concerns |
| Reservation Concurrency (atomic Firestore lock) | ✅ Locked | `reservation_locks` enforces slot uniqueness |
| Branch-scoped capacity limits | ✅ Locked | `BranchModel.capacity` + live query gate |
| Firestore Security Rules | ✅ Locked | Client is treated as hostile at all times |
| Patrol E2E scaffold | ✅ Locked | Windows-native, no Android emulator needed |
| Global Error Widget | ✅ Locked | All uncaught exceptions surface to UI, never silent |
| Shorebird OTA CI Pipeline | ✅ Locked | `.github/workflows/shorebird_patch.yml` ready |
| Cloud Functions v2 structure | ✅ Ready | Functions written, just need Blaze to deploy live |
| Stripe payment flow | ✅ Scaffolded | Wired in `kDemoMode` bypass until Blaze live keys |
| Firebase App Check | ✅ Configured | Activates automatically on real bundle IDs |

---

## Part 2 — What to Activate the Moment You Have a Blaze Plan

These are fully written. They just need a live Firebase project.

- [ ] **Deploy Cloud Functions** — `firebase deploy --only functions` from `functions/src/index.ts`
- [ ] **Enable Stripe Live Keys** — Replace `kDemoMode` bypass in `CheckoutScreen` with real `createPaymentIntent` call
- [ ] **Activate Crashlytics Alerts** — Wire Crashlytics → Slack/email webhook in Firebase console
- [ ] **Run Firebase Emulator Suite in GitHub Actions CI** — `firebase emulators:exec dart tool/pipeline.dart` as a CI step
- [ ] **Enable Golden Screenshot regression tests** — Tier 3 gate blocking bad UI on non-standard screen densities

---

## Part 3 — What MUST Change for the Client App (Non-Negotiable)

### 🔴 Firebase Project
- Create a **brand new** Firebase project (never reuse the demo project)
- New `google-services.json` (Android) + `GoogleService-Info.plist` (iOS)
- New `.env` file with client-specific keys
- Update `ADMIN_TAP_ESCAPE_HATCH_PIN` in environment secrets

### 🟠 Brand & UI (Complete Replacement)
- All UI is in `lib/features/*/presentation/` — safe to gut and rebuild
- `global_error_widget.dart`, `carnama_button.dart`, color tokens in `theme/` → rebrand entirely
- App name, bundle ID, package name in `pubspec.yaml`, `AndroidManifest.xml`, `Info.plist`
- Replace all hardcoded `'Carnama'` strings (search globally)
- Replace app icon, splash screen, favicon

### 🟡 Shorebird
- Run `shorebird init` on the new project to register a new app ID
- Update `shorebird.yaml` with the new app ID
- Add `SHOREBIRD_TOKEN` to the new repo's GitHub Secrets

### 🟡 Notification Config
- Register new FCM sender ID for the new project
- Update `android/app/google-services.json` (FCM is project-scoped)

### 🟢 Depend on Packages (Architecture — V2 Extraction)
> **IMPORTANT (V2):** The monolithic `lib/core/` has been extracted into two first-class Melos workspace packages. Client apps **depend on these packages** via `pubspec.yaml` — they no longer copy-paste `lib/core/`.

**Step 1 — Add package dependencies to client app `pubspec.yaml`:**
```yaml
dependencies:
  core:
    path: ../packages/core
  core_ui:
    path: ../packages/core_ui
```

**Step 2 — Import via public barrels (never `src/`):**
```dart
import 'package:core/core.dart';        // domain + services
import 'package:core_ui/core_ui.dart';  // Flutter widgets + theme
```

**What the packages provide:**
- `packages/core/` — all providers, auth, error handling, navigation, cache, compliance, payment, kitchen, network, storage (pure Dart, no Flutter)
- `packages/core_ui/` — theme tokens (AppColors, AppDimensions, AppTheme), shared widgets (BrandButton, EmptyStateWidget), compliance dialogs, ForceUpdateGuard

**What stays in the client app:**
- `lib/features/reservations/` — data + domain layer (not presentation)
- `lib/features/orders/` — data + domain layer
- `firestore.rules` — extend, never shrink (security first)
- `tool/pipeline.dart` — run as-is
- `test/core/`, `test/wiring/`, `test/e2e/` — adapt and extend

> ⚠️ **Never copy `lib/core/` into a client app.** Depend on `packages/core` and `packages/core_ui` instead. This ensures all clients share a single source of truth for domain logic and UI primitives (Law 3 — Single Source of Truth).

---

## Part 4 — Demo App Stability Rules (Until Client App Begins)

These rules protect the demo from breaking during client pitches.

1. **No new dependencies** without running `dart tool/pipeline.dart` first
2. **No Firestore rule changes** without a concurrency test confirming nothing regressed
3. **kDemoMode must stay `true`** — Stripe is not wired live on Spark
4. **No new screens** added without wiring them to `global_error_widget.dart` boundary
5. **The Windows build must stay green** — it's the demo target

---

## Part 5 — Estimated Client App Sprint Roadmap

| Sprint | Goal |
|--------|------|
| Client 0 | Firebase Blaze project setup, deploy Cloud Functions, activate Stripe live |
| Client 1 | Full UI rebrand (new theme, new screens, new brand assets) |
| Client 2 | Firebase Emulator CI running in GitHub Actions |
| Client 3 | Crashlytics alerting + Golden screenshot regression gate |
| Client 4 | App Store / Play Store production submission |

---

*This document is the source of truth for the client app transition. Update it as the demo app evolves.*
