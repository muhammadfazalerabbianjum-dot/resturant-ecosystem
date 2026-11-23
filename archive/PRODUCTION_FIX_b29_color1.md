# BATCH COLOR-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W10.**

## 29. BATCH COLOR-1 - APPCOLORS THEME-BYPASS ELIMINATION

**Predecessor:** any (independently safe; after BACKEND-2/UX-1 is cleanest to avoid palette conflicts). **Emulator-gated:** no. **Master:** W10. **MIRROR: core_ui + themes shared; shell regenerated carries it.**

### 29.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/lib/**` (dozens of sites) | Direct `AppColors.*` usage bypasses per-client theme - latent today (palettes byte-identical), mixed-brand UI the moment a client palette differs | P0 (08-P0-WL-3) |
| P-2 | repo | No `AppColors`-usage lint/aliasing layer | P1 (08-P1-WL-2) |
| P-3 | chart widgets | `Color(0x...)` chart literals bypass config | P2 (00-consistency) |

### 29.2 Solution - design principle + acceptance contract

**Design principle:** one theme mapping (config -> ThemeExtension); ban direct `AppColors` outside core_ui; prove with a distinct palette.

**Acceptance contract (from master W10):**
1. Add a lint/rule banning `AppColors.` outside `packages/core_ui/lib` in `core_app/lib` + `apps/*/lib`; wire into the CI analyze job.
2. Add a `BrandColors` ThemeExtension mapping the config palette (primary/secondary/accent/success/warning/error + neutrals) built by `AppTheme.buildTheme` from the SAME config keys for light+dark.
3. Migrate every direct `AppColors.*` use in `core_app/lib` to `Theme.of(context)`/`BrandColors`; fold 05-P2-COLORLIT raw `Colors.*` (8 files) into the same tokens; wire chart `Color(0x...)` literals from BrandColors/confetti.
4. Prove with a distinct-palette TEST `ClientConfig` fixture: no `AppColors` leakage in a widget test.

### 29.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Lint/rule 0 violations | CI analyze job / repo test |
| T-2 | Distinct palette respected | Widget: fixture with different hexes -> UI uses fixture colors everywhere |
| T-3 | No AppColors in core_app/lib | grep `AppColors.` in core_app/lib = 0 |
| T-4 | Goldens byte-identical today | Verify (don't assume) - re-capture if pixel-affected |

### 29.4 Proof gates

- [ ] Lint/rule = 0 violations
- [ ] Distinct-palette widget test green
- [ ] grep `AppColors.` in `core_app/lib` = 0
- [ ] `flutter analyze` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 29.5 Honest residuals

- The migration is large (dozens of sites) but mechanical; the distinct-palette test is the proof it actually works.
- `custom_lint` is only used if already a dependency; otherwise an enforceable repo test (grep-based) is the mechanism - record which in the addendum.

**END OF BATCH COLOR-1 SPEC** - do not proceed until these gates pass and the COLOR-1 addendum is appended to FIX_VERIFICATION.md.