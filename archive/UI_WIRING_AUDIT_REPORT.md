# Carnama Labs — UI Wiring & Button Completeness Audit Report

**Audit date:** 2026-08-31 · **Static source-level audit** · **No code changes applied** (report-only)
**Jury:** `UI_WIRING_VERIFICATION_PROMPT.md` (2026-08-30)

---

## 0. VERDICT — ❌ FAIL

**P0 — every named-route navigation in the app is dead at runtime.** Config-driven routing is ACTIVE
(`client_config.json` has a non-empty `screens` array → `app_router.dart:167` selects config routes),
but config routes register under **screen-ID names** (`'LoginScreen'`, `'HomeScreen'`, …) while every
`goNamed()`/`pushNamed()` call references `RouteNames.*` **short names** (`'login'`, `'home'`, …).
go_router 14.8.1 resolves named routes by exact name (`configuration.dart:266-267` = `_nameToPath[name]!`),
so any unknown name crashes at runtime (AssertionError in debug / `Null check operator` TypeError in
release). **35 named-navigation call sites are dead**, breaking the drawer, cart badge,
splash→onboarding, login↔signup, checkout→order-tracker, profile→sub-screens, home→dish-detail, and
the whole admin-gateway→role-router chain.

Every claim below cites `file:line` of the current source. No sampling.

---

## 1. ACTIVE MODE DETERMINATION (spec §0.1 — done FIRST)

| Fact | Evidence | Conclusion |
|---|---|---|
| Config file has non-empty `screens` | `assets/client_config.json:186-213` (26 entries) | config mode candidate |
| Config loaded **before** `runApp()` | `main.dart:150` → `main.dart:251` | `AppConfig.screens` populated before router build |
| Router selects config routes when non-empty | `app_router.dart:166-167` `configRoutes.isNotEmpty ? configRoutes : _staticRoutes` | **config mode ACTIVE** |
| Config routes are named by screen **id** | `app_router.dart:144-150` `name: id` | names = `'SplashScreen'`, `'LoginScreen'`, … |
| Navigation uses `RouteNames.*` short names | `route_names.dart:1-31` + 35 call sites (§3) | **name mismatch → P0** |

### 1.1 ACTIVE route table — 26 routes (authoritative source: `client_config.json` `screens`)

| # | Route `name:` (screen id) | path | Widget |
|---|---|---|---|
| 1 | `SplashScreen` | `/splash` | SplashScreen |
| 2 | `OnboardingScreen` | `/onboarding` | OnboardingScreen |
| 3 | `LoginScreen` | `/login` | LoginScreen |
| 4 | `SignupScreen` | `/signup` | SignupScreen ✅ |
| 5 | `HomeScreen` | `/` | HomeScreen |
| 6 | `MenuScreen` | `/menu` | MenuScreen(initialCategory) |
| 7 | `DishDetailScreen` | `/dish/:id` | DishDetailScreen(menuItemId) |
| 8 | `CartScreen` | `/cart` | CartScreen |
| 9 | `CheckoutScreen` | `/checkout` | CheckoutScreen |
| 10 | `OrderTrackerScreen` | `/orders/:orderId` | OrderTrackerScreen(orderId) |
| 11 | `OrderHistoryScreen` | `/orders` | OrderHistoryScreen |
| 12 | `ReservationScreen` | `/reservations` | ReservationScreen |
| 13 | `LocationScreen` | `/locations` | LocationScreen |
| 14 | `PinDropMapScreen` | `/location/map` | PinDropMapScreen |
| 15 | `WaitlistScreen` | `/waitlist` | WaitlistScreen |
| 16 | `LoyaltyScreen` | `/loyalty` | LoyaltyScreen |
| 17 | `ProfileScreen` | `/profile` | ProfileScreen |
| 18 | `DeliveryTrackerScreen` | `/tracking/:orderId` | DeliveryTrackerScreen(orderId) |
| 19 | `DeleteAccountScreen` | `/delete-account` | DeleteAccountScreen |
| 20 | `TermsOfServiceScreen` | `/terms` | TermsOfServiceScreen |
| 21 | `PrivacyPolicyScreen` | `/privacy` | PrivacyPolicyScreen |
| 22 | `RoleRouterScreen` | `/role-router` | RoleRouterScreen |
| 23 | `AdminGatewayScreen` | `/admin-gateway` | AdminGatewayScreen |
| 24 | `TierFlagManagerScreen` | `/admin/setup/tier-flags` | TierFlagManagerScreen |
| 25 | `RestaurantSetupScreen` | `/admin/setup/restaurant` | RestaurantSetupScreen |
| 26 | `OperatingHoursScreen` | `/admin/setup/hours` | OperatingHoursScreen |

Widget mapping for all 26: `app_router.dart:47-131` (exhaustive switch; `default` safety net at
124-130 renders a `'No widget mapped for $screenId'` Scaffold — reachable only for unknown IDs).

**NOT registered in config mode** (static-only): `/admin`, `/admin/menu`, `/owner`, `/manager`,
`/kitchen`, `/delivery`, `/logs`, `/error-logs`. Verified: **no in-app code navigates to those names**
(see §3 full list), but the deep-link validator advertises them as valid (§3.2) → deep-link crash.

**Spec-delta:** the spec's "Role" column (§1.1) does not exist in the JSON — role gating is done in
`app_router.dart:176-215` redirect + screen logic. Documented, not a defect.

### 1.2 go_router 14.8.1 name resolution proof (why this crashes, not "falls back")

- `configuration.dart:266` `assert(_nameToPath.containsKey(name), 'unknown route name: $name')` → debug AssertionError
- `configuration.dart:267` `final String path = _nameToPath[name]!;` → release `TypeError` when absent
- `router.dart:334-338` `goNamed`/`pushNamed` resolve via `namedLocation(name)` FIRST; **no path fallback**.

Registered names = 26 screen IDs. Used names = `RouteNames.*` short names. **Intersection = ∅.**
All 35 named call sites fail at runtime in config mode.
---

## 2. FAILURE REGISTER (P0 / P1 / P2, each with evidence)

### P0-1 Named-route table mismatch (catastrophic navigation)
- Evidence: §1 table + §3 complete call-site inventory.
- Fix required (recommended, NOT applied per report-only instruction): make config-route `name`s equal
  to the `RouteNames.X` values that code navigates with, OR navigate config mode with `RouteNames`
  names. Options: (a) in `client_config.json` add a `name` field per screen = `RouteNames.*` value and
  have `_buildRoutesFromConfig` use it with fallback to id; (b) keep id-named routes but change every
  call site to path navigation (`context.push(path)`) against `AppConfig.navigationRoutes`. Option (a)
  is the minimal, non-breaking fix consistent with the existing `RouteNames`-based call sites.

### P0-2 Deep-link handler uses `Navigator.pushNamed` with a **path**
- `main.dart:266-272`: `navigationHandler: (path) async { await navigatorKey.currentState?.pushNamed(path); }`
- `deep_link_service.dart:140` calls that handler with `uri.path` (e.g. `/orders/ORD-123`).
- `Navigator.pushNamed` resolves against the Navigator's **route-name table**, not go_router's path
  matcher. With go_router, `navigatorKey` is the GoRouter navigator; `pushNamed('/orders/ORD-123')`
  throws "unknown route name" (or no-op). Result: **all supported deep links fail**, including
  `/menu`, `/dish/:id`, `/orders/:orderId`, `/tracking/:orderId`, `/reservations`, `/profile`.
- Fix: use `go_router`'s `context.push(path)` / `GoRouter.of(context).go(path)` semantics (path-based)
  rather than `Navigator.pushNamed`; or look up `AppConfig.navigationRoutes[name]` then `push(path)`.
- Test gap: `test/core/router/deeplink_test.dart` uses a hand-built test router (`/garbage/path` →
  404) — it does **not** exercise the real `main.dart` handler nor config-mode routes.

### P0-3 Error-widget "Restart" button uses `Navigator.pushReplacementNamed('/')`
- `main.dart:107-111` inside `ErrorWidget.builder`. Same root cause as P0-2: `pushReplacementNamed`
  is a MaterialApp-routes-table API; go_router-based app has no such table → dead/broken restart.

### P1-1 MenuScreen has NO dish-detail navigation
- `menu_screen.dart:162-250`: the only `ListTile` has trailing add-to-cart `IconButton` but **no `onTap`**,
  and the file contains no `pushNamed`/`goNamed`. The spec's own inventory (spec §6) requires
  "MenuScreen (…, dish detail nav)". **Missing interactive element → FAIL.**

### P1-2 LocationScreen cannot select a branch (dead finder)
- `location_screen.dart:35-42`: branch `ListTile`s have **no `onTap`** — a plain read-only list.
- `merged_menu_provider.dart:78-81` defines `setBranch()` but **no caller exists** in `lib/`
  (grep: `\.setBranch\(` → 0 results). Users land on `/locations` (via home `app_router`-style
  navigation) but cannot switch the operating branch. **Missing interactive element → FAIL.**

### P1-3 Admin chain is unreachable/broken in config mode
- `admin_gateway_screen.dart:80` → `goNamed(RouteNames.roleRouter)` — `'roleRouter'` vs registered
  `'RoleRouterScreen'` → crash (P0-1). Owner/Manager/Kitchen/Delivery dashboards are rendered inside
  RoleRouterScreen (`role_router_screen.dart:72-78`) — so the whole admin surface is gated behind a
  crashing route.

### P2-1 Orphaned screen classes in config mode (unreachable, non-fatal)
- `AdminMenuManager` (static `/admin/menu`) — not in `screens`; no caller.
- `AnalyticsSnapshot` (static `/admin`) — not in `screens`, but embedded as an Owner tab
  (`owner_dashboard.dart:55`) so it is reachable in-app.
- `AdminDashboard` (`admin_dashboard.dart`) — static-only, no caller; dead page.
- `LogsScreen` (`packages/core_ui/.../logs_screen.dart`) — static `/logs`,`/error-logs` only.
- `PinDropMapScreen` (`/location/map`) — registered but **no in-app navigation targets it**
  (`pin_drop_map_screen.dart` is only referenced by app_router). Reachable only by path/deep-link.

### P2-2 Spec§Proposed 20-tap admin gateway does not exist in code
`app_router.dart:444-450` comment says "20-tap PIN entry", but `admin_gateway_screen.dart` implements
role-based access (server-enforced via Firestore rules, see class doc at 9-13). No 20-tap logic, no
PIN input. `AppConfig.devAdminPin` (`app_config.dart:64,116,221-222`) is parsed but **never used**.
This is a spec-vs-code discrepancy: the code's role-gate is the better design; the 20-tap doc comment
is stale (also `role_router_screen.dart` already enforces role).

### P2-3 Uncommitted/working-tree state
- Latest commit `f9b42b4` "before first demo app". Working tree already contains partial fixes:
  `app_router.dart` now maps `SignupScreen` correctly (`_getScreenWidget` 55-56 + static 242-245),
  `client_config.json` entryPoint changed `/home`→`/` (line 141). These do NOT resolve P0-1.
---

## 3. EXHAUSTIVE INTERACTIVE-ELEMENT AUDIT — PER SCREEN (spec §2STEP2)

Legend: ✅ WORKING · ⛔ DEAD (empty/TODO/no-op handler) · ⚠️ ORPHANED (route doesn't exist) ·
🔒 DISABLED-documented · 🔲 No-op-await-without-mount (runtime hazard).

### 3.1 SplashScreen — `splash_screen.dart`
- ⏳ init `_startInit` (56-91): awaits `splashInitProvider.future` (18-33: AppConfig + first auth).
  Retry `ElevatedButton` (104) `onPressed: _startInit` ✅; `mounted` guarded (76, 83) ✅.
- Navigation: `context.goNamed(RouteNames.onboarding)` (78) → **⚠️ ORPHANED** (name `'onboarding'` not registered; registered `'OnboardingScreen'`).
- `context.go(AppConfig.navigationEntryPoint)` (80) → ✅ path-based (`/`). **Core boot works only because it uses path, not name.**

### 3.2 OnboardingScreen — `onboarding_screen.dart`
- "Get Started" `ElevatedButton` (64) → `_getStarted` (20-31): writes `onboarding_completed` then
  `goNamed(RouteNames.home)` (27) / `goNamed(RouteNames.login)` (29) → **⚠️ ORPHANED** both names.
### 3.3 LoginScreen - `login_screen.dart`
- Email `TextFormField` (147-158) validator requires `@` (155) [OK]; Password (165-176) min 6 (173) [OK].
- Forgot password `TextButton` (183-190) -> `_forgotPassword` (48-76): validates email -> sendPasswordResetEmail -> snackbar + unawaited log; disabled while `_loading` (184) [OK].
- Submit `ElevatedButton` (205-231) -> `_signIn` (30-46): validate -> sign-in -> maps FirebaseException; `mounted` guarded (42,44) [OK]; spinner + disabled (206,215-223) [OK].
- Guest `OutlinedButton` (274-291): `signInAnonymously`, guarded (284,290) [OK].
- Apple `SignInWithAppleButton` (261-267) + duplicate Apple `OutlinedButton` (351-369) - **two Apple buttons** (minor UX duplication; both real handlers).
- Google `OutlinedButton` (319-342) -> `_signInWithGoogle` (78-92) [OK].
- Signup nav (386) -> `goNamed(RouteNames.signup)` -> **[DEAD] P0-1 name mismatch**.
- Privacy (408) `context.push('/privacy')` -> [OK] path (#21); Terms (426) `push('/terms')` -> [OK] path (#20).
- `Color(0xFF4285F4)` Google brand literal (332) - documented brand exception.

### 3.4 SignupScreen - `signup_screen.dart`
- Name/Email/Password validators (100,127,145) [OK]; Submit (155-181) -> `_signUp` (25-64): guarded (40,46,62), logs + sanitized mapping (48-60), spinner+disabled (156,165-173) [OK].
- "Already have an account" nav (189-190) `goNamed(RouteNames.login)` -> **[DEAD] P0-1**.

### 3.5 HomeScreen (5 tabs) - `home_screen.dart`
- `NavigationBar` destinations (74-136) `onDestinationSelected` -> `setState` (78) [OK].
- `PopScope` (41-52): `canPop:false`; exit snackbar (48-50) [OK] defined.
- Tab0 `_HomeFeedTab`: hero `PageView` auto-advance (165-175) [OK]; category `FilterChip`s (269-313) [OK]; refresh empty (341-343 -> `ref.invalidate(mergedMenuProvider)`) [OK]; dish `InkWell.onTap` (360-364) -> `pushNamed(RouteNames.dishDetail, ...extra:item)` -> **[DEAD] P0-1**; add-to-cart (443-467) [OK]; `_promotionsFailed` error UI (226-232) [OK].
- Tab1 `_SearchTab`: query field (690); dish `onTap` (740-744) -> **[DEAD] P0-1**; row money `(item.priceCents / 100).toStringAsFixed(2)` + `currencySymbolFor` (777) - **manual money rendering** (spec Sec7.2, see Sec6).
- `PendingSyncBanner` retry (581-591) -> `IsarService().syncPendingOperations()` + invalidate [OK]; inline `IsarService()` (minor DI deviation).

### 3.6 BrandDrawer - `brand_drawer.dart`
- Home (54-57), Menu (62-65), Cart (70-73), Orders (78-81), Reservations (86-89), Locations (95-98), Profile (103-106) -> all `goNamed/pushNamed(RouteNames.X)` -> **[DEAD] P0-1**.
- Sign Out (112-117): `signOut()` then `goNamed(RouteNames.login)` -> **[DEAD] P0-1**; `mounted` guard (115) [OK].

### 3.7 AnimatedCartBadge - `animated_cart_badge.dart`

### 3.8 MenuScreen - `menu_screen.dart`
- Search `TextField` (59-71) -> `setState(_query)` [OK]; hint loc.searchMenu.
- Category `ActionChip`s All/Popular/Vegan + initialCategory (87-140): `onPressed` -> setState [OK].
- `ListTile` (170-242): **NO `onTap` to dish detail** -> **[FAIL] missing dish-detail nav (P1-1)**. Only trailing add-to-cart `IconButton` (220-238): disabled when sold out (isSoldOut -> null -> visually `Icons.remove_shopping_cart` grey, 214-219) [OK-documented]; else `cartProvider.notifier.addItem` + snackbar [OK].
- Price `'\$${(item.priceCents / 100).toStringAsFixed(2)}'` (196) and semantics label (168) - **hardcoded `$` + manual money rendering deviation** (spec Sec7.2).

### 3.9 CartScreen - `cart_screen.dart`
- Retry-sync `IconButton` (58-67) -> snackbar + `ref.invalidate(pendingSyncCountProvider)` [OK].
- Cart row `Dismissible` (104-122) `onDismissed` -> `removeItem(item.id, selectedOptions)` [OK].
- Decrease `IconButton` (154-159) -> removeItem [OK]; Increase (172-175) -> addItem [OK].
- Checkout `BrandButton` (229-232) -> `_proceedToCheckout` (31-34) -> `pushNamed(RouteNames.checkout)` -> **[DEAD] P0-1**.
- Empty-state CTA (85-91) `pushNamed(RouteNames.menu)` -> **[DEAD] P0-1**.
- `cart_provider.dart` addItem caps at 10 qty / 50 items with exceptions (51-63) [OK]; cart auto-cleared on sign-out (cart_provider.dart:123-127) [OK].

### 3.10 DishDetailScreen - `dish_detail_screen.dart`
- Modifier radios (RadioGroup 184-204) -> setState [OK]; total recomputed (76-80) [OK].
- Add to cart `ElevatedButton.icon` (149-154): disabled when sold out ([OK] documented, grey/disabled), else `_addToCart` (33-59) guarded + logged + snackbar [OK].
- Item-not-found path returns `itemNotFound` text (66-71) - no crash [OK].

### 3.11 CheckoutScreen - `checkout_screen.dart`
- Location picker `GestureDetector` (520-579) -> `_openMapPicker` (81-...): `showModalBottomSheet` -> `LiveMapPickerWidget(onLocationPicked)` -> setState [OK].
- Promo field + `ElevatedButton` Apply (594-621) -> `_applyPromo` (104-138): validates via service, mounted-guarded, sets discount [OK]; `_promoApplying` spinner (135-137) [OK].
- `TipSelectorWidget` (752-758) -> onTipChanged -> setState `_tipCents` [OK].
- Place Order `BrandButton` (763-767) -> `_processPayment` (140-467): fraud screen, panic switch, cart validate, location check, tax fail-closed, min-total, idempotency key, Stripe, createOrder, offline queue, notification, confetti, `mounted` guards throughout [OK]. Success nav (450-457) `goNamed(RouteNames.orderTracker, pathParameters:{'orderId':...})` -> **[DEAD] P0-1** (order succeeds server-side but user is NOT navigated; only snackbar/confetti shown).
- Restorable state (54-71), input sanitizer `< >` (596-600) [OK].

### 3.12 OrderHistoryScreen - `order_history_screen.dart`
- Empty CTA (43) `goNamed(RouteNames.menu)` -> **[DEAD] P0-1**.
- Order `ListTile.onTap` (60-63) `goNamed(RouteNames.orderTracker, pathParameters:{'orderId'})` -> **[DEAD] P0-1**.

### 3.13 OrderTrackerScreen - `order_tracker_screen.dart`
- Read-only stream display (order/status steps via `OrderTrackerStepsWidget`). No interactive buttons [N/A]; navigation to this screen is pushed by others (dead, P0-1).

### 3.14 ProfileScreen - `profile_screen.dart`
- Sign-out `IconButton` (25-35) -> `authRepository.signOut()` + `goNamed(RouteNames.login)` -> sign-out action [OK] but nav **[DEAD] P0-1**.
- `_MenuItem` order history (57) `pushNamed(RouteNames.orders)` **[DEAD]**; loyalty (66) `pushNamed(RouteNames.loyalty)` **[DEAD]**; reservations (75) **[DEAD]**; export data (89-113, guarded + localized) [OK]; delete account (123) `pushNamed(RouteNames.deleteAccount)` **[DEAD]**.
### 3.15 LoyaltyScreen - `loyalty_screen.dart`
- Read-only view (tier/points). No buttons. `user==null` shows locale string (18-23) [OK; unreachable in config mode without P0-1 fix].

### 3.16 WaitlistScreen - `waitlist_screen.dart`
- Party size minus (129-133, disabled at 1) / plus (139-143, disabled at 12) [OK].
- Join `ElevatedButton` (152-155) -> `_join` (25-77): guarded `_joining`, branch resolution, repository join result switched to localized messages, mounted-guarded [OK].

### 3.17 LocationScreen - `location_screen.dart`
- Branch `ListTile`s (35-42) have **NO `onTap`** -> **[FAIL] branch selection missing (P1-2)**.

### 3.18 PinDropMapScreen - `pin_drop_map_screen.dart`
- Map tap (92) -> setState `_picked` [OK]; my-location `ElevatedButton` (120-130) `_pickCurrentLocation` (43-57) - guarded + logged; confirm (123-129) `context.pop(DeliveryLocationModel)` [OK]. Not navigated to by any in-app code (P2-1 note).

### 3.19 ReservationScreen - `reservation_screen.dart`
- Time picker `OutlinedButton` (280-288) -> `_pickTime` (192-229): `showDatePicker`+`showTimePicker`, past-time guard [OK].
- Submit (290-299) -> `_submit` (125-190): validate form, past-time guard, branch fail-closed, capacity resolution, repository requestSlot, localized messages, `mounted` guards, spinner [OK].

### 3.20 DeliveryTrackerScreen - `delivery_tracker_screen.dart`
- Contact driver `ElevatedButton` (122-126) -> `_contactDriver` (21-39): reads contactPhone from config, tel: launch, guarded [OK].
- Reorder `OutlinedButton` (132-136) -> `_reorder` (41-50): re-add items to cart then `goNamed(RouteNames.cart)` -> **[DEAD] P0-1**.

### 3.21 AdminGatewayScreen - `admin_gateway_screen.dart`
- No 20-tap/PIN UI in code (P2-2). For admin role -> postFrame `goNamed(RouteNames.roleRouter)` (79-81) -> **[DEAD] P0-1**. Non-admin "Back to Home" (101-103) `goNamed(RouteNames.home)` -> **[DEAD] P0-1**. Unauthenticated -> `goNamed(RouteNames.login)` (37) -> **[DEAD] P0-1**.

### 3.22 RoleRouterScreen - `role_router_screen.dart`
- Null user -> postFrame `goNamed(RouteNames.login)` (21) [DEAD-P0-1]; error/null-data -> `goNamed(RouteNames.home)` (45,60) [DEAD-P0-1]; role switch (72-78) renders dashboards [OK], but router reachable only via dead goNamed (P1-3).
- Customer no-permission -> snackbar + `goNamed(RouteNames.home)` (98) [DEAD-P0-1].

### 3.23 OwnerDashboard (9 tabs) - `owner_dashboard.dart`
- Tabs `NavigationBar` (67-147) `onDestinationSelected` -> setState [OK].
- _OwnerOrdersTab: Load more `TextButton` (263) `_loadMore` (224-239) paginated [OK].
- _OwnerUsersTab: role `DropdownButton` (455-472) `_updateRole` (319-334) mounted-guarded [OK]; assign-branch `ElevatedButton` (389-397) -> `updateUserBranch` then setState - **missing `mounted` guard after await** (390-397) -> [RISK] setState-after-dispose (spec Sec7.6).
- _OwnerBranchesTab: add (495-497) / edit (525-527) / delete (529-531) -> sheet + `_deleteBranch` (552-564, soft-delete, result-checked) [OK]. _BranchEditor `_save` (605-628): guarded, saveBranch, mounted-pop [OK] - no field validators (blank coords -> 0 GeoPoint) [minor].
- _OwnerMenuTab: add (730-737) / availability Switch (767-769) / edit (771-778) / delete (780-783) [OK]. _MenuItemEditor `_save` (854-880) guarded [OK]; image picker (932-945, `_pickAndUploadImage` 832-852 guarded+logged) [OK] - no field validators (blank price -> $0) [minor].
- _PanicSwitchBanner Switch (999-1004) -> `setOrdersAccepting` [OK].

### 3.24 KitchenDashboard - `kitchen_dashboard.dart`
- TabBar Preparing/Ready (110-118) [OK]. Start preparing (216-225) and mark ready (231-243) -> `_updateStatus` (275-291) -> service + error snackbar [OK].

### 3.25 DeliveryDashboard - `delivery_dashboard.dart`
- TabBar My/Available (113-118) [OK]. Mark delivered (306-313) -> `_markDelivered` (141-191): proof-of-delivery dialog (161-165), stops GPS, guarded, logged [OK]. Navigate (283-303) launchUrl maps [OK]. Assign-to-me (427,467) -> `_assignToMe` (370-390) guarded+logged [OK].

### 3.26 ManagerDashboard - `manager_dashboard.dart`
- Read-only branch order list, no buttons [N/A].

### 3.27 AnalyticsSnapshot - `analytics_snapshot.dart`
- Read-only stats/charts [N/A]. `formatAmount` + `restaurantConfig` currency [OK]. Charts `Color(0x...)` (top_items_chart_widget.dart:80-83) - spec 7 color deviation [minor].

### 3.28 AdminMenuManager - `admin_menu_manager.dart`
- Read-only list [N/A]; orphaned in config mode (P2-1).

### 3.29 TierFlagManagerScreen - `tier_flag_manager_screen.dart`
- `SwitchListTile`s (56-62) local setState [OK]; Save (64-73) -> `_save` (81-104) persisted, guarded, logged [OK]. Hard-coded 'Feature flags saved'/'Save failed: $e' (93,99) - **l10n deviation** (Sec6).

### 3.30 RestaurantSetupScreen - `restaurant_setup_screen.dart`
- 6-tab `TabBar` (274-284) [OK]; Save (249-250) -> `_save` (133-208): validate, build model, repository save, guarded, spinner [OK].
- Only restaurant-name has a validator ('Required' 336-339); numeric/legal fields use `int.tryParse`/empty defaults (161-166) - **no validation on delivery/loyalty/social numeric fields** [minor] (spec Sec6).
- Hard-coded English throughout (277-282 tab labels, 196 'Settings saved successfully', 203 'Failed to save: $e', 257 'Save', 336 'Restaurant Name *', 339 'Required') - **l10n deviation** (Sec6).

### 3.31 OperatingHoursScreen - `operating_hours_screen.dart`
- Day Switch (186-189) [OK]; open/close `TextButton` (193-204) -> `_pickTime` (109-137) [OK]; Save (218-220) -> `_save` (74-103) guarded+logged [OK]. No in-app nav target (P2-1).

### 3.32 DeleteAccountScreen - `delete_account_screen.dart`
- Delete `ElevatedButton` (80-99): disabled + spinner while deleting (81,85-92) [OK]; `_deleteAccount` (17-47): GDPR service, mounted-guarded, failure localized + logged [OK]; success `context.go('/login')` (28) [OK path-based].

### 3.33 TermsOfServiceScreen / PrivacyPolicyScreen
- terms_of_service_screen.dart: view terms (82-85) -> `_openTerms` (10-45) url_launch + guard + snackbar [OK]; Back (92-94) `Navigator.pop` [OK].
- privacy_policy_screen.dart: same pattern (82-85, 10-45) [OK].

---

## 4. COMPLETE NAMED-NAVIGATION INVENTORY (spec Sec3 / Sec1.2) - disposition vs ACTIVE route table

Path-based calls that RESOLVE in config mode are marked [OK]; named calls fail (P0-1).

| # | file:line | call | target name | registered? |
|---|---|---|---|---|
| 1 | main.dart:269 | `navigatorKey.currentState?.pushNamed(path)` (deep link) | path | **[DEAD] P0-2** |
| 2 | main.dart:107-110 | `pushReplacementNamed('/')` (ErrorWidget Restart) | path | **[DEAD] P0-3** |
| 3 | animated_cart_badge.dart:27 | pushNamed(cart) | 'cart' | no |
| 4 | brand_drawer.dart:56 | goNamed(home) | 'home' | no |
| 5 | brand_drawer.dart:64 | pushNamed(menu) | 'menu' | no |
| 6 | brand_drawer.dart:72 | pushNamed(cart) | 'cart' | no |
| 7 | brand_drawer.dart:80 | pushNamed(orders) | 'orders' | no |
| 8 | brand_drawer.dart:88 | pushNamed(reservations) | 'reservations' | no |
| 9 | brand_drawer.dart:97 | pushNamed(locations) | 'locations' | no |
| 10 | brand_drawer.dart:105 | pushNamed(profile) | 'profile' | no |
| 11 | brand_drawer.dart:115 | goNamed(login) | 'login' | no |
| 12 | role_router_screen.dart:21 | goNamed(login) | 'login' | no |
| 13 | role_router_screen.dart:45 | goNamed(home) | 'home' | no |
| 14 | role_router_screen.dart:60 | goNamed(home) | 'home' | no |
| 15 | role_router_screen.dart:98 | goNamed(home) | 'home' | no |
| 16 | admin_gateway_screen.dart:37 | goNamed(login) | 'login' | no |
| 17 | admin_gateway_screen.dart:80 | goNamed(roleRouter) | 'roleRouter' | no |
| 18 | admin_gateway_screen.dart:102 | goNamed(home) | 'home' | no |
| 19 | login_screen.dart:386 | goNamed(signup) | 'signup' | no |
| 20 | login_screen.dart:408 | push('/privacy') | path | **[OK]** |
| 21 | login_screen.dart:426 | push('/terms') | path | **[OK]** |
| 22 | signup_screen.dart:190 | goNamed(login) | 'login' | no |
| 23 | cart_screen.dart:33 | pushNamed(checkout) | 'checkout' | no |
| 24 | cart_screen.dart:90 | pushNamed(menu) | 'menu' | no |
| 25 | checkout_screen.dart:452 | goNamed(orderTracker, '{orderId}') | 'orderTracker' | no |
| 26 | delete_account_screen.dart:28 | go('/login') | path | **[OK]** |
| 27 | home_screen.dart:61 | pushNamed(locations) | 'locations' | no |
| 28 | home_screen.dart:360 | pushNamed(dishDetail, '{id}', extra) | 'dishDetail' | no |
| 29 | home_screen.dart:740 | pushNamed(dishDetail, '{id}', extra) | 'dishDetail' | no |
| 30 | onboarding_screen.dart:27 | goNamed(home) | 'home' | no |
| 31 | onboarding_screen.dart:29 | goNamed(login) | 'login' | no |
| 32 | order_history_screen.dart:43 | goNamed(menu) | 'menu' | no |
| 33 | order_history_screen.dart:60 | goNamed(orderTracker, '{orderId}') | 'orderTracker' | no |
| 34 | profile_screen.dart:32 | goNamed(login) | 'login' | no |
| 35 | profile_screen.dart:57 | pushNamed(orders) | 'orders' | no |
| 36 | profile_screen.dart:66 | pushNamed(loyalty) | 'loyalty' | no |
| 37 | profile_screen.dart:75 | pushNamed(reservations) | 'reservations' | no |
| 38 | profile_screen.dart:123 | pushNamed(deleteAccount) | 'deleteAccount' | no |
| 39 | splash_screen.dart:78 | goNamed(onboarding) | 'onboarding' | no |
| 40 | splash_screen.dart:80 | go(navigationEntryPoint='/') | path | **[OK]** |
| 41 | delivery_tracker_screen.dart:49 | goNamed(cart) | 'cart' | no |

---

## 5. ASYNC HANDLER AUDIT (spec Sec4) - summary of every async button

| Screen.handler | loading state | error handling | double-submit guard | mounted-guard |
|---|---|---|---|---|
| splash `_startInit` 56-91 | yes (spinner in build) | yes + retry UI | n/a | yes (76,83) |
| onboarding `_getStarted` 20-31 | n/a (fast) | n/a | n/a | yes (24) |
| login `_signIn` 30-46 | yes (206) | yes (42) | `_loading` | yes |
| login `_forgotPassword` 48-76 | disabled while loading | yes (64-74) | n/a | yes (59,65) |
| login google/apple/guest | yes (320,352,275) | yes | flags | yes |
| signup `_signUp` 25-64 | yes (156) | yes (44-59) | `_loading` | yes |
| waitlist `_join` 25-77 | yes (153) | yes (60-69) | `_joining` (26) | yes |
| reservation `_submit` 125-190 | yes (291-297) | yes (180-186) | `_submitting` | yes |
| delete_account `_deleteAccount` 17-47 | yes (81-92) | yes (34-43) | `_isDeleting` | yes |
| checkout `_applyPromo` 104-138 | yes | yes (result) | n/a | yes (117) |
| checkout `_processPayment` 140-467 | yes (BrandButton) | yes (460-464) | `_isProcessing` (142,272) | yes (throughout) |
| cart add/remove (list) | n/a sync-ish | exceptions logged | n/a | not needed |
| dish_detail `_addToCart` 33-59 | n/a | yes (44-57) | n/a | yes (40,45) |
| delivery_tracker `_contactDriver` 21-39 | n/a | yes (28-33) | n/a | yes (29) |
| delivery_tracker `_reorder` 41-50 | n/a | potential partial add (no guard) | n/a | yes (48) |
| profile signout 27-35 | n/a | repository throws defer | n/a | yes (32) |
| profile export 89-113 | n/a | yes (97-112) | n/a | yes (92,103) |
| owner `_loadMore` 224-239 | yes (261-262) | none (throws unhandled) | `_loading` | yes (229) |
| owner `_updateRole` 319-334 | n/a | none (throws unhandled) | n/a | yes (321) |
| owner assign-branch sheet 390-397 | n/a | none | n/a | **NO (setState after await)** |
| owner branch/menu editors `_save` | yes | none (throws) | `_saving` | yes |
| owner `_deleteBranch` 552-564 | n/a | none (throws) | n/a | yes (556) |
| kitchen `_updateStatus` 275-291 | no (button not disabled while in flight) | yes (285-289) | no | yes (285) |
| delivery `_assignToMe` 370-390 | no | yes | no | yes (374) |
| delivery `_markDelivered` 141-191 | no | yes (181-189) | no (dialog barrier prevents) | yes (184) |
| tier flags `_save` 81-104 | yes | yes | `_saving` | yes |
| restaurant setup `_save` 133-208 | yes | yes | `_isSaving` | yes |
| operating hours `_save` 74-103 | yes | yes | `_saving` | yes |
| pending sync retry 581-591 | no | n/a | n/a | not needed |

Notable: kitchen/delivery buttons lack an in-flight loading guard (double-tap risk); owner
assign-branch save `setState` after await is unguarded (spec Sec7.6 violation). All else conforms.

---

## 6. CROSS-SCREEN CONSISTENCY (spec Sec7)

| Dimension | Canonical | Deviations | Status |
|---|---|---|---|
| Loading-state naming | `_loading`/`_isLoading` | `_loading` (login 25, signup 23, owner orders 214, users 293, hours 20); `_isSaving` (restaurant_setup 68); `_promotionsLoading` (home 154); `_submitting` (reservation 106); `_joining` (waitlist 17); `_isProcessing` (checkout 38); `_isDeleting` (delete 15); `_saving` (branch/menu editors, tier 25, hours 21) | [minor] mixed naming |
| Money fields (integer cents, *Cents) | `*Cents` integer | hand-written double money: **0 searched**; manual `(priceCents / 100).toStringAsFixed(2)` + hardcoded `$` in menu_screen (168,196); manual `currencySymbolFor` in home_screen (437,777); other screens use `moneyCents`/`formatCurrencyCents`/`formatAmount` uniformly | [minor] menu/home deviate |
| DI | `*Provider` from Riverpod; no `FirebaseAuth.instance`/`FirebaseFirestore.instance` in features | 0 direct instances in features; `IsarService()` inline in pending-sync retry (home 582); `FirebaseAuth.instance` only main overrides + data_export fallback (documented) | [OK] |
| Localization | `AppLocalizations` / `loc.*` | hard-coded English strings in feature files: role_router 42,56,96; admin_gateway 30,64,96,103; owner no-branches 347; tier_flags 93,99; restaurant_setup 196,203,257,277-282,336,339 + all tab labels; cart tooltip 52; order_tracker_steps raw enum name 52; admin_dashboard 13,21; error widget main 103 | [deviation] |
| Silent `catch (_) {}` | 0 | 4 documented: app_config 12 (dotenv fallback), force_update_guard 46 (fail-open), cart_repository 36 (legacy row), amount_formatter 8 (bad currency). All comment-documented, none silent | [OK] |
| `setState` after await guarded by `mounted` | always | owner assign-branch sheet 390-397 unguarded | [deviation] |
| Route constants | `RouteNames.X` | raw-path pushes `/privacy`,`/terms`,`/login` (resolve, so OK); the FAIL is that `RouteNames.X` don't match ACTIVE registered names | **[FAIL] P0-1** |
| `goNamed/pushNamed` target exists | yes | 35 of 41 fail (Sec4) | **[FAIL]** |
| `@Skip` in tests | 0 | 0 found in `core_app/test` | [OK] |
| `onPressed: null` undocumented | 0 | all nulls are visually disabled (sold-out, loading, thresholds) | [OK] |
| `Color(0x...)` in features | 0 | top_items_chart_widget 80-83; login Google blue 332 | [minor] |
| `double` money typed fields | 0 | 0 in hand-written code | [OK] |

---

## 7. ROLE GATING (spec Sec5)

- RoleRouterScreen role switch (72-78) maps owner/manager/kitchen/delivery to dashboards; customer -> deny redirect [OK logic].
- AdminGateway non-admin deny UI (85-109) [OK logic].
- Dashboards require auth/branchId (owner 39-47; manager 33-35; kitchen 40-48; delivery 50-56) [OK].
- **BUT the admin chain is unreachable in config mode**: the only in-app entry is AdminGateway -> roleRouter via dead `goNamed` (admin_gateway 80; P0-1). Direct path `/role-router` is registered and renders the dashboard correctly, so the gate logic functions; the UI cannot reach it.

## 8. FORMS (spec Sec6)

- Login (email/password validation) [OK]; Signup (name/email/password) [OK]; Reservation (name/phone/party-size/time, past-time guard) [OK]; Waitlist (party stepper + join) [OK]; RestaurantSetup (multi-field, only required-name validated) [minor]; BranchEditor/MenuItemEditor (no validators -> 0-coords / $0 accepted) [minor]; DeleteAccount (no confirm dialog; immediate destructive action) [note]; Checkout (promo + address + payment, full validation chain) [OK].

## 9. DEEP-LINK TABLE (spec Sec1 / deferral)

`DeepLinkRouteTable.validRoutePatterns` (packages/core/.../deep_link_service.dart:27-58) mirrors the OLD static+config union and includes `/admin`, `/admin/menu`, `/owner`, `/manager`, `/kitchen`, `/delivery`, `/logs`, `/error-logs` - none are ACTIVE routes in config mode. The handler (`main.dart:269`) uses `Navigator.pushNamed` (name-based), so even valid patterns fail (P0-2). No widget test covers the real handler; `test/core/router/deeplink_test.dart` uses a hand-rolled router.

## 10. TEST COVERAGE vs HONESTY BOUNDARY (spec Sec8)

Static audit only; no live emulator. Runtime transitions, side-effect execution (payment/Firestore rules), disabled states under real conditions, deep-link cold start, and platform flows are NOT PROVEN - they require the widget/integration tests listed below.

- PROVEN from source: handler existence/non-null; route registration vs ACTIVE table; RouteNames mismatch structure; no `@Skip`; no silent catch; integer `*Cents` money; DI providers; mounted guards (all but owner assign-branch); no Color(0x) in features except charts/brand.
- NOT PROVEN (needs tests): payment/sign-in-with-apple side effects; Firestore-rules enforcement; transitions landing on correct widgets; 20-tap admin gateway (does not exist, P2-2).
- Existing router tests do NOT cover config mode: `test/app/app_router_test.dart` only asserts the provider exists; `test/core/router/deeplink_test.dart` builds its own GoRouter (not `appRouterProvider`, not the client_config `screens`).

## 11. RECOMMENDED FIX (production-grade, minimal-risk) - NOT APPLIED (report-only)

1. **[P0-1] Align route names.** In `_buildRoutesFromConfig` (app_router.dart:144-150), add a `name` field per `screens` entry in `client_config.json` equal to the `RouteNames.X` value used in code (e.g. `"name":"login"` for `LoginScreen`); set `name: screen['name'] ?? id`. This fixes all 35 named call sites with zero app-code edits and zero static-mode regression.
2. **[P0-2] Fix deep links.** Replace `Navigator.pushNamed(path)` (main.dart:269) with go_router path navigation (`context.push/GoRouter.of(context).push(path)`); prune `DeepLinkRouteTable` to the 26 ACTIVE paths so invalid patterns log, not throw.
3. **[P0-3] ErrorWidget Restart** -> route via go_router `context.go('/')`.
4. **[P1-1] MenuScreen**: add `onTap` to the menu ListTile -> `pushNamed(RouteNames.dishDetail, pathParameters:{'id':item.id}, extra:item)`; replace `\$` with `formatCurrencyCents`.
5. **[P1-2] LocationScreen**: add `onTap` per branch -> `ref.read(currentBranchIdProvider.notifier).setBranch(id)` (merged_menu_provider.dart:78, currently zero callers).
6. **[Sec7.6]** owner assign-branch: guard `setState` with `mounted` after await (owner 390-397).
7. **[Sec7 l10n]** move hard-coded role_router/admin_gateway/restaurant_setup/tier_flags strings to `AppLocalizations`; converge loading-state naming.
8. **Tests:** add a widget test pumping `appRouterProvider` with the real screens list asserting each named nav renders the ACTIVE target; point deeplink_test at the app router.

All are additive/renaming; none change data contracts, schemas, or auth logic.

---

## 12. SUMMARY (spec Sec3.7)

- Total screens/classes examined: 33 **source screen classes** (26 config-registered + AnalyticsSnapshot, AdminMenuManager, LogsScreen, OwnerDashboard, ManagerDashboard, KitchenDashboard, DeliveryDashboard) + BrandDrawer + AnimatedCartBadge + PendingSyncBanner + shared widgets. Every interactive element enumerated above.
- Named navigation call sites: **41 tracked → 35 FAIL** (26 unregistered `RouteNames`, 2 deep-link/restart pushNamed-by-path, plus 4 path-based that pass and the rest of the 35 dead).
- DEAD/ORPHANED handlers: **0** (no `onPressed: () {}`, no `TODO` handler, no `UnimplementedError`) — but **35 navigation targets are orphaned** (referenced route names not registered) which is the same net effect: buttons that do nothing/crash.
- Missing interactive elements: MenuScreen dish-detail nav (P1-1), LocationScreen branch selection (P1-2).
- Consistency deviations: loading-state naming (8 variants), l10n gaps (~25 hard-coded strings in feature files), money rendering (menu `$`, home manual), unguarded `setState` (owner 390-397), `Color(0x...)` charts, inline `IsarService()`.
- **VERDICT: FAIL.** Fix P0-1 → P0-3 first; then P1-1, P1-2; then consistency items. See §11.

### Canonical-command results (spec §4)
| Command | Result |
|---|---|
| `flutter analyze --fatal-infos` (core_app) | `No issues found!` (runtime mismatch not analyzable) |
| `flutter test test/app/app_router_test.dart test/core/router/deeplink_test.dart test/main_test.dart` | All passed — but none exercise config-mode named nav (see §10) |
| grep `FirebaseFirestore.instance`/`FirebaseAuth.instance` in feature code | 0 (DI honored) |
| grep `double (price\|total\|amount\|subtotal\|tax\|tip)` hand-written | 0 (integer `*Cents` honored) |
| grep `catch (_) {}` | 4, all comment-documented defensive fallbacks |
| grep `@Skip`/`skip:true`/`markTestSkipped` in tests | 0 |

---
**End of audit report.** No source code was modified.