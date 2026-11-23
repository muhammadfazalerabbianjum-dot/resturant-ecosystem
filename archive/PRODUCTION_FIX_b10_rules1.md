# BATCH RULES-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W4.1, W4.2, W4.3, W4.6, W4.7, W4.9, W4.10.**

## 10. BATCH RULES-1 - FIRESTORE RULES ALIGNMENT + READ FIXES

**Predecessor:** MONEY-3. **Emulator-gated:** rules emulator. **Master:** W4.1, W4.2, W4.3, W4.6, W4.7, W4.9, W4.10. **MIRROR: rules are shared server config; app behavior unchanged this batch.**

### 10.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `firestore.rules:380,386` | Kitchen/delivery update `hasOnly(['status'])` DENIES real payloads carrying `updatedAt`; manager `[:371-374]` also blocks `updatedAt` | P1 (01-P1-A) |
| P-2 | `delivery_service.dart:29-37` | Driver `myOrders` query has no `branchId` filter; delivery read clause requires it -> runtime DENIED (rules-not-filters) | P1 (09-P1-FB-1) |
| P-3 | `firestore.rules:351-353` | Kitchen read clause allows `['confirmed','preparing']`; dashboard streams `['ready']` -> DENIED | P1 (09-P1-FB-2) |
| P-4 | `firestore.rules:287-289, 391-398` | `loyalty`/`presence` full self-write with NO shape validation | P2 (01-P2-2) |
| P-5 | `firestore.rules:492-495` | `analyticsEvents` create open to any signed-in non-anonymous user (spam/storage burn) | P2 (01-P2-4) |
| P-6 | rules write surfaces | App Check gating inconsistent (presence, reservation_locks, reservations, waitlist, promo_usage lack `isAppVerified()`) | P2 (09-P2) |
| P-7 | `firestore.rules:455-458` | `promoCodes` read over-exposed (any authenticated non-anon); client never reads it directly | P3 (09-P3) |

### 10.2 Solution - design principle + acceptance contract

**Design principle:** match rules to REAL payloads and REAL queries; never loosen tenant/role/branch scoping; App Check where the client always has it; NEVER flip `strongAppCheck` (VERIFY-IN-CONSOLE).

**Acceptance contract (from master W4.1/W4.2/W4.3/W4.6/W4.7/W4.9/W4.10):**
1. Orders update block: kitchen + delivery -> `hasOnly(['status','updatedAt'])`; delivery additionally allows `proofOfDelivery` when `request.resource.data.proofOfDelivery.url is string && request.resource.data.proofOfDelivery.uploadedBy == request.auth.uid`; manager -> `hasOnly(['status','assignedDriverId','updatedAt'])`. All role/branch/`assignedDriverId==uid` clauses byte-identical. Comment `updatedAt` as non-authoritative.
2. Driver `myOrders` QUERY fix (not rules): `delivery_service.dart:29-37` adds `.where('branchId', isEqualTo: userBranchId)` (mirror `availableOrders`). Rules unchanged.
3. Kitchen read clause: `['confirmed','preparing']` + `['ready']`.
4. `loyalty`: `hasOnly` + type guards (numeric points, string tier); `presence`: `isOnline bool`, `lastSeen number`, `branchId string`.
5. `analyticsEvents` create: gate `isAppVerified()` + field caps (`properties` keys <= 10, string values <= 500 chars).
6. Add `isAppVerified()` to presence write, `reservation_locks`, `reservations`, `waitlist`, `promo_usage` blocks.
7. `promoCodes` read: owner/manager-only (customers use `applyPromo` CF).
8. `test/rules/firestore_rules_test.js` ADD cases (T-1..T-7 below), record new total (92 -> N).

### 10.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Kitchen update WITH `updatedAt` + POD shape ALLOW; without DENY | Rules harness |
| T-2 | Delivery update `{status, assignedDriverId, updatedAt}` ALLOW | Rules harness |
| T-3 | Driver `myOrders` branch-filtered read ALLOW | Rules harness |
| T-4 | Kitchen read `['ready']` ALLOW | Rules harness |
| T-5 | Customer `pending->cancelled` client update DENY (CF owns it) | Rules harness |
| T-6 | loyalty/presence shape-lock negatives DENY | Rules harness |
| T-7 | analyticsEvents oversize DENY; promoCodes customer read DENY | Rules harness |

### 10.4 Proof gates

- [ ] `npm run test:rules` green with EXTENDED harness total recorded (92 -> N)
- [ ] All pre-existing 92/92 still green
- [ ] grep `hasOnly\(\[.status.\]\)` (without updatedAt) in kitchen/delivery clauses = 0
- [ ] Universal Gate Set U (index Section 1)

### 10.5 Honest residuals

- Live rules enforcement against a populated backend is still a RELEASE-2 emulator+console verification; the harness proves logic, not production token claims.
- `strongAppCheck` stays OFF in console until the VERIFY-IN-CONSOLE claim check passes (section 12 of master).

**END OF BATCH RULES-1 SPEC** - do not proceed to RULES-2/STAFF-QUEUE until these gates pass and the RULES-1 addendum is appended to FIX_VERIFICATION.md.