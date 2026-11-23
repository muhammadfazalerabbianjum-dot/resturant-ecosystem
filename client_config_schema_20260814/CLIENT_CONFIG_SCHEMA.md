# CLIENT CONFIG SCHEMA — Documentation (Constitutional Edition v1.0)

Generated: 2026-08-14
Schema file: `client_config_template.json`
Source audit: `<audit-folder>\CHANGEABILITY_AUDIT_REPORT.md` (sections 1–7) + `<audit-folder>\01_env.txt`
Validation evidence: `04_validation.txt`

---

## 1. Purpose

`client_config_template.json` is the **single validated source of truth** for every configurable
aspect of a client application built on the Carnama core. It is the input contract for the client
generator: given this file, the generator produces a client variant (app identity, Firebase wiring,
feature flags, theme, navigation, included screens, tax behaviour, and optional new features).

Every field in the schema is derived from either:
1. The Changeability Audit report (raw `grep`/`find` output captured in `01_env.txt`), or
2. Direct code inspection of the actual repository (validated in `04_validation.txt`).

No field is guessed.

---

## 2. Domain-by-Domain Field Reference

### 2.1 `app`

| Field | Audit source | Code location | Notes / Default |
|-------|--------------|---------------|-----------------|
| `name` | Report §1 `APP_NAME` (env) | `core_app/lib/app/config/app_config.dart:15` | `Carnama` |
| `bundleId` | Report §1 `APP_BUNDLE_ID` (env) | `core_app/lib/app/config/app_config.dart:16` | `com.carnama.labs` |
| `primaryColor` | Report §5 `AppColors.primary` | `packages/core_ui/lib/src/theme/app_colors.dart:5` | `0xFFFF6B00` — **currently hardcoded; needs code change to be injectable** |
| `fontFamily` | Report §5 "Fonts" | `packages/core_ui/lib/src/theme/app_theme.dart:28` | `'System'` — **currently hardcoded; needs code change to be injectable** |
| `storeAndroidUrl` | Report §1 `STORE_ANDROID_URL` | `app_config.dart` | Store link |
| `storeIosUrl` | Report §1 `STORE_IOS_URL` | `app_config.dart` | Store link |
| `fcmChannelDescription` | Report §1 `FCM_CHANNEL_DESCRIPTION` | `app_config.dart` | Notification channel |

### 2.2 `environment`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `cloudinaryCloudName` | Report §1 / `01_env.txt` | `env.dart:5` | default `dcqf9qpsq` |
| `cloudinaryUploadPreset` | Report §1 / `01_env.txt` | `env.dart:9` | default `carnama_unsigned` |
| `stripePublishableKey` | Report §1 / `01_env.txt` | `env.dart:15`, `main.dart:192` | default `pk_test_REPLACE_ME…` |
| `recaptchaWebKey` | Report §1 | `main.dart:157` | required, no default |
| `firebaseAndroidApiKey` | Report §1 | `firebase_options.dart` | required (fail-fast) |
| `firebaseIosApiKey` | Report §1 | `firebase_options.dart` | required (fail-fast) |
| `devAdminPin` | Report §1 `_kDevAdminPin` | `packages/core/lib/src/admin/admin_access_service.dart:13` | dev-only admin PIN |

### 2.3 `firebase`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `projectId` | Report §1 `FIREBASE_PROJECT_ID` | `app_config.dart:17` | default `''` |
| `androidAppId` / `iosAppId` / `messagingSenderId` / `iosClientId` | Report §1 "Hardcoded Firebase identifiers" | `firebase_options.dart` | **currently hardcoded; externalised in this schema** |
| `collections` | Report §2 (24 collections) | verified via `collection('…')` grep | map of logical name → collection name |
| `clientScopingFields` | Report §2 "Client-specific filtering fields" | repo queries | `branchId`, `customerId`, `userId`, `assignedDriverId` with affected collections |
| `configDocuments` | Report §2 "Config documents" | `settings/…`, `branches/{id}/config/…` | runtime config doc paths |

### 2.4 `features`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `source` | Report §4 | `feature_flags_service.dart` | `settings/featureFlags` (Firestore) |
| `flags.*.enabled` | Report §4 table | `feature_flags_service.dart:8-14` | 7 flags: `smartReorder`, `loyaltyPoints`, `tourMode`, `waitlist`, `referrals`, `deliveryTracking`, `promoCode` — all default `true` |
| `unknownFlagDefault` | Report §4 | `feature_flags_service.dart` | unknown → `false` |

### 2.5 `tax`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `defaultRate` | Report §3 (fail-closed design) | `functions/src/index.ts` | 0.0 = "no default state; fail-closed" — **recommendation: move to Firestore so clients can provide a default** |
| `stateRates` | Report §3 table | `functions/src/index.ts:37` | `CA 0.0725, NY 0.08, TX 0.0625, FL 0.06` — **currently hardcoded in Cloud Function; requires redeploy to change; schema externalises them** |
| `source` | Report §3 "Changeability note" | — | recommended `firestore` (migration target); current implementation is server-side hardcoded |
| `currentImplementation` | Report §3 | `functions/src/index.ts:28-37` + `tax_service.dart` | server-side only; client fail-closed |
| `failClosedOnUnknownState` | Report §3 | `functions/src/index.ts` | unknown state → `failed-precondition`, never $0 |

### 2.6 `theme`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `injection` | Task spec | — | `local-config-file` — theme injected via local config |
| `typography.fontFamily` | Report §5 | `app_theme.dart:28` | `'System'` |
| `typography.sizes` | Report §5 + code inspection | `app_theme.dart` | headline/title/body/caption sizes |
| `colors` | Report §5 table (15 tokens) | `app_colors.dart` (all 15 verified) | primary, secondary, accent, background, surface, textPrimary, textSecondary, error, success, warning, transparent, background54, background70, textPrimary12/45/54 |
| `darkTheme` | Report §5 "Dark theme overrides" | `app_theme.dart` | background `0xFF121212`, surface `0xFF1E1E1E` |
| `confettiOverlay` | Report §5 | `confetti_overlay.dart` | 4 hardcoded colors externalised |
| `spacing` | Report §5 `AppDimensions` | `app_dimensions.dart` | `smallPadding 8.0`, + medium/large derived from inspection |

**Changeability note:** theme is **compile-time** today — the generator will write a local config file
that `ThemeProvider`/`AppColors` must be refactored to consume (code change required, tracked in §4).

### 2.7 `navigation`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `entryPoint` | Task spec; audit §6 Home route | `app_router.dart:119` | `/home` (route name `home`) |
| `tabs` | Task spec; audit §6 primary nav routes | `app_router.dart` | `/home`, `/menu`, `/orders`, `/reservations`, `/profile` |
| `hiddenRoutes` | Audit §6 admin/role routes + §8 "Screens compile-time" | `app_router.dart` | role-gated admin routes (`/admin`, `/owner`, `/manager`, `/kitchen`, `/delivery`, `/role-router`, `/error-logs`, `/logs`, `/admin-gateway`) can be hidden per client |
| `routes` | Report §6 (29 routes) | `app_router.dart` + `route_names.dart` (verified via `name: RouteNames.*`) | full route table |

### 2.8 `screens`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `[].id` | Report §7 (26 screens) | `core_app/lib/features/**/presentation/*_screen.dart` (all 26 files verified on disk) | widget class name |
| `[].route` | Report §6 route table | `app_router.dart` | route path |
| `[].mandatory` | Derived from feature criticality (task spec: "mark mandatory vs optional") | audit §2 (client filters `orders/menus` = core) | `true` for core ordering/auth screens; `false` for feature-gated/optional screens (waitlist, loyalty, admin, reservations, locations, tracking) |

### 2.9 `newFeatures`

| Field | Audit source | Code location | Notes |
|-------|--------------|---------------|-------|
| `newFeatures[]` | Task spec §2h; audit §4 "unknown flag → false" | generator / client modules | **Extensibility contract.** A client can list custom feature names not in the core 7 flags. Each is enabled/disabled per client and implemented either in the client app or as optional core modules. |

---

## 3. How the Generator Uses This Schema

1. **App bootstrap**: `app.name`, `app.bundleId`, `environment.*` → emitted as `--dart-define`/`.env` and `app_config.dart` defaults.
2. **Firebase wiring**: `firebase.projectId`, `appId`, `senderId`, `iosClientId`, and API keys → emitted into `firebase_options.dart` (replacing hardcoded constants in audit §1).
3. **Collection mapping**: `firebase.collections` → central repository constants so `collection('orders')` never appears as a literal in generated clients.
4. **Feature flags**: `features.flags` → generated default map for `feature_flags_service.dart`; runtime overrides still come from Firestore `settings/featureFlags`.
5. **Tax**: `tax.stateRates`, `tax.defaultRate`, `tax.source` → if `source: firestore`, the generator emits the Firestore seed document for `calculateTax`; if `hardcoded`, it emits the Cloud Function rate map.
6. **Theme**: `theme.*` → emitted as a local config file (JSON) consumed by `ThemeProvider`/`AppColors` after the refactor in §4.
7. **Navigation/screens**: `navigation.*`, `screens[]` → generated `app_router.dart` route table with only included screens; `hiddenRoutes` removed from tab/drawer surfacing; `entryPoint` set as initial location.
8. **New features**: `newFeatures[]` → per-client enable flag keys merged into the feature flag map; the client app may register custom modules for each.

---

## 4. Fields Requiring Code Changes to Become Runtime-Configurable

| Field(s) | Current state | Required change |
|----------|---------------|-----------------|
| `app.primaryColor`, `app.fontFamily`, `theme.*` | Compile-time constants in `AppColors`/`AppTheme` (audit §8: "Compile-time") | Refactor `AppColors`/`AppTheme` to load from a local config file (schema `theme.injection: local-config-file`) |
| `tax.stateRates`, `tax.defaultRate`, `tax.source` | Hardcoded in Cloud Function `calculateTax` (`functions/src/index.ts:37`); redeploy required (audit §3) | Move rates to Firestore (e.g. `settings/taxRates`); Cloud Function reads them; client stays fail-closed |
| `navigation.tabs`, `navigation.hiddenRoutes`, `screens[].mandatory` | Routes/screens wired at compile time in `app_router.dart` (audit §8: "Compile-time") | Generator emits the route table; app reads `navigation.entryPoint` and built tab list from schema |
| `firebase.androidAppId`, `iosAppId`, `messagingSenderId`, `iosClientId` | Hardcoded in `firebase_options.dart` (audit §1) | Generator writes `firebase_options.dart` from schema values |
| `features` flags | Fully runtime-configurable today via Firestore (audit §8: "Yes (runtime)") | No code change needed — schema only supplies defaults |
| `environment.*` | Already configurable via `--dart-define`/dotenv (audit §8: "Yes") | No code change needed |

---

## 5. Coverage Traceability (field → audit section)

| Schema domain | Audit section |
|---------------|---------------|
| `app` | §1 (`APP_NAME`, `APP_BUNDLE_ID`, store URLs, FCM), §5 (`AppColors.primary`, fonts) |
| `environment` | §1 (env table) |
| `firebase` | §1 (hardcoded IDs), §2 (collections, scoping, config docs) |
| `features` | §4 (7 flags, unknown→false) |
| `tax` | §3 (rates, fail-closed, server-side) |
| `theme` | §5 (colors, fonts, dark overrides, confetti, spacing) |
| `navigation` | §6 (29-route table) |
| `screens` | §7 (26 screens) |
| `newFeatures` | §4 (unknown-flag behaviour) + Phase 2.1 spec §2h |

---

## 6. Verifier Checklist Status

| # | Check | Result |
|---|-------|--------|
| 1 | Audit files read (`01_audit_read.txt`) | ✅ created from real audit files |
| 2 | Schema file exists | ✅ `client_config_template.json` |
| 3 | Schema is valid JSON | verified by `python -m json.tool` in Step 6 |
| 4 | All 8 domains present | ✅ `app`, `firebase`, `features`, `tax`, `theme`, `navigation`, `screens`, `newFeatures` |
| 5 | Documentation exists | ✅ this file |
| 6 | Each field has a source | ✅ §2 table maps every field to audit section + code location |