import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/tag_release.dart';

/// RELEASE-1 / W11.2 (T-2): the tag tool reads the canonical version from
/// `core_app/pubspec.yaml` and would create an annotated `v<version>` tag
/// (verified via `--dry-run`, which never mutates git state).
void main() {
  group('tag_release (T-2)', () {
    test('parseVersion reads a real pubspec version line', () {
      const pubspec = '''
name: labs
version: 1.1.0+2
environment:
  sdk: ^3.8.0
''';
      expect(parseVersion(pubspec), '1.1.0+2');
    });

    test('parseVersion returns null when version is missing/malformed', () {
      expect(parseVersion('name: labs\n'), isNull);
      expect(parseVersion('name: labs\nversion: dev\n'), isNull);
      expect(parseVersion('name: labs\nversion: 1.1\n'), isNull);
    });

    test('tagNameFor prefixes v', () {
      expect(tagNameFor('1.1.0+2'), 'v1.1.0+2');
    });

    test(
      '--dry-run reads the real version and prints the would-be tag',
      () async {
        final version = parseVersion(File('pubspec.yaml').readAsStringSync());
        expect(version, isNotNull);

        // T-2 runs the documented `dart run tool/tag_release.dart --dry-run`
        // (never mutates git state) and asserts the real tool output. On
        // Windows `dart` is a .bat shim, so PATH resolution must go through
        // cmd; on POSIX spawn it directly. First-run kernel compilation can
        // exceed the default per-test timeout on cold caches, hence the
        // explicit budget.
        final isWindows = Platform.isWindows;
        final result = isWindows
            ? await Process.run('cmd', <String>[
                '/c',
                'dart run tool/tag_release.dart --dry-run',
              ], workingDirectory: Directory.current.path)
            : await Process.run('dart', <String>[
                'run',
                'tool/tag_release.dart',
                '--dry-run',
              ], workingDirectory: Directory.current.path);
        expect(
          result.exitCode,
          0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
        final stdout = result.stdout.toString();
        expect(
          stdout,
          contains('Would create annotated tag ${tagNameFor(version!)}'),
        );
        expect(stdout, contains('"Release $version"'));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  group('CHANGELOG (T-3)', () {
    test(
      'repo-root CHANGELOG.md exists, version-synced, remediation-seeded',
      () {
        final changelog = File('../CHANGELOG.md');
        expect(
          changelog.existsSync(),
          isTrue,
          reason: 'repo-root CHANGELOG.md must exist (RELEASE-1 T-3)',
        );
        final content = changelog.readAsStringSync();

        // Seeded with the production-fix remediation summary.
        expect(content, contains('Production-fix remediation'));
        expect(content, contains('tool/tag_release.dart'));

        // Carries a versioned + dated release heading.
        final heading = RegExp(
          r'^## \[(\d+\.\d+\.\d+\+\d+)\] — \d{4}-\d{2}-\d{2}$',
          multiLine: true,
        );
        expect(
          heading.hasMatch(content),
          isTrue,
          reason: 'CHANGELOG must carry a `## [version] — date` heading',
        );

        // Latest release heading matches the canonical version source.
        final version = parseVersion(File('pubspec.yaml').readAsStringSync());
        expect(version, isNotNull);
        expect(
          content,
          contains('[$version]'),
          reason: 'CHANGELOG latest heading must match pubspec version',
        );
      },
    );
  });
}
