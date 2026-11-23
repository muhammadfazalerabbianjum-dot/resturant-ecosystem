# FIX-B3b — halal money re-pin (restore the shell suite to green on CLDR)

**Batch:** `B3b` · **Origin:** a **regression** surfaced by the wave-3 coordinator battery (not a new audit finding — a direct consequence of `AUD1-02` + owner decision **D-1**). **Priority: HIGH — `main`'s halal suite is currently RED (`+70 -1`).**
**Worktree:** `<repo>-cline-3` (`cline/task-3`). May run ∥ `B6`.

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1 `file:line`). 0.3 Red→green; the failure receipt is captured **before** the re-pin. 0.4 Ledger single-writer. 0.5 Territory (§2). 0.6 Never end on red; commit once. 0.7 **Test-change rule (the pattern already accepted twice in this fleet):** re-pinning an assertion that encoded an **audited defect** is legitimate **only** with (a) the pre-change failure receipt, (b) a one-line reason per changed value, (c) **no assertion deleted** (count provable), (d) all other assertions byte-identical. 0.8 No new dependencies. 0.9 Git strictly serialized.

## §1 Research receipts (verified at `2a90cb6`)

| Fact | Evidence |
|---|---|
| Failing test: `T-B9-3 (ARCH-1): the REAL money formatter … handles negatives and the unknown-code fallback` at `price_cents_guard_test.dart:38` | `tool_fix/wave3/main_halal.txt` → `+70 -1: Some tests failed` |
| Assertion delta: `Expected: '$-5.00'` vs `Actual: '-$5.00'` | same receipt (exact lines) |
| The test was authored by **B9/p16.5** while the legacy formatter still composed symbol-first; it pins the behavior `AUD1-02` audited and **D-1** retired | B9 provenance + `AUD1-02` |
| The identical re-pin was already accepted for the app-side twin, with the same justification | `core_app/test/app/config/currency_format_test.dart` (B3 commit `272d197`) |
| The test title also covers "the unknown-code fallback" — the legacy `$`-for-unknown was retired to a `CODE ` prefix (fail-closed) | `AUD1-02`; B3's `money_text.dart` doc |

## §2 Territory

**MODIFIED:** `apps/halal_boyz/test/price_cents_guard_test.dart` **only**.
**CREATED:** receipts in `tool_fix/b3b/**`.
**FORBIDDEN:** every production file · every other test file · configs · theme · `FIX_VERIFICATION.md` · `tool_audit/**`.

## §3 Tasks

**T-1 — capture the red (before any edit).** Run the halal suite at the current tip; save `tool_fix/b3b/red_halal.txt` showing the exact failure (`$-5.00` vs `-$5.00`).

**T-2 — re-pin to the CLDR target.** Negative money renders `-$5.00` (D-1). If the test also asserts the unknown-code fallback, pin the fail-closed `CODE ` form. Keep every other assertion byte-identical; add a comment per changed value naming `AUD1-02` + `D-1` as the reason.

**T-3 — prove no weakening.** Record the assertion count before/after (must not decrease) and the diff (only the re-pinned values + comments).

**T-4 — suite green.** `flutter test` in `apps/halal_boyz` → **all passed, 0 skip, ≥ 71 tests**; save `tool_fix/b3b/green_halal.txt`.

## §4 Deliverable

`tool_fix/b3b/b3b_report.md`: T-table (red → green), the diff, the assertion-count proof, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B3b` ledger block. Receipts in `tool_fix/b3b/`.

## §5 Acceptance

halal suite green **0 skip** · `flutter analyze --fatal-infos` (halal) 0 · format 0 · `git diff --name-only` = **exactly the one test file** (plus `tool_fix/b3b/**`) · assertion count not reduced · no production file touched · greps 0 · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the halal suite + the full merged battery; verifies the diff is confined; merges; records the closure + the new rule (shell suites are part of every money batch's gate) in the register.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B3b (halal money re-pin — restore the shell suite to green). Worktree <repo>-cline-3 (branch cline/task-3). May run beside B6.
Read <repo>\FIX_b3b_halal_money_repin.md IN FULL — binding contract.
1. SYNC: assert branch == cline/task-3; git merge main; flutter pub get.
2. T-1 RED: cd apps/halal_boyz; flutter test 2>&1 | Tee-Object ..\..\tool_fix\b3b\red_halal.txt — capture the '$ -5.00' vs '-$5.00' failure.
3. T-2/T-3: re-pin apps/halal_boyz/test/price_cents_guard_test.dart to the CLDR target (minus before symbol; CODE-prefix for unknown codes if asserted), comment each changed value with 'AUD1-02 + D-1', delete NO assertion, record the assertion count before/after.
4. T-4 GREEN: flutter test in apps/halal_boyz -> all passed, 0 skip (>= 71); Tee to tool_fix/b3b/green_halal.txt.
5. PROOF: git diff --name-only shows ONLY that test file (+ tool_fix/b3b/**); analyze halal 0; format root 0 changed.
6. REPORT: tool_fix/b3b/b3b_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
7. COMMIT locally on cline/task-3 (explicit paths); do NOT merge, do NOT push — the coordinator merges.
DoD: halal suite green 0 skip + one-file diff + no assertion deleted + nothing uncommitted.
```
