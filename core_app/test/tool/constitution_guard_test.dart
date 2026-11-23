import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/constitution_guard.dart' as guard;

/// constitution_guard v2 — precision + falsifiability (p26 method).
///
/// The guard counted 73 "violations" over `core_app/lib`, but ~57 of them were
/// the token layer the constitution DEMANDS (`BrandColors.of`), identifiers
/// that merely contain a banned substring (`isValidHexColor(`,
/// `buildOrderAttemptFingerprint(`) and comment prose. A detector that cries
/// wolf on correct code is a defect in the detector, so this test pins BOTH
/// directions: every violation class keeps a positive control (never
/// vacuously green), the previously mis-flagged correct code stays silent,
/// and the live gate — the real `lib/` — must scan clean.
void main() {
  List<guard.ConstitutionViolation> scan(String source) => guard.scanLines(
    const LineSplitter().convert(source),
    path: 'fixture.dart',
  );

  List<String> rulesOf(String source) =>
      scan(source).map((v) => v.rule).toList();

  group('fires — every violation class keeps a positive control', () {
    test('a hardcoded Material color literal in code fires COLOR', () {
      expect(
        rulesOf('Widget w() => Container(color: Colors.red);'),
        contains('COLOR'),
      );
    });

    test('a hardcoded Color(0x...) literal in code fires COLOR', () {
      expect(rulesOf('final c = Color(0xFFDEADBE);'), contains('COLOR'));
    });

    test('a real print() call fires PRINT', () {
      expect(rulesOf("print('boom');"), contains('PRINT'));
    });

    test('TODO and FIXME markers fire TODO', () {
      expect(rulesOf('// TODO: later'), contains('TODO'));
      expect(rulesOf('x(); // FIXME: soon'), contains('TODO'));
    });

    test('a firebase_auth import fires FBAUTH', () {
      expect(
        rulesOf("import 'package:firebase_auth/firebase_auth.dart';"),
        contains('FBAUTH'),
      );
    });
  });

  group('silent — the 2026-09 false positives stay silent', () {
    test('the BrandColors token layer is not a violation', () {
      expect(rulesOf('final brand = BrandColors.of(context);'), isEmpty);
      expect(
        rulesOf('style: TextStyle(color: BrandColors.of(c).error),'),
        isEmpty,
      );
    });

    test('identifiers containing Color( are not color literals', () {
      expect(
        rulesOf('if (value is! String || !isValidHexColor(value)) {'),
        isEmpty,
      );
      expect(rulesOf('color: _promotionColor(name, theme, 0),'), isEmpty);
    });

    test('fingerprint identifiers are not print() calls', () {
      expect(
        rulesOf(
          'final fingerprint = buildOrderAttemptFingerprint(\n  orderId: id,\n);',
        ),
        isEmpty,
      );
    });

    test('comment prose about colors is not a violation', () {
      expect(
        rulesOf('// A1: raw Chip with `Colors.orange` now uses a token.'),
        isEmpty,
      );
      expect(
        rulesOf('final brand = BrandColors.of(c); // was Colors.red'),
        isEmpty,
      );
    });

    test('runtime Color(variable) parsing is not a hardcoded literal', () {
      expect(rulesOf('return Color(parsed);'), isEmpty);
    });

    test('const-explicit literals stay exempt (documented exceptions)', () {
      // Law 3's operational line is "no NON-const color literal": a
      // compile-time constant is not hardcoded UI. The Google-brand blue
      // (FIX_VERIFICATION §29.5) and the neutral on-error white rely on it.
      expect(rulesOf('color: const Color(0xFF4285F4),'), isEmpty);
      expect(rulesOf('color: const Colors.white,'), isEmpty);
    });
  });

  group('live gate — the real tree', () {
    test('core_app/lib scans with zero violations', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'test must run from core_app/');
      final violations = guard.scanDirectory(lib);
      expect(
        violations,
        isEmpty,
        reason: violations.map((v) => v.toString()).join('\n'),
      );
    });
  });
}
