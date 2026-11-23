# BATCH MONEY-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W3.1.**

## 7. BATCH MONEY-1 - SERVER-AUTHORITATIVE CHARGE + STORED-ORDER VERIFICATION + MENU CROSS-CHECK

**Predecessor:** CI-3. **Emulator-gated:** money-emulator. **Master:** W3.1. **MIRROR: backend only (client needs no change this batch).**

### 7.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/functions/src/payment.ts:192-210` | `computeItemsSubtotalCents` sums CLIENT-supplied `priceCents`; no `menus` read anywhere in functions | P0 (06-P0-1 = 09-P0-FB-2) |
| P-2 | `core_app/functions/src/index.ts:575-605` | `createPaymentIntent` re-derives subtotal from client items; tampered client pays $1 for a $50 item and every equality check passes | P0 (06-P0-1) |
| P-3 | `core_app/functions/src/index.ts:712-736` | `createOrder` stores client `order` JSON nearly verbatim via Admin SDK (rules bypassed); only total/tax/discount verified | P0 (06-P0-1) |
| P-4 | `payment.ts:388-443` | `verifyOrderCharge` checks only internal consistency - items/status/tip/deliveryFee/orderNumber/branchId trusted | P0 (06-P0-1) |

### 7.2 Solution - design principle + acceptance contract

**Design principle:** the server is the ONLY source of money truth. The client sends intent; the server re-derives from `menus`, verifies against PaymentIntent metadata, and builds the stored order server-side.

**Acceptance contract (from master W3.1):**
(a) `verifyOrderCharge` extension:
- Recomputed subtotal of the STORED `order.items` via `computeItemsSubtotalCents(order.items)` == `metadata.itemsSubtotalCents` (metadata already stamped at `index.ts:621-626`).
- `order.tipCents == metadata.tipCents`; `order.deliveryFeeCents == metadata.deliveryFeeCents`.
- `order.status` in allowlist `['confirmed']` (reject anything else).
- `order.totalCents == itemsSubtotal + tax + deliveryFee + tip - discount` (server re-derived).
- On mismatch: fail-closed, refund the PI (reuse the compensating-refund helper), log to the `firestore-security-alerts` class, return typed error.
(b) Menu cross-check (phase 2, same wave): `createPaymentIntent` reads `menus/{menuItemId}` per item (Admin SDK), asserts `priceCents` == server price + option upcharges; unknown/disabled -> `failed-precondition`. Batch reads (getAll) to stay 1-read-per-item.
(c) `createOrder`: stop trusting the client `order` spread - build the stored doc server-side from validated fields only (id, paymentIntentId, idempotencyKey, server timestamps, VERIFIED items/totals/tax/discount/tip/deliveryFee/status, customerId/userId from auth, branchId re-read, orderNumber server-generated if absent). Nothing else persisted.

### 7.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Client-priced tamper rejected | `money.test.js`: item price lower than `menus` price -> `createPaymentIntent` fails closed, no Stripe charge |
| T-2 | Metadata equality enforced | Stored items subtotal / tip / deliveryFee mismatch -> `createOrder` rejects + refunds |
| T-3 | Status allowlist | Client sends `status:'delivered'` -> rejected |
| T-4 | Total internal consistency | Client total != server re-derivation -> rejected |
| T-5 | End-to-end emulator | `money_emulator_check.js`: real emulator Firestore, tampered item rejected end-to-end |

### 7.4 Proof gates

- [ ] `npm test` green (extended `money.test.js`, T-1..T-4)
- [ ] `npm run test:money-emulator` green (T-5)
- [ ] grep `menus` in `functions/src` > 0 (menu cross-check present; token corrected 2026-09-01 spec audit — the gate previously said `menuItems`, contradicting P-1 and the `menus/{menuItemId}` contract)
- [ ] Universal Gate Set U (index Section 1)

### 7.5 Honest residuals

- Live Stripe calls are NOT provable in the emulator (no real key). Amounts/args asserted via the pure module + emulator harness; live smoke is a RELEASE-2 deploy-time item.
- Branch re-read: `order.branchId` must come from the verified menu/branch context; if a menu doc lacks branchId, record and fail-closed (never default).

**END OF BATCH MONEY-1 SPEC** - do not proceed to MONEY-2 until these gates pass and the MONEY-1 addendum is appended to FIX_VERIFICATION.md.