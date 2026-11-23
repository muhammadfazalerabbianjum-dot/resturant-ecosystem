/// The Carnama constitution guard (Law 3 / 4 / 12 / 16 surface check over
/// `core_app/lib`).
///
/// v2 (p26 post-merge hardening): the rules now match MEANING, not bare
/// substrings — word-bounded patterns over the CODE portion of each line
/// (comments are prose; `BrandColors.`, `isValidHexColor(` and
/// `buildOrderAttemptFingerprint(` are correct code), while `// TODO` markers
/// are still read from the comment where they live. `test/tool/
/// constitution_guard_test.dart` pins BOTH directions: every rule class keeps
/// a positive control (falsifiable, never vacuously green) and the code the
/// v1 matcher mis-flagged stays silent; the live gate is `lib/` scanning to 0.
library;

import 'dart:io';

/// One violation the guard detected. [rule] is one of the four
/// [ConstitutionViolation.rule*] constants.
class ConstitutionViolation {
  const ConstitutionViolation({
    required this.rule,
    required this.path,
    required this.line,
    required this.text,
  });

  /// Non-`const` color literal in code (`Colors.x` / `Color(0x…)`).
  static const String ruleColor = 'COLOR';

  /// `// TODO` / `// FIXME` marker (Law 4: zero stub tolerance).
  static const String ruleTodo = 'TODO';

  /// A real `print(` call (Law 11: logs go through the logger).
  static const String rulePrint = 'PRINT';

  /// A direct `package:firebase_auth` import (Law 12/DI: the SDK stays behind
  /// core's repository — feature code never binds it).
  static const String ruleFirebaseAuth = 'FBAUTH';

  final String rule;
  final String path;
  final int line;
  final String text;

  @override
  String toString() => '$path:$line [$rule] $text';
}

/// Word-bounded `Color(` whose first argument starts with a digit — a
/// hardcoded literal (`Color(0xFF…)`), never a runtime value like
/// `Color(parsed)` from a config parser.
final RegExp colorLiteralPattern = RegExp(r'(?<![A-Za-z0-9_])Color\(\s*\d');

/// Word-bounded `Colors.` — the raw Material palette in code. The lookbehind
/// is what keeps the token layer (`BrandColors.of(...)`) out of the findings.
final RegExp materialColorPattern = RegExp(r'(?<![A-Za-z0-9_])Colors\.');

/// Word-bounded `print(` — real logging calls only. The lookbehind is what
/// keeps `buildOrderAttemptFingerprint(` out of the findings.
final RegExp printCallPattern = RegExp(r'(?<![A-Za-z0-9_])print\(');

/// The CODE portion of a trimmed line: everything before a `//` comment that
/// is not inside a single- or double-quoted string, and `''` for a
/// comment-only line. Prose can then mention anything (Law 14 "why" comments
/// legitimately document past defects such as "Colors.orange replaced") while
/// detectors only ever see code. Boundary, stated honestly: a `//` inside a
/// *multiline* string is treated as a comment start because the scan is
/// line-wise by design — no such line exists in `lib/`, and the live-gate test
/// is what keeps that true.
String codePortionOf(String trimmedLine) {
  if (trimmedLine.startsWith('//')) return '';
  var quote = '';
  for (var i = 0; i < trimmedLine.length - 1; i++) {
    final ch = trimmedLine[i];
    if (quote.isEmpty && ch == '/' && trimmedLine[i + 1] == '/') {
      return trimmedLine.substring(0, i);
    }
    if (quote.isEmpty) {
      if (ch == "'" || ch == '"') quote = ch;
    } else if (quote == ch) {
      quote = '';
    }
  }
  return trimmedLine;
}

/// Scans one source's lines against the four rules. COLOR/PRINT/FBAUTH read
/// the CODE portion; the TODO marker is read from the comment where it lives.
/// Skipping generated files is [scanDirectory]'s job, so this function
/// reports exactly what it is given.
List<ConstitutionViolation> scanLines(
  Iterable<String> lines, {
  required String path,
}) {
  final findings = <ConstitutionViolation>[];
  var number = 0;
  for (final raw in lines) {
    number++;
    final text = raw.trim();

    // The only sanctioned escapes: a whole-line `// ignore:` (this repo never
    // writes one) and coverage markers on their own line.
    if (text.startsWith('//') &&
        (text.contains('// ignore:') || text.contains('// coverage'))) {
      continue;
    }

    final code = codePortionOf(text);

    void add(String rule) {
      findings.add(
        ConstitutionViolation(rule: rule, path: path, line: number, text: text),
      );
    }

    if (code.isNotEmpty &&
        (colorLiteralPattern.hasMatch(code) ||
            materialColorPattern.hasMatch(code)) &&
        !code.contains('const')) {
      add(ConstitutionViolation.ruleColor);
    }
    if (text.contains('// TODO') || text.contains('// FIXME')) {
      add(ConstitutionViolation.ruleTodo);
    }
    if (code.isNotEmpty && printCallPattern.hasMatch(code)) {
      add(ConstitutionViolation.rulePrint);
    }
    if (code.contains('import') &&
        code.contains('package:firebase_auth/firebase_auth.dart')) {
      add(ConstitutionViolation.ruleFirebaseAuth);
    }
  }
  return findings;
}

/// Scans every non-generated `.dart` file under [dir] in deterministic path
/// order, so output is reproducible across runs.
List<ConstitutionViolation> scanDirectory(Directory dir) {
  final findings = <ConstitutionViolation>[];
  final files = dir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (file.path.endsWith('.g.dart') || file.path.endsWith('.freezed.dart')) {
      continue;
    }
    findings.addAll(scanLines(file.readAsLinesSync(), path: file.path));
  }
  return findings;
}

void main(List<String> args) {
  final projectDir = Directory('lib');
  if (!projectDir.existsSync()) {
    stdout.writeln('No lib/ directory found.');
    exit(1);
  }

  final findings = scanDirectory(projectDir);
  if (findings.isNotEmpty) {
    for (final finding in findings) {
      stdout.writeln(finding);
    }
    stdout.writeln('Constitution violations found: ${findings.length}');
    exit(1);
  } else {
    stdout.writeln('All clean.');
  }
}
