# FIX-B4 — TAX-1: ONE server tax implementation + a pinned rounding contract (`functions/` authority)

**Batch:** `B4` · **Findings:** `AUD1-04` (MED-HIGH: two server tax impls; `calculateTax`'s fail-closed guard **unreachable** → silent 5 % tax while the charge path fails closed) + `AUD1-05` (MED: Node `Math.round(-3.5) = -3` vs Dart `(-3.5).round() = -4`; moved here from `B3` per register §9).
**Worktree:** `<repo>-cline-5`. **Runs ALONE** (money path; serialized with `B12` — both edit `functions/src`).

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`); UNVERIFIED mandatory (the functions lane is read-not-executed — §1). 0.3 Red→green per task, receipt **before** the fix. 0.4 Ledger single-writer. 0.5 Territory exclusivity (§2) + §9 standing rule (unlisted call site ⇒ STOP). 0.6 Never end on red; commit per task. 0.7 **MONEY SANCTUARY:** existing tax/money tests may be **added to, never weakened**; **positive-amount outcomes must be byte-identical** (a changed charge is a defect, not a migration); doubt resolves to **fail closed — no charge, no silent default rate**. 0.8 No new dependencies. 0.9 Git strictly serialized. 0.10 **Server = money authority:** the client never computes an authoritative tax (display/preview only).

## §1 Research receipts (verified at `2a90cb6`)

| Fact | Evidence |
|---|---|
| Server twin A — the `calculateTax` callable computes `const taxCents = Math.round(subtotalCents * rate)` | `core_app/functions/src/index.ts:129` (`export const calculateTax = onCall(...)`), `:156`; schema `:123` |
| Server twin B — the **charge path** uses `computeTaxCents(...)` | `core_app/functions/src/index.ts:697`; `core_app/functions/src/payment.ts:158` (`computeTaxCents`), `:102` (`extractClientTaxConfig`) |
| The twins disagree on the guard: AUD-1 proved `calculateTax`'s fail-closed guard is **unreachable** → it silently applies a default rate | `AUD1-04`; `tool_audit/aud1/receipts/c3_tax_sources.txt` |
| Rounding divergence on negative halves: Node `Math.round(-3.5) = -3`, Dart `(-3.5).round() = -4`; 16-row table incl. `-7 @ 0.5`, `50 @ 0.05` | `tool_audit/aud1/receipts/c3_tax_rounding_node_neg.txt` |
| Client calls the callable and parses the result (display/preview only) | `packages/core/lib/src/tax/tax_service.dart:10` (`class TaxService`), `:36` (`httpsCallable('calculateTax')`), `:44` (`taxCents`) |
| Client-side rate lookup/validation (0.0–1.0 bounds) | `core_app/lib/app/config/tax_rates_repository.dart:8-16` |
| No emulator/Jest lane for `functions/` exists → server behaviour is asserted via **pure-function parity + a committed runnable node script**, as AUD-1 did (`tax_round.js`) | AUD-1 UNVERIFIED §4 + `tool_audit/aud1/scratch/tax_round.js` |

## §2 Territory

**MODIFIED:** `core_app/functions/src/payment.ts` (**the single implementation**) · `core_app/functions/src/index.ts` (the `calculateTax` callable delegates + reachable guard) · `packages/core/lib/src/tax/tax_service.dart` (only if a display rounding helper is added) · only if a signature changes, the enumerated callers: `core_app/lib/features/checkout/domain/checkout_service.dart` (call site only — no money logic), `core_app/lib/app/config/tax_rates_repository.dart`.
**CREATED:** parity suites (`packages/core/test/**` display side, `core_app/test/**` integration) · a committed runnable node parity script under `tool_fix/b4/` · receipts in `tool_fix/b4/**`.
**FORBIDDEN:** `B12`'s dedupe branch (`index.ts:1100-1150`) · money formatters (`B3`, closed) · checkout idempotency (`B2`, closed) · theme · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks (each starts red)

**T-1 — one implementation.** The `calculateTax` callable **delegates** to the same function the charge path uses (`computeTaxCents` / `extractClientTaxConfig`); no second rate-resolution or rounding rule survives (grep proof: no second `Math.round(`-based tax computation, no second default-rate literal).

**T-2 — the guard becomes reachable (the fail-closed red).** Unknown client / missing rate / out-of-range rate must **fail closed in both paths** (explicit error surface, no silent default). RED: today `calculateTax` silently applies a default. Tests assert an error for: unknown `clientId`, missing rate for the state, rate outside `[0,1]`.

**T-3 — one rounding contract, both languages.** Integer-cents tax rounding is **half away from zero** (matching Dart's `.round()`); implement it explicitly in JS (NOT `Math.round`, which rounds half toward +∞) and use it in the single implementation. RED: the negative-half rows of the AUD-1 table.

**T-4 — the AUD-1 parity table green.** A committed, re-runnable script (`node tool_fix/b4/tax_round_parity.js`) reproduces the 16-row AUD-1 table for **both** the old and new rules and proves: every **positive** row byte-identical to today; every **negative** row now equal to Dart's `.round()`; the receipt is committed.

**T-5 — display/authority split preserved.** `TaxService` stays display/preview: it never computes an authoritative total, and its parsed value equals the charge path's for the shared rows (asserted).

## §4 Deliverable

`tool_fix/b4/b4_report.md`: T-table (red → green), the 16-row before/after rounding table, six-way classification, DECISIONS, UNVERIFIED (server lane = read-not-executed, explicitly), DRIFT, paste-ready `## FIX B4` ledger block. Receipts + the node script in `tool_fix/b4/`.

## §5 Acceptance

red→green per T · `flutter analyze --fatal-infos` core_app 0 · `dart analyze` core + core_ui 0 · format 0 · suites core_app + core + core_ui **and the halal shell suite** green **0 skip** no drop · existing tax tests byte-unchanged (git diff) · **positive tax outcomes byte-identical** (T-4 receipt) · guard reachable in both paths (T-2) · node parity script committed and clean · greps 0 · forbidden paths untouched · nothing uncommitted.

> **Added after wave-3's coordinator battery:** the **halal shell suite is now an explicit gate for every money-touching batch** (wave 3 surfaced a halal red that neither B3's nor B5's own battery covered — see register §11). Nothing changes hands while a shell suite is red.

## §6 Judge + close (coordinator)

Re-runs the battery on the committed tip **including `apps/halal_boyz`**; spot-checks ≥3 (T-4's before/after table: positives identical, negatives corrected; T-2's error receipts for the three fail-closed cases; no tax test file modified); runs the node script myself; merges; appends the ledger block; flips `AUD1-04` + `AUD1-05` → **CLOSED-WITH-RECEIPT** and re-runs the C3 tax detector.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B4 (TAX-1: one server tax implementation + pinned rounding contract) — money-critical, runs ALONE. Worktree <repo>-cline-5.
Read <repo>\FIX_b4_tax_rounding.md IN FULL — binding contract; MONEY SANCTUARY (§0.7) and server-authority (§0.10) apply.
1. SYNC (fail-closed): assert branch == cline/task-5; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core/core_ui, format root, suites core_app + core + core_ui + apps/halal_boyz all green 0 skip BEFORE any edit. Red => STOP + report.
2. RED: T-2 fail-closed tests + T-3/T-4 rounding table first; capture to tool_fix/b4/red_*.txt (expect the unreachable-guard silent default and the negative-half divergence).
3. GREEN: implement T-1..T-5 (single impl in payment.ts, callable delegates, explicit half-away-from-zero in JS); commit per task; dart fix --apply; dart format; analyze 0; suites green 0 skip.
4. PROOF: positive tax outcomes byte-identical; existing tax tests untouched (git diff); node parity script committed and run; halal suite green; territory + grep evidence.
5. REPORT: tool_fix/b4/b4_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
6. COMMIT locally on cline/task-5; re-run the full battery on the tip; do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green (halal included) + positives byte-identical + guard reachable in both paths + node parity receipt committed + nothing uncommitted.
```

