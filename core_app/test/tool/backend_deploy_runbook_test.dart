import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// P37 T-5 — the deploy runbook ships WITH the artifacts (R5).
///
/// R5: the stamp emits `backend/{firestore.rules, storage.rules,
/// firestore.indexes.json, .firebaserc, firebase.json}` and prints their
/// paths, but no copy-paste deploy command and no new-project flutterfire
/// line — the operator had to reconstruct the exact CLI from thin air. This
/// test pins both: the generator source carries the commands, and
/// `writeBackendBundle` emits `backend/DEPLOY.md` next to the artifacts.
Directory _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/core_app/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/packages').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('repo root not found upward from ${Directory.current.path}');
}

void main() {
  const projectId = 'runbook-project-9';
  late Directory tempDir;
  late Directory repoRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('p37_t5_');
    repoRoot = _findRepoRoot();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('P37 T-5 deploy runbook', () {
    test(
      'the generator carries the copy-paste deploy commands (source pin)',
      () {
        final src = File(
          '${repoRoot.path}/core_app/tool/whitelabel.dart',
        ).readAsStringSync();
        expect(src, contains('DEPLOY.md'), reason: 'no runbook emission (R5)');
        expect(src, contains('firebase deploy'));
        expect(src, contains('firebase login'));
        expect(src, contains('flutterfire configure'));
      },
    );

    test('writeBackendBundle emits backend/DEPLOY.md with the commands', () {
      final files = whitelabel.writeBackendBundle(
        appPath: tempDir.path,
        repoRoot: repoRoot,
        projectId: projectId,
      );
      final deploy = File(
        '${tempDir.path}${Platform.pathSeparator}backend'
        '${Platform.pathSeparator}DEPLOY.md',
      );
      expect(
        deploy.existsSync(),
        isTrue,
        reason: 'the stamp must ship the runbook next to the artifacts',
      );
      expect(files, contains(deploy.path));
      final text = deploy.readAsStringSync();
      expect(text, contains('firebase login'));
      expect(text, contains('firebase deploy --project $projectId'));
      expect(text, contains('flutterfire configure'));
      expect(text, contains('--skip-firebase'));
    });
  });
}
