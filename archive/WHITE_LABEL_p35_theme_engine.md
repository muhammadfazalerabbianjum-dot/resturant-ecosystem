# WHITE-LABEL p35 — THEME ENGINE V2 (SCOPE A: VISUAL-PERFECTION FOUNDATION)

Status: SPEC (owner-approved, 2026-10-14; scope revised after an `impeccable` UI audit) —
design locked, build approved, executing TDD (Law 2).
Registry row: `WHITE_LABEL_p35_theme_engine.md` / THEME-V2 — previously "SPEC PENDING (owner scope pick)".
Branch: `cline/p32-golden-gates`. Base: current tip.

## 0. Why this scope (the audit's verdict)

An `impeccable` pass over the shipped UI (token layer, shapes, colors, flagship
components, home screen) scored the **foundation 8.5/10 — premium-grade, not the
problem.** The block on "perfect, distinct per-client UI" is **thin differentiation
levers**, not weak craft. Typography (Outfit + Montserrat), enforced token discipline
(`BrandColors` ThemeExtension + repo color-ban test), AA-contrast auto-foreground, and a
real motion system already ship. The gaps that actually gate "perfect":

1. **No written DESIGN.md** — "perfect UI" is implicit in code; a per-client
   *visual-truth doc* is what makes rebrands mistake-proof (the owner's core goal).
2. **Spacing is ad-hoc** — `AppDimensions` has 3 constants; components hardcode
   `12/2/6/16` inline (menu_tile, brand_card). No scale = inconsistent rhythm.
3. **No single shape/form preset** — the shape vocabulary (small/medium/large/pill)
   exists but isn't wired to ONE config key. The owner's "circular" ask = a global
   `sharp|soft|round|pill` preset.

Scope A builds the **visual-perfection foundation** for these three, TDD-first, each
committed. The earlier nav/preset scope is NOT dropped — it moves to §7 deferrals
(p35-B nav "5+More", p35-C preset gallery) because nav is *functional*, while these are
the *visual* levers the owner is actually asking about.

## 0.2 Scope, and what is explicitly NOT in this batch

**In scope A:**
- **V1 — `DESIGN.md`**: written visual truth + per-client style guardrail (docs, zero risk).
- **V2 — `AppSpacing` token scale** (`xs=4 sm=8 md=12 lg=16 xl=24 xxl=32`) as a
  `ThemeExtension` (b10 single-parse pattern). Additive; the go-forward standard.
- **V3 — `theme.shape.style` preset** (`sharp|soft|round|pill`): ONE key that sets
  card/cta/small/input/chip radii together. Net-new config path (no golden baseline
  exists for an opted-in preset); absent key = today byte-for-byte.
- **V4 — Generator + gate parity**: mirror new keys in generator `validate()` + schema-
  identity test; W6.5 gate; branding map + CHANGELOG (Law 19).

**Out of scope A (recorded, not silently dropped → §7):**
- **Full spacing migration** of all 42 components: snapping legacy `2`/`6` literals to
  the scale changes pixels → golden drift (Law 17). Separate, owner-approved golden-
  regeneration batch (p35-B.1), NOT bundled here.
- Nav "5+More" overflow (p35-B.2) and the F2.0 nav-truthfulness fix.
- Preset/font gallery bundle (p35-C).
- `ScreenVariants` catalog beyond HomeScreen (layout-variant epic, p35-D).
- Signature-style gallery beyond `rule`.

## 1. Current state — PROVEN facts (read from source this session)

- **Shape tokens** (`packages/core_ui/lib/src/theme/app_tokens.dart`): `AppShapeTokens`
  ThemeExtension = `cardRadius` (default 16), `ctaRadius` (null = Material default),
  `smallRadius` (null). Validated in `client_config.dart`. Component themes attach ONLY
  when the key is present (absent = Material 3 default = today).
- **Shape fallback vocab** (`shapes.dart`): `BrandShapes.small=8 medium=12 large=16
  pill=999` + `borderSmall/Medium/Large/Pill`, `tileShape`, `stadium`, `outlinedMedium`.
- **Spacing today** (`app_dimensions.dart`): only `paddingS=8, paddingM=16, radiusM=12`.
  Components hardcode inline: menu_tile `all(12)`, `SizedBox(width:12/height:2/height:6)`;
  brand_card default `all(16)`; brand_button `SizedBox(width:8)`.
- **Motion** (`AppMotionTokens`): `theme.animationStyle` ∈ {full,subtle,none} already ships.
- **Screen variants** (`screen_variants.dart`): catalog = {HomeScreen:{grid,showcase}},
  fail-closed W6.5, mirrored in generator `validate()`, pinned by
  `whitelabel_schema_identity_test.dart`.
- **Fonts**: `theme.typography.{headingFont,bodyFont}` = raw GoogleFonts strings (no preset).

## 2. Feature V1 — `DESIGN.md` (the guardrail)

Location: repo root `DESIGN.md` (the impeccable "visual authority" artifact; PRODUCT.md
is out of scope — this is a scoped review, not `init`). Contents:
- The intended aesthetic in words (Tier-1 SaaS, warm, geometric, AA-clean).
- The typography system (Outfit display/body + Montserrat for buttons/labels; the
  letter-spacing/height rules from `app_theme.dart`).
- The **spacing scale** (V2 values) as the single rhythm standard.
- The **shape language** (V3 presets + the `BrandShapes` fallback vocab).
- Color usage (only `BrandColors.of`; `theme.colors.*`; top-level `theme.primary` ignored).
- Motion (`animationStyle`), iconography, splash.
- **The per-client guardrail**: the change-point map (what a client edits vs what is
  code), pointing at `GENERATOR_BRANDING_MAP.md`. This is the "no mistakes ever" artifact.

## 3. Feature V2 — `AppSpacing` token scale

- New `AppSpacing extends ThemeExtension<AppSpacing>` in `app_tokens.dart` (b10 pattern):
  `xs=4 sm=8 md=12 lg=16 xl=24 xxl=32`, all `const`, proper `copyWith`/`lerp`/`==`/`hashCode`.
- Resolved by `AppTheme` builders (attached like the other token extensions).
- **Additive + safe:** NO existing component is migrated in scope A (that snaps pixels →
  golden drift; deferred to p35-B.1). V2 = introduce the scale + prove it reads from theme.
  New code (incl. V3 preset docs) references it as the standard.

## 4. Feature V3 — `theme.shape.style` preset (the "circular" ask)

- New optional config key `theme.shape.style` ∈ {`sharp`,`soft`,`round`,`pill`},
  validated fail-closed (W6.5 + generator `validate()` mirror + schema-identity test).
- Resolution (pinned by test): `theme.shape.style` preset sets card/cta/small/input/chip
  radii together; an **explicit** per-key token (`theme.shape.cardRadius` etc.) OVERRIDES
  the preset (preset < explicit, deterministic); **absent `style` = today byte-for-byte**.
- Curated values (tasteful; the mechanism is the deliverable):
  - `sharp`: card 4, cta 4, small 4, input 4, chip 4 — crisp/modern
  - `soft`  (today's warm baseline): card 16, cta 12, small 8, input 12, chip 8
  - `round`: card 24, cta 20, small 12, input 16, chip 16 — friendly
  - `pill` : card 28, cta 999 (stadium), small 999, input 999, chip 999 — fully rounded
- Net-new path: an opted-in preset has no existing golden baseline; the DEFAULT (no
  `style` key) preserves today, so goldens do not drift (Law 17).

## 5. TDD task table (Law 2 — failing test first, each proven, commit after each)

| T | Deliverable | Red (fails first) | Green (proof) |
|---|---|---|---|
| T-1 | `DESIGN.md` visual-truth + guardrail | — (docs) | doc exists, cites tokens/scale/preset + guardrail; committed |
| T-2 | `AppSpacing` ThemeExtension + builder attach | spacing test: scale reads from theme with exact values | `AppSpacing.of(ctx)` returns xs..xxl; absent override = defaults |
| T-3 | `theme.shape.style` resolver + validation | preset test: `round` → expected radii; unknown style fails closed | preset sets radii; explicit token overrides; absent = today byte-for-byte |
| T-4 | Generator `validate()` + schema-identity mirror + branding map + CHANGELOG (Law 19) | identity test: app+generator disagree on shape.style | identity green; map + CHANGELOG updated; dry-run EXIT=0 |
| T-5 | Full gate battery | — | analyze×4=0, format 0, floors hold, goldens unchanged, dry-run EXIT=0 |

## 6. Acceptance gates (all must pass, paste-ready receipts)
- `flutter analyze --fatal-infos` ×4 (core_app, halal_boyz, core, core_ui) = 0
- `dart format --output=none --set-exit-if-changed .` = 0
- Default floors hold (core_app 2528, core 396, core_ui 437, halal 77, tool 240);
  new spacing/shape suites green
- **Zero golden baseline drift** (default theme unchanged — the core safety property)
- **Zero suppressions** (`// ignore`, `.skip`)
- Generator: `whitelabel_schema_identity_test` + full `test/tool` green; dry-run EXIT=0
- `DESIGN.md`, `GENERATOR_BRANDING_MAP.md`, `CHANGELOG.md` updated in the same change (Law 19)

## 7. Deferrals (Law 26 — tracked here + DEFERRED.md, never inline TODO)
- **p35-B.1** — migrate all 42 components to `AppSpacing` (requires owner-approved golden
  regeneration because legacy `2`/`6` snap to the scale = intentional pixel change).
- **p35-B.2** — nav "5+More" overflow + F2.0 nav-truthfulness fix.
- **p35-C** — preset/font gallery bundle (one "vibe" key across palette+font+shape+motion+nav).
- **p35-D** — `ScreenVariants` catalog beyond HomeScreen (layout-variant epic).
- Signature-style gallery beyond `rule`.
- Owner-curated final preset palettes/names (V3 ships a tasteful starter set).


