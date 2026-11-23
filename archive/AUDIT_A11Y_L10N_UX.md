# CARNAMA LABS — ACCESSIBILITY, LOCALIZATION & UX CONSISTENCY AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify accessibility compliance
(WCAG / TalkBack / VoiceOver), localization readiness, and UI consistency across EVERY screen
in the Carnama Labs template (`core_app`) and shared widgets (`packages/core_ui`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Mostly accessible" is a fail; each screen passes or fails.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every screen, every interactive element, every string. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A restaurant app that TalkBack users cannot order from is
   a legal risk (ADA/EAA) and a moral failure. Hard-coded English blocks every future client
   market. The UI wiring audit already found ~25 hard-coded strings — find ALL of them.

---

## 1. SCOPE

### 1.1 Localization Inventory (the blocker for new client markets)

**Files to audit:**
- `core_app/lib/l10n/**` (or wherever arb files / generated strings live — FIND IT)
- EVERY user-visible string in `core_app/lib/features/**` (grep quoted string literals in Text(,
  label:, hintText:, tooltip:, snackBars, dialogs, error messages)
- `packages/core_ui/lib/**` shared widget default strings

**Verify:**
- [ ] Does an l10n system exist AT ALL? (arb files + gen-l10n / intl). If absent: P0 finding with
  a migration plan, because white-label clients WILL need their market's language
- [ ] Complete inventory of hard-coded user-visible strings, file:line, per feature
  (UI wiring audit found ~25 in feature files — enumerate ALL, including packages/core_ui)
- [ ] Currency display: `AmountFormatter` exists — is it used EVERYWHERE money renders?
  List every violation (menu_screen and home_screen already flagged — verify and complete)
- [ ] Date/time display: every `DateFormat(` call — locale-aware? list violations
- [ ] Pluralization-ready: strings with counts baked in ("3 items") are FINDINGS once l10n lands
- [ ] TextDirection: any LayoutBuilder/EdgeInsets that assume LTR (RTL readiness for future
  markets) — list hot spots in shared widgets

### 1.2 TalkBack / VoiceOver (Semantics)

**Files to audit:**
- EVERY interactive element in `core_app/lib` (InkWell, GestureDetector, IconButton,
  ElevatedButton, FloatingActionButton, custom tap targets) and `packages/core_ui/lib`

**Verify:**
- [ ] Every icon-only button has a `tooltip:` or `Semantics(label:)` — list every icon-only
  control WITHOUT a label (screen reader announces "button" = fail)
- [ ] `Semantics` on the cart badge (announces item count, not "1")
- [ ] Order tracker step announcements: current step semantic state (`Semantics(header:)`,
  selected states)
- [ ] Tap target sizes ≥ 48x48dp (Material) — list every smaller tap target
- [ ] `ExcludeSemantics`/`MergeSemantics` correctness on the animated cart badge & tour overlay
  (decorative animation must not pollute the semantic tree)
- [ ] Focus traversal order logical on forms (login, signup, checkout)
- [ ] `TextField` has `labelText` or `Semantics` (hint-only fields are FINDINGS)

### 1.3 Visual Accessibility

**Files to audit:**
- `core_app/lib/app/theme/**` (or theme construction site in app_router/main)
- `apps/halal_boyz/assets/client_config.json` theme section
- Charts in `core_app/lib/features/admin/presentation/analytics_snapshot.dart`
  (chart colors were flagged in the UI wiring audit)

**Verify:**
- [ ] All text/background pairs in template theme pass WCAG AA (4.5:1 body, 3:1 large) —
  compute programmatically and put the ratio table in the report
- [ ] Error states are not color-only (icon + text, not just red)
- [ ] Chart series distinguishable without color (shape/label patterns) for color-blind users
- [ ] `textScaler` handling: long-text screens (dish detail, order history) do NOT overflow at
  1.3x/2.0x font scale — check for `overflow: ellipsis` + `maxLines` traps that drop content
- [ ] Dark theme exists and is tested; every `Colors.white`/`Colors.black` literal in features
  is a FINDING (list them all — grep `Colors.white`, `Colors.black`, `Color(0x`)
- [ ] Touch ripple/feedback present on custom ink wells

### 1.4 UX Consistency & Interaction Contracts

**Files to audit:**
- Cross-screen: back behavior, loading skeletons, empty states, error retry patterns
- `core_app/lib/features/**/presentation/*.dart` (all 33 screens from the UI wiring audit)

**Verify:**
- [ ] Every async screen has loading, empty, error, and retry states — produce the 4-state
  matrix for all screens (UI wiring audit noted 8 different loading-state naming variants;
  document each)
- [ ] Pop-scope: cart/checkout screens guard accidental back-loss? (`PopScope`/`WillPopScope`
  usage list)
- [ ] Confirmation dialogs before destructive actions (clear cart, cancel order, delete account)
- [ ] Keyboard: forms scroll when keyboard opens (`resizeToAvoidBottomInset`), submit actions on
  `textInputAction`, autofill hints on login/signup (email/password)
- [ ] Haptics consistent for key actions (add-to-cart, order placed) — document where they exist
- [ ] Empty cart CTA returns to menu (already wired — verify pattern reused for other empties)

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). Include: (a) full hard-coded-string inventory, (b) contrast ratio table,
(c) icon-button-without-label list, (d) 4-state matrix per screen.

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] l10n presence confirmed or reported absent with evidence?
- [ ] String inventory 100% complete (not a sample)?
- [ ] Contrast table computed from actual config/theme values?
- [ ] Every icon-only interactive element checked?
- [ ] No accessibility claim without code citation?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**
---

# 🏁 AUDIT EXECUTED — 2026-08-31 — ACCESSIBILITY, LOCALIZATION & UX CONSISTENCY

**Prompt:** [AUDIT_A11Y_L10N_UX.md] · **Consolidated block:** appends as section `05` in `PRODUCTION_READINESS_AUDIT_MASTER.md`
**Scope (exhaustive):** all 33 screen classes in `core_app/lib/features/**/presentation/*.dart`, `core_app/lib/app/**` (BrandDrawer, AnimatedCartBadge, GDPR dialog, force-update guard, app_router error shells, main.dart ErrorWidget), ALL of `packages/core_ui/lib`, both `core_app` + `apps/halal_boyz` l10n/arb pairs, both `client_config.json` theme blocks, the existing a11y test layer under `core_app/test/ui/**`.
**Verdict: FAIL** · **P0:** 0 · **P1:** 7 · **P2:** 14 · **P3:** 3

**Hard gates — disposition:** Truth over documents ✅ (every claim cites `file:line` of current source) · No stubs ✅ (PASS/FAIL per item, no sampling — full inventory below) · Exhaustive ✅ · Report-only ✅ (no code was modified).

---

## §0 P0 gate — does an l10n system exist at all? → **YES ✅ (does not fail)**

- `core_app/l10n.yaml` (`arb-dir: lib/l10n`, template `app_en.arb`, `output-class: AppLocalizations`, `nullable-getter: false`) and a matching `apps/halal_boyz/l10n.yaml` (`synthetic-package: false`).
- Generated classes `app_localizations.dart` (+`_en.dart`, `_ar.dart`) exist under `core_app/lib/l10n/` and `apps/halal_boyz/lib/l10n/`.
- Wired: `core_app/lib/app_bootstrap.dart:896-902` registers `AppLocalizations.delegate`, `GlobalMaterial/Widgets/CupertinoLocalizations.delegate`, `supportedLocales: AppLocalizations.supportedLocales` (post-ARCH-2 the old `main.dart` site is gone); same via the shared boot for the shell — `apps/halal_boyz/lib/app/app.dart` L22 returns `CoreApp` and registers no delegates of its own.
- Key parity enforced & green: `core_app` en 532 == ar 532 (zero missing, zero extra); `halal_boyz` en 19 == ar 19 (test `core_app/test/l10n/app_localizations_parity_test.dart`).
- **But the system is bypassed by ≈118 user-visible literal sites** (below) → P1-L10N-STRINGS. An ar user still sees English chrome (drawer, GDPR dialog, force-update, ErrorWidget, admin setup, status names…).

---

## §1.1 Localization inventory

### (a) Full hard-coded user-visible string inventory (file:line — none omitted)

**Shared app layer — `core_app/lib/app/**` (20 sites):**

| # | file:line | Literal | Impact |
|---|---|---|---|
| 1 | `app/app_router.dart:128` | `'Screen: $screenId'` | config-mode fallback screen chrome |
| 2 | `app/app_router.dart:129` | `'No widget mapped for $screenId'` | config-mode fallback body |
| 3 | `app/app_router.dart:173` | `'Route Error'` | global error shell title |
| 4 | `app/app_router.dart:174` | `'Navigation error: ${state.error}'` | global error shell body |
| 5 | `app/brand_drawer.dart` L35-36 (deleted post-audit; no live BrandDrawer) | `'$tier Member'`, `'Guest'` | drawer header |
| 6-13 | `app/brand_drawer.dart` L53,61,69,77,85,94,102,111 (deleted post-audit) | `'Home'`, `'Menu & Search'`, `'My Cart'`, `'Order History'`, `'Reservations'`, `'Find a Branch'`, `'My Profile'`, `'Sign Out'` | 8 drawer destinations |
| 14 | `app/compliance/gdpr_consent_dialog.dart:46` | `'Data & Privacy'` | GDPR title |
| 15 | `app/compliance/gdpr_consent_dialog.dart:48-50` | analytics/push consent copy | GDPR body |
| 16 | `app/compliance/gdpr_consent_dialog.dart:58` | `'Decline'` | GDPR action |
| 17 | `app/compliance/gdpr_consent_dialog.dart:68` | `'Accept'` | GDPR action |
| 18 | `app/config/force_update_guard.dart:88-89` | update-required body | force-update screen (blocks every launch when triggered) |
| 19 | `app/config/force_update_guard.dart:97` | `'Update Now'` | force-update CTA |
| 20 | `main.dart:102-103,111` | `'Something went wrong. Please restart the app.'`, `'Restart'` | ErrorWidget.builder — shows on ANY uncaught error |
**Customer-facing feature screens (15 sites):**

| # | file:line | Literal | Impact |
|---|---|---|---|
| 21 | `features/orders/presentation/order_history_screen.dart:32` | `'Could not load your orders. Please try again.'` | order-history error state |
| 22 | `features/cart/presentation/cart_screen.dart:52` | `'$pendingCount order(s) pending sync'` | tooltip — pseudo-plural |
| 23 | `features/cart/presentation/cart_screen.dart:76` | `'Loading cart'` | Semantics label |
| 24 | `features/checkout/presentation/checkout_screen.dart:480` | `'Loading checkout'` | Semantics label |
| 25 | `features/menu/presentation/menu_screen.dart:168` | `'\$…'` inside Semantics label | wrong for non-USD + not l10n |
| 26 | `features/menu/presentation/menu_screen.dart:196` | `'\$…'` price subtitle | UI-wiring-P1-1’s sibling finding |
| 27 | `features/home/presentation/home_screen.dart:437` | inline `currencySymbolFor(…)…` | money rendered inline, `$` fallback |
| 28 | `features/home/presentation/home_screen.dart:777` | inline `currencySymbolFor(…)…` | same |
| 29 | `features/orders/presentation/order_tracker_steps_widget.dart:52` | `statuses[index].toString().split('.').last` | order-status names = English enum identifiers shown to user |
| 30 | `features/reservations/presentation/reservation_screen.dart:285` | `_startTime.toLocal().toString().substring(0,16)` | raw locale-unaware datetime on time button |
| 31 | `features/admin/presentation/kitchen/kitchen_dashboard.dart:203` | `'• ${item.item.name} × ${item.quantity}'` | glyphs + unlocalized item line |
| 32 | `features/admin/presentation/manager/manager_dashboard.dart:89` | `'Order ${…}, ${order.status.name}, …'` | status `.name` inside Semantics |
| 33 | `features/admin/presentation/owner/owner_dashboard.dart:274,447` | `'⋯ · ${order.status.name}'`, `'${u.role.name} · …'` | status/role `.name` + `·` separator |
| 34 | `features/admin/presentation/owner/owner_dashboard.dart:347` | `'No branches found.'` | main EmptyState copy |
| 35 | `features/admin/presentation/owner/owner_dashboard.dart:363` | `'${loc.assignBranch} — ${user.displayTitle}'` | structure not localized |

**Admin / setup surfaces (≈60 sites):**

| # | file:line | Literal |
|---|---|---|
| 36-63 | `setup/restaurant_setup_screen.dart:336-701` | 28× `labelText:` (`'Restaurant Name *'`, `'Tagline'`, `'Support Email'`, `'Contact Phone'`, `'Address'`, `'Currency'`, `'Default Language'`, `'Minimum Order (cents)'`, `'Delivery Fee Type'`, `'Delivery Fee (cents)'`, `'Free Delivery Threshold (cents)'`, `'Estimated Prep Time (minutes)'`, `'Service Charge (%)'`, `'Loyalty Program Name'`, `'Points Per Dollar'`, `'Redemption Threshold (points)'`, `'Redemption Value (cents)'`, `'Signup Bonus Points'`, `'Notification Tone'`, `'Notification Opt-In'`, `'App Store Name'`, `'App Description'`, `'Terms URL'`, `'Privacy URL'`, `'Instagram URL'`, `'TikTok URL'`, `'Open Time (e.g. 09:00)'`, `'Close Time (e.g. 22:00)'`) |
| 64-66 | same 424-426 | `'Flat'` / `'Distance'` / `'Free Above'` (dropdown) |
| 67 | same 468 | `'Tip Enabled'` |
| 68-69 | same 538-539 | `'Casual'` / `'Formal'` |
| 70-71 | same 551-554 | `'On Launch'` / `'After First Order'` |
| 72 | same 620 | `'Allergen Disclaimer Enabled'` |
| 73-79 | same 655-685 | `'Monday'`…`'Sunday'` |
| 80 | same 257 | `'Save'` |
| 81-83 | same 196,203,263 | `'Settings saved successfully'`, `'Failed to save: $e'`, `'Error: $err'` |
| 84-86 | `setup/tier_flag_manager_screen.dart:93,99,39` | `'Feature flags saved'`, `'Save failed: $e'`, `'${loc.error}: $e'` |
| 87-89 | `admin_dashboard.dart` L13,21,28 (deleted P9/T-5; pinned by `core_app/test/app/deleted_sources_pin_test.dart`) | `'Admin Dashboard'`, `'Lock TTL enforced'`, `'Enforce Lock TTL'` |
| 90-91 | `gateway/admin_gateway_screen.dart:30,103` | `'Auth error. Please try again.'`, `'Back to Home'` |
| 92-94 | `role_router_screen.dart:42,57,96` | `'Unable to verify role. Please try again.'` ×2, `'No admin permission for this account.'` |
| 95 | `admin_menu_manager.dart:20`, `analytics_snapshot.dart:27`, `home_screen.dart:704`, `admin_reservations_tab.dart:61`, `setup/*` | `'${loc.error}: $e'` raw-exception interpolation (5+ sites, P3 grouping) |
| 96 | `data_export_service.dart:156-157` | share-sheet subject/body English |
| 97 | `app/theme/app_strings.dart` L5 (deleted post-audit; no live genericError fallback) | `genericError` const (unlocalized fallback) |
| 98 | `setup/operating_hours_screen.dart:198` | `'–'` en-dash (glyph) |

**Shared widgets — `packages/core_ui/lib` (6 sites):**

| file:line | Literal | Note |
|---|---|---|
| `src/compliance/gdpr_consent_dialog.dart:48,70` | `'Data & Privacy'`, `'Accept'` | duplicate of #14/17; hidden by `main.dart:16` `hide GdprConsentDialog` |
| `src/config/force_update_guard.dart:110,117-118,126` | `'Update Required'`, body, `'Update Now'` | duplicate of #18/19; hidden by `hide ForceUpdateGuard` |
| `src/error_logger/logs_screen.dart:49,54,63` | `'Logs'`, `'Refresh logs'`, `'No logs available'` | DEBUG/PROFILE-only (bug reporter) |
| `src/widgets/live_map_picker_widget.dart:126,139,149` | `'Drop a pin anywhere on the map'`, `'Set Delivery Location'`, `'Confirm'` | customer-visible in checkout map sheet |
| `src/ui/global_error_widget.dart:9-10` | `kGlobalErrorFallbackBody` | documented pre-`runApp` fallback, still English |

**Enum `.name` leaks (systemic, 6 call sites):** `order_tracker_steps_widget.dart:52`, `manager_dashboard.dart:89`, `owner_dashboard.dart:274,447`, `order_history_screen.dart:55` (Semantics), `kitchen_dashboard.dart:395` (`_ => status.name` chip fallback). `OrderStatus.name`/`UserRole.name` return English identifiers — Arabic sees `confirmed`, `pickedUp`, `owner`. Convention already proven at `kitchen_dashboard.dart:392-394` (`loc.orderStatus_*`).

**Inventory total ≈ 118 literal sites.** The earlier UI-wiring estimate (~25) covered only the customer feature set; the exhaustive count including admin/setup and shared-widget defaults is substantially larger.
### (b) Currency display — canonical-formatter violations (P1-L10N-MONEY)

**Three money helpers coexist** — the spread is itself the finding:

| Helper | Definition | Used by |
|---|---|---|
| `formatAmount(cents, [currency='USD'])` — intl `NumberFormat.simpleCurrency`, **USD default** | `features/orders/domain/amount_formatter.dart:4-13` | delivery_dashboard:237,424,464 · kitchen_dashboard:355 · manager_dashboard:89,94 · owner_dashboard:162,276,762 · admin_menu_manager:32,36 · revenue_chart_widget:115 · analytics_snapshot:58 |
| `formatCurrencyCents` + `currencySymbolFor` — pure, `$` fallback, no grouping | `app/config/currency_format.dart:12-35` | cart_screen:103,145,212 · dish_detail_screen:116,196 · home_screen:437,777 · menu_screen:168,196 |
| `moneyCents` — core_ui, grouping but no locale digits | `packages/core_ui/lib/src/ui/money_text.dart:55-65` | order_history_screen:52 · order_tracker_screen:66 · checkout_screen:743 |

Violations → `features/menu/presentation/menu_screen.dart:196` literal `'$…'` (flagship customer screen, not config-driven); `home_screen.dart:437,777` inline `currencySymbolFor` with no thousands grouping; `admin_menu_manager.dart:32,36` call `formatAmount(item.priceCents)` **without** currency → an AED/SAR white-label client gets the wrong symbol on admin prices; the prompt's "list every violation" is answered by this table.

### (c) Date/time locale-awareness → FAIL (P2-L10N-DATE)

| file:line | Call | Finding |
|---|---|---|
| `features/admin/presentation/analytics/revenue_chart_widget.dart:128` | `DateFormat('E').format(date)` (no locale param) | resolves `Intl.defaultLocale` (en) — Arabic dashboard shows `Mon` |
| `features/admin/presentation/reservations/admin_reservations_tab.dart:104,133,141` | custom `DateFormat('…')` + `toLocal()` | no `loc.localeName`, device-local |
| `features/reservations/presentation/reservation_screen.dart:285` | `toLocal().toString().substring(0,16)` | raw DateTime string |
| `features/admin/presentation/setup/operating_hours_screen.dart:139-151` | `_parseTime`/`_formatTime` `'HH:mm'` | string time fields, no TimePicker localization |
| `data_export_service.dart:49` | `toIso8601String()` (offset-less) | re-confirmed from audits 02/03 |

### (d) Pluralization readiness → NOT READY (P2-L10N-PLURAL)

- `app_en.arb` / `app_ar.arb`: `"itemsCount": "{count} item(s)"` / `"{count} عنصر(عناصر)"` — the `@itemsCount` metadata is empty (no `placeholders`, no `type`); the generated getter takes `String count`, so Arabic renders `"1 عنصر(عناصر)"`.
- Same pseudo-plural: `cart_screen.dart:52` `'$pendingCount order(s) pending sync'`; `delivery_dashboard.dart:237,424,464` `itemsCount(order.items.length.toString())`.
- Genuine `Intl.plural` (zero/one/two/few/many/other) needs real ARB plural metadata — absent.

### (e) TextDirection / RTL readiness (P3-RTL) — hot spots

- `packages/core_ui/lib/src/error_logger/bug_reporter_overlay.dart:28-29` hard-codes LTR — DEBUG-only, accepted exemption.
- Swipe-to-delete background **does not mirror**: `cart_screen.dart:108-116,149` — `DismissDirection.endToStart` mirrors in RTL (Material), but the delete background `Alignment.centerRight` + `EdgeInsets.only(right:20)` stays pinned right.
- No other asymmetric `EdgeInsets.only(left/right)` in `core_ui` — grep clean except the above.
---

## §1.2 TalkBack / VoiceOver — Semantics

### (c-deliverable) Icon-only buttons WITHOUT a label/tooltip → **8 sites (P1-A11Y-ICONS)**

| file:line | Icon | Reading verbatim |
|---|---|---|
| `app/animated_cart_badge.dart:25-28` | shopping_cart | "button" — not "Cart" |
| `features/admin/presentation/owner/owner_dashboard.dart:495-498` | `Icons.add` (branches) | "button" |
| `features/admin/presentation/owner/owner_dashboard.dart:525-528` | `Icons.edit` (branch) | "button" |
| `features/admin/presentation/owner/owner_dashboard.dart:529-532` | `Icons.delete` (branch) — **destructive** | "button" — no "delete branch" |
| `features/admin/presentation/owner/owner_dashboard.dart:730-738` | `Icons.add` (menu item) | "button" |
| `features/admin/presentation/owner/owner_dashboard.dart:771-779` | `Icons.edit` (menu item) | "button" |
| `features/admin/presentation/owner/owner_dashboard.dart:780-783` | `Icons.delete` (menu item) — **destructive** | "button" |
| `features/home/presentation/home_screen.dart:688-691` | `Icons.clear` (search) | "button" |

Counter-examples (convention to imitate): `owner_dashboard.dart:452-454,673-675` (`tooltip:`), `admin_reservations_tab.dart:219-224` (`tooltip: loc.callCustomer`), `cart_screen.dart:58-60,151-176` (Semantics), `menu_screen.dart:210-213` (tooltip + wrapper), `profile_screen.dart:22-35` (Semantics), `home_screen.dart:440-468` (Semantics), `logs_screen.dart:51-54` (tooltip).

### Cart badge (P1-A11Y-CART)

`app/animated_cart_badge.dart:25-58` — `IconButton` (no tooltip, no Semantics) + `Text('$count')` overlay in a `Positioned` → ① TalkBack announces "button"; ② the raw digit leaks into the semantic tree; ③ no item-count phrase (the prompt’s explicit check). No `ExcludeSemantics` on the badge, no merged label. `.animate().scale()` is transform-only ✅ (no semantics pollution).

### Order tracker step announcements (P1-A11Y-TRACKER)

`features/orders/presentation/order_tracker_steps_widget.dart:26-58` — steps are `ListTile`s; active state via `primary.withValues(alpha:0.1)` background + bold only. **No `Semantics(header:)`, no `selected:`, no step-of-total, no live region.** Titles = English enum names (`statuses[index].toString().split('.').last`), step numbers = bare digits. A TalkBack user cannot answer "which step am I on". (`order_tracker_screen.dart:51-58` labels only the section.)

### Tap targets → **1 sub-48dp violation (P2-A11Y-TAP)**

`features/home/presentation/home_screen.dart:443-449` — add-to-cart `IconButton(constraints: BoxConstraints(), padding: EdgeInsets.zero)` → ≈24×24 dp (Material min 48). All other buttons in the K-grep use 48-dp defaults ✅; `checkout_screen.dart:522` `GestureDetector` card is full-width/≈68 dp ✅.

### Exclude/Merge semantics on decorative surfaces → PASS

Tour overlay wraps every control in `Semantics(label, button: true)` (`tour_overlay.dart:55-93`) ✅; no decorative animation in overlay; home nav/feed `Semantics` wrappers + `RepaintBoundary` (`home_screen.dart:99-110`) ✅; no `ExcludeSemantics` misuse.

### Form labels & focus (P2-A11Y-FIELD + P2-UX-KEYBOARD)

- **PASS:** login/signup/reservation `TextFormField`s all carry `labelText:` + `Semantics(textField:true)` (`login_screen.dart:144-177`, `signup_screen.dart:100-149`, `reservation_screen.dart:250-278`); checkout promo + menu search are wrapped (`checkout_screen.dart:591-607`, `menu_screen.dart:56-72`).
- **FAIL (home search):** `home_screen.dart:682-699` — hint-only `TextField`, **no Semantics** → unlabeled field.
- **FAIL (autofill/keyboard):** zero hits for `AutofillHints` / `textInputAction` / `onFieldSubmitted` in the whole tree → no autofill on login/signup (email/password contract not met), and the keyboard "go/done" neither submits nor advances. P2-UX-KEYBOARD.

### Focus traversal → PASS
Login/signup/reservation forms are single linear columns; no reordering or focus traps found.
---

## §1.3 Visual accessibility

### Contrast ratio table — computed from ACTUAL values (`core_app/assets/client_config.json` + `apps/halal_boyz/assets/client_config.json` `theme.colors`, identical; `AppColors` defaults `packages/core_ui/lib/src/theme/app_colors.dart:5-45`), WCAG 2.x relative luminance:

| Pair (fg on bg) | Ratio | Verdict |
|---|---|---|
| textPrimary `#1E1E1E` on background `#FFFFFF` | 16.67 : 1 | ✅ PASS AA |
| textPrimary `#1E1E1E` on primary `#FF6B00` | 5.84 : 1 | ✅ PASS AA |
| white `#FFFFFF` on secondary `#1D3557` | 12.36 : 1 | ✅ PASS AA |
| dark onSurface `#E6E1E5` on dark bg `#121212` (M3 approx) | 12.91 : 1 | ✅ PASS AA (dark) |
| **white `#FFFFFF` on primary `#FF6B00`** — BrandButton fg + every filled CTA | **2.86 : 1** | ❌ **FAIL** (needs ≥4.5; even 3.0 large fails) |
| **textSecondary `#9E9E9E` on `#FFFFFF`** — login muted :140, privacy/terms links :411-432 (12px), kitchen empty :172 | **2.68 : 1** | ❌ **FAIL** |
| **success `#4CAF50` on `#FFFFFF`** — status icons/chips (kitchen :346-350, admin_menu_manager :44, owner panic) | **2.78 : 1** | ❌ **FAIL** |
| error `#E53935` on `#FFFFFF` | 4.23 : 1 | ⚠️ AA-large-only — normal text FAIL |
| warning `#FFC107` on `#FFFFFF` | 1.63 : 1 | ❌ FAIL (icon usage) |
| `textPrimary54` effective `#858585` on white | 3.69 : 1 | ⚠️ large-only |
| `background54` effective `#929292` on `#121212` | 6.02 : 1 | ✅ PASS |
| white `#FFFFFF` on error `#E53935` (delete-account button) | 3.8 : 1* | ⚠️ large-only (*M3 `onError` is darker — derived) |

**Impact (P1-A11Y-CONTRAST):** `brand_button.dart:74-77` paints white on `Theme.of(context).primaryColor` — that is every primary CTA: cart BC → checkout → place order, login/signup `ElevatedButton`s (`signup_screen.dart:155-182`, login 214-…), disabled state uses `AppColors.textSecondary` background (:78). **The entire ordering path is below AA.** Fix belongs in the palette (AppColors + 2 client configs), not per-widget.

**Error states are icon+text, not color-only** → PASS (`GlobalErrorWidget` icon+`onErrorContainer`, `delete_account_screen.dart` icon+text, login `_error` text, validators).

### Dark theme → PASS-with-caveat (P2-A11Y-COLORLIT)

Dark theme exists and is dynamic: `core_app/lib/app_bootstrap.dart:893` (`darkTheme: AppConfig.darkTheme`), `core_app/lib/app/config/app_config.dart:153-155` (the audited `theme_config_provider.dart` was deleted P9/T-5 and pinned), config `darkTheme.background/surface` honored (`app_theme.dart:179-196`); tests `test/widget/dark_mode_test.dart`, `test/ui/dark_mode_golden_test.dart`.

**Raw `Colors.*`/`Color(0x…)` literals in feature code (full G-grep list — render identically in dark, bypass ColorScheme):**

| file:line | Literal |
|---|---|
| `features/menu/presentation/dish_detail_screen.dart:125-126` | `Colors.red` bg + `Colors.white` label (sold-out chip) |
| `features/orders/presentation/order_tracker_steps_widget.dart:48` | `Icon(check, color: Colors.white)` on primary circle |
| `features/admin/presentation/kitchen/kitchen_dashboard.dart:392-394` | `Colors.blue` / `Colors.orange` / `AppColors.success` chips |
| `features/admin/presentation/delivery/delivery_dashboard.dart:284,348` | `Colors.blue` |
| `features/admin/presentation/owner/owner_dashboard.dart:979-1001` | `Colors.green/red` shades + `activeThumbColor` |
| `features/admin/presentation/admin_menu_manager.dart:44` | `Colors.green`/`Colors.red` availability icon |
| `features/menu/presentation/widgets/allergen_disclaimer_banner.dart` L29-47 (deleted P9/T-5; pinned by `core_app/test/app/deleted_sources_pin_test.dart`) | `Colors.amber.shade50/700/800/900` |
| `features/menu/presentation/dish_detail_screen.dart:96,101` | `Colors.black12` placeholder |
| `features/auth/presentation/login_screen.dart:332` | `Color(0xFF4285F4)` (Google brand — acceptable) |
| `core_ui skeleton_loader.dart:58` | `Colors.grey[800]` vs `Colors.white` — theme-guarded ✅ |

### Charts — color-blind / screen-reader → POOR (P2-A11Y-CHART)

`top_items_chart_widget.dart:80-83` single-series bar chart, 4 hues, no pattern/shape, `Semantics` only on the title (:98-105), no per-bar value label semantics, axis digits plain. `revenue_chart_widget.dart:88-95` line chart — Semantics on title only, `DateFormat('E')` weekday labels, no data table for screen readers.

### textScaler → FAIL (P2-A11Y-TEXTSCALE)

- No app-level `textScaler` clamp; zero `textScaler`/`textScaleFactor` references in features or core_ui (grep clean).
- Trap sites at 1.3×/2.0×: home grid `maxLines:1 + ellipsis` in fixed `childAspectRatio: 0.75` cells (`home_screen.dart:424-430,773-774`); `brand_button.dart:105-106` `maxLines:1` CTA label; `checkout_screen.dart:568-569` address `maxLines:2`; `global_error_widget.dart:59-60` `maxLines:4`. Long-form screens stack in `ListView` (dish_detail, tracker, history) ✅.
- Existing `responsive_layout_test.dart` / `form_validation_overflow_test.dart` cover default scale only — no 2.0× assertion exists.

### Touch ripple/feedback → PASS
`InkWell`/`IconButton`/`CareMessage` use Material splashes; `brand_button.dart:59-62` uses a real `ElevatedButton` (single tap path, no double-fire); `home_screen.dart:359` card `InkWell` splashes natively.
---

## §1.4 UX Consistency & Interaction Contracts

### (d-deliverable) 4-state matrix per screen

Legend: ✅ present · ❌ absent · ➖ not applicable/static.

| Screen (file) | Loading | Empty | Error | Retry | Notes |
|---|---|---|---|---|---|
| splash (`splash_screen.dart`) | ✅ :124 | ➖ | ✅ :102 | ✅ Retry :104 | — |
| onboarding | ➖ static | ➖ | ➖ | ➖ | — |
| login (`login_screen.dart`) | ✅ :219-357 | ➖ | ✅ `_error` :192-199 | ➖ re-tap | not color-only ✅ |
| signup (`signup_screen.dart`) | ✅ :169 | ➖ | ✅ SnackBar :44 | ➖ | — |
| home feed+search (`home_screen.dart`) | ✅ :225,391,512,603 | ✅ :337 | ✅ :226-232 / :704 | ✅ refresh CTA :342 | — |
| menu (`menu_screen.dart`) | ✅ skeletons :270 | ✅ :159 | ✅ :277 | ❌ | refresh overlay ✅ |
| dish_detail | ✅ :97 | ➖ | ✅ :69 | ➖ | — |
| cart (`cart_screen.dart`) | ✅ :77,134 | ✅ CTA→menu :85 | ✅ :80 | ❌ | empty pattern ✅ |
| checkout (`checkout_screen.dart`) | ✅ :481 | ✅ `emptyCart` :487 **no CTA** | ✅ :483 | ❌ | — |
| order_history | ✅ :27 | ✅ CTA→menu :37 | ✅ :32 (English) | ❌ | — |
| order_tracker | ✅ :32 | ✅ not-found :44 | ✅ :37 | ❌ | — |
| loyalty | ✅ :28 | ➖ | ✅ :33 | ➖ | non-auth msg ✅ |
| reservation | ✅ :296 | ➖ | ✅ SnackBars | ➖ | — |
| locations | ✅ :17 | ✅ text :28 **no CTA** | ✅ :22 | ❌ | — |
| pin_drop_map | ✅ :67 | ➖ | ❌ silent map :68 | ➖ | geoloc SnackBar ✅ |
| waitlist | ✅ :120 | ➖ | ❌ silent :121 | ➖ | — |
| profile | ➖ | ➖ | ✅ export SnackBar | ➖ | — |
| delete_account | ✅ :89 | ➖ | ✅ SnackBar | ➖ | — |
| admin_gateway / role_router | ✅ | ➖ | ✅ :30 / :42,57,96 | ➖ | — |
| admin_dashboard | ➖ static hub | ➖ | ➖ | ➖ | — |
| admin_menu_manager | ✅ :19 | ✅ :23 | ❌ | ❌ | — |
| kitchen_dashboard | ✅ | ✅ EmptyState ×3 :22 | ✅ :157 | ❌ | refresh ✅ |
| delivery_dashboard | ✅ | ✅ | ✅ | ❌ | — |
| manager_dashboard | ✅ :19 | ✅ :47 | ❌ | ❌ | — |
| owner_dashboard | ✅ :136 | ✅ :41 | ❌ | ❌ | per-tab streams |
| operating_hours / tier_flags | ✅ | ❌ | ✅ text | ❌ | — |
| restaurant_setup | ✅ :263 | ➖ | ✅ `'Error: $err'` | ❌ | — |
| admin_reservations_tab | ✅ :57 | ✅ | ✅ :61 | ❌ | — |
| analytics charts (2) | ✅ :39/:35 | ❌ | ❌ | ❌ | — |
| delivery_tracker | ✅ :60 | ❌ | ✅ SnackBar | ➖ | — |
| proof_of_delivery | ✅ :136 | ➖ | ✅ SnackBar | ➖ | — |
| core_ui logs_screen | ✅ :59 | ✅ :63 | ✅ :61 | ✅ :51 | debug-only |

**Loading-state naming variants:** `Center(CircularProgressIndicator)` (majority), `SkeletonLoader.listTile()` (menu), `strokeWidth:2` `Positioned` refresh overlays (isRefreshing, ≥10 screens — consistent ✅), `Semantics`-labeled spinners (`cart_screen.dart:76`, `checkout_screen.dart:480`, `loyalty_screen.dart:28`). The two English hard-coded labels (`'Loading cart'`, `'Loading checkout'`) break l10n (already counted in the string inventory).

### Pop-scope / back-loss → **FAIL (P1-UX-POPSCOPE)**

- Only `home_screen.dart:41-52` guards back (tab-reset + exit SnackBar) ✅.
- **Checkout has no PopScope** (`checkout_screen.dart`) — during `_isProcessing` (Stripe/order in flight) a back press silently leaves the screen while the server call continues; the customer may be charged without a result screen. Same on promo apply. P1.
- Other screens: no destructive back-loss ➖.

### Confirmation before destructive actions → **PARTIAL (P2-UX-CONFIRM)**

| Action | Where | Confirm? |
|---|---|---|
| Cart swipe-to-remove | `cart_screen.dart:104-122` (`onDismissed` → immediate remove) | ❌ no `confirmDismiss`, no undo |
| Clear cart | no clear-all affordance | n/a |
| Cancel order | no cancel-order action | n/a |
| Delete account | `delete_account_screen.dart` + `cannotBeUndone` | ✅ |
| Mark delivered | `delivery_dashboard.dart:147-166` confirm dialog | ✅ |
| Delete branch/menu item | `owner_dashboard.dart:529-532,780-783` | ❌ direct mutation |
| Sign out | `brand_drawer.dart` L112-116 (deleted post-audit), `profile_screen.dart:25-34` | ❌ no confirm (P3) |

### Keyboard / forms → **FAIL (P2-UX-KEYBOARD)**

Zero hits for `AutofillHints` / `textInputAction` / `onFieldSubmitted` across the tree → no autofill on login/signup (email/password contract unmet), no keyboard-submit on login, signup, reservation, checkout promo. `resizeToAvoidBottomInset` default true ✅; login/signup are `SingleChildScrollView` ✅.

### Haptics → **PARTIAL (P2-UX-HAPTICS)**

`HapticFeedback.lightImpact()` only inside `BrandButton` (`brand_button.dart:49`). Add-to-cart (menu/home/cart) and order-placed have no haptic.

### Empty-state CTA reuse → **PARTIAL (P2-UX-STATES)**

Empty cart CTA → menu ✅ (`cart_screen.dart:85-91`); empty order-history CTA → menu ✅ (`:37-44`); home-feed empty → refresh ✅. **Empty locations (`location_screen.dart:28`) and empty checkout (`checkout_screen.dart:487`) have no CTA** — the "reuse" pattern is incomplete.
---

## Enforcement-gap finding (why CI was green) → P2-A11Y-ENFORCE

The repo **has** an a11y test layer — `test/ui/accessibility_guidelines_test.dart`, `accessibility_scan_test.dart`, `semantics_accessibility_test.dart` run `meetsGuideline(androidTapTargetGuideline / iOSTapTargetGuideline / textContrastGuideline / labeledTapTargetGuideline)`, and `app_localizations_parity_test.dart` enforces arb symmetry. **But** those guideline tests pump synthetic mock scaffolds (`ElevatedButton(Text('Primary Action'))` etc.), **never the real screens** — so the unlabeled real icon buttons, the raw `$` prices, and the 2.86:1 primary-contrast failure all pass CI. The `meetsGuideline` primitives are valid enforcement points; they are just pointed at the wrong widgets.

## §2 Deliverable — per-item PASS/FAIL summary

- **P0: 0** — the prompt's hard l10n-existence gate PASSES (system exists, 532/532 en↔ar, wired). Overall still FAIL.
- **P1 (7):**
  1. **P1-L10N-STRINGS** — ≈118 literal sites bypass AppLocalizations (biggest: drawer 10, GDPR 4, force-update 2, ErrorWidget 2, router fallback 4, restaurant_setup 48, admin hub/gateway/role-router 8, order-history error, tracker status names, loading semantics, menu/home money literals).
  2. **P1-L10N-MONEY** — 3 formatters coexist; literal `$` at `menu_screen.dart:168,196`; inline non-grouped `home_screen.dart:437,777`; `admin_menu_manager.dart:32,36` default-USD foot-gun for AED/SAR clients.
  3. **P1-A11Y-CONTRAST** — white-on-#FF6B00 2.86:1, textSecondary 2.68:1, success 2.78:1 (computed) — the entire ordering path + muted copy fail AA.
  4. **P1-A11Y-CART** — unlabeled cart button + raw count digit, no item-count phrase (`animated_cart_badge.dart:25-58`).
  5. **P1-A11Y-ICONS** — 8 tooltip-less icon-only buttons incl. 2 destructive deletes (`owner_dashboard.dart:495,525,529,730,771,780`; `home_screen.dart:688`; `animated_cart_badge.dart:25`).
  6. **P1-A11Y-TRACKER** — no step semantics / current-step announcement / English status names (`order_tracker_steps_widget.dart:26-58`).
  7. **P1-UX-POPSCOPE** — checkout back press during payment is unguarded (`checkout_screen.dart`) — charge-without-result risk.
- **P2 (14):** P2-A11Y-TAP (home grid add 43,449 <48dp) · P2-A11Y-FIELD (home search hint-only, unlabeled) · P2-A11Y-CHART (no data semantics / color-only) · P2-A11Y-TEXTSCALE (no clamp/test; ellipsis traps) · P2-A11Y-COLORLIT (raw Colors in 8 files, dark-inconsistent) · P2-L10N-PLURAL (pseudo-plurals ×3) · P2-L10N-DATE (DateFormat locale-blind ×5) · P2-L10N-STATUSROLE (`.name` leaks ×6) · P2-UX-CONFIRM (cart dismissible, owner deletes) · P2-UX-KEYBOARD (no autofill/submit) · P2-UX-HAPTICS (BrandButton only) · P2-UX-STATES (locations/checkout empty no CTA; retry gaps) · P2-RTL (cart dismissible bg) · P2-A11Y-ENFORCE (guideline tests use mocks, not real screens).
- **P3 (3):** raw `'${loc.error}: $e'` interpolation consistency (5 sites) · debug-only FAB/logs literals · promo-hero config-color contrast + sign-out no-confirm.
## §2 Fix plan (execution order — fixes are NOT part of this report)

1. **P1-A11Y-CONTRAST first** (palette): darken primary to ≥4.5:1 with white in `AppColors` + both `client_config.json` color blocks; darken `textSecondary` to ≥4.5 (#757575 class); darken `success` to ≥4.5 (#388E3C). Extend `accessibility_guidelines_test.dart` to assert ratios against the **real palette**; re-baseline goldens.
2. **P1-L10N-STRINGS**: migrate the 20 app-layer strings + 15 customer strings + 48 setup strings + status/role `.name` to arb keys (en+ar), re-run parity test; delete dead `genericError` if unused.
3. **P1-L10N-MONEY**: single canonical `formatCurrencyCents` (add thousands grouping); replace literal `$` in menu/home; pass config currency at `admin_menu_manager:32,36`; retire `formatAmount`'s USD-default or require an explicit currency param.
4. **P1-A11Y-CART / ICONS**: add `tooltip:`/`Semantics` + `ExcludeSemantics` on badge count; label the 8 icon buttons (loc keys).
5. **P1-A11Y-TRACKER**: `Semantics(header: true, selected: isActive, label: loc.orderStatusX(step))` per step; live region on current step.
6. **P1-UX-POPSCOPE**: `PopScope(canPop: !_isProcessing && !_promoApplying)` + in-flight dialog following `home_screen.dart:41` precedent.
7. **P2 batch**: confirm-before-dismiss on cart, 48dp add button, home-search Semantics, chart value semantics, autofill/text-input-action on 5 forms, haptics on add-to-cart, empty CTAs, RTL mirror on dismiss background, pluralized `itemsCount`, locale-aware `DateFormat` (pass `loc.localeName`), 2.0× textScaler test, real-screen guideline scans.

## Canonical-command results

`grep Text('…'|labelText:|hintText:|tooltip:|title:)` → full inventory (this document) · `grep '\$[0-9{]'` → money strings (3 formatter families + 2 literal `$` sites) · `grep DateFormat(` → 5 sites, 3 locale-blind · `grep Colors\.(white|black|red|green|amber|grey|blue)|Color\(0x` → 18 raw-color sites (table above) · `grep IconButton(|FloatingActionButton(|InkWell(|GestureDetector('` → 20 icon-button sites; 8 unlabeled · `grep Semantics(|tooltip:` → 60+ labeled sites (majority PASS) · `grep HapticFeedback|PopScope|AutofillHints|textInputAction|textScaler` → 1 haptic, 1 PopScope, **0 autofill / 0 textInputAction / 0 textScaler** · ARB parity: 532/532 core_app, 19/19 halal_boyz ✅ · `flutter analyze`/`flutter test` → **not re-run this session** (static, report-only; master §01 records `core_app` clean + 1238 passing, which includes the parity/guideline suites).

## Honest limitations

- Static audit: TalkBack/VoiceOver were not run on device; semantics claims derive from code inspection, not runtime dumps.
- Contrast ratios are mathematically exact for the hex pairs in the two client-config theme blocks and `AppColors`; derived/alpha-composited pairs are marked `*`/`approx`.
- `DateFormat('E')` resolution depends on `Intl.defaultLocale` at runtime (the app never sets it) — flagged P2 with that caveat.
- The 4-state matrix is from code paths; flaky-network runtime behavior is audit-02’s domain, not reproduced here.
- `flutter analyze` / full `flutter test` were not executed this session (report-only); prior passing counts are cited from master §01 and file presence, not a fresh run.