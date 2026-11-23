# BATCH WL-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W6.4, W6.5, W6.6.**

## 18. BATCH WL-2 - CONFIG DRIFT REPAIRS + SCHEMA VALIDATION + DEAD KEYS

**Predecessor:** WL-1. **Emulator-gated:** no. **Master:** W6.4, W6.5, W6.6. **MIRROR: app_config shared core code; generated shell adapter updated via generator.**

### 18.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `app_config.dart:218-220` | `firebase.projectId` in JSONs never read; parser wants `environment.firebaseProjectId` | P1 (02-P1-CONFIG / 08-P1-WL-3) |
| P-2 | `app_config.dart:98-101, 317-322` | `loadFailed` set but NEVER consumed -> broken config boots silently | P1 (02-P1-CONFIG / 08-P1-WL-6) |
| P-3 | `core_config_adapter.dart:35-39` | Template LAN endpoint hardcoded `192.168.1.100`; config key absent in template | P1 (02-P1-CONFIG) |
| P-4 | configs | `_meta.schemaVersion` unvalidated; `currency` absent in template but shell consumes it (USD fallback) | P2 (08-P2-6) |
| P-5 | whole loop | NO client_config schema validation / fail-closed loader anywhere | P1 (07-P1-3) |
| P-6 | both configs | Dead keys: `app.primaryColor`, `app.fontFamily`, `environment.recaptchaWebKey`, `firebase.collections`, `clientScopingFields`, `configDocuments`, `tax.*`, `newFeatures`, `screens[].mandatory` | P2 (08-P2-1) |
| P-7 | `whitelabel.dart:228-233` | Forbidden-token list narrow (4 fragments); identity check absent; no display-name rewrite for manifest/plist | P2 (08-P2-3, 08-P2-8) |

### 18.2 Solution - design principle + acceptance contract

**Design principle:** typed, fail-closed config loading for REQUIRED fields; graceful degradation for optional/unknown; generator validates what consumers read.

**Acceptance contract (from master W6.4/W6.5/W6.6):**
1. `app_config.dart`: read BOTH `environment.firebaseProjectId` AND `firebase.projectId` (non-empty-wins: dotenv > JSON).
2. Consume `AppConfig.loadFailed`: after load, `logger.error` + debug banner (release: log only).
3. Template JSON gains `environment.kitchenLanEndpoint`; core parser reads it (replaces hardcoded IP).
4. `validate()` requires `_meta.schemaVersion` == supported constant; `currency` required (USD fallback only with `--allow-usd-fallback`).
5. W6.5: new typed `ConfigException` (JSON path); strict `ClientConfig.fromMap` (required: `app.name`, `app.bundleId`, `theme.colors.primaryHex`, `navigation.entryPoint`, enum `mode`; unknown route keys reject); malformed REQUIRED config -> fail-closed `ConfigValidationErrorScreen` (no silent default boot); optional/unknown fields keep graceful degradation. Tests: `core_app/test/config/client_config_schema_test.dart` matrix.
6. W6.6: prune dead keys from BOTH configs (record decision); widen forbidden-token list with Carnama sender-id/API-key/project-id fragments; post-generation identity check (`applicationId` == pbxproj `PRODUCT_BUNDLE_IDENTIFIER` == `app.bundleId`); add `AndroidManifest.xml android:label` + `Info.plist CFBundleDisplayName` rewrite steps.

### 18.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | projectId dual-read | Unit: both keys populated -> dotenv wins; only JSON -> JSON used |
| T-2 | loadFailed surfaced | Unit: broken config -> `logger.error` called + debug banner |
| T-3 | Schema matrix | Missing-required x wrong-type x modes -> typed `ConfigException`; golden valid fixtures parse |
| T-4 | Unknown route keys reject | Config with bad route -> load error |
| T-5 | Dead keys pruned | grep dead keys in both configs = 0 |
| T-6 | Identity check | Generator dry-run: applicationId == pbxproj == bundleId |

### 18.4 Proof gates

- [ ] `client_config_schema_test.dart` green (T-3, T-4)
- [ ] validate() green (schemaVersion + currency)
- [ ] Both configs parse; dead-key grep = 0
- [ ] Generator identity check passes (T-6)
- [ ] Universal Gate Set U (index Section 1)

### 18.5 Honest residuals

- `navigation.routes` + `stripePublishableKey` are KEPT (halal consumes both) - the prune list is exact, not broad.
- Config-validation tightening may break a previously-booting config on first run - the addendum must record any config that needed fixing to pass.

**END OF BATCH WL-2 SPEC** - do not proceed until these gates pass and the WL-2 addendum is appended to FIX_VERIFICATION.md.