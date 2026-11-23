import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// P37 T-4 (scope A — owner decision D-P37-2, 2026-10-08) — the INVERSE matrix.
///
/// WHY: the engine-key matrix (`client_config_engine_key_matrix_test.dart`)
/// proves the keys the engine READS are SET; the disposition register proves
/// the p25 dotted paths are accounted for. Neither proves every TOP-LEVEL key
/// of a shipped config is either read in production or allowlisted with a
/// WRITTEN reason — a dead promise could still hide at the config root. This
/// test is that proof, plus the generator-side fail-closed: `validate()`
/// rejects unknown top-level keys (typo insurance).
///
/// Scope decision (D-P37-2): inert schema keys STAY in the shipped configs
/// with register-written reasons — `validate()` requires the `navigation` /
/// `features` sections and the disposition register pins their presence; the
/// trim is a later owner wave, not p37.
class TopKeyRow {
  const TopKeyRow.read(this.key, this.readSite) : reason = null;
  const TopKeyRow.allowlisted(this.key, this.reason) : readSite = null;

  /// Top-level key as it appears in both shipped configs.
  final String key;

  /// READ rows: repo-relative `file:line` of the production reader.
  final String? readSite;

  /// ALLOWLIST rows: the written reason why carrying this key is correct.
  final String? reason;

  bool get isRead => readSite != null;
}

/// RED shipped this empty; GREEN fills it — every top-level key of BOTH
/// shipped configs must appear exactly once, as a READ row (cited production
/// reader) or an ALLOWLIST row (written reason >= 60 chars).
const List<TopKeyRow> inverseRegister = <TopKeyRow>[
  TopKeyRow.read('_meta', 'core_app/tool/whitelabel.dart:338'),
  TopKeyRow.read('app', 'core_app/lib/app/config/app_config.dart:303'),
  TopKeyRow.read('currency', 'core_app/lib/app/config/app_config.dart:375'),
  TopKeyRow.read('environment', 'core_app/lib/app/config/app_config.dart:318'),
  TopKeyRow.read('firebase', 'core_app/lib/app/config/app_config.dart:342'),
  TopKeyRow.allowlisted(
    'features',
    'Parsed into AppConfig._featureFlags but both getters have zero '
        'production callers (p25 register: features.source is INERT; the live '
        'flag surface is the Firestore settings/featureFlags doc wired by '
        'p37 T-2 FlagGate). validate() requires the section as the schema '
        'declaration of unknownFlagDefault — owner FEATURES wave to wire the '
        'config mirror or drop the key (D-P37-2 keeps it for now).',
  ),
  TopKeyRow.allowlisted(
    'navigation',
    'All three navigation sub-keys are intentional-inert per the p25/AUD2R-04 '
        'disposition register (config_key_disposition_test.dart): the router '
        'builds from RouteNames + the screens registry, never these lists, '
        'and validate() requires the section — owner ROUTER/spec wave to wire '
        'or trim (D-P37-2 keeps it for now).',
  ),
  TopKeyRow.read('screens', 'core_app/lib/app/config/app_config.dart:450'),
  TopKeyRow.read('theme', 'core_app/lib/app/config/app_config.dart:384'),
];

/// Repo-relative (tests run with cwd = `core_app/`).
const Map<String, String> shippedConfigPaths = <String, String>{
  'core_app': 'assets/client_config.json',
  'halal_boyz': '../apps/halal_boyz/assets/client_config.json',
};

Map<String, dynamic> _decode(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group(
    'P37 T-4 inverse matrix: every top-level key is read or allowlisted',
    () {
      test('positive control — the register is populated (never vacuous)', () {
        expect(
          inverseRegister.length,
          greaterThanOrEqualTo(9),
          reason:
              'both shipped configs carry 9 top-level keys; the register '
              'must account for all of them (RED proof: register is empty)',
        );
      });

      test('both shipped configs are fully accounted for', () {
        final registered = {for (final row in inverseRegister) row.key};
        for (final entry in shippedConfigPaths.entries) {
          final keys = _decode(entry.value).keys.toSet();
          final uncovered = keys.difference(registered);
          expect(
            uncovered,
            isEmpty,
            reason:
                '${entry.key}: top-level keys with no read site and no '
                'allowlist reason (RED proof): $uncovered',
          );
          final stale = registered.difference(keys);
          expect(
            stale,
            isEmpty,
            reason: 'register entries no shipped config carries: $stale',
          );
        }
      });

      test('READ rows cite a real production reader of that key', () {
        for (final row in inverseRegister.where((r) => r.isRead)) {
          final bits = row.readSite!.split(':');
          final file = File('../${bits[0]}');
          expect(file.existsSync(), isTrue, reason: 'missing ${row.readSite}');
          final lines = file.readAsLinesSync();
          final lineNo = int.parse(bits[1]);
          expect(lineNo, lessThanOrEqualTo(lines.length), reason: row.readSite);
          expect(
            lines[lineNo - 1],
            contains(row.key),
            reason: '${row.readSite} does not read "${row.key}"',
          );
        }
      });

      test('ALLOWLIST rows carry a written reason (>= 60 chars)', () {
        for (final row in inverseRegister.where((r) => !r.isRead)) {
          expect(
            row.reason!.trim().length,
            greaterThanOrEqualTo(60),
            reason: '${row.key}: allowlist reason must be written out',
          );
        }
      });

      test('validate() rejects an unknown top-level key (fail-closed)', () {
        final original = _decode(shippedConfigPaths['core_app']!);
        original['bogusSection'] = <String, dynamic>{'x': 1};
        final temp = File(
          '${Directory.systemTemp.path}/p37_t4_unknown_key_client_config.json',
        );
        temp.writeAsStringSync(jsonEncode(original));
        try {
          final errors = whitelabel.ClientConfig.load(temp.path).validate();
          expect(
            errors.any((e) => e.contains('bogusSection')),
            isTrue,
            reason:
                'unknown top-level keys must block generation, got: $errors',
          );
        } finally {
          if (temp.existsSync()) temp.deleteSync();
        }
      });

      test('neither shipped config trips the unknown-key gate', () {
        for (final entry in shippedConfigPaths.entries) {
          final errors = whitelabel.ClientConfig.load(entry.value).validate();
          expect(
            errors.where((e) => e.startsWith('Unknown top-level key')),
            isEmpty,
            reason: '${entry.key} must stay clean: $errors',
          );
        }
      });
    },
  );
}
