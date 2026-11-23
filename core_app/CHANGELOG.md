# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-10-15

### Changed
- **p35 close-out (owner-approved):** depth preset `soft` snapped 2→3 so the
  ladder is exactly M3 (`0`/`3`/`6` = `Level0`/`Level2`/`Level3`) — core_ui
  depth tests red→green ×3, no golden baseline uses `soft` → zero golden drift.
  **W6.5 runtime parity:** `ClientConfig.fromMap` now fails CLOSED on a
  present-but-unknown `theme.shape.style` / `theme.depth` (previously
  generator-only; the runtime silently degraded) — new public pins
  `knownShapeStyles` / `knownDepthStyles`, three-way pinned (runtime ↔
  generator ↔ core_ui vocabulary) in `whitelabel_schema_identity_test`; schema
  tests ×2 red→green. **Doc truth:** `DEFERRED.md` D-P35-2 corrected — B-2
  `theme.darkTheme.surfaces` is deferred, not shipped (zero code hits);
  depth doc + `GENERATOR_BRANDING_MAP.md` updated for the parity and M3
  ladder; `DESIGN.md` §4 documents the depth ladder. **Hygiene:**
  `apps/copper_grill` (never tracked, not a workspace member, `pub get`
  EXIT=66) deleted on owner order with its lone `.idea` run config.

### Fixed
- **T-FLAKE-1 (boot-log race, closed):** under `flutter test` the boot
  logger sank into the machine-global `%TEMP%/app_logs.txt`, which all 4
  boot-harness test files (each its own process) snapshot+deleted+
  overwrote concurrently — `freshBootLog()` could read back `''` (~1 in 5
  full-suite runs). Root cause was NOT the stale DEFERRED hint (missing
  logger await — every boot-chain `logger.error` call is awaited); it was
  the shared file. New `bootLogDirectoryForTest()` (per-PID subdirectory)
  is the single source of truth for the logger's `FLUTTER_TEST` branch,
  the `handleBootFailure` crash-log fallback and `BootHarness`
  (`bootLogPathForTest`/`crashLogPathForTest`); production path untouched.
  New contract test `test/boot_log_process_isolation_test.dart` (red→green);
  boot set ×10 (5 pre-format + 5 post-format) 10/10 EXIT=0, full default
  tier +2538 green, analyze 0 issues.

## [Unreleased] - 2026-10-11

### Added
- **p35 THEME-V2 (visual-perfection foundation):** `DESIGN.md` (written visual
  truth + per-client style guardrail). `AppSpacing` rhythm-scale token
  (xs4/sm8/md12/lg16/xl24/xxl32) as a `ThemeExtension` — the go-forward spacing
  standard. `theme.shape.style` one-key form preset
  (`sharp`/`soft`/`round`/`pill`) sets card/cta/small radii together; an
  explicit `theme.shape.*Radius` overrides it and an absent/unknown value is
  byte-for-byte today (runtime graceful-degrade; the generator's `validate()`
  fails closed on an unknown style). Full spacing migration of legacy
  components is deferred (D-P35: golden-gated).
- **p35 scope B (DEPTH & DARK) — B-1 depth system:** `theme.depth` one-key
  preset (`flat`/`soft`/`elevated`) sets Material elevation on the 5 flat
  card/tile surfaces (brand_card, menu_tile, setting_tile, status_tile,
  stat_tile). Absent = `flat` = today byte-for-byte (zero golden drift);
  runtime graceful-degrades an unknown value and the generator's `validate()`
  fails closed. Additive + golden-safe (core_ui suite +463, no drift).
  B-2 (designed dark surface ramp) and B-3 (AA-on-dark) are deferred: the
  visual audit (`tool_uilib/p35/VISUAL_AUDIT.md`) found dark mode
  shallow-but-functional, not broken; a beautiful dark by default is a
  golden-gated pass (D-P35-2).

### Changed
- **Isar → isar_community 3.3.2 (p34 A-fix, 16 KB page sizes):** `isar` /
  `isar_flutter_libs` 3.1.0+1 shipped a prebuilt `libisar.so` with 4 KB LOAD
  alignment (`ELF_NOT_ALIGNED` + `PageSizeMismatchDialog` on 16 KB devices).
  The community fork's binaries are 16 KB-aligned (ELF-verified `align=0x4000`
  on x86_64 and arm64). All 27 `package:isar` imports swapped;
  `isar_schemas.g.dart` regenerated with the real community generator (schema
  ID hashes unchanged → existing local data stays readable). The generator
  itself is deferred (D-P34-1: source_gen ^4 collides with the freezed 2.x
  chain). Host test helpers now pin the lockfile's binary via
  `package_config.json` (`test/helpers/isar_native.dart`,
  `test/helpers/isar_test_boot.dart`).
- **Device e2e lane hardened (p34 C-fix):** `v13`/`v15` rules suites no longer
  install `setupFirebaseAuthMocks()` on the device lane (the mock/real
  FirebasePlatform split deadlocked the 2nd auth cycle);
  `tool/run_integration_tests.ps1` STEP 6 no longer runs
  `adb reverse --remove-all` when reusing an operator's emulators (it ripped
  tunnels out from under concurrent runs → okhttp "unexpected end of stream").

## [Unreleased] - 2026-10-04

### Added
- **Signature identity (Q1 — impeccable 2026-10-02):** optional `theme.signature.style` (closed set,
  validated at BOTH config gates: `client_config.dart` + `tool/whitelabel.dart`) builds the
  `AppSignatureTokens` ThemeExtension; `SignatureRule` leads `SectionHeader` and `EmptyStateWidget`
  when present. Absent = byte-identical stock tree (b10) — core stays stock, the shell opts in.
- **Visual pack (Q2 — impeccable):** the capture harness loads the real bundled fonts via `FontLoader`
  through the public `applyResolvedFamilies` seam, drops the debug banner (P2 "corner ribbon"), wraps
  chips at the outer-margin spacing, and ships `states.png` (five tones + badges + skeleton) plus
  full-screen `home`/`cart`/`checkout` captures at 393x844 with seeded content.
- **Harness:** a committed anomaly-detector suite (classes 3, 5, 6, 8, 9) with a surfaces x wave matrix,
  pinned by a repo test that asserts both its failure exit and its green exit
  (`core_app/tool/anomaly_detectors.dart`, `core_app/test/tool/anomaly_detectors_test.dart`).
- **Evidence archive:** the 57 files that tracked ledgers, tests and production source still cited from
  the retired `tool_perf2/**` scratch tree are restored under `tool_archive/perf2_cited/` - each one
  byte-identical to its pre-deletion blob - with provenance, byte accounting and a residue table in that
  directory's README, plus `tool_uilib/p26/receipts/t7_evidence_restore.txt`.

### Changed
- **Brand slot reads config (P1, impeccable re-rate):** the home app bar renders
  `AppConfig.appName` (client config `app.name`) instead of the demo-era l10n `appName` — the hero
  surface says "Halal Boyz", not "Labs" (two-sided pin in shell `widget_test` T-1).
- **Pack icons render (P1, impeccable re-rate):** the capture harness loads the Flutter SDK
  MaterialIcons font from a test-only fixture (`apps/halal_boyz/test/fonts/` + its license file,
  never in `assets/`, zero bundle cost), so tone/nav/action icons are real pictographs in the pack.
- **Semantic sold-out (Q3 — impeccable):** `theme.colors.soldOut` flows end-to-end (AppColors →
  BrandColors → engine → both shipped configs, hex-strict at both validators). The dish-detail notice
  and menu-row icon adopt `InfoTone.soldOut` (an availability state is no longer dressed as a system
  error), and two `AppColors.*` leaks (`InfoBanner` body, `EmptyStateWidget` subtitle) now resolve
  through `BrandColors.of(context)`.
- **Law-10 gate is real:** `core_app/tool/pipeline.dart` now runs `dart format --set-exit-if-changed`,
  `flutter analyze --fatal-infos` and the core_app unit tier fail-fast, exiting non-zero on the first
  red gate. It previously logged a success line without running anything.
- **Logger hygiene:** the test fleet no longer writes to a machine-global `%TEMP%` sink - each test run
  gets its own directory - and the production `TaxService` logger default no longer points at `%TEMP%`.
- **Checkout session key:** the no-argument mint is private; the public API is attempt-scoped and
  re-pinned per attempt, so a session key cannot be reused across attempts.
- **Rule files are versioned:** `.clinerules/**` and `.clineignore` are tracked in the repo, and the
  machine-local `.agents/**` skill cache is ignored.

### Security
- **Orders create rule hardened:** `core_app/firestore.rules` and `core_app/staging.firestore.rules`
  constrain the create path with an explicit `affectedKeys().hasOnly([...])` key shape, and the offline
  order payload no longer writes the now-forbidden `orderSource` key. The generated
  `apps/halal_boyz/backend/firestore.rules` mirror was regenerated and its parity test is green.

### Fixed
- The 8 encoding-damaged lines in `archive/FIX_VERIFICATION.md` (32 U+FFFD codepoints) were restored
  character-for-character from the commit that introduced that text; the ledger now decodes with zero
  replacement characters.
- **WHITE_LABEL p31 P2 batch:** the home category chips reflect the live Firestore menu (price band via
  new `categoryUnderAmount` l10n instead of a hardcoded demo hint); the checkout total renders through
  `PriceTag` so the `$` glyph no longer collides with the first digit; the cart strip dead zone surfaces
  real menu suggestions (`cartSuggestionsFor` + `cartYouMayAlsoLike`, painted with `BrandColors` tokens).
- **WHITE_LABEL p31 generator batch:** `whitelabel.dart` copies the canonical
  `tool/templates/fonts/*.ttf` into the client tree (`copyTemplateFonts`, fails loud on a missing
  source), and `--template` actually applies (`applyTemplateThemePreset` — fill-missing only, explicit
  client values are never overwritten); pinned by `whitelabel_p31_assets_test`.
- **Coverage fleet rule (p30 gap):** `AppSignatureTokens` now carries a full line-coverage contract
  test, so the b7 floor is green again (EXIT=0) without touching the pinned baseline.

## [1.1.1] - 2026-05-22

### Fixed (Critical Post-UAT Sprint)
- **Security**: Added protection to `reservation_locks` via Firestore rules to prevent DOS and lock-stealing by scoping lock IDs to the `userId`.
- **Security**: Closed role escalation vulnerability in Owner Dashboard; users can no longer assign the `owner` role via the UI, nor can owners demote themselves accidentally.
- **Backend/Auth**: Seeded the missing `settings/ownerInfo` Firestore document, resolving the cascade of "permission-denied" errors across all admin write operations (creating branches, toggling feature flags, etc.).
- **Backend**: Resolved Firestore schema mismatch for branch coordinate seeding (replaced `lat`/`lng` with explicit `GeoPoint` fields), fixing `flutter_map` `NaN` crash.
- **Android**: Updated `MainActivity.kt` to extend `FlutterFragmentActivity` instead of `FlutterActivity` and sandboxed initialization, permanently resolving the Stripe SDK hard crash on cold boot.
- **UI/UX**: Replaced hardcoded hero banner text on `HomeScreen` with dynamic `HeroCarouselWidget` hooked up to the `promotions` Firestore collection.
- **UI/UX**: Added `useSafeArea: true` to all Admin Modal Bottom Sheets (Menu Editor, Branch Editor) to prevent clipping under the iOS Home Indicator and Android Navbar.
- **UI/UX**: Fixed endless loading spinners in Kitchen and Manager dashboards by implementing a 5-second timeout and explicit error handling for missing/null `branchId` assignments.
- **Features**: Added `imageUrl` inputs to the Manager and Owner `_MenuItemEditor` forms.
- **Features**: Removed the `branchId isNull` restriction in the Owner Global Menu view to correctly display all menu items.
- **Polish**: Gated the red debug action button behind `kDebugMode` to prevent it from shipping to production. 
