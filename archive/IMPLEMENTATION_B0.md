# BATCH 0 — FIRESTORE RULES COMPLETENESS + REAL RULES EMULATOR SUITE · P0 RELEASE-BLOCKER

**Pre-read `IMPLEMENTATION_PROMPT.md`** (rules §0, batch map §1, Gate set U §3). This file is
batch 0's self-contained spec.

## PROBLEM
| # | Evidence (current source) | Issue |
|---|---|---|
| P0-1 | `firestore.rules` (full `match /` set; `reservation_locks` only) vs `reservations_repository.dart:18-22,45-55` | NO `match /reservation_counters`. `requestSlot()` writes `reservation_counters/{branch}_{start}` in a transaction; rules deny by default → `permission-denied` → booking ALWAYS fails (false) in production. Same for `waitlist_counters` (`waitlist_repository.dart:49-52,80-87`). Booking + waitlist DEAD in production. |
| P0-2 | `firestore.rules` (no `locations` match) vs `location_repository.dart:26-31` | NO `match /locations`. `getLocations()` reads `.collection('locations')` → denied → Locations screen fails. |
| P0-3 | `firestore.rules:113-119` (`settings` read only `featureFlags \|\| isOwner()`, write only `featureFlags`) vs `restaurant_config_service.dart:7-20`, `operating_hours_screen.dart:33` | `settings/restaurantConfig` read denied to customers (home/cart/checkout watch it) AND write denied to owner. Config feature broken. |
| P0-4 | `core_app/test/firestore_emulator_rules_test.dart`, `test/firestore_rules_test.dart`, `test/wiring/firestore_security_rules_test.dart` | All three are `fake_cloud_firestore` mocks that NEVER load `firestore.rules`. No real rules emulator test exists. |

## SOLUTION (production-grade)
1. **Counter collections** (deterministic-key counter docs; the repo transaction is the
   authority): add `match /reservation_counters/{key}` and `match /waitlist_counters/{branchId}`:
   `allow create, update: if isAppVerified() && isAuthenticated() && !isAnonymous();`
   shape-limited (`hasOnly(['booked'])` / `hasOnly(['count','updatedAt'])`, ints ≥ 0);
   `allow delete: if false`; read: owner/manager (record decision).
2. **Locations** — `match /locations/{id}`: read if `isAppVerified() && isAuthenticated() &&
   !isAnonymous()`; write if owner or manager same-branch + known-shape check; delete
   owner/manager only.
3. **Settings config** — add `match /settings/restaurantConfig` and
   `match /settings/defaultOperatingHours` BEFORE the generic `settings/{doc}` block
   (most-specific-first): read if app-verified + authenticated; write if `isOwner()` or
   (manager && `request.resource.data.branchId == userBranch()`); known-shape check.
4. **REAL rules emulator suite** — new `core_app/test/rules/firestore_rules_test.js`
   (`@firebase/rules-unit-testing`): assert allow+deny for EVERY `match /` collection incl. the
   new ones; red on today's rules for the P0 cases, green after (RULES-EMUL).
5. **Document the exact emulator command** in the B0 addendum (as a `functions/package.json`
   script OR the standalone command).

## TESTS
| Test | Asserts |
|---|---|
| T-E0 counters | authed user creates/updates `reservation_counters/{b}_{t}`; extra-key shape rejected; delete denied; anon denied |
| T-E1 waitlist counter | same for `waitlist_counters/{branch}` |
| T-E2 locations | signed-in user reads `locations`; customer cannot write; owner/manager can |
| T-E3 settings config | signed-in user reads `settings/restaurantConfig`; customer cannot write; owner can; non-featureFlags settings still owner-only (regression) |
| T-E4 orders/reservations regression | customer own-order ok + other denied; reservation create `hasOnly` (userId, no customerId) still enforced |
| T-E5 gap-closure proof | the P0 cases FAIL on the pre-B0 rule file, PASS after |

## GATES (must ALL pass)
- [ ] `Select-String -Path firestore.rules -Pattern 'reservation_counters|waitlist_counters|match /locations|restaurantConfig'` → matches present.
- [ ] RULES-EMUL → exit 0, 0 failures.
- [ ] `flutter test` (core_app) + FN-TEST → green (U-NOBREAK).
- [ ] Gate set U: analyze green, greps 0, zero skips, B0 addendum appended.

## RESIDUALS (honest)
- Counter keys are deterministic `{branch}_{start}` / `{branch}`; a hostile same-slot write only
  corrupts a booking slot (never money). Owner-decision: acceptable for v1.
- `settings/restaurantConfig` read is authenticated-only; any pre-login need is a follow-up
  decision, not a P0.

**END OF BATCH 0.** Not closed until Gates green + addendum appended.