# 🛡️ CARNAMA MONOREPO — FULL PRE-WIRE AUDIT PROMPT

**Purpose:** Exhaustively audit every screen, service, provider, repository, and wiring point in the Carnama monorepo so that **nothing is broken, stubbed, hardcoded, or logically wrong** before the UI is wired in. This prompt is designed to be handed to an auditor agent (or run by you) in **batches** so every domain is uncovered in a few passes.

**Scope:** `packages/core`, `packages/core_ui`, `core_app`, `apps/*` (halal_boyz, sunset_grill, blue_ocean), `core_app/functions`, Firestore rules.

---

## 0. NON-NEGOTIABLE RULES (apply to EVERY file, EVERY batch)

The auditor MUST enforce all of these on every single file read. Any violation is a **finding** — no exceptions.

1. **NO HARDCODED VALUES — except documented offline fallbacks.** No hardcoded prices, names, colors, URLs, API keys, IDs, phone numbers, addresses, or business logic in UI or domain code. Everything user-facing must come from `AppConfig`, `CoreConfig`, Firestore, or a repository. Exception: genuinely static UI copy (labels) that is not business data.
   - **INTENTIONAL OFFLINE FALLBACKS ARE ALLOWED** (see §0.1). A hardcoded value is a **finding ONLY IF** it is (a) not marked as a fallback, (b) not gated behind real-then-fallback logic, (c) masquerading as live production data with no marker, OR (d) the fallback logic itself is broken.
2. **NO STUBS / PLACEHOLDERS — except deferred integrations.** No `TODO`, `FIXME`, `throw UnimplementedError()`, empty method bodies, `return null` where a value is expected, mock data masquerading as real, or `// placeholder` code. Every function must have a real implementation.
   - **DEFERRED INTEGRATIONS ARE ALLOWED BUT MUST BE EXPLICIT** (see §0.1). If a backend (Cloud Function, real Stripe, real payment) is not deployed yet, a **clearly-marked placeholder implementation is acceptable for now** — but it MUST be: (a) isolated behind an interface/branch so the real implementation drops in without UI changes, (b) tagged with a recognizable marker (e.g. `// OFFLINE_FALLBACK:`, `// TODO_DEPLOY:`, config flag `isDemoMode`), (c) listed in the Known Fallbacks Register in §0.2, and (d) verified to be logically perfect (correct types, no crashes, no fake success states passed off as real).
3. **NO AI SLOP / VIBECODE.** No dead code, unused imports, unused variables, copy-pasted blocks, duplicated logic that should be shared, inconsistent naming, magic numbers, or "works by accident" code. No code that looks plausible but is never called or cannot be reached.
4. **NO BUGS OF ANY KIND.** No null-pointer risks, no unhandled async errors, no race conditions, no off-by-one, no wrong currency/quantity math, no incorrect state transitions, no memory leaks (unclosed streams/controllers/subscriptions), no `BuildContext` used across async gaps without `mounted` checks.
5. **NO LOGIC ISSUES.** Every conditional, loop, switch, and provider must be traced end-to-end. Verify the happy path AND every error/empty/loading/offline path. Verify state actually flows from repository → provider → widget.
6. **EVERYTHING WIRED.** Every screen ID in the client config `screens` array must map to a real widget in `app_router.dart`. Every route in `_staticRoutes` must be reachable. Every provider must be registered/overridden where needed. Every repository must be injected. No orphaned files.
7. **MULTI-APP READINESS.** The code must work for ANY client config (halal_boyz, sunset_grill, blue_ocean, future apps). Nothing may be hardcoded to one restaurant. The `core` + `core_ui` packages must be the single source of truth; `core_app` is the reference implementation; `apps/*` are generated shells.
8. **NO ERRORS.** `flutter analyze` must be 0 issues (fatal-infos). `flutter test` must pass 100%. No runtime exceptions, no `print()` debug leftovers, no `debugPrint` in production paths.

---

## 0.1 OFFLINE FALLBACK & DEFERRED-INTEGRATION POLICY (READ FIRST)

**Context from the owner:** Some hardcoded values are **intentional offline fallbacks** — used only because the Cloud Functions and real Stripe payment are **not deployed yet**. Actual payment testing happens later. Right now the job is to **verify the code is perfect** (correct types, correct flow, no crashes, no fake success states passed off as real), and use a **clearly-marked placeholder** for now. We get it perfect later.

**Therefore, the auditor must classify every hardcoded value / placeholder into one of three buckets:**

| Bucket | Definition | Verdict |
|--------|-----------|---------|
| ✅ **ACCEPTABLE FALLBACK** | Hardcoded value used ONLY when the real backend is unavailable, AND it is (a) clearly marked with a recognizable tag, (b) gated behind real-then-fallback logic (try real → catch → fallback), (c) listed in the Known Fallbacks Register (§0.2), AND (d) logically perfect (correct types, no crash, no fake success passed off as real). | **NOT a finding.** Log it in the register. |
| 🟠 **UNMARKED / BROKEN FALLBACK** | A fallback exists but is (a) not marked, (b) not gated (always returns fake data even when backend is up), (c) crashes or returns wrong types, OR (d) presents fake success as real success (e.g. "Order placed!" when nothing happened). | **FINDING — MAJOR.** Must be marked + gated + registered. |
| 🔴 **FAKE DATA MASQUERADING AS REAL** | Hardcoded business data (dishes, prices, order lines, promos, analytics) shown to the user as if it were live production data, with no marker and no fallback intent. | **FINDING — CRITICAL.** Blocks UI wiring. |

**Required marker tags** (use one of these so the auditor can grep for them):
- `// OFFLINE_FALLBACK:` — a hardcoded value used when the backend is unreachable.
- `// TODO_DEPLOY:` — a placeholder for a backend that is not deployed yet (Cloud Function, real Stripe, real payment).
- `// DEMO_MODE:` — gated behind `kDemoMode` / `isDemoMode` config flag (must be false in release — see `_assertSafeBuildConfig`).

**The code logic around a fallback must still be PERFECT.** A fallback is not an excuse for a bug. The fallback path must: return the correct type, not throw, not leak, not double-write, and must clearly signal to the UI that it is a fallback (e.g. a `isFallback` flag or a distinct UI state) so the user is never silently told a fake action succeeded.

---

## 0.2 KNOWN FALLBACKS REGISTER (maintain this as you audit)

Every acceptable fallback/placeholder you find MUST be added to this register. This is the single source of truth for "what is intentionally not-yet-real" so it is never re-flagged and never accidentally shipped as real.

| # | File | Line | What it falls back to | Marker tag | Gated by | Real impl planned? | Verified logically perfect? |
|---|------|------|----------------------|-----------|----------|--------------------|-----------------------------|
| 1 | `core_app/lib/main.dart` | ~221 | Stripe publishable key from `String.fromEnvironment` (empty until real key) | `// TODO_DEPLOY:` | `assert` + `if (key.isNotEmpty)` | Yes — real Stripe later | Verify |
| 2 | `core_app/lib/features/admin/domain/cloud_function_mocks.dart` | — | Cloud Function responses | `// OFFLINE_FALLBACK:` | Must be test-only OR gated | Yes | Verify it never leaks to prod |
| 3 | `core_app/tool/whitelabel.dart` | ~741 | Generated app menu/cart/checkout hardcoded data | `// TODO_DEPLOY:` | Generated shells only | Yes — wire to real providers | Verify |
| 4 | `core_app/tool/whitelabel.dart` | ~645 | `ClientCoreConfig.kitchenLanEndpoint` hardcoded | `// OFFLINE_FALLBACK:` | Config override | Yes | Verify |
| 5 | `core_app/functions/src/index.ts` | — | Tax Cloud Function hardcoded rates | `// TODO_DEPLOY:` | Server-side | Yes — config-driven | Verify |
| 6 | *(add as found)* | | | | | | |

**Rule:** If a hardcoded value is NOT in this register, it is a finding. If it IS in the register but the code is broken, it is still a finding (the fallback logic itself must be perfect).

---

## 0.3 SELF-SUFFICIENCY / SUBOPTIMAL-SOLUTION AUDIT (the "why redeploy?" pass)

**Context from the owner:** The audit must also flag **suboptimal solutions**, not just bugs. The guiding question for every piece of configuration and every piece of data:

> **"Does this require a code rebuild / config-file redeploy to change, when it could be runtime-editable via Firestore?"**

The app is a **multi-app white-label platform**. A client (e.g. Halal Boyz) should be able to change their own business data **without** you rebuilding/redeploying the app. If a value is baked into `client_config.json` (or worse, into Dart code) but is **business data that the owner will want to change**, that is a **suboptimal solution** — flag it.

**The self-sufficiency test — for EVERY config value, ask:**
1. Is this a **build-time identity** value (bundle ID, Firebase project ID, app name, theme colors, Stripe publishable key, Cloudinary creds)? → **OK to be in config/env.** These are per-app build identity.
2. Is this **runtime business data** the owner will change (owner emails, menu items, prices, operating hours, tax rates, feature flags, promotions, branch info, admin accounts)? → **MUST be in Firestore**, read at runtime, editable via an admin screen. If it's in `client_config.json` or Dart code, **FLAG as suboptimal** — the owner shouldn't need a redeploy to change their menu or their own email.

**Known suboptimal patterns to hunt for (flag each with a suggested fix):**

| # | Suboptimal pattern | Why it's suboptimal | Better design |
|---|--------------------|--------------------|---------------|
| 1 | `ownerEmails` in `CoreConfig` / `client_config.json` | Owner can't change their own email without a redeploy | Read from Firestore `settings/ownerInfo` (config already references `configDocuments.ownerInfo`) — owner edits via admin screen |
| 2 | Menu items / prices hardcoded or seeded only via config | Owner can't update menu without redeploy | Menu lives in Firestore `menus` collection, editable via `AdminMenuManager` / `OwnerDashboard` |
| 3 | Admin accounts seeded only via `seed_admin.dart` at build | Can't add/remove staff without redeploy | Admin list in Firestore `admins` collection, managed via `ManagerDashboard` |
| 4 | Feature flags in `client_config.json` `features.flags` | Can't toggle features without redeploy | Read from Firestore `settings/featureFlags` (config already has `features.source: settings/featureFlags`) — editable via `TierFlagManagerScreen` |
| 5 | Tax rates hardcoded in Cloud Function | Can't change tax without redeploying functions | Read from Firestore `settings/restaurantConfig` (config has `tax.source: firestore`) |
| 6 | Operating hours in config | Can't change hours without redeploy | Read from Firestore `settings/defaultOperatingHours` + `branches/{id}/config/operatingHours` (config already references these) — editable via `OperatingHoursScreen` |
| 7 | Promotions / hero carousel hardcoded | Can't change promos without redeploy | Read from Firestore `promotions` collection — editable via admin |
| 8 | Branch / location info in config | Can't add a branch without redeploy | Read from Firestore `branches` / `locations` collections |
| 9 | Any screen content (titles, copy) that is business data baked into Dart | Can't change without redeploy | Move to Firestore or config-driven localization |

**How to report:** Add a **🟠 SUBOPTIMAL** severity tier to the findings format (§5). For each, state: (a) what requires a redeploy today, (b) why the owner would want to change it at runtime, (c) the Firestore collection/document it should read from instead, (d) the admin screen that should edit it.

**Important nuance:** This is NOT the same as the offline-fallback policy (§0.1). A value can be BOTH a marked fallback AND suboptimal. E.g. `ownerEmails` might have a config fallback for bootstrapping, but the **primary** source should be Firestore. The audit should flag the architecture, not just the fallback marker.

---

## 0.4 BETTER-SOLUTION / IMPROVEMENT-OPPORTUNITY AUDIT (the "could we do this better?" pass)

**Context from the owner:** Beyond bugs and redeploy-required values, the audit must also flag **any place where a better solution could be in place** — so the owner can review those opportunities and decide. This is a **catch-all** for anything that "feels off" or could be improved, even if it currently works.

**The auditor MUST flag (as 💡 IMPROVEMENT) any of the following, even if the current code is functionally correct:**

1. **Duplicated logic** — the same logic exists in 2+ places and should be extracted to a shared helper/service (e.g. price math, date formatting, validation, error handling). Violates DRY.
2. **Overly complex code** — a function/method that could be simpler, clearer, or more readable. Nested conditionals that could be early-returns, switch statements that could be maps, long methods that should be split.
3. **Inefficient data access** — N+1 Firestore reads, reading an entire collection when a query would do, fetching data that isn't used, missing pagination (`firestore_paginator.dart` exists — is it used where it should be?).
4. **Missing abstraction** — a hardcoded branch/switch on a value that should be an interface/strategy (e.g. payment method, delivery type, tax source) so new options drop in without editing the switch.
5. **Poor naming** — names that don't convey intent, misleading names, inconsistent naming conventions across the codebase.
6. **Missing error handling** — a path that could fail but isn't guarded, a `catch` that swallows the error silently, a missing retry where `network_retry.dart` should be used.
7. **Missing state handling** — a screen that doesn't distinguish loading/empty/error/offline when it should.
8. **Performance concerns** — rebuilds that could be avoided, missing `const`, heavy work on the UI thread, missing memoization, unnecessary `setState`.
9. **Security hardening** — a check done client-side that should also be server-side (Firestore rules / Cloud Function), a value exposed that shouldn't be, missing validation.
10. **Config/data that should be dynamic** — anything that is static but the owner would plausibly want to change (this overlaps §0.3 but is broader — e.g. a hardcoded copy string, a fixed list, a constant that varies per client).
11. **Dead / vestigial code** — code that is no longer used, commented-out blocks that should be deleted, deprecated markers that should be resolved.
12. **Anything that "feels off"** — if the auditor reads something and thinks "there's a better way to do this," it MUST be flagged. Do not suppress the instinct.

**How to report:** Add a **💡 IMPROVEMENT** severity tier to the findings format (§5). For each, state: (a) the file + line, (b) what the current code does, (c) why a better solution exists, (d) the suggested better approach. These are **non-blocking** — they don't stop UI wiring — but they are collected for the owner to review and decide.

**Important:** 💡 IMPROVEMENT is distinct from 🔴 CRITICAL / 🟠 MAJOR / 🟠 SUBOPTIMAL. If something is both broken AND improvable, report it under the higher severity (broken) AND note the improvement. If it works but could be better, report it as 💡 IMPROVEMENT only.

---

## 1. HOW TO READ FILES (methodology)

- **List ALL files** in the target directory recursively first (`list_files recursive:true`). Do not skip any file.
- **Read every file in totality** — do not truncate, do not skim. Use `read_file` with full ranges. For files >1000 lines, read in sequential chunks until the whole file is covered.
- For each file, trace **every function, method, getter, and provider** — verify it is called somewhere, verify its inputs/outputs, verify error handling.
- Cross-reference: when a file references another (import, provider, repository, route, model), open that referenced file and verify the contract matches (names, types, params, return types).
- **Do not trust tests as proof of correctness.** Tests can be weak, tautological, or test the wrong thing. Read the test too and judge whether it actually exercises the real behavior.
- Produce findings in the format in §4.

---

## 2. SCREEN-BY-SCREEN AUDIT CHECKLIST

For **every screen** below, verify ALL of the following (this is the universal screen checklist):

- [ ] Screen is registered in `app_router.dart` (both config-driven `_getScreenWidget` AND `_staticRoutes` where applicable).
- [ ] Screen ID in `client_config.json` `screens` array maps to the correct widget.
- [ ] Route path matches the config `navigation.routes` and `screens[].route`.
- [ ] All constructor params (e.g. `menuItemId`, `orderId`, `initialCategory`) are correctly passed from the router (path params, query params, `state.extra`).
- [ ] No hardcoded business data — all data comes from providers/repositories.
- [ ] Loading state, empty state, error state, and offline state are all handled (no infinite spinner, no blank screen, no crash on empty).
- [ ] Every button/action actually does something real (navigates, calls a service, updates state) — no dead buttons.
- [ ] Form validation is correct (email format, required fields, numeric ranges, no negative quantities).
- [ ] Async operations check `mounted` before using `context` after `await`.
- [ ] Streams/controllers/subscriptions are disposed in `dispose()`.
- [ ] Localization: user-facing strings go through `AppLocalizations` (or are config-driven), not hardcoded English literals (except where the app is English-only by design — flag it).
- [ ] Theme: uses `Theme.of(context)` / `AppConfig.theme`, not hardcoded colors.
- [ ] No `print()` / `debugPrint()` debug leftovers.
- [ ] No dead code, unused imports, unused variables.

### 2.1 Customer-Facing Screens

| # | Screen | File | Specific checks |
|---|--------|------|-----------------|
| 1 | SplashScreen | `core_app/lib/features/splash/presentation/splash_screen.dart` | Navigation logic after splash; auth state resolution; no infinite loop; respects `navigationEntryPoint` |
| 2 | OnboardingScreen | `core_app/lib/features/onboarding/presentation/onboarding_screen.dart` | Skip/next flow; persistence of "seen" flag; no hardcoded content |
| 3 | LoginScreen | `core_app/lib/features/auth/presentation/login_screen.dart` | Email/password validation; error display; loading state; navigation on success; signup link; password reset |
| 4 | SignupScreen | `core_app/lib/features/auth/presentation/signup_screen.dart` | **NOTE: router maps SignupScreen → LoginScreen.** Verify this is intentional and signup actually works, or flag as a stub. |
| 5 | HomeScreen | `core_app/lib/features/home/presentation/home_screen.dart` | Hero carousel; feature tiles; navigation to all tabs; config-driven content; `home_service.dart` |
| 6 | MenuScreen | `core_app/lib/features/menu/presentation/menu_screen.dart` | Category filter (`initialCategory`); grid/list; item tap → DishDetail with correct `MenuItemModel`; `menu_provider.dart`, `merged_menu_provider.dart`, `menu_repository.dart` |
| 7 | DishDetailScreen | `core_app/lib/features/menu/presentation/dish_detail_screen.dart` | Loads by `menuItemId`; modifiers (`menu_modifier_model.dart`); add-to-cart with correct price math incl. modifiers; image loading |
| 8 | CartScreen | `core_app/lib/features/cart/presentation/cart_screen.dart` | Quantity +/-; remove; subtotal math; promo code (`promo_service.dart`); navigation to checkout; `cart_provider.dart`, `cart_repository.dart`; `animated_cart_badge.dart` |
| 9 | CheckoutScreen | `core_app/lib/features/checkout/presentation/checkout_screen.dart` | Address; delivery/pickup; tip (`tip_selector_widget.dart`); promo (`promo_calculator.dart`, `promo_code_service.dart`); tax (`tax_service.dart`); payment via Stripe; order placement via `checkout_service.dart`; idempotency; failure handling |
| 10 | OrderTrackerScreen | `core_app/lib/features/orders/presentation/order_tracker_screen.dart` | Loads by `orderId`; status updates; `order_provider.dart`, `order_repository.dart` |
| 11 | OrderHistoryScreen | `core_app/lib/features/orders/presentation/order_history_screen.dart` | Lists past orders; empty state; reorder (`smartReorder` feature flag); navigation to tracker |
| 12 | DeliveryTrackerScreen | `core_app/lib/features/tracking/presentation/delivery_tracker_screen.dart` | Loads by `orderId`; live driver location (`driver_location_service.dart`); map; status |
| 13 | ReservationScreen | `core_app/lib/features/reservations/presentation/reservation_screen.dart` | Date/time/party size; availability; `reservations_repository.dart`; counter/lock logic; admin tab (`admin_reservations_tab.dart`) |
| 14 | LocationScreen | `core_app/lib/features/locations/presentation/location_screen.dart` | Branch list; `location_repository.dart`, `branch_service.dart`; map |
| 15 | PinDropMapScreen | `core_app/lib/features/location/presentation/pin_drop_map_screen.dart` | Map picker; `live_map_picker_widget.dart`; coordinate capture; delivery location model |
| 16 | WaitlistScreen | `core_app/lib/features/waitlist/presentation/waitlist_screen.dart` | Join/leave; position; `waitlist_repository.dart`; feature flag |
| 17 | LoyaltyScreen | `core_app/lib/features/loyalty/presentation/loyalty_screen.dart` | Points balance; rewards; `loyalty_provider.dart`; feature flag |
| 18 | ProfileScreen | `core_app/lib/features/profile/presentation/profile_screen.dart` | User info; edit; logout; links to orders, loyalty, reservations, delete account, terms, privacy |
| 19 | DeleteAccountScreen | `core_app/lib/features/compliance/presentation/delete_account_screen.dart` | GDPR Art.17 flow; confirmation; `data_export_service.dart`, `gdpr_service.dart` |
| 20 | TermsOfServiceScreen | `core_app/lib/features/auth/presentation/terms_of_service_screen.dart` | Reachable without login; content |
| 21 | PrivacyPolicyScreen | `core_app/lib/features/admin/presentation/privacy_policy_screen.dart` | Reachable without login; content |

### 2.2 Admin / Staff Screens

| # | Screen | File | Specific checks |
|---|--------|------|-----------------|
| 22 | RoleRouterScreen | `core_app/lib/features/admin/presentation/role_router_screen.dart` | Routes by role to correct dashboard; no client-side security bypass (rules enforce) |
| 23 | AdminGatewayScreen | `core_app/lib/features/admin/presentation/gateway/admin_gateway_screen.dart` | 20-tap hidden entry; PIN validation (`devAdminPin` from config); no hardcoded PIN |
| 24 | OwnerDashboard | `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart` | Menu item CRUD; image upload (`cloudinary_upload_service.dart`); `_uploadingImage` state; `_pickAndUploadImage`; no broken controller `.text` access |
| 25 | ManagerDashboard | `core_app/lib/features/admin/presentation/manager/manager_dashboard.dart` | Staff/orders management; `admin_data_service.dart` |
| 26 | KitchenDashboard | `core_app/lib/features/admin/presentation/kitchen/kitchen_dashboard.dart` | Order queue; status updates; `kitchen_service.dart`, `kitchen_task_dispatcher.dart`, `kitchen_offline_service.dart` |
| 27 | DeliveryDashboard | `core_app/lib/features/admin/presentation/delivery/delivery_dashboard.dart` | Assign drivers; `delivery_service.dart`, `fleet_dispatch_service.dart`; `driver_location_service.dart` |
| 28 | AnalyticsSnapshot | `core_app/lib/features/admin/presentation/analytics_snapshot.dart` | Revenue/top items charts (`revenue_chart_widget.dart`, `top_items_chart_widget.dart`); real data not mock |
| 29 | AdminMenuManager | `core_app/lib/features/admin/presentation/admin_menu_manager.dart` | Menu CRUD; categories; modifiers; pricing |
| 30 | TierFlagManagerScreen | `core_app/lib/features/admin/presentation/setup/tier_flag_manager_screen.dart` | Feature flag toggling; persists to Firestore |
| 31 | RestaurantSetupScreen | `core_app/lib/features/admin/presentation/setup/restaurant_setup_screen.dart` | Restaurant config; operating hours; branding |
| 32 | OperatingHoursScreen | `core_app/lib/features/admin/presentation/setup/operating_hours_screen.dart` | Hours editing; `operating_hours_model.dart` |
| 33 | LogsScreen | `packages/core_ui/lib/src/error_logger/logs_screen.dart` | Shows real logs; no crash on empty |

### 2.3 Shared / Overlay Widgets

| # | Widget | File | Specific checks |
|---|--------|------|-----------------|
| 34 | BrandDrawer | `core_app/lib/app/brand_drawer.dart` | Navigation items; config-driven branding; logout |
| 35 | AnimatedCartBadge | `core_app/lib/app/animated_cart_badge.dart` | Count reflects real cart; animation |
| 36 | HeroCarouselWidget | `core_app/lib/features/promotions/presentation/hero_carousel_widget.dart` | Promotions from `promotions_provider.dart`; no hardcoded promos |
| 37 | TourOverlay | `core_app/lib/features/tour/presentation/tour_overlay.dart` | Feature flag; onboarding tour; no hardcoded steps |
| 38 | BugReporterOverlay | `packages/core_ui/lib/src/error_logger/bug_reporter_overlay.dart` | Captures real errors; submits |
| 39 | GdprConsentDialog | `core_app/lib/app/compliance/gdpr_consent_dialog.dart` + `packages/core_ui/lib/src/compliance/gdpr_consent_dialog.dart` | Consent persistence; analytics gating |
| 40 | ForceUpdateGuard | `core_app/lib/app/config/force_update_guard.dart` + `packages/core_ui/lib/src/config/force_update_guard.dart` | Version check; no hardcoded version |
| 41 | EmptyStateWidget / GlobalErrorWidget / SkeletonLoader / ConfettiOverlay / BrandButton / Transitions | `packages/core_ui/lib/src/ui/*` | Real implementations; used correctly |

---

## 3. WIRING AUDIT (the "everything wired up" pass)

This is the most important section. Verify the ENTIRE dependency graph end-to-end.

### 3.1 App Bootstrap (`core_app/lib/main.dart`)
- [ ] `_assertSafeBuildConfig()` — demo mode forbidden in release.
- [ ] `dotenv.load()` — `.env` loaded before config.
- [ ] `AppConfig.loadConfig()` — reads `assets/client_config.json`, falls back to defaults.
- [ ] Logger initialized before Firebase.
- [ ] Firebase init with `_buildFirebaseOptions()` (config wins over defaults).
- [ ] Emulator wiring (`USE_EMULATORS`).
- [ ] App Check (native + web ReCaptcha).
- [ ] GDPR consent gates analytics.
- [ ] FCM init (fire-and-forget with error logging).
- [ ] Stripe key from `String.fromEnvironment` — **no hardcoded key**.
- [ ] Isar DB opened.
- [ ] Provider overrides: `loggerProvider`, `authRepositoryProvider` (with `onSignOutNavigated`), `deepLinkServiceProvider`.
- [ ] `ForceUpdateGuard` wraps `ProviderScope`.
- [ ] `CoreApp` — router, theme (dynamic, not hardcoded light), localization delegates, `BugReporterOverlay`.

### 3.2 Router (`core_app/lib/app/app_router.dart`)
- [ ] EVERY screen ID in `client_config.json` `screens` array has a case in `_getScreenWidget`. **Cross-check against `client_config_schema_20260814/halal_boyz_config.json` (26 screens) and `client_config_template.json`.**
- [ ] `SignupScreen` → `LoginScreen` mapping: verify signup is genuinely functional or flag as a stub.
- [ ] `_buildRoutesFromConfig()` — config-driven routes built correctly; empty config falls back to `_staticRoutes`.
- [ ] `redirect` logic: auth loading wait; public paths (login, signup, /, menu, cart, onboarding, locations, waitlist, privacy, terms, admin-gateway); logged-in redirect away from login/signup/onboarding; splash self-navigates.
- [ ] `errorBuilder` — graceful, no crash.
- [ ] `initialLocation` = `AppConfig.navigationEntryPoint`.
- [ ] Every `_staticRoutes` route has a matching `RouteNames` constant in `route_names.dart`.
- [ ] Path params (`:id`, `:orderId`) and query params (`category`) correctly extracted and passed.

### 3.3 Config Layer (`core_app/lib/app/config/`)
- [ ] `app_config.dart` — reads all config sections; no hardcoded fallbacks that mask missing config.
- [ ] `env.dart` — env var access; no hardcoded secrets.
- [ ] `demo_config.dart` — demo mode flag; must be false in release.
- [ ] `theme_config_provider.dart` — theme from config.
- [ ] `force_update_guard.dart` — version logic.
- [ ] `restaurant_config_model.dart` — model matches Firestore `settings/restaurantConfig`.

### 3.4 Core Package Exports (`packages/core/lib/core.dart`)
- [ ] Every public class/service is exported.
- [ ] No export of internal/private files.
- [ ] `CoreConfig` interface (`core_config.dart`) — all getters implemented by `ClientCoreConfig` in generated apps AND by `core_app`'s config.

### 3.5 Core_UI Exports (`packages/core_ui/lib/core_ui.dart`)
- [ ] All shared widgets exported.
- [ ] `main.dart` hides `GdprConsentDialog` and `ForceUpdateGuard` from core_ui and uses its own — verify no conflict.

### 3.6 Provider / Repository Wiring (per feature)
For each feature, trace: **Repository (data) → Provider (state) → Screen (UI)**. Verify:
- [ ] Repository reads/writes the correct Firestore collection (from config `firebase.collections`).
- [ ] Provider watches the repository and exposes loading/error/data states.
- [ ] Screen consumes the provider and handles all states.
- [ ] No provider is created but never used; no repository is instantiated but never injected.
- [ ] Offline: `sync_queue.dart`, `pending_sync_provider.dart`, `isar_service.dart` actually persist and replay offline mutations.

### 3.7 Deep Links & Notifications
- [ ] `deep_link_service.dart` — `navigationHandler` wired in `main.dart`; routes resolve.
- [ ] `fcm_service.dart` / `push_notification_service.dart` — background handler registered; notification tap navigates to correct screen.

---

## 4. OPTIMAL BATCHING PLAN (uncover every domain in a few passes)

Run these batches **in order**. Each batch is self-contained and produces a findings report. Do NOT proceed to the next batch until the current one is clean (or findings are logged and fixed). This ordering prioritizes the shared foundation first so downstream batches don't re-report the same root cause.

### 🅰️ BATCH 0 — FOUNDATION & WIRING (do FIRST — everything depends on this)
**Goal:** Prove the app boots, routes resolve, config flows, and nothing is orphaned.
**Files:**
- `core_app/lib/main.dart`
- `core_app/lib/app/app_router.dart`
- `core_app/lib/app/navigation/route_names.dart`
- `core_app/lib/app/config/*` (app_config, env, demo_config, theme_config_provider, force_update_guard)
- `core_app/lib/app/models/restaurant_config_model.dart`
- `core_app/lib/firebase_options.dart`
- `core_app/lib/app/compliance/data_export_service.dart`
- `packages/core/lib/core.dart`, `packages/core_ui/lib/core_ui.dart`
- `packages/core/lib/src/config/core_config.dart`
- `client_config_schema_20260814/client_config_template.json`, `halal_boyz_config.json`
- `core_app/lib/app/brand_drawer.dart`, `core_app/lib/app/animated_cart_badge.dart`
- `core_app/lib/app/compliance/gdpr_consent_dialog.dart`
- `core_app/lib/app/config/force_update_guard.dart`
- `core_app/lib/services/notification_service.dart`
- `core_app/lib/l10n/*` (app_en.arb, app_ar.arb, app_localizations*.dart)

**Deliverable:** A route-map table: every config screen ID → widget → route → reachable? → params correct? → auth required? Also: every provider override verified; every config value traced to its consumer.

### 🅱️ BATCH 1 — AUTH & ONBOARDING DOMAIN
**Goal:** Login/signup/onboarding/splash + GDPR + terms/privacy all work, no stubs.
**Files:**
- `core_app/lib/features/auth/presentation/login_screen.dart`, `signup_screen.dart`, `terms_of_service_screen.dart`
- `core_app/lib/features/onboarding/presentation/onboarding_screen.dart`
- `core_app/lib/features/splash/presentation/splash_screen.dart`
- `core_app/lib/features/compliance/presentation/delete_account_screen.dart`
- `packages/core/lib/src/auth/*` (auth_provider, auth_repository, user_model)
- `packages/core/lib/src/compliance/gdpr_service.dart`
- `packages/core/lib/src/admin/seed_admin.dart`, `admin_access_service.dart`
- `packages/core/lib/src/schemas/user_schema.dart`
- Tests: `core_app/test/features/auth/presentation/login_screen_test.dart`, `onboarding_screen_test.dart`, `splash_screen_test.dart`, `core/compliance/delete_account_screen_test.dart`, `core/auth/auth_repository_test.dart`, `wiring/v15_phase2_auth_audit_test.dart`, `core/admin_access_test.dart`

**Key question:** Is signup REAL or a stub mapping to Login? Is the admin gateway PIN config-driven? Is GDPR consent persisted and honored?

### 🅲 BATCH 2 — MENU & CART DOMAIN
**Goal:** Browse menu, dish detail with modifiers, cart math — all correct, no hardcoded dishes.
**Files:**
- `core_app/lib/features/menu/presentation/menu_screen.dart`, `dish_detail_screen.dart`
- `core_app/lib/features/menu/presentation/menu_provider.dart`, `merged_menu_provider.dart`
- `core_app/lib/features/menu/data/menu_repository.dart`
- `core_app/lib/features/menu/domain/menu_item_model.dart`, `menu_modifier_model.dart`
- `core_app/lib/features/cart/presentation/cart_screen.dart`, `cart_provider.dart`
- `core_app/lib/features/cart/data/cart_repository.dart`
- `core_app/lib/features/cart/domain/promo_service.dart`
- `core_app/lib/app/animated_cart_badge.dart`
- `packages/core/lib/src/models/*` (delivery_location_model, operating_hours_model, promotion_model, geo_point_converter, num_to_int_converter)
- Tests: `menu_screen_test.dart`, `dish_detail_screen_test.dart`, `cart_repository_test.dart`, `promo_service_test.dart`, `models_shaping_test.dart`, `model_roundtrip_test.dart`

**Key question:** Does add-to-cart correctly sum base price + modifiers? Does the cart persist offline? Is the menu truly from Firestore (no hardcoded `_dishes` list like the generator template)?

### 🅳 BATCH 3 — CHECKOUT & ORDERS DOMAIN (highest risk — money)
**Goal:** Checkout math, payment, order placement, tracking — zero tolerance for bugs.
**Files:**
- `core_app/lib/features/checkout/presentation/checkout_screen.dart`, `tip_selector_widget.dart`
- `core_app/lib/features/checkout/domain/checkout_service.dart`, `promo_calculator.dart`, `promo_code_service.dart`
- `core_app/lib/features/orders/presentation/order_provider.dart`, `order_history_screen.dart`, `order_tracker_screen.dart`
- `core_app/lib/features/orders/data/order_repository.dart`
- `core_app/lib/features/orders/domain/order_model.dart`, `order_number_service.dart`, `order_payload_adapter.dart`, `kitchen_task_dispatcher.dart`
- `core_app/lib/features/tracking/presentation/delivery_tracker_screen.dart`
- `core_app/lib/features/tracking/data/driver_location_service.dart`
- `packages/core/lib/src/tax/tax_service.dart`
- `packages/core/lib/src/payment/fraud_screening_service.dart`, `nfc_terminal_service.dart`
- `packages/core/lib/src/kitchen/kitchen_offline_service.dart`, `order_payload.dart`
- Tests: `checkout_service_test.dart`, `chaos_checkout_test.dart`, `tip_selector_widget_test.dart`, `order_tracker_screen_test.dart`, `order_history_screen_test.dart`, `delivery_tracker_screen_test.dart`, `fraud_screening_service_test.dart`, `tax_service_test.dart`, `idempotency_test.dart`, `kitchen_offline_service_test.dart`

**Key question:** Is the total = subtotal + modifiers + tax + tip + delivery − promo correct in EVERY combination? Is order placement idempotent (no double-charge)? Is the kitchen task dispatched correctly? **Payment (Stripe) is a DEFERRED integration per §0.1 — right now verify the code path is PERFECT around the placeholder**: the Stripe init fails gracefully when the key is empty (no crash), the checkout flow correctly handles the not-yet-configured payment state, no fake "payment successful" is passed off as real, and the real Stripe implementation can drop in behind the same interface without UI changes. Actual payment testing happens later.

### 🅴 BATCH 4 — HOME, PROMOTIONS, LOYALTY, RESERVATIONS, WAITLIST, LOCATIONS DOMAIN
**Goal:** All secondary customer features work with real data.
**Files:**
- `core_app/lib/features/home/presentation/home_screen.dart`, `home/domain/home_service.dart`
- `core_app/lib/features/promotions/data/promotions_provider.dart`, `presentation/hero_carousel_widget.dart`
- `core_app/lib/features/loyalty/presentation/loyalty_screen.dart`, `loyalty_provider.dart`
- `core_app/lib/features/reservations/presentation/reservation_screen.dart`, `admin_reservations_tab.dart`, `data/reservations_repository.dart`
- `core_app/lib/features/waitlist/presentation/waitlist_screen.dart`, `data/waitlist_repository.dart`
- `core_app/lib/features/locations/presentation/location_screen.dart`, `data/location_repository.dart`
- `core_app/lib/features/location/presentation/pin_drop_map_screen.dart`
- `packages/core/lib/src/location/branch_service.dart`
- `packages/core/lib/src/presence/presence_service.dart`, `presence_model.dart`
- Tests: `home_service_test.dart`, `reservation_screen_test.dart`, `reservations_repository_test.dart`, `waitlist_repository_test.dart`, `location_screen_test.dart`, `pin_drop_map_screen_test.dart`, `delivery_location_model_test.dart`

**Key question:** Are reservations atomic (counter + lock, no double-booking)? Is waitlist position real? Are promotions from Firestore (no hardcoded carousel)? Is presence tracking real?

### 🅵 BATCH 5 — ADMIN DOMAIN (owner/manager/kitchen/delivery/setup)
**Goal:** All admin dashboards functional, no broken controllers, no mock data.
**Files:**
- `core_app/lib/features/admin/presentation/role_router_screen.dart`, `gateway/admin_gateway_screen.dart`
- `core_app/lib/features/admin/presentation/owner/owner_dashboard.dart`
- `core_app/lib/features/admin/presentation/manager/manager_dashboard.dart`
- `core_app/lib/features/admin/presentation/kitchen/kitchen_dashboard.dart`
- `core_app/lib/features/admin/presentation/delivery/delivery_dashboard.dart`
- `core_app/lib/features/admin/presentation/analytics_snapshot.dart`, `analytics/revenue_chart_widget.dart`, `analytics/top_items_chart_widget.dart`
- `core_app/lib/features/admin/presentation/admin_menu_manager.dart`
- `core_app/lib/features/admin/presentation/setup/tier_flag_manager_screen.dart`, `restaurant_setup_screen.dart`, `operating_hours_screen.dart`
- `core_app/lib/features/admin/domain/admin_data_service.dart`, `delivery_service.dart`, `kitchen_service.dart`, `fleet_dispatch_service.dart`, `cloud_function_mocks.dart`, `menu_item_model.dart`
- Tests: `owner_dashboard_test.dart`, `manager_dashboard_test.dart`, `kitchen_dashboard_test.dart`, `delivery_dashboard_test.dart`, `role_router_screen_test.dart`, `admin_gateway_test.dart`, `admin_menu_manager_test.dart`, `tier_flag_manager_screen_test.dart`, `admin_data_service_test.dart`

**Key question:** Is `cloud_function_mocks.dart` used ONLY in tests, or does production code call mocks? (Mocks in production = AI slop **UNLESS** they are clearly-marked `// OFFLINE_FALLBACK:` placeholders registered in §0.2, gated, and logically perfect.) Is the owner dashboard image upload real? Is the admin gateway PIN config-driven? Is `fleet_dispatch_service.dart` / `delivery_service.dart` wired to a real Firestore path or a fallback (and if a fallback, is it marked + gated + registered)?

### 🅶 BATCH 6 — PROFILE, TOUR, DRIVER, COMPLIANCE DOMAIN
**Goal:** Remaining customer + driver features.
**Files:**
- `core_app/lib/features/profile/presentation/profile_screen.dart`
- `core_app/lib/features/tour/presentation/tour_overlay.dart`
- `core_app/lib/features/driver/proof_of_delivery_service.dart`
- `core_app/lib/app/compliance/data_export_service.dart`
- `packages/core/lib/src/compliance/gdpr_service.dart`
- Tests: `tour_overlay_test.dart`, `delete_account_screen_test.dart`

### 🅷 BATCH 7 — CORE PACKAGE (shared services — the multi-app engine)
**Goal:** Every service in `packages/core` is real, correct, and reusable across apps.
**Files (ALL of `packages/core/lib/src/`):**
- `auth/*`, `cache/*` (isar_schemas, isar_service), `network/*` (firestore_client, sync_queue, pending_sync_provider, push_notification_service, chaos_firestore, http_interceptor, network_retry), `error_logger/*` (error_logger_service, logger_service, crash_reporter, firebase_exception_mapper, logger_provider), `analytics/*` (analytics_service, telemetry_service), `payment/*` (fraud_screening_service, nfc_terminal_service), `presence/*`, `tax/tax_service.dart`, `notifications/fcm_service.dart`, `navigation/deep_link_service.dart`, `compliance/gdpr_service.dart`, `kitchen/*`, `admin/*`, `location/branch_service.dart`, `models/*`, `utils/*` (firestore_paginator, json_converters), `services/cloudinary_upload_service.dart`, `providers/firestore_provider.dart`
- Tests: ALL of `packages/core/test/` + `core_app/test/core/**`

**Key question:** Is `chaos_firestore.dart` a test-only chaos injection or does it leak into production? Is the sync queue correct (no data loss, no duplicate writes)? Is Isar schema in sync with models? Is telemetry GDPR-compliant?

### 🅸 BATCH 8 — CORE_UI PACKAGE (shared widgets)
**Goal:** Every shared widget is real, themed, and reusable.
**Files (ALL of `packages/core_ui/lib/src/`):**
- `theme/*` (app_colors, app_dimensions, app_theme, theme_provider)
- `ui/*` (brand_button, confetti_overlay, empty_state_widget, global_error_widget, skeleton_loader, transitions)
- `error_logger/*` (bug_reporter_overlay, logs_screen)
- `compliance/gdpr_consent_dialog.dart`, `config/force_update_guard.dart`, `widgets/live_map_picker_widget.dart`
- Tests: `packages/core_ui/test/**`

### 🅹 BATCH 9 — WHITELABEL GENERATOR & GENERATED APPS
**Goal:** The multi-app factory produces working, non-hardcoded apps.
**Files:**
- `core_app/tool/whitelabel.dart` (the generator)
- `apps/halal_boyz/**` (lib/main.dart, lib/app/*, lib/features/*, assets/client_config.json, pubspec.yaml)
- `apps/sunset_grill/**`, `apps/blue_ocean/**`
- `client_config_schema_20260814/client_config_template.json`
- Tests: `apps/*/test/widget_test.dart`, `apps/sunset_grill/integration_test/app_launch_test.dart`

**Key question:** The generator templates (`_menuScreenTemplate`, `_cartScreenTemplate`, `_checkoutScreenTemplate`) contain **HARDCODED dishes, prices, and order lines** (`_Dish('Margherita Pizza', 9.99, ...)`, `_OrderLine('Subtotal', 24.98)`). Per §0.1, this is only **ACCEPTABLE** as a clearly-marked `// TODO_DEPLOY:` placeholder for the generated-shell apps BEFORE they are wired to real providers — BUT it must be listed in the §0.2 register and must NOT be presented to a real end user as live data. If it lacks the marker, is in `core_app` itself, or is passed off as real, it is a **CRITICAL finding**. Also verify `ClientCoreConfig.kitchenLanEndpoint` is marked `// OFFLINE_FALLBACK:` and config-overridable (not silent).

### 🅺 BATCH 10 — BACKEND & RULES
**Goal:** Firestore rules, indexes, and cloud functions match the client's expectations.
**Files:**
- `core_app/functions/src/index.ts`
- `core_app/firestore.rules`, `core_app/staging.firestore.rules`, `core_app/storage.rules`
- `core_app/firestore.indexes.json`
- `core_app/cloud_functions_spec.md`
- `core_app/test/rules/firestore_rules_test.js`
- `core_app/docs/firestore_rules_audit_20260820.md`, `firestore_rules_fix_plan_20260820.md`

**Key question:** Do the rules enforce the `clientScopingFields` (branchId, customerId, userId, assignedDriverId) from the config? Is the tax Cloud Function using hardcoded rates a **marked `// TODO_DEPLOY:`** placeholder? Per §0.1: if it's a `//*` marked placeholder awaiting config-driven deployment, it is acceptable; if it's silently hardcoded with no marker and no plan, it's a finding. Verify the client `tax_service.dart` picks up config `tax.defaultRate` / `stateRates` correctly (the multi-app concern is that a hardcoded server rate breaks OTHER apps — so the client must read its OWN config). Do indexes cover all queries?

### 🅻 BATCH 11 — FULL VERIFICATION (final gate)
**Goal:** Prove the whole monorepo is green.
**Commands (run from repo root):**
```bash
# Analyze every package with fatal-infos
flutter analyze --fatal-infos
cd packages/core && flutter analyze --fatal-infos
cd packages/core_ui && flutter analyze --fatal-infos
cd core_app && flutter analyze --fatal-infos
cd apps/halal_boyz && flutter analyze --fatal-infos
cd apps/sunset_grill && flutter analyze --fatal-infos
cd apps/blue_ocean && flutter analyze --fatal-infos

# Test every package
flutter test
cd packages/core && flutter test
cd packages/core_ui && flutter test
cd core_app && flutter test
cd apps/halal_boyz && flutter test
cd apps/sunset_grill && flutter test
cd apps/blue_ocean && flutter test
```
- [ ] 0 analyzer issues everywhere.
- [ ] 100% tests passing everywhere.
- [ ] No `print()`/`debugPrint()` in `lib/` (only in `tool/` and tests).
- [ ] No `TODO`/`FIXME`/`UnimplementedError` in `lib/` or `packages/*/lib/`.
- [ ] No hardcoded business data anywhere in `lib/` or `packages/*/lib/`.

---

## 5. FINDINGS REPORT FORMAT

For every batch, produce a findings report (append to `AUDIT_REPORT.md` or a new `BATCH_N_FINDINGS.md`):

```markdown
## Batch N — <Domain> Findings

### 🔴 CRITICAL (blocks UI wiring)
| File | Line | Issue | Rule violated | Fix |
|------|------|-------|---------------|-----|

### 🟠 MAJOR (bug / logic error)
| File | Line | Issue | Rule violated | Fix |
|------|------|-------|---------------|-----|

### 🟠 SUBOPTIMAL (requires redeploy when it should be runtime-editable — see §0.3)
| File | Line | What needs a redeploy today | Why owner wants runtime control | Firestore source it should read | Admin screen that should edit it |
|------|------|------------------------------|-------------------------------|-------------------------------|--------------------------------|

### 💡 IMPROVEMENT (a better solution exists — see §0.4, non-blocking, for owner review)
| File | Line | What the code does today | Why a better solution exists | Suggested better approach |
|------|------|--------------------------|------------------------------|---------------------------|

### 🟡 MINOR (lint / dead code / style)
| File | Line | Issue | Rule violated | Fix |
|------|------|-------|---------------|-----|

### ✅ VERIFIED CLEAN
- [ ] Screen X — all checks passed
- [ ] Service Y — all checks passed
```

**Severity definitions:**
- 🔴 **CRITICAL** — app crashes, data loss, security hole, money bug, hardcoded business data, stub/mock in production, broken wiring (screen unreachable / provider not injected).
- 🟠 **MAJOR** — logic error on an edge path, unhandled error, race condition, incorrect state, offline sync bug, wrong math on a non-primary path.
- 🟠 **SUBOPTIMAL** — a value that requires a code rebuild / config-file redeploy to change, when it is runtime business data the owner will want to change (owner emails, menu, prices, hours, tax, feature flags, promos, branches, admin accounts). Per §0.3, these should read from Firestore and be editable via an admin screen.
- 💡 **IMPROVEMENT** — the code works but a better solution exists (duplicated logic, over-complex code, inefficient data access, missing abstraction, poor naming, missing error/state handling, performance, security hardening, static data that should be dynamic, dead code, or anything that "feels off"). Per §0.4. **Non-blocking** — collected for the owner to review and decide.
- 🟡 **MINOR** — dead code, unused import, lint, naming, magic number, missing localization.

---

## 6. FINAL DELIVERABLE

After all batches pass, produce a documentation containing:
1. A route-map table (every screen → widget → route → status).
2. A provider/repository wiring matrix (every provider → repository → collection → status).
3. A list of every finding fixed (with file + line).
4. A statement: **"No hardcoded business data, no stubs, no AI slop, no bugs, no logic errors, no broken wiring. All screens verified. Multi-app ready."** — OR a list of what still blocks that statement.

---
at the end of each batch , we look at potato.md as the final deliverable , each batch will be an addendum to that file with documentation of what was found

IF YOU FIX ANYTHING YOU MUST RESEARCH AND PROVE THAT THE FIX YOU DID WAS THE BEST POSSIBLE FIX FOR THE PROBLEM

*End of audit prompt. Run batches 0→11 in order. Do not skip Batch 0.*