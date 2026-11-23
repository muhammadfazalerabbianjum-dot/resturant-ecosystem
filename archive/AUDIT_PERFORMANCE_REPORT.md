# CARNAMA LABS — PERFORMANCE & RESPONSIVENESS AUDIT REPORT (Prompt 04)

**Audited:** 2026-08-31 · **Scope:** `core_app/lib/**`, `packages/core/lib/**`, `packages/core_ui/lib/**`
**Source of truth = the CURRENT codebase.** Report ONLY — this audit changed no code.
**Detailed evidence file; the master (`PRODUCTION_READINESS_AUDIT_MASTER.md`) carries the consolidated block.**

**VERDICT: FAIL · P0: 0 · P1: 4 · P2: 10**

| Gate | Result |
|---|---|
| Boot await chain fully enumerated | ✅ §1 |
| Every scrollable classified (virtualized / not) with expected item count | ✅ §2 |
| Every Firestore query's limit documented | ✅ §4.3 |
| Every image call site classified (transform / full-res) | ✅ §3 |
| No perf claim without code citation or explicit NOT-PROVEN marker | ✅ throughout |

---

## 1. Cold Start & App Boot — FAIL (1×P1)

### 1.1 Boot timeline — EVERY await before first `runApp` frame (main.dart:251)

| # | Step | Site (file:line) | Cost class | Verdict |
|---|---|---|---|---|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | `main.dart:142` | ~0 | ✅ correct inside `runZonedGuarded` (:140); `ErrorWidget.builder` (:90) + `PlatformDispatcher.onError` (:122) set before it deliberately (neither needs the binding). **No ordering bug.** |
| 2 | `dotenv.load()` | `main.dart:145` | asset read+parse (~ms) | ✅ |
| 3 | `AppConfig.loadConfig()` | `main.dart:150` | asset read + `jsonDecode` client_config.json | ✅ idempotent (`_loaded` `app_config.dart:314`); failure falls back to defaults (:317-322) |
| 4 | `CoreConfigHolder.set` | `main.dart:155` | sync | ✅ |
| 5 | `logger.init()` | `main.dart:160` | file exists/create | ✅ cheap (`logger_service.dart:30-36`) |
| 6 | `Firebase.initializeApp` | `main.dart:166-170` | native (tens of ms) | ✅ exactly once — `Firebase.apps.isEmpty` (:166); bg-handler path re-guards (:58-62) |
| 7 | emulator hooks | `main.dart:173-177` | — | ✅ compile-time gated — skipped in prod |
| 8 | `FirebaseAppCheck.activate` | `main.dart:180-196` | native handshake | ✅ required before first Firestore call |
| 9 | `GdprConsentDialog.hasConsent()` | `main.dart:199` | SharedPreferences first call | ✅ |
| 10 | `setAnalyticsCollectionEnabled` | `main.dart:200-202` | platform channel | ✅ |
| 11 | FCM init | `main.dart:210-225` | **unawaited** ✅ | ⚠ `requestPermission` OS dialog can surface pre-first-frame (P2-10); consent-stream listener never cancelled (:203-207) — app-lifetime singleton, documented |
| 12 | `Stripe.instance.applySettings()` | `main.dart:236-238` | platform channel | ✅ conditional on key (:236) |
| 13 | `IsarService().openDB()` | `main.dart:245` | **Isar open on UI isolate + double-open race** | ❌ P2-1 (§6) |
| 14 | **`ForceUpdateGuard` version check** | wraps app child `main.dart:252`; `initState→_checkVersion` `force_update_guard.dart:26-31`; `activate()` awaits `setConfigSettings`→`setDefaults`→**`fetchAndActivate()`** `force_update_service.dart:21-34`, `fetchTimeout: 10 s` (:23) | **network RTT — worst-case 10 s** | ❌ **P1-BOOT**: until `_checked`, `build` returns a bare spinner `MaterialApp` (`force_update_guard.dart:61-65`) → **no app UI until a Remote Config network round-trip completes**. Fail-open only on *throw* (:46-48), not on *slow* network. |

**Over-50 ms gate:** steps 8, 13, 14. Step 8 justified (required before first Firestore call). Step 14 is pure network on the critical path → **P1-BOOT**. Step 13 disk IO on UI isolate → P2-1 (NOT PROVEN — needs on-device profile).

### 1.2 Splash hard timeout
✅ **PASS — bounded.** `splashInitProvider` races auth-first-value (10 s timeout) vs 1 s cosmetic floor (`splash_screen.dart:18-33`); `_startInit` wraps it in a **30 s hard timeout** → visible `splashTimeout` retry UI (`splash_screen.dart:63-70, 82-90`). A hung config/auth cannot trap the user.

### 1.3 First frame of Home
- **Progressive ✅:** `mergedMenuProvider` is a live stream → skeletons first (`menu_screen.dart:270-275`).
- **Eager ⚠ (P2-2):** `HomeScreen` mounts **all 5 tabs synchronously** in `IndexedStack` (`home_screen.dart:33-39, 70`) — Cart (Isar load + pending-sync Isar watch, `cart_screen.dart:39-41`), Orders (limit-20 stream, `order_provider.dart:14-19`), Profile all construct on the first Home frame.

---

## 2. Rebuild Hygiene — FAIL (P1-STREAM; P2-2/3/5/6)

**Global fact: `.select(` usage across `core_app/lib`, `packages/core/lib`, `packages/core_ui/lib` = 0** (grep, this session). All watches are whole-provider watches.

### 2.1 Per-screen census (all 46 presentation files + app-level widgets)

| Screen / widget | Watched in build | Scrollables (virtualization + expected items) | Verdict |
|---|---|---|---|
| `_HomeFeedTab` (`home_screen.dart`) | `mergedMenuProvider` whole list (:216), `pendingSyncCountProvider` (:548) | hero `PageView` in `SliverToBoxAdapter` (:221-256, promos ≤ handful); chips static horizontal `ListView` (:262); menu `SliverGrid.builder` 2-col (:348-350) ✅ (catalog ≤500, `menu_repository.dart:16`); search `ListView.builder` (:729) ✅ | ✅ lists; ⚠ P2-2, P2-6 |
| hero timer | `Timer.periodic` 5 s (:165-175), guarded `hasClients && _promotions.isNotEmpty`, **cancelled on dispose** (:207-210) | — | ⚠ not lifecycle/tab-aware → P2-6 |
| `menu_screen.dart` | `mergedMenuProvider` (:46) | chips static horizontal (:80) ✅; items `ListView.builder` (:162-250) ✅ (no `itemExtent` — variable-height rows; catalog ≤500 so acceptable); skeleton `ListView.separated`×6 (:270-275) ✅ | ✅ |
| `dish_detail_screen.dart` | `menuItemByIdProvider` (:63; family over merged stream, `menu_provider.dart:26-40`) | static `ListView` (:84) — bounded | ✅ |
| `cart_screen.dart` | `cartProvider` (:39 — appropriate, renders the cart), `pendingSyncCountProvider` (:41) | `ListView.builder` (:96) ✅ — `Dismissible`+thumbnail rows (:123-138); footer `Column` + one-shot `.animate().slideX` (:236-240) | ✅ |
| `checkout_screen.dart` | `cartProvider` (:472), `restaurantConfigProvider` (:492) | `ListView` **static children** (:509) with `...cart.items.map(…)` (:632-652) — **non-virtualized but bounded ≤50** rows (`cart_provider.dart:58`), each a two-`Text` `Row` | ⚠ documented, acceptable; `AnimatedContainer` (:524-536) driven only by `_selectedLatLng` — not continuous ✅; `RestorationMixin` ✅ |
| `order_history_screen.dart` | `userOrdersProvider` (:17) | `ListView.separated` (:45) ✅ — items ≤20 (`order_repository.dart:36`) | ✅ |
| `order_tracker_screen.dart` | `singleOrderProvider(orderId)` (:23) — autoDispose family single-doc stream (:11-14) | `SingleChildScrollView`+3 children (:46-72) ✅ | ✅ |
| `order_tracker_steps_widget.dart` | — | `AnimatedContainer` (:30) driven by `currentStatus` prop | ✅ not continuous |
| `kitchen_dashboard.dart` | `restaurantConfigProvider` (:303) | `ListView.separated` (:176, :339) ✅ — items = branch+status active orders | ❌ **streams created inside build** (:140-152, :300-315) → P1-STREAM |
| `manager_dashboard.dart` | `restaurantConfigProvider` (:67) | `ListView.separated` (:81) ✅ | ❌ inline stream in build (:65-79) + **unbounded query** → P1-STREAM + P1-QUERY |
| `owner_dashboard.dart` | `authStateProvider` (:38), `restaurantConfigProvider` (:127, :244, :723), `ordersAcceptingProvider` (:973 — single-doc ✅) | orders `ListView.separated` **with cursor pagination** (:249-279; limit 20 + `startAfterDocument`, `admin_data_service.dart:103-117`) ✅ **best pattern in repo**; users tab same (:284-300 + :135-137); menu tab `ListView.separated` (:748) | ❌ inline streams in `_OverviewTab` (:125-133) + `_OwnerMenuTab` (:721-748) → P1-STREAM; menu stream uncapped (P1-QUERY, small collection) |
| `delivery_dashboard.dart` | `myOrdersProvider`/`availableOrdersProvider` (:15-22) — **`StreamProvider.autoDispose` ✅ the model to replicate** | lists (:213, :414, :454) | ✅ pattern; queries uncapped → P1-QUERY |
| `admin_menu_manager.dart` | `mergedMenuProvider` (:13) | `ListView.separated` (:24) ✅ | ✅ |
| `analytics_snapshot.dart` | `analyticsProvider` (:15; emits once — `analytics_provider.dart:19-55`), currency (:17) | — | ✅ (emit-once mislabel is correctness, not perf) |
| `revenue_chart_widget.dart` / `top_items_chart_widget.dart` | `firestoreProvider` + config (:21-22 / :18) | fl_chart over `limit(200)` sources (:33 / :29) ✅ | ✅ |
| `admin_reservations_tab.dart` | stream :32 — date-windowed (deliberate no-cap, documented :31) | list (:89) | ✅ windowed |
| `waitlist_screen.dart` | `currentUserIdProvider` (:82), `waitlistPositionProvider` family (:87) | none | ✅ |
| `reservation_screen.dart` | — | none | ✅ (capacity doc read per join only) |
| `location_screen.dart` | `locationsProvider` (limit 50) | `ListView.separated` (:29) ✅ | ✅ |
| `profile_screen.dart` / `loyalty_screen.dart` | `authStateProvider` (:15 / :17), `userLoyaltyProvider` (:24 — single-doc stream) | static | ✅ |
| `login/signup/onboarding/privacy/terms/delete/gateway/role_router/tour/pin_drop` | local `setState` only | bounded Columns | ✅ |
| `allergen_disclaimer_banner.dart` | `restaurantConfigProvider` (:14) — single doc | — | ✅ |
| `tip_selector_widget.dart` | — | 3-option map (:63) | ✅ |
| `brand_drawer.dart` | 3 providers (:16-21) | static drawer `ListView` (:31) | ⚠ **never mounted** (grep: definition only) → P2-8 |
| `animated_cart_badge.dart` | **whole `cartProvider`** (:14-20), re-folds quantities per tick | — | ❌ P2-5 |
| `logs_screen.dart` (core_ui) | — | `ListView.builder` (:64) — debug route | ✅ |
| `main.dart` shell | `appRouterProvider`+`themeModeProvider` (:315-316) | — | ✅ stable; router recreated only on auth change (`app_router.dart:161-163`) |

### 2.2 Continuous-rebuild constructs
- `AnimatedBuilder`/`TweenAnimationBuilder`/`AnimatedSwitcher`: **0** (grep). `AnimatedContainer`: 2 sites, both event-driven (checkout :524, tracker-steps :30) ✅.
- `Timer.periodic` census: hero carousel 5 s (above) + `cloud_function_mocks` 2×60 s daemons auto-started on provider watch (`cloud_function_mocks.dart:17, 42-63`) — sole watcher (`admin_dashboard.dart` L10, deleted P9/T-5; pinned by `core_app/test/app/deleted_sources_pin_test.dart`) is **not in any route table** → dead today; background churn if ever mounted → P2-7. **No high-frequency UI polling exists.**

---

## 3. Image Strategy — FAIL (P1-IMG; P2-3/9)

### 3.1 Every call site classified

| # | Site | Widget | Cloudinary transform? | memCache (decode cap) | Placeholder | Error | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | `home_screen.dart:380-386` (feed grid, highest traffic) | `CachedNetworkImage` | ❌ raw URL | `memCacheWidth: 400` ✅ | ✅ | ✅ | decode-capped, **full-res download** |
| 2 | `home_screen.dart:748-764` (search rows) | `CachedNetworkImage` | ❌ | `memCacheWidth: 100` ✅ | ✅ | ✅ | same |
| 3 | `menu_screen.dart:174-188` (menu list rows) | `CachedNetworkImage` in `Hero` | ❌ | `memCacheWidth/Height: 100` ✅ | ✅ `SkeletonLoader` | ✅ | same |
| 4 | `cart_screen.dart:125-138` (cart rows) | `CachedNetworkImage` | ❌ | `memCacheWidth: 150` ✅ | ✅ | ✅ | same |
| 5 | `dish_detail_screen.dart:90-104` (detail hero) | `CachedNetworkImage` | ❌ | **none** — full-res decode | ✅ | ✅ | ❌ P2-3 |
| 6 | `owner_dashboard.dart:917-929` (admin editor preview) | `CachedNetworkImage` | ❌ | none | ✅ | ✅ | admin-only, minor |
| 7 | `proof_of_delivery_service.dart:103` | `Image.network` | ❌ | none | ❌ none | ❌ none | ❌ P2-9 |
| 8 | `packages/core_ui` | — | — | — | — | — | 0 image call sites ✅ |
| 9 | asset images | launcher/icons only; **no `Image.asset` in any list** | — | — | — | — | ✅ |

### 3.2 Transform pipeline — FINDING P1-IMG
- Uploads store the **raw `secure_url`** with no eager/named transforms (`cloudinary_upload_service.dart:36-66`); picker pre-compression exists (:18-24, 1024 px / q80 — helps *new* uploads only).
- **No client-side transform insertion anywhere in the display path** (grep `c_fill|q_auto|f_auto|/upload/` → only the upload endpoint constant :41). `memCacheWidth` caps decode memory, but the **network bytes and disk-cache entries are still the full-resolution originals** on every menu row — the highest-traffic images in the app.
- Disk cache: `cached_network_image` default `DefaultCacheManager` — **bounded** (library default 200 entries / 30-day stale period; no custom config in repo — grep 0). ✅ not unbounded.
- `Hero` double-decode: list sources decode at 100/400 px while the detail hero decodes uncapped → different provider keys → decoded twice during the flight (home :378 → dish :90; menu :172 → dish :90) → P2-3.
- `precacheImage`: **0 uses** ✅ (sane by absence).

---

## 4. Memory & Leak Behavior — FAIL (P1-QUERY; P2-4/5)

### 4.1 Isar retention/TTL per collection (`isar_service.dart`)

| Collection | Cap | TTL | Enforced where | Verdict |
|---|---|---|---|---|
| `IsarMenuItem` | 500 (:23) | 24 h (:25) | `evictStaleCache` :73-95, run at `openDB` :53-54 | ✅ (full-table scan + Dart filter :74-80 — fine at ≤500) |
| `IsarCart` | — | 7 d **declared** (:26) | **eviction skipped** — comment :85-86 | ❌ P2-4 |
| `IsarPendingOperation` | 100 (:24) | none — orders never age out by design (`sync_queue.dart:146-148`) | cap enforced **only at boot** :87-109 | ⚠ P2-4 (session growth) |
| `IsarDeadLetter` | **none** | **none** | no purge/reaper anywhere (`sync_queue.dart:125-137` only moves ops IN) | ❌ P2-5 — unbounded |
| `analyticsEvents` (Firestore) | — | — | prod path = Cloud Function (`telemetry_service.dart:36`); demo direct-write forbidden in release (`main.dart:71-79`) | ✅ |
| `presence/{uid}` (Firestore) | — | — | per-uid doc, merge-set on lifecycle (`presence_service.dart:37-49`) | ✅ bounded |

### 4.2 `includeMetadataChanges: true` — **0 occurrences** ✅ (grep).

### 4.3 Firestore query census — every query with its limit

**UNBOUNDED (FINDING P1-QUERY):**

| Query | Site | Feeds | Expected scale |
|---|---|---|---|
| `menus` where `branchId == null` (live) | `merged_menu_provider.dart:120-123` | Home grid, Menu list, DishDetail, AdminMenuManager | catalog (~50-500; uncapped) |
| `menus` where `branchId == branch` (live) | `merged_menu_provider.dart:135-141` | same | overrides, uncapped |
| `orders` branch+`status ∈ {confirmed, preparing}` (live) | `kitchen_service.dart:27-37` | kitchen preparing tab | grows with busy day |
| `orders` branch+`status == ready` (live) | same | kitchen ready tab | grows |
| `orders` driver + `status ∈ {ready, pickedUp}` (live) | `delivery_service.dart:28-43` | driver "my orders" | small but uncapped |
| `orders` branch+`status == ready` (live) | `delivery_service.dart:46-58` | driver "available" | grows |
| `orders` where `branchId` — **no status, no window, live** | `admin_data_service.dart:238-241` | manager dashboard | **entire branch history, unbounded** |
| `menus` all (live) | `admin_data_service.dart:252-253` | owner menu tab | catalog, uncapped |
| `branches` all (live) | `admin_data_service.dart:190-191` | branch editor | small — documented |
| `admins` all (live) | `admin_provider.dart` L18-19 (deleted P9/T-5; pinned by `core_app/test/app/deleted_sources_pin_test.dart`) | role router | tiny — documented |
| `waitlist` by branch (live) | `waitlist_repository.dart:104-106` | position | small — documented |
| `orders` by status ∈ active (one-shot get) | `analytics_provider.dart:36-39` | owner overview | bounded by active set — documented |
| `notification_queue` / `menus` (live) | `cloud_function_mocks.dart:169-170, 237-238` | mock daemons | dead code (P2-7) |

**BOUNDED (PASS evidence):** `getUserOrders` limit 20 (`order_repository.dart:36`) · `loadOrders`/`loadUsers` limit 20 + `startAfterDocument` (`admin_data_service.dart:103-137`) · charts `limit(200)` (`revenue_chart_widget.dart:33`, `top_items_chart_widget.dart:29`) · overview stats 24 h window (`admin_data_service.dart:70-73`) · `analyticsProvider` today-window get (`analytics_provider.dart:31-35`) · reservations date window (`admin_reservations_tab.dart:22-32`) · locations limit 50 · promotions one-shot `isActive`+orderBy (`home_service.dart:70-73`) · single-doc streams: `settings/restaurantConfig` (`restaurant_config_service.dart:21-26`), feature flags (`feature_flags_service.dart:31-34`), `loyalty/{uid}` (`loyalty_provider.dart:12`), `orders/{id}` (`order_repository.dart:20`), panic-switch doc (`panic_switch_service.dart:32-35`) · Isar refresh `limit(500)` (`menu_repository.dart:99`).

### 4.4 Large JSON on the UI isolate — **NONE today**
Menu sync maps docs per-doc under the 500 cap (`menu_repository.dart:98-119`); sync-queue decodes one small op payload at a time (`sync_queue.dart:42, 151-154`); config JSON is KB-scale. ✅ (Re-evaluate only if menu moves to a single bulk blob.)

### 4.5 Misc
`precacheImage`: 0 ✅ · Driver GPS throttled by design (30 m `distanceFilter` + 20 m publish threshold, `driver_location_service.dart:55-96`) ✅ · FCM token saved merged into `users/{uid}` (`fcm_service.dart:56-75`), errors contained ✅.

---

## 5. Navigation Performance Under Config Mode — PASS

- **Routes are lazy:** config-driven routes emit `GoRoute`s whose `pageBuilder` closures construct widgets **on demand** (`app_router.dart:148-157` → `_getScreenWidget(id, s)` switch, :47-70); the static fallback table is likewise builder-based (:221-451). No map of pre-built instances. ✅
- **No work in builder closures beyond widget construction:** closures only read `state.uri.queryParameters` / `pathParameters` / `extra` (:61, :64-67). ✅
- **Redirect is O(1) per hop:** reads **already-resolved** provider values — `authState.valueOrNull` (:180), `userState.valueOrNull` (:181) — zero `await`, zero Firestore reads per navigation. `currentUserProvider` is a cached `FutureProvider` resolved once per auth change (`auth_provider.dart:12-16` → single `users/{uid}` read, `auth_repository.dart:54`). ✅
- Note: the `GoRouter` is recreated when auth state changes (`app_router.dart:161-163`) — rare event, intentional for redirect freshness; not a per-hop cost.

---

## 6. Findings — P1 (4)

### P1-BOOT — First frame is blocked behind a Remote Config network fetch
`ForceUpdateGuard` wraps the entire app (`main.dart:252`). Its `initState` fires `_checkVersion()` (`force_update_guard.dart:26-31`) which awaits `activate()` → **`fetchAndActivate()`** (`force_update_service.dart:34`, `fetchTimeout: 10 s` :23) + `PackageInfo.fromPlatform` (:56). Until `_checked`, `build` renders a **bare spinner MaterialApp** (`force_update_guard.dart:61-65`). Consequence: on a slow-but-alive network the user stares at a spinner for up to **10 s before any app UI exists** (splash never shows, no retry affordance). Fail-open only covers a *thrown* fetch (:46-48), not a slow one. This is the single worst cold-start defect in the template. *(Measured ms: NOT PROVEN — needs profiling on mid-range Android; the 10 s ceiling is proven by `fetchTimeout` at `force_update_service.dart:23`.)*

### P1-QUERY — Seven live streams + one admin history stream have no limit/window
Full census in §4.3. Worst: `streamOrdersByBranch` (`admin_data_service.dart:238-241`) streams the **entire order history of a branch, live, forever** into the manager dashboard — memory and bandwidth grow with every order ever placed. Kitchen/delivery streams are operationally bounded (transient statuses) but have no safety cap, unlike the repo's own precedents (`kMenuMaxItemsSafetyCap`, `limit(200)` charts, 24 h window, cursor pagination). The two `menus` streams (`merged_menu_provider.dart:120-141`) are the app's primary data path and are uncapped.

### P1-STREAM — Firestore streams created inside `build` (re-subscribe churn + loading flashes)
`kitchen_dashboard.dart:140-152` & `:300-315`, `manager_dashboard.dart:65-79`, `owner_dashboard.dart:125-133` & `:721-748` call `ref.read(service).streamX(...)` **inside `build`** and hand the fresh stream to a `StreamBuilder`. Every rebuild of those widgets (theme/locale change, parent setState, `restaurantConfigProvider` emission) re-subscribes the Firestore listener: snapshot resets to `ConnectionState.waiting` → the list flashes a spinner and refires listener setup. `delivery_dashboard.dart:15-22`, `order_tracker_screen.dart:11-14` and `waitlist_screen.dart:87` prove the correct in-repo pattern (`StreamProvider.autoDispose[.family]`).

### P1-IMG — Menu thumbnails (highest-traffic images) download full-res originals
Upload stores the raw Cloudinary `secure_url` (`cloudinary_upload_service.dart:58-60`); no transform params are inserted at any of the 4 list display sites (§3.1). `memCacheWidth` bounds *decode*, not *download*: every Home-grid / Menu / Search / Cart row pulls the original file over the network and caches the original on disk. On mid-range Android over LTE this is the dominant scroll cost. *(Per-row ms NOT PROVEN — needs device profile; the absence of transforms is proven by grep + upload code.)*

---

## 7. Findings — P2 (10)

| # | Finding | Evidence |
|---|---|---|
| P2-1 | Isar opened at boot on the UI isolate **and opened twice concurrently**: `IsarService()` constructor starts `db = openDB()` (`isar_service.dart:19`), then `main.dart:245` calls `IsarService().openDB()` again — the `Isar.instanceNames.isEmpty` check (:41) evaluates before the first open registers → both call `Isar.open`; the loser's error is swallowed by main's try/catch (:244-249). Dead weight + race; the real open cost is **NOT PROVEN** (needs device profile). |
| P2-2 | `IndexedStack` builds all 5 tabs on first Home frame (`home_screen.dart:33-39, 70`) — Cart Isar load + limit-20 orders stream + profile start at boot. |
| P2-3 | Hero decode mismatch: list rows decode at 100/400 px, detail hero uncapped (`dish_detail_screen.dart:90-104`) → double decode per dish open. |
| P2-4 | Cart TTL eviction skipped (`isar_service.dart:85-86`); pending-ops cap enforced only at boot (:87-109) — both eviction paths are startup-only. |
| P2-5 | `IsarDeadLetter` has **no cap, no TTL, no reaper** (`sync_queue.dart:125-137` only moves ops in; `deadLetterCountProvider` only counts, `pending_sync_provider.dart:31-37`). |
| P2-6 | Hero carousel `Timer.periodic` not app-lifecycle/tab-aware (`home_screen.dart:165-175`) — keeps animating while app is backgrounded or another tab is shown (dispose cancels, :207-210). |
| P2-7 | `cloudFunctionMocksProvider` auto-starts two 1-min timers + two collection listeners on first watch (`cloud_function_mocks.dart:17, 42-63`); sole watcher `AdminDashboard` (:10) is unrouted — dead code that becomes background churn if ever mounted. |
| P2-8 | Dead widgets: `BrandDrawer` never mounted (grep: definition only) — 3 provider subscriptions waiting to happen; `FirestorePaginator` utility never used (self-references only, `firestore_paginator.dart` L7,24 (deleted post-audit)) while owner orders hand-roll identical pagination (`owner_dashboard.dart:224-239`). |
| P2-9 | `proof_of_delivery_service.dart:103` raw `Image.network` — no placeholder, no error widget, no disk cache (full-res). |
| P2-10 | FCM `requestPermission` kicked pre-`runApp` (`main.dart:210`) — OS permission dialog can appear before the first Flutter frame; `GdprConsentDialog.onConsentChangedStream.listen` (:203-207) never cancelled (app-lifetime singleton — acceptable, documented). |

---

## 8. Fix plan (priority order) — full option analysis lives in the master's Proven Best-Fit table

1. **P1-BOOT**: relocate the force-update *await* into `splashInitProvider` (runs in parallel with the existing auth wait; bounded by the splash's 30 s timeout + fail-open + retry UI, `splash_screen.dart:18-33, 63-70`) and demote `ForceUpdateGuard` to enforcement-renderer only (no pre-check spinner). Zero new libraries; splash remains the designated init funnel.
2. **P1-QUERY**: named caps/windows per stream, mirroring in-repo precedents — kitchen/delivery/status streams get a named `limit` + `orderBy`; `streamOrdersByBranch` gains a 24 h window (matching `streamOverviewStats` :70-73); menu streams get the named safety cap. Owner history already paginates correctly — replicate, don't invent.
3. **P1-STREAM**: hoist kitchen/manager/owner-tab streams to `StreamProvider.autoDispose.family` keyed by `(branchId, statuses)` — the exact shape of `delivery_dashboard.dart:15-22` and `singleOrderProvider`.
4. **P1-IMG**: pure `cloudinaryThumb(url, width)` helper in `packages/core` (beside `cloudinary_upload_service.dart`) inserting `w_<w>,q_auto,f_auto` after `/upload/`, passthrough for non-Cloudinary URLs; apply at the 4 list sites; then align dish-detail decode (`memCacheWidth`) to kill P2-3.
5. **P2 batch**: single guarded `openDB` (remove the explicit boot call OR the constructor call), add a DLQ reaper/TTL + enforce cart TTL at boot eviction, `select` the cart badge count, make the hero timer `AppLifecycleState`-aware, delete-or-route `AdminDashboard`/`BrandDrawer`, adopt-or-delete `FirestorePaginator`, fix the POD image site.

---

## 9. Canonical commands (this session)

- `flutter analyze --no-pub` (core_app): **No issues found** (Flutter 3.41.2 stable, 81.6 s).
- `flutter test`: **not re-run this session** (static audit; master §01 already records `core_app` clean + 1238 passing).
- Greps cited inline: `.select(` = 0 · `includeMetadataChanges` = 0 · `precacheImage(` = 0 · `Hero(` = 2 (home :378, menu :172) · `Timer.periodic` = 3 (hero 5 s, mocks 2×60 s) · `AnimatedBuilder` = 0 · `FirestorePaginator(` callers = 0 · `BrandDrawer` callers = 0 · image call sites = 7 (§3.1) · `memCacheWidth` present at 4/7.

## 10. Honest limitations

- **Runtime claims (cold-start ms, scroll jank, memory MB) are NOT PROVEN** — no mid-range device/profiler was available this session. Every such claim is marked NOT PROVEN; structural findings are code-proven.
- Boot-await costs are cost-*classes* (asset read, platform channel, network), not measurements.
- `apps/halal_boyz/lib` contains **0** `CachedNetworkImage`/`Image.network` sites — the generated shell does not mirror the template's feature screens; findings apply to `core_app` (the client template) and `packages/*` (shared by both).
- Remote-Config `fetchAndActivate` cache behavior (fast-path when fetched < `minimumFetchInterval`) is platform behavior, not repo code — the 10 s worst case stands for cold fetches / flaky networks.
- The Flutter-cache-manager bound (200 entries / 30 days) is the library's documented default; no repo code changes it (grep 0).

---

**END OF AUDIT 04 DETAILED REPORT · VERDICT: FAIL (0×P0 · 4×P1: BOOT → QUERY → STREAM → IMG; 10×P2 hardening debt)**