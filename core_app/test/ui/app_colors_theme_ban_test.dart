import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// COLOR-1 (08-P0-WL-3 / 08-P1-WL-2, master W10.1) — the enforceable repo
/// ban on direct `AppColors.*` usage outside `packages/core_ui/lib`.
///
/// `custom_lint` is NOT a dependency of this repo (verified against
/// core_app/packages pubspecs), so per W10.1 the mechanism is THIS repo test:
/// it runs in the CI `unit-tests` tier (full `flutter test` tree, required by
/// `ci-gate`) and fails the build the moment any `AppColors.` usage appears
/// in `core_app/lib` or `apps/*/lib`. The canonical palette lives in
/// `packages/core_ui` and reaches every surface through `BrandColors`
/// (`AppTheme.buildTheme`/`buildDarkTheme` extension) — see
/// `packages/core_ui/test/brand_colors_test.dart` for the distinct-palette
/// proof.
void main() {
  final pattern = RegExp(r'\bAppColors\s*\.');

  Directory repoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final coreApp = Directory('${dir.path}/core_app');
      final packages = Directory('${dir.path}/packages');
      final batches = File('${dir.path}/PRODUCTION_FIX_BATCHES.md');
      if (coreApp.existsSync() &&
          packages.existsSync() &&
          batches.existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    fail('repo root not found upward from ${Directory.current.path}');
  }

  List<File> dartFilesUnder(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('ban regex is live (positive control — never vacuously green)', () {
    expect(pattern.hasMatch('color: AppColors.primary'), isTrue);
    expect(pattern.hasMatch('AppColors.background'), isTrue);
    // Underscored filenames/identifiers are NOT usages.
    expect(pattern.hasMatch("import 'app_colors.dart'"), isFalse);
    expect(pattern.hasMatch('final brandColors = BrandColors.of(c)'), isFalse);
  });

  test('core_ui remains the sole legitimate AppColors owner (scope proof)', () {
    final coreUiLib = Directory('${repoRoot().path}/packages/core_ui/lib');
    expect(coreUiLib.existsSync(), isTrue);
    final uses = dartFilesUnder(
      coreUiLib,
    ).expand((f) => pattern.allMatches(f.readAsStringSync())).length;
    expect(
      uses,
      greaterThan(0),
      reason:
          'the canonical palette itself must still live in core_ui — '
          'if this ever hits 0 the scan below is scanning the wrong trees',
    );
  });

  test('no AppColors.* usage in core_app/lib + apps/*/lib (T-1/T-3)', () {
    final root = repoRoot();
    final scopes = <Directory>[
      Directory('${root.path}/core_app/lib'),
      ...Directory('${root.path}/apps')
          .listSync()
          .whereType<Directory>()
          .map((shell) => Directory('${shell.path}/lib'))
          .where((dir) => dir.existsSync()),
    ];
    expect(scopes.first.existsSync(), isTrue);

    final offenders = <String>[];
    for (final scope in scopes) {
      for (final file in dartFilesUnder(scope)) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add(
              '${file.path.substring(root.path.length + 1)}:${i + 1}: '
              '${lines[i].trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'COLOR-1 ban: direct AppColors.* usage bypasses the per-client '
          'theme. Resolve colors via BrandColors.of(context) '
          '(config-driven ThemeExtension) or Theme.of(context) instead. '
          'Offending sites:\n${offenders.join('\n')}',
    );
  });
}
