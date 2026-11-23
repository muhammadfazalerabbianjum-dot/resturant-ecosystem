# CARNAMA LABS — UI WIRING & BUTTON COMPLETENESS VERIFICATION PROMPT

**Spec date:** 2026-08-30 · The single authoritative prompt to verify EVERY screen,
EVERY button, EVERY interactive element, and EVERY navigation path in the Carnama Labs
reference app (`core_app`) works — no dead buttons, no broken routes, no orphaned handlers.

**Source of truth = the CURRENT codebase.** This prompt is a SPEC. It performs NO code changes.
Read source, verify against source, report. A claim without `file:line` of current source is a fail.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it. Never trust this spec's screen list —
   discover dynamically from `app_router.dart` and the widget tree. Code differs → cite, amend, prove.
2. **No stubs / fake success / AI slop.** No placeholder `Container()`, no `onPressed: null` without
   documented reason, no `// TODO` handlers, no buttons that look enabled but do nothing.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source. Every button's status cites
   the exact handler code. "Looks fine" is not evidence.
4. **Completeness.** You MUST enumerate every screen and every interactive element. A screen you didn't
   check is a screen that's failed. No sampling — exhaustive.
5. **No escapes.** No `@Skip`, no `skip:`, no `markTestSkipped`, no "too many to check".
6. **Production-grade or not at all.** A dead button in production is a fail. A button with `onPressed: null`
   that isn't visibly disabled is a fail. A route that 404s is a fail.

---

## 1. SCOPE — what to verify

### 1.1 Screen inventory (discover dynamically — this is the authoritative route list)

**AUTHORITATIVE ROUTE SOURCES:** `core_app/lib/app/app_router.dart` + the `screens` array in
`core_app/assets/client_config.json`. **CRITICAL:** the router uses the config `screens` array
EXCLUSIVELY when it is non-empty (`app_router.dart:167` — `configRoutes.isNotEmpty ? configRoutes : _staticRoutes`).
The static fallback routes are NOT registered when the config file has `screens`. This means the
effective route table = `client_config.json` `screens` (26 entries), NOT the static list. Verify
which mode the running app is in FIRST, then audit against the ACTIVE route set.

**Verified config-driven routes (`client_config.json` `screens`, 26 entries — verified 2026-08-30):**

| Route name | Path | Screen | Role |
|---|---|---|---|
| SplashScreen | /splash | SplashScreen | public |
| OnboardingScreen | /onboarding | OnboardingScreen | public |
| LoginScreen | /login | LoginScreen | public |
| SignupScreen | /signup | SignupScreen | public |
| HomeScreen | / | HomeScreen (5 tabs) | auth |
| MenuScreen | /menu | MenuScreen | public |
| DishDetailScreen | /dish/:id | DishDetailScreen | public |
| CartScreen | /cart | CartScreen | auth |
| CheckoutScreen | /checkout | CheckoutScreen | auth |
| OrderTrackerScreen | /orders/:orderId | OrderTrackerScreen | auth |
| OrderHistoryScreen | /orders | OrderHistoryScreen | auth |
| ReservationScreen | /reservations | ReservationScreen | auth |
| LocationScreen | /locations | LocationScreen | auth |
| PinDropMapScreen | /location/map | PinDropMapScreen | auth |
| WaitlistScreen | /waitlist | WaitlistScreen | auth |
| LoyaltyScreen | /loyalty | LoyaltyScreen | auth |
| ProfileScreen | /profile | ProfileScreen | auth |
| DeliveryTrackerScreen | /tracking/:orderId | DeliveryTrackerScreen | auth |
| DeleteAccountScreen | /delete-account | DeleteAccountScreen | auth |
| TermsOfServiceScreen | /terms | TermsOfServiceScreen | public |
| PrivacyPolicyScreen | /privacy | PrivacyPolicyScreen | public |
| RoleRouterScreen | /role-router | RoleRouterScreen | any-auth |
| AdminGatewayScreen | /admin-gateway | AdminGatewayScreen | public |
| TierFlagManagerScreen | /admin/setup/tier-flags | TierFlagManagerScreen | owner |
| RestaurantSetupScreen | /admin/setup/restaurant | RestaurantSetupScreen | owner |
| OperatingHoursScreen | /admin/setup/hours | OperatingHoursScreen | owner |

**Routes declared in `navigation.routes`/`hiddenRoutes` but NOT in `screens` — NOT registered in
config mode.** Deep-links or `goNamed` to these will 404 when the config file is present:
`/owner`, `/manager`, `/kitchen`, `/delivery`, `/admin`, `/admin/menu`, `/error-logs`, `/logs`.
The admin dashboards ARE reachable in-app because `RoleRouterScreen` renders them as child
widgets (`role_router_screen.dart:72-78`) — but verify that NO code path calls
`context.goNamed(RouteNames.ownerDashboard)` / `goNamed` to the above while the config `screens`
array is non-empty. Also verify the deep-link handler (`main.dart:269` `pushNamed(path)`) — an
inbound URL targeting those paths must not throw.

**Static-fallback routes (`app_router.dart:221-451`) — ACTIVE ONLY when config `screens` is empty:**
splash /splash, onboarding /onboarding, login /login, signup /signup, home /, menu /menu,
dishDetail /dish/:id, cart /cart, checkout /checkout, orderTracker /orders/:orderId, orders /orders,
reservations /reservations, locations /locations, waitlist /waitlist, loyalty /loyalty, profile /profile,
errorLogs /error-logs, admin /admin, adminMenu /admin/menu (nested), roleRouter /role-router,
ownerDashboard /owner, managerDashboard /manager, kitchenDashboard /kitchen,
deliveryDashboard /delivery, privacy /privacy, terms /terms, deleteAccount /delete-account,
logs /logs, adminGateway /admin-gateway.

**Verified screen classes exist (33 total):** SplashScreen, OnboardingScreen, LoginScreen,
SignupScreen, HomeScreen, MenuScreen, DishDetailScreen, CartScreen, CheckoutScreen,
OrderTrackerScreen, OrderHistoryScreen, ReservationScreen, LocationScreen, PinDropMapScreen,
WaitlistScreen, LoyaltyScreen, ProfileScreen, DeliveryTrackerScreen, DeleteAccountScreen,
TermsOfServiceScreen, PrivacyPolicyScreen, RoleRouterScreen, AdminGatewayScreen,
TierFlagManagerScreen, RestaurantSetupScreen, OperatingHoursScreen, AnalyticsSnapshot,
AdminMenuManager, LogsScreen (in `packages/core_ui/lib/src/error_logger/logs_screen.dart`),
OwnerDashboard, ManagerDashboard, KitchenDashboard, DeliveryDashboard.

**PLUS** AdminReservationsTab, RestaurantSetupScreen (via owner tab), TierFlagManagerScreen,
OperatingHoursScreen, and any screen reached via `state.extra` (e.g. DishDetailScreen receives a
`MenuItemModel` extra).

### 1.2 Interactive element types to audit per screen

For EACH screen, find and verify EVERY instance of:

- `ElevatedButton`, `TextButton`, `FilledButton`, `OutlinedButton`, `IconButton`
- `GestureDetector`, `InkWell`, `ListTile` (with onTap)
- `NavigationDestination`, `BottomNavigationBarItem`, `TabBar` tabs
- `TextField` / `TextFormField` (with `onSubmitted`, `onEditingComplete`)
- `Switch`, `Checkbox`, `Slider`, `Radio` (with onChanged)
- `DropdownButton`, `PopupMenuButton`
- `FloatingActionButton`
- `AppBar` actions, leading buttons, back buttons
- Dialog action buttons (AlertDialog, showModalBottomSheet)
- `RefreshIndicator`, `Dismissible`
- `CheckboxListTile`, `RadioListTile`, `ExpansionTile`
- Custom tappable widgets (any class with `onTap`/`onPressed` callback)

---

## 2. METHODOLOGY — how to verify (exhaustive, not sampled)

### STEP 1 — DISCOVER

1. Read `core_app/lib/app/app_router.dart` — extract the COMPLETE route list.
2. Read `core_app/lib/app/navigation/route_names.dart` — extract all route names.
3. For each route, read the screen file. Identify all interactive elements.
4. For screens with tabs (HomeScreen, OwnerDashboard), read EACH tab's file.
5. For config-driven screens, read `_getScreenWidget()` and verify the switch is exhaustive.

### STEP 2 — VERIFY EACH INTERACTIVE ELEMENT

For EVERY interactive element found, determine its status:

| Status | Definition | Pass? |
|---|---|---|
| **WORKING** | Has a non-null `onPressed`/`onTap`/`onChanged` that performs a real action (navigation, state change, API call, dialog) | ✅ |
| **DISABLED (documented)** | `onPressed: null` BUT the button is visually disabled (e.g., `ElevatedButton(onPressed: null)` renders disabled) AND there's a clear reason (e.g., form invalid, loading state) | ✅ |
| **DEAD** | `onPressed: null` with no visual disabled state, OR handler is empty `{}`, OR handler only has a comment | ❌ |
| **ORPHANED** | References a route/screen that doesn't exist, or calls a method that does nothing | ❌ |
| **TODO** | Handler contains `// TODO`, `throw UnimplementedError()`, or is a placeholder | ❌ |

### STEP 3 — VERIFY NAVIGATION

1. Every `context.push`/`context.pushNamed`/`context.go`/`context.goNamed`/`Navigator.push`/
   `Navigator.pushNamed` must reference a route that EXISTS in the router.
2. Every `RouteNames.X` constant must map to a registered route.
3. Deep links (`carnama.com`) must resolve to a screen.
4. Back navigation (`context.pop`, `Navigator.pop`) must not trap the user.
5. `PopScope`/`WillPopScope` must have a defined behavior.

### STEP 4 — VERIFY ASYNC BUTTONS

For every button that triggers an async action (API call, Firestore write, navigation after await):

1. Does it show a LOADING state while in flight? (spinner, disabled, loading indicator)
2. Does it handle ERROR states? (snackBar, error message, log)
3. Does it prevent DOUBLE-SUBMISSION? (debounce, loading guard)
4. Does it verify `mounted` before `setState` after await?

### STEP 5 — VERIFY ROLE-BASED GATING

1. `RoleRouterScreen` must route to the correct dashboard per role.
2. Each admin dashboard must reject unauthorized roles.
3. The `adminGateway` (20-tap PIN) must gate admin access.

### STEP 6 — VERIFY FORMS

1. Every form must have a submission mechanism (button or onSubmitted).
2. Form validation must work (invalid input → error message, not submission).
3. Required fields must be marked and enforced.

### STEP 7 — VERIFY CROSS-SCREEN CONSISTENCY (same variables everywhere)

Screens must use IDENTICAL variable naming, provider patterns, and state conventions so
maintenance and cross-screen data flow never mismatch. Audit the ENTIRE `core_app/lib` +
`packages/*/lib` surface for:

1. **Loading/submitting state naming** — one convention only. Record which each screen uses and
   flag any screen that deviates from the majority: `_loading` / `_isLoading` / `_isSubmitting` /
   `_isSaving` / `_busy` / `_promotionsLoading`.
   **KNOWN VARIANCE (verified 2026-08-30, must be reconciled):** `login_screen.dart:25`,
   `signup_screen.dart:23`, `owner_dashboard.dart:214,293`, `operating_hours_screen.dart:20` use
   `_loading`; `restaurant_setup_screen.dart:68` uses `_isSaving`; `home_screen.dart:154` uses
   `_promotionsLoading`. Decide ONE convention and flag every divergence.
2. **Money fields** — every money value must be integer cents named with the `*Cents` suffix
   (`priceCents`, `totalCents`, `subtotalCents`, `taxCents`, `tipCents`, `deliveryFeeCents`,
   `discountCents`, `amountCents`). Grep for `double (price|total|amount|subtotal|tax|tip)`
   (hand-written, excluding generated/freezed) → MUST be 0. No `price`/`total`/`amount` as a
   double anywhere in hand-written code.
3. **DI pattern** — every screen/service must consume `firestoreProvider`/`functionsProvider`/
   `loggerProvider`/`authRepositoryProvider` from Riverpod. `FirebaseFirestore.instance` /
   `FirebaseAuth.instance` / inline `LoggerService()` in feature screens → MUST be 0.
4. **Localization** — every user-facing string must go through `AppLocalizations` (`loc.*`) or
   config. Hard-coded English string literals inside `Text('...')` in feature widgets → MUST be 0
   (record exceptions that are genuinely static UI copy and justify them).
5. **Error/logging** — every service `catch` must log via injected `LoggerService` (never silent
   `catch (_) {}`). Grep for `catch (_) {}` / `catch (_) {` in hand-written lib → MUST be 0.
6. **Async safety** — every `setState` after an `await` must be guarded by `if (mounted)`.
7. **Route constants** — every navigation must use `RouteNames.X` (or an existing config `route`
   string), never a raw literal path that doesn't exist. Cross-check each `goNamed`/`pushNamed`
   target against the ACTIVE route table (§1.1).

Report the canonical convention chosen for each dimension + every screen that deviates (file:line).

---

## 3. OUTPUT FORMAT — the verification report

Produce a report with these sections:

### 3.1 Screen-by-screen inventory

For EACH screen:

```
### [ScreenName](file_path)
**Route:** /route-path
**Role:** public/auth/owner/manager/kitchen/delivery

| # | Element | Type | Location | Handler | Status | Notes |
|---|---------|------|----------|---------|--------|-------|
| 1 | "Place Order" | ElevatedButton | checkout_screen.dart:145 | onPressed: _placeOrder | ✅ WORKING | Calls createOrder |
| 2 | "Cancel" | TextButton | checkout_screen.dart:150 | onPressed: null | ❌ DEAD | No handler, not disabled |
```

### 3.2 Navigation matrix

| From | Action | To | Route exists? | Status |
|------|--------|----|---------------|--------|
| HomeScreen | tap menu dest | /menu | ✅ | ✅ |
| LoginScreen | tap forgot password | ??? | ❌ | ❌ ORPHANED |

### 3.3 Async button audit

| Screen | Button | Loading? | Error guard? | Double-submit guard? | mounted check? | Status |
|--------|--------|----------|--------------|---------------------|----------------|--------|

### 3.4 Role gating audit

| Screen | Required role | Rejects others? | Status |
|--------|---------------|-----------------|--------|

### 3.5 Route-registration audit (config mode vs static)

| Route name | Path | In config `screens`? | In static fallback? | Referenced by code? | Status |
|---|---|---|---|---|---|
| ownerDashboard | /owner | ❌ | ✅ | ??? (verify) | ⚠️ verify |
| RoleRouterScreen | /role-router | ✅ | ✅ | ✅ goNamed | ✅ |

**MUST ANSWER:** with the bundled `client_config.json` present (26 screens), are `/owner`,
`/manager`, `/kitchen`, `/delivery`, `/admin`, `/logs` ever the target of `goNamed`/`pushNamed`/
an inbound deep link? If yes → unreachable/mis-routed in config mode → FAIL.

### 3.6 Cross-screen consistency audit

| Dimension | Canonical convention chosen | Screens that deviate (file:line) | Status |
|---|---|---|---|
| Loading state var | e.g. `_isLoading` | login:25, signup:23, owner:214, ... | ⚠️ |
| Money fields | integer `*Cents` | (0) | ✅ |
| DI (providers) | `firestoreProvider` etc. | (0) | ✅ |
| l10n | `loc.*` | (0) | ✅ |
| Silent catch | none allowed | (0) | ✅ |
| mounted-guard | `if (mounted)` before setState | (0) | ✅ |
| Navigation | RouteNames.X | (0) | ✅ |

### 3.7 Summary

- Total screens checked: N
- Total interactive elements: N
- Working: N
- Disabled (documented): N
- DEAD: N (list each with file:line)
- ORPHANED: N (list each with file:line)
- TODO: N (list each with file:line)
- Consistency deviations: N (list each with file:line)
- **VERDICT:** PASS (0 dead/orphaned/todo + 0 consistency deviations) / FAIL (list every failure)

---

## 4. CANONICAL COMMANDS

| id | CWD | Command | Expected |
|---|---|---|---|
| ANALYZE | `core_app/` | `flutter analyze --fatal-infos` | `No issues found!` |
| TEST | `core_app/` | `flutter test` | All green, 0 skips |
| ROUTES | `core_app/` | `grep -rn "GoRoute\|context.push\|context.go\|Navigator.push" lib/` | All targets resolve against ACTIVE route table |
| DI | `core_app/` | `grep -rn "FirebaseFirestore.instance\|FirebaseAuth.instance" lib/` | 0 in feature code |
| MONEY | repo root | `grep -rn "double (price\|total\|amount)" core_app/lib packages/*/lib` | 0 (hand-written) |
| CATCH | `core_app/` | `grep -rn "catch (_) {}" lib/` | 0 |
| SKIP | repo root | `grep -rn "@Skip\|skip:\s*true\|markTestSkipped" core_app/test apps/*/test packages/*/test` | 0 |

---

## 5. EXECUTION RULES

1. **Read EVERY screen file.** No sampling. If a screen has 30 buttons, check all 30.
2. **Read the ACTUAL handler code.** Don't assume — read what `onPressed` actually calls.
3. **Check for null handlers.** `onPressed: null` is only acceptable if the widget renders disabled.
4. **Check for empty handlers.** `onPressed: () {}` is a dead button.
5. **Check for TODO handlers.** `onPressed: () { // TODO: implement }` is a fail.
6. **Verify route existence.** Every navigation target must exist in the router.
7. **Check async safety.** Every async handler must guard `mounted` before `setState`.
8. **No skipping.** "Too many buttons" is not an excuse. Check them all.
9. **Cite file:line.** Every claim must have a source citation.

---

## 6. KNOWN COMPLEX SCREENS (verify extra carefully)

These screens have the most interactive elements — audit exhaustively:

- **OwnerDashboard** (9 tabs, each with multiple buttons/forms)
- **HomeScreen** (5 tabs, hero carousel, category filters, search)
- **CheckoutScreen** (payment, promo, tip, place order, validation)
- **CartScreen** (quantity adjust, remove, promo, checkout navigation)
- **MenuScreen** (category filters, search, add-to-cart, dish detail nav)
- **ReservationScreen** (date/time picker, party size, submit, validation)
- **RestaurantSetupScreen** (multi-field form, image picker, save)
- **LoginScreen** (email/password, Google, Apple, forgot password, signup nav)
- **AdminGatewayScreen** (20-tap PIN entry, PIN validation)

---

## 7. WHAT CONSTITUTES A FAILURE

Any of these is a FAIL (must be fixed before production):

- A button with `onPressed: null` that isn't visually disabled
- A button with an empty handler `() {}`
- A button with a `// TODO` or `UnimplementedError` handler
- A navigation call to a route that doesn't exist (against the ACTIVE route table — config mode)
- An async button with no loading state (risk of double-submit)
- An async handler that calls `setState` after await without `mounted` check
- A form with no submission mechanism
- A required field with no validation
- A role-gated screen that doesn't reject unauthorized roles
- A back button that traps the user (no pop handler)
- A `goNamed`/`pushNamed`/deep-link targeting `/owner`, `/manager`, `/kitchen`, `/delivery`,
  `/admin`, `/logs`, `/error-logs` while the config `screens` array is non-empty (not registered)
- A cross-screen consistency deviation (mixed loading-state naming, double money, direct
  `FirebaseFirestore.instance`, hard-coded English in a widget, silent `catch (_) {}`,
  unguarded `setState` after await, raw path literal instead of `RouteNames.X`)

---

## 8. HONESTY BOUNDARY — WHAT THIS STATIC AUDIT CAN AND CANNOT PROVE

**This prompt is a source-level (static) audit.** Do NOT claim runtime proof you do not have.

**PROVABLE FROM SOURCE (cite file:line):** handler exists / is non-null / calls a real method;
route is registered in the ACTIVE table; `RouteNames.X` resolves; `mounted` guard present;
`*Cents` integer money; provider DI; `loc.*` localization; no silent catch; no `@Skip`; no
double money; no `Color(0x...)` in feature files.

**NOT PROVABLE WITHOUT A LIVE EMULATOR + WIDGET TESTS (state this explicitly in the report):**
- A handler executes its intended side effect correctly (a `Firestore.set` that fires rules-deny
  still "works" from Dart's view — the DB layer must be proven separately by the rules suite)
- Navigation transition actually lands on the widget (needs a widget/integration test that pumps
  the router and asserts the target screen renders)
- A button's disabled state is reached under the real condition it guards
- Network/permission flows (payment, location, camera, deep-link cold start) — device-level
- 20-tap admin gateway count logic under real taps

For each of these, either (a) cite the existing test that proves it (e.g. widget test), or
(b) mark it `NOT PROVEN — needs [test name]`. Never write "verified" for a runtime behavior you
only read in source.

---

## 9. VERDICT

- **PASS** — Every screen checked, every button working or documented-disabled, every route
  resolves against the ACTIVE table, every async button guarded, every form submits, every role
  gate enforced, every cross-screen convention consistent, and the honesty boundary above is
  fully respected (no runtime claim without its test).
- **FAIL** — List EVERY failure with `file:line`, the exact handler code, and the fix required.
  A failure means the app is NOT production-ready.

---

**END OF PROMPT.** Read the code. Verify every button. Verify every route against the ACTIVE
table. Verify cross-screen consistency. Report exhaustively. Never claim a runtime behavior you
did not execute. No escapes.