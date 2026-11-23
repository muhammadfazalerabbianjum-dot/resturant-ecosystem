/// Automated verification script for the Carnama Constitution — v2 (p27 T-4).
///
/// v1 could not run on Windows: it shelled out to an external `grep`, its cwd
/// contract was self-contradictory (`File('lib')` needs `core_app`, while
/// `File('.git/hooks/pre-push')` needs the repo root), and it carried an
/// `ignore_for_file: avoid_print` suppression. v2 is Dart-native (no external
/// process), resolves the repo root by walking up (the same idea as
/// `pipeline.dart`'s `pipelineRepoRoot`) for the file-check laws, shares
/// [codePortionOf] with `constitution_guard.dart` (ONE source for both tools:
/// detectors see CODE, comments are prose), and writes via `stdout.writeln`
/// so the suppression is DELETED, not honoured.
///
/// Pattern table — each law pinned in BOTH directions by planted fixtures in
/// `test/tool/verify_constitution_test.dart` (≥1 fixture for all 9 laws):
///
///  * Law 1 — `(assume|guess|probably)` unchanged, over the code portion.
///  * Law 3 — word-bounded `Colors.` + literal `Color(<digit>` over code,
///    const-exempt on the line: the operational reading the guard documents
///    ("no NON-const color literal") — a `static const Color _k = Color(...)`
///    declaration is the legal end state the T-2 design mandates.
///  * Law 4 — `TODO|FIXME` read from the WHOLE line (markers live in
///    comments) plus code `Placeholder(` and `throw UnimplementedError`
///    (net STRONGER than v1; bare prose `placeholder` / `REPLACE_ME` dropped
///    as false-positive classes — D-p27-2).
///  * Law 12 — `role ==` byte-identical; violations are fixed in CODE (the
///    core capability extension), never in the pattern.
///  * Law 16 — `(API_KEY|SECRET)\s*[:=]\s*['"]`: env-var NAMES pass,
///    hardcoded literal assignments fail.
///  * Laws 21/13/18/26 — required files resolved against the REPO ROOT.
///
/// Run from `core_app/`: `dart run tool/verify_constitution.dart` →
/// `AUDIT PASSED` (exit 0) or `AUDIT FAILED` (exit 1).
library;

import 'dart:io';

import 'constitution_guard.dart' show codePortionOf;

/// One detector row of the per-law pattern table. [wholeLine] reads the full
/// trimmed line instead of the code portion (Law 4 markers live in comments);
/// [constExempt] skips lines whose code carries `const` (Law 3's documented
/// exemption — identical to the constitution guard's).
class _Detector {
  const _Detector(
    this.law,
    this.pattern, {
    required this.label,
    this.wholeLine = false,
    this.constExempt = false,
  });

  /// The law id this detector reports violations against, e.g. `Law 3`.
  final String law;

  /// The word-bounded pattern the detector matches.
  final RegExp pattern;

  /// Short human description used in the finding line.
  final String label;

  /// Whether [pattern] is matched against the whole line, not just its code.
  final bool wholeLine;

  /// Whether a `const` in the code portion exempts the line.
  final bool constExempt;
}

/// The per-law pattern table (Laws 1/3/4/12/16; the file laws 21/13/18/26
/// live in [checkFileLaws]). `final`, not `const`: `RegExp` has no const
/// constructor.
final List<_Detector> _detectors = <_Detector>[
  _Detector('Law 1', _law1Pattern, label: 'silent assumption in code'),
  _Detector(
    'Law 3',
    _law3Pattern,
    label: 'hardcoded color literal',
    constExempt: true,
  ),
  _Detector(
    'Law 4',
    _law4MarkerPattern,
    label: 'stub marker (TODO/FIXME)',
    wholeLine: true,
  ),
  _Detector('Law 4', _law4PlaceholderPattern, label: 'Placeholder widget stub'),
  _Detector(
    'Law 4',
    _law4UnimplementedPattern,
    label: 'throw UnimplementedError stub',
  ),
  _Detector('Law 12', _law12Pattern, label: 'role check in Dart code'),
  _Detector('Law 16', _law16Pattern, label: 'hardcoded secret literal'),
];

// ── per-law patterns (byte-spec from WHITE_LABEL_p27 §3) ────────────────────
final RegExp _law1Pattern = RegExp(r'(assume|guess|probably)');
final RegExp _law3Pattern = RegExp(
  r'(?<![A-Za-z0-9_])(?:Colors\.|Color\(\s*\d)',
);
final RegExp _law4MarkerPattern = RegExp(r'TODO|FIXME');
final RegExp _law4PlaceholderPattern = RegExp(
  r'(?<![A-Za-z0-9_])Placeholder\(',
);
final RegExp _law4UnimplementedPattern = RegExp(r'throw\s+UnimplementedError');
final RegExp _law12Pattern = RegExp(r'role ==');
final RegExp _law16Pattern = RegExp(r'''(API_KEY|SECRET)\s*[:=]\s*['"]''');

/// The file-check laws, split by the root they resolve against — HEAD shows
/// `.git/` exists only at the repository root, while `tool/measure_apk.sh`,
/// `staging.firestore.rules` and `DEFERRED.md` live in the PACKAGE root
/// (`core_app/`). Spec §1 listed all four without distinguishing roots; code
/// at HEAD is the source of truth (METHOD §2.4), so a single-root check would
/// fail three laws the constitution already satisfies.
const Map<String, String> _repoRootFiles = <String, String>{
  'Law 21': '.git/hooks/pre-push',
};

const Map<String, String> _packageRootFiles = <String, String>{
  'Law 13': 'tool/measure_apk.sh',
  'Law 18': 'staging.firestore.rules',
  'Law 26': 'DEFERRED.md',
};

/// All nine audited laws, in report order.
const List<String> _allLaws = <String>[
  'Law 1',
  'Law 3',
  'Law 4',
  'Law 12',
  'Law 16',
  'Law 21',
  'Law 13',
  'Law 18',
  'Law 26',
];

/// Scans every `.dart` file under [libDir] (recursive, deterministic path
/// order, generated files included — v1's grep did not skip them either)
/// against the pattern table. Returns one `Law N [FAIL]: path:line: label`
/// string per finding; an empty list means every pattern law is clean.
List<String> scanPatternLaws(Directory libDir) {
  final findings = <String>[];
  final files = libDir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.dart')) continue;
    var lineNumber = 0;
    for (final raw in file.readAsLinesSync()) {
      lineNumber++;
      final text = raw.trim();
      if (text.isEmpty) continue;
      final code = codePortionOf(text);
      for (final detector in _detectors) {
        final target = detector.wholeLine ? text : code;
        if (target.isEmpty) continue;
        if (detector.constExempt && target.contains('const')) continue;
        if (detector.pattern.hasMatch(target)) {
          findings.add(
            '${detector.law} [FAIL]: ${file.path}:$lineNumber: ${detector.label}',
          );
        }
      }
    }
  }
  return findings;
}

/// Checks the four required files of Laws 21/13/18/26: Law 21 against
/// [repoRoot] (the walk-up `.git` holder), Laws 13/18/26 against
/// [packageRoot] (the scanned package — `core_app/` at HEAD). Returns one
/// `Law N [FAIL]: required file missing: <rel>` per absent file.
List<String> checkFileLaws({
  required Directory repoRoot,
  required Directory packageRoot,
}) {
  final findings = <String>[];
  void check(String law, Directory root, String relativePath) {
    final path =
        '${root.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}';
    if (!File(path).existsSync()) {
      findings.add('$law [FAIL]: required file missing: $relativePath');
    }
  }

  _repoRootFiles.forEach((law, rel) => check(law, repoRoot, rel));
  _packageRootFiles.forEach((law, rel) => check(law, packageRoot, rel));
  return findings;
}

/// Walks up from [start] to the nearest directory holding a `.git` entry;
/// `null` when no ancestor qualifies. This is what lets the file laws run
/// from any working directory inside the repository (v1's cwd contract was
/// self-contradictory: `lib` needs `core_app`, `.git/hooks` needs the root).
Directory? findRepoRoot(Directory start) {
  var current = start.absolute;
  while (true) {
    if (Directory(
      '${current.path}${Platform.pathSeparator}.git',
    ).existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

/// Runs the full audit: pattern laws over [libDir], file laws against
/// [repoRoot] (resolved by walk-up when null) and [packageRoot] (the scanned
/// package, defaulting to the working directory — run from `core_app/`).
/// Writes the report to [out] and returns the process exit code:
/// 0 = `AUDIT PASSED`, 1 = `AUDIT FAILED`.
int runAudit({
  required Directory libDir,
  Directory? repoRoot,
  Directory? packageRoot,
  required StringSink out,
}) {
  out.writeln('=============================================');
  out.writeln('CARNAMA CONSTITUTION AUDITOR');
  out.writeln('=============================================');

  if (!libDir.existsSync()) {
    out.writeln('lib [FAIL]: directory not found at ${libDir.path}');
    return _finish(out, 1);
  }

  final findings = <String>[...scanPatternLaws(libDir)];
  final root = repoRoot ?? findRepoRoot(Directory.current);
  if (root == null) {
    findings.add(
      'repo root [FAIL]: no .git ancestor found from ${Directory.current.path}',
    );
  } else {
    findings.addAll(
      checkFileLaws(
        repoRoot: root,
        packageRoot: packageRoot ?? Directory.current,
      ),
    );
  }

  for (final law in _allLaws) {
    final hasFailure = findings.any((f) => f.startsWith('$law [FAIL]'));
    if (!hasFailure) out.writeln('$law [PASS]');
  }
  for (final finding in findings) {
    out.writeln(finding);
  }
  return _finish(out, findings.length);
}

int _finish(StringSink out, int failures) {
  out.writeln('---------------------------------------------');
  if (failures > 0) {
    out.writeln('AUDIT FAILED with $failures violations.');
    return 1;
  }
  out.writeln('AUDIT PASSED. Constitution strictly enforced.');
  return 0;
}

/// CLI entry point — run from `core_app/` (`dart run
/// tool/verify_constitution.dart`).
void main() {
  final code = runAudit(libDir: Directory('lib'), out: stdout);
  exit(code);
}
