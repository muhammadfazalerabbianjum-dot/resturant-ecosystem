# WHITE_LABEL_p16_adoption1 — UI-6: LIBRARY ADOPTION WAVE 1 (customer core) — MAIN, SINGLE EXECUTOR

**Purpose:** wire the 26-component library into the customer-facing core (menu + dish detail + home + cart) so clients SEE it. **Owner-authorized freeze-lift for UI presentation only** — this wave changes PRESENTATION, never logic, never money math, never backend. Admin/staff screens = a later wave (p17 candidate), deliberately out of scope.

**Predecessors:** UI fleet p11–p15 DONE + declared UI LIBRARY COMPLETE at `eb0589a` (LEDGER). Baseline tip: **`de6c636`+** = record at SYNC; suite counts recorded at dispatch.

## §0 Rules (binding — inherited p10 §0 0.1–0.7 + p11 laws L1–L5)

0.8 **Main-only, single executor.** 0.9 **Read-mostly:** `packages/core_ui/**` changes ONLY as documented red→green fallout (e.g. an additive `MenuTile` seam), never rewrites of frozen components. 0.10 **Presentation-only:** no changes to providers/logic (`*_provider.dart`), money computation, Firebase calls, routes; presentation files only, named in §2.

### Batch laws (adoption-specific)

L12 **THE VISUAL FLOOR (owner requirement: maximum visual appeal — operationalized, judged not asserted — externally grounded, §1b).** Every wired surface satisfies ALL of: (1) zero hardcoded colors — `app_colors_theme_ban_test.dart` stays green, everything via ambient theme/`BrandColors.of`; (2) spacing via `Gap`/`AppDimensions` at every touched seam (no new magic numbers); (3) every list/grid keeps an entrance motion (adopt `StaggeredEntrance`/`FadeSlideIn` OR preserve the existing `flutter_animate` stagger — visibly equivalent or better, durations within the M3 short/medium scale); (4) every async surface shows its skeleton state; (5) **touch targets ≥ 48×48 dp with ≥ 8 dp separation** (Google Accessibility Help: "at least 48dp … separated by 8dp of space or more"; WCAG 2.5.8 AA floor = 24×24 CSS px, AAA 2.5.5 = 44×44 — we exceed both); (6) **before/after golden pairs** captured per wired screen into `tool_uilib/p16/visual_review/` — the OWNER reviews the pairs and approves the look; "appeal" is an owner verdict on evidence, not an executor claim.
L13 **MONEY DISPLAY PARITY (the researched trap).** RESEARCH FINDING (P1): `core_app/lib/app/config/currency_format.dart:27-28` delegates to the single rule set `moneyCents` (`packages/core_ui/lib/src/ui/money_text.dart:89`), so the audited divergence is gone: known codes agree on positive values (`$12.50`) and negatives/unknown codes render once, CLDR-style (`-$1.50`, `CODE `). Rule: positive/known-code prices must remain **byte-identical** after wiring; any negative/unknown divergence introduced by `PriceTag` is a recorded DECISION-NEEDED-FROM-OWNER with before/after goldens — never silent. Pass `currencySymbolFor(code)` explicitly where needed to preserve the `$` fallback. Zero arithmetic changes; `PriceTag` stays display-only.
L14 **BEHAVIOR PRESERVATION.** All existing suites stay green with no weakening (feature/COV suites, W9 a11y suite, l10n en+ar parity). Preserved verbatim or improved: `Semantics` labels (menu rows carry a composed label — keep it), `Hero` tags on dish images, Cloudinary thumbnail URLs (`cloudinaryThumb`), add-to-cart flow (haptic + snackbar), sold-out states, search behavior, `ClampedTextScale`. l10n: all visible strings stay caller-supplied via `AppLocalizations`.
L15 **No new dependencies** (`flutter_animate`, `cached_network_image` already sanctioned; library motion may replace hand-rolled animate chains where visibly equivalent).

## §1 Research findings (all P1, opened this session — the proven premises)

1. **Targets confirmed:** `menu_screen.dart` builds hand-rolled `ListTile` rows (`:176-310`): 50 px Cloudinary thumb + `Hero`, title, price as a plain subtitle via `formatCurrencyCents`, sold-out-aware add-to-cart `IconButton` (haptic + snackbar), composed `Semantics` label, staggered `.animate().fade()` entrance, `SkeletonLoader.listTile()` loading, empty-category plain `Text`. This is exactly what `MenuTile`+`PriceTag` replace — with every listed behavior preserved (L14).
2. **The money trap (L13):** two formatters, divergent edge behavior (finding above). Any wiring that swaps formatters silently would visibly change negatives/unknown codes.
3. **Variant registry is real and validated** (`screen_variants.dart:20-60`): `HomeScreen` ∈ {`grid`, `showcase`}, fail-closed validator, byte-for-byte default. Home wiring must keep BOTH variants rendering and re-golden each (`home_feed_showcase.dart` exists at 7.3 KB).
4. **Clients already differ by theme** (parsed both configs): core_app orange `0xFFC84F00`/System; halal_boyz maroon `0xFF900000`/Playfair — wiring is theme-neutral, so both clients inherit the new look through their own tokens.
5. **Infra in place:** 19 feature dirs; 23 files already import `core_ui`; `app_colors_theme_ban_test.dart` active; 27 goldens corpus (re-capture discipline = b10 precedent); sanctioned deps present.

## §1b External research (credible primary sources, fetched this session — what the design decisions stand on)

| Claim in this spec | Source (primary) | Verified quote/finding |
|---|---|---|
| Touch targets ≥ 48×48 dp, ≥ 8 dp apart (L12.5) | **Google Android Accessibility Help** — "Touch target size" (support.google.com/accessibility/android/answer/7101858) | "Any on-screen element that someone can click, touch, or otherwise interact with should be large enough… at least **48dp**, as described in the Material Design Accessibility guidelines" · "Consider making touch targets at least **48x48dp, separated by 8dp of space or more**" · "A touch target of 48x48dp results in a physical size of about **9mm**… The recommended target size for touchscreen objects is **7-10mm**." |
| Accessibility floor beneath that (L12.5) | **W3C WCAG 2.2, SC 2.5.8 Target Size (Minimum), Level AA** (w3.org/WAI/WCAG22/Understanding/target-size-minimum) | "The size of the target for pointer inputs is at least **24 by 24 CSS pixels**", with a spacing exception (24px circles must not intersect); "using larger target sizes will help many people"; AAA (2.5.5 Target Size Enhanced) is the stricter 44×44 target — our 48 dp exceeds both. |
| Motion durations/curve (L12.3, b10 tokens) | **material-components-android, docs/theming/Motion.md** (the M3 motion reference implementation) | MaterialFadeThrough duration = `motionDurationLong1` = **300 ms**, easing `cubic-bezier(0.4, 0.0, 0.2, 1)` (**FastOutSlowIn/standard**); MaterialFade = short2 150 ms in / short1 75 ms out. Our b10 `AppMotionTokens` (fast 200 / **standard 300** / slow 500) sit exactly on the M3 duration scale — entrance motion adoption stays within the Material motion system. |
| Negative-currency display (L13) | **Unicode CLDR — Number and currency patterns** (cldr.unicode.org/translation/number-currency-formats/number-and-currency-patterns) | Currency patterns use `¤` for the symbol position and a **semicolon-separated negative sub-pattern** (e.g. `#,##0.00¤;…-¤…`), i.e. the standard negative form places the minus **before the currency symbol** → standard en-US negative = **`-$1.50`**. Therefore `moneyCents`' form is CLDR-conformant and `formatCurrencyCents`' `$-1.50` is NOT — adopting `PriceTag` is a **conformance improvement**, recorded via L13's DECISIONS path with before/after goldens (still never silent). |

*(All four fetched this session; the quotes are the load-bearing external premises. Anything the executor needs beyond these is a STOP-and-report, not an assumption.)*

## §2 Territory (exclusive)

MODIFIED (presentation only): `core_app/lib/features/menu/presentation/{menu_screen,dish_detail_screen}.dart` · `core_app/lib/features/home/presentation/home_screen.dart` (+`home_feed_showcase.dart` only as the variant requires) · `core_app/lib/features/cart/presentation/cart_screen.dart`
MODIFIED (additive fallout only, red→green receipted): `packages/core_ui/lib/src/ui/**` seams (e.g. `MenuTile` image/hero seam) + their tests · additive export lines if a seam is public
NEW: tests under `core_app/test/` (named per phase) · golden re-captures under the existing golden dirs · `tool_uilib/p16/**`
FORBIDDEN: `*_provider.dart` and all logic files · `packages/core_ui/lib/src/theme/**` · `FIX_VERIFICATION.md` · `pubspec.*` · `functions/**` · rules · `apps/**` (regenerate via generator if a config mirror is needed — mirror rule) · admin/driver/kitchen feature dirs (later wave).

## §3 Phases → T-x table (each phase: red→green receipt + goldens; commit per phase, never end on red)

| Phase | Tasks | Acceptance |
|---|---|---|
| **A — menu** | A1: menu rows → `MenuTile` (preserving Hero/Cloudinary thumb, Semantics label, sold-out gating, add-to-cart haptic+snackbar; add the `MenuTile` image/hero seam in core_ui ONLY if needed — additive, receipted). A2: prices → `PriceTag` (L13 parity test: rendered string == `formatCurrencyCents` for the active currency across the supported code set — test written red→green). A3: entrance → `StaggeredEntrance` or preserved animate-stagger. A4: empty-category state → `EmptyStateWidget`. | menu feature tests green; parity test green; goldens before/after pair; l10n untouched. |
| **B — dish detail** | B1: price → `PriceTag(large: true)`. B2: quantity picker → `QuantityStepper` (bounds behavior preserved; existing add-to-cart semantics kept). B3: informational/allergen notices → `InfoBanner` (tone mapping explicit; strings caller-supplied). | dish-detail tests green; goldens pair; a11y intact. |
| **C — home** | C1: feed cards → `BrandCard`-based composition (or `MenuTile` where the content is a dish). C2: feed sections → `SectionHeader`. C3: BOTH variants (`grid` default + `showcase`) re-rendered and re-goldened — the variant registry contract (`screen_variants.dart`) must keep working byte-for-byte for configs without variant keys. | home tests green (both variants); goldens pairs ×2 variants. |
| **D — cart** | D1: line-item rows → tile composition (name, `PriceTag` per line, `QuantityStepper` per line where quantity editing lives — presentation only, provider untouched). D2: totals/subtotal displays → `PriceTag` with L13 parity (totals are derived in providers — NOT recomputed; display-only). D3: empty cart → `EmptyStateWidget`. | cart tests green (money assertions untouched — display parity proven); goldens pair. |
| **E — close** | E1: full battery (analyze ×2, format, core_app + core + core_ui suites, rules/functions untouched-verification via git). E2: golden re-capture inventory + the visual-review pack (before/after pairs) for owner approval. E3: coverage: core_ui stays 100% × 26 (+ any seam); core_app aggregate no drop vs recorded baseline. E4: report §4. | every §5 item green. |

## §4 Deliverable

`tool_uilib/p16/p16_report.md`: phase summaries; per-T evidence; the visual-review pack index (before/after golden pairs per screen); six-way classification; DECISIONS-NEEDED-FROM-OWNER (esp. L13 divergences); UNVERIFIED (non-empty allowed); DRIFT; paste-ready `## APP COMPLETION UI-6 (p16)` block.

## §5 Acceptance

- `flutter analyze --fatal-infos` (core_app + core_ui) · `dart analyze` (core) — all exit 0 · `dart format` root 0 changed.
- Suites: core_app + core + core_ui + shell + rules + functions — all green, **0 skip**, counts recorded at SYNC with **no drop**; existing feature tests untouched in assertions (only presentation wiring may require mechanical updates where a widget type changed — each such edit receipted).
- l10n en+ar parity green · W9 a11y suite green · ban test green.
- Coverage: core_ui 100% × 26 maintained; core_app aggregate ≥ recorded baseline.
- Goldens: every changed visual re-captured deliberately (list in report); NO golden re-captured to force a green without a recorded visual-decision entry.
- `git status` proves zero forbidden paths.

## §6 Judge + close

Coordinator re-runs the battery; reviews the visual-review pack WITH the owner (the appeal verdict is the owner's); spot-checks ≥3 claims (A2 parity test, C3 both-variant goldens, D2 display-only totals); appends the ledger block; owner approves the new look → wave closed. Further adoption waves (admin/staff, remaining features) dispatch separately.

## §7 Executor quickstart

```
You are the SINGLE EXECUTOR of UI-6 (p16), ADOPTION WAVE 1 (customer core: menu, dish detail, home, cart), MAIN ONLY.
Read <repo>\WHITE_LABEL_p16_adoption1.md IN FULL — binding contract. Inherits p10 §0 0.1-0.7 + p11 L1-L5 + §0.8-0.10 + L12-L15.
1. SYNC (fail-closed): cd <repo>; tracked tree clean; record main tip + suite counts (core_app/core/core_ui, 0 skip). BLOCKER: analyze x2 + dart analyze (core) + format + all suites green BEFORE any edit. Failure => STOP, evidence table.
2. RED per phase: write the phase's tests FIRST (menu parity test A2 is mandatory and must fail before wiring), capture to tool_uilib/p16/red_phase<X>.txt.
3. GREEN per phase: wire per §3 (A menu -> B dish detail -> C home -> D cart); commit after EACH phase; never end a phase on red.
4. VISUAL FLOOR (L12) at every touched seam: token colors only, Gap spacing, entrance motion, skeletons, 48dp targets, before/after golden pairs into tool_uilib/p16/visual_review/.
5. MONEY PARITY (L13): A2/D2 parity tests green; any negative/unknown divergence => DECISIONS entry + goldens, never silent.
6. GATES (E1): analyze x2 + dart analyze core + format + ALL suites (core_app, core, core_ui, shell, rules, functions) green 0 skip; l10n + a11y + ban tests green; coverage floors held.
7. REPORT: tool_uilib/p16/p16_report.md per §4 (visual-review pack index, six-way, UNVERIFIED non-empty allowed, DECISIONS, DRIFT, paste-ready UI-6 ledger block). NEVER touch FIX_VERIFICATION.md.
8. COMMIT final + push only if credentials cached; owner reviews the visual pack before the wave is judged closed.
DoD: every §5 item green + visual pack ready for owner review + receipts committed + nothing left uncommitted.
```

**END OF UI-6 SPEC — adoption wave 1.**