# BATCH QUEUE-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W5.2.**

## 13. BATCH QUEUE-2 - REAL RETRY COVERAGE

**Predecessor:** QUEUE-1. **Emulator-gated:** no. **Master:** W5.2. **MIRROR: network_retry + wrapped services are shared `packages/core` code - shell inherits automatically (no shell copy); verify none wrapped in shell-local files.**

### 13.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `packages/core/lib/src/network/network_retry.dart` | `withExponentialBackoff` exists but has exactly ONE call site (`order_repository.dart:59`) | P1 (02-P1-RETRY) |
| P-2 | one-shot reads | No retries on `checkout_service.dart:138` branch fetch, `menu_repository.dart:99`, `panic_switch_service.dart:48`, `auth_repository.dart:54` | P1 (02-P1-RETRY) |
| P-3 | callables | Bare `.call()` on `applyPromo`, `calculateTax`, `createPaymentIntent`, `createOrder`, `gdpr_service.dart:201` | P1 (02-P1-RETRY) |
| P-4 | `network_retry.dart:14-25` | Retries don't skip 4xx/user errors -> wasted retries on permanent failures | P1 (02-P1-RETRY) |

### 13.2 Solution - design principle + acceptance contract

**Design principle:** retry with classification; only idempotent ops get blind retries; fail-closed semantics unchanged.

**Acceptance contract (from master W5.2):**
1. Add `static bool isRetryable(Object error)` to `NetworkRetry`: skip `FirebaseFunctionsException` codes `permission-denied|not-found|invalid-argument|unauthenticated|failed-precondition|already-exists`; skip Firestore `permission-denied`.
2. Wrap idempotent ops only: `checkout_service.dart:138`, `menu_repository.dart:99`, `panic_switch_service.dart:48`, `auth_repository.dart:54`, callables `applyPromo`/`calculateTax`/`createPaymentIntent`/`createOrder` (idempotency-key safe per `checkout_service.dart:296-299`), `gdpr_service.dart:201`.
3. Keep `screenPaymentFraud` fail-closed (no blind retry).

### 13.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | 4xx skip | `sync_queue_test.dart` style: `permission-denied` NOT retried |
| T-2 | Backoff sequence | Transient error -> exponential backoff, bounded |
| T-3 | Idempotent callables wrap | Unit: `createOrder` with idempotency key retried safely (no double charge) |
| T-4 | screenPaymentFraud unwrapped | Code read: no `NetworkRetry` on the fraud call |

### 13.4 Proof gates

- [ ] New unit tests green (T-1..T-3)
- [ ] grep `withExponentialBackoff|isRetryable` call sites > 1 (was 1)
- [ ] `flutter test` (packages/core) green
- [ ] Universal Gate Set U (index Section 1)

### 13.5 Honest residuals

- Some wrapped callables are inherently at-least-once; idempotency keys cover createOrder/PI; `applyPromo`/`calculateTax` are pure reads - safe.
- Chaos tests (`chaos_checkout_test.dart`) simulate failure at the repository layer; this batch adds transport-level classification - both remain.

**END OF BATCH QUEUE-2 SPEC** - do not proceed until these gates pass and the QUEUE-2 addendum is appended to FIX_VERIFICATION.md.