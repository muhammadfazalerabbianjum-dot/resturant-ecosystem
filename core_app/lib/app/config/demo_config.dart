/// DEMO MODE CONFIGURATION
/// ─────────────────────────────────────────────────────────────────────────────
/// This flag controls whether the app runs in "demo mode" (no Cloud Functions)
/// or "production mode" (full Cloud Functions on Firebase Blaze plan).
///
/// DEMO MODE (kDemoMode = true):
///   - All Cloud Function calls are replaced with local Dart implementations.
///   - Stripe payment is simulated (succeeds instantly, no real charge).
///   - Tax is calculated inline using a hardcoded rate table.
///   - GDPR delete performs client-side batch deletes.
///   - Fraud screening performs a simple local Firestore count.
///   - Telemetry writes directly to Firestore instead of via Cloud Function.
///   - Fleet dispatch writes directly to Firestore.
///   - Orders are created directly in Firestore (no server-side validation).
///   Use this on the Firebase Spark (free) tier for demos and presentations.
///
/// PRODUCTION MODE (kDemoMode = false):
///   - All features route through secure Firebase Cloud Functions.
///   - Requires Firebase Blaze (pay-as-you-go) plan.
///   - Stripe totals are re-validated server-side (can't be spoofed).
///   - Run `firebase deploy --only functions` before switching to false.
///
/// HOW TO SWITCH FOR A CLIENT DEPLOYMENT:
///   1. Upgrade the client's Firebase project to Blaze plan.
///   2. Run: firebase deploy --only functions
///   3. Change `kDemoMode` below to `false`.
///   4. Rebuild: flutter build apk --release
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// DEMO MODE flag — controlled by --dart-define for client deployments.
/// Default is FALSE (production). Demo mode requires explicit opt-in:
///   --dart-define=DEMO_MODE=true
/// A release build with DEMO_MODE=true is a production hazard and is
/// rejected at startup (see _assertSafeBuildConfig in app_bootstrap.dart —
/// the shared init every app calls since ARCH-2).
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

/// DEPRECATED: Client-side tax rates are no longer used.
/// Tax is calculated server-side via Cloud Function.
/// @deprecated
// const Map<String, double> kDemoTaxRates = {
//   'CA': 0.0725, // California
//   'NY': 0.08, // New York
//   'TX': 0.0625, // Texas
//   'FL': 0.06, // Florida
//   'DEFAULT': 0.05, // Fallback for all other states
// };
