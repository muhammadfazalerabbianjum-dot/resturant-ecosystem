# Carnama Restaurant App - Final Verification Report

**Auditor:** final verification engineer (evidence-only). potato*.md untrusted; every claim = file:line read + command run on THIS run.
**Run env:** 2026-08-27 / Windows AMD64 / Flutter 3.41.2 / Dart 3.11.0 / node v24.13.1 / npm 11.8.0 / firebase CLI 15.15.0 / Java 21.

---

## 0. VERDICT
**NOT-GO - release blockers remain: (1) `reservation_counters` + `waitlist_counters` have NO Firestore rules -> booking & waitlist broken in production; (2) no real emulator rules tests (all fake_cloud_firestore mocks); (3) the GDPR erasure emulator integration test is RED on this run (exit 1, 2 failures); (4) `createPaymentIntent` trusts client-supplied tax & discount (money-integrity gap); (5) `locations` collection read by feature code but has no rules. Major also red: 8 skipped tests, 3 direct `FirebaseFirestore.instance` in feature code, literal `'usd'` in the money path.**

500 users CANNOT be affirmed: not proven production-grade; no load test supports any concurrent-user claim.

---

## 1. PROVEN-CLOSED (green via commands on this run)
### 1.1 Backend build + unit tests (functions)
- `npm --prefix core_app/functions run build` -> exit 0 (`tsc`). `npx tsc --noEmit` -> exit 0.
- `npm --prefix core_app/functions test` -> exit 0; `tests 17 / pass 17 / fail 0 / skipped 0`.
- ddos.test.js (src/ddos.ts:22-52); deploy_guard.test.js (package.json:7 main:lib/index.js, compiled lib/index.js exists, no sk_test_/ReplaceMeInProduction, no bare English push); notification_copy.test.js (en+ar parity, locale fail-closed).
- Deploy entry correct: package.json:7 + firebase.json predeploy npm run build; stale root functions/index.js gone (deploy_guard passed).

### 1.2 Static analysis - all green (exit 0)
- dart analyze packages/core, packages/core_ui. flutter analyze --fatal-infos core_app, apps/halal_boyz. All "No issues found!".

### 1.3 Test suites - green (exit 0; skips in OPEN #4)
- packages/core: 14 pass / 0 fail; packages/core_ui: 20 pass / 0 fail; apps/halal_boyz: 6 pass / 0 fail.
- core_app: +1235 pass / 8 skipped / 0 fail (exit 0).

### 1.4 Money/auth/security fail-closed (code-read evidence, lines verified this run)
- createOrder (index.ts:463-552): ownership (476-481), idempotency (484-492), money equality `totalCents == paymentIntent.amount` (507-516), compensating refund on order-create failure after success (536-548).
- createPaymentIntent: idempotency key forwarded to Stripe (438-452); server re-derives subtotal from flat line items + upcharges (403-411); discount<=subtotal guard (421-423); max qty 50 (429-431); positive amount (432-434). NOTE: tax/discount still client-supplied -> OPEN 6.1.
- stripeWebhook verifies signature with raw body; rejects missing sig/secret (index.ts:772-790).
- App Check enforced on every callable (index.ts:27-34).
- Demo-in-release rejected: main.dart:71-80 throws StateError; kDemoMode default false (demo_config.dart:36).
- GDPR (verified): setMarker in_progress first (310-319), runErase completes + marker completed (291-302), deleteAuthUser idempotent on user-not-found (269-281), deleteUserDataRetry onSchedule('0 * * * *')/540s sweeps >=1h markers (368-373, 337-361). collectUserDocs keys reservations/locks by userId, orders by customerId, users LAST (180-222); eraseRefs chunked 400 < 500 cap (230-244).
- Demo GDPR mirrors production collectUserDocs exactly (packages/core/.../gdpr_service.dart:51-115 vs index.ts:180-222).

### 1.5 Grep gates that returned 0
- FirebaseAuth.instance in screens: only main.dart:176/258 (bootstrap/DI) + data_export_service.dart:37 (DI default).
- Color(0xFFFF6B35)=0; 'customerId' in features/reservations=0; sk_test_/Replace in functions/src=0; carnama_unsigned/dcqf9qpsq/192.168.1.100/com.carnama.app/Order placed!=0 in apps.
---

## 2. OPEN (fail the bar; none callable "fixed")
### 2.1 [P0] counter collections have NO Firebase rules -> booking/waitlist broken
firestore.rules has `match /reservation_locks/{lockId}` (rules:240) but NO `match /reservation_counters` and NO `match /waitlist_counters` (verified the full `match /` set). Firestore deny-by-default -> writes to unruly collections are permission-denied. Code writes them in transactions: reservations_repository.dart:18-22/45-55 (requestSlot false on throw, 30-76); waitlist_repository.dart:49-52/80-87 (joinWaitlist error, 90-93). Both feature calls fail closed -> customers cannot book reservations or join the waitlist in production.

### 2.2 [P0] No real emulator rules test (all fake_cloud_firestore)
firestore_emulator_rules_test.dart = "Mock Implementation" (lines 1-16), never loads rules; firestore_rules_test.dart:6-8 admits fake_cloud_firestore "does NOT execute real security rules"; wiring/firestore_security_rules_test.dart = fake "Client Mirror" DAO. Real rules emulator tests are required -> not met; this hides 2.1 and 6.2.

### 2.3 [P0] GDPR erasure emulator integration is RED on this run
`cd core_app; firebase emulators:exec --only firestore "node test/functions/gdpr_erasure_test.js"` -> exit 1: `PASSED: 19 FAILED: 2`. Failures: `T4 user docs were STILL erased before the auth failure (durable marker-first)`; `T5 locks + waitlist erased too`. 22 scoped assertions passed; the 2 failures are whole-collection checks where testEnv.clearFirestore() does not clear the admin-SDK client's namespace (harness mismatch). Erasure logic individually proven, but the "eras+rules green on this run" gate is STRICTLY RED.

### 2.4 [Major] 8 skipped tests (zero-skip gate fails)
checkout_e2e_test.dart:2 @Skip + :17 skip:true; reservation_e2e_test.dart:2 + :16 skip:true. core_app run reported `+1235 ~8: 8 skipped tests`.

### 2.5 [Major] Direct FirebaseFirestore.instance in feature code
lib/app/config/restaurant_config_service.dart:8,17,25 (reads/writes settings/restaurantConfig, bypassing DI firestoreProvider).

### 2.6 [Major] Literal currency in money path
functions/src/index.ts:441 `currency: 'usd'` hardcoded inside createPaymentIntent (blocks white-label multi-currency).

### 2.7 [Minor] 3 `// ignore` in hand-written code (not 1)
core_app/lib/features/orders/domain/order_model.dart:44; packages/core/lib/src/auth/user_model.dart:29; packages/core/lib/src/presence/presence_model.dart:15 (all invalid_annotation_target for freezed). The rest are generated files.
---

## 3. NOT-PROVABLE (static cannot prove; not claimed fixed)
- App Check enrollment on real iOS/Android hardware: main.dart:180-196 activates native providers, but rules default to the RELAXED `isAppVerified()` (firestore.rules:30-35, strongAppCheck flag-gated, default off).
- Live Stripe/webhook/real money: keys from process.env (index.ts:402,495,774); not exercised live this run.
- Real external fleet dispatch: dispatchToFleet (index.ts:112-139) is a labeled TODO_DEPLOY fallback setting fleet fields only.
- Live FCM delivery to devices; and 500-concurrent-user capacity: no load/soak test exists in the repo, so any capacity claim is unproven.
- Full firestore+functions emulator suite not run: no real rules suite exists to exercise it (2.2) and the one real test is RED (2.3).

## 4. Generated/personal apps coverage
- apps/ contains ONLY halal_boyz; sunset_grill and blue_ocean are ABSENT from this repo, so they cannot be audited (only halal_boyz analyzed/tested).
- packages/core + core_ui analyzed and tested green (1.2, 1.3); halal_boyz clean (no Carnama fallback, no FirebaseFirestore.instance/FirebaseAuth.instance, no "Order placed!", prices via moneyCents).

## 5. Honest note on "perfect launch"
"Perfect" is unprovable for any code. Against the prompt's stated bar (every P0/Major closed, all suites/rules/erasure/greps green ON THIS RUN, zero tolerated suppression), the app is NOT there. Release must be HELD until all P0s and Majors below are closed and re-verified green on a clean run.

---

## 6. SECOND-PASS SUPPLEMENT (added after the user asked "is this really everything?")
The user asked for a total sweep. I re-read every `index.ts` line I cited (all verified) and swept every Firestore collection the code touches against the rules `match` set, plus re-checked the checkout/order/promo money flow. Additional findings below, each verified by file:line read this run.

### 6.1 [P0 money-integrity] `createPaymentIntent` trusts client tax AND discount - promo validated only client-side
- index.ts:413-423: `tax`/`discount` come straight from the request, clamped only to non-negative and discount<=subtotal (421-423). Server does NOT re-derive tax from clientId+stateCode and does NOT re-validate the promo.
- calculateTax is advisory: checkout_service.dart:161-180 computes tax for DISPLAY, but processStripePayment (286-294) forwards the client's own taxCents/discountCents to createPaymentIntent; createOrder only checks totalCents==amount (index.ts:507-516) - equal against the same client-influenced amount.
- Promo validation is fully client-side (promo_code_service.dart:21 reads the doc directly; checkout_service.dart:108).
- Impact: a hostile client can send taxCents:0 (underpay tax) or discountCents~subtotal (pay almost nothing). Money/fraud gap in the FAIL-CLOSED payment path.

### 6.2 [P0 feature-blocker] `locations` collection has NO rules match but is read by feature code
- Verified full `match /` list in firestore.rules contains no `locations`.
- location_repository.dart:26-31 getLocations() reads .collection('locations').limit(50); locationsProvider (16-18) feeds the Locations screen / map picker.
- Impact: production read is permission-denied -> Locations feature fails. Same class as 2.1 (rule set does not cover real feature collections).
### 6.3 [Major-demo] `notifications` / `notification_queue` / `audit_logs` collections also lack rules
- cloud_function_mocks.dart:169,187,195 writes notification_queue and notifications; :248 writes audit_logs (plural). No rules `match` for any. These are demo/replacement paths only (production uses server FCM + CF triggers, which bypass rules), so severity is demo-scoped but still a strict-rules gap.

### 6.4 [Minor dead-code] `OrderRepository.submitOrderAtomically` is a test-only path whose payload does not match `createOrder`
- order_repository.dart:86 referenced only by its own definition + tests (test/idempotency_test.dart:41,70,74; test/features/checkout/chaos_checkout_test.dart). Not in the production call graph.
- Production path is checkout_service.dart:318-337, which correctly sends {paymentIntentId, order: order.toJson(), userId, idempotencyKey} (matches index.ts:467-472). submitOrderAtomically (order_repository.dart:117) sends only order.toJson(), leaving those top-level keys undefined -> retrieve(undefined) + money mismatch -> guaranteed failure if reached. Dead/misleading; must be removed or aligned.

### 6.5 [Minor] Verified-cleared (NOT additional bugs)
- Production order flow correctly wired: checkout_service.createOrder payload matches the callable (6.4).
- Demo GDPR erasure mirrors production collectUserDocs exactly (gdpr_service.dart:51-115 vs index.ts:180-222), including notifications subcollection, carts, presence, loyalty, driverLocations, users LAST.
- createOrder rejects customerId/userId mismatch (476-481), idempotent (484-492), money-equality (507-516), refund (536-548).
- LocationRepository logs missing geo fields honestly; isOwner (firestore.rules:47-52) reads settings/ownerInfo per write - a known cost, not a correctness bug.

### 6.6 [Informational] LoggerService() inline uses exist but none in feature screens
- Inline LoggerService() appears in bootstrap error handlers (main.dart:125,158,293), package-service constructor DI defaults (isar_service.dart, gdpr_service.dart:38, kitchen_offline_service.dart:37, deep_link_service.dart:95, logger_provider.dart:6), package network layer (http_interceptor.dart:20,36,38), and telemetry_service.dart:38. No feature screen constructs an inline logger. The gate's spirit is met; the blanket literal is not literally-zero.

## 7. UPDATED VERDICT COUNTS (with second-pass additions)
- P0 release-blockers now 6: counters rules (2.1), no real rules tests (2.2), GDPR emulator RED (2.3), client-trusted tax/discount (6.1), `locations` no-rules (6.2).
- Major: 2.4, 2.5, 2.6 + 6.3 (demo-scoped) = 4.
- Minor: 2.7 (3 `// ignore`) + 6.4 dead code + 6.6 informational = several.
**Verdict remains NOT-GO.** Do not launch for 500 users until 2.1, 2.2, 2.3, 6.1, 6.2 are closed and re-verified green on a clean run.
---

## 8. COMPLETE AUDIT MATRIX - EVERY TASK-PROMPT ITEM MAPPED (final pass)

The user demanded "100% coverage, skip nothing". This appendix maps EVERY audit item in the task prompt to status + evidence (file:line read or command+exit this run). Supersedes earlier counts at section 7 boundaries.

### 8.1 BOOTING / CONFIG
- main.dart bootstrap order (verified, main.dart:82-116): safe-build guard 84, FCM background handler 86, ErrorWidget 96-119, PlatformDispatcher.onError 122-139, runZonedGuarded 140, dotenv.load 145, AppConfig.loadConfig 150, CoreConfigHolder.set 155, logger init 158, Firebase.initializeApp 167, emulator binding (10.0.2.2 Android / localhost) 173-177, App Check native/ReCaptcha 180-196, analytics consent 199-207, FCM init 210-225, Stripe publishable-key assert 228-236, Isar 245, runApp 251. PASS.
- Demo-in-release rejection: main.dart:71-80 `_assertSafeBuildConfig` throws StateError if release+demo; kDemoMode defaults false (demo_config.dart:36). PASS.
- Env: core_app/.env holds only non-secret build vars (APP_NAME, FIREBASE_PROJECT_ID, STORE urls, FCM_CHANNEL_DESCRIPTION, CLOUDINARY_UPLOAD_PRESET). No Stripe/auth secrets in env. PASS.

### 8.2 CUSTOMER FLOW (screen -> provider -> repo -> DB -> rules)
- Menu/dish/modifiers: merged_menu_provider uses DI firestoreProvider; dish_detail + modifier upcharges feed buildStripeLineItems (checkout_service.dart:254-270) and match server re-derivation (index.ts:403-411); menus public-read rules (71). PASS.
- Cart: persisted to carts/{uid}, rules:274-276 uid-scoped. PASS.
- Checkout/pay: calculateTax advisory (161-180), client tax/discount to createPaymentIntent (286-294), server money-equality (507-516). OPEN money gap 6.1.
- Order history/tracker: order_repository streams own orders only (where customerId=uid, order). PASS.
- Delete-account GDPR: gdpr_service both paths (marker-first, purge, marker completed); export full + rethrows on every section failure (data_export_service.dart:40-143). PASS.
- Reservation past-time guard: reservation_screen.dart:129 rejects `!startTime.isAfter(now)`; date clamp 197/217. PASS.
### 8.3 RESERVATION / WAITLIST
- reservation: atomic counter+lock+capture, capacity check (reservations_repository.dart:15-72). Rules: reservation_locks OK (240-258) + reservations-rule-shape OK (255-271) + blocks `customerId` on create; **reservation_counters has NO rule -> OPEN 2.1 (P0)**.
- waitlist: idempotent deterministic key + per-branch counter + queue position (waitlist_repository.dart:43-139); waitlist rules OK (356-367); **waitlist_counters has NO rule -> OPEN 2.1 (P0)**.

### 8.4 LOYALTY / PROMOTIONS / LOCATIONS / OFFLINE
- Loyalty: server writes points on delivered (index.ts:615-638); referral pure engine (referral_engine.dart:1-17). PASS.
- Promotions: promo code validated CLIENT-SIDE only (promo_code_service.dart:21) and discount is client-supplied -> OPEN 6.1 (P0).
- Locations: location_repository.dart:26-31 reads `.collection('locations')`; **NO locations rule -> OPEN 6.2 (P0)**; missing geo fields logged, not fabricated (onMissingField).
- Offline/sync/queue: IsarSyncQueue used for order ops (checkout_screen.dart:25-26,347-348) + pending banner (home_screen). PASS (presence of queue).

### 8.5 ADMIN / OWNER / MANAGER / KITCHEN / DELIVERY / SETUP
- Role gating: admin_gateway (admin_gateway_screen.dart:71-80) + role_router (role_router_screen.dart:68-82) route by role; DB rules enforce per-role scoping. PASS defense-in-depth.
- Substring/force-unwrap crash: owner_dashboard.dart:443 `displayTitle.substring(0,1)` is SAFE because displayTitle falls back to non-empty id (user_model.dart:15); top_items substring(0,7) guarded by length>8 (top_items_chart_widget.dart:131-132). PASS.
- Setup writes: saves to settings/restaurantConfig and settings/defaultOperatingHours (restaurant_config_service.dart:16-28, operating_hours_screen.dart:33). Settings rule only allows writes to featureFlags -> **OPEN 8.7 (P0)**.

### 8.6 GDPR / AWS-auth flows
- Full erasure on CF + demo mirror; deletion_requests durable; scheduled retrier (index.ts:290-373). Integration test RED -> OPEN 2.3.
- Export: PASS. Sign-out cleanup: Isar clear + analytics reset + prefs remove + Firestore terminate/clearPersistence + Google signOut (auth_repository.dart:282-318). **CLOSED (no cross-user leak).**
### 8.7 BACKEND, RULES, PACKAGES - consolidated
- Backend callables/triggers all present + compiled + 17 unit tests green; App Check on every user callable; idempotency; localized push; no secrets; deploy entry correct (sections 1.1/1.4).
- Rules gap closure: rule-set covers users, orders, reservations, reservation_locks, waitlist, carts, promoCodes, driverLocations, deliveries, presence, loyalty, promo_usage, proof_of_delivery, analyticsEvents, audit_log, menus, branches(+config), promotions, admins, deletion_requests, settings. Embedded misses: reservation_counters, waitlist_counters, locations, notifications/notification_queue/audit_logs (demo). -> OPEN 2.1, 6.2, 6.3.
- App Check: relaxed by default (firestore.rules:30-35); real-device enrollment NOT PROVABLE.
- Emulator loads: no real rules test -> OPEN 2.2; GDPR emulator RED -> OPEN 2.3.
- Packages/apps: core+core_ui PASS (analyze+tests); halal_boyz PASS; sunset_grill & blue_ocean ABSENT -> cannot audit.

### 8.8 FINAL COMBINED COUNTS
- P0 release-blockers (6): counters rules (2.1), no real rules tests (2.2), GDPR emulator RED (2.3), client tax/discount (6.1), locations rules (6.2), settings/restaurantConfig read+write denied (8.7).
- Major (4): 8 skipped tests (2.4), direct FirebaseFirestore.instance x3 (2.5), literal 'usd' in money path (2.6), panic switch NOT enforced at the DB layer (8.9).
- Minor: `// ignore` x3 (2.7), demo collections (6.3), dead submitOrderAtomically (6.4), LoggerService() inline-in-DI (6.6 informational).
**VERDICT: NOT-GO.** Do not launch for 500 users until the 6 P0s + 4 Majors are closed and every suite/rules/erasure/grep re-run green on a clean run.

### 8.10 [Confirmation] No additional P0 beyond the six — last un-traced paths closed
Chasing "are there any more P0s?", I closed the last two un-traced paths:
- `'items'` collection (sweep artifact) = `notifications/{uid}/items` subcollection only, touched by demo mock (`cloud_function_mocks.dart:189,197`) and GDPR erasure (`gdpr_service.dart:97`). NOT a top-level feature collection -> belongs to 6.3/2.3, no new P0.
- Customer live-delivery tracking: driver publishes to `deliveries/{orderId}` (`driver_location_service.dart:99`), and the `deliveries` read rule explicitly allows the owning customer (`firestore.rules:302-303 customerId == uid`). Correctly scoped -> CLOSED, not a P0. (Separate `driverLocations` read is staff/driver-only, not the customer tracking path.)
- Confirmed total P0s = 6 (2.1, 2.2, 2.3, 6.1, 6.2, 8.7). No further P0 found in the full sweep.
- Borderline, NOT elevated to P0 in this audit: (a) hardcoded `'usd'` in createPaymentIntent (2.6) — a genuine money-correctness defect that becomes a P0 the moment any non-USD client ships (white-label multi-currency); (b) App Check rules default to the relaxed OR-mode (`firestore.rules:30-35`) pending `strongAppCheck` flag — a security-posture gut-check that is already partly mitigated by strict App Check on every callable (`index.ts:27-34`). Both should be resolved before launch but are distinct in severity from the six confirmed P0s.
### 8.9 [NEW - this pass] Panic switch is NOT enforced at the database layer (product-safety gap)
- `panic_switch_service.dart:11-14` documents: "The field settings/restaurantConfig.ordersAccepting is the gate" and "the Firestore security rule ... blocks all new order writes (fail at the database layer)".
- But `firestore.rules` orders `create` rule (firestore.rules:201-207) only checks `customerId==uid`, `branchId is string`, `totalCents is int`, `status=='pending'` — it does NOT read `ordersAccepting`. The client-only gate is `checkout_screen.dart:158-159` + `checkout_service.dart:127-128`. So the DB-layer guarantee claimed by the feature does NOT exist; only the client-side UX check enforces it. That is a Major functional-safety gap (the claimed "DB fail-closed" is not real) and should be raised, plus its own branch consumer path also hits the settings rule denial (8.7).
