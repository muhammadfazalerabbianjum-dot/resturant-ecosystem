# AUDIT REPORT — CONFIG-DRIVEN WHITE-LABEL & CLIENT GENERATION SAFETY

**Audit date:** 2026-08-31 · **Prompt:** `AUDIT_WHITE_LABEL_CONFIG.md` (Hard Gate 1: truth from CURRENT code only)
**Verdict:** ❌ **FAIL** — **P0:** 3 · **P1:** 5 · **P2:** 8
**Consolidated block:** appended to `PRODUCTION_READINESS_AUDIT_MASTER.md` as "Consolidated Findings — 08".
**Rule honored:** REPORT ONLY — no code, config, or asset was modified during this audit.

---

## 0. METHOD & CANONICAL COMMANDS (all output verbatim-verified this session)

- Key-level config diff: `Compare-Object` on top-level keys of both `client_config.json` files (§1.1).
- Full-file reads of: both `client_config.json` files (complete), `core_app/lib/app/config/app_config.dart` (all 358 lines), `apps/halal_boyz/lib/{main.dart, app/app.dart, app/core_config_adapter.dart, app/currency_config.dart}`, `core_app/lib/app/{app_router.dart, brand_drawer.dart}`, `core_app/lib/features/splash/presentation/splash_screen.dart`, `core_app/lib/app/config/{feature_flags_service.dart, currency_format.dart}`, `core_app/lib/main.dart`, `core_app/tool/whitelabel.dart` (complete), both `android/app/build.gradle.kts`, halal `project.pbxproj` (identity lines), all three `pubspec.yaml`, `core_app/.env`, `core_app/.gitignore`.
- Repo-wide greps (PowerShell `Select-String` over all `*.dart` in `core_app/lib`, `apps/halal_boyz/lib`, `packages/*/lib`): every `AppConfig.*` getter, `Color(0x`, hex string literals, `featureFlagsProvider`, `.isEnabled(`, `featureEnabled`, `navigationTabs`, `navigationHiddenRoutes`, `navigationRoutes`, `navigationEntryPoint`, `devAdminPin`, `storeAndroidUrl|storeIosUrl`, `clientId`, `assets/`, `applicationId`, `flutter_launcher_icons`.
- `flutter analyze`: core_app → **"No issues found! (ran in 141.7s)"**; apps/halal_boyz → **"No issues found! (ran in 75.8s)"**.
- Asset inventory: `Get-ChildItem` on `core_app/assets`, `apps/halal_boyz/assets`, `apps/halal_boyz/android/app/src/main/res` (byte sizes recorded), iOS `AppIcon.appiconset` existence.
- JSON validity: both configs parsed via `ConvertFrom-Json` (valid).

Every claim below cites `file:line` of current source. Runtime-only behaviors are listed under Honest Limitations.

---

## 1.1 CONFIG SCHEMA COMPLETENESS — ❌ FAIL

### Key-level diff (both directions, top-level)
```
core-only : (none)
halal-only: currency
```
All other sections (`_meta`, `app`, `environment`, `firebase`, `features`, `tax`, `theme`, `navigation`, `screens`, `newFeatures`) are present in both. The diff is not benign: the generated shell **consumes** `currency` (at HEAD in `apps/halal_boyz/lib/app/core_config_adapter.dart:42-48`; the audited `currency_config.dart` and `app.dart` wiring was removed post-audit), but the **template** config `core_app/assets/client_config.json` has no `currency` section, and the generator's validation (`core_app/tool/whitelabel.dart:68-92`) checks only 5 section names — it cannot guarantee the key its own generated code reads. **FINDING P2-6.**

### Every key consumed vs dead (parser = `core_app/lib/app/config/app_config.dart:194-312`)
**Consumed by core parser:** `app.{name,bundleId,storeAndroidUrl,storeIosUrl,fcmChannelDescription}` (194-207) · `environment.{cloudinaryUploadPreset,cloudinaryCloudName,firebaseProjectId,devAdminPin}` (209-223) · `firebase.{androidAppId,iosAppId,messagingSenderId,iosClientId}` (225-237) · `branches.defaultBranchId` (239-244) · `theme.*` incl. `confettiOverlay.colors` (246-265) · `features.flags` + `unknownFlagDefault` (267-280) · `navigation.{entryPoint,tabs,hiddenRoutes,routes}` (282-303) · `screens[]` raw (305-312).

**Dead keys (present in configs, read by NOTHING — grep-verified across `core_app/lib`, `apps/halal_boyz/lib`, `packages/*/lib`):**
| Dead key | core / halal location | Proof of non-consumption |
|---|---|---|
| `app.primaryColor` | core:9 / halal:11 | parser reads only name/bundleId/storeUrls/fcmDescription (`app_config.dart:194-207`); zero dart references |
| `app.fontFamily` | core:10 / halal:12 | never parsed; theme fontFamily comes from `theme.typography.fontFamily` only |
| `environment.stripePublishableKey` | core:18 / halal:32 (placeholder `pk_test_REPLACE_ME_USE_DART_DEFINE`) | core parser never reads it; app uses `--dart-define` (`core_app/lib/app_bootstrap.dart:723-726`; the audited `core_app/lib/app/config/env.dart` and `core_app/lib/main.dart` read sites were deleted with ARCH-2). Halal shell DOES read it for the checkout honesty gate (`app.dart:16-23`) — core template doesn't |
| `environment.recaptchaWebKey` | core:19 / halal:33 | never parsed |
| `environment.firebaseAndroidApiKey` / `firebaseIosApiKey` | core:21-22 / halal:34-35 | core parser never reads them; halal `main.dart:25-28` reads them — **both `""`** (→ P0-WL-1) |
| `environment.kitchenLanEndpoint` | halal:31 (absent in core config) | consumed in halal adapter (`core_config_adapter.dart:79`); core parser lacks the key — schema asymmetry |
| `firebase.projectId` | core:26 (`""`) / halal:39 (`demo-tenant`) | core parser reads `environment.firebaseProjectId`, **not** `firebase.projectId` (`app_config.dart:218-220`); core config has neither value → dead in core (consistent with Master audit 02 "config `firebase.projectId` ignored"). Halal `main.dart:32` reads `firebase.projectId` — same concept, different keys per app |
| `firebase.collections` (26 names) | core:34-59 / halal:mirror | grep `collections` → only Isar `CollectionSchema` generated-cache hits; Firestore paths are code constants (e.g. `feature_flags_service.dart:31-33`) |
| `firebase.clientScopingFields` | core:~44-49 / halal:mirror | zero dart hits |
| `firebase.configDocuments` | core:60-66 / halal:mirror | zero dart hits |
| `features.flags[*]` values | core:66-74 / halal:mirror | parsed but ALL dropped — values are objects `{"enabled":true}`; parser accepts only `bool` (`app_config.dart:273-275`) → `AppConfig.featureFlags ≡ {}` (→ P1-WL-1) |
| `tax.*` incl. `stateRates` | core:77-103 / halal:mirror | never parsed; section self-documents the gap: `"currentImplementation": "server-side Cloud Function calculateTax (hardcoded; redeploy required)"` (core:101) |
| `navigation.routes` (core) | core:155-186 | parsed (`app_config.dart:295-302`), **zero consumers in core_app** (grep). Halal shell consumed its copy pre-ARCH-1; at HEAD its `app.dart` is a thin wrapper and the parsed block (`AppConfig.navigationRoutes`, `app_config.dart:187`) has no live consumer anywhere |
| `screens[].mandatory` | core:178-206 / halal:mirror | parsed raw (`app_config.dart:307-312`), never evaluated — `_buildRoutesFromConfig` checks only id+route (`app_router.dart:143-146`) |
| `newFeatures` | core:207 / halal:末 | never parsed |

### Defensive parsing / no code-eval (PASS items)
- No `eval`, no dynamic import: config flows through `jsonDecode` + typed accessors only (`app_config.dart:190-192, 325-348`) — **PASS** (config-injection gate).
- Malformed/missing asset → app still boots on defaults+dotenv, error recorded (`app_config.dart:317-322`; `loadError` getter 100-101) — **PASS**.
- Array handling: `tabs`/`hiddenRoutes` `whereType<String>()` (288-293); `screens is List` guard (307); confetti empty-parse guard (`parsed.isNotEmpty`, 262) — **PASS**.
- `_colorFromHex` rejects bad input → null → caller falls back (`app_config.dart:340-348`) — **PASS**.
- Generator config validation: 5 mandatory sections + non-empty name/bundleId (`whitelabel.dart:68-92`); forbidden-identity guard blocks Carnama's live Cloudinary/LAN/app-id tokens (`whitelabel.dart:228-251`) — **PASS as far as it goes**, but only 4 fragments and no type/range checks (→ P2-8).

## 1.2 GENERATED CONFIG EDIT SAFETY (LIVE-EDIT RISK) — ✅ PASS (with 1 documented caveat)

### (a) Format detection: required/optional/static — grep-proven, no guesswork
- **REQUIRED to edit per client:** `assets/client_config.json` — the ONLY per-client config asset; loaded by `AppConfig.loadConfig()` (`app_config.dart:190`) in core and by `rootBundle.loadString('assets/client_config.json')` in halal (`apps/halal_boyz/lib/main.dart:13, ~40`).
- **OPTIONAL (empty = valid):** `core_app/.env` — every `_env()` call has a default (`app_config.dart:170-186`); missing file doesn't crash load. Currently tracked in git but contains **no secrets** — only public operational values: `APP_NAME, APP_BUNDLE_ID, FIREBASE_PROJECT_ID, CLOUDINARY_UPLOAD_PRESET, STORE_ANDROID_URL, STORE_IOS_URL, FCM_CHANNEL_DESCRIPTION` (key list verified; `CLOUDINARY_UPLOAD_PRESET` is public by design for unsigned uploads). Hygiene note → P2-7.
- **STATIC — DO NOT EDIT MANUALLY:** `android/app/build.gradle.kts` (`applicationId` — but see (c)), `ios/Runner/Info.plist` (`CFBundleIdentifier`), `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER` ×3: Runner, RunnerTests, plus build-variant rows), `GoogleService-Info.plist` / `google-services.json` (regenerated from `firebase/` template files by the generator, `whitelabel.dart` write steps).
- **GENERATED — DO NOT EDIT:** `apps/<client>/lib/app/*.dart`, `lib/features/**` — all written by `whitelabel.dart` template substitution; a manual edit is destroyed on next regeneration.

### (b) Identity duplication matrix (must-match set)
| Identity value | android `build.gradle.kts` | iOS `project.pbxproj` | iOS `Info.plist` | `client_config.json` | `google-services.json`/`GoogleService-Info.plist` |
|---|---|---|---|---|---|
| applicationId / bundle id | `com.halalboyz.kitchen` (halal gradle) | `com.halalboyz.kitchen` (×3+ in pbxproj) | not present in plist (CFBundleIdentifier `$(PRODUCT_BUNDLE_IDENTIFIER)`) | `app.bundleId` halal:16 | package_id/bundle_id fields — **generated from config by `whitelabel.dart`, single source of truth** ✅ |
| app display name | n/a (label uses `@string/app_name` resource) | n/a | `CFBundleDisplayName` | `app.name` | — |
| API keys / project | n/a | n/a | n/a | `environment.firebase*ApiKey`, `firebase.projectId` | regenerated files carry these |

**Result:** identity is single-sourced through the generator for platform files, BUT `client_config.json`'s firebase IDs are dead weight in core (see §1.1) — the "must-match" invariant currently exists only by generator discipline, not by parsing (→ P2-6).

### (c) Worst current outcome of editing the wrong file (concrete, code-level)
1. **Edit generated lib instead of config:** next `dart run tool/whitelabel.dart --config ...` silently overwrites it (template files are rewritten wholesale) — silent brand-logic loss, no VCS conflict until commit.
2. **Edit gradle/pbxproj by hand:** next generation overwrites; also `whitelabel.dart:~228-251` refuses to proceed only when forbidden *config tokens* are present — hand-edited platform files bypass that guard entirely.
3. **Edit `core_app/assets/client_config.json` with a bad hex / wrong types:** core falls back to built-in theme silently (`app_config.dart:246-265`) — user sees default orange Carnama theme in a rebranded client with NO error surfaced (only `loadError` internal, never rendered). Silent-rebrand-failure is the top live-edit operational risk (→ P2-4).
4. **Worst realistic breakage:** editing `features.flags` to `{"key": {"enabled": true}}` (the format the template itself uses!) silently disables ALL flags in core (→ P1-WL-1); editing halal's empty `firebaseAndroidApiKey` leaves (→ P0-WL-1).

## 1.3 CLIENT-SPECIFIC VALUES HARD-CODED OUTSIDE CONFIG — ❌ FAIL

### (a) Grep results (exact counts, verbatim)
- **`Color(0x` in core_app/lib:** 0 matches — theme colors all flow from config or `AppTheme` constants ✅.
- **Hex string literals matching `0xFF[0-9A-F]{6}` in core_app/lib:** 0 matches outside `client_config.json` and `app_config.dart`'s own `_colorFromHex` parser ✅.
- **Brand-name literals:** grep `Carnama` in `core_app/lib/app/brand_drawer.dart` + `app_router.dart`: **0 matches** — display strings are fully `AppConfig.appName`/config-driven ✅ (only doc comments in `app_config.dart` mention the core brand; no runtime literal).
- **halal_boyz/lib `Color(0x` / hex:** 0 matches; halal screens use `Theme.of(context)` + config colors only (`home_screen.dart`, `menu_screen.dart` grep clean) ✅.
- **Hard-coded identity tokens in `whitelabel.dart` (deliberate fragment-based guard, `whitelabel.dart:225-251`):** exactly 4 fragments, built by string-concatenation so the generator source itself never contains the literals (banned repo-wide by grep gates): Cloudinary preset fragment `carnama_`+`unsigned`, cloud fragment `dcqf9`+`qpsq`, LAN IP `192.168.1.`+`100`, bundle id `com.carnama.`+`app`. Guard is real but narrow — e.g. Carnama's Firebase sender-id/API-key fragments are NOT in the list (→ P2-8).

### (b) Full inventory of identity leakage outside `client_config.json`
| # | File | What's hard-coded | Tier | Fix tier |
|---|---|---|---|---|
| H-1 | `core_app/assets/client_config.json` | `environment.firebaseAndroidApiKey:""` / `firebaseIosApiKey:""` while the generated shell's `FirebaseOptions` uses them with `?? ''` fallback (halal `main.dart:25-28`) | **P0** | template values |
| H-2 | `core_app/.env` (tracked in git, `git ls-files` verified) | No secret today; tracked env file + no `*.env` rule in any `.gitignore` invites future secret commits | P2 | untrack; add `*.env` to gitignore |
| H-3 | — | **No finding:** zero brand literals in `core_app/lib/app` (grep-verified) | PASS | — |
| H-4 | `apps/halal_boyz/lib/app/currency_config.dart` | currency logic outside JSON — but JSON is authoritative; generator templates it from `config.currency` (`whitelabel.dart:363-364, 1344-1363`), USD fallback if absent | PASS (see P2-6) | keep |
| H-5 | `apps/halal_boyz/assets/client_config.json` | `stripePublishableKey:"pk_test_REPLACE_ME..."` placeholder survives into config — **but the generated shell gates on it**: `_merchantConfigured` (template `whitelabel.dart:705-716`) requires non-empty, non-`REPLACE_ME` key, else checkout Place-Order stays disabled (honesty gate, widget-tested at `whitelabel.dart:1444`) | PASS (gate verified) | fill real key per client |
| H-6 | `core_app/tool/whitelabel.dart` | Firebase API keys are NOT covered by any placeholder/empty gate (unlike stripe above) — empty `""` values pass `validate()` (68-92) and ship | **P0** (root of H-1) | extend `validate()` to fail on empty firebase api keys for generated shells |

**Generator coverage (asset writing):** `whitelabel.dart` writes/renames: launcher icons (both platforms via `flutter_launcher_icons`), splash assets, `google-services.json`, `GoogleService-Info.plist`, copies `assets/` images. **Gaps:** no `AndroidManifest.xml` `android:label` rewrite step found in the script's write list; no `Info.plist CFBundleDisplayName` rewrite found (name fix relies on config at runtime, plist stays generic) — cosmetic-only for Android label, **real store-listing mismatch for iOS display name** (→ P2-3).

## 1.4 THEME/BRAND CONSISTENCY (CONFIG vs BUILT-IN) — ❌ FAIL

**Config theme (both configs identical here):** primary `0xFFFF6B00` (orange), secondary `0xFF1D3557` (navy), accent `0xFFF4A261`, full neutral set, darkTheme bg `0xFF121212`/surface `0xFF1E1E1E`, confetti `0xFFE63946/0xFF1D3557/0xFFF4A261/0xFF2A9D8F` (core:108-132 / halal:113-136).

**Built-in `AppTheme` constants (`packages/core_ui/lib/src/theme/app_colors.dart`):** `primary 0xFFFF6B00`, `secondary 0xFF1D3557`, `accent 0xFFF4A261`, `error 0xFFE53935`, `success 0xFF4CAF50`, `warning 0xFFFFC107` — **byte-identical palette to config defaults**. `AppTheme.buildTheme/buildDarkTheme` (packages/core_ui/.../app_theme.dart) parse the same keys, so divergence is impossible today ✅.

**Where it still diverges / risks:**
- **TH-1 (P1-WL-2):** any widget using `AppColors.*` directly instead of `Theme.of(context)` ignores per-client overrides entirely. Grep shows direct `AppColors.` usage across `core_app/lib` (dozens of hits, e.g. drawers, cards, badges). Today invisible (palettes match); the first client with a different palette gets a mixed-brand UI. This is the single largest latent white-label defect.
- **TH-2 (P2):** `typography.fontFamily: "System"` — no bundled font asset, no `pubspec` font registration for either app; any future `fontFamily` value other than "System" will silently fall back (no font asset loading path exists in `AppTheme`).
- **TH-3 (PASS):** dark theme parses and both `theme`/`darkTheme` are consumed via `MaterialApp` (`core_app/lib/main.dart` MaterialApp wiring; halal `app.dart`).
- **TH-4 (PASS):** confetti colors config-driven with neutral fallback (`app_config.dart:251-265`).

## 1.5 FEATURE-FLAG/NAV CONSISTENCY (JSON vs CODE DEFAULTS) — ❌ FAIL

- **FF-1 (P1-WL-1, format mismatch):** config values are objects `{"enabled":true}`; parser `app_config.dart:273-275` accepts only `v is bool`, so **every flag silently resolves to `featureFlagDefault`** (core: `false`; halal shell has its own gate). Grep: `featureFlagsProvider`/`.isEnabled(` consumers exist in core (owner dashboard, ordering, referrals modules) — all currently read defaults, not the configured values. The template's own format is incompatible with its own parser.
- **FF-2 (PASS):** `unknownFlagDefault` honored (`app_config.dart:277-280`); `AppConfig.featureEnabled(key)` fail-safe default (143-144).
- **FF-3 (P2):** `navigation.routes` parsed but unconsumed in core (see §1.1) — config promises route aliasing that core ignores.
- **FF-4 (PASS):** `navigation.tabs`/`hiddenRoutes`/`entryPoint` all consumed (core `app_router.dart` tabs builder + drawer filter; halal shell same pattern).
- **FF-5 (PASS):** route→flag guards: `_buildRoutesFromConfig` + per-route `featureEnabled` checks in `app_router.dart` keep hidden features unroutable even if deep-linked.
- **FF-6 (PASS):** `screens[].mandatory` unenforced (dead), so no over-promise — flagged in §1.1.

## 2. GENERATOR (`core_app/tool/whitelabel.dart`) — MIXED

**Verified PASS items:**
- Full pipeline present and coherent: parse args → load+validate config (5 sections, name/bundleId required, `whitelabel.dart:68-92`) → forbidden-token check → create `apps/<dir>/` (dir derived from `app.name` slug) → template-substitute Dart → write platform identity files (gradle `applicationId`, pbxproj `PRODUCT_BUNDLE_IDENTIFIER`) → regenerate `google-services.json` / `GoogleService-Info.plist` → copy assets → launcher icons + splash.
- **Reproducibility:** output dir derived from `app.name` slug, NOT hard-coded — regenerating halal with the same config reproduces the same tree ✅.
- **Post-generation `flutter analyze --fatal-infos` is ENFORCED, not optional:** `_runAnalyze()` runs it and on failure prints `"ANALYZE FAILED - generated app did not pass flutter analyze --fatal-infos. Stopping."` and aborts (`whitelabel.dart:285-289, 514-516`) ✅ — stronger than most generators.
- **Overwrite protection:** existing target dir → `ERROR: Target app directory already exists` and stop, unless `--regenerate` is passed explicitly (`whitelabel.dart:260-268`) ✅ — no silent destruction of manual changes.
- **Checkout honesty gate templated:** `_merchantConfigured` requires a real (non-empty, non-`REPLACE_ME`) `stripePublishableKey`, else checkout never fakes success (`whitelabel.dart:705-716`), enforced by generated widget test (`1444`) ✅.
- **Generated app ships with widget tests:** config-driven title (`1263`), honest checkout (`1444`), integer priceCents via config currency (`1503`), plus a test that FAILS if any generated file hard-codes a currency literal (`1534`) ✅.
- **No secrets in templates:** generated Dart reads keys from config/dart-define; template contains no live values ✅.

**Gaps (each mapped to findings):**
| # | Gap | Finding |
|---|---|---|
| G-1 | `validate()` does not require/validate the `currency` section although generated shell consumes it; missing section silently degrades to `CurrencyConfig(code: 'USD')` (`whitelabel.dart:1352-1363`) — a non-USD client could ship showing USD with no error | P2-6 |
| G-2 | `validate()` has no empty/placeholder gate for `environment.firebaseAndroidApiKey`/`firebaseIosApiKey` (unlike the stripe gate it templates) — empty `""` ships and silently disables Firebase at runtime | **P0-WL-1** |
| G-3 | No `AndroidManifest.xml` `android:label` / `Info.plist CFBundleDisplayName` rewrite — generated plist/manifest keep the generic label (grep: zero handling); store listings show wrong display name until hand-edited | P2-3 |
| G-4 | No schema/type/range validation of theme hex values at generation time (bad hex only fails later, silently, per §1.2c-3) | P2-4 |
| G-5 | Forbidden-token list covers only 4 fragments (Cloudinary preset/cloud, LAN IP, bundle id); Firebase sender-id / API-key / project-id fragments not covered | P2-8 |

## 3. BRANDING ASSETS AUDIT — MIXED

**Inventory (bytes verified):**
- core_app: `assets/client_config.json`, `assets/logo.png`, `assets/logo_nobackground.png` — declared in `core_app/pubspec.yaml` assets list ✅.
- halal_boyz: own `client_config.json` + copied brand images; declared in halal `pubspec.yaml` ✅.
- Android launcher icons: `apps/halal_boyz/android/app/src/main/res/mipmap-*/ic_launcher.png` present at all densities (generated by `flutter_launcher_icons`) ✅.
- iOS AppIcon: `apps/halal_boyz/ios/Runner/Assets.xcassets/AppIcon.appiconset/` exists ✅.
- Splash: generator writes splash assets + `flutter_native_splash`/launcher-icons config in generated pubspec ✅.
- **AS-1 (P2):** core_app's own `logo.png` is Carnama-branded; generator copies assets per-client so no cross-client leak **if** clients always regenerate — but there is no guard preventing a generated app from keeping core's logo if config omits a logo path (asset copying is template-dir based, not config-key based) → fold into P2-3.
- **AS-2 (PASS):** no `assets/` string reference in any screen bypassing config; grep `assets/` in halal lib shows only `main.dart:13` (the config path) — screens use theme/config, not raw asset paths ✅.
- **AS-3 (PASS):** both configs valid JSON (`ConvertFrom-Json` clean).

## 4. CONSOLIDATED FINDINGS REGISTER

### P0 (release blockers — 3)
| ID | Finding | Evidence | Fix |
|---|---|---|---|
| **P0-WL-1** | **Firebase silently disabled in every generated shell.** Template config ships `firebaseAndroidApiKey`/`firebaseIosApiKey` as `""` (core:21-22, halal:34-35); generated `main.dart` builds `FirebaseOptions(apiKey: environment[...] ?? '')` (halal `main.dart:25-28`) → `Firebase.initializeApp` throws → the throw is swallowed: `catch (_) { debugPrint('Firebase initialization skipped; continuing offline.'); }` (`main.dart:53-55`) → app runs with NO auth/Firestore/FCM and **no operator-visible error**. `validate()` (whitelabel.dart:68-92) never checks these keys, and unlike stripe there is no `_merchantConfigured`-style gate for them | halal `main.dart:25-28, 49-55`; both configs; `whitelabel.dart:68-92` | (a) extend `validate()` to require non-empty firebase API keys for generated shells, and (b) make the generated shell fail fast (or show a blocking screen) when they are empty instead of silently continuing offline |
| **P0-WL-2** | **All feature flags silently dead in core.** Config stores `{"flag":{"enabled":true}}` objects (core:66-74); parser accepts only `v is bool` (`app_config.dart:270-277`, verified verbatim) → `_featureFlags` is always `{}` → every `featureEnabled`/route-guard consumer resolves to `unknownFlagDefault`. Gating is fiction; template format is incompatible with its own parser | core config:66-74; `app_config.dart:270-280`; router guard consumers | Pick ONE format repo-wide (recommend flattening configs to `"flag": true`, matching the parser), then add a `validate()`/unit check that parsed flags are non-empty when config declares flags |
| **P0-WL-3** | **Latent theme bypass at scale.** Direct `AppColors.*` usage across `core_app/lib` widgets bypasses config theme. Palettes are byte-identical today (§1.4) so nothing visibly breaks — the first client with a different palette gets a mixed-brand UI in production | §1.3a/§1.4 grep; `app_colors.dart` constants vs config colors | Migrate to `Theme.of(context)`/`ColorScheme` or add a lint banning `AppColors.` outside core_ui; verify with a distinct-palette test config |

### P1 (must fix before multi-client launch — 5)
| ID | Finding | Evidence |
|---|---|---|
| P1-WL-1 | (=P0-WL-2 root) Flag defaults silently govern production behavior — no error, no log surfaced to the operator | `app_config.dart:270-277` |
| P1-WL-2 | (=P0-WL-3 tracking) No `AppColors`-usage lint or aliasing layer exists | repo grep |
| P1-WL-3 | Same concept read from different keys per app: core parser reads `environment.firebaseProjectId` (`app_config.dart:218-220`), generated shell reads `firebase.projectId` (halal `main.dart:32`) — drift guaranteed as configs evolve | two parsers compared |
| P1-WL-6 | `AppConfig.loadError` is recorded but never surfaced anywhere in core UI — silent fallback to default branding in production builds | `app_config.dart:100-101, 317-322`; zero render references (grep) |
| P1-WL-8 | **Generated shell's config loader is not resilient** (core's Phase 2.2 fallback rule not carried into the template): `_loadClientConfig()` does a bare `rootBundle.loadString` + `jsonDecode` with NO try/catch (halal `main.dart:15-18`) — a missing/malformed `client_config.json` crashes the generated app at boot, while core degrades gracefully (`app_config.dart:317-322`) | halal `main.dart:15-18` vs core `app_config.dart:189-193, 317-322` |

### P2 (polish / debt — 8)
1. **Dead config keys** (§1.1 table): `app.primaryColor`, `app.fontFamily`, `environment.stripePublishableKey` (core parser), `recaptchaWebKey`, `firebaseAndroidApiKey`/`firebaseIosApiKey` (core parser), `kitchenLanEndpoint` (core), `firebase.projectId` (core), `firebase.collections`, `clientScopingFields`, `configDocuments`, `tax.*`, `navigation.routes` (core), `screens[].mandatory`, `newFeatures` — prune or implement.
2. **`typography.fontFamily` unsupported beyond `"System"`** — no font asset path exists in `AppTheme`; future values silently fall back.
3. **No `AndroidManifest.xml` `android:label` / `Info.plist CFBundleDisplayName` rewrite** in the generator — generated platform files keep generic display names (grep: zero handling in `whitelabel.dart`).
4. **No generation-time theme validation** — bad hex/type values pass `validate()` and only fail later, silently, via per-key runtime fallbacks (§1.2c-3).
5. **Parsed-but-unconsumed in core:** `navigation.routes` (parsed, zero core consumers — only the generated shell uses its copy) and `screens[].mandatory` (parsed raw, never evaluated) — implement or remove from schema.
6. **Versioned config schema missing:** `_meta.schemaVersion` present in configs but unused in code (grep zero hits); template config lacks a `currency` reference section although the generated shell consumes it (silent USD fallback, `whitelabel.dart:1352-1363`); add a post-generation identity consistency check (gradle `applicationId` == pbxproj `PRODUCT_BUNDLE_IDENTIFIER` == `app.bundleId`).
7. **`core_app/.env` tracked in git** with no `*.env` rule in any `.gitignore` (verified: no secrets in the file today — keep it that way by untracking and ignoring it).
8. **Forbidden-token list narrow:** 4 fragments only (`whitelabel.dart:228-233`); Carnama's Firebase sender-id/API-key/project-id fragments are not covered — a copied Carnama `firebase` section would pass the guard.

## 5. HONEST LIMITATIONS (what this audit could NOT verify from static analysis)

1. **Runtime boot behavior** — claims like "app still boots on malformed config" follow from code paths (`app_config.dart:317-322` try/catch) but no emulator run was performed in this audit.
2. **Actual icon/splash pixel content** — file existence and generator wiring verified; whether the generated PNGs visually match Halal Boyz branding was not image-inspected.
3. **`flutter_launcher_icons` regeneration success** — pubspec config present; the icon generation was not re-executed (it mutates files; audit is report-only).
4. **iOS build** — `project.pbxproj` identity lines verified textually; no Xcode build performed (Windows environment).
5. **Firebase project state** — whether `demo-tenant` actually exists / matches the regenerated `google-services.json` is outside repo evidence.
6. **Secret exposure** — `core_app/.env` was verified to contain NO secrets (key list + values inspected; Cloudinary value is the public unsigned-upload preset). Full git-history scan for previously committed secrets was out of scope.

## 6. RECOMMENDED REMEDIATION ORDER (highest production leverage first)

1. **P0-WL-1** — extend generator `validate()` to require non-empty firebase API keys; make the generated shell fail fast/block instead of silently continuing offline; fill the template + halal configs (small, high leverage).
2. **P0-WL-2** — flatten `features.flags` values to `bool` in both configs (parser already matches); add a flag-parse check to `validate()`.
3. **P1-WL-8** — wrap the generated shell's config load in the same try/catch fallback rule core uses (template-only change).
4. **P1-WL-3** — unify the firebase projectId key across both parsers; **P1-WL-6** — surface `loadError` in debug builds.
5. **P0-WL-3** — `AppColors` migration: start with a lint, migrate per-feature (largest, do incrementally).
6. P2 list in order above (P2-7 `.env` untrack is a 2-minute gitignore change).

## 7. FINAL VERDICT

**❌ FAIL for multi-client production as-is.** The architecture is sound and the generator is genuinely strong — enforced `--fatal-infos` analyze, explicit overwrite protection, an honest checkout gate, generated widget tests, defensive core parsing, and zero hard-coded brand literals are all verified facts. Three P0s break the "one config change = new brand" promise today: **(1)** empty Firebase API keys ship through validation and are then silently swallowed at runtime, disabling auth/Firestore/FCM in every generated shell with no error; **(2)** the config's own flag format is incompatible with the parser, so feature gating is silently inert in core; **(3)** direct `AppColors` usage is a loaded trap that fires the moment a client's palette differs. All fixes are small, well-scoped, and require no architectural change.

*End of report.*








