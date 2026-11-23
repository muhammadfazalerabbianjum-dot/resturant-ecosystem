import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// p36 T-6 (spec `WHITE_LABEL_p36_generator_grade.md` S7, discovered live by
/// Attestation L): the generator's `flutter create` baseline ships a ROOT
/// `android/build.gradle.kts` without the AGP-8 namespace shim, so the
/// isar_flutter_libs 3.1.0+1 plugin (pulled by the labs path dep) dies at
/// configuration with "Namespace not specified" on every fresh stamp.
///
/// Shipped shells carry the reflection shim by hand (`apps/halal_boyz/
/// android/build.gradle.kts`, ARCH-1 LEDGER) — the generator must now emit
/// it with the proven aligner contract:
///
/// - stock flutter create baseline (allprojects anchor, no shim) -> shim inserted,
/// - already-shipped shape (shim present) -> byte-identical no-op,
/// - anything else -> StateError (fail-closed).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('whitelabel_shim_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final sep = Platform.pathSeparator;

  /// The stock root build.gradle.kts as this machine's pinned Flutter SDK
  /// template emits it (redirect block present, namespace shim absent) —
  /// byte-pinned from `A:\flutter\packages\flutter_tools\templates\app\
  /// android-kotlin.tmpl\build.gradle.kts.tmpl`.
  const stockRoot = '''
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
''';

  File rootGradle(String content) {
    final file = File('${tempDir.path}${sep}android${sep}build.gradle.kts');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file;
  }

  group(
    'T-6: alignAndroidNamespaceShim gates the stock flutter create baseline',
    () {
      test('stock root kts receives the shipped reflection shim bytes', () {
        final file = rootGradle(stockRoot);
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        final gated = file.readAsStringSync();
        // The shim must be byte-identical to the shipped halal block
        // (code only; the shipped ARCH-1 ledger comment stays hand-owned).
        const shimStart = 'subprojects {\n    afterEvaluate {';
        expect(
          gated.contains(shimStart),
          isTrue,
          reason: 'namespace shim block must be inserted',
        );
        expect(gated, contains('setNamespace.invoke(androidExt, pkg)'));
        expect(gated, contains('getNamespace.invoke(androidExt) != null'));
        expect(gated, contains('Regex("package'));
        // Inserted after the allprojects anchor, before the redirect block.
        expect(
          gated.indexOf(shimStart),
          greaterThan(gated.indexOf('allprojects')),
        );
        expect(
          gated.indexOf(shimStart),
          lessThan(gated.indexOf('val newBuildDir')),
        );
        // Stock anchor survives (no text lost).
        expect(gated, contains('rootProject.layout.buildDirectory'));
        expect(gated, contains('tasks.register<Delete>("clean")'));
      });

      test('second run is a byte-identical no-op (idempotent)', () {
        final file = rootGradle(stockRoot);
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        final first = file.readAsStringSync();
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        expect(
          file.readAsStringSync(),
          equals(first),
          reason: 'shimmed file must be byte-untouched on the second run',
        );
      });

      test('CRLF stock baseline (real Windows flutter create) shims with CRLF '
          'preserved', () {
        final crlfStock = stockRoot.replaceAll('\n', '\r\n');
        final file = rootGradle(crlfStock);
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        final gated = file.readAsStringSync();
        expect(
          gated.contains('setNamespace.invoke(androidExt'),
          isTrue,
          reason: 'shim must land on the real CRLF flutter create output',
        );
        expect(
          RegExp(r'(?<!\r)\n').hasMatch(gated),
          isFalse,
          reason: 'every line must stay CRLF (no lone LF introduced)',
        );
        // Second run: still idempotent under CRLF.
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        expect(file.readAsStringSync(), equals(gated));
      });

      test('already-shipped (halal) shape is byte-untouched', () {
        // Real shipped bytes minus the hand-owned ledger comment still
        // contain the full shim -> recognized, no rewrite.
        final shipped = File(
          '${_findRepoRoot().path}$sep${'apps'}$sep${'halal_boyz'}$sep'
          '${'android'}$sep${'build.gradle.kts'}',
        ).readAsStringSync();
        final file = rootGradle(shipped);
        whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path);
        expect(file.readAsStringSync(), equals(shipped));
      });

      test('unrecognized root kts fails closed with StateError', () {
        final file = rootGradle(
          '// nothing recognizable here\ndependencies {}\n',
        );
        expect(
          () => whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path),
          throwsStateError,
        );
        expect(file.existsSync(), isTrue, reason: 'no rewrite on failure');
      });

      test('missing root kts fails closed with StateError', () {
        expect(
          () => whitelabel.alignAndroidNamespaceShim(appPath: tempDir.path),
          throwsStateError,
        );
      });
    },
  );
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(
      '${dir.path}${Platform.pathSeparator}WHITE_LABEL_BATCHES.md',
    ).existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
