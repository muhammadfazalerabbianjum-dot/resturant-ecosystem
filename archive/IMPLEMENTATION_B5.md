# BATCH 5 — PANIC SWITCH DB-LAYER ENFORCEMENT · Major · DEPENDS on B0's emulator rules suite

**Pre-read `IMPLEMENTATION_PROMPT.md`** FIRST. Do NOT run B5 before B0 is green.

## PROBLEM
- `panic_switch_service.dart:11-14` documents that `settings/restaurantConfig.ordersAccepting`
  is "the gate" and "the Firestore security rule ... blocks all new order writes (fail at the
  database layer)".
- Reality: `firestore.rules:201-207` (orders `create`) checks only `customerId == uid`,
  `branchId is string`, `totalCents is int >= 0`, `status == 'pending'` — it NEVER reads
  `ordersAccepting`. The ONLY enforcement is client-side (`checkout_screen.dart:158-159`,
  `checkout_service.dart:127-128`). A hostile/buggy client can place orders while the kitchen
  is in panic mode. Claimed DB fail-closed does NOT exist.

## SOLUTION — DB is authoritative
1. **Rules change.** orders `create` (and `update` where it creates an effective new order
   state) must require orders to be accepted. Add to the orders create rule:
   `get(/databases/$(database)/documents/settings/restaurantConfig).data.ordersAccepting == true`
   **Decision required (record it):** strict vs default-open. RECOMMENDED (fail-closed for the
   panic feature, safe for greenfield): treat a MISSING config doc as `ordersAccepting == true`
   (fresh projects/bookings), and deny ONLY when the doc exists AND is `false`. This matches the
   service default (`?? true`) and avoids bricking pre-setup emulators/tests, while making the
   owner's explicit pause authoritative at the DB. If the team prefers strict (missing =
   denied), every seed/setup/emulator test in scope must create the doc with
   `ordersAccepting: true` — record which.
2. **Update `panic_switch_service.dart` doc comment** to state the real DB gate + the chosen
   missing-doc default. Keep the client UX check (defense-in-depth) and the owner dashboard
   toggle (`owner_dashboard.dart:967-1003`).
3. **Rules test proof** (extend the B0 suite): order create DENIED while
   `ordersAccepting == false`; ALLOWED when `true`; ALLOWED when doc missing (if that default
   was chosen). Customer/role scoping tests must remain green (regression).

## TESTS
| Test | Asserts |
|---|---|
| T-P1 | orders create denied when `restaurantConfig.ordersAccepting == false` (emulator rules) |
| T-P2 | orders create allowed when `true` |
| T-P3 | (chosen default) orders create allowed when config doc missing |
| T-P4 | existing owner/manager/kitchen/delivery/customer order read+update scoping unchanged (regression) |

## GATES (must ALL pass)
- [ ] RULES-EMUL green incl. T-P1..T-P4.
- [ ] `Select-String -Path core_app/firestore.rules -Pattern 'ordersAccepting'` → present in orders create.
- [ ] `panic_switch_service.dart` comment reflects the real gate (no false DB claim).
- [ ] `flutter test` (checkout + owner dashboard suites) → green (U-NOBREAK).
- [ ] Gate set U; B5 addendum appended incl. the missing-doc decision.

## RESIDUALS (honest)
- The panic gate only applies to client writes; the Admin SDK (Cloud Functions) bypasses rules
  by design — document that `createOrder` CF accepts even in panic (owner decision: either leave
  server-side accepts, or add a guard in `createOrder` — decide + record).

**END OF BATCH 5.** Not closed until Gates green + addendum appended.