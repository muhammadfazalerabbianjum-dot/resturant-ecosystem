# CARNAMA LABS — CONFIG-DRIVEN WHITE-LABEL & CLIENT GENERATION AUDIT PROMPT

**Spec date:** 2026-08-31 · The authoritative prompt to verify that the white-label client
generation pipeline is SAFE — every client app (halal_boyz, future clients) generated from the
`core_app` template must be provably correct BEFORE store submission.

**Source of truth = the CURRENT codebase.** This prompt performs NO code changes.

---

## 0. HARD GATES — any violation fails the audit

1. **Truth over documents.** Done ONLY when code proves it.
2. **No stubs / fake success / AI slop.** "Config supports X" must mean X is CONSUMED and RENDERED.
3. **No hallucination.** Every claim cites `file:line` of CURRENT source.
4. **Completeness.** Every config field, every theme property, every asset, every build flag.
5. **No escapes.** No skipping, no sampling.
6. **Production-grade or not at all.** A client app that boots with a broken theme, wrong logo, or
   missing screen is a ONE-STAR review on the App Store — and a REFUND for the client.

---

## 1. SCOPE — the client-generation contract

The white-label contract is: **`client_config.json` → `core_app` template → store-ready app.**
Everything a client sees must come from config, not code. Verify every layer of this contract.

### 1.1 Config Schema Completeness

**Files to audit:**
- `core_app/assets/client_config.json` (template config — the schema definition)
- `apps/halal_boyz/assets/client_config.json` (generated client config)
- `core_app/lib/app/config/app_config.dart` (the config parser)
- `core_app/lib/app/config/core_config_adapter.dart`
- `packages/core/lib/src/config/core_config.dart`

**Verify:**
- [ ] List EVERY key in template config vs halal_boyz config — diff them
- [ ] Any key present in one but not the other is a FINDING (config drift)
- [ ] Every key is consumed by `app_config.dart` — dead keys are FINDINGS
- [ ] Every key read in code exists in BOTH configs — missing keys are FINDINGS
- [ ] Nested objects (theme, screens, featureFlags) are validated at every level
- [ ] Array fields (screens, branches, hours) handle empty arrays gracefully
- [ ] No config value is interpreted as code (no `eval`, no dynamic import) — XSS via config is P0

### 1.2 Theme & Branding Propagation

**Files to audit:**
- `core_app/lib/app/theme/app_theme.dart` (or equivalent)
- `core_app/lib/app/config/app_config.dart` (theme parsing)
- ALL `Color(0x...)` references everywhere in `core_app/lib`

**Verify:**
- [ ] `ThemeData` built from config theme section — list every property
- [ ] PRIMARY, SECONDARY, BACKGROUND, SURFACE, ERROR colors all configurable
- [ ] NO hard-coded `Color(0x...)` in feature files (grep `Color(0x`) — every hit is a FINDING
- [ ] NO hard-coded hex strings in widget code (grep `'#` and `'0xFF`)
- [ ] Typography (font family, sizes, weights) configurable from config
- [ ] Dark mode: does config define a dark theme? If not, what renders in system dark mode?
- [ ] Brand logo: config-driven path, and file must exist in assets (verify each client build)
- [ ] App name, bundle ID, splash text — all from config, not hard-coded
- [ ] WCAG AA contrast: programmatic check that all config color combos pass 4.5:1 for body text

### 1.3 Screen Registry Integrity (config ↔ code contract)

**Files to audit:**
- `core_app/assets/client_config.json` `screens` array
- `core_app/lib/app/app_router.dart` (config-mode route registration)
- `core_app/lib/app/navigation/route_names.dart`
- `core_app/lib/features/**/presentation/*.dart` (all screen widgets)

**Verify:**
- [ ] Every screen ID in config maps to a REAL Dart widget class (grep the import + class name)
- builder factory
- [ ] Every Dart screen widget is reachable from some route in BOTH static and config modes
- [ ] Screen IDs in halal_boyz config match template config IDs (drift = FINDING)
- [ ] The P0-1 name mismatch from UI_WIRING_AUDIT_REPORT.md is FIXED or explicitly acknowledged
- [ ] Deep links resolve against the ACTIVE route set (config mode), not the static set
- [ ] Route names referenced in `RouteNames` match the active router registration
- `RouteNames` short names vs config screen-ID names — THE P0-1 CLASS BUG

### 1.4 Asset & Media Integrity

**Files to audit:**
- `core_app/pubspec.yaml` asset declarations
- `apps/halal_boyz/pubspec.yaml`
- `core_app/assets/` directory tree
- `apps/halal_boyz/assets/` directory tree
- Every `Image.asset(`, `Image.network(`, `CachedNetworkImage(` in `core_app/lib`

**Verify:**
- [ ] Every asset path referenced in code exists on disk (programmatic check, not eyeball)
- [ ] Every asset declared in pubspec.yaml exists on disk
- [ ] Every file in assets/ is declared in pubspec.yaml (unused assets = app size bloat)
- [ ] Every network image URL in halal_boyz config returns HTTP 200 (programmatic check)
- [ ] Every image has errorBuilder + loadingBuilder (broken image = unprofessional)
- [ ] `apps/halal_boyz` has no asset that references the TEMPLATE's branding (logo cross-contamination)

### 1.5 Build Pipeline & Multi-Tenancy Isolation

**Files to audit:**
- `apps/halal_boyz/` (full directory — build scripts, flavors, env files)
- `core_app/android/app/build.gradle` + `apps/*/android/app/build.gradle`
- `core_app/ios/Runner.xcodeproj` + any `apps/*/ios` projects
- Any build scripts at repo root (`*.ps1`, `*.sh`, `Makefile`)
- `core_app/lib/app/config/app_config.dart` (clientId derivation)
- ALL Firestore query call sites (tenant isolation at query level)

**Verify:**
- [ ] `clientId` derivation: how is it computed? bundle ID? config? Is it IMPOSSIBLE for two
  client apps to produce the same clientId?
- [ ] Bundle ID uniqueness: template vs halal_boyz — diff them
- [ ] Firebase project: does each client app point to its OWN Firebase project (google-services.json
  / GoogleService-Info.plist)? Or shared project with tenant keys? Document the actual model.
- [ ] Firestore queries: EVERY query that reads orders/menu/settings MUST filter by clientId —
  list any query that does NOT (this is a cross-tenant data leak, P0)
- [ ] Cloud Function calls: every `httpsCallable` sends clientId in payload? Can client A invoke
  client B's data?
- [ ] Push notifications: FCM topics/tokens namespaced per client?
- [ ] Analytics: per-client dashboards possible? (Firebase Analytics with app suffix?)
- [ ] Env/secrets: any `.env`, `--dart-define`, or key files that differ per client — are they
  gitignored? Any template secret accidentally shipped in a client build?

### 1.6 Feature Flags & Remote Kill Switches

**Files to audit:**
- `core_app/lib/app/config/app_config.dart` (`_featureFlags` and getters)
- ALL consumers of feature flags (grep for the flag getter names)
- Any Remote Config usage in the codebase

**Verify:**
- [ ] List EVERY feature flag and its default value
- [ ] Every flag has at least one consumer (dead flags are FINDINGS)
- [ ] Default-off flags: behavior when flag missing from config must be SAFE
- [ ] Is there a remote way to flip a flag WITHOUT an app-store release? (Remote Config, or
  config fetch from Firestore at boot?) If none exists, document as P1 operational gap
- [ ] Flag evaluation: can a flag flip mid-session cause inconsistent state (half-checked-out order)?

### 1.7 Store Compliance Per Client

**Verify (documented as pre-submission checklist):**
- [ ] App name + subtitle configured per client
- [ ] App icons: all sizes present per client (iOS: 1024px no-alpha; Android: adaptive icons)
- [ ] Splash screens per client
- [ ] Privacy policy URL per client (config field? does it point to the CLIENT's policy?)
- [ ] Terms of service URL per client
- [ ] Support contact (email/phone) per client — the "Contact us" screen must show client's info
- [ ] Data-deletion flow works per client (Firebase Auth deletion is per-project — verify)
- [ ] App Store "account deletion" requirement (Apple 5.1.1(v)): in-app deletion path exists
- [ ] Google Play Data Safety form: can be filled from actual code behavior (data collected list)

---

## 2. DELIVERABLE

Write findings to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` (same format as the other audit prompts:
Verdict + P0/P1/P2 counts → per-item PASS/FAIL with file:line → issue table → fix plan → honest
limitations). For config diffs, include the ACTUAL diff output (key-level, both directions).

**Report ONLY. No code changes. No fixes.**

---

## 3. PROMPT SELF-CHECK before submission

- [ ] Template config vs every generated client config diffed key-by-key?
- [ ] Every `Color(0x` / hard-coded string-brand hit in feature code listed?
- [ ] Tenant isolation: every Firestore query listed with its clientId filter (or flagged)?
- [ ] Every asset path verified programmatically (script written in report appendix)?
- [ ] No claim about what "would happen" without code proof?

---

## DELIVERABLE — MASTER REPORT APPEND (mandatory, in this order)

1. APPEND to `<repo>\PRODUCTION_READINESS_AUDIT_MASTER.md` under "Consolidated Findings" the
   canonical block defined there — including the **Proven Best-Fit Solution table**: for EVERY
   P0/P1, enumerate ≥2 candidate fixes, evaluate each against THIS codebase (conventions, DI,
   existing helpers, white-label impact), declare the winner with file:line evidence that rules out
   the alternatives, and state the regression risk + guard. A fix is "best" only when proven.
2. Flip your row in the master's "Audit Prompt Index" (⬜ NOT RUN → ✅ DONE — PASS/FAIL) and in the
   "Master Verdict" table.
3. Keep detailed evidence in your per-domain report file; the master gets the consolidated block.
4. No library additions unless an equivalent pattern already exists in the codebase.

**Report ONLY. No code changes. No fixes.**

---

**END OF PROMPT — Begin audit when instructed. Do not start without explicit user command.**