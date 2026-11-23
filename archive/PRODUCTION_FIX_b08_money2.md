# BATCH MONEY-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W3.2, W3.4.**

## 8. BATCH MONEY-2 - REFUND-REPLAY GUARD + cancelOrder CALLABLE

**Predecessor:** MONEY-1. **Emulator-gated:** money-emulator. **Master:** W3.2, W3.4. **MIRROR: backend only; client needs zero changes.**

### 8.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `index.ts:742-756, 700-704` | Refund leaves PI `succeeded`; client keeps session key on failure and retries; `createOrder` checks only `status !== 'succeeded'` -> order confirmed on a refunded charge | P1 (06-P1-1) |
| P-2 | `index.ts:746` | Only refund = compensating handler, fire-and-forget (`console.error` swallow), no record | P1 (06-P1-1) |
| P-3 | `functions/src` (17 exports) | `cancelOrder` callable ABSENT; client `order_repository.dart:56-67` already calls it; l10n dialog strings exist | P1 (01-P1-B = 09-P1-FB-3) |

### 8.2 Solution - design principle + acceptance contract

**Design principle:** money paths are CF-authoritative; the client already follows the contract - the server must complete it, idempotently.

**Acceptance contract (from master W3.2/W3.4):**
1. `createOrder` pre-check (~:700-704): besides `paymentIntent.status !== 'succeeded'`, fetch PI charges; if any charge `refunded === true` or a refund exists -> reject `already-refunded`, fail-closed, persist a minimal refund record `orders/{id}.refunds[]` (amount, reason, at).
2. Compensating-refund failure handler: `await` + `logger.error` (no fire-and-forget swallow); never throw past the caller's idempotent retry.
3. New `cancelOrder` callable (mirror `createOrder` structure): `enforceAppCheck` + auth; zod `{orderId: string}`; load order; assert `order.customerId == request.auth.uid`; assert `status in ['pending','confirmed']`; if `paymentIntentId` present and charge capturable -> `stripe.refunds.create` (idempotency key `cancel-{orderId}`); Admin-SDK update `{status:'cancelled', cancelledAt, cancelledBy:'customer'}`; idempotent on re-call (already cancelled -> ok). Failure-path events per `index.ts:902` conventions.

### 8.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Refunded-PI replay denied | `money.test.js`: PI with refunded charge -> `createOrder` rejects `already-refunded`, refund record persisted |
| T-2 | cancelOrder happy path | Emulator: customer cancels pending/confirmed order -> status `cancelled`, refund issued, `cancelledBy:'customer'` |
| T-3 | cancelOrder non-owner denied | Different uid -> `permission-denied` |
| T-4 | cancelOrder delivered denied | `delivered` status -> rejected |
| T-5 | cancelOrder replay idempotent | Second call with already-cancelled -> ok (no double refund) |
| T-6 | Compensating refund no longer fire-and-forget | Code read: `await` + error log present |

### 8.4 Proof gates

- [ ] `npm test` green (T-1 + cancelOrder unit cases)
- [ ] `npm run test:money-emulator` green (T-2..T-5)
- [ ] grep `cancelOrder` in `functions/src` > 0 (export present)
- [ ] grep `refunds` on the order doc write present
- [ ] Universal Gate Set U (index Section 1)

### 8.5 Honest residuals

- Stripe refund-call correctness is asserted via the emulator harness (mock Stripe); live refund behavior is a RELEASE-2 deploy-time smoke item.
- Refund record schema: keep it minimal and documented (amount, reason, at, refundId if available).

**END OF BATCH MONEY-2 SPEC** - do not proceed until these gates pass and the MONEY-2 addendum is appended to FIX_VERIFICATION.md.