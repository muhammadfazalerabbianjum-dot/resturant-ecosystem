# BATCH MONEY-3 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W3.5, W3.6, W3.7, W3.8.**

## 9. BATCH MONEY-3 - ERASURE COVERAGE + COMPOSITE INDEX + WEBHOOK + DEAD-CODE REMOVAL

**Predecessor:** MONEY-1 (safe after MONEY-2). **Emulator-gated:** GDPR emulator. **Master:** W3.5, W3.6, W3.7, W3.8. **MIRROR: erasure demo mirror must match server - both updated.**

### 9.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `index.ts:195-236` + `gdpr_service.dart:51-129` | Erasure misses `deliveries`, `analyticsEvents`, `audit_log` user rows, Storage `proof_of_delivery/*` + `avatars/*` | P0 (06-P0-2) |
| P-2 | `driver_location_service.dart:99-105` | `deliveries` rows have NO uid field - not queryable for erasure | P0 (06-P0-2) |
| P-3 | `firestore.indexes.json` | Missing composite `orders(status ASC, createdAt ASC)` -> analytics charts `failed-precondition` on real data | P1 (09-P1-FB-4) |
| P-4 | `index.ts:998-1015` | Webhook handles ONLY `payment_intent.succeeded`; refunds/failures leave no trace | P2 (06-P2-2) |
| P-5 | `order_repository.dart` `submitOrderAtomically` | Dead test-only path whose payload mismatches `createOrder` | Minor (verification_report 6.4) |

### 9.2 Solution - design principle + acceptance contract

**Design principle:** ONE canonical erasure set; demo mirrors server exactly; the retrier reuses the same functions.

**Acceptance contract (from master W3.5/W3.6/W3.7/W3.8):**
1. `collectUserDocs` (server) + demo mirror: collect + erase `deliveries` (key by the user's order IDs gathered BEFORE deleting orders; ALSO stamp `driverId` on new `deliveries` writes so future rows are directly queryable), `analyticsEvents` (uid query), `audit_log` user rows (uid query; keep settings rows per legal-basis comment), Storage prefixes `proof_of_delivery/{orderId}/*` + `avatars/{userId}/*` via Admin SDK `bucket.deleteFiles`.
2. `gdpr_erasure_test.js` extended to the 4 new stores (extend, not replace).
3. Legal-basis comment on `deletion_requests` + `audit_log` settings-rows retention.
4. `firestore.indexes.json`: add composite `orders` `(status ASC, createdAt ASC)`.
5. Webhook: record `payment_intent.payment_failed` + `charge.refunded` on the order doc (status + webhook event log array, size-capped 20).
6. `createPaymentIntent`: `receipt_email` = authenticated user's email (Stripe-hosted receipt), opt-out-safe.
7. `createPaymentIntent`: validate `deliveryFeeCents` against `settings/restaurantConfig` (server re-read, mismatch -> clamp to server value).
8. REMOVE `OrderRepository.submitOrderAtomically` + its tests (`test/idempotency_test.dart` + `chaos_checkout_test.dart` refs); port valuable assertions onto the production `checkout_service` path.

### 9.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Erasure covers 4 new stores (demo) | Seed deliveries/analyticsEvents/audit_log rows + Storage objects; run demo `deleteMyData`; all gone |
| T-2 | Erasure covers 4 new stores (server CF) | Emulator integration, same seed; server `deleteUserData` erases all + Storage objects deleted |
| T-3 | deliveries carry driverId going forward | `driver_location_service` write includes `driverId` |
| T-4 | Index present | JSON contains the composite; charts query shape matches |
| T-5 | Webhook failure/refund recorded | Emulator: `payment_intent.payment_failed` + `charge.refunded` events -> order doc updated, event log capped at 20 |
| T-6 | deliveryFee validated | Tampered fee -> clamped to server config value |
| T-7 | Dead path gone | grep `submitOrderAtomically` = 0 |

### 9.4 Proof gates

- [ ] GDPR emulator suite green (extended to the 4 new stores)
- [ ] `npm test` + `npm run test:money-emulator` green
- [ ] `firestore.indexes.json` contains `status ASC, createdAt ASC`
- [ ] grep `submitOrderAtomically` in repo = 0
- [ ] Universal Gate Set U (index Section 1)

### 9.5 Honest residuals

- `audit_log` settings rows are intentionally retained (audit-proof) - legal basis documented; user rows ARE erased (uid-queryable).
- `deliveries` backfill for EXISTING rows (pre-driverId) via the erasure-by-order-IDs path - record that one-time scan needs to run against production data at deploy (RELEASE-2 class).

**END OF BATCH MONEY-3 SPEC** - do not proceed until these gates pass and the MONEY-3 addendum is appended to FIX_VERIFICATION.md.