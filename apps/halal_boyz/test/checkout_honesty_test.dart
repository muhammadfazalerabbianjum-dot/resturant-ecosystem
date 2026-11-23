import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show CheckoutScreen;

/// T-B9-2 carried forward into the ARCH-1 architecture — the shell's
/// checkout is HONEST.
///
/// Pre-ARCH-1 the shell carried its own placeholder checkout with a
/// `merchantConfigured` honesty gate (disabled Place Order, no fake success).
/// ARCH-1 deletes every local screen: the checkout is now the REAL
/// `package:labs` `CheckoutScreen`, whose payment path is fail-closed by
/// construction — the money never fakes success:
///   * `CheckoutService.processStripePayment` returns null on a failed or
///     unconfigured charge and the order is never confirmed as paid
///     (behavioral proof: `core_app/test/features/checkout/` —
///     `chaos_checkout_test.dart`, `checkout_service_test.dart`,
///     `checkout_auth_guard_test.dart` — the shell cannot and must not
///     duplicate the payment service's cross-territory test suite);
///   * `DEMO_MODE` (simulated Stripe) is a build-time define, forbidden in
///     release by the shared `_assertSafeBuildConfig` (pinned by
///     `demo_mode_wiring_test.dart`).
/// What the SHELL must prove (and does below) is the inverse: it ships NO
/// payment code of its own, and its config carries ONLY the documented
/// placeholder payment key — so there is no fake credential and no fake
/// success to ship.
void main() {
  group('T-B9-2 (ARCH-1): shell checkout honesty', () {
    test('the REAL CheckoutScreen (labs) is the shell checkout — '
        'const-constructible, no local copy anywhere in shell lib', () {
      expect(const CheckoutScreen(), isA<CheckoutScreen>());

      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        final text = file.readAsStringSync();
        expect(
          text.contains('class CheckoutScreen'),
          isFalse,
          reason:
              '${file.path} must not declare a local checkout — '
              'the real one comes from package:labs',
        );
        expect(
          text.contains('processStripePayment'),
          isFalse,
          reason: '${file.path} must not contain shell-side payment logic',
        );
        expect(
          text.contains('merchantConfigured'),
          isFalse,
          reason:
              '${file.path} must not resurrect the deleted placeholder '
              'honesty param — the REAL checkout owns the money gate',
        );
      }
    });

    test('the shell config carries ONLY the documented REPLACE_ME payment '
        'placeholder — never a fake working key, never a live key', () {
      final config =
          jsonDecode(File('assets/client_config.json').readAsStringSync())
              as Map<String, dynamic>;
      final environment = config['environment'] as Map<String, dynamic>;
      final key = environment['stripePublishableKey'] as String;
      expect(
        key.contains('REPLACE_ME'),
        isTrue,
        reason:
            'the payment key must stay the documented placeholder until a '
            'real merchant account exists — honesty over fake green',
      );

      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(
          text.contains('pk_live') || text.contains('pk_test'),
          isFalse,
          reason:
              '${file.path} must never embed a Stripe publishable key '
              '(keys live in build defines / the ops config, never code)',
        );
      }
    });
  });
}
