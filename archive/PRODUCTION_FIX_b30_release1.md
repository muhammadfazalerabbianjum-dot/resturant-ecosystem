# BATCH RELEASE-1 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W11.1, W11.2, W11.3.**

## 30. BATCH RELEASE-1 - RELEASE PIPELINE + VERSIONING + TYPOGRAPHY GUARD

**Predecessor:** every code batch (or the last remaining one). **Emulator-gated:** no. **Master:** W11.1, W11.2, W11.3. **MIRROR: platform files generator-owned - mirror/regenerate.**

### 30.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | repo-wide | No Fastfile, no appbundle build step, no signing templates, no tags, no CHANGELOG, no version automation | P1 (07-P1-4) |
| P-2 | `core_app/android/key.properties` | Gitignored but no committed `.template`; release signing has no gate | P2 (07-P2-3) |
| P-3 | `AppTheme` | Non-`System` `fontFamily` silently falls back (no font asset path) | P2 (08-P2-2) |

### 30.2 Solution - design principle + acceptance contract

**Design principle:** a release must be reproducible, signed, versioned, and never silently degrade.

**Acceptance contract (from master W11.1/W11.2/W11.3):**
1. `core_app/android/key.properties.template` (W1.3) + `app/build.gradle.kts` reads `key.properties` when present (release signing) with a clear build error when absent in release mode.
2. CI `android-release-smoke` upgraded to `flutter build appbundle --release` on the release branch when the keystore secret exists (base64 injection, never committed).
3. `fastlane` android scaffold (`fastlane/Fastfile` lanes `beta`/`promote` using supply + `key.properties`).
4. Root `CHANGELOG.md` (seeded with the remediation summary); `tool/tag_release.dart` (reads `core_app/pubspec.yaml` version, creates annotated tag); melos version command documented.
5. `AppTheme`: non-`System` `fontFamily` -> load bundled font IF registered in pubspec, else explicit `loadError` entry + fallback (never silent).

### 30.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Release build gate | `flutter build appbundle --debug` green (any mode); release mode without key.properties -> clear error |
| T-2 | Tag tool | `tool/tag_release.dart` reads version + creates annotated tag (dry-run) |
| T-3 | CHANGELOG present | File exists with remediation summary |
| T-4 | Typography guard | Unit: unregistered fontFamily -> `loadError` entry + fallback |

### 30.4 Proof gates

- [ ] `flutter build appbundle --debug` green
- [ ] Template/script lint passes
- [ ] CHANGELOG + tag tool present
- [ ] `flutter analyze` + `flutter test` green
- [ ] Universal Gate Set U (index Section 1)

### 30.5 Honest residuals

- iOS release build stays a documented macOS runbook step (no macOS runner) - honest limitation, recorded.
- Fastlane lanes are scaffolded but not executed against a store (no credentials) - RELEASE-2/ops executes them.

**END OF BATCH RELEASE-1 SPEC** - do not proceed to RELEASE-2 until these gates pass and the RELEASE-1 addendum is appended to FIX_VERIFICATION.md.