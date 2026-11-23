// ignore_for_file: unnecessary_brace_in_string_interps
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/deploy_backend.dart' as deploy;

/// BACKEND-1 (W7.1): unit coverage for `tool/deploy_backend.dart` â€” the
/// fail-closed deploy tool. No test ever invokes the live `firebase` CLI;
/// the command contract is pinned as data and the fail-closed early-exit
/// paths are driven with a temporary repo-root override.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('deploy_backend_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Directory validBundle({required String projectId}) {
    final sep = Platform.pathSeparator;
    final backend = Directory(
      '${tempDir.path}${sep}apps${sep}scratch_app${sep}backend',
    );
    backend.createSync(recursive: true);
    File('${backend.path}${sep}.firebaserc').writeAsStringSync(
      jsonEncode(<String, dynamic>{
        'projects': <String, dynamic>{'default': projectId},
      }),
    );
    for (final name in const <String>[
      'firebase.json',
      'firestore.rules',
      'storage.rules',
      'firestore.indexes.json',
    ]) {
      File('${backend.path}${sep}$name').writeAsStringSync('{}');
    }
    return backend;
  }

  group('backendProjectId (.firebaserc parser)', () {
    test('reads projects.default', () {
      final backend = validBundle(projectId: 'my-client-project');
      expect(deploy.backendProjectId(backend.path), 'my-client-project');
    });

    test('throws FormatException when .firebaserc is missing', () {
      expect(
        () => deploy.backendProjectId(tempDir.path),
        throwsFormatException,
      );
    });

    test('throws FormatException when projects.default is empty', () {
      final backend = validBundle(projectId: 'ignored');
      File(
        '${backend.path}${Platform.pathSeparator}.firebaserc',
      ).writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'projects': <String, dynamic>{'default': ''},
        }),
      );
      expect(
        () => deploy.backendProjectId(backend.path),
        throwsFormatException,
      );
    });
  });

  group('preflight contract (pinned command sets)', () {
    test('preflightFirebaseChecks covers project + secrets + apps', () {
      final checks = deploy.preflightFirebaseChecks('my-project');
      final names = checks.map((c) => c.name).toList();
      expect(names, [
        'project-reachable',
        'stripe-secret-key',
        'stripe-webhook-secret',
        'app-check-apps',
      ]);

      final allArgs = checks.expand((c) => c.args).toList();
      expect(allArgs, contains('projects:list'));
      expect(allArgs, contains('functions:secrets:access'));
      expect(allArgs, contains('STRIPE_SECRET_KEY'));
      expect(allArgs, contains('STRIPE_WEBHOOK_SECRET'));
      expect(allArgs, contains('apps:list'));
      expect(allArgs, contains('my-project'));
    });

    test('deployArgs pins the exact W7.1 deploy scope + project', () {
      expect(deploy.deployArgs('my-project'), <String>[
        'deploy',
        '--only',
        'firestore:rules,firestore:indexes,storage,functions',
        '--project',
        'my-project',
      ]);
    });
  });

  group('checkBackendBundle (integrity)', () {
    test('passes for a complete bundle + shared functions source', () {
      // repoRootOverride points at the REAL repo root so the shared
      // core_app/functions package.json is found.
      final repoRoot = _findRepoRoot();
      final backend = validBundle(projectId: 'my-project');
      final result = deploy.checkBackendBundle(backend.path, repoRoot);
      expect(result.pass, isTrue, reason: result.detail);
    });

    test('fails with named missing files', () {
      final repoRoot = _findRepoRoot();
      final backend = validBundle(projectId: 'my-project');
      File(
        '${backend.path}${Platform.pathSeparator}firestore.rules',
      ).deleteSync();
      final result = deploy.checkBackendBundle(backend.path, repoRoot);
      expect(result.pass, isFalse);
      expect(result.detail, contains('firestore.rules'));
    });
  });

  group('runTool fail-closed early exits (no live CLI)', () {
    test('missing --app returns 64 (usage)', () async {
      expect(await deploy.runTool(const <String>[]), 64);
    });

    test('missing backend bundle returns 66', () async {
      final repoRoot = Directory(
        '${tempDir.path}${Platform.pathSeparator}fake_root',
      );
      repoRoot.createSync(recursive: true);
      expect(
        await deploy.runTool(const <String>[
          '--app',
          'ghost',
        ], repoRootOverride: repoRoot),
        66,
      );
    });

    test('invalid .firebaserc returns 65', () async {
      final repoRoot = tempDir;
      Directory(
        '${tempDir.path}${Platform.pathSeparator}apps'
        '${Platform.pathSeparator}scratch_app${Platform.pathSeparator}backend',
      ).createSync(recursive: true);
      expect(
        await deploy.runTool(const <String>[
          '--app',
          'scratch_app',
        ], repoRootOverride: repoRoot),
        65,
      );
    });
  });
}

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
