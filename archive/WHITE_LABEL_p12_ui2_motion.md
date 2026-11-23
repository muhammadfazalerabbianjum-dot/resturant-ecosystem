# WHITE_LABEL_p12_ui2_motion — UI-2: ANIMATIONS / MOTION — SINGLE EXECUTOR

**Fleet:** p11 shapes (DONE, `b024e82`) → **p12 motion** → p13 tiles → p14 layouts → p15 proof. Same contract pattern as `WHITE_LABEL_p11_ui1_shapes.md`; inherits `WHITE_LABEL_p10_t78.md` §0 where applicable. Post-freeze context: additive capability in `packages/core_ui` only — MUST NOT weaken any frozen surface.

## §0 Rules (binding)

0.1 **Proof law.** Every claim carries P1 (file:line opened this session) or P2 (a test that fails if false). No-receipt claims go in a mandatory non-empty UNVERIFIED section.
0.2 **No fake green.** No `@Skip`/`skip:`/TODO-as-done/`expect(true)`. Red→green: the contract suite is captured FAILING in `tool_uilib/p12/red_suite.txt` BEFORE the first component file exists.
0.3 **Blocker behavior is canonical.** Baseline (§1) not green, or spec-vs-code conflict → STOP, change nothing, report with an evidence table.
0.4 **The executor NEVER touches `FIX_VERIFICATION.md`.** Deliverables: receipts under `tool_uilib/p12/` + a paste-ready `## APP COMPLETION UI-2 …` ledger block. Single-writer ledger stays with the coordinator.
0.5 **Territory exclusivity (§2).** Cross-territory findings = handoff notes. Drive-by fixes prohibited.
0.6 **Do not re-derive receipted facts.** Cite `LEDGER:PERF-10` / `DEEP_PROOF.md` / `tool_uilib/p11/p11_report.md` for established facts.
0.7 **Baseline discipline.** Tip must be `b024e82` (UI-1 close), tree clean, blocker gate green BEFORE any edit.
0.8 **Owner is present.** Fail-safe defaults recorded in DECISIONS-NEEDED-FROM-OWNER. Standing defaults: `Brand*` naming (ratified by precedent + SDK-collision lesson); main-tree single-writer session; push/ledger close-out stays with the coordinator.

### Batch laws (UI-motion-specific, additive to §0)

L1 **Consume the frozen token engine, never modify it.** `AppMotionTokens` (b10: style full/subtle/none, fast 200/standard 300/slow 500, `Curves.easeOut`) and `AppShapeTokens` are READ-only — `packages/core_ui/lib/src/theme/**` is out of territory, full stop.
L2 **Zero money math.** `AnimatedCountText` animates a DISPLAYED integer and formats each frame exclusively through `moneyCents` (display-only money law, LEDGER:PERF-10). No arithmetic beyond the tween itself.
L3 **No hardcoded user-facing strings.** All visible text caller-supplied; a11y fallback constants follow the GlobalErrorWidget documented pattern only where unavoidable (none expected this batch).
L4 **No new dependencies.** flutter/material + existing package imports only; `pubspec.*` forbidden.
L5 **Fail-safe cosmetic layers.** Motion is decorative: a missing token, a zero duration, or a `none` style must degrade to the correct final visual state — never throw, never leave content invisible.
L6 **The motion contract (this batch's core law).** Every animated component resolves `AppMotionTokens` from the ambient theme and honors `style`: `full` = documented preset, `subtle` = the b10 subtle preset, `none` = instant final state with NO controller churn (accessibility + per-client config). Tests assert all three styles where behavior differs.
L7 **No haptics in motion wrappers.** `PressableScale` is a pure transform wrapper — callers (e.g. `BrandButton`) already own haptics; wrapping must never double-fire.
L8 **Deterministic animation tests.** Explicit `tester.pump(duration)` steps against the token durations; no unbounded `pumpAndSettle` reliance, no wall-clock dependence.

## §1 Baseline (UI-1 close)

- Tip `b024e82` = main (UI-1 commit); tree clean except pre-existing untracked receipts.
- Gates at baseline: core_ui **141** green (0 skip) · analyze exit 0 (core_ui + core) · format 0 changed · coverage **100% lines** on the 10 UI-1 files (`tool_uilib/p11/coverage.txt`).
- Frozen inputs (P1, opened prior session): `app_tokens.dart` `AppMotionTokens` (+`forStyle` presets, lerp contract), `transitions.dart` (300 ms / `Curves.easeOut` / `Offset(0, 0.05)` shared baseline), `brand_colors.dart`, `money_text.dart`.

## §2 Territory (exclusive)

NEW: `packages/core_ui/lib/src/ui/{pressable_scale,fade_slide_in,staggered_entrance,animated_count_text,animated_visibility}.dart`
MODIFIED (named): `packages/core_ui/lib/src/ui/transitions.dart` (additive optional `motion` seam; legacy default byte-identical) · `packages/core_ui/lib/core_ui.dart` (additive export lines ONLY)
NEW: `packages/core_ui/test/ui2_motion_batch_test.dart` · `tool_uilib/p12/**`
FORBIDDEN everywhere: `FIX_VERIFICATION.md`, `DECISIONS_LOG.md`, `packages/core_ui/lib/src/theme/**`, existing `packages/core_ui/test/*` files, `pubspec.*`, `packages/core/**`, `core_app/**`, `apps/**`, `functions/**`, generated files, lockfiles.

## §3 Problems → Acceptance → T-x table

| Task | Component | Acceptance (all red→green, 100%-line coverage target on new files) |
|---|---|---|
| T-1 | `PressableScale` (`pressable_scale.dart`) | Press → scale 0.96 (BrandButton precedent) over `motion.fast` w/ `motion.curve`; release/cancel → back to 1.0; `style: none` → no controller, no transform, tap still fires; pure wrapper (L7 — no haptics); optional `onTap` forwarded exactly once; child semantics untouched. |
| T-2 | `FadeSlideIn` (`fade_slide_in.dart`) | Entrance fade 0→1 + slide from `Offset(0, 0.05)` (the shared baseline) to zero over `motion.standard`; auto-plays on mount; `style: none` → final state rendered immediately; no overlay/opacity residue after settle. |
| T-3 | `StaggeredEntrance` (`staggered_entrance.dart`) | N children enter with per-index delay `index * stagger` (default 60 ms, scaled by style); order preserved; `style: none` → all children final state immediately. |
| T-4 | `AnimatedCountText` (`animated_count_text.dart`) | Animates the displayed integer previous→new over `motion.standard`; every rendered frame formatted through `moneyCents` (L2); currency config forwarded; `style: none` → jumps to the new value; deterministic explicit-pump tests (L8). |
| T-5 | `AnimatedVisibility` (`animated_visibility.dart`) | `visible` flag fades opacity 1↔0 over `motion.standard`; hidden state = `IgnorePointer` + offstage after settle (findable only with `skipOffstage: false`); `style: none` → instant; content never interactive while hidden. |
| T-6 | `transitions.dart` motion seam | `FadeSlideTransitionPage` gains an OPTIONAL `motion` parameter: supplied → `transitionDuration` = `motion.standard`, curve = `motion.curve`; omitted → byte-identical legacy behavior (300 ms / `Curves.easeOut` / `Offset(0, 0.05)`), asserted. No core_app router changes (out of territory). |

## §4 Deliverable format

`tool_uilib/p12/p12_report.md`: phase summary; per-T evidence; six-way classification (Verified / Unverified / Anomalies / Untested / Risks / Recommendations); honest residuals; **DECISIONS-NEEDED-FROM-OWNER**; **UNVERIFIED** (mandatory, non-empty allowed); DRIFT; paste-ready `## APP COMPLETION UI-2 (p12) - … - VERIFICATION REPORT` block.

## §5 Acceptance

- `flutter analyze --fatal-infos` (core_ui) exit 0 · `dart analyze` (core) exit 0 · `dart format --output=none --set-exit-if-changed .` (repo root) exit 0.
- core_ui suite: **141 + new (≥ 35)** green, 0 fail, **0 skip**; existing 141 tests untouched (no weakening — the T-6 legacy assertions included).
- Coverage: **100% lines per NEW component file**; `transitions.dart` coverage must not drop.
- Greps in new code: `TODO|FIXME|@Skip|skip:|expect(true` → **0**.
- Red→green: `tool_uilib/p12/red_suite.txt` + green receipts.
- `core_app`, shell, packages/core: untouched (git status proves 0).
- Mutation gate: **N/A for this batch** — no money/auth path touched (METHOD §4 mutation applies to named money-path logic; `AnimatedCountText` tween + `moneyCents` delegation is display-only; recorded in the report).

## §6 Coordinator protocol

Judge re-runs all §5 gates personally; spot-check ≥3 claims (T-6 legacy default identity, T-4 `none`-style jump, T-5 hidden-state non-interactivity); verify forbidden paths 0 via `git status`/`git diff --stat`; commit; append the ledger block verbatim; only then dispatch UI-3 (p13) on owner approval.

## §7 Executor quickstart (paste-ready)

```
You are the SINGLE EXECUTOR of UI-2 (p12), the motion/animations batch of the UI expansion fleet.
Working tree: <repo> (main). Read <repo>\WHITE_LABEL_p12_ui2_motion.md IN FULL — it is the binding contract.
1. SYNC: git log -1 == b024e82; tree clean except pre-existing untracked tool_perf2/** and tool_uilib receipts.
2. BLOCKER: flutter analyze --fatal-infos (core_ui) + dart analyze (core) + dart format check (repo root) + flutter test (core_ui, 141/141, 0 skip) — all green BEFORE any edit.
3. RED: write test/ui2_motion_batch_test.dart to the T-1..T-6 contract; run; capture the failure to tool_uilib/p12/red_suite.txt.
4. GREEN: implement the five new components (T-1..T-5) + the transitions.dart motion seam (T-6); dart fix --apply; dart format; suite green 0 skip; analyze 0.
5. COVERAGE: flutter test --coverage; parse lcov for the 5 new files (100% lines) + transitions.dart (no drop).
6. GREPS: TODO|FIXME|@Skip|skip:|expect(true = 0 in new code.
7. REPORT: tool_uilib/p12/p12_report.md per §4 (six-way, UNVERIFIED non-empty, DECISIONS, paste-ready ledger block).
Forbidden: FIX_VERIFICATION.md, theme/** (AppMotionTokens READ-only), pubspec.*, existing tests, core_app/**, apps/**, functions/**, packages/core/**.
Definition of done: every §5 item green + receipts committed + nothing left uncommitted.
```

**END OF UI-2 SPEC.**

