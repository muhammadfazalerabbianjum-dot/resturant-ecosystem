// FIX-B11 T-5 (F-B8-01) — detector for the generator's emitted money template.
//
// The generator's emitted client test
// (`core_app/tool/whitelabel.dart`, `_priceCentsGuardTestTemplate`) must pin
// the SAME strings the canonical formatter produces (owner decision D-1 /
// AUD1-02): a regeneration has to ship a PASSING, CLDR-conformant test.
//
// This detector READS the generator source and CALLS the formatter — it never
// modifies either (text-only discipline, spec 0.7; money-safety carve-out,
// spec 0.10). RED while the emitted expectations pin the retired money form;
// GREEN once the expectation strings + false comment are corrected.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart' show formatCurrencyCents;

void main() {
  late String source;

  setUpAll(() {
    final root = _findRepoRoot();
    source = File(
      [
        root.path,
        'core_app',
        'tool',
        'whitelabel.dart',
      ].join(Platform.pathSeparator),
    ).readAsStringSync();
  });

  group('F-B8-01: emitted money expectations match the canonical formatter', () {
    test('negative USD expectation is the formatter output (-\$5.00)', () {
      final m = RegExp(
        r"formatCurrencyCents\(-500,\s*currencyCode: 'USD'\),\s*(r?'[^']+')",
      ).firstMatch(source);
      expect(
        m,
        isNotNull,
        reason: 'the -500 USD expectation must exist in the emitted template',
      );
      final emitted = _unquote(m!.group(1)!);
      final actual = formatCurrencyCents(-500, currencyCode: 'USD');
      expect(
        emitted,
        actual,
        reason:
            'the emitted test must pin the canonical formatter output (D-1), '
            'not the retired sign-after-symbol form',
      );
    });

    test('unknown-code expectation is the formatter output (XYZ 1.00)', () {
      final m = RegExp(
        r"formatCurrencyCents\(100,\s*currencyCode: 'XYZ'\),\s*(r?'[^']+')",
      ).firstMatch(source);
      expect(
        m,
        isNotNull,
        reason:
            'the unknown-code expectation must exist in the emitted template',
      );
      final emitted = _unquote(m!.group(1)!);
      final actual = formatCurrencyCents(100, currencyCode: 'XYZ');
      expect(
        emitted,
        actual,
        reason:
            'the emitted test must pin the canonical formatter output (D-1), '
            'not the retired symbol-only fallback',
      );
    });

    test('the template comment tells the truth about sign placement', () {
      expect(
        source.contains('renders the sign after the symbol'),
        isFalse,
        reason: 'the retired-form comment must be corrected, not re-asserted',
      );
      expect(
        source.contains('minus before symbol'),
        isTrue,
        reason:
            'the emitted comment must state the CLDR minus-before-symbol rule',
      );
    });
  });
}

String _unquote(String raw) {
  var s = raw.trim();
  if (s.startsWith('r')) s = s.substring(1);
  return s.substring(1, s.length - 1);
}

/// Walks up from the CWD until the monorepo root (pubspec + packages/core),
/// so the detector works from the repo root or any package directory.
Directory _findRepoRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    final sep = Platform.pathSeparator;
    final pubspec = File('${dir.path}${sep}pubspec.yaml');
    final core = Directory('${dir.path}${sep}packages${sep}core');
    if (pubspec.existsSync() && core.existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}
