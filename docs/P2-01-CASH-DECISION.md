# P2-1 — a cash sale cannot reuse `createOrder`: one ruling is needed

Date: 2026-11-15. Status: **BLOCKED on an owner money ruling.** Card:
`docs/queue-P2.md` §P2-1.

This document exists because the card's premise does not survive contact with
the server, and inventing a cash money path is an owner-only decision (money),
not an engineering choice.

## 1. What the card assumed

> **Money is the server's.** The order goes through the existing `createOrder`
> callable, which already writes the order **and exactly one `sale_` ledger row
> in one transaction** (P1-2, D-030).

That sentence is true only for CARD sales, where a Stripe PaymentIntent exists.

## 2. What the code actually does (cited)

| Fact | Where |
| --- | --- |
| Every order retrieves a Stripe intent, unconditionally | `core_app/functions/src/index.ts:1178` |
| Without a succeeded intent: `failed-precondition / Payment not confirmed` — there is no branch that skips it | `index.ts:1181` |
| Money is then re-derived from the intent (amount + server-stamped metadata), never from the client | `index.ts:1245`–`1305` (`extractMenuPricingInput`, `verifyMenuPricing`, `verifyOrderCharge`) |
| A ledger row REQUIRES a non-empty `orderId`, `customerId` and `paymentIntentId` | `functions/src/ledger.ts:95`–`98` |
| The row's amount comes from the PaymentIntent, not the order | `ledger.ts:158`–`180` (`commitSaleForOrder`) |
| No `paymentMethod`, `channel`, `staffId` on the order create allowlist (`keys().hasOnly`) | `core_app/firestore.rules:566`–`582` (orders block at `:538`) |
| **No client may ever write a ledger row** (`write: if false`) | `core_app/firestore.rules:906`–`909` |
| Target shape is already specified (order `paymentMethod`, `channel: 'counter'`, ledger `paymentMethod`/`paymentRef`/`status`) | `docs/ORCHESTRATOR_HANDOFF.md:520`, `:535`–`540` |
| The plan explicitly expects a cash sale to write one order + one ledger row | `docs/ORCHESTRATOR_HANDOFF.md:680` |

**Consequence.** A walk-in cash sale has no PaymentIntent and often no customer
account. A client-written order would produce **an order with no ledger row**
(`transactions` is unwritable by any client), i.e. cash taken with no trail — the
exact failure the ledger exists to prevent. So cash needs a **new server
callable and a ledger row shape that permits it**.

## 3. What the card therefore needs (proposal, not yet built)

1. **New callable `createCashOrder`** — `onCall`, App Check enforced, tenant from
   the `tenantId` claim (never the payload), staff role and branch checked
   server-side; payload = `lines[{menuItemId, quantity, selectedOptions[]}]`,
   `idempotencyKey`, `amountTenderedCents`.
2. **Server derives all money**: re-price every line from `menus` with the
   existing `verifyMenuPricing` path, tax through the existing tenant settings +
   `calculateTax` seam, total computed server-side. The client's total is
   display-only, exactly as `createOrder` treats it.
3. **One transaction**: order doc + `sale_<orderId>` row, `paymentMethod: 'cash'`,
   `paymentRef: {kind: 'cash', tenderedCents, changeCents, staffUid}`.
4. **Ledger v2** (`buildSaleRow`): `paymentIntentId` becomes nullable *when*
   `paymentMethod === 'cash'`, `customerId` becomes nullable for a walk-in, and
   the row gains `paymentMethod`, `staffId`, `paymentRef`, and an **immutable
   items snapshot** (names + unit prices) so a later menu edit cannot rewrite
   history. Today's card rows keep every current guarantee — the schema version
   moves to 2 and old rows stay valid.
5. **Idempotency**: a double-tap on tender must produce ONE order and ONE row
   (handoff §Phase 2:680). Reuse the `orders.idempotencyKey` query + the
   deterministic `sale_` id; a replay returns the same `orderId`.

## 4. The ruling needed — three questions

**Q1. Who is the "customer" on a walk-in cash sale?**
(a) the staff member's `uid`; (b) **empty** `customerId: ''` + an optional
`guestName`; (c) a per-tenant `walk_in` placeholder document.
*Recommendation: (b), and specifically the EMPTY STRING, not `null`: `OrderModel`
declares `@Default('') String customerId` (non-nullable) and `fromDoc` normalises
null → `''`, so empty is the shape every reader already handles.* Option (a) is
disqualified by measurement — see §5.1: the DSAR sweep deletes
`orders where customerId == uid`, so a cashier leaving the company would erase
the tenant's sales.

**Q2. May a ledger row's money come from the server's own menu re-pricing (no
processor)?** *Recommendation: yes, with the items snapshot on the row — but this
is the ruling that changes the ledger's contract, so it is the owner's call, not
mine.*

**Q3. Which roles may take cash, and where is the tender recorded?**
*Recommendation: `owner|manager` for v1 (no new role until the role model is
reviewed); `amountTenderedCents` on the ledger row only, so the order document
keeps its current shape.*

> **Ruled against, 2026-11-15 (P2-1 build).** The role model *has* already been
> reviewed: `functions/src/permissions.ts` is the authority, and it says
> `payment.take` = **owner, manager, counter** while `payment.reverse` /
> `payment.refund` = **owner, manager**. `counter` exists in that table today, so
> the recommendation above would have invented a second, narrower rule beside
> the one the codebase enforces everywhere else. The callables therefore call
> `assertCapability(auth, 'payment.take')` and `assertCapability(auth,
> 'payment.reverse')` — no role strings in the callables. Changing who may take
> cash is a one-line edit to `permissions.ts`, and every callable follows.
> Tender (`amountTenderedCents`) stays on the row (see D-059).

## 5. Pressure test — what a row without a PaymentIntent breaks

Run before locking the design, against the code that will read the row.

### 5.1 DSAR deletion — **breaks, and it is already broken for card rows**

`deleteUserData` deletes `orders where customerId == uid`
(`index.ts:313`–`319`) and **never touches `transactions`**: the string
`transactions` does not appear in `index.ts` at all, and the ledger is written
only through `commitSaleForOrder` (`index.ts:22`, `:1382`). So ledger rows keep
`customerId` forever today.

Consequences:
- Never put the staff uid in `customerId` (it would be swept with the orders and
take the sales with it). This is what disqualifies Q1 option (a).
- Cash adds `staffId` — a **second** PII reference in an append-only collection
  with no erasure story. Financial records must be retained, so the fix is not
  deletion but **anonymisation**: a DSAR pass that rewrites `customerId`/`staffId`
  to `null` + `anonymiseAt`, keeping amounts and ids intact. This is a retention
  policy question (owner/legal), so it is listed as required work, not silently
  added.

### 5.2 Revenue analytics — **breaks: cash revenue is invisible**

| Surface | Filter | Cash sale outcome |
| --- | --- | --- |
| `revenue_chart_widget.dart:35` | `status == 'delivered'` | **excluded** — a counter sale is handed over at `pickedUp` and never reaches `delivered` (`order_model.dart:9`–`17`) |
| `top_items_chart_widget.dart:24` | `status == 'delivered'` | same exclusion |
| `analytics_provider.dart:63`–`66` | day window only, **no status filter** | includes cash — but also counts `cancelled` orders today |

The honest conclusion: **orders are not the money record — the ledger is.** Once
cash exists, revenue must be summed from `transactions` (`kind: 'sale'` sum plus
`kind: 'reversal'` rows), which fixes the cancelled-order inflation at the same
time. That is a separate card (analytics re-basing) and is NOT part of P2-1; P2-1
must simply not claim the dashboard shows cash takings.

**Also found (pre-existing, same class as D-057):** all three queries above omit
a `tenantId` constraint, and the orders read rule tests `tenantOk()` on
`resource.data` (`firestore.rules:539`–`540`), so a list query without the
constraint cannot be proven safe and is denied. The same holds for
`kitchen_service.dart:47`–`52`. These surfaces are broken in a multi-tenant
deployment **today**, independently of cash.

### 5.3 Kitchen display — **works, with one fix required**

`kitchen_service` streams `orders` by `branchId` + `status in
[confirmed, preparing, ready]` and reads `OrderModel.fromDoc`. A cash order with
`customerId: ''` parses normally (empty string), shows as a guest ticket, and
needs `channel: 'counter'` only for display. **Required fix:** add the `tenantId`
equality to that query (5.2), or KDS stays denied.

### 5.4 Refunds / voids — **breaks: a cash sale would be un-undoable**

- `cancelOrder` retrieves the PaymentIntent to reverse a captured charge
  (`index.ts:1596`–`1602`, `:1550`). With no intent it cannot run.
- The reversal MACHINERY already exists and is cash-safe: `buildReversalRow`
  mirrors the original with the opposite sign and copies `paymentIntentId ??
  null` (`ledger.ts:223`–`253`); `appendReversal` writes a new row and never
  edits the original (`ledger.ts:255`–`280`).
- **But nothing calls it:** `index.ts` imports only `commitSaleForOrder`. There is
  no reversal callable yet (P1-3's UI/entry point is unbuilt).

So a counter that can take cash but never void a mistaken sale is not shippable:
**P2-1 must include a `voidCashSale` callable** (no Stripe call: append the
reversal row + set the order `cancelled` in one transaction, actor from the
claim, reason required).

## 6. The minimal ledger-v2 change that survives all four

`buildSaleRow` today requires non-empty `customerId` AND `paymentIntentId`
(`ledger.ts:95`–`98`). The smallest change that keeps every card guarantee and
makes cash safe:

| Field | Card row (unchanged) | Cash row (new) | Why |
| --- | --- | --- | --- |
| `schemaVersion` | `1` | `2` | old rows stay valid; readers branch on the version |
| `paymentIntentId` | required | **`null` allowed only when `paymentMethod === 'cash'`** | 5.4: a cash row has no processor reference |
| `customerId` | required | **empty string allowed** | Q1 / 5.1: `customerId` is a deletion key; `staffId` carries the human |
| `staffId` | absent | **required** | who took the money; must be anonymisable (5.1) |
| `paymentMethod` | absent (implicitly card) | **required** (`'cash'`) | reporting + which reversal path applies |
| `items[]` | absent | **required snapshot** (name, unitPriceCents, quantity) | the row is the only record that money moved; a later menu edit must not rewrite history |
| `taxRate` | absent | **required** | without it the tax on the row cannot be re-derived or audited |
| `amountTenderedCents`, `changeCents` | absent | required | drawer reconciliation (`BACKLOG-P5.md:26`) |

Everything else in the row is already copied from the order and does not change.
The validation rule is one line: `paymentIntentId` must be non-empty **unless**
the row is a cash row, in which case `staffId`, `paymentMethod: 'cash'`,
`items[]`, `taxRate` and the tender fields become mandatory. A row that is
neither (no intent, not cash) still throws — the guarantee that a sale always
names how it was paid.

## 7. What is deliberately NOT done while blocked

- **No counter UI.** A cart that cannot submit is the exact failure class C-6
  already names ("a built panel no user can reach"), and every acceptance clause
  in the card depends on a real create.
- **No client-side cash order.** It would either be denied by rules or write an
  untrailered sale.
- **No ledger change** before Q2 is answered: `buildSaleRow` is the guarantee
  that a sale and its money agree.

## 8. What unblocks the card

One ruling on Q1–Q3 above (or a different arrangement the owner prefers). On
receipt the work is: ledger v2 + `createCashOrder` + rules allowlist for
`paymentMethod`/`staffId` + the shell's counter surface, proven by the card's
five acceptance clauses (emulator create → order + exactly one row with matching
amounts; replay adds no row; cross-tenant denied; 390/1024 px no overflow; same
money renderer; web build + import check still green).
