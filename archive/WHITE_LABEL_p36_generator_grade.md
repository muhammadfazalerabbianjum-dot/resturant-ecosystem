# WHITE_LABEL_p36 — GENERATOR-GRADE: make `whitelabel.dart` production-grade

**Tag:** GEN-GRADE · **Predecessor:** p32/p34 branch work (committed) · **Emulator:** T-5 only (attestation boot)
**Territory (owns):** `core_app/tool/whitelabel.dart` · `core_app/test/tool/whitelabel_*` (new suites) · `core_app/android/**` (template styles parity) · emitted pubspec template · `apps/halal_boyz/assets/client_config.json` + `core_app/assets/client_config.json` (icon key) · `tool_uilib/p36/**` · this spec. **NEVER:** goldens, `firestore.rules`, `functions/**`, `lib/features/**`.

## 0. Evidence table (inspection 2026-10-07, orchestrator session)

| ID | Finding | Proof |
|---|---|---|
| S1 | Generator never emits/patches `MainActivity.kt` or `styles.xml`; fresh `flutter create` ships `FlutterActivity` + `@android:style/*` parents → flutter_stripe rejects → fail-closed boot | grep 3,922 lines: 0 hits; `git show d76bcdd2^` stock baseline; red→green `apps/halal_boyz/test/stripe_android_gate_test.dart` (2+2) |
| S2 | `run()` ends at `flutter analyze` (exit 70) — the 12 emitted guards incl. `app_launch_test` never execute; no build/boot gate | `whitelabel.dart:1666-1742`; tests use `scratchApp()` fixtures only (`whitelabel_backend_bundle_test.dart:37`) |
| S3 | `_maybeRunFlutterFire` fail-open: WARNING + continue → stamp can complete with no google-services files | `whitelabel.dart:1962-1970` |
| S4 | Shipped-vs-emitted drift = 5 CONTENT-DRIFT + 4 SHIPPED-ONLY rows; contradicts "generator stays the only source of truth" (1671) | `FIX_VERIFICATION.md:5989` (p25 residual, "regeneration wave owns") |
| S5 | Zero icon/splash surface (no config key, schema entry, emitter) — fresh client ships Flutter default icons | grep `ic_launcher|splash|logo` = 0 emission hits; register issue 9 |
| S6 | Attestation L ("stamps a fresh client from config alone and boots REAL screens") never signed | no attestation matrix exists in `FIX_VERIFICATION.md` |
| M1 | Mirror-rule gap: `core_app` template MainActivity ✅ Fragment, but **all 5 styles.xml** still plain (`Theme.Light/Black.NoTitleBar`, incl. `values-v31`) | live read 2026-10-07 (deferred p34-4) |

## 1. Design principles (no suboptimal approaches)

1. **Clone the proven aligner pattern** (`alignReleaseSigningGate:893`): pinned byte-exact anchors, idempotent second-run no-op, half-applied/unrecognized shape = `StateError` (fail-closed).
2. **Mirror rule:** fix `core_app` template FIRST, generator emission second, shell parity third.
3. **Pins come from shipped truth** (`git show d76bcdd2`): `values` → `@style/Theme.MaterialComponents.Light.NoActionBar`; `values-night` → `@style/Theme.MaterialComponents.NoActionBar`; MainActivity → `FlutterFragmentActivity`.
4. **Dev-only deps are legal** (§0 rule 3 bans RUNTIME deps): `flutter_launcher_icons` + `flutter_native_splash` = industry-standard raster pipelines replacing custom PNG code; emitted into the generated app's `dev_dependencies` only; APK budget untouched.
5. **Tests never touch the live shell:** regeneration/parity runs in temp dirs (`Directory.systemTemp` pattern from `whitelabel_backend_bundle_test.dart:29`).
6. **Attestation L uses `--skip-firebase`:** `flutterfire configure` would REGISTER apps in the Firebase project = a write against production; the stamp proves "config alone" with the shipped config bundle instead (matches row L wording).

## 2. Acceptance contract (the 100% definition)

- **A1** `alignStripeAndroidGate(appPath)` exists, called in `run()` after `alignReleaseSigningGate`, idempotent + fail-closed (T-1).
- **A2** `core_app` template styles (all 5 files) carry Material parents; template MainActivity pin asserted (T-2). Halal shipped files stay byte-identical (already correct).
- **A3** `run()` fail-closed end-to-end: flutterfire failure = exit 74 unless `--skip-firebase`; `flutter test` gate = exit 72; `flutter build apk --debug` gate = exit 73 with `STRIPE_PUBLISHABLE_KEY` resolved env → config (non-placeholder) → hard fail.
- **A4** Icon+splash stamping: `app.icon` (required, PNG, ≥512², fail-closed in `validate()`), emitted `flutter_launcher_icons.yaml` + `flutter_native_splash.yaml` from config, tools run during generation; BOTH shipped configs carry key + asset.
- **A5** Generated apps receive the stripe gate test (13th emitted test) — a fresh stamp can never regress S1 silently.
- **A6** **Attestation L signed:** fresh stamp in temp dir → test gate → debug build → emulator boot `NO_BOOT_ERRORS` + populated screenshot; receipt `tool_uilib/p36/receipts/` + attestation row in `FIX_VERIFICATION.md` with tip hash (T-5).
- **A7** Regen-parity: regenerated emission diff vs shipped = 0 rows (p25's 5+4 closed by disposition), pinned as a permanent test (T-6).
- **A8** Gates green: analyze ×4, `dart format` 0, core_app suite green (incl. new T-x), halal suite green, dry-run `EXIT=0`.

## 3. T-x test table (RED → GREEN per task)

| T | RED (must fail first) | GREEN (proof) |
|---|---|---|
| T-1 | `whitelabel_stripe_android_gate_test.dart` compiles against missing `alignStripeAndroidGate` → red; stock-fixture subcases assert gated output | stock fixture → gated bytes match shipped pins; second run byte-identical (idempotent); garbage fixture → `StateError` |
| T-2 | `whitelabel_template_parity_test.dart`: planted plain-parent fixture → red | live `core_app/android` read: every `styles.xml` parent ∈ Material set; MainActivity = Fragment; halal files byte-unchanged vs `d76bcdd2` |
| T-3 | `whitelabel_run_gates_test.dart`: stripe-define resolver (env → config → fail) red on unimplemented resolver | resolver cases green; `--skip-firebase` flag parse green; exit codes 72/73/74 pinned in doc + receipts from real runs |
| T-4 | `whitelabel_icon_stamps_test.dart`: validate() accepts config missing `app.icon` → red | missing/not-PNG/too-small → error list; emitted YAML matches config; tools in emitted pubspec dev_deps |
| T-5 | attestation receipt absent → red-by-absence | **SIGNED 2026-10-08:** `receipts/attest_full_run.txt` (regenerate EXIT=0: identity ✓, branding ✓, analyze gate ✓, emitted 49/49 ✓, `✓ Built app-debug.apk`) + `receipts/attest_boot_green.txt` (fresh dumps root pkg `labs.carnama.p36attest`: consent gate 4 nodes → tap Accept → menu screen 23 nodes, `P36 Attest` brand, no ConfigErrorScreen; logcat stripe/theme/fatal = 0) + `attest/boot_menu.png` `VERDICT: populated - all bands carry content` |
| T-6 | parity harness red on the current 5+4 drift rows | each row dispositioned; emitted-vs-shipped diff = 0; test pins it |

## 4. Proof gates (run after each task; receipts `tool_uilib/p36/receipts/gate_*.txt`)

`flutter analyze --fatal-infos` (core_app + halal) · `dart analyze` (packages) · `dart format --output=none --set-exit-if-changed .` · core_app suite · halal suite · `whitelabel.dart --dry-run` EXIT=0 · T-5 emulator proof (AVD `Medium_Phone_API_36.1`, recipe `core_app/tool/run_integration_tests.ps1`: `USE_EMULATOR=true`, `STRIPE_PUBLISHABLE_KEY=pk_test_FAKE`).

## 5. Honest residuals (declared upfront)

- iOS real-device build unproven (machine scope) — plist/privacy emission covered by emitted `platform_privacy_test` only.
- `flutterfire` online path proven for the P36 fixture (reconfigure on an already-registered project, `receipts/attest_full_run.txt`); NEW projects still need an operator Firebase login.
- p35 Theme-V2 (per-client visual epic) stays out of scope; only icon+splash stamping moves here (register issue 9 re-owned by p36).

## 6. Attestation L findings (live defects found & fixed, red → green)

The attestation earned its keep — every gate below failed a real stamp before it passed:

| # | Defect found live | Fix | Proof |
|---|---|---|---|
| S7a | `!appDir.existsSync()` dead guard: fresh stamps never joined the workspace → `flutter pub get` failed | workspace registration unconditional (`workspaceChanged` path) | `whitelabel_run_gates_test.dart` S7 group |
| S7b | Root `build.gradle.kts` lacked the AGP-8 `setNamespace` shim → isar codegen build fail | `alignAndroidNamespaceShim` (EOL-aware, CRLF-preserving), fail-closed `StateError` | `whitelabel_namespace_shim_test.dart` (5+1), live stamp shim present |
| S8 | **Sequencing:** `_runBrandingTools()` (flutter_native_splash `[Android] Updating styles...`) rewrote `values-v31/styles.xml` to stock parents AFTER `alignStripeAndroidGate` → rebuilt stamp died in `flutter_stripe` on API-31+ (theme not MaterialComponents) and booted ConfigErrorScreen | re-run the idempotent aligner AFTER branding so it is the LAST writer; pinned by source-order test | `whitelabel_run_gates_test.dart` T-8 group; post-regen all 4 `styles.xml` Material-pinned; logcat stripe/theme errors = 0 |
| — | Windows cannot produce the iOS plist (`flutterfire configure` is macOS-only) | `_ensureAppleServiceFiles` patches `core_app/firebase.json` ios entry + `flutterfire reconfigure` (2 retries), fail-closed exit 74 | T-6 plist tests green |

Final gate tally (this session): tool suite 231 ✓ · core suite 2500 ✓ · halal 77 ✓ · analyze ×4 = 0 · format repo 0 · dry-run EXIT=0 · full regenerate EXIT=0 · emulator boot populated (receipts/attest_boot_green.txt).

