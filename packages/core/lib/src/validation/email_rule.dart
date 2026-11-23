/// Single canonical email rule definitions shared between form validation
/// and PII redaction (AUD1-06 / PRIV-2 / FIX-B6).
///
/// Invariant: `isValidEmail(x) == true` implies `emailLikePattern.hasMatch(x) == true`
/// and `scrubPii(x)` redacts `x` (Redaction ⊇ Validation Superset Invariant).
library;

/// Permissive pattern for PII scrubbing and redaction.
/// Matches email-like strings including local intranet addresses (e.g. `a@b`),
/// multi-dot domains, tags (`+tag`), and long/unusual TLDs (`.museum`).
final RegExp emailLikePattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+');

/// Stricter pattern for form inputs requiring a dotted domain/TLD of at least 2 chars.
final RegExp strictEmailPattern = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Returns true if [candidate] is a valid email for form input submission.
///
/// Ensures candidate is non-null, trimmed, and conforms to standard email format
/// with a valid domain and TLD. Any string satisfying [isValidEmail] is guaranteed
/// to be matched by [emailLikePattern] and redacted by `scrubPii`.
bool isValidEmail(String? candidate) {
  if (candidate == null) return false;
  final trimmed = candidate.trim();
  if (trimmed.isEmpty) return false;
  return strictEmailPattern.hasMatch(trimmed);
}
