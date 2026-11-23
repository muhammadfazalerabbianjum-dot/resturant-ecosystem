import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/error_logger/pii_scrubber.dart';

void main() {
  group('PRIV-2 — Redaction ⊇ Validation Superset Invariant', () {
    // Corpus of accepted emails from form validation and spec requirements:
    // Any address accepted by form validation MUST be scrubbed by scrubPii.
    const acceptedCorpus = [
      'a@b.co',
      'user@example.com',
      'first.last+tag@sub.domain.co.uk',
      'test.user+promo@restaurant.ai',
      'jane_doe-123@service.org',
    ];

    // Permissive emails that might appear in logs or be typed (e.g. intranet/short names):
    const permissiveCorpus = ['a@b', 'x@y.z'];

    for (final email in acceptedCorpus) {
      test('isValidEmail accepts "$email" and scrubPii redacts it', () {
        expect(
          isValidEmail(email),
          isTrue,
          reason: 'Expected isValidEmail to accept "$email"',
        );
        final input = 'User email is $email in logs';
        final scrubbed = scrubPii(input);
        expect(
          scrubbed.contains(email),
          isFalse,
          reason:
              'Expected "$email" to be redacted by scrubPii, but was: "$scrubbed"',
        );
        expect(scrubbed, contains('[EMAIL_REDACTED]'));
      });
    }

    for (final email in permissiveCorpus) {
      test('scrubPii redacts permissive/intranet email "$email"', () {
        final input = 'User email is $email in logs';
        final scrubbed = scrubPii(input);
        expect(
          scrubbed.contains(email),
          isFalse,
          reason:
              'Expected "$email" to be redacted by scrubPii, but was: "$scrubbed"',
        );
        expect(scrubbed, contains('[EMAIL_REDACTED]'));
      });
    }

    test(
      'Superset Invariant: for any valid email x, scrubPii(x) redacts x',
      () {
        final samples = [
          'user@example.com',
          'admin+tag@restaurant.org',
          'dev.lead_42@sub.domain.net',
        ];
        for (final s in samples) {
          expect(isValidEmail(s), isTrue);
          expect(emailLikePattern.hasMatch(s), isTrue);
          expect(scrubPii('contact: $s'), 'contact: [EMAIL_REDACTED]');
        }
      },
    );

    test('Reject set: invalid emails rejected by isValidEmail', () {
      expect(isValidEmail(null), isFalse);
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('   '), isFalse);
      expect(isValidEmail('plainaddress'), isFalse);
      expect(isValidEmail('no@tld'), isFalse);
      expect(isValidEmail('@missinglocal.com'), isFalse);
      expect(isValidEmail('missingdomain@.com'), isFalse);
    });
  });
}
