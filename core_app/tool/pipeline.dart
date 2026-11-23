/// Law 10 — the Master Pipeline Gate. Implemented for real by p26 T-1
/// (D-P26-3(i)); the previous 3-line stub ("Pipeline check passed.") is
/// gone. Exit contract: 0 = every gate green, 1 = a gate failed, 2 = bad
/// usage. Emulator/deploy/store phases stay CI-only in
/// `.github/workflows/carnama_ci.yml` — this gate runs exactly the local
/// gates the constitution's PART 9 names for a developer machine (format,
/// analyze, tests) and never fakes the ones it cannot honestly run.
library;

import 'dart:io';

/// Result of one gate.
class GateResult {
  const GateResult(this.ok, this.detail);

  final bool ok;

  /// Empty on success; failure context (exit code + output tail) otherwise.
  final String detail;
}

/// A named pipeline step.
class Gate {
  const Gate(this.name, this.run);

  final String name;
  final Future<GateResult> Function() run;
}

/// Process runner seam so the repo test can pin failure exits without
/// spawning the real 4-minute battery.
typedef CmdRunner =
    Future<ProcessResult> Function(
      String exe,
      List<String> args, {
      String? workingDirectory,
    });

/// Platform-correct runner: on Windows `dart`/`flutter` are `.bat` shims, so
/// the command goes through `cmd /c` (the `tag_release_test.dart` precedent).
Future<ProcessResult> runCmd(
  String exe,
  List<String> args, {
  String? workingDirectory,
}) {
  final useCmd = Platform.isWindows;
  return Process.run(
    useCmd ? 'cmd' : exe,
    useCmd ? <String>['/c', exe, ...args] : args,
    workingDirectory: workingDirectory,
  );
}

/// Tail of a captured stream for failure context (bounded output).
String streamTail(Object? text, {int max = 600}) {
  final value = text.toString().trim();
  return value.length <= max ? value : value.substring(value.length - max);
}

/// Run [gates] in order, fail fast. Returns the process exit code.
Future<int> runPipeline(List<Gate> gates, {StringSink? out}) async {
  final sink = out ?? stdout;
  for (final gate in gates) {
    sink.write('[gate] ${gate.name} ... ');
    final result = await gate.run();
    if (!result.ok) {
      sink.writeln('FAILED');
      sink.writeln(result.detail);
      sink.writeln('[gate] ${gate.name} FAILED -> pipeline exit 1');
      return 1;
    }
    sink.writeln('ok');
  }
  sink.writeln('[pipeline] all ${gates.length} gates green -> exit 0');
  return 0;
}

/// The repo root above `core_app/` (walks up from [from], defaulting to the
/// working directory).
String pipelineRepoRoot([String? from]) {
  final sep = Platform.pathSeparator;
  var dir = Directory(from ?? Directory.current.path).absolute;
  while (true) {
    if (Directory(
          '${dir.path}$sep'
          'core_app',
        ).existsSync() &&
        Directory(
          '${dir.path}$sep'
          'packages',
        ).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw FileSystemException(
        'repo root not found above',
        Directory.current.path,
      );
    }
    dir = parent;
  }
}

/// The real gates, in constitution PART 9 order:
/// 1. `dart format --output=none --set-exit-if-changed .` (repo root)
/// 2. `flutter analyze --fatal-infos` (core_app)
/// 3. `flutter test --exclude-tags=e2e,nightly,needs-emulator` (core_app)
List<Gate> realGates(CmdRunner runner) {
  final sep = Platform.pathSeparator;
  final root = pipelineRepoRoot();
  final coreApp = '$root${sep}core_app';
  return <Gate>[
    Gate('format', () async {
      final result = await runner('dart', <String>[
        'format',
        '--output=none',
        '--set-exit-if-changed',
        '.',
      ], workingDirectory: root);
      if (result.exitCode == 0) {
        return const GateResult(true, '');
      }
      return GateResult(
        false,
        'exit ${result.exitCode}\n${streamTail(result.stdout)}'
        '\n${streamTail(result.stderr)}',
      );
    }),
    Gate('analyze', () async {
      final result = await runner('flutter', <String>[
        'analyze',
        '--fatal-infos',
      ], workingDirectory: coreApp);
      if (result.exitCode == 0) {
        return const GateResult(true, '');
      }
      return GateResult(
        false,
        'exit ${result.exitCode}\n${streamTail(result.stdout)}'
        '\n${streamTail(result.stderr)}',
      );
    }),
    Gate('tests', () async {
      final result = await runner('flutter', <String>[
        'test',
        '--exclude-tags=e2e,nightly,needs-emulator',
      ], workingDirectory: coreApp);
      if (result.exitCode == 0) {
        return const GateResult(true, '');
      }
      return GateResult(
        false,
        'exit ${result.exitCode}\n${streamTail(result.stdout)}'
        '\n${streamTail(result.stderr)}',
      );
    }),
  ];
}

const String _usage =
    'Usage: dart tool/pipeline.dart\n'
    '  --list   print the gate names without running them\n'
    '  --help   this text\n'
    'Exit: 0 = all gates green; 1 = a gate failed; 2 = bad usage.';

/// CLI core (testable in-process; [main] only wires the exit code).
Future<int> pipelineMain(
  List<String> args, {
  StringSink? out,
  CmdRunner? runner,
}) async {
  final sink = out ?? stdout;
  if (args.contains('--help') || args.contains('-h')) {
    sink.writeln(_usage);
    return 0;
  }
  if (args.contains('--list')) {
    for (final gate in realGates(runner ?? runCmd)) {
      sink.writeln(gate.name);
    }
    return 0;
  }
  if (args.isNotEmpty) {
    sink.writeln('unknown argument: ${args.join(' ')}');
    sink.writeln(_usage);
    return 2;
  }
  return runPipeline(realGates(runner ?? runCmd), out: sink);
}

/// `dart tool/pipeline.dart` entry point (Law 10).
Future<void> main(List<String> args) async {
  exitCode = await pipelineMain(args);
}
