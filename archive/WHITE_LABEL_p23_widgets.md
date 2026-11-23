# WHITE_LABEL_p23_widgets — UI-11: THE MISSING VISUAL-WIDGET FAMILIES (W-1..W-6) — MAIN, SINGLE EXECUTOR

**Purpose:** the coherence audit (`AUDIT_COHERENCE_LADDER.md` §3) proved the library is missing **six** component families that the *uncovered* surfaces hand-roll per screen (duplication the fleet exists to kill): `TipSelector` (96 hand-rolled lines), `OrderTimeline` (76), the chart family (200 + 184 app-side only), sheet/dialog wrappers (none), splash/onboarding shells (135 + 69), and staff data tables (kitchen 413 / manager 128 / dead-letter 124 hand-roll table-ish layouts). This wave builds them in `core_ui` under the **same fleet laws and the same 100% line-coverage bar** as UI-1..UI-5 — **library only**: adoption is `p21` (tip/timeline/splash/onboarding), `p22` (data table/sheet), `p17` (charts).
**Predecessors:** UI fleet `p11`–`p15` complete (library declared COMPLETE at `eb0589a`; 26 components, 100% line coverage, 13 goldens). This wave is **independent of p16** except for the exclusive-territory serialization (both write `packages/core_ui/lib/src/ui/**` — `p16` holds a seam right there until it merges).

## §0 Rules (inherited p10 §0 0.1–0.7 + **p11 laws L1–L5 verbatim**)

**L1** Consume the frozen token engine, never modify it (`AppShapeTokens`, `BrandColors.of`, ambient `ThemeData`/`ColorScheme`). **L2** Zero money math — `PriceTag`-class components format via `moneyCents` (display-only); a tip selector computes NOTHING (see L24). **L3** No hardcoded user-facing strings (caller-supplied only; a11y fallback constants per the GlobalErrorText precedent). **L4** No new dependencies (`pubspec.*` forbidden). **L5** Fail-safe cosmetic layers — decorative surfaces degrade, never throw.

### Widget-specific laws

**L24 TIP/GIFT NUMERIC LAW (money-adjacent, display-only).** `TipSelector` presents candidate percentages/amounts and returns the **caller's own selection** to the caller — it never multiplies, rounds, or formats money itself. If it renders a computed amount at all, that amount arrives as an **already-formatted string** from the caller (the app's money authority). Test: the selector's public API contains no arithmetic on cents; a mutation of any cents value it receives cannot change the string it displays.

**L25 SHEET/DIALOG BARRIER CONTRACT.** `BrandSheet`/`BrandDialog` wrap the framework primitives with brand tokens, `Semantics(scopesRoute)`, dismissal rules (barrier dismiss configurable, **default = non-dismissable for money-confirming sheets**), and a focus-safe `SafeArea` composition. They must NOT own business logic: no callbacks beyond `onConfirm`/`onCancel`, no state beyond visibility.

**L26 CHART HONESTY.** `BrandChart` renders data it is given and **computes nothing**; an empty series renders the library's `EmptyStateWidget` (never a fake axis); a single-point series renders without dividing by zero; all labels are caller-supplied. No chart may imply precision the data does not carry (no interpolated curves for discrete buckets — the existing app-side charts' semantics are the reference).

**L27 ADDITIVE-ONLY LIBRARY.** Frozen UI-1..UI-5 components and their goldens/tests are **not edited** by this wave except where a documented, receipted red→green seam is genuinely required (e.g. an enum value). The only unconditional edit permitted is adding export lines to the barrel (`packages/core_ui/lib/core_ui.dart`, currently **43** exports). Every new component gets its own file, test file, and goldens.

## §1 Baseline (P1 — measured at authoring)

- Library: 26 exported classes, barrel = **43** export lines (counted this session), 100% line coverage, `packages/core_ui` suite **+289** at the Stage-5 close (receipt: `AUDIT_TRIAGE_STAGE3.md` L372), 13 goldens (UI-5 proof).
- The six hand-rolled sources this wave supersedes (app-side; **left running until their adopting wave lands** — no big-bang deletion):
  `core_app/lib/features/checkout/presentation/tip_selector_widget.dart` (96) · `core_app/lib/features/orders/presentation/order_tracker_steps_widget.dart` (76) · `core_app/lib/features/admin/presentation/analytics/{revenue_chart_widget.dart 200, top_items_chart_widget.dart 184}` · `core_app/lib/features/splash/presentation/splash_screen.dart` (135) + `onboarding_screen.dart` (69) · staff table-ish layouts (`kitchen_dashboard.dart` 413, `manager_dashboard.dart` 128, `dead_letter_screen.dart` 124).
- Constraint from the coherence audit §4: any palette-adjacent work must keep `core_app/test/ui/accessibility_guidelines_test.dart:203-232` green (it asserts AA-passing palette values from BOTH client configs).

## §2 Territory (exclusive)

NEW: `packages/core_ui/lib/src/ui/**` — one file per component family (`segment_selector.dart`/`tip_selector.dart`, `order_timeline.dart`, `brand_chart.dart`, `brand_sheet.dart` + `brand_dialog.dart`, `branded_splash.dart` + `onboarding_shell.dart`, `brand_data_table.dart`) · `packages/core_ui/test/**` per-component tests + goldens · `tool_uilib/p23/**`
MODIFIED (minimal): `packages/core_ui/lib/core_ui.dart` — **export lines only** (append; never reorder or remove)
FORBIDDEN: `packages/core_ui/lib/src/theme/**` · any existing UI-1..UI-5 component file except a receipted red→green seam · `core_app/**` **entirely** (this is a library wave — adoption is p17/p21/p22) · `apps/**` · `FIX_VERIFICATION.md` · `pubspec.*`.

## §3 T-x table (each task: red→green receipt + goldens; commit per task; never end on red)

| Task | Component | Contract (the red tests that must fail first) | Acceptance |
|---|---|---|---|
| **T-1** | **W-1 `SegmentSelector` + `TipSelector`** (`segment_selector.dart`) | Generic N-option segmented control: selection owned by caller or internal (documented), disabled option, loading option, RTL-mirrored order, `Semantics(selected:)`, focus traversal. `TipSelector` = the money-facing preset (L24): percent presets + custom entry, returns a value; **no arithmetic**; displays caller-formatted strings. | selection callback with exact value; RTL golden; disabled/loading states; **L24 test** (mutating any cents it receives cannot change the string it displays — the string is caller-supplied); 100% lines; goldens (light/dark, en/ar). |
| **T-2** | **W-2 `OrderTimeline`** | Ordered step list with current/completed/future/error states, caller-supplied labels, optional timestamps, vertical + horizontal layouts, `Semantics` announcing the current step, **no timers** (pure presentation). | every state × layout covered; a11y announcement test; goldens; 100% lines. |
| **T-3** | **W-3 `BrandChart` family** | `bars` / `line` / `donut` over caller-supplied series; **L26**: empty => `EmptyStateWidget`; single point => no divide-by-zero; discrete buckets => no implied interpolation; token colors only; optional legend. | empty/single/multi series, label truncation, extreme values, RTL; goldens; 100% lines. |
| **T-4** | **W-4 `BrandSheet` + `BrandDialog`** | L25 barrier contract: branded header/actions, `SafeArea`, `Semantics(scopesRoute)`, configurable barrier dismiss (**money-confirming default = non-dismissable**), scroll-safe content, `onConfirm`/`onCancel` only. | dismiss rules per config; focus containment; scroll overflow; goldens; 100% lines. |
| **T-5** | **W-5 `BrandedSplash` + `OnboardingShell`** | Splash: logo/name/loader slots driven by tokens, no business logic, reduced-motion aware. Onboarding: N-page shell with pager, skip/next/done, dots indicator, caller-supplied page content, `Semantics` page announcements. | page advance/back, skip, reduced-motion, first/last page affordances; goldens (en/ar); 100% lines. |
| **T-6** | **W-6 `BrandDataTable`** | Declarative column model (label, flex, alignment, cell builder), dense/comfortable density presets (**an INTERACTIVE cell keeps the >=48 dp target even in dense**), sticky header, empty/loading states, horizontal scroll for many columns, `Semantics` header association. | density presets; empty/loading; overflow scroll; header a11y; goldens; 100% lines. |
| **T-7** | **Proof + close** | Barrel export audit (43 => 43 + 6 families, append-only); coverage 100% per new file; the L24 mutation receipt; library suite green with **0 skips**. | `p23_report.md` §4; every §5 item green. |

## §4 Deliverable

`tool_uilib/p23/p23_report.md`: per-component contract table with red→green receipts (the **red run captured before each implementation**); the L24 mutation-test receipt; barrel diff proof (append-only); per-file coverage table (100% line); golden inventory; six-way classification; **DECISIONS-NEEDED-FROM-OWNER = the CONSUMER CONTRACT** (the API shapes p17/p21/p22 will adopt — those waves read this section before dispatch); UNVERIFIED (non-empty allowed); DRIFT; handoff table; paste-ready `## APP COMPLETION UI-11 (p23)` block.

## §5 Acceptance

- `flutter analyze --fatal-infos` (core_ui) exit 0 · `dart format` 0 changed · `packages/core_ui` suite green **0 skip**, no drop vs the recorded baseline (receipt: **+289** at the Stage-5 close, `AUDIT_TRIAGE_STAGE3.md` L372/L406) and strictly greater after the new tests.
- **100% line coverage** on every new file (the UI-1..UI-5 bar); core_ui aggregate stays at 100% for fleet files.
- Barrel diff = **append-only export lines** (receipt: `git diff` of `core_ui.dart`, 43 exports at dispatch).
- Zero edits under `core_app/**` and `apps/**` (`git status` proof) — this wave ships library code only.
- The library-touching a11y/ban/l10n gates stay green.

## §6 Judge + close

Coordinator re-runs the battery; spot-checks ≥3 (the L24 mutation test, the empty-series chart behaviour, the non-dismissable money-confirming sheet default); appends the ledger block. **This wave closes register row `F3-13`** (`showModalBottomSheet` 4 sites / 1 screen with **no** barrel counterpart — `BrandSheet` absent; register L75, re-verified by the Stage-5 auditor at L406) **and supplies the components `p21` (M-1 tip, M-2 splash/onboarding, M-8 timeline), `p22` (M-7 tables/sheets) and `p17` (charts) adopt.**

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-11 (p23), THE MISSING VISUAL-WIDGET FAMILIES (W-1..W-6), MAIN ONLY — LIBRARY ONLY.
Read <repo>\WHITE_LABEL_p23_widgets.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + p11 L1-L5 + L24-L27.
Predecessor: p16 merged (it holds a seam right in the same ui/** directory until then).
1. SYNC (fail-closed): tracked tree clean; record tip + packages/core_ui suite count (+289 baseline) + barrel export count (43) + coverage. BLOCKER: analyze + format + core_ui suite green 0 skip BEFORE any edit. Failure => STOP.
2. RED per task (T-1..T-6): write each component's contract tests FIRST; capture the failing run to tool_uilib/p23/red_<component>.txt.
3. GREEN in order W-1 segment/tip -> W-2 timeline -> W-3 charts -> W-4 sheet/dialog -> W-5 splash/onboarding -> W-6 data table.
   L24: the tip selector performs NO arithmetic and displays caller-formatted strings (prove it with the mutation test).
   L26: empty chart => EmptyStateWidget; single point => no divide-by-zero; no implied interpolation.
   L25: money-confirming sheets are non-dismissable by default.
   Commit after EACH component; never end on red.
4. L27 ADDITIVE-ONLY: do not touch frozen UI-1..UI-5 files; the only unconditional edit is APPENDING export lines to core_ui.dart.
5. GATES: analyze (core_ui) + format 0 + core_ui suite 0 skip no drop + 100% line coverage on every new file + barrel append-only diff + ZERO edits under core_app/** and apps/**.
6. REPORT: tool_uilib/p23/p23_report.md per §4 (contracts, red receipts, L24 receipt, barrel diff, coverage table, goldens, six-way, DECISIONS as the CONSUMER CONTRACT for p17/p21/p22, UNVERIFIED, DRIFT, handoff, paste-ready UI-11 ledger block). NEVER touch FIX_VERIFICATION.md.
7. COMMIT final + battery on the tip; push only if credentials are cached.
DoD: §5 green + report + receipts + green committed tip + nothing uncommitted.
```

**END OF UI-11 SPEC — the six missing families, built before their adopters dispatch.**
