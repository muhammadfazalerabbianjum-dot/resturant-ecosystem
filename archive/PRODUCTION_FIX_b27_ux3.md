# BATCH UX-3 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W9.8, W9.9, W9.10, W9.11.**

## 27. BATCH UX-3 - CONSENT CHAIN + SIGNUP ToS + ART.20 EXPORT + PRIVACY P2

**Predecessor:** UX-1 (uses ARB keys). **Emulator-gated:** GDPR emulator. **Master:** W9.8, W9.9, W9.10, W9.11. **MIRROR: gdpr_consent/telemetry/signup shared code - mirror where shell carries copies.**

### 27.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `gdpr_consent_dialog.dart:12,32-41` + `telemetry_service.dart:23` + `main.dart:199-207` | Consent dialog NEVER shown; key mismatch (`gdpr_consent_given` vs `gdpr_analytics_consent`) -> analytics/telemetry permanently dead | P1 (06-P1-3) |
| P-2 | `signup_screen.dart` | No ToS/Privacy references at signup (login has them) | P1 (06-P1-4) |
| P-3 | `data_export_service.dart:48-141` vs `index.ts:195-236` | Art.20 export misses 6 erasure-set sources + local data | P1 (06-P1-7) |
| P-4 | `delete_account_screen.dart:24-47` | Deletion path performs no local cleanup (Isar/prefs/signOut) | P2 (06-P2-4) |
| P-5 | `core_app/ios/Runner/PrivacyInfo.xcprivacy` | EmailAddress/Name `linked=false` (inaccurate); missing data types; unused ATT string | P2 (06-P2-7) |
| P-6 | `error_logger_service.dart:49-53` | Raw error objects to Crashlytics unscrubbed | P2 (06-P2-8) |
| P-7 | `logger_service.dart:127-132` | `app_logs.txt` unbounded; `clearLogs` zero callers | P2 (06-P2-8) |

### 27.2 Solution - design principle + acceptance contract

**Design principle:** consent is a single canonical key; export mirrors the erasure set; local cleanup completes the deletion contract.

**Acceptance contract (from master W9.8/W9.9/W9.10/W9.11):**
1. Call `GdprConsentDialog.showIfNeeded` once after onboarding completes; unify the consent key into ONE constant (canonical `gdpr_analytics_consent`) consumed by dialog + `telemetry_service.dart:23` + `main.dart:199-207`; l10n the dialog copy. Test: shown once; accepted -> telemetry enabled.
2. Signup: required checkbox + `/privacy` + `/terms` links (pattern from `login_screen.dart:400-432`) gating `_signUp`; loc strings; test: submit disabled until accepted.
3. Art.20 export: extend `data_export_service.dart` (+ server path where rules-gated): add `promo_usage`, `reservation_locks`, `notifications/{uid}/items`, `driverLocations` via a new `exportMyData` CF section (mirrors erasure set), `deliveries` (via order IDs), `analyticsEvents`; include local Isar/prefs summary; update export UI copy + tests.
4. Delete-account: local cleanup (Isar clearAll + prefs + signOut) after CF completes.
5. `PrivacyInfo.xcprivacy`: EmailAddress/Name `linked=true`, add order-history + analytics data types, remove unused `NSUserTrackingUsageDescription`.
6. `ErrorLoggerService` scrubs error objects through the existing regex scrubber before Crashlytics; `app_logs.txt` rotation (1 MB cap, `clearLogs` wired to settings).

### 27.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | Consent shown once + enables telemetry | Widget: post-onboarding -> dialog once; accept -> telemetry enabled |
| T-2 | Signup gated | Widget: submit disabled until ToS accepted |
| T-3 | Export completeness | Unit: export contains all sections incl. new stores |
| T-4 | Delete-account local cleanup | Widget/unit: after CF success -> Isar cleared + prefs removed + signOut |
| T-5 | GDPR emulator still green | `gdpr_erasure_test.js` (MONEY-3 extended) |
| T-6 | Error scrubbing | Unit: PII-bearing exception -> Crashlytics reason scrubbed |

### 27.4 Proof gates

- [ ] Consent widget test green (T-1)
- [ ] Signup test green (T-2)
- [ ] Export test green (T-3)
- [ ] GDPR emulator suite green (T-5)
- [ ] Universal Gate Set U (index Section 1)

### 27.5 Honest residuals

- `exportMyData` CF is new server surface - it must reuse `collectUserDocs` shape minus deletion (no new erasure logic); keep it read-only.
- Consent is opt-in-by-default (both flags default false) - the privacy-safe direction is preserved; the fix makes the OPT-IN reachable.

**END OF BATCH UX-3 SPEC** - do not proceed until these gates pass and the UX-3 addendum is appended to FIX_VERIFICATION.md.