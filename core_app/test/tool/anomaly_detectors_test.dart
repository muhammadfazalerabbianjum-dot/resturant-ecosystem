import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/anomaly_detectors.dart' as harness;
import '../../tool/pipeline.dart' as pipeline;
import 'client_config_engine_key_matrix_test.dart' as matrix;
import 'config_key_disposition_test.dart' as disp;

/// UI-16 (p26) T-1 — the harness repo test.
///
/// For EVERY detector: a fixture that makes it FIRE, a fixture/real-tree run
/// where it stays SILENT, and the declaration mechanism that keeps nothing
/// dying unexplained (p26 spec §3 T-1). Law 3 reuse is pinned by the
/// detector-6 parse-parity test: the script's parsers must agree with
/// p25's imported consts exactly, so the key list can only ever exist once.
/// The Law-10 pipeline gate's failure exit is pinned here too
/// (D-P26-3(i)) — via the injected runner seam, without spawning the
/// 4-minute battery; the subprocess tests pin the script's real exit codes.
void main() {
  final repoRoot = harness.findRepoRoot(Directory.current.path);
  final fixtures = '$repoRoot/core_app/test/tool/fixtures/p26';

  group('detector 3 — divergent twins (class 3)', () {
    test('fire: an unpinned concept and a citation without tokens fire', () {
      final outcome = harness.detectDivergentTwins(
        repoRoot: '$fixtures/d3_fire',
        productionRoots: const <String>['core_app/lib'],
        concepts: const <harness.TwinConcept>[
          harness.TwinConcept(
            name: 'fixture-unpinned',
            tokens: <String>['twinA', 'twinB'],
            citations: <String>['parity_missing.md'],
            evidence: 'fixtures/p26/d3_fire',
          ),
          harness.TwinConcept(
            name: 'fixture-citation-empty',
            tokens: <String>['twinA', 'twinB'],
            citations: <String>['notes.md'],
            evidence: 'fixtures/p26/d3_fire',
          ),
          harness.TwinConcept(
            name: 'fixture-single-impl',
            tokens: <String>['twinA', 'ghostToken'],
            citations: <String>[],
            evidence: 'fixtures/p26/d3_fire',
          ),
        ],
      );
      expect(
        outcome.candidates.map((c) => c.key).toSet(),
        <String>{'d3:fixture-unpinned', 'd3:fixture-citation-empty'},
        reason: 'single-impl concepts are not live twins and must not fire',
      );
    });

    test('silent: a pinned concept stays silent', () {
      final outcome = harness.detectDivergentTwins(
        repoRoot: '$fixtures/d3_silent',
        productionRoots: const <String>['core_app/lib'],
        concepts: const <harness.TwinConcept>[
          harness.TwinConcept(
            name: 'fixture-pinned',
            tokens: <String>['twinA', 'twinB'],
            citations: <String>['parity_citation.md'],
            evidence: 'fixtures/p26/d3_silent',
          ),
        ],
      );
      expect(outcome.candidates, isEmpty);
    });

    test(
      'real tree: both documented precedents are pinned (0 candidates)',
      () {
        final outcome = harness.detectDivergentTwins(repoRoot: repoRoot);
        expect(outcome.candidates, isEmpty, reason: outcome.report);
        expect(outcome.report, contains('2 concepts checked'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('detector 5 — orphaned deferrals (class 5)', () {
    test('fire: a deferral naming no existing file is a candidate', () {
      final outcome = harness.detectOrphanedDeferrals(
        repoRoot: '$fixtures/d5_fire',
      );
      expect(outcome.candidates, hasLength(1));
      expect(
        outcome.candidates.single.key,
        startsWith('d5:WHITE_LABEL_p99_fake.md:'),
      );
    });

    test('silent: path refs and bare spec ids both resolve on disk', () {
      final outcome = harness.detectOrphanedDeferrals(
        repoRoot: '$fixtures/d5_silent',
      );
      expect(outcome.candidates, isEmpty, reason: outcome.report);
      expect(outcome.report, contains('2 deferral line(s)'));
    });

    test(
      'real tree: every spec deferral names a file that exists (S5-01)',
      () {
        final outcome = harness.detectOrphanedDeferrals(repoRoot: repoRoot);
        expect(outcome.candidates, isEmpty, reason: outcome.report);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('detector 6 — unconfigured mechanism (class 6)', () {
    final fireRoot = '$fixtures/d6_fire';
    final silentRoot = '$fixtures/d6_silent';
    final fireMatrix = '$fireRoot/matrix_test_source.txt';
    final fireDisposition = '$fireRoot/disposition_test_source.txt';
    final silentMatrix = '$silentRoot/matrix_test_source.txt';
    final silentDisposition = '$silentRoot/disposition_test_source.txt';

    test(
      'fire: unset keys with no allowlist/disposition and a missing config',
      () {
        final outcome = harness.detectUnconfiguredKeys(
          repoRoot: fireRoot,
          matrixTestPath: fireMatrix,
          dispositionTestPath: fireDisposition,
        );
        expect(outcome.candidates.map((c) => c.key).toSet(), <String>{
          'd6:core_app:theme.colors.primary',
          'd6:core_app:theme.shape.cardRadius',
          'd6:halal_boyz:__config__',
        });
      },
    );

    test(
      'silent: value / allowlist / disposition all suppress the finding',
      () {
        final outcome = harness.detectUnconfiguredKeys(
          repoRoot: silentRoot,
          matrixTestPath: silentMatrix,
          dispositionTestPath: silentDisposition,
        );
        expect(outcome.candidates, isEmpty, reason: outcome.report);
        expect(outcome.report, contains('3 engine keys x 2 configs'));
        expect(outcome.report, contains('1 disposition rows reused'));
      },
    );

    test(
      'Law 3 reuse: the parsers agree with p25\'s imported consts exactly',
      () {
        final matrixSource = harness.readText(
          '$repoRoot/core_app/test/tool/'
          'client_config_engine_key_matrix_test.dart',
        );
        final parsed = harness.parseEngineMatrix(matrixSource);
        expect(
          parsed.engineKeys.toSet(),
          matrix.engineKeys.map((k) => k.path).toSet(),
        );
        expect(parsed.shippedConfigs, matrix.shippedConfigs);
        expect(parsed.allowlist.keys.toSet(), matrix.allowlist.keys.toSet());
        matrix.allowlist.forEach((config, entries) {
          expect(
            parsed.allowlist[config]!.keys.toSet(),
            entries.keys.toSet(),
            reason: 'allowlist keys for $config drifted from the matrix test',
          );
        });

        final dispositionSource = harness.readText(
          '$repoRoot/core_app/test/tool/config_key_disposition_test.dart',
        );
        final parsedRegister = harness.parseKeyDispositionRegister(
          dispositionSource,
        );
        expect(
          parsedRegister.keys.toSet(),
          disp.dispositionRegister.map((r) => r.path).toSet(),
        );
        for (final row in disp.dispositionRegister) {
          expect(
            parsedRegister[row.path],
            row.disposition.name,
            reason: 'disposition for ${row.path} drifted from the register',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'real tree: every engine key has a value or a documented disposition',
      () {
        final outcome = harness.detectUnconfiguredKeys(repoRoot: repoRoot);
        expect(outcome.candidates, isEmpty, reason: outcome.report);
        expect(outcome.report, contains('engine keys x 2 configs'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('detector 8 — uncovered surface (class 8)', () {
    test(
      'fire: unassigned, conflicting, and missing-owner-file rows all fire',
      () {
        final outcome = harness.detectUncoveredSurfaces(
          repoRoot: '$fixtures/d8_fire',
        );
        expect(outcome.candidates.map((c) => c.key).toSet(), <String>{
          'd8:M-2',
          'd8:M-3',
          'd8:M-4',
        });
        final conflict = outcome.candidates.firstWhere((c) => c.id == 'M-2');
        expect(conflict.detail, contains('conflicting owners'));

        // Unassigned rows render as UNASSIGNED until declared.
        final bare = harness.renderSurfaceMatrix(
          outcome,
          const <String, harness.Disposition>{},
        );
        expect(bare, contains('**UNASSIGNED**'));

        // Declared rows render with their disposition instead.
        final declared = harness.parseDispositions(
          harness.readText('$fixtures/d8_fire_dispositions.json'),
        );
        final rendered = harness.renderSurfaceMatrix(outcome, declared);
        expect(rendered, isNot(contains('**UNASSIGNED**')));
        expect(rendered, contains("SPEC'D (declared"));
      },
    );

    test('silent: ranged §6 ownership + register surface row resolve', () {
      final outcome = harness.detectUncoveredSurfaces(
        repoRoot: '$fixtures/d8_silent',
      );
      expect(outcome.candidates, isEmpty, reason: 'unexpected candidates');
      expect(outcome.ladderRows, 2);
      expect(outcome.registerRows, 1);
      final rendered = harness.renderSurfaceMatrix(
        outcome,
        const <String, harness.Disposition>{},
      );
      expect(rendered, contains('WHITE_LABEL_p99_fixture.md'));
      expect(rendered, contains('| W2 |'));
      expect(rendered, isNot(contains('**UNASSIGNED**')));
    });

    test(
      'real tree: exactly W-7 fires, matrix has zero unassigned rows',
      () {
        final outcome = harness.detectUncoveredSurfaces(repoRoot: repoRoot);
        expect(
          outcome.candidates.map((c) => c.key).toSet(),
          <String>{'d8:W-7'},
          reason: outcome.candidates.map((c) => c.detail).join('\n'),
        );
        expect(outcome.ladderRows, 15);
        expect(outcome.registerRows, 1);

        final dispositions = harness.parseDispositions(
          harness.readText('$fixtures/dispositions.json'),
        );
        final rendered = harness.renderSurfaceMatrix(outcome, dispositions);
        expect(rendered, isNot(contains('**UNASSIGNED**')));
        expect(rendered, contains('| M-8 |'));
        expect(rendered, contains('WHITE_LABEL_p21_adoption3.md'));
        expect(rendered, contains('FALSE-POSITIVE (declared'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('detector 9 — hand-rolled density (class 9)', () {
    test('fire: sites above the injected baseline regress', () {
      final outcome = harness.detectDensityRegression(
        repoRoot: '$fixtures/d9_fire',
        baselines: const <harness.DensityBaseline>[
          harness.DensityBaseline('ListTile', 2, 1, 'fixture baseline'),
        ],
      );
      expect(outcome.candidates.map((c) => c.key).toSet(), <String>{
        'd9:ListTile',
      });
      expect(outcome.candidates.single.detail, contains('3 site(s)'));
    });

    test('silent: at-baseline density and comment mentions never count', () {
      final outcome = harness.detectDensityRegression(
        repoRoot: '$fixtures/d9_silent',
        baselines: const <harness.DensityBaseline>[
          harness.DensityBaseline('ListTile', 1, 1, 'fixture baseline'),
        ],
      );
      expect(outcome.candidates, isEmpty, reason: outcome.report);
      expect(outcome.report, contains('1 site(s) / 1 file(s)'));
    });

    test(
      'real tree: every adoption-gap token is non-increasing vs §2',
      () {
        final outcome = harness.detectDensityRegression(repoRoot: repoRoot);
        expect(outcome.candidates, isEmpty, reason: outcome.report);
        expect(outcome.report, contains('d9 hand-rolled density'));
        expect(outcome.report, contains('76/33'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('declarations & exit codes', () {
    final realDispositions = '$fixtures/dispositions.json';
    final missingRoot = '$fixtures/no_such_tree';

    test('parseDispositions rejects every malformed shape', () {
      expect(() => harness.parseDispositions('["x"]'), throwsFormatException);
      expect(
        () => harness.parseDispositions('{"k": 3}'),
        throwsFormatException,
      );
      expect(
        () => harness.parseDispositions(
          harness.readText('$fixtures/malformed_dispositions.json'),
        ),
        throwsFormatException,
        reason: 'an invalid status must be rejected, not accepted',
      );
      expect(
        () => harness.parseDispositions(
          '{"k": {"status": "FIXED", "note": "short"}}',
        ),
        throwsFormatException,
        reason: 'a note under 20 chars is not a written disposition',
      );
    });

    test('happy path: the committed dispositions parse', () {
      final parsed = harness.parseDispositions(
        harness.readText(realDispositions),
      );
      expect(parsed.keys, <String>['d8:W-7']);
      expect(parsed['d8:W-7']!.status, 'FALSE-POSITIVE');
    });

    test('harnessMain: help, usage error, and unfindable root', () {
      expect(harness.harnessMain(['--help'], out: StringBuffer()), 0);
      expect(harness.harnessMain(['--bogus'], out: StringBuffer()), 2);
      final temp = Directory.systemTemp.createTempSync('p26_root_');
      try {
        final buf = StringBuffer();
        expect(harness.harnessMain([], out: buf, cwd: temp.path), 2);
        expect(buf.toString(), contains('repo root not found'));
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('exit 0: declared fixture candidates and stale warnings', () {
      final buf = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$fixtures/d8_fire',
          '--dispositions=$fixtures/d8_fire_dispositions.json',
        ], out: buf),
        0,
        reason: buf.toString(),
      );
      expect(buf.toString(), contains('declared d8:M-2'));

      final staleBuf = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$fixtures/d8_silent',
          '--dispositions=$fixtures/stale_dispositions.json',
        ], out: staleBuf),
        0,
      );
      expect(
        staleBuf.toString(),
        contains('stale disposition (no candidate fired): d9:NoSuchTokenEver'),
      );
    });

    test('exit 1: absent dispositions leave candidates undeclared', () {
      final buf = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$fixtures/d8_fire',
          '--dispositions=$fixtures/no_such.json',
        ], out: buf),
        1,
      );
      expect(buf.toString(), contains('dispositions file absent'));
      expect(buf.toString(), contains('UNDECLARED d8:M-3'));
    });

    test('exit 2: unreadable and invalid dispositions', () {
      final badJson = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$fixtures/d8_silent',
          '--dispositions=$fixtures/d5_silent/WHITE_LABEL_p99_fake.md',
        ], out: badJson),
        2,
      );
      expect(badJson.toString(), contains('dispositions unreadable/invalid'));

      final badStatus = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$fixtures/d8_silent',
          '--dispositions=$fixtures/malformed_dispositions.json',
        ], out: badStatus),
        2,
      );
      expect(badStatus.toString(), contains('invalid status'));
    });

    test('a detector error becomes an ERROR candidate, not a crash', () {
      final buf = StringBuffer();
      expect(
        harness.harnessMain(<String>[
          '--root=$missingRoot',
          '--dispositions=$fixtures/no_such.json',
        ], out: buf),
        1,
      );
      for (final id in harness.kDetectorIds) {
        expect(buf.toString(), contains('$id ERROR'));
      }
    });

    test('--emit-matrix writes the matrix (and the d8-error fallback)', () {
      final temp = Directory.systemTemp.createTempSync('p26_matrix_');
      try {
        final target = '${temp.path}${Platform.pathSeparator}matrix.md';
        final buf = StringBuffer();
        expect(
          harness.harnessMain(<String>[
            '--root=$fixtures/d8_silent',
            '--dispositions=$realDispositions',
            '--emit-matrix=$target',
          ], out: buf),
          0,
          reason: buf.toString(),
        );
        final md = File(target).readAsStringSync();
        expect(md, startsWith('# p26 surface'));
        expect(md, contains('| M-1 |'));

        final fallback = '${temp.path}${Platform.pathSeparator}none.md';
        final errBuf = StringBuffer();
        expect(
          harness.harnessMain(<String>[
            '--root=$missingRoot',
            '--dispositions=$fixtures/no_such.json',
            '--emit-matrix=$fallback',
          ], out: errBuf),
          1,
        );
        expect(File(fallback).readAsStringSync(), contains('d8 errored'));
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test(
      'end-to-end on the real tree exits 0',
      () {
        final buf = StringBuffer();
        expect(harness.harnessMain([], out: buf), 0, reason: buf.toString());
        expect(buf.toString(), contains('all candidates declared -> exit 0'));
        expect(buf.toString(), isNot(contains('UNDECLARED')));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('main() wires the exit code (covered via --help)', () {
      final previous = exitCode;
      harness.main(['--help']);
      expect(exitCode, 0);
      exitCode = previous;
    });
  });

  group('subprocess exit contract (real `dart run`)', () {
    Future<ProcessResult> runScript(List<String> args) {
      final command = <String>['run', 'tool/anomaly_detectors.dart', ...args];
      final exe = Platform.isWindows ? 'cmd' : 'dart';
      final exeArgs = Platform.isWindows
          ? <String>['/c', 'dart', ...command]
          : command;
      return Process.run(
        exe,
        exeArgs,
        workingDirectory: Directory.current.path,
      );
    }

    test(
      'dart run exits 0 with the committed dispositions',
      () async {
        final result = await runScript(<String>[]);
        expect(
          result.exitCode,
          0,
          reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(result.stdout.toString(), contains('all candidates declared'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'dart run exits 1 when candidates are undeclared',
      () async {
        final result = await runScript(<String>[
          '--dispositions=test/tool/fixtures/p26/no_such.json',
        ]);
        expect(
          result.exitCode,
          1,
          reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(result.stdout.toString(), contains('UNDECLARED d8:W-7'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('Law-10 pipeline gate (D-P26-3(i))', () {
    test('runPipeline: all green -> 0', () async {
      final buf = StringBuffer();
      final gates = <pipeline.Gate>[
        pipeline.Gate('one', () async => const pipeline.GateResult(true, '')),
        pipeline.Gate('two', () async => const pipeline.GateResult(true, '')),
      ];
      expect(await pipeline.runPipeline(gates, out: buf), 0);
      expect(buf.toString(), contains('all 2 gates green -> exit 0'));
    });

    test('runPipeline: first failure is fail-fast -> 1 with detail', () async {
      final buf = StringBuffer();
      final gates = <pipeline.Gate>[
        pipeline.Gate('one', () async => const pipeline.GateResult(true, '')),
        pipeline.Gate(
          'bad',
          () async => const pipeline.GateResult(false, 'boom detail'),
        ),
        pipeline.Gate('three', () async => const pipeline.GateResult(true, '')),
      ];
      expect(await pipeline.runPipeline(gates, out: buf), 1);
      final text = buf.toString();
      expect(text, contains('[gate] bad FAILED -> pipeline exit 1'));
      expect(text, contains('boom detail'));
      expect(text, isNot(contains('[gate] three')));
    });

    test('pipelineMain: --help / --list / unknown argument', () async {
      expect(await pipeline.pipelineMain(['--help'], out: StringBuffer()), 0);
      final listBuf = StringBuffer();
      expect(await pipeline.pipelineMain(['--list'], out: listBuf), 0);
      expect(
        listBuf.toString().split('\n'),
        containsAllInOrder(<String>['format', 'analyze', 'tests']),
      );
      expect(await pipeline.pipelineMain(['--bogus'], out: StringBuffer()), 2);
    });

    test(
      'realGates through the runner seam: green once, red at each gate',
      () async {
        var calls = 0;
        Future<ProcessResult> green(
          String exe,
          List<String> args, {
          String? workingDirectory,
        }) async {
          calls++;
          return ProcessResult(0, 0, 'ok', '');
        }

        final greenBuf = StringBuffer();
        expect(
          await pipeline.runPipeline(pipeline.realGates(green), out: greenBuf),
          0,
        );
        expect(calls, 3);
        expect(greenBuf.toString(), contains('all 3 gates green'));

        for (var failAt = 1; failAt <= 3; failAt++) {
          var attempt = 0;
          Future<ProcessResult> failing(
            String exe,
            List<String> args, {
            String? workingDirectory,
          }) async {
            attempt++;
            if (attempt == failAt) {
              return ProcessResult(
                0,
                7,
                List<String>.filled(700, 'x').join(),
                'failure from $exe',
              );
            }
            return ProcessResult(0, 0, 'ok', '');
          }

          final buf = StringBuffer();
          expect(
            await pipeline.runPipeline(pipeline.realGates(failing), out: buf),
            1,
            reason: 'gate $failAt must fail the pipeline',
          );
          expect(buf.toString(), contains('exit 7'));
          expect(buf.toString(), contains('failure from'));
        }
      },
    );

    test(
      'pipelineMain runs the battery seam end to end (fake runner)',
      () async {
        Future<ProcessResult> green(
          String exe,
          List<String> args, {
          String? workingDirectory,
        }) async => ProcessResult(0, 0, 'ok', '');
        expect(
          await pipeline.pipelineMain([], out: StringBuffer(), runner: green),
          0,
        );
      },
    );

    test(
      'runCmd executes for real (dart --version)',
      () async {
        final result = await pipeline.runCmd('dart', <String>['--version']);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('pipelineRepoRoot throws above a rootless tree', () {
      final temp = Directory.systemTemp.createTempSync('p26_pipeline_');
      try {
        expect(
          () => pipeline.pipelineRepoRoot(temp.path),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('main() wires the exit code (covered via --list)', () async {
      final previous = exitCode;
      await pipeline.main(['--list']);
      expect(exitCode, 0);
      exitCode = previous;
    });
  });
}
