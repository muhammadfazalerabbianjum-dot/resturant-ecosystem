# FIX-B2 — MONEY-4: order-scoped checkout idempotency (money-critical, runs ALONE)

**Batch:** `B2` · **Finding:** `AUD1-01` (**CRITICAL**, money) · **Authority:** `AUDIT_TRIAGE_STAGE3.md` §2.1/§3 · **Rule:** runs **alone** — no other window may compile-and-commit while it runs.
**Worktree:** `<repo>-worktree` (`cline/task-1`; B1 already merged there → clean continuation).

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`); UNVERIFIED section mandatory if non-empty. 0.3 Red→green per task, receipt captured **before** the fix. 0.4 Ledger single-writer (never touch `FIX_VERIFICATION.md`). 0.5 Territory exclusivity (§2). 0.6 Never end on red; commit per task. 0.7 **MONEY SANCTUARY:** existing money-path tests may be **added to, never weakened or deleted**; every change ships with the regression test that would have caught the defect; **doubt resolves to "do not charge / do not create a second order."** 0.8 No new dependencies. 0.9 Git strictly serialized.

## §1 Research receipts (verified at `59220f4`)

| Fact | Evidence |
|---|---|
| Client mints **one** key per session: `Uuid().v4()` under the constant `_checkoutSessionKey`, cleared only after **full** success | `core_app/lib/features/checkout/domain/checkout_service.dart:96-103` (AUD-1) |
| Server **dedupes orders by that key**, returning the EXISTING order id | `core_app/functions/src/index.ts:1100-1108` → `{orderId: existing.docs[0].id, idempotent: true}` |
| Compensation/refund runs **only** after the order path is entered | `core_app/functions/src/index.ts:1119-1150` (AUD-1) |
| Stated in-code intent is **retry-scoped** ("a retry after a createOrder failure reuses the SAME PaymentIntent") | AUD-1 `receipts/c3_idempotency_sites.txt` |
| ~~**Existing guard to keep green:** "L4 – Checkout Idempotency Token: two consecutive tokens are unique"~~ **CORRECTED after execution** — that group (`core_app/test/wiring/phase7_regression_test.dart`) asserts the **order-id token helpers** (`generateToken`/`generateSessionOrderId`), not the checkout idempotency key; it runs green (**+13**) but **would NOT have caught `AUD1-01`**. The new `checkout_order_scoped_idempotency_test.dart` is the actual detector (mutant M1 proves it). Coordinator's premise was wrong; the executor's receipt is `tool_fix/b2/b2_report.md` §16.6 and `tool_fix/b2/mutant_M1.txt` | `tool_fix/b2/mutant_M1.txt` (CORRECTED) |
| Consequence | app killed / network loss after `createOrder`, **or** a second, *different* order in the same session ⇒ resolves to the FIRST order; the new order is never created, so no compensating refund can fire. Silent, money path, no client-visible error |

## §2 Territory

**MODIFIED:** `core_app/lib/features/checkout/domain/checkout_service.dart` (key scoping) · **only if** a server guard is unavoidable: `core_app/functions/src/index.ts` (dedupe branch) — the report must justify any server edit explicitly.
**CREATED:** tests under `core_app/test/**` · receipts under `tool_fix/b2/**`.
**FORBIDDEN:** price/total/tax UI · `packages/**` money formatters (that is `B3`) · payment-intent parameters · other features · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — name the invariant in code:** the idempotency key is scoped to **one order attempt** — stable across retries of that attempt, **distinct** for a different cart/attempt, **rotated** once the order reaches full success. Never a session-wide constant.

**T-2 — two different carts in one session (the CRITICAL red).** Complete (or fail after `createOrder`) with cart A, then start cart B in the same session ⇒ B must create a **NEW** order. RED today (A's id is returned). GREEN after the fix.

**T-3 — retry safety preserved.** A genuine retry of the **same** attempt (failure after `createOrder`, then retry) reuses the **same** key ⇒ no duplicate charge/order. This is the behaviour the mechanism exists for; breaking it is a regression.

**T-4 — post-success rotation.** After a full success the next attempt uses a **different** key (no leakage of a finished order's key).

**T-5 — server contract respected.** A different cart fingerprint must never produce a key the server can match to another order's content; `idempotent: true` may only occur for a true retry.

**T-6 — fail-closed on doubt.** If the key cannot be derived/validated, the attempt fails **without creating an order and without charging** (explicit error), never falling back to a shared key.

## §4 Deliverable

`tool_fix/b2/b2_report.md`: T-table (red → green receipts), the invariant statement, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B2` ledger block. Receipts in `tool_fix/b2/`.

## §5 Acceptance

red→green per T · `flutter analyze --fatal-infos` core_app 0 · `dart analyze` core/core_ui 0 · format 0 · suites core_app + core + core_ui green **0 skip** no drop · **existing money/idempotency tests byte-unchanged** (git diff proof, incl. `phase7_regression_test.dart`) · money mutation gate re-run (no mutant survives in the idempotency/charge path) · greps 0 · forbidden paths untouched · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the battery on the committed tip; spot-checks ≥3 (T-2's red receipt shows **A's** order id returned for cart B; T-3 shows the same key reused on a true retry; no money test file modified); merges; appends the ledger block; flips `AUD1-01` → **CLOSED-WITH-RECEIPT** and re-runs the C3 divergent-twins detector for the idempotency row.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B2 (MONEY-4: order-scoped idempotency) — money-critical. Worktree <repo>-worktree (branch cline/task-1).
Read <repo>\FIX_b2_money_idempotency.md IN FULL — binding contract; MONEY SANCTUARY (§0.7) applies.
1. SYNC (fail-closed): assert branch == cline/task-1; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core/core_ui, format root, suites core_app/core/core_ui green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: write T-2/T-3/T-4/T-6 tests first; capture failures to tool_fix/b2/red_*.txt (T-2 MUST show cart B resolving to cart A's order id).
3. GREEN: implement T-1..T-6 in checkout_service.dart ONLY unless the report justifies a functions/ edit; commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. PROOF: existing money tests byte-unchanged (git diff), money mutation gate re-run, territory + grep evidence.
5. REPORT: tool_fix/b2/b2_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-1; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + regression tests present + money tests untouched + nothing uncommitted.
```

