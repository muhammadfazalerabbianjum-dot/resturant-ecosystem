import '../validation/email_rule.dart';

export '../validation/email_rule.dart';

/// Single canonical PII scrubber (GDPR/CCPA) shared by every Crashlytics and
/// local-log sink (W9.11 / 06-P2-8).
///
/// WHY one function: before UX-3 only `LoggerService` scrubbed (its private
/// `_scrubPii`), while `ErrorLoggerService` handed RAW error objects to
/// Crashlytics — emails/phones inside exception messages leaked to the crash
/// console. Both services now delegate to this scrubber so the regexes can
/// never drift apart again.
///
/// Under FIX-B6 (PRIV-2), the email rule is shared with form validation, and
/// the scrubber uses [emailLikePattern] to ensure redaction is a superset of
/// validation: any string accepted as an email by forms (and any permissive email-like
/// string) is scrubbed here.
// ignore_for_file: prefer_final_locals
String scrubPii(String input) {
  var out = input;
  // Scrub Emails using the permissive shared pattern
  out = out.replaceAll(emailLikePattern, '[EMAIL_REDACTED]');
  // Scrub Standard Phones (e.g. 555-123-4567, 555.123.4567)
  out = out.replaceAll(
    RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
    '[PHONE_REDACTED]',
  );
  // Scrub International Phones (e.g. +1...)
  out = out.replaceAll(RegExp(r'\+\d{10,15}\b'), '[PHONE_REDACTED]');
  return out;
}

/// Wraps an error so its PAYLOAD is PII-scrubbed before it reaches
/// Crashlytics, while keeping the original runtime type visible in the
/// rendered string (Crashlytics groups issues by exception type + message —
/// preserving the type keeps triage grouping intact).
class RedactedError {
  final Object original;

  const RedactedError(this.original);

  @override
  String toString() =>
      '${original.runtimeType}: ${scrubPii(original.toString())}';
}
