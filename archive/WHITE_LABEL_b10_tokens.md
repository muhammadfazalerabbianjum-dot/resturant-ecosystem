# WHITE-LABEL TOKENS SPEC - DESIGN TOKEN SYSTEM (part of WHITE_LABEL_BATCHES.md)

**Read `WHITE_LABEL_BATCHES.md` FIRST (incl. WORKTREE OPS §3.5 + territory §3.6 — blocker gate B-1..B-5 before you start; per-worktree ledger + commit format + merge-back are there) + `CLIENT_ACQUISITION_PLAYBOOK.md` §8A. Gap analysis: the halal_boyz UI spec (mockups/Halal Boyz/halal_boyz_ui_spec.md) demands dimensions the theme engine cannot express today.**

## TOKENS - DESIGN TOKEN SYSTEM: SHAPE + TYPOGRAPHY SPLIT + COMPONENT VARIANTS

**Predecessor:** ARCH-1 (barrel exists so shells inherit instantly). **Emulator-gated:** no. **Territory:** `packages/core_ui/lib/src/theme/` (app_theme.dart + new token classes) + `core_app/lib/app/config/app_config.dart` (parser keys) + `core_app/tool/whitelabel.dart` (validate keys) + both `client_config.json` schemas.

### Problems (verified this session — from app_theme.dart's 421 lines + the spec's demands)

| Spec demand | Theme engine today | Gap |
|---|---|---|
| Serif headings (Playfair) + sans body (Inter) simultaneously | ONE `fontFamily` applied to the entire TextTheme (`_textThemeFor`) | No heading/body font split |
| Card radius 12-16px per client | `CardThemeData` hardcoded to 16 | No cardRadius token |
| CTA stadium/pill (100px) vs sharp buttons | No button shape config | No ctaRadius token |
| Small button radius 6-8px | Not themed | No smallRadius token |
| Navigation bar color #1A1A1A + active color | Not themed from config | No navigationBar token |
| Scaffold bg + decorative overlay (city map) | Not themed | No scaffoldBackground/overlay token |
| Input decoration (search/fields) | Not themed | No inputTheme token |
| Chip shape (category circles) | Not themed | No chipTheme token |
| Animation intensity (full/subtle/none) | Not themed | No animationStyle token |

### Acceptance contract
1. **Extend `AppTheme.buildTheme(theme)`** to consume the new token keys (it already receives the whole `theme` map): `theme.typography.headingFont` + `theme.typography.bodyFont` (split TextTheme: display/headline/title use heading font, body/label use body font); `theme.shape.cardRadius|ctaRadius|smallRadius` (→ CardThemeData, FilledButtonTheme, OutlinedButton/IconButton themes); `theme.components.navigationBar.{background,activeColor}` (→ NavigationBarThemeData); `theme.components.input.*` (→ InputDecorationTheme); `theme.components.chip.*` (→ ChipThemeData); `theme.background.{color,overlayAsset}` (→ scaffoldBackgroundColor + an exported `ScaffoldBackground` widget for the overlay); `theme.animationStyle` (full/subtle/none → shared durations/curves).
2. **Parser + schema + validate()** gain the same keys together (WL-2 pattern: typo fails fast, never silent).
3. **Every token has a default** = today's behavior (cardRadius 16, system fonts, etc.) — zero visual change for configs that don't set them (Rule: backward-compatible).
4. **halal_boyz config updated** to consume the tokens from the Halal Boyz spec (Playfair/Inter split, maroon nav, card 12-16, CTA stadium).
5. **Tests:** per-token red→green (set token → ThemeData reflects it; omit → default), the distinct-palette/distinct-tokens widget test pattern (COLOR-1's T-2 pattern extended), golden re-capture where visuals change, parser/validator tests.
6. **Zero logic changes** — this batch touches theme/config only.

### Tests / Gates
- U-ANALYZE ×4 + U-TESTS + U-FORMAT + U-GREPS; full repo suite green; 0 skips; goldens green (re-captured where legitimately changed).

### Honest residuals
- The city-map overlay ASSET itself is an art asset (operator supplies the PNG) — the batch builds the mechanism, not the artwork.
- True per-client *screen layout* restructure (e.g. search-at-bottom) is a widget variant, not a token — that remains a shared-widget feature batch if a client demands it (playbook §8A).
- Android 12+ splash screens ignore some theme tokens (platform limitation, documented).

**END OF TOKENS SPEC.**