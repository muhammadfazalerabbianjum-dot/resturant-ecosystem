# Batch 8 — Core_UI Package Findings (2026-08-22)

**Scope:** ALL of `packages/core_ui/lib/src/` — theme/*, ui/*, error_logger/*, compliance/gdpr_consent_dialog.dart, config/force_update_guard.dart, widgets/live_map_picker_widget.dart; all `packages/core_ui/test/**`; cross-verified consumers in `core_app`.

## 🔴 CRITICAL (blocks UI wiring) — FIXED

| File | Issue | Rule violated | Fix |
|---|---|---|---|
| `packages/core_ui/lib/src/widgets/live_map_picker_widget.dart` | Hardcoded Karachi center `LatLng(24.8607, 67.0011)` + `userAgentPackageName: 'com.carnama.labs'` baked into a shared widget (multi-app leak) | §0.1 no hardcoded business data / Law 3 | Added injectable `initialCenter` + `userAgentPackageName` (defaults: neutral `(0,0)` + `'flutter_map'`). Host injects `AppConfig.bundleId` + Firestore `locations` coords. |
| `core_app/lib/features/location/presentation/pin_drop_map_screen.dart` | Mirror hardcoded Karachi + `com.carnama.app` UA | §0.1 / multi-app | Map center from Firestore `locations` first doc (runtime-editable) + neutral fallback; UA from `AppConfig.bundleId`. |
| `core_app/lib/features/checkout/presentation/checkout_screen.dart` | `_openMapPicker()` had no center/UA (Karachi + hardcoded UA on money path) | §0.1 / multi-app | `LiveMapPickerWidget` now gets `initialCenter: _mapInitialCenter()` (from `locationsProvider`) + `userAgentPackageName: AppConfig.bundleId`. |

## 🟠 MAJOR (bug / logic error) — FIXED

| File | Issue | Rule violated | Fix |
|---|---|---|---|
| `packages/core_ui/lib/src/widgets/live_map_picker_widget.dart` | Redundant `Geolocator.checkPermission()` pre-check hung the platform channel in widget tests (Confirm never enabled) | §0.4 testability | Removed pre-check; `getCurrentPosition` already throws on denial; catch-all falls back to seeded/neutral pin. |
| `core_app/lib/features/locations/data/location_repository.dart` | `locationsProvider` + `locationRepositoryProvider` were declared in `location_screen.dart` but consumed from `checkout_screen.dart` + `pin_drop_map_screen.dart` → `undefined name` analyzer errors | §3.6 repository → provider (single source of truth) | Moved both providers into `location_repository.dart` (data layer). All 3 consumers import from repo. |

## 🟠 SUBOPTIMAL (requires redeploy when it should be runtime-editable — §0.3)

| File | What needs a redeploy today | Why owner wants runtime control | Firestore source | Admin screen |
|---|---|---|---|---|
| map center (live_map_picker / pin_drop_map / checkout) | Map center hardcoded to Karachi | Every client restaurant is in a different city | `locations` / `branches` collection (`lat`/`lng`) | RestaurantSetupScreen / OwnerDashboard |

## 💡 IMPROVEMENT (non-blocking — §0.4)

| File | What the code does today | Why a better solution exists | Suggested better approach |
|---|---|---|---|
| `confetti_overlay.dart` | **FIXED** — now accepts `colors` param | Config-driven path wired in `core_app` | Also let admins pick celebration colors per client in `RestaurantSetupScreen` |
| `app_colors.dart` | Static `softShadow`/`activeShadow` | Hardcoded shadows could be per-theme | Drive from `ColorScheme` |
| `global_error_widget.dart` | Static 'Our team has been notified' | Not L10n-driven | Pass localised copy |
| `bug_reporter_overlay.dart` | FAB always visible | Reveals internal logs to end users in prod | Gate behind `kDebugMode` |
| `app_theme.dart` | `_colorFromConfig` only parses `0x`/bare hex | Missing `#RRGGBB` support | Accept optional leading `#` |

## 🟡 MINOR

| File | Issue |
|---|---|
| `live_map_picker_widget.dart` | Business label strings hardcoded English (widget-test strings) — host should be able to inject copy |

## ✅ VERIFIED CLEAN

- `packages/core_ui analyze --fatal-infos` → **0 issues**
- `packages/core_ui flutter test` → **12/12 passed**
- `core_app analyze --fatal-infos` → **0 issues**
- `core_app` map/location tests → **15/15 passed**

## Known Fallbacks Register (Batch 8 additions)

| File | What it falls back to | Gated by | Verified perfect? |
|---|---|---|---|
| `live_map_picker_widget.dart` | Neutral `(0,0)` center | `initialCenter == null` | ✅ |
| `live_map_picker_widget.dart` | `'flutter_map'` UA | `userAgentPackageName == null` | ✅ |
| `app_config.dart` | multi-brand confetti palette | config `theme.confettiOverlay.colors` | ✅ |

## Files Modified

1. `packages/core_ui/lib/src/widgets/live_map_picker_widget.dart` — injectable center/UA, mounted guards, removed redundant permission pre-check, neutral fallbacks
2. `packages/core_ui/lib/src/ui/confetti_overlay.dart` — injected `colors` param
3. `packages/core_ui/pubspec.yaml` — removed unused `share_plus` + `mocktail`
4. `core_app/lib/features/locations/data/location_repository.dart` — providers consolidated
5. `core_app/lib/features/locations/presentation/location_screen.dart` — imports from repo
6. `core_app/lib/features/location/presentation/pin_drop_map_screen.dart` — Firestore center + `AppConfig.bundleId` UA
7. `core_app/lib/features/checkout/presentation/checkout_screen.dart` — `_mapInitialCenter()` + `AppConfig.bundleId` UA + `AppConfig.confettiColors`
8. `core_app/lib/app/config/app_config.dart` — `confettiColors` getter + hex parser
9. `core_app/test/core/widgets/live_map_picker_widget_test.dart` — updated to new API + `pump()`-not-settle + flush timer

## Remaining blockers (from Batch 7 — wire-or-delete, not Batch 8 UI scope)

`FirestorePaginator`, `presence_service`, `adminAccessProvider`, `PushNotificationService`, `TelemetryService`, `NfcTerminalService`, `deadLetterCountProvider`, `promotions_provider`/`hero_carousel_widget`, admin dead screens, `seedInitialAdmin`, `data_export_service`, `tour_overlay`, `proof_of_delivery_service` — still unwired. Resolve before Batch 11 verification.