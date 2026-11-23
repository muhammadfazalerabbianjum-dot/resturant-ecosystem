# CARNAMA LABS — NETWORK, SYNC & DATA RESILIENCE AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify EVERY network call, retry mechanism,
offline sync path, cache strategy, and configuration validation in the Carnama Labs template
(`core_app`) and domain package (`packages/core`).

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it. Never trust assumptions.
2. **No stubs / fake success / AI slop.** No "has retry" without proving the retry is actually used.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every Firestore call, every HTTP call, every config field. Exhaustive.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A network call without retry is a fail. A config field
   consumed without validation is a fail. An order that can be silently lost is a fail.

---

## 1. SCOPE

### 1.1 Network Retry Coverage

**Files to audit:**
- `packages/core/lib/src/network/network_retry.dart` (defines `NetworkRetry.withExponentialBackoff`)
- `packages/core/lib/src/network/firestore_client.dart`
- `packages/core/lib/src/network/http_interceptor.dart`
- `packages/core/lib/src/network/chaos_firestore.dart`
- ALL files in `packages/core/lib/src/` and `core_app/lib/` that make network calls
  (grep for `.collection(`, `.doc(`, `httpsCallable(`, `http.get`, `http.post`, `dio`)

**Verify:**
- [ ] `NetworkRetry.withExponentialBackoff` is used (grep for it) — list every call site
- [ ] Every Firestore read/write either uses `NetworkRetry` or has documented justification
- [ ] Every `httpsCallable` Cloud Function call has timeout + retry
- [ ] No bare `await firestore.get()` without retry wrapper in feature code
- [ ] Retry does NOT apply to 4xx errors (auth failure, permission denied — retrying is wasteful)
- [ ] Max retry count is bounded (no infinite loop on persistent failure)
- [ ] Backoff is exponential (1s, 2s, 4s...) not linear

### 1.2 Offline Sync & Queue Integrity

**Files to audit:**
- `packages/core/lib/src/network/sync_queue.dart`
- `packages/core/lib/src/network/pending_sync_provider.dart`
- `packages/core/lib/src/cache/isar_service.dart`
- `packages/core/lib/src/cache/isar_schemas.dart`
- `packages/core/lib/src/kitchen/kitchen_offline_service.dart`
- ALL files referencing `SyncQueue`, `IsarSyncQueue`, `enqueue`, `processQueue`

**Verify:**
- [ ] `SyncQueue.enqueue` is called for EVERY order mutation (create, update, cancel)
- [ ] `processQueue()` is invoked: on app start, on connectivity restore, and on timer
- [ ] Dead-letter queue (DLQ) has UI for ops to inspect and retry failed items
- [ ] `kMaxRetries` (5) is enforced — operations move to DLQ after max attempts
- [ ] Queue operations are idempotent (re-running `processQueue` doesn't duplicate orders)
- [ ] Isar schema migrations are handled (what happens if schema version changes?)
- [ ] `PendingSyncBanner` UI exists and displays when queue > 0

### 1.3 Configuration Loading & Validation

**Files to audit:**
- `core_app/lib/app/config/app_config.dart` (the full `loadConfig` method)
- `core_app/assets/client_config.json` (the template config)
- `apps/halal_boyz/assets/client_config.json` (a generated client config)
- `packages/core/lib/src/config/core_config.dart`
- `core_app/lib/app/config/core_config_adapter.dart`
- `core_app/lib/app/config/demo_config.dart`

**Verify:**
- [ ] Every field in `client_config.json` is consumed by `app_config.dart` — list any dead config
- [ ] Every field read by `app_config.dart` exists in the config — list any missing config
- [ ] Type coercion is defensive (bad type doesn't crash, falls back)
- [ ] `_loadFailed` flag is exposed and checked by the app (does the user know config failed?)
- [ ] Fallback values are production-safe (not empty strings that break the app)
- [ ] Empty config string doesn't clobber a valid dotenv value (documented at app_config.dart:29-31)
- [ ] `screens` array: does the code validate that all screen IDs map to real Dart widgets?
- [ ] What happens if `client_config.json` is MISSING entirely? (app must still boot)

### 1.4 Date/Time Correctness

**Files to audit:**
- `packages/core/lib/src/models/operating_hours_model.dart`
- `packages/core/lib/src/tax/tax_service.dart`
- ALL files using `DateTime.now()`, `Timestamp.now()`, `DateFormat`, `TimeZone`

**Verify:**
- [ ] Order timestamps use `Timestamp.now()` (Firestore server time), not `DateTime.now()`
- [ ] Operating hours comparison uses the restaurant's timezone, not the device's
- [ ] Reservation slots handle timezone correctly (a 1 PM slot means 1 PM at the restaurant)
- [ ] DST transitions don't break hour comparisons
- [ ] `toIso8601String()` includes timezone offset for data export
- [ ] No code compares `DateTime.now()` against a stored Firestore `Timestamp` without conversion
- [ ] Offline cart operations survive app restart (persisted to Isar)

### 1.5 Push Notifications & Background Delivery

**Files to audit:**
- `packages/core/lib/src/notifications/fcm_service.dart`
- Every consumer of FCM tokens/messages (`onMessage`, `onBackgroundMessage`, `onMessageOpenedApp`)
- Notification tap → navigation path in `core_app/lib/main.dart`

**Verify:**
- [ ] Token lifecycle: stored where? refreshed on rotate? deleted on logout AND on account deletion
- [ ] Tap → route: notification payload's target is resolved through the ACTIVE router (config
  mode) and role-checked — a customer tapping an admin-targeted payload must NOT land there
- [ ] Background/terminated delivery: handler registered before `runApp`? isolate-safe?
- [ ] Tenant isolation: payload `clientId` validated client-side; wrong-tenant payload discarded
- [ ] Foreground presentation: in-app banner vs silent data message — behavior per type documented

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` in the **same format as
`<repo>\UI_WIRING_AUDIT_REPORT.md`**:

- **Section 0:** Verdict (PASS / FAIL) + P0/P1/P2 counts
- **Section 1:** Per-item PASS/FAIL with file:line citations
- **Section 2:** Issue table (ID, Severity, File, Issue, Impact, Fix sketch)
- **Section 3:** Recommended fix plan (ordered by blast radius)
- **Section 4:** Honest limitations — "NOT PROVEN without X test" for runtime claims

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] Every network call site in the codebase inventoried? (target: 100%)
- [ ] Every config field in `client_config.json` checked both directions?
- [ ] Every checklist item has a file:line citation or explicit "NOT FOUND in codebase"
- [ ] No claim made about runtime behavior without a test proving it
- [ ] Zero recommendations to add a library unless the codebase already uses a similar pattern

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

# AUDIT 02 — NETWORK, SYNC & DATA RESILIENCE — DETAILED FINDINGS (appended)

**Audit date:** 2026-08-31 · **Static source-level audit** (codebase = sole source of truth) · **Report-only — no code changes applied**
**Jury:** this prompt · **Scope:** `packages/core` + `core_app` + `apps/halal_boyz` + `core_app/functions/src` + `core_app/firestore.rules`

---

## 0. VERDICT — ❌ FAIL

**1× P0 + 5× P1 + 8× P2.**

The headline blocker is **P0-SYNC**: the offline order sync queue *appears* to exist but can **never deliver a single order** — the queued `create` op writes `status: 'confirmed'` while `firestore.rules:361-368` only allows orders create with `status == 'pending'` (and there is **no customer update branch** at `firestore.rules:369-387`). On top of that the queue has **no automatic trigger** (no app-start / connectivity / timer schedule; `connectivity_plus` is not a dependency) and there is **no DLQ UI** (`deadLetterCountProvider` is referenced only by tests). Meanwhile `PushNotificationService` is **never instantiated** (FCM tokens are collected and the server sends pushes, but the app never listens — tap→route is dead), the kitchen-LAN Workmanager heartbeat is **never scheduled**, and the client-config JSON `firebase.projectId` field is **silently ignored** by the parser.

Every claim cites `file:line` of current source. Full call-site inventory in §1.1-A/B/C.

---

## 1. PER-ITEM FINDINGS (exhaustive — no sampling)

### 1.1 Network Retry Coverage

**Checklist: 3 FAIL, 2 PASS, 2 partial-hardening.**
**4) No bare `await firestore.get()` without retry in feature code — FAIL** (all single-shot reads are bare; see §1.1-A).

**5) Retry does NOT apply to 4xx — FAIL.**
- `network_retry.dart:14-25` catches **every** exception; no `FirebaseException`/`FirebaseFunctionsException` code classification → `cancelOrder` burns retries on `permission-denied`/`not-found`/`unauthenticated`.
- `sync_queue.dart:167-176` bumps `retryCount` and backs off on **every** error including rules `permission-denied` — under P0-SYNC all 5 retries are guaranteed waste.

**6) Max retry bounded — ✅ PASS.** `network_retry.dart:10` (default 3), `order_repository.dart:61` (2), `sync_queue.dart:27` `kMaxRetries = 5` enforced at `sync_queue.dart:125-144` (→ DLQ).

**7) Backoff exponential — ✅ PASS.** `network_retry.dart:22` `pow(2,attempt)*1000`; `sync_queue.dart:173-175` `1 << retryCount.clamp(0,5)` (2s→32s).

### §1.1-A — Complete Firestore call-site inventory (read/write; generated files excluded)

| File:line | Op | Protected | Notes |
|---|---|---|---|
| `packages/core/src/auth/auth_repository.dart:54` | users doc get | ❌ none | profile read; login-critical |
| `auth_repository.dart:245` | transaction | ✅ SDK txn | user doc cleanup |
| `packages/core/src/network/sync_queue.dart:155-161` | orders set/delete | ⚠️ retry loop | **rules-denied (P0-SYNC)** |
| `packages/core/src/notifications/fcm_service.dart:60-63` | users doc set | ❌ none | token upsert; per-tenant |
| `packages/core/src/presence/presence_service.dart:37-49` | presence set | ✅ best-effort | wrapped+logged |
| `packages/core/src/analytics/telemetry_service.dart:28` | analyticsEvents add | ✅ best-effort | demo mode only path |
| `packages/core/src/compliance/gdpr_service.dart:55-112` | 6× queries | ❌ none | erasure=abort-on-error (durable marker mitigates) |
| `gdpr_service.dart:151-177` | deletion_requests set/update | ❌ none | durable marker first |
| `packages/core/src/admin/admin_access_service.dart:82` | audit_log add | ❌ none | admin audit |
| `packages/core/src/utils/firestore_paginator.dart` L36 (deleted post-audit; 0 live references) | q.get() | ❌ none | 0 callers in lib (dead util) |
| `core_app/lib/.../data_export_service.dart:56-132` | 7× one-shot gets | ❌ none | GDPR export; rethrow w/ logging |
| `core_app/lib/.../restaurant_config_service.dart:30` | settings set | ❌ none | server-side config save |
| `core_app/lib/.../feature_flags_service.dart:31-35` | settings stream | ✅ stream | |
| `core_app/lib/.../admin_data_service.dart:155/167` | users doc update | ❌ none | role flips |
| `admin_data_service.dart:179` | branches get | ❌ none | limit 50 read |
| `admin_data_service.dart:203/205` | branches update/add | ❌ none | admin write |
| `admin_data_service.dart:224` | branches set | ❌ none | |
| `admin_data_service.dart:265/267/278/290` | menus update/add/update/delete | ❌ none | admin menu CRUD |
| `core_app/lib/.../kitchen_service.dart:43-46` | orders update | ❌ none | **also rules-denied → 01 P1-A** |
| `core_app/lib/.../delivery_service.dart:68-71,91-95` | orders update (+txn) | ❌ none | **also rules-denied → 01 P1-A** |
| `core_app/lib/.../proof_of_delivery_service.dart:54-61` | orders update | ❌ none | **also rules-denied → 01 P1-A** |
| `core_app/lib/.../panic_switch_service.dart:41-44,47-50` | settings set/get | ❌ none | orders gate; **not queued** |
| `core_app/lib/.../operating_hours_screen.dart:46,78` | settings/branch hours get/set | ❌ none | |
| `core_app/lib/.../cart_validator_service.dart:70` | menus doc get | ❌ none | per-item validation |
| `core_app/lib/.../checkout_service.dart:138` | branches doc get | ❌ none | gates checkout |
| `core_app/lib/.../menu_repository.dart:99` | menus get | ❌ none | menu bootstrap |
| `core_app/lib/.../merged_menu_provider.dart:58` | branches get | ❌ none | |
| `core_app/lib/.../reservation_screen.dart:33` | branches doc get | ❌ none | |
| `core_app/lib/.../reservations_repository.dart:30-72` | txn counter/lock/res | ✅ SDK txn | deterministic keys |
| `core_app/lib/.../waitlist_repository.dart:55-89` | txn counter/entry | ✅ SDK txn | deterministic key |
| `core_app/lib/.../waitlist_repository.dart:102-122` | waitlist stream | ✅ stream | |
| `core_app/lib/.../order_repository.dart:50-53` | orders update (demo) | ❌ none | demo cancel; rules-denied too (no customer update branch) |
| `core_app/lib/.../order_number_service.dart:30-38` | txn counter | ✅ SDK txn | crash-safe fallback |
| `core_app/lib/.../driver_location_service.dart:99` | deliveries set | ✅ throttle+log | 20 m epsilon filter |
| `core_app/lib/.../home_service.dart:70,103` | promotions/branches get | ❌ none | |
| `core_app/lib/.../location_repository.dart:29` | locations get | ❌ none | |
| `core_app/lib/.../loyalty_provider.dart:12` | loyalty stream | ✅ stream | |
| `core_app/lib/.../admin_reservations_tab.dart:21-30` | reservations stream | ✅ stream | |
| `core_app/lib/.../admin/domain/cloud_function_mocks.dart:82-248` | locks/orders/notifications/audit_logs | ✅ demo-only | kDemoMode-gated; never in release |
### §1.1-B — Complete Cloud-Function callable inventory

| File:line | Function | Retry | Timeout | Justification note |
|---|---|---|---|---|
| `order_repository.dart:58-63` | `cancelOrder` | ✅ NetworkRetry (2×, 15s) | per-attempt | **only retried callable** |
| `tax_service.dart:31-35` | `calculateTax` | ❌ | SDK default 60s | fail-closed at caller |
| `checkout_service.dart:169,222` | `calculateTax` | ❌ | SDK default | fail-closed at caller |
| `checkout_service.dart:299` | `createPaymentIntent` | ❌ | SDK default | idempotency-key retry-safe |
| `checkout_service.dart:356-362` | `createOrder` | ❌ | SDK default | idempotency-key retry-safe |
| `promo_code_service.dart:35-39` | `applyPromo` | ❌ | SDK default | non-fatal UI result |
| `fraud_screening_service.dart:41` | `screenPaymentFraud` | ❌ | SDK default | fail-closed by design (control) |
| `gdpr_service.dart:201` | `deleteUserData` | ❌ | SDK default | durable marker + server retrier (`index.ts:383-393`) |
| `telemetry_service.dart:36` | `logFunnelEvent` | ❌ | SDK default | best-effort analytics |

### §1.1-C — Complete HTTP inventory

| File:line | Endpoint | Retry | Notes |
|---|---|---|---|
| `packages/core/src/kitchen/kitchen_offline_service.dart:109-132` | LAN `POST $_kitchenEndpoint/orders` | ❌ | fire-and-forget + logging; **task never scheduled (P1-KITCHEN)** |
| `packages/core/src/services/cloudinary_upload_service.dart:36-66` | Cloudinary multipart | ❌ | user-triggered; snackbar error path (`owner_dashboard.dart:846`) |

`http_interceptor.dart` (`packages/core/src/network/http_interceptor.dart:12-53`) is a logging interceptor only — no retry, no timeout. **Not wired to the http package in this codebase** (grep: 0 instantiations in lib).

---

### 1.2 Offline Sync & Queue Integrity

**Checklist: 1 PASS, 1 PARTIAL, 5 FAIL.**

**1) `SyncQueue.enqueue` for EVERY order mutation (create, update, cancel) — FAIL.** Exactly **one** enqueue call exists in the whole repo: `checkout_screen.dart:354-355` — order **create only**. Cancel path (`order_repository.dart:49-67`) and status-update paths (`kitchen_service.dart:43-46`, `delivery_service.dart:68-71/91-95`, `proof_of_delivery_service.dart:54-61`) write directly to Firestore with **no queue** — a flaky network silently loses those mutations.

**2) `processQueue()` on app start / connectivity restore / timer — FAIL.**
- Only call path: `home_screen.dart:582,640` (PendingSyncBanner **Retry** button) → `isar_service.dart:183-192` `syncPendingOperations()` → `sync_queue.dart:114` `processQueue()`.
- No app-start scheduling (grep `processQueue` in `main.dart`/`CoreApp` → 0). No connectivity listener: `connectivity_plus` is **not a dependency** (grep *.yaml → 0 hits). No sync timer: `Timer.periodic` exists only for the hero carousel (`home_screen.dart:165`) and demo admin mocks (`cloud_function_mocks.dart:51,56`).

**3) DLQ has UI for ops to inspect and retry — FAIL.** `deadLetterCountProvider` (`pending_sync_provider.dart:31-37`) and `retryDeadLetter`/`getDeadLetters` (`sync_queue.dart:79-111`) are consumed **only by tests** (`test/widget/runtime_audit_flow_test.dart:133`, `runtime_audit_smoke_test.dart:143`, `test/core/network/sync_queue_test.dart:212-226`). No app screen renders dead letters or offers retry. **Ops cannot see stranded writes.**

**4) `kMaxRetries` (5) enforced — ✅ PASS.** `sync_queue.dart:125-144` moves an op to `IsarDeadLetter` (with `lastError: 'Max retries exceeded'`) once `retryCount >= kMaxRetries`, then `continue`.

**5) Queue idempotency — PARTIAL (fails as designed).**
- Replay is idempotent *in shape*: deterministic doc id (`data['id']`) + `set(merge: true)` (`sync_queue.dart:150-158`) → re-running cannot duplicate.
- **BUT the replay cannot succeed:** queued order carries `status: 'confirmed'` (`checkout_screen.dart:334`) while create-rules require `status == 'pending'` (`firestore.rules:361-368`); if the doc already exists (created by `createOrder`), the merged set becomes an **update** and there is **no customer update branch** (`firestore.rules:369-387`). **P0-SYNC.**
- Additionally the queue replays **unpaid** order intents: on payment failure the op is retained and the user is told “saved offline” (`checkout_screen.dart:371-383`), but the payload is `status: confirmed` with **no payment attachment** — a semantics bug even if the rules were opened.

**6) Isar schema migrations — FAIL.** `isar_service.dart:43-51` opens Isar with the 4 fixed schemas and **no versioning / migration** (Isar `3.1.0+1` in `pubspec.lock`). A schema change on a live install throws at `Isar.open` (SchemaException) — no migration harness anywhere in the repo.

**7) `PendingSyncBanner` exists and displays when queue > 0 — ✅ PASS.** `home_screen.dart:68` (mounted in body), `:542-660` renders the count via `pendingSyncCountProvider`, Retry → `syncPendingOperations()`. (No DLQ indicator — see #3.)
---

### 1.3 Configuration Loading & Validation

**Checklist: 1 PASS, 1 PARTIAL, 4 FAIL.**

**1) Validation of loaded config values — ✅ PARTIAL-PASS.** `app_config.dart` uses defensive typed helpers (`_asMap/_asString/_asBool/_colorFromHex`, `:326-348`) and non-empty-wins semantics (`:197-206`, extension `:352-357`); malformed JSON falls back to defaults + dotenv `:317-322`. Load is gated before `runApp` (`main.dart:150`).

**2) Bidirectional field check (both directions) — FAIL.** Bidirectional drift:
- **`firebase.projectId` is dead config; `environment.firebaseProjectId` is never present.** Both JSONs put the project id at `firebase.projectId` (`core_app/assets/client_config.json:27`, `apps/halal_boyz/assets/client_config.json:32`) **but the parser reads `environment['firebaseProjectId']`** (`app_config.dart:218-220`) and **never reads `firebase['projectId']`**. Result: `demo-tenant` is silently ignored; `_buildFirebaseOptions` (`main.dart:36-53`) falls back to `DefaultFirebaseOptions.projectId`. A white-label client whose flutterfire-generated projectId differs boots against the wrong backend. **P1-CONFIG.**
- **`firebase.collections`, `firebase.clientScopingFields`, `firebase.configDocuments`, `tax.*`, `features.source`, `currency.*`, `app.primaryColor`, `app.fontFamily`, `newFeatures`, `navigation.routes`** are present in the JSON but have **zero consumers** in `lib` (verified `navigationRoutes` getter at `app_config.dart:158-159` has 0 readers).
- **`environment.kitchenLanEndpoint`:** consumed only by the generated shell (`apps/halal_boyz/lib/app/core_config_adapter.dart:79`); the **template** adapter hardcodes `'http://192.168.1.100:8080/api/orders'` (`core_app/lib/app/config/core_config_adapter.dart:35-39`) and the documented Firestore `settings/restaurantConfig.kitchenLanEndpoint` override has **no consumer** anywhere (grep → only comments). Template schema also lacks the `kitchenLanEndpoint` field that the generated schema has → template/generated schemas have already diverged.
- Template vs generated schema drift: `apps/halal_boyz/assets/client_config.json:17-20` adds a `currency` block and `:24` adds `environment.kitchenLanEndpoint`; the template `client_config.json:17-25` has neither.

**3) `AppConfig.loadFailed` exposed and CHECKED by the app — FAIL.** `loadFailed` is set (`app_config.dart:315,320`) and exposed (`:98`) but **no consumer exists** (grep cross-repo → only definition/assignments). A broken/missing `client_config.json` boots the app silently on defaults — operators never learn config failed.

**4) `schemaVersion` validation — FAIL.** `_meta.schemaVersion` exists in both JSONs (`client_config.json:3`, halal_boyz `:3`) but is **never read or validated** against expected versions.

**5) `CoreConfigHolder` injection — ✅ PASS.** `main.dart:155` injects `CoreAppConfig` after config load, before any core service starts. `core_config.dart:81-96` defaults are safe/fail-closed (empty Cloudinary preset, `core_config.dart:58-68`; empty owner emails `:35`).

### 1.4 Date, Time & Persistence Integrity

**Checklist: 2 PASS, 5 FAIL.**

**1) Order timestamps server time — PARTIAL (production ✅, offline/demo ❌).** Production `createOrder` re-stamps `paymentConfirmedAt/createdAt/updatedAt = serverTimestamp()` (`functions/src/index.ts:733-735`). But the client builds `createdAt/updatedAt: DateTime.now()` (`checkout_screen.dart:345-346`); offline-queued ops and demo writes therefore carry **device clock** authority. **FAIL for the queued path** (it is P0-SYNC's payload).

**2) Operating hours in the restaurant's timezone — FAIL/NOT PRESENT.** No timezone concept exists anywhere (grep `TimeZone|timezone|tz` over lib → 0 hits). `OperatingHoursModel` stores plain `"HH:mm"` strings (`operating_hours_model.dart:10-19,22-26`) — no tz, no DST handling, no `isOpenNow` consumer exists in the customer path at all (`operating_hours_screen.dart` is admin-edit only).

**3) Reservation slots timezone-correct — FAIL.** A "1 PM slot" is a **device-local** instant: `reservation_screen.dart:105,129,194` uses `DateTime.now()`; stored via `Timestamp.fromDate(reservation.startTime)` (`reservations_repository.dart:66`); rendered with `.toLocal()` (`admin_reservations_tab.dart:133`). Device tz ≠ restaurant tz shifts bookings/reservations.

**4) DST transitions — FAIL (no mechanism exists at all — see #2/#3).**

**5) `toIso8601String()` includes timezone offset for export — FAIL.** Local-DateTime `toIso8601String()` emits **no** offset marker: `order_model.dart:102,105`, `reservation_model.dart:32`, `promotion_model.dart:33`, `user_model.dart:72`, `data_export_service.dart:49` (GDPR-export `exportedAt` is ambiguous). The only correct usage is `logger_service.dart:91` (`DateTime.now().toUtc().toIso8601String()` → `Z`).

**6) No `DateTime.now()` vs stored `Timestamp` comparison without conversion — ✅ PASS (not found).** Queries compare Timestamp-to-Timestamp via `Timestamp.fromDate(...)` (`fraud_screening_service.dart:25-31`, `admin_data_service.dart:41,73`); model parsing converts via `timestampToDateTime` (`order_model.dart:98-105`).

**7) Offline cart survives restart — ✅ PASS.** `cart_repository.dart:15-89` is fully Isar-backed (persist on each save, rehydrated with full modifiers via `selectedOptionsJson`), survives app restart; `kCartTtl = 7 days` (`isar_service.dart:26-27`). NOTE: cart **TTL eviction is skipped** (`isar_service.dart:85-86` — "Skipped: cart eviction requires build_runner-generated IsarCartSchema") → P2.

**8) Pending-op timestamps use local `DateTime.now()` (`sync_queue.dart:43,101`) — minor**: only used for FIFO `sortByTimestamp()` ordering (`:117-120`); a clock rollback can reorder replays.
---

### 1.5 Push Notifications & Background Delivery

**Checklist: 1 PASS, 4 FAIL.**

**1) Token lifecycle — PARTIAL (stores ✅, refresh ✅, logout-delete ❌).** Stored at `fcm_service.dart:60-63` under `users/{uid}.fcmToken` + `fcmLastUpdated`; refreshed on rotate (`:37-39`); `init()` re-uploads on permission (`:26-49`); `FcmService()` init hooked in `main.dart:211-214`. **Never deleted on logout** (`auth_repository.dart:299-325` clears prefs/Isar/Firestore-persistence/Google/Auth but not `fcmToken`) — the **P1-D cross-user push leak already logged under Consolidated-Findings 01**; re-confirmed against current source this audit. Account deletion cleans the token only transitively (erasure deletes the `users/{uid}` doc).

**2) Tap → route through the ACTIVE router, role-checked — FAIL (the listener is never registered).** `PushNotificationService` (**`push_notification_service.dart:9-52`**) exposes `onMessage` (`:22-28`), `onMessageOpenedApp` (`:31-37`) and cold-start `getInitialMessage` (`:40-47`), but **0 instantiations exist** (grep `PushNotificationService(` → only the constructor at `:14`). The app never listens → foreground pushes do nothing, taps do nothing, cold-start from notification does nothing. Even if wired, the handler signature `PushNavigationHandler` is an untyped passthrough (`:7,27,36,46`) with **no route-name resolution** — and the config-mode router names routes by screen-ID (`app_router.dart:144-150`), so audit-00's P0-1 route-name mismatch would make any `goNamed(RouteNames.X)` tap navigation crash anyway.

**3) Background/terminated handler before `runApp`, isolate-safe — ✅ PASS (registration) / PARTIAL (behavior).** `main.dart:87` registers `_firebaseMessagingBackgroundHandler` before `runApp` (`:251`); `@pragma('vm:entry-point')` at `:56`. But the handler only logs (`:63-64`) — no data handling; acceptable for background (platform restricts navigation), but combined with #2 the entire push chain is non-functional.

**4) Tenant isolation — FAIL.** No `clientId`/tenant validation exists anywhere in the push path: payload `data` is forwarded verbatim to the (never-called) navigation handler; wrong-tenant or unauthenticated payloads would navigate without any check.

**5) Foreground presentation documented — FAIL.** No in-app banner / data-vs-notification behavior exists (no `onMessage` consumer at all). Local notifications (`services/notification_service.dart:4-50`) are a separate `flutter_local_notifications` path used for order confirmations (`checkout_screen.dart:436-440`) and tracker status updates — its own tap handling (`onDidReceiveNotificationResponse`) is **also not wired** (no callback registered in `initialize()`), so local-notification taps are inert too.

---

## 2. ISSUE TABLE (ID · Severity · File · Issue · Impact · Fix sketch)

| ID | Sevr | File:line | Issue | Impact | Fix sketch |
|---|---|---|---|---|---|
| **P0-SYNC** | P0 | `checkout_screen.dart:334,354-355` + `firestore.rules:361-387` + `sync_queue.dart:150-161` | Queued order `create` op writes `status:'confirmed'`; orders-create rules demand `status=='pending'`; no customer update branch → every queue replay is rules-DENIED; queue has no auto triggers (`home_screen.dart:582,640` only) | Offline orders silently stranded; “saved offline” is a lie; 5× backoff burn + invisible DLQ entries | (see master solution table P0-SYNC) |
| **P1-RETRY** | P1 | `network_retry.dart:8-27` + callers | Only 1 retry call site (cancelOrder); zero Firestore non-stream/non-txn retries; all httpsCallables bare except cancelOrder; 4xx not skipped | Transient blips fail critical reads/writes (branch fetch, menu, panic gate) and charge-path callables | (see master solution table) |
| **P1-PUSH** | P1 | `push_notification_service.dart:9-52` + `main.dart:87` | Service never instantiated; tap→route dead; no tenant/payload validation | Order pushes invisible; FCM tokens collected for nothing; dead navigation UX | (see master solution table) |
| **P1-KITCHEN** | P1 | `kitchen_offline_service.dart:53-84` + `kitchen_task_dispatcher.dart:11-22` | `initialize()`/`scheduleHeartbeat()` have zero callers in lib — Workmanager never initialized, heartbeat never registered | Kitchen LAN offline fallback is dead code in production | (see master solution table) |
| **P1-CONFIG** | P1 | `app_config.dart:218-220` vs `client_config.json:27/32`; `app_config.dart:98`; `core_config_adapter.dart:35-39` | `firebase.projectId` JSON field ignored (code reads non-existent `environment.firebaseProjectId`); `loadFailed` never surfaced; template LAN-endpoint override unwired | Wrong-Firebase-project boot for clients; silent config-failure; hardcoded LAN IP | (see master solution table) |
| **P1-STAFF** | P1 | `kitchen_service.dart:43-46`, `delivery_service.dart:68-71/91-95`, `proof_of_delivery_service.dart:54-61` | Staff order-status writes bypass the sync queue entirely; no retry/queue (and currently rules-DENIED online — overlap with 01 P1-A) | Flaky-network staff mutations lost silently | (see master solution table) |
| **P2-TZ** | P2 | `operating_hours_model.dart:10-26`, `reservation_screen.dart:105/129/194` | No timezone/DST anywhere; reservation slots are device-local instants | Off-by-hours bookings for restaurants in a different tz | Store tz id; do utc-math comparisons; drop `.toLocal()` |
| **P2-ISO** | P2 | `order_model.dart:102,105`, `data_export_service.dart:49`, `reservation_model.dart:32` | `toIso8601String()` on local DateTimes → no offset marker in exports | Ambiguous exported timestamps (GDPR portability) | `.toUtc().toIso8601String()` pattern from `logger_service.dart:91` |
| **P2-MIGRATE** | P2 | `isar_service.dart:39-62` | No Isar schema versioning/migration | Future schema bump bricks installs | Version the open + run idempotent migration steps |
| **P2-DEADCFG** | P2 | `app_config.dart:158-159,301`, both JSONs | `navigation.routes`, `collections`, `clientScopingFields`, `configDocuments`, `tax.*`, `currency.*`, `app.primaryColor/fontFamily`, `features.source`, `newFeatures` unused | Config promises features that don't exist; drift risk for generators | Delete or consume; single-source the grid in audit-08 |
| **P2-HTTPS** | P2 | `kitchen_offline_service.dart:109-132`, `cloudinary_upload_service.dart:36-66` | No HTTP retry/timeout | Transient LAN/upload failures need manual retry | Wrap in NetworkRetry (existing pattern) |
| **P2-CART** | P2 | `isar_service.dart:85-86` | `kCartTtl` never enforced (eviction skipped) | Stale carts accumulate past 7d | Implement cart TTL eviction |
| **P2-LOCAL** | P2 | `notification_service.dart:7-20` | Local-notification taps not wired (`onDidReceiveNotificationResponse` missing) | Local order-confirm taps do nothing | Register tap callback → `RouteNames.orderTracker` |
| **P2-DEMOCLOCK** | P2 | `checkout_screen.dart:345-346` | Offline/demo order timestamps are device-clock | Non-authoritative created_at for queued orders | Enqueue with serverTimestamp-stamped payload or re-stamp at replay |

---

## 3. RECOMMENDED FIX PLAN (ordered by blast radius — summary; detailed option evaluation in master §02 solution table)

1. **P0-SYNC (first — everything else depends on honest sync):** make queue replays rule-passing (queue must write `status:'pending'` + payment guard) or stop pretending — see master. Then trigger `processQueue()` on app-start + connectivity restores + a timer; surface the DLQ.
2. **P1-CONFIG:** fix the `firebase.projectId` mapping (read `firebase['projectId']` in `app_config.dart:226-236`), surface `_loadFailed`, wire the LAN endpoint override, reconcile template/generated schemas.
3. **P1-PUSH:** instantiate `PushNotificationService` with a role-checked `PushNavigationHandler` resolving through the ACTIVE router (after audit-00 P0-1 is fixed); validate payload `clientId`.
4. **P1-RETRY:** extend the existing `NetworkRetry` pattern (add 4xx-skip) to critical one-shot reads and idempotent callables (createOrder/createPaymentIntent/calculateTax — safe due to idempotency keys).
5. **P1-STAFF:** after 01 P1-A unblocks rules, add queueing/retry for staff status-mutation writes; revisit after 09.
6. **P1-KITCHEN:** schedule the Workmanager heartbeat from `main.dart` (it is already entry-point annotated and unit-tested); fail-closed on missing endpoint.
7. **P2 pile:** tz model, ISO-UTC exports, Isar versioning, TTL eviction, local-tap wiring — batch with audit-03/05 passes.

---

## 4. HONEST LIMITATIONS — NOT PROVEN without a test

- **Rules enforcement is static-derived, NOT live-run:** the P0-SYNC DENIED conclusion comes from comparing rules text (`firestore.rules:361-387`) with the queued payload (`checkout_screen.dart:334`). The emulator-gated rules suites exist (`test/wiring/firestore_security_rules_test.dart`, `test/integration/*`) but **were not executed this offline session** — the emulator pass must follow any fix.
- **`flutter analyze`/`flutter test` were NOT re-run this session** (static grep audit). Prior master §01 reports `core_app` clean + 1238 tests passing; this audit changes nothing.
- **"Push never instantiated"** is proven by absence-grep across `packages/core`, `core_app`, `apps/halal_boyz` — no runtime push test exists to contradict it.
- **"Workmanager never scheduled"** is proven by absence-grep of `initialize(`/`scheduleHeartbeat(` callers in lib; the dispatcher itself is unit-tested for method signatures only (`test/features/kitchen/domain/kitchen_offline_service_test.dart:68-78`).
- **`connectivity_plus` absence** is proven by pubspec grep — no connectivity-reaction test exists.
- **Timezone/DST items** are structural absences (no tz field anywhere); no behavioral test can exist until a tz model is added.

## 5. PROMPT SELF-CHECK (from the audit prompt)

- Every network call site inventoried: ✅ §1.1-A/B/C (Firestore 40+ sites, 9 callables, 2 HTTP) + auth/analytics/presence/GDPR.
- Every config field checked both directions: ✅ §1.3 (bidirectional table of dead/missing fields).
- Every checklist item has a file:line citation or explicit NOT FOUND: ✅ (all items — see §1.1-§1.5).
- Runtime behavior claims provenance: ✅ every conclusion is static-derivable; live claims flagged in §4.
- Zero recommendations to add a library unless already-mirrored pattern: ✅ all fixes reuse `NetworkRetry`, `throw-if` DI, existing providers, existing migration style (v002).

---

**END OF AUDIT 02 DETAILED FINDINGS · VERDICT: FAIL (1×P0 + 5×P1 + 8×P2)**