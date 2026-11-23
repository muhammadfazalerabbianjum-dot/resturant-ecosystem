// p26 T-2 negative guard — the determinism law (B7 §0.7): no test may depend
// on state that survives a run, and the machine-global `%TEMP%` log
// generations (`app_logs.txt` / `app_logs.1.txt`) are exactly that: shared by
// every suite, worktree and run. Every test logger must sink into its OWN
// per-test directory (`Directory.systemTemp.createTempSync(...)`), and the
// production TaxService default must not target the temp dir at all.
//
// RED before the fix: 83 injection sites across 64 files (see
// `tool_uilib/p26/receipts/t2_census.txt`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Machine-global sink: `testDirectory: Directory.systemTemp` (the bare
/// value) WITHOUT a following `.createTempSync(...)` — the shared file, not a
/// private dir.
final RegExp _machineGlobalSink = RegExp(
  r'testDirectory:\s*Directory\.systemTemp(?!\.)',
);

void main() {
  group('p26 T-2 temp-log guard', () {
    test('no test injects the machine-global temp dir as a logger sink', () {
      final List<String> offenders = <String>[];
      // Fleet scope: every member's test tree (guards are written from
      // core_app, cwd = core_app root during `flutter test`).
      const List<String> roots = <String>[
        'test',
        '../packages/core/test',
        '../packages/core_ui/test',
        '../../apps/halal_boyz/test',
      ];
      final List<FileSystemEntity> entities = <FileSystemEntity>[
        for (final String root in roots)
          if (Directory(root).existsSync())
            ...Directory(root).listSync(recursive: true),
      ];
      for (final FileSystemEntity entity in entities) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // Self-exclusion: this guard quotes the forbidden pattern in its own
        // failure message (and in the RegExp source above) — scanning itself
        // would flag the detector instead of the fleet.
        if (entity.path.endsWith('temp_log_guard_test.dart')) continue;
        final int hits = _machineGlobalSink
            .allMatches(entity.readAsStringSync())
            .length;
        if (hits > 0) {
          offenders.add('${entity.path} ($hits site${hits == 1 ? '' : 's'})');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A test injects the BARE systemTemp value as its LoggerService '
            'sink, which shares one machine-global file across every '
            'test/run. Inject a per-test directory instead: '
            'LoggerService(testDirectory: Directory.systemTemp'
            ".createTempSync('carnama_logs_')). Offenders: $offenders",
      );
    });

    test('tax_service production default does not target the temp dir', () {
      // flutter test runs with the package root (core_app) as cwd; the
      // pinned file is the production default at tax_service.dart:16
      // (`logger ?? LoggerService(...)`).
      final File source = File(
        '${Directory.current.path}/../packages/core/lib/src/tax/'
        'tax_service.dart',
      );
      expect(source.existsSync(), isTrue, reason: 'pinned file moved');
      final String text = source.readAsStringSync();
      expect(
        text.contains('Directory.systemTemp'),
        isFalse,
        reason:
            'TaxService must fall back to LoggerService() (production '
            'documents dir), never the machine-global temp dir — D-P26-1 '
            'determinism half, p26 T-2.',
      );
      expect(
        text.contains('logger ?? LoggerService()'),
        isTrue,
        reason: 'the default must be the bare production LoggerService',
      );
    });
  });
}
