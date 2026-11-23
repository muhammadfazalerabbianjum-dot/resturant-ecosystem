# BATCH 1 — MONEY INTEGRITY + CURRENCY · P0 RELEASE-BLOCKER

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST.

## PROBLEM
| # | Evidence (current source) | Issue |
|---|---|---|
| P0-1 | `core_app/functions/src/index.ts:413-423` | `createPaymentIntent` takes `taxCents`/`discountCents` from the client, clamps only non-negative + `discount <= subtotal` (:421-423). Hostile client sends `taxCents:0` (underpays tax) or `discountCents ~ subtotal` (pays ~nothing). Money gap, FAIL-CLOSED violated. |
| P0-2 | `checkout_service.dart:161-180,286-294` + `promo_code_service.dart:21` | `calculateTax` is advisory (display only); the same client tax/discount is forwarded to the charge. Promo codes validated CLIENT-SIDE only; discount client-supplied, no server check. |
| P1 | `index.ts:441` | `currency: 'usd'` hardcoded in the money path. Breaks white-label multi-currency. |

## SOLUTION — server is authoritative
1. **Server-side tax re-derivation.** Add `stateCode` to the `createPaymentIntent` schema
   (already used by `calculateTax`). Inside, read `settings/taxRates.clients[clientId].stateRates`
   (the exact lookup `calculateTax` uses), compute `taxCents = round(subtotal * rate)` server-side,
   and IGNORE client `taxCents` entirely — a differing client value still charges the server
   amount (never less tax). Unknown `stateCode` → throw `failed-precondition` (never $0 tax).
2. **Server-side promo validation.** New `onCall('applyPromo')` `{code, cartSubtotalCents, userId}`:
   read `promoCodes/{code}`; validate active window + remaining uses + per-user `promo_usage`
   (uid-scoped, idempotent write); compute the discount (percentage or fixed, clamped to subtotal)
   and RETURN the authoritative discount. `createPaymentIntent` then charges
   `subtotal + serverTax - serverDiscount`; client may only SEND the code, never a `discountCents`
   value. Track `promo_usage` at charge time (uid-scoped doc, one per code+user, idempotent).
3. **Currency config-driven.** Read currency from `settings/taxRates.clients[clientId].currency`
   (or `settings/restaurantConfig.currency`) at charge time; validate against a small allowlist;
   remove the literal `'usd'` at `index.ts:441`.
4. **Keep** the `createOrder` money-equality check (`index.ts:507-516`) and the compensating
   refund (`:536-548`). `createOrder` must ALSO verify the stored order's tax/discount equal the
   server-derived values (belt-and-suspenders).
5. **Client:** `checkout_service` sends `{code}` (not discountCents) and uses the server
   `applyPromo`/tax returns for display; `processStripePayment` only forwards item subtotal +
   server tax + server discount. Update any test that relied on client tax.

## TESTS (hard, behavior-asserting — functions unit + integrate)
| Test | Asserts |
|---|---|
| T-M1 | client `taxCents:0` is ignored; charge uses server-derived tax (hostile override cannot change the amount) |
| T-M2 | unknown `stateCode` → `failed-precondition`; never $0 tax |
| T-M3 | `discountCents` > subtotal or non-server promo → rejected; server-computed discount only |
| T-M4 | `applyPromo` rejects inactive / exhausted / outside-window / already-used codes; idempotent per user+code |
| T-M5 | currency comes from config per clientId; valid ones charged in that currency; invalid → throw (no silent USD fallback) |
| T-M6 | money-equality still enforced in `createOrder` (regression) |

## GATES (must ALL pass)
- [ ] `Select-String -Path core_app/functions/src -Pattern "currency: 'usd'|'usd'"` → **0 matches**.
- [ ] `Select-String -Path core_app/functions/src -Pattern "discountCents|taxCents"` → only as server-computed values (no client-trusted charge inputs).
- [ ] FN-TEST + emulator `functions` run → green.
- [ ] `flutter test` (core_app checkout/order suites) → green (U-NOBREAK).
- [ ] Gate set U; zero skips; B1 addendum appended.

## RESIDUALS (honest)
- Stripe live webhook is NOT provable statically (deploy-time — see B6 matrix). Logic is
  written and unit-tested; live smoke belongs to B6.

**END OF BATCH 1.** Not closed until Gates green + addendum appended.