# P1-4 ORCHESTRATOR REPORT

**Card:** P1-4 (tenancy rules + a harness that can prove isolation)
**Branch:** `cline/p32-golden-gates` — HEAD `dcafca5a`, **36 commits ahead of
`origin`, nothing pushed**
**Rulings in force:** D-021…D-024, D-035 (design 1), D-036 (approve proposal,
gate (j)), D-037 (rule + registry flip in one commit)
**State:** 15 of 28 collections ACTIVE and proven in both directions; 10/10 gates
PASS; tree clean.

---

## 1. Bottom line

The harness the card exists for is real and it can fail. Gate (j) boots the
Firestore + Auth emulators, seeds 73 documents across 28 collections under two
tenants, mints tokens carrying `{tenantId, roles, claimsVersion, app_id}`, and
runs a generated suite that asserts, per ACTIVE collection, that tenant B is
denied **read and write** on tenant A's seeded document and that tenant A is
**allowed** to read its own. Fifteen collections satisfy that today; thirteen do
not, and each of the thirteen is stopped by a named structural conflict rather
than by remaining effort (section 4). Four of those need a decision from you, not
more coding.

## 2. What landed (20 commits, one per GREEN step)

| Commit | Content |
|---|---|
| `cf982deb` | Registry learns `readDocId`/`writeDocId`/`allowDocId`/`sameTenant`; generator validates and emits allow cases; seeded-id denial replaces random paths |
| `4333df81` | `tool/tenant_isolation_probe.mjs` — free ports, `emulators:exec --only firestore,auth`, 73-doc seed, two `createUser` + `setCustomUserClaims` calls, suite run; `menus` converted; gate (j) registered |
| `a1356612` | Gate (d) contract updated (unauthenticated `/menus` → 403); halal_boyz parity copy; lazy suite bootstrap (gate (b) loads every file, so load-time bootstrap is forbidden) |
| `bcfac0e2`, `ba8c6c4c`, `dcafca5a` | All-gate checkpoints and the progress record |
| ×14 | `promotions`, `locations`, `analyticsEvents`, `transactions`, `users`, `carts`, `loyalty`, `deletion_requests`, `notifications` (+`items`), `driverLocations`, `presence`, `reservation_locks`, `promo_usage`, `waitlist` — each as rule change + ACTIVE flip + gate (j) in one commit |

## 3. Evidence

**Gate battery (`checkpoints/gate-20261111T181849Z.md`):**

| Gate | Result | Time |
|---|---|---|
| a dart-analyze | PASS | 264.9 s |
| b gate-fast-tests | PASS | 458.3 s |
| c functions-build | PASS | 12.7 s |
| d emulator-rules | PASS | 26.9 s |
| e whitelabel-dry-run | PASS | 2.7 s |
| f stub-scan | PASS | 0.0 s |
| g functions-coverage | PASS | 14.3 s |
| h backend-parity | PASS | 1.1 s |
| i tenant-isolation-generator | PASS | 1.1 s |
| j tenant-isolation-emulator | PASS | 52.0 s |

`GATE RESULT: PASS (10 ran, 0 failed, 0 unavailable, 0 not-active)`

**Coverage of the suite:** 15 ACTIVE rows — 12 carry a same-tenant **allow**
control, 3 (`analyticsEvents`, `transactions`, `presence`) declare
`sameTenant: none` with a written reason (owner/staff-only reads, so no
tenant-scoped readable principal exists), and `menus` remains the global
guest-boot control. 13 rows remain `PENDING-TENANCY`.

**Falsifiability was proven by plant, not asserted:** making `tenantOk()` return
false failed gate (j); reverting `menus` to `allow read: if true` failed gate (j);
restoring either returned it to PASS.

## 4. Structural findings

1. **Combined `allow read, write` statements cannot carry tenancy.** `tenantOk()`
   inspects the existing document, create must inspect the merged
   `request.resource` (`tenantOkCreate()`), and delete has no `request.resource`
   at all. Every converted collection split its combined statement into
   read / create,update / delete. This is why the conversions are not mechanical
   search-and-replace.
2. **Two collections are blocked by their own shape locks.** `orders` and
   `reservations` reject any create whose keys are outside a `hasOnly([...])`
   list that does not include `tenantId`. Adding `tenantOkCreate()` today would
   deny **every legitimate create** — a lockdown that gate (j) would pass and the
   app would not. The client payload and the shape lock must change in the same
   commit, and that is a frozen-interface change needing your approval.
3. **`settings` is keyed by name, not by tenant.** `restaurantConfig`,
   `taxRates`, `featureFlags`, `ownerInfo` are singleton documents, and
   `isOwner()` reads one global `ownerInfo.ownerEmail`. There is no per-tenant
   key to compare, so tenancy here is a schema decision. It also owns
   `admins`, `audit_log` and `audit_logs`, which are all `isOwner()` readers —
   four collections stand behind one decision.
4. **`branches` owns three nested matches** (`menu_overrides`, `config`,
   `waitlist_meta`) that the registry does not enumerate. Converting the parent
   alone would leave nested reads unscoped, so it needs a suite extension first.
5. **Transport:** `flutter test` cannot initialise `firebase_core` (no platform
   channel) and `test/flutter_test_config.dart` blocks network for all of `test/`
   by design, so the suite speaks HTTP/1.1 to the emulator over a raw `Socket`
   with its own incremental reader. The emulator ignores `Connection: close`
   (read-to-EOF stalls exactly 15 s) and the auth emulator rejects
   `returnSecureToken` as a string.

## 5. Decisions requested

1. **`settings`/`ownerInfo` tenancy key scheme** (owner call per D-035). Until it
   is ruled, `settings`, `admins`, `audit_log`, `audit_logs` stay PENDING.
2. **Approve the `orders`/`reservations` payload change** — `tenantId` added to the
   create shape lock and to the client payload together. Without approval these
   two cannot be scoped without breaking every order and reservation create.
3. **Approve nested-block registry rows** for `branches`, so the suite can prove
   `menu_overrides`/`config`/`waitlist_meta` rather than converting the parent and
   hoping.
4. **Confirm the deploy sequence stays as D-035 wrote it** — claim callable →
   guest boot claim → `migrate_v004_tenancy` → rules last. The rules are
   currently **ahead of the app**: no callable mints `tenantId` yet (gate (j)
   mints it with the Admin SDK), and `TenantFirestore` has not started. Shipping
   these rules to the live project before the client work would take menus down.

## 6. What is not proven

- The client path: no callable derives `tenantId` from App Check, so nothing in
  the running app sends a tenant-bearing token.
- `hasAppId()` may be effectively always-false in production until one real ID
  token is inspected — that check is human-only under A2 and has not been done.
- Nested subcollection reads (`branches/*`, `notifications/*/items` beyond the
  generated case).
- Anything about production data: all of this ran against emulators; no live
  call, no deploy, no network mutation.

## 7. Recommended next move

`reservation_counters`, `waitlist_counters`, `promoCodes`, `notification_queue`
are mechanical and can proceed immediately under D-037. `branches` and the
`orders`/`reservations` pair should wait for decisions 2 and 3; `settings` and its
three dependants should wait for decision 1. Estimated cost per mechanical
collection: ~60 s of local gate time, one commit.
