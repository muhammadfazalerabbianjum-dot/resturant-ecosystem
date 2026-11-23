import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PERF-3 T-2 drift guard: the `devAdminPin` config surface (field, getter,
/// config parse, test reset — 6 sites) was DEAD: it had zero readers. The
/// single, fail-closed PIN authority is `AdminAccessService` (packages/core):
/// `--dart-define ADMIN_PIN` in debug (no default — unset means verifyPin
/// always returns false) and Remote Config `admin_pin` in release.
///
/// This scan pins the removal so a duplicate PIN surface cannot silently
/// reappear in the app config (a future dev could mistake it for a working
/// gate — the exact hazard class PERF-3 removes).
void main() {
  test('AppConfig exposes no admin-PIN surface (devAdminPin removed)', () {
    final source = File('lib/app/config/app_config.dart').readAsStringSync();
    expect(
      source.contains('devAdminPin'),
      isFalse,
      reason:
          'the dead duplicate PIN config must stay deleted — AdminAccessService '
          '(packages/core) is the ONLY PIN authority and it fails closed',
    );
  });
}
