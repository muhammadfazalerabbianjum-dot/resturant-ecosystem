import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo-level guard (T-B9-1) that proves every generated adapter is free of
/// Carnama's live identity and uses empty, fail-fast defaults.
void main() {
  const carnamaPreset =
      'carnama_'
      'unsigned';
  const carnamaCloud =
      'dc'
      'qf9qpsq';
  const staleLan =
      '192.168.1.'
      '100';
  const carnamaAppId =
      'com.ca'
      'rnama.app';

  test('generated app never embeds the Carnama identity', () {
    final files = <String>['lib/app/core_config_adapter.dart', 'lib/main.dart'];
    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');
      final text = file.readAsStringSync();
      expect(
        text.contains(carnamaPreset),
        isFalse,
        reason: '$path must not embed the Carnama upload preset',
      );
      expect(
        text.contains(carnamaCloud),
        isFalse,
        reason: '$path must not embed the Carnama cloud name',
      );
      expect(
        text.contains(staleLan),
        isFalse,
        reason: '$path must not embed the stale LAN IP',
      );
      expect(
        text.contains(carnamaAppId),
        isFalse,
        reason: '$path must not fall back to the Carnama app id',
      );
    }
  });

  test('adapter defaults are empty, marked, and fail fast', () {
    final text = File('lib/app/core_config_adapter.dart').readAsStringSync();
    expect(
      text.contains('OFFLINE_FALLBACK'),
      isTrue,
      reason:
          'empty defaults must be documented with an OFFLINE_FALLBACK marker',
    );
    expect(
      text.contains('client bundleId missing'),
      isTrue,
      reason: 'a missing bundle id must fail fast, never silently fall back',
    );
  });
}
