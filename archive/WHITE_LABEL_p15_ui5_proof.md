# WHITE_LABEL_p15_ui5_proof — UI-5: PROOF WAVE — MAIN ONLY (single executor on main)

**Fleet finale:** p11 shapes (DONE) → p12 motion (DONE) → p13 tiles (DONE, merged `667a4c9`) → p14 layouts (DONE) → **p15 proof (this spec)**. This is the `WHITE_LABEL_BATCHES.md` §3.6 final-wave pattern: **main-only, not window work** — its verdict is the library's clearance authority. Inherits p10 §0 0.1–0.7 + p11 laws L1–L5.

**Predecessors verified (B-1):** `ui2(p12)` `3fe9019..2ff3d5a` in main + pushed; `ui3(p13)` merged `667a4c9`; `ui4(p14)` merged `da77c1d`; ledger addenda `0694b4a`; wave closure `b720556`. Baseline tip: **`b720556`**, suite **+230 / 0 skip**, analyze ×2 = 0, format 0, barrel 43 exports / 0 dups.

## §0 Rules (binding)

0.1–0.7 inherited verbatim from `WHITE_LABEL_p10_t78.md` §0 (proof law; no fake green; blocker canonical; executor never touches `FIX_VERIFICATION.md` — paste-ready block only; territory exclusivity with documented red→green fix fallout allowed; no re-derive — cite the four batch reports; baseline discipline; fail-safe defaults recorded).
0.8 **Main-only.** No worktree, no parallel window work. Wave batteries must not run concurrently with anything else.
0.9 **Read-only library surface by default.** This wave writes TESTS + receipts + goldens only. If the matrix exposes a real component defect, the fix is red→green **inside the named component's file** with a DRIFT entry and receipts — never a silent fix, never a matrix weakened to pass.
0.10 **Deterministic visuals.** Goldens pump with fixed themes and settle explicitly (L8 discipline); fonts are the AppTheme test-guard path (System in tests — P1: `app_theme.dart` `_isTest` seam). Golden files live under `packages/core_ui/test/goldens/`.

### Batch laws (proof-wave specific)

L9 **The matrix is the contract.** Every new component (26 files, §1 inventory) must render WITHOUT exception under: light × dark × `AppMotionStyle.{full,subtle,none}` × shape-token variants (`AppShapeTokens(cardRadius: 24)` and default), with content asserted present. A component that cannot render under any combo fails the fleet.
L10 **Palette injection is the Law-3 proof.** At least the components that read `BrandColors` (chip, badge, banner, price tag, stepper, stat/status tiles) are asserted to resolve an INJECTED custom palette (distinct from `AppColors` constants) — proving config-driven rebranding end-to-end.
L11 **A11y is a gate, not a wish.** Every interactive component exposes a semantics handle with the expected action/label: `PriceTag` merged label, stepper tooltips, chip/card/tile tap semantics, ≥ 48 dp tap targets on steppers.

## §1 Inventory (verified — the barrel's 43 exports, new-file subset)

p11 (10): `shapes`, `brand_card`, `brand_chip`, `brand_badge`, `price_tag`, `brand_divider`(+`DashedLinePainter`), `info_banner`, `gradient_scaffold`, `brand_text_field`, `quantity_stepper` · p12 (5): `pressable_scale`, `fade_slide_in`, `staggered_entrance`, `animated_count_text`, `animated_visibility` · p13 (6): `stat_tile`, `setting_tile`, `menu_tile`, `status_tile`, `tile_grid`, `tile_skeletons` · p14 (5): `app_breakpoints`(+`ResponsiveBuilder`), `screen_scaffold`, `section_header`, `adaptive_row`, `gap`. (Receipts: `tool_uilib/p11..p14/*/coverage.txt`.)

## §2 Territory (exclusive)

NEW: `packages/core_ui/test/ui5_proof_matrix_test.dart` · `packages/core_ui/test/goldens/**` (captured goldens) · `tool_uilib/p15/**`
MODIFIED: only via §0.9 documented red→green fallout, inside named component files, with receipts.
FORBIDDEN: everything else — theme/**, existing tests, barrel (no new exports — this wave adds no components), pubspec.*, `core_app/**`, `apps/**`, `functions/**`, `packages/core/**`, `FIX_VERIFICATION.md`.

## §3 T-x table (all red→green where behavior is asserted; matrix/goldens are new capability — their RED is the absence proof in `red_suite.txt`)

| Task | Deliverable | Acceptance |
|---|---|---|
| T-1 | Compatibility matrix (`ui5_proof_matrix_test.dart`) | All 26 components × light/dark × motion {full, subtle, none} × shape variants render exception-free with content asserted (L9). Combinatorics bounded: per-component themed loops + explicit style-variant cases for the 5 motion components + the 3 tile/grid components. |
| T-2 | Palette injection (in the matrix file) | Injected `BrandColors` palette (distinct hues) resolved by every `BrandColors`-reading component (L10) — assert ≥ 6 components render the CUSTOM color, not the `AppColors` constant. |
| T-3 | Goldens | Captured set ≥ 12 files covering each family (card, chip, badge, price tag, divider solid+dashed, banner, stat/setting/menu tile, section header, gradient scaffold, stepper) at fixed light theme; `expectLater(...matchesGoldenFile)` green; `--update-goldens` capture recorded. Cross-machine golden fragility = documented residual, not a gate failure. |
| T-4 | A11y sweep (in the matrix file) | Semantics assertions per L11 across the interactive set; failures are fleet blockers. |
| T-5 | Final battery + manifest (`tool_uilib/p15/p15_report.md`) | §5 gates + the library completion statement: 26 components, 43 exports, suite counts, coverage roll-up (100% × 26), grep census, residuals; paste-ready `## APP COMPLETION UI-5 (p15)` block. |

## §4 Deliverable

`tool_uilib/p15/p15_report.md`: summary; per-T evidence; six-way classification; honest residuals (golden portability, device-only classes); DECISIONS-NEEDED-FROM-OWNER; UNVERIFIED (non-empty allowed); DRIFT; paste-ready ledger block.

## §5 Acceptance

- analyze --fatal-infos (core_ui) + dart analyze (core) exit 0 · format (root) 0 · core_ui suite **230 + new (≥ 20)** green 0 skip; existing 230 untouched · coverage: **100% lines on all 26 new component files — no drop** (the wave adds no production lines; if §0.9 fallout adds lines, they land covered) · greps 0 · red→green receipts · goldens captured under `test/goldens/` (or loudly parked with reason).

## §6 Judge + library clearance

Coordinator re-runs the full battery; spot-checks ≥ 3 matrix cells + ≥ 2 goldens + the palette-injection assertions; appends the UI-5 ledger block; then declares **UI LIBRARY COMPLETE** (or lists named residuals). This is the fleet's numeric freeze criterion: zero open findings + floors met → declaration in the ledger.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-5 (p15), the PROOF WAVE, MAIN ONLY.
Read <repo>\WHITE_LABEL_p15_ui5_proof.md IN FULL — binding contract.
1. SYNC + UP-TO-DATE (fail-closed): cd <repo>; git status --porcelain --untracked-files=no (clean); git log --oneline -1 == b720556 (or descendant; origin/main == local). BLOCKER: flutter analyze --fatal-infos (core_ui) + dart analyze (core) + dart format check (root) + flutter test (core_ui, 230/230, 0 skip) — ALL green BEFORE any edit. Failure => STOP, evidence table.
2. RED: write test/ui5_proof_matrix_test.dart to the §3 T-1..T-4 contract; run; capture failure to tool_uilib/p15/red_suite.txt (symbols/components render-checks may fail first by absence of the matrix itself — the honest red is the suite's new file failing its assertions).
3. GREEN: make the matrix pass. If a component genuinely fails under a combo: red→green fix INSIDE that component file (0.9), receipts before/after. dart fix --apply; dart format; analyze 0; suite green 0 skip.
4. GOLDENS: capture the T-3 set (flutter test --update-goldens on the golden group once), then verify plain `flutter test` passes against the captured goldens. Any mismatch => investigate, never re-capture to force green.
5. COVERAGE + GREPS: 100% on all 26 files (no drop); greps 0; receipts to tool_uilib/p15/.
6. REPORT: tool_uilib/p15/p15_report.md per §3 T-5 (six-way, UNVERIFIED non-empty allowed, DECISIONS, DRIFT, paste-ready UI-5 ledger block). NEVER touch FIX_VERIFICATION.md.
7. COMMIT + BATTERY: git add <territory files> && git commit -m "ui5(p15): proof wave — matrix + goldens + a11y, library cleared"; full battery on the committed tip; push only if credentials cached.
DoD: every §5 item green + report + receipts + green committed tip + nothing left uncommitted.
```

**END OF UI-5 SPEC — the library's final contract.**