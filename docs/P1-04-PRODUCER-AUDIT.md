# P1-4 producer audit — who still writes a tenant-scoped document without a tenant?

**Method.** `checkpoints/audit_producers.py` walks `core_app/lib`, matches a
document reference and a create/full-set (`.collection('x').doc(...).set(` /
`.add(`) and reports whether the written body carries `tenantId`. `update()` is
excluded deliberately: `tenantOk()` on an update evaluates the **existing**
document (`resource.data`), so an update needs no key once the document has one.
`transaction.set(ref, ...)` calls are not reached by the pattern — they are
covered by the reservation and waitlist work in step 6 and are listed separately
below.

Run: `python checkpoints/audit_producers.py`.

## Findings — creates/full-sets that must carry the key

| Site | Collection | State |
|---|---|---|
| `features/admin/domain/admin_data_service.dart:266` | `branches` (`add`) | **missing** |
| `features/admin/domain/admin_data_service.dart:285` | `branches` (`set`) | **missing** |
| `features/admin/domain/admin_data_service.dart:360` | `menus` (`add`) | **missing** |
| `features/reservations/data/reservations_repository.dart:46` | `reservation_counters` | carried (6c) |
| `features/reservations/data/reservations_repository.dart:86` | `reservations` | carried (6c) |
| `features/waitlist/data/waitlist_repository.dart` (3 sites) | `waitlist`, `waitlist_meta` | carried (6d) |

`branches` and `menus` were scoped in step 5b, so **admin branch and menu creation
is denied in production today**. They are the next producer fix.

## Findings — writes on collections still PENDING-TENANCY

Nothing to do yet, listed so the conversion does not silently break them:

- `features/tracking/data/driver_location_service.dart:110` — `deliveries.set`
- `features/admin/domain/cloud_function_mocks.dart:240` — `audit_log.set` (demo
  mock; `audit_log` is `write: if false`, so this mock write is only meaningful in
  the mock harness)
- `features/admin/domain/cloud_function_mocks.dart:190` — `notifications/.../items`
  (self-keyed; the mailbox rules are already scoped, so this follows the same fix
  as `branches`)

## Findings — reads by literal settings name (card 7 blocker)

Every one of these resolves `settings/<name>` exactly, so any rename to
`${tenantId}_<name>` (D-038) breaks it:

| Reader | Path |
|---|---|
| `lib/app/config/restaurant_config_service.dart:21` | `settings/restaurantConfig` |
| `lib/app/config/tax_rates_repository.dart:73` | `settings/taxRates` |
| `lib/app/config/feature_flags_service.dart:37` | `settings/featureFlags` |
| `lib/features/admin/domain/panic_switch_service.dart:27` | `settings/restaurantConfig` |
| `lib/features/admin/presentation/setup/operating_hours_screen.dart:34` | `settings/defaultOperatingHours` |
| `lib/features/admin/presentation/setup/tier_flag_manager_screen.dart:114` | `settings/featureFlags` |
| `functions/src/index.ts:126` | `settings/orderCounter` |
| `functions/src/index.ts:164`, `:709` | `settings/taxRates` |
| `functions/src/index.ts:716`, `:938`, `:1971` | `settings/restaurantConfig` |

`settings/orderCounter` is not a documented settings document; it is a counter the
server keeps in the settings collection. It has no tenant field today and no rules
match beyond the generic `settings/{doc}` block.

## Consequence

The rename cannot be a rules-only diff. The **server** sites (`index.ts`) have no
tenant context today: they read one global config. Before the rename lands, four
server call sites in the tax path and the order-number counter need an explicit
tenant source, which is a money-path change and therefore needs its own decision
and its own tests (card 7 plan, decision C7-2).
