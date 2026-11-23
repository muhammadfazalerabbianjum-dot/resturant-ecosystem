# QUEUE — P2 (Operations surfaces)

Authoritative spec: `docs/ORCHESTRATOR_HANDOFF.md` §10 Phase 2, plus the frozen
rulings in `docs/DECISIONS.md` (A8/Q6 web spike; Q7 card-present = Canada only,
simulated reader in test mode; Q4/Q5 reversal; Q3 receipts blocked).

**Gate discipline is unchanged from P0/P1.** A card is `DONE` only when its
`DONE WHEN` clause is true **and** the evidence is in a checkpoint from the same
session. `gate.cmd check` green is the floor, not the proof.

---

| Card | Deliverable | DONE WHEN | Status |
| --- | --- | --- | --- |
| P2-0 | **Flutter-web spike** (owner-approved, 2 days): run the existing staff surfaces under Flutter web against the emulator; measure build, first meaningful paint, and whether `packages/core` and Firebase JS interop survive unchanged. Fallback candidate: thin PWA shell reusing `packages/core`. | A written verdict in `checkpoints/P2-00.md`: build succeeds or the blocking package is named with the error; the measured numbers are pasted from the run; a recommendation (keep Flutter web / take the PWA shell) with its cost. **Then STOP** — the verdict is returned to the owner before any staff-UI card is authored. | **DONE (halted)** — `checkpoints/P2-00.md`. Build FAILS at 147 s: `isar_community` (no web platform) via the `packages/core` barrel, plus int64 sentinels in `money_text.dart:51` / `currency_format.dart:48`. FMP and JS interop UNMEASURED (nothing to run). Recommendation: the A8 shell. Awaiting the owner's A/B ruling. |
| P2-1a | **Thin shell foundation** (D-049): a second web entrypoint in `core_app` that boots in a browser, signs in, carries the tenant claim, reads one tenant-scoped collection, and whose reachable import graph contains **no Isar**. Includes the portable min-int fix that dart2js rejected. | `flutter build web --target lib/shell/main.dart` exits 0; the shell boots to sign-in; emulator sign-in succeeds; the claim reports the tenant; one bounded read returns that tenant's rows; a mechanical import-graph check proves `isar_community` is unreachable and **fails** when a shell file imports `package:core/core.dart`; size and first-paint numbers pasted from the run. No money behaviour. | **DONE** — `checkpoints/P2-01a-BOUNDARY.md`. Build **BUILD_EXIT=0** (62.1 s, `main.dart.js` 2 565 416 B, `build/web` 37 MB); FCP **519 ms** warm / **9018 ms** cold. Emulator proof (D-058): console trace `signIn: done counter@shell.test` → `claim: tenant_shell` → `read: 2 row(s) in 450ms for tenant_shell → [Proof Shawarma, Proof Falafel]`; outside verification `node tool/shell_proof.mjs verify` → constrained 200/2 rows, unconstrained **403 PERMISSION_DENIED** (D-057). Import checker proved failing on the barrel then passing over 24 files. Pixels NOT viewed (window minimised) — §6d. |
| P2-1 | Counter/POS — cash first, on the shell (authored below) | See §P2-1 acceptance. Server path proven; the counter surface, the rules allowlist and the D-057 query pass remain. | **IN PROGRESS — server half DONE and proven** (`createCashOrder` / `voidCashSale`, D-059/D-060). Emulator round trip `node tool/cash_proof.mjs`: **34/34, `CASH PROOF OK`** — one create → one order + one `sale_` row at 2436 ¢ (2250 + 186 tax, change 564 ¢), replay adds none (`idempotent: true`), cross-tenant void `not-found`, void → `cancelled` + `rev_sale_…` at −2436 ¢, second void refused. Unit lane 271/271, `eslint src` clean. Remaining: `firestore.rules` for the server-written fields; tenant constraints on the kitchen/analytics queries (D-057); the shell counter surface (C-6 now satisfiable — a callable exists to call). |
| P2-2 | Card-present via Stripe Terminal (simulated reader, test mode) | Blocked on P2-1. Hardware registration is owner-only. | BLOCKED on P2-1 |
| P2-3 | Kitchen Display + Waiter surfaces | Blocked on P2-1. | **NEXT** — proposed to run before P2-1's unblocking work, because KDS is not money: it reads existing `orders` and advances status, so it needs no cash ruling. Reorder is recorded in `docs/P2-01-CASH-DECISION.md`; the owner may overrule. |

---

## P2-1a — thin shell foundation (owner ruling D-049: option B)

**Why this card exists first.** The owner ruled the A8 fallback after the P2-0
measurement (`checkpoints/P2-00.md`): Flutter web cannot carry the whole app
because `packages/core`'s barrel exports `isar_community`, which has no web
platform. Option B is "a thin shell reusing the Isar-free service layer, never a
fork of business logic" (D-023). The shell cannot start until the import
boundary below is real, so the boundary is this card.

**Shape (decided, D-050).** A second entrypoint inside `core_app`
(`lib/shell/`), built with `flutter build web --target lib/shell/main.dart`.
Rejected: a new app package — it would duplicate Firebase init, the config
loader and the `packages/core` version pin, and the two copies would drift on
the first dependency bump.

**The boundary, measured before it was written:** 7 files in `packages/core`
touch isar (`cache/isar_{schemas,schemas.g,service}.dart`, `auth/auth_repository`,
`kitchen/kitchen_offline_service`, `network/{sync_queue,pending_sync_provider}`);
everything else is importable. Every service uses Flutter plugin packages
(`cloud_firestore`, `firebase_auth`), which is why the shell is thin **Flutter
web** and not a TypeScript rewrite that would have to fork the domain.

**Work items**
1. `LocalCache` seam in `packages/core` so `AuthRepository` no longer imports
   isar. The parameter is **required**, not optional, so every construction site
   must state its cache — the same "required, never silently defaulted" ruling
   P1-4 7f applied to `TenantClaimReader`. `core_app` passes the Isar-backed
   implementation (today's behaviour, unchanged); the shell passes a no-op,
   which is safe **only because the shell holds no local cache** — a shell that
   starts caching must implement it.
2. Portable min-int guard replacing `-9223372036854775807 - 1` in
   `packages/core_ui/lib/src/ui/money_text.dart:51` and
   `core_app/lib/app/config/currency_format.dart:48` (`v != 0 && v == -v` is the
   same predicate on the VM and harmless on web doubles). Money parity matrix
   re-run — this is a money renderer, so it is proven, not eyeballed.
   **Pre-verified 2026-11-13** (`checkpoints/P2-00.md` §8): the predicate's VM and
   JS truth tables were measured, and with it applied the money suites pass
   50/50 (core_app) and 8/8 (core_ui), including both `int.min` cases. The change
   was reverted afterwards, so this card still owns it — do not re-litigate the
   predicate, do re-run the matrix in the card and paste the numbers.
3. The import-graph check: a script/test that walks imports from the shell
   entrypoint and fails on any path to `isar_community`. It must be shown
   failing (a shell file importing `package:core/core.dart`) before it is trusted.
4. Boot, sign-in and one bounded read against the emulator, then the web build.

**Named blocker (human-only, does not stop P2-1a):** a **web App Check
registration** (registered web app + reCAPTCHA-family provider) is a Firebase
console action. Without it the deployed shell cannot write: D-036 binds tenancy
to the verified App Check app id. Emulator work proceeds without it.

## P2-1 — Counter/POS, cash first (authored from D-049, not in advance)

*Depends on P2-1a. Runs in the shell.*

**Deliverable.** A counter surface that takes a cash order: pick items from the
menu, build the cart, send it, show the total and a receipt, and list today's
counter orders. Card-present is P2-2 and is **not** in this card.

**Hard constraints**
- **Money is the server's.** The order goes through the existing `createOrder`
  callable, which already writes the order **and exactly one `sale_` ledger row
  in one transaction** (P1-2, D-030). The POS never writes a ledger row, never
  sends `totalCents` as authority, and never computes tax locally for the charge
  (`calculateTax` is the server seam).
- **Tenant from the claim** (D-035/D-039): the create payload carries the
  caller's `tenantId`; no surface supplies one.
- **Every read is bounded** — menu and today's orders get a limit and a date
  window. An unbounded stream in a counter screen is a cost bug.
- **Nothing native.** No Isar, no `package:core/core.dart` barrel import.
- **No offline queue in v1.** If the counter loses connectivity the create
  fails loudly; an offline queue is a separate card with its own DLQ semantics
  (it is the one thing that would need the cache seam the shell does not have).

**Acceptance (DONE WHEN)**
1. Emulator-backed proof of the money path from the counter surface: one create
   → one order document + exactly one `sale_<orderId>` ledger row with matching
   amounts; a replayed create adds no second row.
2. A cross-tenant create is denied by rules (gate (j) already owns the case;
   cite the receipt).
3. A widget test at 390 px and 1024 px renders the cart, the total and the
   receipt with no overflow captured as an error.
4. The displayed total is produced by the same money renderer the fleet uses
   (no second formatter), and its number equals the server's charged amount in
   the emulator run.
5. `flutter build web --target lib/shell/main.dart` still passes and the
   import-graph check still proves no Isar path.

**Out of scope, stated so it cannot creep in:** tips, discounts/promos, splits,
refunds (the ledger's reversal path exists server-side; no counter UI), printing
of any kind (thermal stays blocked, D-024), and any card-present flow.

## Rules for authoring P2 cards

1. **No card ships money behaviour without an emulator-backed proof.** The
   existing shape — order + exactly one ledger row in one transaction — is the
   reference.
2. **Tenancy applies to every new collection on the day it is created.** Add the
   rules block with `tenantOk()`, and add the registry row in the same commit;
   gate (i) fails a collection with no row.
3. **The web-spike verdict is a halt point.** Do not start a staff surface on an
   assumption about the rendering target.
4. **Anything needing a human** (new Firebase project, Stripe Connect, hardware,
   thermal printing) enters `ROADMAP.md` as BLOCKED with the human action named.

### P2-1 rules gap (2026-11-15) — **CLOSED the same day, see D-061**: the OWNER update clause had no key allowlist

`firestore.rules:590` opens `allow update` on `orders` with `userRole() == 'owner' ||`
and no `diff(resource.data).affectedKeys().hasOnly([...])` beside it, while every other
role in the same rule is key-restricted (`manager` → status/assignedDriverId/updatedAt,
`kitchen` → status/updatedAt, `customer` → status/updatedAt, `delivery` → status/
assignedDriverId/updatedAt/proofOfDelivery). Consequence, now that the ledger is real: an
owner-claimed CLIENT can rewrite `totalCents`, `taxCents`, `items`, `paymentMethod` or
`idempotencyKey` on an order whose immutable `sale_` row says otherwise — the order and the
ledger disagree, and the ledger is the taxable record. (The server is unaffected: the admin
SDK bypasses rules, which is why `createCashOrder`/`voidCashSale` are not blocked.)

**Not fixed blind, and why:** narrowing the owner clause would change what the owner app is
allowed to write, and that surface has not been read yet (an owner UI may legitimately write
fields no other role does). The fix must be driven by the client's real writes, not by
guesswork:

1. Inventory the owner-claimed client writes to `orders` (grep the Dart services for
   `orders.doc(...).update` / `set`), the way `b10 P-1` inventoried the staff updates.
2. Give the owner clause an allowlist of exactly those keys (plus `updatedAt`), so the rule
   stops being "owner may write anything".
3. Add the money/provenance keys (`totalCents`, `taxCents`, `changeCents`,
   `amountTenderedCents`, `taxRate`, `items`, `paymentMethod`, `paymentIntentId`,
   `idempotencyKey`, `voidReason`, `voidedBy`) to a shared `hasOnly`-excluded set: no client
   role may touch them, because the server owns money.
4. Pin it in the rules harness (a q-test per role) and with a source-text contract test, the
   way `test/rules/order_create_payload_contract_test.dart` pins the create allowlist.

**Closed by D-061.** The owner branch now carries
`hasOnly(['status', 'assignedDriverId', 'updatedAt'])` — the union of the five real client
writers, inventoried above — in BOTH rule files. Proof in both directions:
`order_update_payload_contract_test.dart` went RED naming exactly `['owner']` then green
(10 assertions per rule file); the rules harness `OWN1`–`OWN3` went RED with the lock removed
(`OWN2 … Expected request to fail, but it succeeded`) and is green with it
(`173 passed, 56 failed, 56 in baseline, 0 new`).
