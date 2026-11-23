// FIX-B1 T-4 (F-AUD2-06, doc truth) — the Stripe release-guard comment may
// not overclaim in either direction.
//
// CHOICE (recorded in tool_fix/b1/b1_report.md): correct the COMMENT to
// match the code (a DEBUG-ONLY assert); do NOT promote the guard to a
// release-visible check — the audit ACCEPTed release behavior as fail-closed
// at payment-sheet init, and changing release boot behavior is outside this
// batch's blast radius.
//
// RED-AT-HEAD: the old comment "fail fast if key missing in production"
// overclaimed (the assert is stripped from release builds) — receipt
// tool_fix/b1/red_t4.txt.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String source = File('lib/app_bootstrap.dart').readAsStringSync();

  test(
    'T-4a: the Stripe guard comment states what the code does (no release fail-fast claim)',
    () {
      expect(
        source,
        isNot(contains('fail fast if key missing in production')),
        reason:
            'the old comment claimed a release fail-fast the debug-only assert '
            'cannot deliver (stripped from release builds)',
      );
      expect(
        source,
        contains('DEBUG-ONLY assert'),
        reason: 'the corrected comment names the guard honestly',
      );
      expect(
        source,
        contains('Stripe.publishableKey.isNotEmpty'),
        reason: 'the guard itself is unchanged — doc truth, not behavior drift',
      );
      expect(
        source,
        isNot(contains("'STRIPE_PUBLISHABLE_KEY is required in production'")),
        reason:
            'the assert message must not imply the check runs in production',
      );
    },
  );
}
