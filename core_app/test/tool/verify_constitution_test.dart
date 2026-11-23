import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_constitution.dart' as verify;

/// verify_constitution v2 (p27 T-4) — planted-violation fixtures for ALL NINE
/// audited laws, each pinned in BOTH directions:
///
///  * a fixture that MUST fail the audit (positive control — the detector
///    never goes vacuously green), and
///  * the false-positive class v1 either missed or over-matched (prose
///    `placeholder`/`REPLACE_ME`, env-var NAMES like `'FIREBASE_API_KEY'`,
///    the token layer `BrandColors.of`, `Color(parsed)` parsing, const
///    declarations — the T-2 end state).
///
/// The v1 tool could not be imported at all (no external `grep` on Windows,
/// contradictory cwd, `// ignore_for_file: avoid_print`), so the red for this
/// suite is the compile failure captured BEFORE the rewrite
/// (`t4_verify_test_red.txt`); this file is the green proof after it.
void main() {
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('p27_verify_');
  });

  tearDown(() {
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  Directory libDir() =>
      Directory('${tempRoot.path}${Platform.pathSeparator}lib')
        ..createSync(recursive: true);

  Directory repoRoot() =>
      Directory('${tempRoot.path}${Platform.pathSeparator}repo')
        ..createSync(recursive: true);

  /// Writes [source] as `fixture.dart` into a fresh temp `lib/` and runs the
  /// pattern-law scan over it.
  List<String> scanSource(String source) {
    File(
      '${libDir().path}${Platform.pathSeparator}fixture.dart',
    ).writeAsStringSync(source);
    return verify.scanPatternLaws(libDir());
  }

  bool firesLaw(List<String> findings, String law) =>
      findings.any((f) => f.startsWith('$law [FAIL]'));

  group('Law 1 — no silent assumptions (pattern unchanged)', () {
    test('a code-level assume/guess/probably reference fires Law 1', () {
      final findings = scanSource('final mode = guessMode(current);\n');
      expect(firesLaw(findings, 'Law 1'), isTrue, reason: findings.join('\n'));
    });

    test('prose in a comment is not an assumption (code-only scan)', () {
      final findings = scanSource(
        '// we probably want this later; do not guess now\n',
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });

  group('Law 3 — no hardcoded color literals (word-bounded, const-exempt)', () {
    test('a raw Colors. member in code fires Law 3', () {
      final findings = scanSource(
        'Widget w() => Container(color: Colors.red);\n',
      );
      expect(firesLaw(findings, 'Law 3'), isTrue, reason: findings.join('\n'));
    });

    test('a non-const Color(0x...) literal in code fires Law 3', () {
      final findings = scanSource('final c = Color(0xFFDEADBE);\n');
      expect(firesLaw(findings, 'Law 3'), isTrue, reason: findings.join('\n'));
    });

    test('the BrandColors token layer stays silent', () {
      final findings = scanSource('final brand = BrandColors.of(context);\n');
      expect(findings, isEmpty, reason: findings.join('\n'));
    });

    test(
      'a const declaration (the T-2 named-const end state) stays silent',
      () {
        final findings = scanSource(
          'static const Color _kConfettiRed = Color(0xFFE63946);\n',
        );
        expect(findings, isEmpty, reason: findings.join('\n'));
      },
    );

    test('runtime Color(variable) parsing stays silent', () {
      final findings = scanSource('return Color(parsed);\n');
      expect(findings, isEmpty, reason: findings.join('\n'));
    });

    test('comment prose mentioning raw literals stays silent', () {
      final findings = scanSource(
        '// (BrandColors) instead of raw Color(0x...) literals — mapping:\n',
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });

  group('Law 4 — zero stub tolerance (markers + real stub constructs)', () {
    test('a whole-line TODO marker fires Law 4', () {
      final findings = scanSource('// TODO: wire this later\n');
      expect(firesLaw(findings, 'Law 4'), isTrue, reason: findings.join('\n'));
    });

    test('a Placeholder( widget construction fires Law 4', () {
      final findings = scanSource('Widget build() => Placeholder();\n');
      expect(firesLaw(findings, 'Law 4'), isTrue, reason: findings.join('\n'));
    });

    test('a throw UnimplementedError fires Law 4', () {
      final findings = scanSource(
        "void run() => throw UnimplementedError('later');\n",
      );
      expect(firesLaw(findings, 'Law 4'), isTrue, reason: findings.join('\n'));
    });

    test('prose placeholder / REPLACE_ME stays silent (D-p27-2)', () {
      final findings = scanSource(
        '// Render a placeholder while loading.\n'
        '// REPLACE_ME after the migration lands.\n'
        'const String _placeholderKeyPattern = "placeholder";\n',
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });

  group('Law 12 — no role checks in Dart code (byte-identical pattern)', () {
    test('a role == comparison in code fires Law 12', () {
      final findings = scanSource('final ok = role == UserRole.owner;\n');
      expect(firesLaw(findings, 'Law 12'), isTrue, reason: findings.join('\n'));
    });
  });

  group('Law 16 — no hardcoded secrets (env NAMES pass, literals fail)', () {
    test('an API_KEY/SECRET literal assignment fires Law 16', () {
      final findings = scanSource(
        "final String FIREBASE_API_KEY = 'leaked-value';\n",
      );
      expect(firesLaw(findings, 'Law 16'), isTrue, reason: findings.join('\n'));
    });

    test('an env-var NAME passed to the loader stays silent', () {
      final findings = scanSource(
        "apiKey: _requireEnv('FIREBASE_ANDROID_API_KEY', 'Android API key'),\n",
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });

  group('file laws 21/13/18/26 — repo-root file checks', () {
    test('all four laws fire when the required files are missing', () {
      final findings = verify.checkFileLaws(
        repoRoot: repoRoot(),
        packageRoot: repoRoot(),
      );
      for (final law in const ['Law 21', 'Law 13', 'Law 18', 'Law 26']) {
        expect(
          findings.any((f) => f.startsWith('$law [FAIL]')),
          isTrue,
          reason: '$law missing from: ${findings.join('\n')}',
        );
      }
    });

    test('all four laws pass once the required files exist at repo root', () {
      _plantRequiredFiles(repoRoot());
      expect(
        verify.checkFileLaws(repoRoot: repoRoot(), packageRoot: repoRoot()),
        isEmpty,
      );
    });
  });

  group('repo-root walk-up', () {
    test('findRepoRoot ascends nested directories to the .git holder', () {
      Directory(
        '${repoRoot().path}${Platform.pathSeparator}.git',
      ).createSync(recursive: true);
      final nested = Directory(
        '${repoRoot().path}${Platform.pathSeparator}a${Platform.pathSeparator}b',
      )..createSync(recursive: true);

      final found = verify.findRepoRoot(nested);
      expect(found, isNotNull);
      expect(
        _canonical(found!.path),
        _canonical(repoRoot().path),
        reason: 'walk-up must resolve to the directory holding .git',
      );
    });

    test('findRepoRoot returns null when no .git ancestor exists', () {
      final bare = Directory.systemTemp.createTempSync('p27_bare_');
      addTearDown(() => bare.deleteSync(recursive: true));
      expect(verify.findRepoRoot(bare), isNull);
    });
  });

  group('runAudit — the CLI contract', () {
    test('a planted tree reports AUDIT FAILED and returns exit 1', () {
      File(
        '${libDir().path}${Platform.pathSeparator}fixture.dart',
      ).writeAsStringSync('final c = Color(0xFFDEADBE);\n');
      final out = StringBuffer();
      final exitCode = verify.runAudit(
        libDir: libDir(),
        repoRoot: repoRoot(),
        packageRoot: repoRoot(),
        out: out,
      );
      expect(exitCode, 1);
      expect(out.toString(), contains('AUDIT FAILED'));
      expect(out.toString(), contains('Law 3 [FAIL]'));
    });

    test('a clean tree with required files reports AUDIT PASSED and 0', () {
      _plantRequiredFiles(repoRoot());
      final out = StringBuffer();
      final exitCode = verify.runAudit(
        libDir: libDir(),
        repoRoot: repoRoot(),
        packageRoot: repoRoot(),
        out: out,
      );
      expect(exitCode, 0, reason: out.toString());
      expect(out.toString(), contains('AUDIT PASSED'));
    });
  });

  group('live gate — the real core_app tree', () {
    test('core_app/lib scans with zero findings across all pattern laws', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'test must run from core_app/');
      final findings = verify.scanPatternLaws(lib);
      expect(findings, isEmpty, reason: findings.join('\n'));
    });
  });
}

/// Plants the four Law 21/13/18/26 required files under [root].
void _plantRequiredFiles(Directory root) {
  for (final path in const [
    '.git/hooks/pre-push',
    'tool/measure_apk.sh',
    'staging.firestore.rules',
    'DEFERRED.md',
  ]) {
    final file = File(
      '${root.path}${Platform.pathSeparator}'
      '${path.replaceAll('/', Platform.pathSeparator)}',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('p27 fixture\n');
  }
}

String _canonical(String path) => path.replaceAll('\\', '/').toLowerCase();
