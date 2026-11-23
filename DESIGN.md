# Carnama — Design System (Visual Truth)

> This is the authoritative description of how the app *should look and feel*.
> It is the per-client **style guardrail**: when a rebrand changes colors, fonts,
> shape, or layout, THIS document + `GENERATOR_BRANDING_MAP.md` define the only
> legal change points, so a rebrand can never accidentally break the design.
>
> Source of truth for values: `packages/core_ui/lib/src/theme/*` (tokens) and
> `assets/client_config.json` (per-client). Code wins over prose on exact values;
> this doc wins on *intent*. Written as part of p35 THEME-V2 (scope A).

## 1. The aesthetic

Tier-1 SaaS: **warm, geometric, high-craft, accessible.** Calm surfaces, one bold
brand accent, generous-but-tight rhythm, motion that confirms actions rather than
performs for attention. Every client renders this same *system* with its own
palette + fonts + shape preset — never a different architecture.

## 2. Typography

- **Display / body:** `Outfit` (geometric, friendly). **Buttons / labels:**
  `Montserrat` (tighter, higher weight). Pairing is fixed in
  `packages/core_ui/lib/src/theme/app_theme.dart`.
- Rules already in code: display uses negative letter-spacing (−1.0) and tight
  height (1.1); buttons use Montserrat w600–w700 with +0.5 tracking. Do not
  introduce a third family without a design decision recorded here.
- Per-client override: `theme.typography.headingFont` / `bodyFont` (raw GoogleFonts
  names). *(Preset gallery — one "vibe" key — is deferred to p35-C.)*
- Text scale is clamped for accessibility (`ClampedTextScale`); never hardcode a
  font size that ignores the theme's `TextTheme`.

## 3. Spacing (the rhythm standard)

Single scale — **`AppSpacing`** (p35 V2): `xs=4 sm=8 md=12 lg=16 xl=24 xxl=32`.
Use these steps for padding/gaps. (Legacy components still carry a few inline
`2`/`6` values; migrating them to the scale is p35-B.1 — intentional, golden-gated.)

## 4. Shape & form language

- Fallback vocabulary (`BrandShapes`): `small=8 medium=12 large=16 pill=999`.
- **One-key form preset** (p35 V3): `theme.shape.style` ∈ {`sharp`,`soft`,`round`,
  `pill`}. An explicit per-key token (`theme.shape.cardRadius` …) overrides the
  preset. Absent = today's soft baseline, byte-for-byte.
- "Circular" look a client wants = `round` (friendly) or `pill` (stadium).
- **Depth** (`theme.depth` ∈ {`flat`,`soft`,`elevated`}): M3-exact elevations
  `0` / `3` (`Level2`) / `6` (`Level3`) on the 5 flat card/tile surfaces; absent
  = `flat` = today byte-for-byte. A present-but-unknown value fails closed in
  both the generator and the runtime config validator — it never boots degraded.

## 5. Color

- **Only** `BrandColors.of(context)` (a `ThemeExtension` carrying 13 fields) inside
  `packages/core_ui/lib`. Direct `AppColors.*` use outside core_ui is banned and
  enforced by a repo test.
- Per-client palette = `theme.colors.*` (`primary`, `surface`, `background`,
  `textPrimary`, `soldOut`, …). Dark reads `theme.darkTheme.*`.
- ⚠️ **A top-level `theme.primary` is silently ignored** — brand hues live under
  `theme.colors.*`. This is the #1 rebrand mistake; it is documented in
  `GENERATOR_BRANDING_MAP.md`.
- Foreground-on-fill is derived for WCAG AA automatically (`onColorFor`); never
  hardcode white-on-color.

## 6. Motion

- `theme.animationStyle` ∈ {`full`,`subtle`,`none`} (`AppMotionTokens`). Micro-
  interactions: button press-scale + haptic, staggered entrances, fade-slide-in,
  skeletons. Motion confirms intent; it never blocks or delays a frame.

## 7. Components

42 shared components in `packages/core_ui/lib/src/ui/` (buttons, cards, tiles,
  chips, fields, sheets, dialogs, empty states, charts, data tables, skeletons…).
  Use them; do not fork a one-off widget that re-implements spacing/shape/color.
  Tap = exactly one `InkWell` (never a `GestureDetector` wrapper) so accessibility
  cannot double-fire.

## 8. Layout variants

- `ScreenVariants` catalog (currently `{HomeScreen: grid|showcase}`) is the only
  config-selectable layout today. Extending it beyond HomeScreen is **p35-D** — a
  scoped, golden-gated epic, never an ad-hoc per-app hack (all clients share
  `package:labs`, so a layout change is never client-isolated).

## 9. Icon & splash

- Stamped per client by the generator (`flutter_launcher_icons.yaml` +
  `flutter_native_splash.yaml` from `app.icon`/`app.splash`), verified on a real
  16 KB device. Backdrop overlay via `theme.background.overlayAsset` (decorative,
  fail-safe).

## 10. The per-client guardrail (no mistakes ever)

A rebrand is **config-only** for: colors, fonts, shape preset, motion, spacing
scale is global, icon/splash, currency, nav labels. It is **code** (shared, tested,
golden-gated) for: any new layout, any new component, the variant catalog.

→ See `GENERATOR_BRANDING_MAP.md` for the exact key-by-key change points and the
safe stamp sequence. Change a value there, run the gates, regenerate — never edit
branding values by hand across many files.
