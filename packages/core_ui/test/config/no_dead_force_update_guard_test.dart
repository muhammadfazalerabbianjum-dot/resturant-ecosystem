import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PERF-3 T-4 drift guard: the `core_ui` ForceUpdateGuard/ForceUpdateChecker
/// copy was a DEAD duplicate of the live guard (the core_app-local
/// `ForceUpdateGuard` + `forceUpdateStatusProvider` → `ForceUpdateService`,
/// covered by core_app's own 3 test files). It was deleted in PERF-3; this
/// source-scan pins its absence so it can never be resurrected — re-wiring the
/// dead copy would reintroduce a dormant, English-only, unmonitored
/// security-adjacent surface (the drift class this batch removes).
void main() {
  test('core_ui exposes no ForceUpdateGuard/ForceUpdateChecker symbol', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'the scan target (packages/core_ui/lib) must exist',
    );

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains('ForceUpdateGuard') ||
          text.contains('ForceUpdateChecker')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'the dead force-update duplicate must stay deleted — the ONLY '
          'force-update implementation is the live core_app guard',
    );
  });
}
