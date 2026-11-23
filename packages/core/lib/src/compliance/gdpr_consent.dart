/// Canonical GDPR analytics-consent key (W9.8 / 06-P1-3).
///
/// WHY a single shared constant: the consent decision must be written and
/// read by the SAME key on every surface — the consent dialogs (core_app +
/// core_ui copies), `TelemetryService.log` (the analytics gate) and the boot
/// guard in the host app's `main.dart`. Before UX-3 the dialog wrote a
/// DIFFERENT key (the legacy key) than the one telemetry read, so an
/// accepted dialog NEVER enabled analytics (and vice versa) — permanently
/// dead analytics/telemetry.
///
/// Semantics (three-state via nullable bool):
///   * key absent            -> consent NOT decided (dialog may be shown)
///   * key == false          -> user DECLINED (opt-out is durable, never re-prompted)
///   * key == true           -> user ACCEPTED (analytics/telemetry allowed)
///
/// Pre-launch note: no migration of the legacy key's stored value is needed
/// — there is no shipped install base (fail-safe default: undecided).
const String kGdprAnalyticsConsentKey = 'gdpr_analytics_consent';
