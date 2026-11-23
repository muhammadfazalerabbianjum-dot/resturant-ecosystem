# WHITE_LABEL_p14_ui4_layouts — UI-4: LAYOUTS — SINGLE EXECUTOR, WORKTREE cline-2

**Fleet:** p11 shapes (DONE) → p12 motion (running, main) → p13 tiles (running, cline-1) → **p14 layouts (this spec)** → p15 proof. Inherits p10 §0 0.1–0.7 + p11 laws L1–L5 verbatim + WL_BATCHES §3.5/§3.6.

## §0 Worktree rules (binding, additive)

0.8 **Worktree:** work ONLY in `<repo>-cline-2` on branch `cline/task-2`.
0.9 **B-1..B-5 first.** Sync = `git -C <repo>-cline-2 merge main` + `flutter pub get`; gates green BEFORE any edit; blockers fail-closed.
0.10 **Self-contained territory (B-2).** Do NOT import any p12 (motion) or p13 (tile) component. Layout primitives compose plain widgets + theme/token reads only.
0.11 **Per-worktree ledger:** append to `<repo>-cline-2\FIX_VERIFICATION_cline-task-2.md` — NEVER main's `FIX_VERIFICATION.md`.
0.12 **Merge-back duty:** identical to p13 §0.12 (re-sync → merge from a clean main anchor → barrel conflicts = UNION, alphabetized → full battery on merged main, staggered → commit → push only if cached).
0.13 **Serialization gate:** if main moved past your anchor (p12 or p13 merged mid-flight), re-sync + re-run §5 gates before merge-back.

## §1 Baseline

- Main tip at dispatch: `2e21b10`. core_ui suite **141**, 0 skip; analyze/format 0.
- Frozen inputs (P1): `app_dimensions.dart` (paddingS 8 / paddingM 16 / radiusM 12), `app_tokens.dart` (backdrop), `brand_colors.dart`, `scaffold background` semantics of `app_theme.dart` (READ-only).

## §2 Territory (exclusive — zero shared paths with p12/p13)

NEW in worktree: `packages/core_ui/lib/src/ui/{app_breakpoints,screen_scaffold,section_header,adaptive_row,gap}.dart`
NEW: `packages/core_ui/test/ui4_layouts_batch_test.dart` · `tool_uilib/p14/**` · `FIX_VERIFICATION_cline-task-2.md`
MODIFIED (additive export lines ONLY): `packages/core_ui/lib/core_ui.dart`
FORBIDDEN: main `FIX_VERIFICATION.md`, `DECISIONS_LOG.md`, `packages/core_ui/lib/src/theme/**`, `transitions.dart` (p12's), every existing test file, `pubspec.*`, `core_app/**`, `apps/**`, `functions/**`, `packages/core/**`, generated files.

## §3 T-x table (all red→green; red receipt `tool_uilib/p14/red_suite.txt` BEFORE any component file)

| Task | Component | Acceptance |
|---|---|---|
| T-1 | `AppBreakpoints` + `ResponsiveBuilder` | Pure breakpoint algebra: `compact < 600 ≤ medium < 1024 ≤ expanded` (exact bounds asserted: 599/600, 1023/1024); `ResponsiveBuilder` rebuilds on width crossing via `LayoutBuilder`, calls the right lane, returns `childOf` result; builder result is the ONLY child (no wrappers). |
| T-2 | `ScreenScaffold` | Composition (no platform channels): SafeArea + `ScaffoldBackground` (b10 overlay, degrade-safe) + optional centered `maxContentWidth` (default 640, null = unconstrained) + optional bottom nav slot passthrough; body always rendered. |
| T-3 | `SectionHeader` | Title (w700) + optional action widget right-aligned; optional subtitle secondary-colored; pure layout, caller-supplied strings (L3); overlong title ellipsized. |
| T-4 | `AdaptiveRow` | `compact` → Column, `medium/expanded` → Row (spacing applied between children in both); children order preserved; breakpoint from the ambient width (ResponsiveBuilder), not MediaQuery hacks. |
| T-5 | `Gap` | `Gap.h(AppDimensions.paddingM)`-style constants: `Gap.h8/h16/h24`, `Gap.v8/v16/v24` (SizedBox delegates, exact extents asserted) + parameterized `Gap.h(n)/Gap.v(n)`. |

## §4 Deliverable

`tool_uilib/p14/p14_report.md` in the worktree per the p13 §4 pattern (six-way, UNVERIFIED non-empty allowed, DECISIONS, paste-ready `## APP COMPLETION UI-4 (p14)` block + per-worktree ledger append per 0.11).

## §5 Acceptance

- analyze --fatal-infos (core_ui) + dart analyze (core) exit 0 · format (repo root) 0 · core_ui suite **141 + new (≥ 25)** green 0 skip, existing tests untouched · coverage **100% lines per new file** · greps 0 · red→green receipt · after merge-back: full battery green on MERGED MAIN (staggered per 0.13).

## §6 Judge + close

Coordinator spot-checks ≥3 claims (T-1 exact bounds 599/600 + 1023/1024, T-2 maxContentWidth behavior, T-4 compact/medium flip), forbidden paths 0, ratifies merge-back; owns final ledger + push.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-4 (p14), layouts batch, in worktree <repo>-cline-2 (branch cline/task-2).
Read <repo>\WHITE_LABEL_p14_ui4_layouts.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + p11 laws L1-L5 + WL_BATCHES §3.5/§3.6.
1. SYNC (B-3): git -C <repo>-cline-2 merge main; cd <repo>-cline-2; flutter pub get. Record your anchor tip.
2. BLOCKER (B-4): flutter analyze --fatal-infos (core_ui) + dart analyze (core) + dart format check (root) + flutter test (core_ui, 141/141, 0 skip) — all green BEFORE any edit. (If p12/p13 already merged to main, the suite is 141+new — use the CURRENT main count, re-verify, record it.)
3. RED: test/ui4_layouts_batch_test.dart to the T-1..T-5 contract; capture failure to tool_uilib/p14/red_suite.txt.
4. GREEN: implement the five files; dart fix --apply; dart format; suite green 0 skip; analyze 0; coverage 100% new files; greps 0.
5. REPORT: tool_uilib/p14/p14_report.md per §4 + append the addendum to FIX_VERIFICATION_cline-task-2.md (0.11). NEVER touch main's FIX_VERIFICATION.md.
6. COMMIT (in the worktree): git add <territory files> && git commit -m "ui4(p14): layouts batch".
7. MERGE-BACK (0.12): re-sync; from <repo> (clean tree, anchor check) merge cline/task-2; barrel conflicts = UNION, alphabetized; other conflicts = abort + report; full battery on merged main (stagger — never concurrent with another window's battery); commit; push only if cached.
DoD: §5 green + report + per-worktree ledger + commit + merge-back battery green + nothing left uncommitted.
```

**END OF UI-4 SPEC.**

