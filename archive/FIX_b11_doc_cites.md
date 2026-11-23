# FIX-B11 — DOC-CITES + stale claims + the generator's money template (`F-B8-01`)

**Batch:** `B11` · **Findings:** `AUD4-C4-01…04` (22 hard-bad doc refs: 16 missing files + 6 past-EOF, inside 176/789 BAD_REF rows) · `AUD4-C5-03` (18 deferral rows needing an explicit owner) · `AUD1-11…16` (stale claims: `app_colors.dart:10` byte-sync, `labs.dart:18-20` naming, 9 post-ARCH-2 "wiring lives in `main.dart`" comments, 2 comments citing non-existent test files, "banker's rounding" mislabel) · **`F-B8-01` (NEW, MED-HIGH, fail-open — found by B8 + independently confirmed by the coordinator): the generator's emitted client test still pins the RETIRED money form.**
**Worktree:** `<repo>-cline-2` (`cline/task-2`). May run ∥ `B10`.

## §0 Laws

0.1 Spec = acceptance contract; spec-vs-code conflict = **STOP + report**. 0.2 Proof law (receipts + P1). 0.3 Red→green where a detector exists (T-1, T-5). 0.4 Ledger single-writer. 0.5 Territory (§2). 0.6 Commit per task; never end on red. 0.7 **Text-only discipline:** this batch changes prose, comments and one emitted **expectation string**; it must not alter any production behaviour. 0.8 No new dependencies. 0.9 Git strictly serialized. 0.10 **Money-safety carve-out for T-5:** the emitted template's expected string may be corrected, but `moneyCents`/`money_text.dart`/the money formatters are **forbidden** — the fix aligns the *expectation* to the canonical formatter, never the reverse.

## §1 Research receipts (verified at `15fac44`)

| Fact | Evidence |
|---|---|
| `core_app/tool/whitelabel.dart:2185-2200` emits a client test asserting `expect(formatCurrencyCents(-500, 'USD'), r'$-5.00')` and `expect(..., r'$1.00')` for the unknown code, with the comment *"The canonical formatter renders the sign after the symbol — the exact production contract"* | read at HEAD; **independently reproduced by the coordinator** |
| The unified formatter renders `-$5.00` / `XYZ 1.00` (owner decision **D-1**, `AUD1-02`) and the shipped halal test was re-pinned accordingly in `B3b` | `apps/halal_boyz/test/price_cents_guard_test.dart` (merged) |
| ⇒ a regeneration would ship a client whose test suite **fails**, and re-introduce the audited money form | B8 T-4 census: the only `CONTENT-DRIFT` surface; `tool_fix/b8/t4_drift_money_shipped_test_run.txt` |
| Doc-ref scanner: 789 rows, **176 BAD_REF**, of which hard-bad = **16 missing files + 6 past-EOF**; live queue specs p16–p20 have **0** stale path premises | AUD-4 C4 (`tool_audit/aud4/**`) |
| 18 deferral rows lack a named owner; the one real orphan (`p20:43` → `p22_staff`) was already fixed in the register | AUD-4 C5; register §11 |
| Stale claims list (`AUD1-11…16`) | `tool_audit/aud1/aud1_report.md` |

## §2 Territory

**MODIFIED:** the **hard-bad** lines in the active specs/audits (`WHITE_LABEL_p1*.md`, `p2*.md`, `AUDIT_*.md`, `RESEARCH_*.md`) · the stale inline comments named in `AUD1-11…16` (comment text only: `packages/core_ui/lib/src/theme/app_colors.dart` doc line, `packages/core_app/lib/labs.dart` doc lines — **path per HEAD**) · **`core_app/tool/whitelabel.dart` lines 2185-2200 only** (the emitted expectation strings + that comment).
**CREATED:** a re-runnable doc-ref scanner under `tool_fix/b11/` · a detector test proving the emitted money expectations match the canonical formatter · receipts in `tool_fix/b11/**`.
**FORBIDDEN:** `money_text.dart` and every money formatter · production logic · `.gitignore`/litter (`B10`) · `FIX_VERIFICATION.md` · `tool_audit/**` (findings stay verbatim; only the *live* specs get corrections) · history rewriting.

## §3 Tasks (each starts red where a detector exists)

**T-1 — doc-refs, scanner first (red).** Commit a re-runnable scanner (`tool_fix/b11/doc_refs.ps1`) that extracts every `path:line`-style reference from the live specs and reports missing-file / past-EOF rows. RED: it must reproduce the 22 hard-bad rows (16 missing + 6 past-EOF). Then correct **only the hard-bad ones** (re-point to the real file/line, or rephrase the claim). GREEN: hard-bad = **0**; the 78 leaf-ambiguous rows are classified (ambiguous vs benign) with a one-line note each.

**T-2 — `AUD1-11…16` stale claims.** Fix each named claim at its HEAD location: `app_colors.dart`'s byte-sync assertion (false since the sanctioned halal rebrand), `labs.dart`'s naming, the 9 post-ARCH-2 "wiring lives in `main.dart`" comments (main.dart is now a 27-line wrapper), the 2 comments citing non-existent test files, and the "banker's rounding" mislabel (Dart `num.round()` is half-away-from-zero). Each edit is comment/doc text only, with a receipt quoting before/after.

**T-3 — `AUD4-C5-03` deferral owners.** Add an explicit owner to the 18 rows that lack one (they are benign prose/echoes — the fix is the annotation, not a new batch). Confirm `AUD4-C5-01`'s orphan stays closed.

**T-4 — the detector for T-1.** The scanner must exit non-zero when a hard-bad ref exists (prove with a deliberate temporary break, then restore).

**T-5 — `F-B8-01`, the generator's money template (the one behaviour-adjacent fix).** RED first: a test that **fails** because the emitted client test's money expectations do not match the canonical formatter. Then correct the emitted strings to `-$5.00` / `XYZ 1.00` and the false comment, so a regeneration ships a **passing, CLDR-conformant** test. Prove: the detector red → green; the shipped halal test still passes; `money_text.dart` + every formatter **untouched** (`git diff` empty); the generator's dry-run census shows the CONTENT-DRIFT count dropping to 0.

## §4 Deliverable

`tool_fix/b11/b11_report.md`: T-table (red → green per task), the hard-bad before/after counts, the claim-by-claim correction table, the deferral annotations, the `F-B8-01` red→green pair, six-way classification, DECISIONS, UNVERIFIED, DRIFT, paste-ready `## FIX B11` ledger block. Receipts in `tool_fix/b11/`.

## §5 Acceptance

doc-ref hard-bad **0** with the scanner committed and failing on a deliberate break · every stale claim corrected at HEAD with a before/after receipt · deferral rows annotated · `F-B8-01` detector red → green · **money formatters byte-unchanged** · format 0 · analyze ×3 0 · suites core + core_ui + core_app + halal green **0 skip** no drop · greps 0 · forbidden paths untouched · nothing uncommitted.

## §6 Judge + close (coordinator)

Re-runs the scanner (expect hard-bad 0) and the `F-B8-01` detector; confirms `money_text.dart` is untouched; spot-checks 3 corrected claims against HEAD; merges; appends the ledger block; flips `AUD4-C4-01…04`, `C5-03`, `AUD1-11…16`, `F-B8-01` → **CLOSED-WITH-RECEIPT**.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of FIX-B11 (DOC-CITES + stale claims + the generator money template). Worktree <repo>-cline-2 (branch cline/task-2). May run beside B10.
Read <repo>\FIX_b11_doc_cites.md IN FULL — binding contract; the text-only discipline (§0.7) and the money-safety carve-out (§0.10) apply.
1. SYNC (fail-closed): assert branch == cline/task-2; git merge main; flutter pub get; BLOCKER gate: analyze core_app + core + core_ui, format root, suites core + core_ui + core_app + apps/halal_boyz green 0 skip. Red => STOP + report.
2. T-1 RED: write tool_fix/b11/doc_refs.ps1; capture the 22 hard-bad rows to tool_fix/b11/red_doc_refs.txt.
3. GREEN T-1: correct only the hard-bad refs; re-run -> hard-bad 0.
4. T-2 stale claims (comment/doc text only) + T-3 deferral annotations + T-4 scanner exit-code proof.
5. T-5 RED: the emitted-money-expectation test fails; GREEN: correct whitelabel.dart lines 2185-2200 only (strings + comment); prove money_text.dart untouched and the dry-run CONTENT-DRIFT = 0.
6. PROOF: format 0; analyze 0 x3; suites core/core_ui/core_app/halal green 0 skip; greps 0; territory diff.
7. REPORT: tool_fix/b11/b11_report.md per §4 (paste-ready ledger block; NEVER touch FIX_VERIFICATION.md).
8. COMMIT locally on cline/task-2 (explicit paths, one commit per task); do NOT merge, do NOT push — the coordinator merges.
DoD: every §5 item green + hard-bad 0 + F-B8-01 closed + money formatters untouched + nothing uncommitted.
```

