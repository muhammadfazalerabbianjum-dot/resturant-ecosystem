# P1-4 PROGRESS — 15 of 28 collections tenant-scoped

Status after the second batch (branch `cline/p32-golden-gates`). Every collection
below landed as ONE commit containing its `tenantOk()` clauses plus its registry
row flipped to ACTIVE (D-037), each proven by gate (j) before the commit.

## ACTIVE (15)

`menus`, `promotions`, `locations`, `analyticsEvents`, `transactions`, `users`,
`carts`, `loyalty`, `deletion_requests`, `notifications` (+ its `items`
subcollection), `driverLocations`, `presence`, `reservation_locks`,
`promo_usage`, `waitlist`.

Denial is proven for all 15 against seeded tenant-B documents. An allow control
runs for the 13 that have a tenant-scoped readable principal; `analyticsEvents`,
`transactions` and `presence` declare `sameTenant: none` with a reason (owner /
staff only). The global control is `menus` — the guest-boot read design 1 risks.

## PENDING (13) and why each one is not a copy-paste

| Collection | Why it needs its own decision |
|---|---|
| `orders` | The create shape lock (`keys().hasOnly([...])`) does not include `tenantId`, so adding `tenantOkCreate()` would deny every legitimate create. The client payload and the shape lock must change together. |
| `reservations` | Same conflict: `hasOnly([userId, branchId, ...])` excludes `tenantId`. |
| `settings` | Documents are singletons keyed by NAME (`restaurantConfig`, `taxRates`, `featureFlags`, `ownerInfo`), so there is no per-tenant key to compare. Needs a key scheme, not a rule edit. |
| `admins`, `audit_log`, `audit_logs` | Reads are `isOwner()`, which keys on the singleton `settings/ownerInfo.ownerEmail` — one global owner. Tenancy for the owner identity is the same schema decision as `settings`. |
| `promoCodes`, `notification_queue` | Owner/manager reads and owner writes; scoping is mechanical but the collections are also written by the demo daemon acting as owner, so the write path needs a tenancy story first. |
| `deliveries`, `proof_of_delivery` | Read/write resolve the driver through `orders/{orderId}`, so an allow control needs a linked order fixture; and both depend on `orders` landing first. |
| `branches` | The top-level doc is easy, but the block also owns three nested matches (`menu_overrides`, `config`, `waitlist_meta`) which the generated suite does not enumerate. Converting the parent alone would leave nested reads unscoped. |
| `reservation_counters`, `waitlist_counters` | Per-branch counter docs read inside booking transactions; mechanical, next batch. |

## What is proven, and what is not

- Proven: rules-level cross-tenant denial + same-tenant allow, per collection,
  against a real emulator, and the gate fails on a leak and on a lockdown.
- Not proven: the client path. No callable mints `tenantId` claims yet (gate (j)
  mints them with the Admin SDK), and `TenantFirestore` has not started. Until
  those land, the rules are ahead of the app — which is the intended deploy order
  (rules last in production, per D-035/D-036) but means nothing here is shippable
  to the live app yet.

## Next batch

`reservation_counters`, `waitlist_counters`, `promoCodes`, `notification_queue`,
then `branches` with its three nested blocks, then the two shape-lock collections
(`orders`, `reservations`) together with the payload change they require, and
last the `settings`/`ownerInfo` schema decision, which is an owner call.
