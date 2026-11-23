# FIX-B12 - SERVER DEDUPE CONTENT-COMPARISON (REC-B2-1 / AUD1-01 residual)

**Batch:** B12 (Stage 4, final batch) - **money-critical, runs ALONE**
**Worktree:** `<repo>-cline-5` (branch `cline/task-5`)
**Owner of the finding:** `REC-B2-1`, raised by B2 (MONEY-4) and reproduced by the coordinator in `AUDIT_TRIAGE_STAGE3.md` section 15.

---

## 0. LAWS (binding)

**0.1 Proof law (p10 0.1).** Every claim carries a P1 (`file:line`) or P2 (a failing/green test) receipt. No claim without a receipt.

**0.2 Red -> green.** Write the tests FIRST, capture the red to `tool_fix/b12/red_*.txt`, then implement. A batch that cannot show red did not prove anything.

**0.3 No fake green.** `0 failures / 0 skips` means exactly that. Never weaken, delete or `skip:` an existing assertion. Re-pinning an assertion that encodes a *retired defect* is allowed only with the old value, the new value, the reason, and an unchanged assertion count in the receipt.

**0.4 Money sanctuary.** The server is the money authority (Law 9 / Law 12). `roundHalfAwayFromZero`, `computeTaxCents`, `extractClientTaxConfig`, `calculateTax` (B4) and the Law-12 client amount guard (B3) are **read-only** in this batch. Any change to a charge amount is OUT OF SCOPE.

**0.5 Fail-closed direction.** When in doubt: **no order, no success response, no charge** - and a security alert. Doubt never resolves to "return success".

**0.6 Territory exclusivity.** Only the files named in section 2. No other file may be modified, created or deleted. A need outside territory = STOP and report.

**0.7 Server lane.** `core_app/functions` is a TypeScript/Node lane: gates are `npx tsc --noEmit`, the functions lint, and `npm test` (Jest). Baseline measured at `3b95c0f`: **npm test 90/90 pass**. Live emulator/Firestore behaviour is UNVERIFIED by construction (no emulator in this fleet) - say so, never imply otherwise.

**0.8 Coordination with B2 and B5 (already merged - read them before coding).**
- B2 made the CLIENT mint an ORDER-SCOPED idempotency key (`checkout_service.dart:54-60`, `125-211`) and rotate it after full success. A legitimate retry therefore reuses the SAME key with the SAME content - that path MUST keep working byte-identically.
- B5 made ONE retry classifier where `already-exists` resolves to **permanent / non-retryable** (`packages/core/lib/src/network/network_retry.dart`). The new conflict error therefore must NOT be retried by any client path.

**0.9 Coordinator executes merges; this batch commits locally only.** No merge, no push, no ledger write (`FIX_VERIFICATION.md` is forbidden).

---

## 1. RESEARCH RECEIPTS (verified at `3b95c0f`)

**R-1 The hole (the thing being fixed).** `core_app/functions/src/index.ts:1092-1101`:
```ts
// IDEMPOTENCY (Law 9): if an order with this key already exists, return it.
if (idempotencyKey) {
  const existing = await db.collection('orders')
      .where('idempotencyKey', '==', idempotencyKey).limit(1).get();
  if (!existing.empty) {
    return {orderId: existing.docs[0].id, idempotent: true};
  }
}
```
It returns the found order **without comparing anything**: not the customer, not the PaymentIntent, not the amount. Any caller that presents a key already in use is told "your order is confirmed" and receives **another order's id**.

**R-2 Why B2 did not fix it.** B2's report (section 16.6, `REC-B2-1`) recorded that a `functions/` edit was not "unavoidable" for the client-side defect, so it correctly stayed inside its territory and raised the residual. This batch closes it.

**R-3 What the client does with the response today.**
- `checkout_service.dart:414-471` calls `createPaymentIntent` (whose key creation is idempotent) and applies the Law-12 amount guard; `createOrder` is called with the same `idempotencyKey` (`core_app/lib/features/checkout/domain/checkout_service.dart:59-60` documents both sides).
- The client treats the returned `orderId` as **the placed order** - so a bogus id becomes a bogus success (wrong order shown, wrong contents).
- The client's failure paths are the catch blocks at `checkout_service.dart:247`, `:308`, `:353`.

**R-4 Who else can reach the branch.** The owner checks at `index.ts:1084-1090` validate the *request's* `order` / `userId` against `request.auth.uid`, but the **found** document is never checked against the caller - so a key collision (or a replayed key from an older app build, or a crafted call) crosses users.

**R-5 Existing guards that must stay intact.** The refund-replay guard (`index.ts:1111-1135`, MONEY-2) and the "payment succeeded" check (`:1103-1109`) run only on the MISS path today. After this fix the replay path must not let a *different* attempt skip them - that is the entire point.

**R-6 Existing security-logging helper.** `logSecurityAlert({fn, event, reason, ...})` is already used in this file (`index.ts:1131-1135`), so the new rejection uses the same channel - no new logging framework.

**R-7 Jest lane shape.** B4's `tax_fail_closed.test.js` unit-tests **exported pure helpers**; wiring inside `index.ts` is covered by the existing suite. Follow the same shape: a pure, exported comparison function + unit tests, wired into `index.ts`.

---

## 2. TERRITORY

**MAY be modified (named exactly):**
- `core_app/functions/src/idempotency.ts` - **NEW**: the pure decision function (T-1).
- `core_app/functions/src/index.ts` - **only** the block at `:1092-1101` (replace the blind return with the decision-function call) plus the `idempotency.ts` import.
- `core_app/functions/test/idempotency_conflict.test.js` - **NEW**: the unit matrix (T-2).
- `core_app/lib/features/checkout/domain/checkout_service.dart` - **only** the error mapping for the new conflict error (T-3), if R-3 shows the generic catch is not truthful.
- `core_app/test/features/checkout/**` - only a NEW test file for T-3.
- `tool_fix/b12/**` - receipts and the report.

**FORBIDDEN (any touch = STOP + report):** `core_app/functions/src/payment.ts` - tax/rounding/money helpers - `packages/**` - `apps/**` - `theme/**` - `pubspec.*` - `package.json` / `package-lock.json` - `firestore.rules` / `storage.rules` - `.github/**` - `FIX_VERIFICATION.md` - `tool_audit/**` - every existing test file.

---

## 3. TASKS (red -> green, commit per task)

**T-1 - the pure decision function (red first).**
In `core_app/functions/src/idempotency.ts` export a **pure** function that classifies a key hit, e.g.
`classifyIdempotentReplay({request: {uid, paymentIntentId, totalCents}, existing: {customerId, paymentIntentId, totalCents}})`
returning either `{kind: 'replay'}` or `{kind: 'conflict', reason: string}`, where `reason` names the field (`customer_mismatch`, `payment_intent_mismatch`, `amount_mismatch`).
Rules: same uid + same paymentIntentId + same amount -> **replay**; ANY difference -> **conflict**; missing/blank field on either side -> **conflict** (fail-closed, law 0.5).

**T-2 - the unit matrix (red before T-1's body exists).** `functions/test/idempotency_conflict.test.js` covering at minimum: identical triple -> replay; each of the three fields differing alone -> conflict with the matching reason; two fields differing -> conflict; `null` / `undefined` / empty string on either side -> conflict; and the case that IS the defect: key hit with a DIFFERENT customer -> conflict (this row is the red receipt).

**T-3 - wire it (index.ts) + truthful client mapping.**
- `index.ts:1092-1101`: on `replay` return `{orderId: existing.docs[0].id, idempotent: true}` (unchanged shape for legitimate retries); on `conflict` **do not return the foreign order** - throw `new HttpsError('already-exists', <message>, {code: 'IDEMPOTENCY_CONFLICT', reason})` and call `logSecurityAlert({fn: 'createOrder', event: 'idempotency_conflict_rejected', ...})`.
- Client: with a receipt, show what the catch blocks (`:247`, `:308`, `:353`) do with an `already-exists` HttpsError today. Then map it to a **distinct, non-retryable, user-visible conflict failure** (never "order placed"), with a test under `core_app/test/features/checkout/**`. If the change would exceed the section-2 territory, STOP and report instead of widening it.

**T-4 - regression proof (sanctuary).** Prove the legitimate path is untouched: the same-key + same-content case still returns the same order id with `idempotent: true`; the money/tax/refund guards still run on the miss path; `npm test` reports `90 + N` with 0 failures; the Flutter lanes are unchanged (+1996 core_app / +329 / +289 / +71, 0 skip).

**T-5 - report + receipts.** `tool_fix/b12/b12_report.md` per section 4.

---

## 4. REPORT FORMAT (`tool_fix/b12/b12_report.md`)

1. Header: batch, worktree, branch, base (must be `3b95c0f` or a proven descendant), commits.
2. T-table: task, red receipt, green receipt, files touched.
3. The decision matrix actually implemented (rows x expected x observed).
4. **Six-way classification** for every finding touched: VERIFIED / UNVERIFIED (server-live behaviour, emulator) / ANOMALY / DRIFT / RISK / RECOMMENDATION - the UNVERIFIED list must be non-empty and honest.
5. Sanctuary proof: `git diff` showing no money/tax/rounding file touched; existing tests byte-unchanged; assertion counts.
6. Gate receipts (section 5) with the exact commands.
7. **Paste-ready ledger block** `## FIX B12` (findings closed, base, tip, territory, deltas, gates).
8. DECISIONS-NEEDED-FROM-OWNER, if any behaviour choice is not fully determined by this contract.

---

## 5. GATES (all must be green on the committed tip)

| Gate | Command | Expect |
|---|---|---|
| Type check | `npx tsc --noEmit` in `core_app/functions` | exit 0 |
| Server tests | `npm test` in `core_app/functions` | `90 + N` pass, 0 fail |
| Flutter analyze | `flutter analyze --fatal-infos` core_app + core_ui; `dart analyze` core | 0 each |
| Format | `dart format --output=none --set-exit-if-changed .` (root) | 0 changed |
| Suites | core / core_ui / core_app / halal_boyz | `+329 / +289 / +1996 / +71`, 0 fail, 0 skip |
| Greps | new code: `TODO`, `FIXME`, `@Skip`, `skip:`, `expect(true` | 0 |
| Territory | `git diff --name-only` vs the section-2 list | exact |

**Out of scope, explicitly:** deploying anything, emulator runs, live Stripe calls, rules changes, dependency changes.

---

## 6. COORDINATOR PROTOCOL (after the report)

1. Verify the red receipt predates the implementation commit.
2. Re-run the section-5 gates on the merged tip; check the sanctuary diff.
3. Flip `REC-B2-1` in `AUDIT_TRIAGE_STAGE3.md` to CLOSED-WITH-RECEIPT (or record the residual honestly).
4. Declare **Stage 4 complete**, then open **Stage 5**: re-run all four audits (the AUD-1..AUD-4 prompts in `AUDIT_FLEET_13CLASSES.md`) - every remaining register row must flip to CLOSED-WITH-RECEIPT or receive a named owner.

---

## 7. EXECUTOR QUICKSTART

```
cd <repo>-cline-5
git rev-parse --abbrev-ref HEAD            # must be cline/task-5
git merge main                             # expect 3b95c0f or a proven descendant (rule W2b: prove it)
flutter pub get ; cd core_app/functions ; npm ci
# BLOCKER gate: npx tsc --noEmit, npm test (90), analyze x3, format root, 4 suites
# then: write T-2's test file FIRST -> capture red -> implement T-1 -> wire T-3 -> T-4 -> T-5
```

**House discipline reminders:** explicit `git add <paths>` (never `git add -A`) - every receipt must be non-empty and reproducible (rule R-V) - one commit per task, then a receipts commit - red before green, always.
