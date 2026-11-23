# Carnama Labs — Release Runbook (RELEASE-1 / W11)

This runbook is the operational half of the release pipeline. It documents
**Android signing**, the **CI release job**, the **fastlane** lanes, and
**version discipline** (melos + `tool/tag_release.dart`). The iOS release
build remains a documented **macOS-only** step — there is no macOS runner in
CI (honest limitation, spec 30.5) — and is executed manually via the legacy
`core_app/ios/fastlane` scaffold.

---

## 1. Android release signing (fail-closed)

1. Copy the template: `core_app/android/key.properties.template` →
   `core_app/android/key.properties`.
2. Fill in: `storeFile` (relative to `core_app/android/app/`, e.g.
   `keystore.jks`), `storePassword`, `keyAlias`, `keyPassword`.
   The keystore itself (`*.jks`) lives next to it, e.g. `core_app/android/app/keystore.jks`.
3. **Never commit**: `key.properties`, `*.keystore`, `*.jks` are gitignored
   (root + `core_app/.gitignore`).
4. `core_app/android/app/build.gradle.kts` reads `key.properties` when present
   and **fails closed with a clear error** when any release build
   (`bundleRelease` / `assembleRelease`) runs without a complete keystore.
   The generated shell (`apps/halal_boyz/android/app/build.gradle.kts`) mirrors
   the same contract (hand-mirror; a generator regeneration reverts it — re-apply).
5. Debug smoke needs no keystore: `cd core_app && flutter build appbundle --debug`.

## 2. CI release job (`.github/workflows/carnama_ci.yml`)

`android-release-smoke` always builds `flutter build appbundle --debug`. On the
`release` branch or `v*` tags it additionally builds a **fully signed** release
bundle from GitHub secrets (base64 injection — never committed):

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | base64 of the upload keystore (`*.jks`) |
| `ANDROID_KEYSTORE_STORE_PASSWORD` | keystore password |
| `ANDROID_KEYSTORE_KEY_PASSWORD` | key password |
| `ANDROID_KEYSTORE_KEY_ALIAS` | key alias |

The job writes `android/app/keystore.jks` + `android/key.properties` at build
time. A release-branch/tag build **without** the secret is a hard CI failure
(fail-closed) so an unsigned/debug-signed bundle can never be released.

## 3. fastlane (root `fastlane/`)

Prereqs: `gem install fastlane` (>= 2.150.0) and `GOOGLE_JSON_KEY_FILE`
pointing to a Play Console service-account JSON (the key file itself is never
committed). Signing uses `core_app/android/key.properties` (§1).

```bash
fastlane beta      # build signed release AAB + upload to the internal track
fastlane promote   # promote internal -> beta (closed) track
```

Lanes are scaffolded but not store-run in CI (no credentials on runners) —
RELEASE-2/ops executes them per the release calendar.

## 4. Version discipline

- **Single source of truth:** `core_app/pubspec.yaml` → `version:
  <major.minor.patch+build>` (today `1.1.0+2`).
- **Bump + changelog:** `cd core_app && dart run tool/generate_changelog.dart [patch|minor|major]`
  (scans conventional commits since the last tag, bumps version+build, prepends `CHANGELOG.md`).
- **Tag a release (annotated, immutable):**
  ```bash
  cd core_app
  dart run tool/tag_release.dart --dry-run   # preview: v1.1.0+2 @ <sha>
  dart run tool/tag_release.dart             # create annotated tag v1.1.0+2
  ```
  The tool reads the version from `core_app/pubspec.yaml`, refuses to
  overwrite an existing tag, and exits non-zero on any failure.
- **melos (workspace) versioning:** this monorepo is a melos workspace
  (root `pubspec.yaml` lists `core_app`, `apps/halal_boyz`, `packages/core`,
  `packages/core_ui`; scripts `analyze` / `test` / `gen`). Use
  `melos version --dry-run` then `melos version` to version the workspace
  members, and `melos bootstrap` to re-link after any bump. `melos version`
  is the sanctioned workspace-level version command — manual cross-package
  version edits must stay in sync with it.

## 5. Typography (release note)

`AppTheme` (packages/core_ui) now guards `fontFamily`: a non-`System` family
is applied only when it is a **registered bundled font** (declared under
`flutter.fonts` in pubspec.yaml → built into `FontManifest.json`). Anything
else records an explicit load error and falls back to the built-in type
system — never silent. `AppTheme.loadBundledFontFamilies()` is wired at app
boot in `core_app/lib/main.dart`. The generated shell should call the same
loader in its `runShell()` boot path (generator template is W3 territory —
handoff recorded in the RELEASE-1 addendum).

## 6. iOS (macOS-only — honest limitation)

Not CI-gated (no macOS runner). Perform on a macOS host:

```bash
cd core_app/ios
fastlane beta   # legacy scaffold: match certs + build + TestFlight upload
```

See `core_app/ios/fastlane/Fastfile`; requires Apple credentials
(`APPLE_ID`, `ITC_TEAM_ID`, `TEAM_ID` env vars). Treat as a manual release
step until a macOS runner exists.