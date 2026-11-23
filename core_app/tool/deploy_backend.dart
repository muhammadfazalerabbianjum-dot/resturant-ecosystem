// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps
//
// BACKEND-1 (W7.1, 09-P0-FB-1) Ã¢â‚¬â€ per-client backend deploy tool.
//
//   dart run tool/deploy_backend.dart --app <dir> [--check-only]
//   npm run deploy:backend -- --app <dir>
//
// Expects `apps/<dir>/backend/` Ã¢â‚¬â€ the per-client bundle the generator
// (tool/whitelabel.dart) emits: firestore.rules, storage.rules,
// firestore.indexes.json, .firebaserc (projects.default) and firebase.json
// (whose functions.source points at the SHARED core_app/functions).
//
// Preflight is FAIL-CLOSED: every check must PROVE the project is ready
// (reachable, Stripe secrets present, Android+iOS apps registered, bundle
// intact) before the deploy may start. Any failure aborts with a clean error
// and exit != 0 Ã¢â‚¬â€ the tool never deploys a half-provisioned backend.
import 'dart:convert';
import 'dart:io';

/// One `firebase` CLI invocation the preflight runs before deploying.
typedef PreflightCheck = ({String name, List<String> args});

/// The outcome of one preflight check (pass + human-readable detail).
typedef PreflightResult = ({bool pass, String detail});

/// The exact preflight `firebase` invocations (data, so tests pin the
/// contract without ever invoking the live CLI).
List<PreflightCheck> preflightFirebaseChecks(String projectId) =>
    <PreflightCheck>[
      (name: 'project-reachable', args: <String>['projects:list', '--json']),
      (
        name: 'stripe-secret-key',
        args: <String>[
          'functions:secrets:access',
          'STRIPE_SECRET_KEY',
          '--project',
          projectId,
        ],
      ),
      (
        name: 'stripe-webhook-secret',
        args: <String>[
          'functions:secrets:access',
          'STRIPE_WEBHOOK_SECRET',
          '--project',
          projectId,
        ],
      ),
      (
        name: 'app-check-apps',
        args: <String>['apps:list', '--project', projectId, '--json'],
      ),
    ];

/// The deploy invocation the tool runs once every preflight check PASSes.
List<String> deployArgs(String projectId) => <String>[
  'deploy',
  '--only',
  'firestore:rules,firestore:indexes,storage,functions',
  '--project',
  projectId,
];

/// Reads `projects.default` from the bundle's `.firebaserc`.
///
/// Throws [FormatException] (never returns an empty id) so the caller can
/// fail closed with a clean message.
String backendProjectId(String backendPath) {
  final sep = Platform.pathSeparator;
  final file = File('$backendPath${sep}.firebaserc');
  if (!file.existsSync()) {
    throw const FormatException(
      '.firebaserc missing Ã¢â‚¬â€ the app was not generated with the backend bundle.',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('.firebaserc root must be a JSON object.');
  }
  final projects = decoded['projects'];
  if (projects is! Map<String, dynamic>) {
    throw const FormatException(
      '.firebaserc must contain a "projects" object.',
    );
  }
  final projectId = projects['default'];
  if (projectId is! String || projectId.trim().isEmpty) {
    throw const FormatException(
      '.firebaserc "projects.default" must be a non-empty string.',
    );
  }
  return projectId;
}

/// Integrity check of the generated bundle + the shared functions source it
/// points at. Runs synchronously (no live CLI) and always reports PASS/FAIL.
PreflightResult checkBackendBundle(String backendPath, Directory repoRoot) {
  const names = <String>[
    '.firebaserc',
    'firebase.json',
    'firestore.rules',
    'storage.rules',
    'firestore.indexes.json',
  ];
  final sep = Platform.pathSeparator;
  final missing = <String>[
    for (final name in names)
      if (!File('$backendPath${sep}$name').existsSync()) name,
  ];
  if (missing.isNotEmpty) {
    return (pass: false, detail: 'missing bundle files: ${missing.join(', ')}');
  }
  final functionsPkg = File(
    '${repoRoot.path}${sep}core_app${sep}functions${sep}package.json',
  );
  if (!functionsPkg.existsSync()) {
    return (
      pass: false,
      detail: 'shared functions source missing: ${functionsPkg.path}',
    );
  }
  return (
    pass: true,
    detail: '5/5 bundle files + shared functions source present',
  );
}

/// Full preflight + deploy flow. Returns the process exit code so it can be
/// driven by both `main` and tests.
///
/// [repoRootOverride] exists ONLY for tests that must not write to / depend on
/// the real workspace layout (the live CLI checks are never reached by those
/// tests).
Future<int> runTool(List<String> args, {Directory? repoRootOverride}) async {
  final appDirName = _flagValue(args, '--app');
  final checkOnly = args.contains('--check-only');
  if (appDirName == null) {
    _printUsage();
    return 64;
  }

  final repoRoot = repoRootOverride ?? _findRepoRoot();
  final sep = Platform.pathSeparator;
  final backendPath =
      '${repoRoot.path}${sep}apps${sep}$appDirName${sep}backend';

  if (!Directory(backendPath).existsSync()) {
    stderr.writeln('ERROR: no backend bundle at $backendPath.');
    stderr.writeln(
      '       Generate the app first: '
      'dart run tool/whitelabel.dart --config <config> [--regenerate]',
    );
    return 66;
  }

  final String projectId;
  try {
    projectId = backendProjectId(backendPath);
  } on FormatException catch (error) {
    stderr.writeln('ERROR: $error');
    return 65;
  }

  print('=== Backend deploy preflight Ã¢â‚¬â€ project: $projectId ===');
  var allPassed = true;
  for (final check in preflightFirebaseChecks(projectId)) {
    final result = await _runPreflightCheck(check, projectId);
    final detail = result.detail.isEmpty ? '' : ' Ã¢â‚¬â€ ${result.detail}';
    print('  ${result.pass ? 'PASS' : 'FAIL'}  ${check.name}$detail');
    allPassed = allPassed && result.pass;
  }
  final bundle = checkBackendBundle(backendPath, repoRoot);
  print(
    '  ${bundle.pass ? 'PASS' : 'FAIL'}  bundle-integrity'
    '${bundle.detail.isEmpty ? '' : ' Ã¢â‚¬â€ ${bundle.detail}'}',
  );
  allPassed = allPassed && bundle.pass;

  if (!allPassed) {
    stderr.writeln('PREFLIGHT FAILED Ã¢â‚¬â€ deploy aborted (fail-closed).');
    return 1;
  }
  if (checkOnly) {
    print('PREFLIGHT: all checks PASSED (--check-only; nothing deployed).');
    return 0;
  }

  print(
    '=== Preflight PASSED Ã¢â‚¬â€ deploying '
    'firestore:rules,firestore:indexes,storage,functions ===',
  );
  final process = await _runFirebase(
    deployArgs(projectId),
    workingDirectory: backendPath,
  );
  if (process.stdout is String) {
    stdout.write(process.stdout as String);
  }
  if (process.exitCode != 0) {
    if (process.stderr is String) {
      stderr.write(process.stderr as String);
    }
    stderr.writeln(
      '\nfirebase deploy failed with exit code ${process.exitCode}.',
    );
  }
  return process.exitCode;
}

Future<void> main(List<String> args) async {
  exitCode = await runTool(args);
}

Future<PreflightResult> _runPreflightCheck(
  PreflightCheck check,
  String projectId,
) async {
  final process = await _runFirebase(check.args);
  final stdout = process.stdout is String ? process.stdout as String : '';
  switch (check.name) {
    case 'project-reachable':
      if (process.exitCode != 0) {
        return (
          pass: false,
          detail: 'firebase projects:list exit ${process.exitCode}',
        );
      }
      final found = _jsonContainsProject(stdout, projectId);
      return (
        pass: found,
        detail: found
            ? ''
            : 'projectId "$projectId" not listed among reachable projects',
      );
    case 'stripe-secret-key':
    case 'stripe-webhook-secret':
      final ok = process.exitCode == 0;
      return (
        pass: ok,
        detail: ok
            ? 'secret accessible'
            : 'missing/not accessible Ã¢â‚¬â€ set it with '
                  'firebase functions:secrets:set (runbook step 6)',
      );
    case 'app-check-apps':
      if (process.exitCode != 0) {
        return (
          pass: false,
          detail: 'firebase apps:list exit ${process.exitCode}',
        );
      }
      return (
        pass: _hasAndroidAndIos(stdout),
        detail: 'Android + iOS apps registered',
      );
    default:
      return (pass: false, detail: 'unknown preflight check "${check.name}"');
  }
}

bool _jsonContainsProject(String stdout, String projectId) {
  try {
    final decoded = jsonDecode(stdout);
    final projects = decoded is List
        ? decoded
        : (decoded is Map && decoded['projects'] is List)
        ? decoded['projects'] as List
        : const <dynamic>[];
    return projects.any((p) => p is Map && p['projectId'] == projectId);
  } catch (_) {
    // Fail-closed: an unparseable response cannot prove reachability.
    return false;
  }
}

bool _hasAndroidAndIos(String stdout) {
  final platforms = <String>[];
  try {
    final decoded = jsonDecode(stdout);
    final apps = decoded is List
        ? decoded
        : (decoded is Map && decoded['apps'] is List)
        ? decoded['apps'] as List
        : const <dynamic>[];
    platforms.addAll(<String>[
      for (final app in apps)
        if (app is Map && app['platform'] is String) app['platform'] as String,
    ]);
  } catch (_) {
    return false;
  }
  final normalized = platforms.map((p) => p.toUpperCase()).toSet();
  return normalized.contains('ANDROID') && normalized.contains('IOS');
}

Future<ProcessResult> _runFirebase(
  List<String> args, {
  String? workingDirectory,
}) {
  if (Platform.isWindows) {
    // `firebase` on Windows is a .cmd shim that needs cmd /c like the other
    // repo tools' _resolvedCommand pattern.
    return Process.run('cmd', <String>[
      '/c',
      'firebase',
      ...args,
    ], workingDirectory: workingDirectory);
  }
  return Process.run('firebase', args, workingDirectory: workingDirectory);
}

String? _flagValue(List<String> args, String flag, {String? fallback}) {
  final index = args.indexOf(flag);
  return (index == -1 || index + 1 >= args.length) ? fallback : args[index + 1];
}

Directory _findRepoRoot() {
  Directory? dir = File.fromUri(Platform.script).parent;
  while (dir != null) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    final core = Directory(
      '${dir.path}${Platform.pathSeparator}packages${Platform.pathSeparator}core',
    );
    if (pubspec.existsSync() && core.existsSync()) return dir;
    dir = dir.parent == dir ? null : dir.parent;
  }
  throw StateError(
    'Could not locate monorepo root (a directory containing pubspec.yaml '
    'and packages/core).',
  );
}

void _printUsage() {
  print('Usage: dart run tool/deploy_backend.dart --app <dir> [--check-only]');
  print('');
  print('Options:');
  print(
    '  --app <dir>    (required) The generated app directory under apps/ '
    '(e.g. halal_boyz). Its backend/ bundle must exist.',
  );
  print(
    '  --check-only   Run the preflight checks and report PASS/FAIL per '
    'check without deploying.',
  );
}
