# BATCH BACKEND-2 SPEC - CARNAMA PRODUCTION FIX (part of PRODUCTION_FIX_BATCHES.md)

**Read `PRODUCTION_FIX_BATCHES.md` FIRST (RULES Section 0, Universal Gate Set U Section 1, environment/decisions Section 2, batch map Section 3). Deep HOW = `PRODUCTION_FIX_PROMPT.md` W7.2, W7.3, W7.4.**

## 20. BATCH BACKEND-2 - PLATFORM PRIVACY LAYER + FUNCTION AUTH GAPS

**Predecessor:** BACKEND-1. **Emulator-gated:** no. **Master:** W7.2, W7.3, W7.4. **MIRROR: this batch IS the generator/regenerate + shared index.ts - halal regenerated.**

### 20.1 Problems to solve (evidence)

| # | File (evidence) | Problem | Severity |
|---|---|---|---|
| P-1 | `core_app/android/.../AndroidManifest.xml` | `ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` declared but NO consuming feature (driver stream is foreground-only) | P1 (06-P1-5) |
| P-2 | `apps/halal_boyz/android/.../AndroidManifest.xml` | Generated shell has ZERO permissions (not even INTERNET) -> release build cannot reach Firebase/Stripe | P1 (06-P1-6) |
| P-3 | `apps/halal_boyz/ios/Runner/Info.plist` | No usage descriptions -> iOS aborts on first location/camera access; NO `PrivacyInfo.xcprivacy` | P1 (06-P1-6) |
| P-4 | `index.ts:127-158` | `dispatchToFleet` lacks auth gate (staff action, App-Check only) | P2 (09-P2) |
| P-5 | `index.ts:556-576` | `createPaymentIntent` lacks auth binding (no user claim on intent) | P2 (09-P2) |

### 20.2 Solution - design principle + acceptance contract

**Design principle:** least privilege; the generator writes the platform privacy layer so every future shell inherits it.

**Acceptance contract (from master W7.2/W7.3/W7.4):**
1. Template manifest: REMOVE `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`; keep INTERNET + FINE/COARSE; declare `POST_NOTIFICATIONS` explicitly. Update `tool/audit_permissions.dart` fixture expectations.
2. Generator writes for `apps/<dir>/android/.../AndroidManifest.xml`: INTERNET + FINE/COARSE + POST_NOTIFICATIONS (fixed safe set); for `apps/<dir>/ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (strings from config `app.name`); copy `PrivacyInfo.xcprivacy` (W9-corrected template) into the shell. Generated widget test asserting INTERNET present.
3. `index.ts`: `dispatchToFleet` gains auth + staff-claim check; `createPaymentIntent` stamps `request.auth.uid` into PI metadata (`createdBy`).
4. Regenerate/mirror halal_boyz.

### 20.3 Tests

| Test | What it asserts | How |
|---|---|---|
| T-1 | audit_permissions green | `dart tool/audit_permissions.dart` exit 0 with updated fixtures |
| T-2 | Generated manifest has INTERNET | Generated widget test |
| T-3 | dispatchToFleet auth-gated | Unit: no auth -> denied |
| T-4 | createPaymentIntent stamps createdBy | Unit: PI metadata contains uid |
| T-5 | Shell has usage strings + PrivacyInfo | File asserts on regenerated halal |

### 20.4 Proof gates

- [ ] `dart tool/audit_permissions.dart` green
- [ ] Generated manifest INTERNET test green
- [ ] `flutter analyze` (core_app + halal) green; `npx tsc --noEmit` + `npm test` green
- [ ] halal regenerated with manifest/plist/PrivacyInfo
- [ ] Universal Gate Set U (index Section 1)

### 20.5 Honest residuals

- iOS build itself is not runnable on Windows (no Xcode) - the plist/PrivacyInfo are verified textually + by the generated test; a macOS build is a RELEASE-2 item.
- `POST_NOTIFICATIONS` runtime request is handled in PUSH-2 (in-context); the manifest declaration here is the static half.

**END OF BATCH BACKEND-2 SPEC** - do not proceed until these gates pass and the BACKEND-2 addendum is appended to FIX_VERIFICATION.md.