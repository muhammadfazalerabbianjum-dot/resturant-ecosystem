# WHITE_LABEL_p11_ui1_shapes — UI-1: SHAPES + PRIMITIVES — SINGLE EXECUTOR

**Owner-approved UI expansion fleet (2026-09-22): p11 shapes → p12 motion → p13 tiles → p14 layouts → p15 proof.** One batch per unit of work, full gate set between batches, rolling owner approval. This spec is the acceptance contract for UI-1 only. Post-freeze context: the app is FROZEN at zero open findings (LEDGER:PERF-10) — this fleet is additive capability in `packages/core_ui` and MUST NOT weaken any frozen surface.

## §0 Rules (binding — inherited from WHITE_LABEL_p10_t78.md §0 where applicable)

0.1 **Proof law.** Every claim in the deliverable carries P1 (file:line opened this session) or P2 (a test that fails if false). No-receipt claims go in a mandatory non-empty UNVERIFIED section.
0.2 **No fake green.** No `@Skip`/`skip:`/TODO-as-done/`expect(true)`. New components ship **red→green**: the suite is captured FAILING (classes absent) in `tool_uilib/p11/red_suite.txt` BEFORE the first component file is created.
0.3 **Blocker behavior is canonical.** Baseline (§1) not green, or spec-vs-code conflict → STOP, change nothing, report with an evidence table.
0.4 **The executor NEVER touches `FIX_VERIFICATION.md`.** Deliverables: receipts under `tool_uilib/p11/` + a paste-ready `## APP COMPLETION UI-1 …` ledger block in the report. Single-writer ledger stays with the coordinator.
0.5 **Territory exclusivity (§2).** Cross-territory findings = handoff notes. Drive-by fixes prohibited.
0.6 **Do not re-derive receipted facts.** Cite `LEDGER:PERF-10` / `DEEP_PROOF.md` for frozen-state claims.
0.7 **Baseline discipline.** Tip must be `19abedf` (main), tree clean, blocker gate green BEFORE any edit. (Verified this session: analyze exit 0, format 0 changed, core_ui 90/90 — post-revert of an unauthorized premature edit, itself the lesson this spec encodes.)
0.8 **Owner is present.** Any decision that would normally be asked is decided fail-safe and recorded in **DECISIONS-NEEDED-FROM-OWNER**. Recorded defaults: (a) component naming `Brand*` (matches `BrandButton` precedent); (b) worktree waived — single-writer main-tree session, one commit at batch close, coordinator/owner pushes.

### Batch laws (UI-specific, additive to §0)

L1 **Consume the frozen token engine, never modify it.** Components read `AppShapeTokens` (b10) / `BrandColors.of` (COLOR-1) / ambient `ThemeData`/`ColorScheme` with the documented `AppColors` fallback. `packages/core_ui/lib/src/theme/**` is out of territory, full stop.
L2 **Zero money math.** `PriceTag` formats via `moneyCents` (display-only money law, LEDGER:PERF-10) and never computes on cents. The comparison `compareAtCents > cents` only suppresses a nonsensical compare-at display — display logic, not money math.
L3 **No hardcoded user-facing strings.** All visible text is caller-supplied. The only literal strings permitted are a11y fallback constants with the GlobalErrorWidget doc pattern (`kGlobalErrorFallbackBody` precedent) — call sites are expected to pass localized values.
L4 **No new dependencies.** `pubspec.yaml`/`pubspec.lock` forbidden. flutter/material + existing package imports only.
L5 **Fail-safe cosmetic layers.** Decorative surfaces (banners, backdrops) degrade, never throw; content is never rendered by a decorative layer.

## §1 Baseline (verified this session)

- Tip `19abedf` = `origin/main`; clean tracked tree (untracked `tool_perf2/**` receipts pre-exist and are untouched).
- Gates at baseline: core_ui **90** green · analyze exit 0 · format 0 changed (run post-revert, this session).
- Frozen inputs (P1: files opened this session): `app_tokens.dart` (AppShapeTokens default cardRadius 16; AppMotionTokens; AppBackdropTokens), `brand_colors.dart` (`BrandColors.of` + `BrandColors.fallback()`), `app_colors.dart` (semantic tones incl. success `0xFF2E7D32`, warning `0xFFFFC107`), `money_text.dart` (`moneyCents`), `skeleton_loader.dart` (factory pattern), `global_error_widget.dart` (fallback-string pattern), `transitions.dart` (motion baseline).

## §2 Territory (exclusive)

NEW: `packages/core_ui/lib/src/ui/{shapes,brand_card,brand_chip,brand_badge,price_tag,brand_divider,info_banner,gradient_scaffold,brand_text_field,quantity_stepper}.dart` (T-4 renamed `badge.dart` → `brand_badge.dart`, see §3 DRIFT)
NEW: `packages/core_ui/test/ui1_shapes_batch_test.dart` · `tool_uilib/p11/**`
MODIFIED (additive export lines ONLY): `packages/core_ui/lib/core_ui.dart`
FORBIDDEN everywhere: `FIX_VERIFICATION.md`, `DECISIONS_LOG.md`, `packages/core_ui/lib/src/theme/**`, existing `packages/core_ui/test/*` files, `pubspec.*`, `packages/core/**`, `core_app/**`, `apps/**`, `functions/**`, generated files, lockfiles, `.dart_tool/`, `build/`.

## §3 Problems → Acceptance → T-x table

| Task | Component | Acceptance (all red→green, 100%-line coverage target) |
|---|---|---|
| T-1 | `BrandShapes` (`shapes.dart`) | Pure static vocabulary: small 8 / medium 12 / large 16 / pill 999 radii + border getters + `tileShape` (large + optional side) + `stadium` + `outlinedMedium` (medium + optional side/width). |
| T-2 | `BrandCard` (`brand_card.dart`) | Material card, radius = `AppShapeTokens.cardRadius` (fallback 16); `onTap` → InkWell (exactly one tap path, semantics native); no `onTap` → inert (no InkWell); optional margin/padding/color/borderColor. |
| T-3 | `BrandChip` (`brand_chip.dart`) | Stadium chip; selected → primary bg / onPrimary fg; unselected → surface bg + `textSecondary` outline; optional icon; tap fires exactly once. |
| T-4 | `BrandBadge` (`brand_badge.dart`) | 4-tone pill `BadgeTone {neutral, positive, warning, negative}` with distinct (bg, fg) pairs from `BrandColors.of`/fallback: neutral textPrimary12/textPrimary · positive success/white · warning warning/textPrimary · negative error/white; stadium; single-line ellipsis. **DRIFT amendment: `Badge` → `BrandBadge` (Flutter's material SDK already exports `Badge` — the collision broke compilation; caught red→green).** |
| T-5 | `PriceTag` (`price_tag.dart`) | Delegates 100% to `moneyCents` (formatting literals asserted); compare-at shown ONLY when `compareAtCents > cents`, rendered strikethrough secondary; merged semantics label carries the full formatted sentence; `large` scales the primary amount. |
| T-6 | `BrandDivider` (`brand_divider.dart`) | Solid: thickness/indent/endIndent/color (dividerTheme-aware). Dashed: public `DashedLinePainter` with PURE static `dashOffsets(width, dash, gap)` (exact math asserted) + `shouldRepaint` contract by all fields. |
| T-7 | `InfoBanner` (`info_banner.dart`) | `InfoTone {info, success, warning, error}` → distinct icon + `BrandColors` color (info→primary, success→success, warning→warning, error→error); container tint α .08; optional `onDismiss` fires exactly once; `kDefaultDismissTooltip` documented fallback (L3). |
| T-8 | `GradientScaffold` (`gradient_scaffold.dart`) | Composition (no Scaffold): `ScaffoldBackground` (b10 overlay) → optional top-down gradient derived from `BrandColors.primary` α .06 over scaffold background → body. `applyGradient`/`applyOverlay` independently disable; decorative-only (L5). |
| T-9 | `BrandTextField` (`brand_text_field.dart`) | TextFormField wiring: label/hint/error/obscure/enabled/keyboardType/textInputAction/prefixIcon/maxLines/onChanged/onFieldSubmitted/validator (Form.validate path asserted). Chrome (borders/fill) owned by ambient `InputDecorationTheme` (b10 token) — NO border override. |
| T-10 | `QuantityStepper` (`quantity_stepper.dart`) | Clamped integer step [min,max]; decrement disabled at min, increment disabled at max; selection haptic on enabled press; `Tooltip`-backed a11y labels with `kDefaultDecreaseTooltip`/`kDefaultIncreaseTooltip` documented fallbacks (L3). |

## §4 Deliverable format

`tool_uilib/p11/p11_report.md`: phase summary; per-T evidence (receipts); six-way classification (Verified / Unverified / Anomalies / Untested / Risks / Recommendations); honest residuals; **DECISIONS-NEEDED-FROM-OWNER**; **UNVERIFIED** (mandatory, non-empty allowed); DRIFT; paste-ready `## APP COMPLETION UI-1 (p11) - … - VERIFICATION REPORT` block.

## §5 Acceptance

- `flutter analyze --fatal-infos` (core_ui) exit 0 · `dart analyze` (core) exit 0 · `dart format --output=none --set-exit-if-changed .` (repo root) exit 0.
- core_ui suite: **90 + new** green, 0 fail, **0 skip**; existing 90 tests byte-untouched (no weakening).
- Coverage: **100% lines per new component file** (any unreachable-by-design line parked loudly with reason; target is zero parks).
- Greps in new code: `TODO|FIXME|@Skip|skip:|expect(true` → **0**.
- Red→green: `tool_uilib/p11/red_suite.txt` (suite failing before implementation) + green receipts after.
- `core_app`, shell, packages/core: untouched (git status proves 0).

## §6 Coordinator protocol

Judge re-runs all §5 gates personally; spot-check ≥3 claims (T-2 token radius, T-5 formatting literals, T-10 bounds); verify forbidden paths 0 via `git status`/`git diff --stat`; commit; append the ledger block verbatim; only then dispatch UI-2 (p12) on owner approval.

## §7 Executor quickstart (paste-ready)

```
You are the SINGLE EXECUTOR of UI-1 (p11), the shapes+primitives batch.
Working tree: <repo> (main). Read <repo>\WHITE_LABEL_p11_ui1_shapes.md IN FULL — binding contract.
1. SYNC: git log -1 == 19abedf; tree clean except pre-existing untracked tool_perf2/**.
2. BLOCKER: flutter analyze --fatal-infos + dart format check + flutter test (core_ui, 90/90) — all green BEFORE any edit.
3. RED: write test/ui1_shapes_batch_test.dart to the T-1..T-10 contract; run; capture failure to tool_uilib/p11/red_suite.txt.
4. GREEN: implement the ten files; format; suite green 0 skip; analyze 0.
5. COVERAGE: flutter test --coverage; parse lcov for the 10 new files; 100% lines target.
6. GREPS: TODO|FIXME|@Skip|skip:|expect(true = 0 in new code.
7. REPORT: tool_uilib/p11/p11_report.md per §4 (six-way, UNVERIFIED non-empty, DECISIONS, paste-ready ledger block).
Forbidden: FIX_VERIFICATION.md, theme/**, pubspec.*, existing tests, core_app/**, apps/**, functions/**.
Definition of done: every §5 item green + receipts committed + nothing left uncommitted.
```

**END OF UI-1 SPEC.**

