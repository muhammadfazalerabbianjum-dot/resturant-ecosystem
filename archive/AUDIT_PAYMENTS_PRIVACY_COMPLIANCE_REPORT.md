# CARNAMA LABS — AUDIT 06 REPORT: PAYMENTS, PRIVACY & LEGAL COMPLIANCE

**Date:** 2026-08-31 · **Prompt:** `AUDIT_PAYMENTS_PRIVACY_COMPLIANCE.md` · **Verdict: FAIL**
**P0:** 2 · **P1:** 7 · **P2:** 9 · Report-only: no code changes were made.
**Source of truth = current code.** Every claim cites `file:line` of the current tree. The
prompt's premise "iOS folder ABSENT" is **outdated**: `core_app/ios/` and `apps/halal_boyz/ios/`
both EXIST (each with `Runner/Info.plist`; template also has `Runner/PrivacyInfo.xcprivacy`) and
were audited as declared-permission/privacy-metadata surfaces.

---

## 1. PAYMENT FLOW INTEGRITY (per-item PASS/FAIL)

**PSP identification — PASS.** Stripe. Card data NEVER touches app servers or repo code: the
client presents Stripe's hosted PaymentSheet with a `clientSecret` only
(`core_app/lib/features/checkout/domain/checkout_service.dart:311,325-331`); the publishable key
is a dart-define (`core_app/lib/app_bootstrap.dart:723-726` (the pre-ARCH-2 `core_app/lib/main.dart` and `core_app/lib/app/config/env.dart` read sites were deleted with ARCH-2));
`STRIPE_SECRET_KEY` is read from the function environment
(`core_app/functions/src/index.ts:607,699,745,990`). No PAN/CVV fields exist anywhere
(grep: 0).

**1.1 Server-authoritative pricing — FAIL (P0-1).**
- `createPaymentIntent` re-derives the subtotal from **client-supplied** per-item prices:
  `items[].priceCents/upchargeCents` are zod-validated for shape only
  (`core_app/functions/src/payment.ts:451-463`) and summed by `computeItemsSubtotalCents`
  (`payment.ts:192-210`) at `index.ts:575-580`. **No menu lookup exists in the charge path**
  (grep `menuItems` in `functions/src` → 0 hits). A modified client can send `priceCents: 100`
  for a $50 item and be charged $1 + tax — every server equality check still passes.
- `createOrder` then stores the client's `order` JSON nearly verbatim:
  `orderRef.set({ ...order, id, paymentIntentId, idempotencyKey, ...serverTimestamps }, {merge:true})`
  (`index.ts:726-736`); the Admin SDK write bypasses `firestore.rules` entirely. Only
  `totalCents`, `taxCents`, `discountCents` are verified against the PaymentIntent
  (`verifyOrderCharge` `payment.ts:388-443`, wired `index.ts:712-722`) plus ownership of
  `customerId`/`userId` (`index.ts:680-685`).
- NOT verified: `order.items` (list, names, prices, quantities), `status`
  (`checkout_screen.dart:334` sends `confirmed`; a client could send `delivered`), `tipCents`,
  `deliveryFeeCents`, `orderNumber`, `branchId`, `customerLat/Lng`. The server already stamps
  `itemsSubtotalCents`, `tipCents`, `deliveryFeeCents` into PaymentIntent metadata
  (`index.ts:621-626`) — `verifyOrderCharge` never compares stored items/tip/delivery against
  them. Exploit: charge $1 → `createOrder` with `order.items` = expensive items → kitchen
  fulfills the stored order. **P0 per prompt §1.1.**

**1.2 Idempotency — PASS (direct path); queue cannot double-charge.**
- Session-scoped key persisted in SharedPreferences, reused across retries, cleared only after
  full success (`checkout_service.dart:93-111`, `checkout_screen.dart:296-299,423-428`).
- The key is passed as Stripe's `idempotencyKey` (`index.ts:629`) → same key returns the same
  PaymentIntent, never a second charge.
- `createOrder` dedupes by `idempotencyKey` query (`index.ts:687-696`) and uses the client's
  deterministic doc ID (`index.ts:724-727`) — parallel/late retries converge on one doc.
- `IsarSyncQueue.processQueue` (`packages/core/lib/src/network/sync_queue.dart:114-181`) replays
  ONLY Firestore doc writes; the enqueued payload is the order JSON
  (`checkout_screen.dart:350-355`), never a payment op → **no double-charge path via the queue**
  (unpaid-`'confirmed'` replay = audit-02 P0-SYNC; orphaned intents = P2-6 below).

**1.3 Tip flow — PASS with P2-1 caveat.** Tip selected pre-payment
(`tip_selector_widget.dart:6,32-46`), forwarded into `createPaymentIntent`
(`checkout_service.dart:300-309`), clamped ≥0 and included in the SERVER-computed amount
(`index.ts:582,596-602`; `computeAmountCents` `payment.ts:212-229`). Post-payment mutation of
the charged tip is impossible (PaymentIntent immutable; `createOrder` never charges). Caveat:
stored `order.tipCents/deliveryFeeCents` are not re-verified against metadata
(`index.ts:624-625` stamped; unused by `verifyOrderCharge`) — accounting drift only (P2-1).

**1.4 Fraud screening — FAIL (P1-2).** Consulted in BOTH modes (production CF
`fraud_screening_service.dart:39-49`; demo local count `:20-38`) — NOT demo-only — but it gates
nothing server-side: client-invoked only (`checkout_screen.dart:145-156`), so a modified client
skips it; `createPaymentIntent` (`index.ts:555-662`) has no per-uid velocity check; the
`screenPaymentFraud` CF (`index.ts:101-118`) writes `flaggedForFraud: true` (`index.ts:113`)
with **zero readers repo-wide** (grep: writer only).

**1.5 Refund path — FAIL (P1-1); staff refunds ABSENT.**
- Only refund in the repo = automatic compensating refund in `createOrder`'s failure handler
  (`index.ts:742-756`), fire-and-forget (`console.error` swallow `:751-753`), no Firestore record.
- No admin/staff refund callable or UI exists (grep `refund` → `index.ts:746` only);
  `cancelOrder` CF also absent (master §01 P1-B).
- **Refund-then-replay (P1-1):** refund leaves the PI `succeeded` (Stripe semantics); client
  keeps the session key on failure (`checkout_screen.dart:407-419` — the comment explicitly
  refuses to clear it) and prompts retry; retry reuses the SAME PI (Stripe idempotency) and
  `createOrder` checks only `paymentIntent.status !== 'succeeded'` (`index.ts:700-704`) →
  **order confirmed on a refunded charge.**

**1.6 Receipts — FAIL (P2-2).** No `receipt_email` anywhere (grep: 0) → no email receipt;
customer gets a local notification (`checkout_screen.dart:436-449`) + order tracker.
`stripeWebhook` handles ONLY `payment_intent.succeeded` (`index.ts:998-1015`) — refunds,
disputes, failures leave no Firestore trace.

**1.7 Webhook — PASS (signature), P2-2 scope note.** `constructEvent` with
`STRIPE_WEBHOOK_SECRET`; missing secret → 400 fail-closed (`index.ts:978-996`) ✅. The
unvalidated `status:'confirmed'` write (`index.ts:1005-1009`) is an unguarded transition
(cross-ref master §03 P1-TRANSITION).

**1.8 Tax/promo surfaces — P2-3.** `calculateTax` falls back to hardcoded CA/NY/TX/FL + 5%
(`index.ts:66-77`) while the charge path fail-closes (`payment.ts:102-186` →
`failed-precondition` `index.ts:657-659`). Unconfigured client ⇒ displayed tax ≠ charged tax ⇒
Law-12 abort (`checkout_service.dart:317-323`) — safe but a guaranteed checkout failure. Promo
is server-authoritative end-to-end (`applyPromo`/`evaluatePromoUse`/`planPromoUsage`,
`index.ts:437-456,460-500`; uid-scoped idempotent `promo_usage` commit `:468-499`) ✅.

**1.9 Charge inputs the server trusts — P2-9.** `deliveryFeeCents` is read client-side from
`settings/restaurantConfig` (`checkout_screen.dart:217-219`), forwarded into the charge
(`checkout_service.dart:304`), accepted by the server (`index.ts:583`) without validation
against that config doc → tampered client zeroes its own fee. `stateCode` hardcoded `'DEFAULT'`
(`checkout_service.dart:44,305`).

**1.10 NFC terminal — OK.** Honest deferred placeholder; never fakes success
(`packages/core/lib/src/payment/nfc_terminal_service.dart:1-56`); zero UI callers.

---

## 2. PII INVENTORY (every user-data store in the repo)

| Store | PII fields (writer → file:line) | Retention | Erased | Exported |
|---|---|---|---|---|
| `users/{uid}` | email, name, role, locale, loyaltyPoints, tier, isOnline, assignedOrderIds, createdAt (`auth_repository.dart:248-259`); fcmToken/fcmLastUpdated (`fcm_service.dart:60-63`); flaggedForFraud (`index.ts:113`); branchId (staff) | forever | ✅ (LAST, `index.ts:233-234`) | ✅ |
| `orders/{orderId}` | customerId, branchId, customerLat/Lng, totals, orderNumber, items (names+prices+options), paymentIntentId, idempotencyKey, proofOfDelivery{url,uploadedBy} (`checkout_screen.dart:328-348`, `index.ts:728-736`, `proof_of_delivery_service.dart:54-61`) | forever (no expiry, `sync_queue.dart:146-148`) | ✅ by customerId | ✅ |
| `deliveries/{orderId}` | driver lat/lng/heading/speed/timestamp (`driver_location_service.dart:99-105`) — **no uid field** | forever | ❌ **P0-2** | ❌ |
| `driverLocations/{uid}` | driver GPS (`firestore.rules:460-461`) | forever | ✅ (`index.ts:231`) | ❌ |
| `reservations` | userId, branchId, customerName, customerPhone, startTime, partySize, notes (`index.ts:187-191`) | forever | ✅ | ✅ |
| `reservation_locks` | userId, lockedAt, expiresAt | TTL-adjacent | ✅ (`index.ts:211-212`) | ❌ |
| `waitlist` | userId + entry fields | forever | ✅ | ✅ |
| `promo_usage` | code, userId, idempotencyKey, usedAt (`index.ts:486-491`) | forever | ✅ (`index.ts:219-220`) | ❌ |
| `carts/{uid}` | items, recovered; server reads `fcmToken` from it (`index.ts:778`) | forever | ✅ (`index.ts:228`) | ✅ |
| `presence/{uid}` | online/lastSeen (`presence_service.dart:35`) | forever | ✅ | ✅ |
| `loyalty/{uid}` | points/tier (`loyalty_provider.dart:12`) | forever | ✅ | ✅ |
| `notifications/{uid}/items` | notification copies | forever | ✅ (`index.ts:223-225`) | ❌ |
| `analyticsEvents` | event, properties, **uid**, timestamp (`index.ts:162-167`) | forever | ❌ **P0-2** | ❌ |
| `audit_log` | users rows keyed by uid + role transitions (`index.ts:1105-1110`); settings before/after docs (`index.ts:1086-1093`) | forever | ❌ (users rows) **P0-2** | ❌ |
| `deletion_requests/{uid}` | status/requestedAt/completedAt (`index.ts:266-276`) | retained by design (audit proof, `index.ts:261-264`; rules forbid delete `firestore.rules:341-346`) | by design | ❌ |
| Storage `proof_of_delivery/{orderId}/*` | delivery photos (`proof_of_delivery_service.dart:46-52`; `storage.rules:65`) | forever | ❌ **P0-2** | ❌ |
| Storage `avatars/{userId}/*` | profile images (`storage.rules:75`) | forever | ❌ **P0-2** | ❌ |
| Isar (device) | menus, carts, pending ops, dead letters | until signOut | ❌ on deletion path (signOut-only, `auth_repository.dart:286`) **P2-4** | ❌ |
| Crashlytics | user_id/screen/lastAction keys (`error_logger_service.dart:38-47`; `logger_service.dart:63-71`) | Firebase-managed | console-side only | ❌ |
| Firebase Analytics | events/device ids — collection disabled by default (`main.dart:199-207`) | Firebase-managed | `resetAnalyticsData()` on signOut (`auth_repository.dart:293-294`) | ❌ |
| SharedPreferences (device) | checkout idempotency key (`checkout_service.dart:98-105`), branch pref (`branch_service.dart:163-175`), consent/onboarding flags | until signOut (partial purge only, `auth_repository.dart:299-306`) | ❌ **P2-4** | ❌ |

Modeled-but-never-written (hygiene): `UserModel.stripeCustomerId/pushToken/phone/phoneNumber`
(`user_model.dart:47-51` — zero writers repo-wide). Cloudinary images (`app_config.dart:48-58`)
are owner/menu content, not end-user PII.

## 3. DELETION-COVERAGE MATRIX (chain proof)

**Chain (production):** `profile_screen.dart:123` → `delete_account_screen.dart:24` →
`gdpr_service.deleteMyData` (`gdpr_service.dart:187-210`): marker `deletion_requests/{uid}`
`in_progress` FIRST (`:195-199`) → `deleteUserData` CF (`index.ts:336-345`, App Check + auth) →
`eraseUserData` (`index.ts:325-334`) → `collectUserDocs` (`:195-236`) → `eraseRefs` 400-write
chunked batches (`:245-259`) → `deleteAuthUser` idempotent (`:284-296`) → marker `completed`;
hourly `deleteUserDataRetry` sweeps stuck markers (`:352-388`). **Demo:** client-side mirror
(`gdpr_service.dart:141-186`) with the same canonical set. Rules: user may create/update but
never delete their marker (`firestore.rules:341-346`). The MECHANISM is production-grade;
its COVERAGE is not (P0-2).

| Store | Server CF | Demo client | Export |
|---|---|---|---|
| orders · reservations · waitlist · carts · presence · loyalty | ✅ | ✅ | ✅ |
| reservation_locks · promo_usage · notifications(+items) · driverLocations | ✅ | ✅ | ❌ |
| users/{uid} (incl. fcmToken) | ✅ last | ✅ last | ✅ |
| **deliveries** | ❌ | ❌ | ❌ |
| **analyticsEvents** | ❌ | ❌ | ❌ |
| **audit_log (users rows)** | ❌ | ❌ | ❌ |
| **Storage proof_of_delivery / avatars** | ❌ (0 storage code in functions) | ❌ | ❌ |
| Isar + prefs (device) | ❌ (signOut-only) | ❌ | ❌ |

## 4. DATA EXPORT (Art. 20) — FAIL (P1-7)

`data_export_service.dart:41-144` exports: userProfile, orders, loyalty, reservations, cart,
presence, waitlist — machine-readable JSON ✅, fail-loud per section ✅ (`:24-26` contract),
UI-reachable from Profile (`profile_screen.dart:91`, share-sheet `:147-160`) ✅.
**Missing vs the erasure set (`index.ts:195-236`):** promo_usage, reservation_locks,
notifications/{uid}/items, driverLocations, deliveries, analyticsEvents, Isar local data, and
auth-profile fields beyond `email` (`:51`). Driver-role users lose their entire location
history from the export. Note: client-side queries for `analyticsEvents`/`deliveries` would be
rules-gated (`firestore.rules:468-492`) — completeness needs a server-side export path.

## 5. CONSENT & TRANSPARENCY SURFACES

- **ToS/Privacy at signup — FAIL (P1-4).** `signup_screen.dart` (full read) contains name/
  email/password + submit — zero legal references, no checkbox. Login screen HAS both links
  (`login_screen.dart:400-432` → `/privacy`, `/terms`); routes exist pre-auth
  (`app_router.dart:197-198,412-425`) ✅; screens consume config URLs and degrade gracefully
  when unset (`terms_of_service_screen.dart:12-22`; `privacy_policy_screen.dart:12-22`) ✅.
- **Config-driven URLs — PASS (mechanism) / VERIFY (data).** `termsUrl/privacyUrl` live in
  `settings/restaurantConfig` (`restaurant_config_model.dart:102-103,114-115` — no hardcoded
  template legal text anywhere), written by the owner in RestaurantSetup
  (`restaurant_setup_screen.dart:49-50,111-112,169-174,586-595`). Per-client correctness
  depends on the per-project Firestore doc being seeded — VERIFY-IN-CONSOLE.
- **Analytics consent — FAIL (P1-3).** `GdprConsentDialog.showIfNeeded` has ZERO callers
  (grep: definition only) → never shown; dialog writes `gdpr_consent_given`
  (`gdpr_consent_dialog.dart:12,25-28`) while TelemetryService reads `gdpr_analytics_consent`
  (`telemetry_service.dart:23`) — key mismatch, so even an accepted dialog would never enable
  funnel telemetry; `main.dart:199-207` gates FirebaseAnalytics on the never-written key →
  collection permanently disabled (privacy-safe direction, broken product). Dialog copy is
  hardcoded English (`gdpr_consent_dialog.dart:46-70`).
- **Location permission — PASS.** In-context: nearest-branch detection requests only when the
  feature runs, handles denied/deniedForever by returning null (`branch_service.dart:200-229`);
  driver tracking requests at `startTracking` with explicit denied handling
  (`driver_location_service.dart:23-51`). Denial degrades to manual branch selection
  (`merged_menu_provider.dart:34,80`).
- **Notification permission — P2-5.** Requested at first launch via unawaited
  `FcmService().init()` (`main.dart:210-225` → `fcm_service.dart:26-30`), not in-context;
  denied degrades (no token upload, in-app inbox still works). Config knob
  `notificationOptIn` (`restaurant_config_model.dart:75,115`) has zero runtime consumers
  (only the admin form writes it).
- **Marketing consent — PASS (effectively).** No marketing comms exist in the repo; analytics
  is the only comms-adjacent surface and is opt-in-by-default (both consent flags default
  false: `telemetry_service.dart:23`, `gdpr_consent_dialog.dart:22`) — but see P1-3.

## 6. PERMISSIONS POSTURE (least privilege)

**Template Android (`core_app/android/app/src/main/AndroidManifest.xml`) × feature table:**

| Permission | Consuming feature | Verdict |
|---|---|---|
| INTERNET | all Firebase/Stripe/HTTP | ✅ keep |
| ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION | geolocator (nearest branch `branch_service.dart:200-229`; driver tracking `driver_location_service.dart:20-78`; delivery pin) | ✅ keep (pair required by geolocator) |
| ACCESS_BACKGROUND_LOCATION | **NONE** — driver stream is a plain foreground `LocationSettings` stream (`driver_location_service.dart:54-57`); no background API used | ❌ REMOVE (P1-5) |
| FOREGROUND_SERVICE | **NONE** — no service started, no `<service>` in manifest | ❌ REMOVE (P1-5) |
| FOREGROUND_SERVICE_LOCATION | **NONE** — and Android 14 requires a `<service android:foregroundServiceType="location">` which does not exist | ❌ REMOVE (P1-5) |
| POST_NOTIFICATIONS | push (FCM) — runtime request exists (`fcm_service.dart:26-30`) but the app manifest does NOT declare it; relies on the `firebase_messaging` plugin manifest merge (plugin v16.x) | ⚠️ declare explicitly at release (P3 note) |
| CAMERA | not declared; `image_picker` uses the system camera (no manifest permission needed) | ✅ consistent |

**Template iOS (`core_app/ios/Runner/Info.plist` + `PrivacyInfo.xcprivacy`):**
NSLocationWhenInUse/NSCamera/NSPhotoLibrary usage strings present and accurate ✅; ATS
`NSAllowsArbitraryLoads=false` ✅; `PrivacyInfo.xcprivacy` exists with required-reason
UserDefaults (CA92.1) ✅ — but EmailAddress/Name are declared `linked=false` (inaccurate:
both ARE linked to identity) and order-history/analytics data types are missing (P2-7);
`NSUserTrackingUsageDescription` present while `NSPrivacyTracking=false` and no ATT request
exists in code (grep `AppTrackingTransparency` → 0) — unused key (P2-7).

**Generated shell (`apps/halal_boyz`) — FAIL (P1-6).** Android manifest has **zero**
`<uses-permission>` (not even INTERNET) → release build cannot reach Firebase/Stripe; iOS
`Info.plist` has no usage descriptions → iOS aborts on first location/camera access (delivery
address, POD photos); NO `PrivacyInfo.xcprivacy` in `apps/halal_boyz/ios/Runner/` → Apple
privacy-manifest requirement unmet. The white-label generator drops the entire platform
privacy/permission layer (cross-ref audit-08).

## 7. LOGS / ANALYTICS / CRASH PII

- `debugPrint`/`developer.log` sweep (all `packages/core/lib` + `core_app/lib`): ~20 sites,
  none print email/phone/token. HTTP interceptor logs are debug/profile-only with
  `Authorization` stripped (`http_interceptor.dart:15-19,47-52`) ✅. `logger_service.dart:104-118`
  scrubs emails + domestic/international phones before the local file AND the Crashlytics
  reason ✅.
- Gaps: `ErrorLoggerService` records RAW error objects to Crashlytics unscrubbed
  (`error_logger_service.dart:49-53`) while `LoggerService` scrubs only the reason string
  (`logger_service.dart:72-77`) — an exception whose `toString()` embeds PII leaks (P2-8).
  Local `app_logs.txt` has no retention/rotation; `clearLogs()` (`logger_service.dart:127-132`)
  has zero callers (P2-8).
- Crashlytics custom keys carry pseudonymous uid + screen only — disclose in the store privacy
  label (P2-7 link).
- Funnel telemetry: opt-in-gated client-side, non-PII properties only
  (`telemetry_service.dart:20-65`) ✅, but the `logFunnelEvent` CF attaches `uid`
  unconditionally with no server-side consent enforcement (`index.ts:159-168`) (P2-9), and per
  P1-3 the consent surface that would ever enable it is dead.

## 8. ISSUE TABLE (complete)

| ID | Sev | Where | Issue |
|---|---|---|---|
| P0-1 | P0 | `payment.ts:451-463,192-210` · `index.ts:575-605,712-736` | Charge derived from client prices; stored order payload unverified beyond total/tax/discount (items/status/tip/deliveryFee/orderNumber/branchId trusted) |
| P0-2 | P0 | `index.ts:195-236` · `gdpr_service.dart:51-129` · `driver_location_service.dart:99-105` · `index.ts:165,1105-1110` · `proof_of_delivery_service.dart:46-52` · `storage.rules:65,75` | Erasure misses `deliveries`, `analyticsEvents`, `audit_log` (users rows), Storage `proof_of_delivery/*` + `avatars/*` |
| P1-1 | P1 | `index.ts:742-756,700-704` · `checkout_screen.dart:407-419` | Refunded PaymentIntent can still confirm an order on retry |
| P1-2 | P1 | `checkout_screen.dart:145-156` · `index.ts:101-118,555-662` | Fraud gate client-side only; no charge-path velocity limit; `flaggedForFraud` dead-end |
| P1-3 | P1 | `gdpr_consent_dialog.dart:12,32-41` · `telemetry_service.dart:23` · `main.dart:199-207` | Consent dialog never shown + consent-key mismatch → analytics/telemetry permanently dead |
| P1-4 | P1 | `signup_screen.dart` (no legal refs) vs `login_screen.dart:400-432` | ToS/Privacy not surfaced at signup |
| P1-5 | P1 | template `AndroidManifest.xml` · `driver_location_service.dart:54-57` | BACKGROUND_LOCATION + FOREGROUND_SERVICE(_LOCATION) unused; no `foregroundServiceType` service |
| P1-6 | P1 | `apps/halal_boyz/android/.../AndroidManifest.xml` · `apps/halal_boyz/ios/Runner/` | Generated shell: zero permissions (no INTERNET), no iOS usage strings, no PrivacyInfo.xcprivacy |
| P1-7 | P1 | `data_export_service.dart:48-141` vs `index.ts:195-236` | Art.20 export misses 6 erasure-set sources + local data |
| P2-1 | P2 | `index.ts:624-625` vs `payment.ts:388-443` | Stored tipCents/deliveryFeeCents unverified vs PI metadata |
| P2-2 | P2 | `index.ts:608-630,998-1015` · `checkout_screen.dart:436-449` | No receipt (no receipt_email); webhook single-event; no refund ledger |
| P2-3 | P2 | `index.ts:66-77` vs `payment.ts:151-186` | Display tax fallback ≠ fail-closed charge tax when unconfigured |

| P2-4 | P2 | `delete_account_screen.dart:24-47` · `gdpr_service.dart:187-210` | Deletion path performs no local cleanup (Isar/prefs/signOut) |
| P2-5 | P2 | `main.dart:210-225` · `fcm_service.dart:26-30` · `restaurant_config_model.dart:75,115` | Notification permission at launch, not in-context; `notificationOptIn` config dead |
| P2-6 | P2 | `checkout_service.dart:88-91` · `checkout_screen.dart:63-64,355,427` | Queued order intent orphaned when session ID regenerates; stale unpaid `'confirmed'` rows |
| P2-7 | P2 | `core_app/ios/Runner/PrivacyInfo.xcprivacy` · `Info.plist` | Privacy-manifest inaccuracies (linked=false email/name; missing data types; unused ATT string) |
| P2-8 | P2 | `error_logger_service.dart:49-53` · `logger_service.dart:72-77,127-132` | Unscrubbed error objects to Crashlytics; unbounded local log file |
| P2-9 | P2 | `checkout_screen.dart:217-219` · `checkout_service.dart:304` · `index.ts:583,159-168` | Client-supplied deliveryFeeCents accepted; uid attached to analytics without server-side consent check |

## 9. FIX PLAN (ordered by blast radius)

1. **P0-1** — extend `verifyOrderCharge`: server-recompute the subtotal of the STORED
   `order.items` and compare with PI metadata `itemsSubtotalCents`; add `tipCents`/
   `deliveryFeeCents` equality + a `status` allowlist; (phase 2) validate per-item prices
   against `menuItems` by ID. Guard: extend the payment-audit function tests.
2. **P0-2** — extend `collectUserDocs` (server + demo mirror): collect `deliveries` via the
   user's order IDs BEFORE deleting order docs (stamp `driverId` on new writes), add
   `analyticsEvents` + `audit_log` uid queries, delete Storage prefixes
   `proof_of_delivery/{orderId}` + `avatars/{userId}` via Admin SDK. Guard: extend
   `gdpr_erasure_test.js`.
3. **P1-1** — in `createOrder`, fail-closed reject a PI whose charge is refunded (beside the
   existing status check `index.ts:702`); persist a refund record.
4. **P1-2** — extract the `screenPaymentFraud` rate-limit core; call it inside
   `createPaymentIntent` before Stripe.
5. **P1-3** — call `GdprConsentDialog.showIfNeeded` after onboarding; unify the consent key
   into one constant consumed by `main.dart` + `TelemetryService`; l10n the dialog strings.
6. **P1-4** — required ToS/Privacy checkbox + links on signup gating `_signUp`.
7. **P1-5** — remove `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`,
   `FOREGROUND_SERVICE_LOCATION` until a real `foregroundServiceType="location"` service ships.
8. **P1-6** — generator copies/patches template manifest + Info.plist usage strings +
   `PrivacyInfo.xcprivacy` per client; fail generation when missing (cross-ref audit-08).
9. **P1-7** — `exportUserData` callable reusing `collectUserDocs` as the single source list;
   keep the existing client share flow.
10. **P2 backlog** — P2-1…P2-9 as itemized in §8.

**VERIFY-IN-CONSOLE (not provable from repo):** Stripe secrets present (`STRIPE_SECRET_KEY`,
`STRIPE_WEBHOOK_SECRET`); App Check enforcement toggles; webhook endpoint registered in Stripe;
`settings/taxRates.clients[clientId]` + `settings/restaurantConfig.{currency,termsUrl,privacyUrl}`
seeded per client; Crashlytics deletion runbook; Play Data-safety form vs §2 inventory.

## 10. CANONICAL-COMMAND RESULTS + HONEST LIMITATIONS

**Greps executed (source dirs only):** `httpsCallable(` → 12 sites / 8 distinct functions
(money: `calculateTax` ×2, `createPaymentIntent`, `createOrder`, `applyPromo`, `cancelOrder`
(CF absent — master §01 P1-B), `screenPaymentFraud`, `deleteUserData`, `logFunnelEvent`; all
App-Check enforced server-side `index.ts:42-49`) · `.enqueue(` → 1 site
(`checkout_screen.dart:355`) · `refund` in functions → `index.ts:746` only · `receipt_email` → 0 ·
`menuItems` in functions → 0 · `flaggedForFraud` → writer only · `showIfNeeded` → definition
only · `gdpr_consent_given` → writer only · `gdpr_analytics_consent` → reader only ·
`storage(`/`bucket(` in functions → 0 · `debugPrint|developer.log|print(` → ~20 sites, PII-free ·
`AppTrackingTransparency` → 0 · collection( inventory → §2 table · existing regression tests:
`gdpr_compliance_test.dart`, `gdpr_erasure_test.js`, `delete_account_screen_test.dart`,
`gdpr_consent_dialog_test.dart`, `fraud_screening_service_test.dart`, `payment_service_test.dart`,
`checkout_service_test.dart`, `checkout_e2e_test.dart`, `chaos_checkout_test.dart`,
`checkout_auth_guard_test.dart`, `v15_phase3_payment_audit_test.dart`.
`flutter analyze`/`test` not re-run (static audit; master §01 records core_app clean + 1238 passing).

**Honest limitations:**
- Stripe-side runtime state (secret presence, PI state after refund, webhook registration) is
  console/env-dependent — emitted as VERIFY-IN-CONSOLE.
- Merged Android manifest (plugin-provided POST_NOTIFICATIONS) and Xcode build settings were
  not built this session — analysis is of SOURCE manifests/plists only.
- Firestore rules live-enforcement and emulator tests not re-run offline (consistent with
  §01/§09 sessions).
- Demo-mode deletion relies on client-side rules (emulator project); production uses the CF path.
- Exact live values of `settings/taxRates` / `settings/restaurantConfig` are data, not code.
- Refund-then-replay (P1-1) and price-tamper (P0-1) are code-derived exploits (deterministic
  Stripe idempotency semantics), not runtime-reproduced.

**END OF AUDIT 06 REPORT**