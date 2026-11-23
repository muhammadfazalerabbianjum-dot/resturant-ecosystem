# 🚀 Golden Boilerplate Deployment Guide

---

## 🎛️ Demo Mode vs Production Mode

This app has a central flag in `lib/core/config/demo_config.dart`:

```dart
const bool kDemoMode = true;  // ← change to false for production clients
```

| Feature | `kDemoMode = true` (Demo/Spark) | `kDemoMode = false` (Production/Blaze) |
|---|---|---|
| Firebase Plan | Spark (free) | Blaze (pay-as-you-go) |
| Stripe Payment | Simulated (no real charge) | Real server-side validation |
| Tax Calculation | Hardcoded rate table in Dart | `calculateTax` Cloud Function |
| Fraud Screening | Local Firestore count | `screenPaymentFraud` Cloud Function |
| GDPR Delete | Client-side batch delete | Admin SDK cascade via Cloud Function |
| Telemetry | Direct Firestore write | `logFunnelEvent` aggregation pipeline |
| Fleet Dispatch | Direct Firestore update | `dispatchToFleet` DoorDash/Uber API |
| Order Creation | Direct Firestore write | `createOrder` price-validation function |
| Order Cancel | Direct status update | `cancelOrder` inventory refund function |

### Switching a Client to Production Mode
1. Upgrade Firebase project to **Blaze** plan at `console.firebase.google.com`
2. Run: `firebase deploy --only functions`
3. Set `kDemoMode = false` in `lib/core/config/demo_config.dart`
4. Rebuild: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`

---



This guide is your single source of truth for spawning new client instances.

## Step 1: Execute The White-Labeler
Clone the repo and immediately execute the master transformation CLI:
```bash
dart run tool/whitelabel.dart "New Restaurant" "com.new.restaurant" "0xFF1A1A1A"
```

## Step 2: Swap the Brand Assets
1. Delete the old `assets/logo.png` and `assets/logo_nobackground.png`.
2. Add your new client's high-res logo.
3. Generate the Splash Screen and iOS/Android Icons natively:
```bash
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

## Step 3: Zero-Touch Store Asset Generation
Execute our custom script to instantly generate the promotional App Store images overlaid with the client's hex color:
```bash
dart run tool/generate_stores.dart
```

## Step 4: Map the Database & Console Prerequisites
1. Go to Firebase Console and manually create `[Client] Prod` project.
2. Add an Android/iOS app pointing precisely to your newly generated package ID (e.g., `com.new.restaurant`).
3. Download `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/`.
4. **CRITICAL:** Enable Email/Password in Firebase Authentication.
5. **CRITICAL:** Initialize Firestore Database in Production Mode (rules will be pushed later).
6. **CRITICAL:** Go to Project Settings -> Service Accounts -> Generate new private key and save it as `tool/service-account.json`.

## Step 5: Remote Config UI Adjustments (Hardcoded overrides)
Currently we rely on manual developer feature toggles.
- Open `lib/core/config/feature_flags.dart` (or similarly named UI toggles) and explicitly map:
  - `const bool enableReservations = false;`
  - `const bool enableOfflineKitchen = true;`

## Step 6: Deploy Security Rules & Boot
```bash
# Deploy Cloud Functions and Firestore Rules
firebase deploy --only firestore,functions

# Seed test accounts (Driver, Kitchen, Admin)
cd tool
npm install firebase-admin
node seed_test_accounts.js
cd ..

# Build the release bundle
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```
You are now ready to hand off the production `.aab` and `.ipa`!

---

## 🔑 Complete "What Changes Per Client" Swap List

This is the definitive, exhaustive list of **every credential and config** you must replace when onboarding a new restaurant client. Miss any one of these and the client's app will either crash or still be pointing at YOUR Firebase backend.

### 🔥 Firebase (Mandatory — New Project Per Client)
| What | File | Action |
|---|---|---|
| Android Google Services | `android/app/google-services.json` | Download fresh from new client Firebase Console |
| iOS Google Services | `ios/Runner/GoogleService-Info.plist` | Download fresh from new client Firebase Console |
| Project ID | `lib/firebase_options.dart` | Re-run `flutterfire configure` to auto-regenerate entirely |
| Admin Service Account | `tool/service-account.json` | Generate new private key under Project Settings → Service Accounts |

### 💳 Stripe (Mandatory — New Account Per Client)
| What | File | Notes |
|---|---|---|
| Publishable Key | `lib/main.dart` → `Stripe.publishableKey` | Get from Stripe Dashboard → Developers → API Keys |
| Secret Key | `functions/src/index.ts` → `stripe(...)` constructor | Store in Firebase Secret Manager, NOT hardcoded |

### ☁️ Cloudinary (If using image uploads)
| What | File | Notes |
|---|---|---|
| Cloud Name | `lib/core/services/cloudinary_service.dart` | Cloudinary Dashboard → Settings |
| Upload Preset | Same file | Create unsigned preset in Cloudinary Media Library settings |

### 📱 App Identity (Run whitelabeler — auto-handled)
| What | File | Notes |
|---|---|---|
| App Name | `android/app/src/main/AndroidManifest.xml` | `dart run tool/whitelabel.dart` handles this |
| Bundle ID | `ios/Runner.xcodeproj/project.pbxproj` | `dart run tool/whitelabel.dart` handles this |
| Package Name | `android/app/build.gradle` | `dart run tool/whitelabel.dart` handles this |
| Primary Color | `lib/core/theme/app_theme.dart` | `dart run tool/whitelabel.dart --color "#HEX"` handles this |
| Logo | `assets/logo.png`, `assets/logo_nobackground.png` | Replace manually, then re-run `flutter_launcher_icons` |

### 🔔 Push Notifications (Firebase — auto-linked to new project)
- FCM is automatically linked once `google-services.json` is replaced. No extra steps.

### 🧾 Stripe Webhook Secret (Production Only)
- Go to Stripe Dashboard → Webhooks → Add endpoint pointing to your deployed Cloud Function URL.
- Copy the `Signing Secret` and store it in Firebase Secret Manager as `STRIPE_WEBHOOK_SECRET`.

### 🌍 App Store / Play Store (New Listings Per Client)
- Create a new app in [App Store Connect](https://appstoreconnect.apple.com) and [Google Play Console](https://play.google.com/console).
- Update `ios/fastlane/Fastfile` with the new `app_identifier` and `apple_id`.
- Update `android/fastlane/Fastfile` with the new `package_name`.

