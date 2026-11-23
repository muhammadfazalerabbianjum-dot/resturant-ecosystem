# WHITE-LABEL p35 — DEPTH & DARK (SCOPE B)

Status: **B-1 SHIPPED** (2026-10-14, commits `f1cc5464`..`c641e9b4`); **B-2/B-3 DEFERRED**
(D-P35-2 — the visual audit found dark shallow-but-functional, not broken; a designed dark by
default is a golden-gated pass). Full battery: `tool_uilib/p35/battery.txt` (all gates green,
zero golden drift). Design for B-2/B-3 retained below for when the owner wants a richer dark.
Branch: `cline/p32-golden-gates`. Base: p35 scope-A tip. Follows scope A's additive-safe,
TDD-first discipline.

## 0. Why this scope (the audit's verdict)

An evidence-backed audit (this session) of dark mode + elevation found two real,
well-bounded gaps — the delta between the shipped 8.5/10 and impeccable:

1. **Dark mode is a color-flip, not a designed theme.** `buildDarkTheme` resolves
   exactly two dark values — `background = 0xFF121212`, `surface = 0xFF1E1E1E`
   (both hardcoded, `app_theme.dart:85-86`) — and reuses the entire light brand
   palette unchanged. No elevated dark surfaces, no surface ramp, and the client's
   `theme.darkTheme.*` colors are inconsistently applied (the scaffold `surface` is
   hardcoded while `BrandColors` reads config → the two can disagree). Brand primary
   reused on dark = an AA-contrast risk the light path guards but dark does not.
2. **Elevation is flat-by-absence, no depth system.** Only 5 of 43 components touch
   `elevation`, and each is `elevation: 0` (explicitly flat). Zero positive-shadow
   anywhere; "flat" is the default by omission, not a client-tunable decision.

Good news (do NOT rebuild): components are theme-surface-driven (1 hardcoded light
value repo-wide, already `isDark`-aware); Hero transitions, Lottie empty states, AA
foreground, signature, and motion all ship. Scope B adds depth + a designed dark.

## 0.2 Scope, and what is explicitly NOT here

**In scope B:**
- **B-1 — `AppDepthTokens`** (`theme.depth` ∈ {`flat`,`soft`,`elevated`}): a shared
  elevation/shadow scale. Default `flat` = today's `elevation: 0` byte-for-byte, so
  migrating the 5 flat components is golden-safe. Per-client hierarchy, zero code.
- **B-2 — dark surface ramp, one source** (`theme.darkTheme.surfaces.{background,
  surface,surfaceVariant,elevated}`): a single ramp feeding BOTH the scaffold
  `ThemeData` AND `BrandColors` (fixing the hardcoded-vs-config split). Default =
  today's `0xFF121212`/`0xFF1E1E1E` byte-for-byte. Lets a client author a designed dark.
- **B-3 — AA foreground on dark**: `onColorFor` applied on dark surfaces too, so a
  brand hue never renders low-contrast text on dark. Red→green.

**Out of scope B (recorded → §7):**
- **Changing the DEFAULT dark look to a designed ramp, and/or defaulting depth to
  non-flat** — an intentional pixel change → dark-golden drift (Law 17). Separate,
  owner-approved golden-regeneration pass (D-P35-2), NOT bundled in the safe mechanism.
- Nav 5+More (p35-B.2), preset/font gallery (p35-C), layout variants (p35-D), full
  spacing migration (D-P35-1) — already deferred in `WHITE_LABEL_p35_theme_engine.md`.

## 1. Current state — PROVEN (audited this session)

- Dark: `app_theme.dart:85-86` hardcodes `0xFF121212` / `0xFF1E1E1E`; `BrandColors`
  reads `theme.darkTheme.*` (`brand_colors.dart` doc). Two sources → can disagree.
- Elevation: `brand_card/menu_tile/setting_tile/status_tile/stat_tile` each `elevation:0`;
  no `BoxShadow` / positive elevation in `core_ui/lib/src/ui`.
- Components are otherwise theme-surface-driven (dark-safe); `skeleton_loader.dart:58`
  is the only hardcoded light value and is already `isDark`-aware.
- Token extensions attach in the shared `_theme(...)` builder (both brightnesses), so
  `AppSpacing`/`AppShapeTokens`/`AppShapePreset` already reach dark — the ramp/depth
  tokens will attach the same way.

## 2. Feature B-1 — `AppDepthTokens` (`theme.depth`)

- New `AppDepthTokens extends ThemeExtension` in `app_tokens.dart`: a named depth
  level (`AppDepth.flat|soft|elevated`) + resolved elevation/shadow values per level.
  - `flat`     → elevation 0, no shadow (today, byte-for-byte).
  - `soft`     → elevation 3 (M3 `Level2`) + a subtle brand-tinted shadow.
  - `elevated` → elevation 6 (M3 `Level3`) + a stronger shadow.
    The ladder is M3-exact (0/3/6 = AOSP `Level0`/`Level2`/`Level3`); `soft` was
    snapped 2→3 in the p35 close-out so no rung sits between Material levels.
- Config: optional `theme.depth` ∈ {flat,soft,elevated}, validated fail-closed in
  BOTH the generator and the runtime config validator (W6.5 parity, the same
  contract as `shape.style`); absent = `flat`.
- **Golden-safe migration:** the 5 flat components (`brand_card`, `menu_tile`,
  `setting_tile`, `status_tile`, `stat_tile`) read `AppDepthTokens` instead of literal
  `elevation: 0`. Because default `flat` resolves to 0, this is byte-for-byte today —
  no golden drift. A client opting into `soft`/`elevated` gets depth; no existing golden
  uses it.

## 3. Feature B-2 — dark surface ramp, one source

- New optional config `theme.darkTheme.surfaces.{background,surface,surfaceVariant,
  elevated}` (hex). A single resolved ramp feeds BOTH the scaffold `ThemeData`
  (`scaffoldBackgroundColor`/`colorScheme.surface`/card) AND `BrandColors` (background/
  surface) — eliminating the hardcoded-vs-config split so the two can never disagree.
- Default (absent) = today's `0xFF121212` / `0xFF1E1E1E` byte-for-byte (dark goldens safe).
- `surfaceVariant`/`elevated` are NEW levels — only consumed when a client authors them
  (or when B-1 depth is non-flat and a ramp is present); absent = surface (today).

## 4. Feature B-3 — AA foreground on dark

- `AppColors.onColorFor` (the AA auto-foreground) is already the light-path guard; B-3
  ensures dark surfaces route through it too, so a brand primary/accent never yields
  low-contrast text on a dark background. Red→green: a dark theme with a mid-luminance
  brand hue must still resolve a ≥4.5:1 foreground.

## 5. TDD task table (Law 2 — failing test first, each proven, commit after each)

| T | Deliverable | Red (fails first) | Green (proof) |
|---|---|---|---|
| T-1 | `AppDepthTokens` + resolver + validation | depth test: `soft`→elevation>0; unknown fails closed | `flat`=0 today; `soft`/`elevated` set depth; absent=flat |
| T-2 | Migrate the 5 flat components to the token | golden/widget test: default flat still renders identical | byte-for-byte at `flat`; depth applies when configured |
| T-3 | Dark surface ramp, single source (scaffold + BrandColors agree) | dark test: configured `darkTheme.surfaces` reaches BOTH | absent=today `0xFF121212/0xFF1E1E1E`; configured ramp consistent |
| T-4 | AA foreground on dark surfaces | dark contrast test: mid-luminance brand on dark | `onColorFor` resolves ≥4.5:1 on dark |
| T-5 | Full gate battery | — | analyze×4=0, format 0, floors hold, goldens unchanged, dry-run 0 |

## 6. Acceptance gates (all must pass, paste-ready receipts)
- `flutter analyze --fatal-infos` ×4 = 0; `dart format --set-exit-if-changed .` = 0
- Default floors hold (core_ui, core_app, core, halal, tool, functions); new depth/dark
  suites green
- **Zero golden baseline drift** — the core safety property: default `flat` depth +
  default dark ramp = today byte-for-byte
- **Zero suppressions** (`// ignore`, `.skip`)
- Generator `validate()` mirrors `theme.depth` + `theme.darkTheme.surfaces`; identity
  test pins the vocabulary; dry-run EXIT=0
- `DESIGN.md`, `GENERATOR_BRANDING_MAP.md`, `CHANGELOG.md` updated in the same change (Law 19)

## 7. Deferrals (Law 26 — tracked here + DEFERRED.md, never inline TODO)
- **D-P35-2 — designed dark by default + non-flat default depth:** changing the DEFAULT
  dark surfaces to a designed ramp (and/or defaulting depth to `soft`) is an intentional
  pixel change → requires an owner-approved dark-golden regeneration. The mechanism
  ships opt-in in scope B; the beautiful default is this deferred, golden-gated pass.
- Adaptive/tablet layout (rail on wide screens) — separate epic.
- Delight micro-interaction set (fly-to-cart, steppers, toasts) — separate polish batch.

