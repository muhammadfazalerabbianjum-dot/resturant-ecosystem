# CLIENT GENERATOR — BRANDING & CONFIG CHANGE-POINT MAP (authoritative)

**Purpose:** the single reference for "to change X in a client app, edit Y." Every
row is traced to the code that reads it and proven by the generator's gates.
**Generator:** `core_app/tool/whitelabel.dart` (4727 lines). **Runtime consumer:**
`package:labs` (`core_app`) via `AppConfig` + `AppTheme`. **Proof:** p36
attestation signed 2026-10-08 (`tool_uilib/p36/receipts/attest_*.txt`); re-verified
green at today's tip (dry-run EXIT=0, tool suite +239).

---

## 0. The one architectural fact that prevents mistakes

The generator is a **THIN-SHELL FACTORY**. It does NOT transform branding — it:

1. **Copies `client_config.json` byte-identical** into `apps/<app>/assets/`
   (`_copyClientConfig`, whitelabel.dart:2267). The ONLY exception: an explicit
   `--template minimal|modern|classic` seeds *absent* theme keys (fill-missing);
   it never overwrites an owner-authored value, and never rewrites the source.
2. The generated shell's `main.dart` is a thin wrapper that loads that config and
   calls the SHARED `initCarnamaApp` (`package:labs`), which hydrates `AppConfig`
   statics (STEP 07). Every screen, router, palette, and en+ar l10n come from
   `package:labs`.

**⇒ To change branding, you edit `client_config.json`. You do NOT edit generated
app code.** The config is the single source of truth (Law 3).

---

## 1. Every config key → where it lands (traced + proven)

### 1a. Identity / platform (native, fail-closed)

| Config key | Lands in | Gate that protects it |
|---|---|---|
| `app.name` | launcher label, iOS `CFBundleDisplayName`, privacy usage strings, package dir slug | B7-2 identity fast-fail; `generatedIdentityErrors` (exit 71) |
| `app.bundleId` | Android `applicationId`, iOS `PRODUCT_BUNDLE_IDENTIFIER`, org prefix | identity check: `applicationId == pbxproj == bundleId` (exit 71) |
| `app.icon` | `tool/branding/app_icon.png` → `flutter_launcher_icons` (all densities) | PNG-signature + ≥512×512 check; branding fail-closed (exit 75) |
| `app.storeAndroidUrl` / `app.storeIosUrl` | store-rating deep links | completeness warning only |
| `app.fcmChannelDescription` | Android notification channel | — |

### 1b. Theme colors — the AUTHORITATIVE path is `theme.colors.*`

`AppTheme._cfgColor(theme, key)` reads **`theme.colors[key]`** (app_theme.dart:410).
Do NOT put colors at `theme.primary` (top level) — that is ignored. Valid keys
(live halal_boyz values shown):

| `theme.colors.*` | Consumed by | halal_boyz value |
|---|---|---|
| `primary` | ColorScheme.primary, buttons, FABs | `0xFF900000` |
| `secondary` | ColorScheme.secondary | `0xFFFFA500` |
| `accent` | BrandColors.accent | `0xFFFFA500` |
| `background` | scaffold background (light) | `0xFFF9F9F9` |
| `surface` | cards, sheets, surfaces | `0xFFFFFFFF` |
| `textPrimary` / `textSecondary` | body/heading text | `0xFF111111` / `0xFF666666` |
| `error` / `success` / `warning` / `soldOut` | semantic states | red / green / amber / grey |
| `textPrimary12` / `45` / `54`, `background54` / `70`, `transparent` | opacity variants | see config |

Format: `0xRRGGBB` or `0xAARRGGBB` or bare `RRGGBB` (alpha defaults FF).
Any missing/empty key falls back to `AppColors` (Law 3) — never a crash.

**Dark theme:** `theme.darkTheme.*` (same key vocabulary) → `buildDarkTheme`.
`theme.background.color` (top-level, separate from `colors`) seeds the NATIVE
splash background; `theme.darkTheme.background` for night.

### 1c. Typography

| Key | Lands in | Guard |
|---|---|---|
| `theme.typography.fontFamily` | body font | must be a REGISTERED bundled font (Inter/PlayfairDisplay shipped) or `System`; unregistered → explicit `fontLoadError` + safe fallback (never silent) |
| `theme.typography.headingFont` | headings | same registered-font guard |
| `theme.typography.bodyFont` | body | same |
| `theme.typography.{headline,title,body,caption}Size` | text scale | — |


### 1d. Shape / spacing / components / signature

| Key | Lands in |
|---|---|
| `theme.shape` | `RoundedRectangleBorder` radius on branded surfaces |
| `theme.shape.style` | **one-key form preset** `sharp`\|`soft`\|`round`\|`pill` (sets card/cta/small radii; an explicit `theme.shape.*Radius` overrides it; absent = today). Generator and the runtime config validator both fail closed on an unknown value. |
| `theme.depth` | **one-key depth preset** `flat`\|`soft`\|`elevated` (Material elevation on the 5 flat card/tile surfaces — brand_card, menu_tile, setting_tile, status_tile, stat_tile; absent = `flat` = today byte-for-byte). Generator and the runtime config validator both fail closed on an unknown value. |
| `theme.spacing` | layout spacing tokens |
| `theme.components` | per-component knob overrides |
| `theme.signature` | signature visual style |
| `theme.confettiOverlay.colors[]` | celebration confetti palette |
| `theme.background.overlayAsset` | decorative scaffold overlay (null = none) |

### 1e. Navigation (drives the router)

| Key | Lands in |
|---|---|
| `navigation.entryPoint` | first route after splash |
| `navigation.tabs[]` | bottom-nav tab routes |
| `navigation.hiddenRoutes[]` | routes removed from this client |
| `navigation.routes{}` | logical-name → path map (27 routes) |

### 1f. Features (flag surface)

| Key | Lands in |
|---|---|
| `features.flags{}` | `map<String,bool>` — must be non-empty, all-bool (W6.2); object-valued flags are silently dropped → gating inert, so blocked |
| `features.unknownFlagDefault` | default for an unrecognized flag |

Live flags: `smartReorder, loyaltyPoints, tourMode, waitlist, deliveryTracking, promoCode`.

### 1g. Firebase / environment (fail-closed — the boot gate)

| Key | Lands in | Gate |
|---|---|---|
| `firebase.projectId` | emulator/project target | must be non-empty, non-placeholder; boot blocked otherwise |
| `firebase.androidAppId` / `iosAppId` / `messagingSenderId` / `storageBucket` | `firebase_options.dart` emission | identity pin vs native google-services |
| `environment.firebaseAndroidApiKey` / `firebaseIosApiKey` | `firebase_options.dart` + runtime W6.1 gate | **fail-closed: empty/placeholder = boot renders ConfigErrorScreen, never a silent auth-less shell** |
| `environment.stripePublishableKey` | `--dart-define` resolver (env → config → fail) | placeholders never reach the build |

### 1h. Money / branches / delivery

| Key | Lands in |
|---|---|
| `currency.code` / `currency.symbol` | money display (p37 T-3) |
| `branches.defaultBranchId` | default branch |
| `deliveryPlatforms[]` | UberEats/DeliveryHero adapters (validated vocab; forbidden credential prefixes blocked) |

### 1i. Schema meta

| Key | Rule |
|---|---|
| `_meta.schemaVersion` | generator speaks exactly ONE version; a mismatch refuses generation |

---

## 2. Fail-closed gates (a mistake can never ship silently)

In `run()` order (whitelabel.dart:2116):
1. **Forbidden identity** (`_checkConfigForbiddenTokens`): any Carnama live token
   (project id, sender id, bundle id, LAN IP, Cloudinary) → hard throw.
2. **`validate()`** (unknown top-level key, missing section, placeholder key,
   bad icon, non-bool flag, schema-version mismatch) → blocks.
3. **Identity parity** applicationId==pbxproj==bundleId → exit 71.
4. **Stripe/AppCompat aligner** (MaterialComponents theme, FragmentActivity) —
   re-run as the LAST writer after branding (S8: flutter_native_splash rewrites
   styles.xml) → API-31+ devices never die in flutter_stripe.
5. **flutterfire** failure → exit 74 unless `--skip-firebase` (operator attest).
6. **Branding tools** (launcher_icons + native_splash) failure → exit 75.
7. **analyze** (`--fatal-infos`) → exit 70.
8. **emitted 49-test battery** → exit 72.
9. **debug APK build** (resolved Stripe key) → exit 73.

## 3. Proven status (today, 2026-10-14)

- dry-run EXIT=0 (emits 49 tests, all gates listed) · tool suite **+239** (all 12
  `whitelabel_*` suites) · p36 attestation signed (fresh stamp → 49/49 → APK →
  emulator boot populated, 0 stripe/theme/fatal).
- **Residuals (honest):** iOS real-device build unproven (machine scope);
  NEW Firebase projects need an operator `flutterfire` login; Windows can't
  produce the iOS plist (attested path only).

## 4. Operating a new client — the safe sequence

1. Copy `apps/halal_boyz/assets/client_config.json` as the starting template.
2. Edit ONLY the keys in §1 (identity, `theme.colors.*`, typography, nav, flags,
   firebase, currency). Never put colors at top-level `theme.*`.
3. Supply a real ≥512×512 `app.icon` PNG next to the config.
4. `dart run tool/whitelabel.dart --config <path> --dry-run` → confirm EXIT=0.
5. `dart run tool/whitelabel.dart --config <path>` → stamp + gates.
6. Boot the emulator → confirm real screens (no ConfigErrorScreen).

