# BATCH STATE-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W8.1, W8.2, W8.3, W8.4.**

## 21. BATCH STATE-1 - LIFECYCLE CORRECTNESS (DASHBOARD / GPS / STATE MACHINE / CART)

**Predecessor:** RULES-1. **Emulator-gated:** no. **Master:** W8.1, W8.2, W8.3, W8.4. **MIRROR: owner_dashboard/GPS/cart are core_app/packages shared - mirror where the shell carries copies.**

### 21.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `owner_dashboard.dart:390-402` | Unguarded async `setState` after `updateUserBranch` await -> `setState() called after dispose()`; no try/catch; manual `_users` mirror drifts from Firestore | P1 (03-P1-STATE-A) |
| P-2 | `driver_location_service.dart:72-77` | `startTracking` reassigns `_positionStream` without cancelling prior -> duplicate GPS listeners, doubled writes/battery | P1 (03-P1-GPS) |
| P-3 | `kitchen_service.dart:41-51`, `delivery_service.dart:66-77, 81-101` | Status writes unconditional; no transition validation -> stale snapshots flip dead orders | P1 (03-P1-TRANSITION) |
| P-4 | `cart_provider.dart:66-68` | Optimistic cart state not reconciled when Isar save fails -> items user believes saved vanish on restart | P2 (03-P2-CART-DIVERGENCE) |

### 21.2 Solution - design principle + acceptance contract

**Design principle:** follow the codebase's own established guards (`if (mounted)`, transaction pattern from `assignToMe`, provider invalidation); encode the order state machine ONCE on the enum.

**Acceptance contract (from master W8.1/W8.2/W8.3/W8.4):**
1. `owner_dashboard.dart`: (a) `if (!mounted) return;` after the await; (b) try/catch -> `FirebaseExceptionMapper.map` snackbar + `unawaited(logger.error(...))` (mirror `kitchen_dashboard.dart:284-290`); (c) drop the local `_users` mirror-edit -> `ref.invalidate(usersProvider)` (delete the manual `UserModel(` reconstruction).
2. `driver_location_service.dart`: `startTracking` early-returns if `_activeOrderId == orderId`; else `await _positionStream?.cancel();` BEFORE reassigning.
3. `order_model.dart`: add `bool canTransitionTo(OrderStatus next)` to `OrderStatus` encoding: pending->confirmed/preparing/cancelled; confirmed->preparing/ready/cancelled; preparing->ready/cancelled; ready->pickedUp/cancelled; pickedUp->delivered; delivered/cancelled terminal. `KitchenService.updateOrderStatus` + `DeliveryService.markDelivered` become transaction-guarded like `assignToMe` (read current status -> `canTransitionTo` -> write `{status, updatedAt}`); violation -> mapped-error fail-closed. W4.1 rules remain the server guard.
4. `cart_provider.dart`: capture `final previous = state.value;` before mutating; on `saveCart` failure restore `state = AsyncValue.data(previous)` before rethrow.

### 21.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Double-start -> single GPS subscription | Fake geolocator stream: two `startTracking` calls -> one listener |
| T-2 | Every transition pair | Unit: `canTransitionTo` matrix (valid + invalid) |
| T-3 | Wrong transition fail-closed | Transaction test: `delivered` -> `pickedUp` rejected with mapped error |
| T-4 | Cart revert on failure | Fake repo: save throws -> state restored to previous |
| T-5 | Owner dashboard mounted-guard | Widget: dispose mid-flight -> no setState-after-dispose |

### 21.4 Proof gates

- [ ] New unit/widget tests green (T-1..T-5)
- [ ] `flutter analyze` + full `flutter test` green
- [ ] grep `canTransitionTo` in lib present; used by kitchen + delivery
- [ ] Universal Gate Set U (index Section 1)

### 21.5 Honest residuals

- The setState-after-dispose and GPS double-stream are race-derived from code (not runtime-reproduced) - the tests close the deterministic class.
- Client transition guard does NOT substitute for rules/CF enforcement (RULES-1 + server) - cross-ref documented.

**END OF BATCH STATE-1 SPEC** - do not proceed until these gates pass and the STATE-1 addendum is appended to FIX_VERIFICATION.md.