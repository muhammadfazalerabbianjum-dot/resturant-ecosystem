# P1-4 STEP 3 — cards 1–4 of the amended order

Executed under the 2026-11-12 master directive (D-038…D-042). One collection per
commit, rule change + ACTIVE flip + gate (j) together (D-037).

## Landed

| Card | Collection | Commit | gate (j) |
|---|---|---|---|
| 1 | `reservation_counters` | `b69203a` | PASS |
| 2 | `waitlist_counters` | `ae67a78` | PASS |
| 3 | `promoCodes` | `c84e2d6` | PASS |
| 4 | `notification_queue` | `1036b24` | PASS |

Four commits, in order, each: `scoped <name>` → `GATE RESULT: PASS (1 ran, 0
failed)` → `COMMITTED <name>`. ACTIVE rows are now **19 of 28**; PENDING-TENANCY
is **9**.

## The one shape decision these four forced

`promoCodes` and `notification_queue` each had a single `allow write`. A write
statement covers create, update **and delete**, and tenancy cannot be one clause
across those: create must read `request.resource` (no stored document exists),
delete has no `request.resource` at all, and update has both. Both were split
into `allow create, update: … tenantOkCreate() …` plus
`allow delete: … tenantOk() …`. `reservation_counters` and `waitlist_counters`
keep `allow delete: if false`, which is stricter than tenancy and therefore left
alone (Q3: no drive-by widening).

## Not done here

`branches` and its three nested blocks are the next card and are **not** started.
The registry today describes one top-level collection per row, the generator
treats any key without a matching four-space `match` as stale, and the probe seeds
a single document id per row. Nested rows therefore need all three extended —
generator discovery, registry schema, probe seeding — before a `branches` rule
change could be proven. Doing the rule edit first would produce a row gate (i)
calls stale, i.e. a red commit.
