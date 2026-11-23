# BATCH QUEUE-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W5.1.**

## 12. BATCH QUEUE-1 - OFFLINE QUEUE DELIVERABLE + AUTO-TRIGGERS + DLQ UI

**Predecessor:** RULES-1 (rules legal) AND ROUTER-1 (DLQ route). **Emulator-gated:** rules emulator. **Master:** W5.1. **MIRROR: shell carries main.dart + routers - mirror startup + DLQ route.**

### 12.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `checkout_screen.dart:334,355` | Queue enqueues unpaid `status:'confirmed'`; create-rules require `pending`; no customer update branch -> every replay rules-DENIED -> invisible DLQ | P0 (02-P0-SYNC) |
| P-2 | `sync_queue.dart` + no callers | `processQueue()` has NO auto trigger (no app-start, no connectivity listener, no timer) - only PendingSyncBanner Retry | P0 (02-P0-SYNC) |
| P-3 | `deadLetterCountProvider`/`retryDeadLetter` | DLQ exists but has NO UI (tests only) | P0 (02-P0-SYNC) |
| P-4 | `sync_queue.dart:167-176` | Retries catch EVERYTHING incl. rules-DENIED -> burns retries on permanent failures | P1 (02-P1-RETRY companion) |

### 12.2 Solution - design principle + acceptance contract

**Design principle:** the queue stays offline-first but replays only rules-legal `pending` intents; money stays CF-authoritative (never replay an unpaid intent as `confirmed`); auto-triggers make it self-delivering; DLQ is visible.

**Acceptance contract (from master W5.1):**
(a) Payload legality: enqueue a SEPARATE payload with `status:'pending'` (rules-legal create per `firestore.rules:361-368`), + `offlineQueued: true`, + `queuedAt` (ISO). The in-memory/UI order object is NOT mutated. NEVER enqueue `confirmed`.
(b) Auto-triggers in `main.dart` after `IsarService().openDB()` (:245): (1) app-start `unawaited(syncQueue.processQueue())`; (2) NEW `ConnectivitySyncTrigger` in `core_app/lib/app/` - add `connectivity_plus` to `core_app/pubspec.yaml` ONLY (the sanctioned dep); on connectivity-restored (debounce 5 s) -> `processQueue()`; (3) periodic safety net: Workmanager pattern (`kitchen_task_dispatcher.dart` style) 15-min task -> `processQueue()`, `existingWorkPolicy: keep`.
(c) Retry classification in `sync_queue.dart` (~:167-176): `permission-denied`/rules-rejection -> immediate DLQ (no retry burn); transient (unavailable/deadline-exceeded/network) -> existing exponential retries then DLQ.
(d) DLQ UI: new minimal owner/admin-only screen + route registered in BOTH routers (via the W2 map); lists `IsarDeadLetter` via existing providers, row actions retry + dismiss; PendingSyncBanner links to it.

### 12.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Enqueued payload is `pending` + `offlineQueued` | Unit: `syncQueue.enqueue` payload assert |
| T-2 | Rules-legal create | Rules harness: create `orders` with `status:'pending'` + app-verified non-anon -> ALLOW |
| T-3 | permission-denied -> instant DLQ | `sync_queue_test.dart`: rules-rejection error -> dead letter, retry count 0 |
| T-4 | App-start trigger calls processQueue | Widget/unit: main startup flushes once |
| T-5 | Connectivity trigger fires on restore | Unit: `ConnectivitySyncTrigger` debounced call on restored event |
| T-6 | DLQ screen lists + retries | Widget: seeded dead letters -> rows + retry action |

### 12.4 Proof gates

- [ ] Queue unit tests green (T-1, T-3)
- [ ] `npm run test:rules` green (T-2 case present; extended total recorded)
- [ ] grep `processQueue(` now has app-start + connectivity + timer callers
- [ ] `connectivity_plus` present ONLY in `core_app/pubspec.yaml`
- [ ] Universal Gate Set U (index Section 1)

### 12.5 Honest residuals

- Connectivity events are platform-driven; on startup with no connectivity the queue stays parked until a trigger fires (documented behavior, not loss).
- The 15-min Workmanager task duplicates the app-start flush - `existingWorkPolicy: keep` + guarded bool prevent duplicate registration.

**END OF BATCH QUEUE-1 SPEC** - do not proceed to QUEUE-2/STAFF-QUEUE until these gates pass and the QUEUE-1 addendum is appended to FIX_VERIFICATION.md.