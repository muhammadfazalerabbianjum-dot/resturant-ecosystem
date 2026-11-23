// P32 T-4 — golden-gate hygiene pin (p25 L-P4 law, inherited).
//
// p31 §Q11 defect N-1: a sync `expect(..., matchesGoldenFile(...))` never awaits
// the comparison, so the golden detaches — artifacts are still written but the
// test passes on a pixel mismatch (6 of 66 sites were void). This pin scans
// every Dart file under `core_app/test/**` and fails naming file:line for any
// `matchesGoldenFile` statement that is not awaited through `expectLater`.
//
// The scanner excludes its own file (it holds the pattern literals).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [window] chars before a `matchesGoldenFile(` call are enough to see which
/// statement wraps it — the matcher is always the last argument.
const int _window = 600;

List<String> _violationsIn(File file) {
  final text = file.readAsStringSync();
  final violations = <String>[];
  var offset = 0;
  while (true) {
    final idx = text.indexOf('matchesGoldenFile(', offset);
    if (idx < 0) break;
    offset = idx + 1;
    final start = idx - _window < 0 ? 0 : idx - _window;
    final window = text.substring(start, idx);
    final laterMatches = <RegExpMatch>[
      ...RegExp(r'\bexpectLater\(').allMatches(window),
    ];
    final syncMatches = <RegExpMatch>[
      ...RegExp(r'\bexpect\(').allMatches(window),
    ];
    final laterAt = laterMatches.isEmpty ? -1 : laterMatches.last.start;
    final syncAt = syncMatches.isEmpty ? -1 : syncMatches.last.start;
    if (syncAt > laterAt) {
      final line = text.substring(0, idx).split('\n').length;
      violations.add('${file.path}:$line');
    }
  }
  return violations;
}

void main() {
  test(
    'every matchesGoldenFile in core_app/test is awaited via expectLater',
    () {
      final testRoot = Directory('test');
      expect(
        testRoot.existsSync(),
        isTrue,
        reason: 'flutter test runs from the core_app package root',
      );
      final violations = <String>[];
      final dartFiles =
          testRoot
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in dartFiles) {
        final normalized = file.path.replaceAll('\\', '/');
        if (normalized.endsWith('test/ui/golden_gate_hygiene_test.dart')) {
          continue; // the scanner itself carries the pattern literals
        }
        violations.addAll(_violationsIn(file));
      }
      expect(
        violations,
        isEmpty,
        reason:
            'sync expect(...) around matchesGoldenFile lets a pixel mismatch '
            'pass silently (p31 N-1). Convert to `await expectLater(` at:\n'
            '${violations.join('\n')}',
      );
    },
  );
}
