import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/config_key_disposition_test.dart' hide main;

/// p33 T-1 — FLAG TRUTH pin (decision D-P33-1, fail-safe default INERT),
/// reconciled at the p33 × p37 sync point (2026-10-09).
///
/// TRUTH at this tip:
///   * `AppConfig.featureEnabled()` (app_config.dart:205) has ZERO production
///     callers — the config-file `features.flags` block stays decorative, and
///     D-P33-1 keeps the default INTENTIONAL-INERT for unlisted flags;
///   * the Firestore flag surface IS consumed since p37 T-2 (D-P37-1 branch
///     A): `feature_flag_gate.dart` resolves `featureFlagsProvider` and six
///     screens gate through FlagGate — authorized by the WIRED-BY
///     `features.flags` row in `test/tool/config_key_disposition_test.dart`;
///   * the one flag that gates server-side behavior is rules-side
///     `strongAppCheck` (firestore.rules:8-32).
///
/// L-P4 contract: this file must FIRE when a planted production caller
/// appears (red_t1_plant.txt) and PASS at HEAD (green_t1_plant.txt) — both
/// receipted. A new caller is only legal once the disposition register
/// (`config_key_disposition_test.dart`) carries a WIRED-BY row for
/// `features.flags` with its read-site, so wiring always ships together with
/// its decision row.
void main() {
  group('T-1: flag-surface truth (D-P33-1 default INERT)', () {
    test('the production scan covers a real source set (anti-vacuous)', () {
      final sources = _productionSources();
      expect(
        sources.length,
        greaterThan(100),
        reason:
            'the scan found only ${sources.length} dart files — roots are '
            'wrong, so the zero-consumer proof would be vacuous',
      );
    });

    test('no unauthorized production caller of the flag surface exists '
        '(featureEnabled / .isEnabled)', () {
      final callers = _flagCallers();
      final authorized =
          callers.isNotEmpty &&
          dispositionRegister.any(
            (row) =>
                row.path == 'features.flags' &&
                row.disposition == KeyDisposition.wiredBy &&
                row.readSite != null,
          );
      expect(
        callers.isEmpty || authorized,
        isTrue,
        reason:
            'D-P33-1 default is INTENTIONAL-INERT: a production flag consumer '
            'appeared without a decision. Either revert it, or add a WIRED-BY '
            'row for features.flags (with the read-site below) to '
            'test/tool/config_key_disposition_test.dart + an owner decision '
            'row. Offending sites:\n'
            '  ${callers.join('\n  ')}',
      );
    });
    test('featureFlagsProvider is referenced only by sanctioned files', () {
      const allowed = <String>{
        'core_app/lib/app/config/feature_flags_service.dart', // definition
        'core_app/lib/app/config/feature_flag_gate.dart', // sanctioned gate
        'core_app/lib/labs.dart', // package export
        'core_app/lib/features/admin/presentation/setup/'
            'tier_flag_manager_screen.dart', // admin editor
      };
      final offenders = <String>[];
      for (final entry in _productionSources().entries) {
        final rel = entry.key;
        if (allowed.contains(rel)) continue;
        if (!_codeLines(
          entry.value,
        ).any((line) => line.contains('featureFlagsProvider'))) {
          continue;
        }
        offenders.add(rel);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'R2 truth pinned: featureFlagsProvider has exactly one production '
            'consumer (the admin editor) plus the package export; a new '
            'reference means a flag now gates — update this allowlist AND the '
            'features.flags disposition row together. Offenders:\n'
            '  ${offenders.join('\n  ')}',
      );
    });

    test('the corrected docstrings still state the truth (D2 stays fixed)', () {
      final service = File(
        'lib/app/config/feature_flags_service.dart',
      ).readAsStringSync();
      expect(
        service.contains('Usage: ref.watch(featureFlagsProvider)'),
        isFalse,
        reason:
            'the pre-p33 misleading Usage example (it implied production '
            'consumption that does not exist) must stay deleted',
      );
      expect(
        service,
        contains('D-P33-1'),
        reason:
            'feature_flags_service.dart must keep the D-P33-1 marker pointing '
            'at the INERT truth',
      );
      final config = File('lib/app/config/app_config.dart').readAsStringSync();
      expect(
        config,
        contains('D-P33-1'),
        reason:
            'the featureEnabled docs in app_config.dart must keep the D-P33-1 '
            'marker (p31 §Q4 correction pinned by p33 T-1)',
      );
    });
  });
}

/// Repo-relative production roots — the same roots the disposition
/// register's zero-consumer proof scans
/// (config_key_disposition_test.dart `productionRoots`).
Map<String, File> _productionSources() {
  final found = <String, File>{};
  for (final root in productionRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      found['core_app/${entity.path}'.replaceAll(r'\', '/')] = entity;
    }
  }
  return found;
}

/// Non-comment code lines of [file] (a doc example is not a caller).
List<String> _codeLines(File file) {
  final out = <String>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('//') || line.startsWith('*')) continue;
    out.add(line);
  }
  return out;
}

/// Every production code line that calls the flag surface. Comment lines are
/// skipped, package TEST directories are skipped (delivery-registry
/// `registry.isEnabled` calls in packages/core/test are not flag consumers),
/// and the `featureEnabled` definition line is skipped (the definition is
/// not a caller).
List<String> _flagCallers() {
  final hits = <String>[];
  _productionSources().forEach((rel, file) {
    if (rel.contains('/test/')) return;
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('//') || line.startsWith('*')) continue;
      if (line.contains('bool featureEnabled(')) continue;
      if (line.contains('featureEnabled(') || line.contains('.isEnabled(')) {
        hits.add('$rel:${i + 1}: $line');
      }
    }
  });
  return hits;
}
