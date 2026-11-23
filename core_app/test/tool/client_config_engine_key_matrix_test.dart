import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/whitelabel.dart' as whitelabel;

/// UI-14 (p25) T-2 — the ENGINE-KEY MATRIX.
///
/// F-8's root cause was that `validate()` only asked "is this config VALID?",
/// never "does it set the keys the theming engine actually reads?" — so a
/// client could be perfectly valid and still render Material-default inputs,
/// chips and backdrop (the B9 defects). This test is the systemic fix: ONE
/// list of engine-read keys, each row citing the file:line that reads it,
/// crossed with each shipped config. An unset key must therefore be either
/// (a) an allowlist entry carrying a WRITTEN reason, or (b) a failing row.
///
/// The read sites are `packages/core_ui/lib/src/theme/app_theme.dart`
/// (`_themeFromConfig`, `_brandColorsFor`, `_fontFamilyFrom`,
/// `_fontOptionFrom`) — the tool must not import app lib code (WL-2), so the
/// mirror is pinned HERE instead of imported.
class EngineKey {
  const EngineKey(this.path, this.readSite);

  /// Dotted JSON path, rooted at the config root (as `validate()` names it).
  final String path;

  /// Repo-relative `file:line` where the engine reads this key.
  final String readSite;

  String get leaf => path.split('.').last;
}

const List<EngineKey> engineKeys = <EngineKey>[
  EngineKey(
    'theme.colors.primary',
    'packages/core_ui/lib/src/theme/app_theme.dart:346',
  ),
  EngineKey(
    'theme.colors.secondary',
    'packages/core_ui/lib/src/theme/app_theme.dart:444',
  ),
  EngineKey(
    'theme.colors.accent',
    'packages/core_ui/lib/src/theme/app_theme.dart:368',
  ),
  EngineKey(
    'theme.colors.success',
    'packages/core_ui/lib/src/theme/app_theme.dart:369',
  ),
  EngineKey(
    'theme.colors.warning',
    'packages/core_ui/lib/src/theme/app_theme.dart:370',
  ),
  EngineKey(
    'theme.colors.error',
    'packages/core_ui/lib/src/theme/app_theme.dart:447',
  ),
  EngineKey(
    'theme.colors.background',
    'packages/core_ui/lib/src/theme/app_theme.dart:425',
  ),
  EngineKey(
    'theme.colors.surface',
    'packages/core_ui/lib/src/theme/app_theme.dart:430',
  ),
  EngineKey(
    'theme.colors.textPrimary',
    'packages/core_ui/lib/src/theme/app_theme.dart:375',
  ),
  EngineKey(
    'theme.colors.textSecondary',
    'packages/core_ui/lib/src/theme/app_theme.dart:379',
  ),
  EngineKey(
    'theme.colors.textPrimary12',
    'packages/core_ui/lib/src/theme/app_theme.dart:383',
  ),
  EngineKey(
    'theme.darkTheme.background',
    'packages/core_ui/lib/src/theme/app_theme.dart:423',
  ),
  EngineKey(
    'theme.darkTheme.surface',
    'packages/core_ui/lib/src/theme/app_theme.dart:429',
  ),
  EngineKey(
    'theme.typography.fontFamily',
    'packages/core_ui/lib/src/theme/app_theme.dart:152',
  ),
  EngineKey(
    'theme.typography.headingFont',
    'packages/core_ui/lib/src/theme/app_theme.dart:452',
  ),
  EngineKey(
    'theme.typography.bodyFont',
    'packages/core_ui/lib/src/theme/app_theme.dart:453',
  ),
  EngineKey(
    'theme.shape.cardRadius',
    'packages/core_ui/lib/src/theme/app_theme.dart:457',
  ),
  EngineKey(
    'theme.shape.ctaRadius',
    'packages/core_ui/lib/src/theme/app_theme.dart:458',
  ),
  EngineKey(
    'theme.shape.smallRadius',
    'packages/core_ui/lib/src/theme/app_theme.dart:459',
  ),
  EngineKey(
    'theme.components.navigationBar.background',
    'packages/core_ui/lib/src/theme/app_theme.dart:463',
  ),
  EngineKey(
    'theme.components.navigationBar.activeColor',
    'packages/core_ui/lib/src/theme/app_theme.dart:464',
  ),
  EngineKey(
    'theme.components.input.fillColor',
    'packages/core_ui/lib/src/theme/app_theme.dart:467',
  ),
  EngineKey(
    'theme.components.input.borderColor',
    'packages/core_ui/lib/src/theme/app_theme.dart:468',
  ),
  EngineKey(
    'theme.components.input.radius',
    'packages/core_ui/lib/src/theme/app_theme.dart:469',
  ),
  EngineKey(
    'theme.components.chip.radius',
    'packages/core_ui/lib/src/theme/app_theme.dart:471',
  ),
  EngineKey(
    'theme.background.color',
    'packages/core_ui/lib/src/theme/app_theme.dart:474',
  ),
  EngineKey(
    'theme.background.overlayAsset',
    'packages/core_ui/lib/src/theme/app_theme.dart:476',
  ),
  EngineKey(
    'theme.animationStyle',
    'packages/core_ui/lib/src/theme/app_theme.dart:478',
  ),
  // Q3 (semantic state palette): the sold-out token is read by
  // `AppTheme._brandColorsFor` — shipped configs must set it (no allowlist).
  EngineKey(
    'theme.colors.soldOut',
    'packages/core_ui/lib/src/theme/app_theme.dart:405',
  ),
  // Q1 (signature identity): the motif style is engine-read by
  // `_themeFromConfig` — the shell opts IN; the core template stays absent
  // on purpose (its allowlist entry carries the b10 byte-contract reason).
  EngineKey(
    'theme.signature.style',
    'packages/core_ui/lib/src/theme/app_theme.dart:506',
  ),
];

/// The ALLOWLIST — the artefact that makes F-8 unrepeatable.
///
/// Keyed `<shipped config> -> <engine key path>`, every entry carrying a
/// WRITTEN reason (why unset is acceptable here, plus who owns the call).
/// An entry for a key that IS set is stale and fails the test, so this list
/// can never decay into a rubber stamp.
const Map<String, Map<String, String>>
allowlist = <String, Map<String, String>>{
  'core_app': <String, String>{
    'theme.shape.ctaRadius':
        'null => no filled/outlined/icon/text button theme is attached, so '
        'Material 3 keeps its default button shape (app_theme.dart:531-574). '
        'This is the BLANK generation baseline an operator customises; owner '
        'TOKENS/W1 if a template default is ever wanted.',
    'theme.shape.smallRadius':
        'null => TextButton keeps the Material 3 default shape '
        '(app_theme.dart:564-574). Blank template baseline; owner TOKENS/W1.',
    'theme.components.navigationBar.background':
        'null => NavigationBarThemeData is not attached at all '
        '(app_theme.dart:575-576), so the Material 3 default bar renders. '
        'Blank template baseline; owner the operator who runs the generator.',
    'theme.components.navigationBar.activeColor':
        'null => no selected-icon color override is applied '
        '(app_theme.dart:579-585); Material 3 default selection color. '
        'Blank template baseline; owner the operator.',
    'theme.components.input.fillColor':
        'null => inputDecorationTheme is not attached (app_theme.dart:587-590). '
        'Deliberate for the BLANK template (the shipped halal_boyz config '
        'sets fillColor/borderColor/radius), because an unset field fill is '
        'exactly the B9 defect class this row exists to keep visible; owner '
        'the operator.',
    'theme.components.input.borderColor':
        'null => no enabled/focused border color override '
        '(app_theme.dart:594-609); Material 3 default border. Blank '
        'template baseline; owner the operator.',
    'theme.components.input.radius':
        'null => the field border radius falls back to the Material default '
        '4dp (app_theme.dart:597,605). Blank template baseline; owner the '
        'operator.',
    'theme.components.chip.radius':
        'null => chipTheme is not attached (app_theme.dart:611-617); Material 3 '
        'default chip shape. Blank template baseline; owner the operator.',
    'theme.background.color':
        'null => scaffoldBackgroundColor falls back through '
        'theme.colors.background to AppColors.background '
        '(app_theme.dart:424-427,512), and the template SETS '
        'colors.background (0xFFFFFFFF), so a deliberate colour still '
        'renders; owner TOKENS/W1.',
    'theme.background.overlayAsset':
        'null => AppBackdropTokens(overlayAsset: null): no backdrop art is '
        'loaded (app_theme.dart:475-477,502). Decorative only and neither '
        'shipped client commissions backdrop art; owner TOKENS/W1.',
    'theme.signature.style':
        'absent => no AppSignatureTokens extension is attached and every '
        'consumer renders its stock tree (app_theme.dart:500-509,534-535) — '
        'the core template ships the STOCK UI by design: the signature motif '
        'is a per-client REBRAND opt-in (halal_boyz sets "rule"), and keeping '
        'core absent is what holds the b10 byte-identical golden contract. '
        'Owner: the operator who runs the generator.',
  },
  'halal_boyz': <String, String>{
    'theme.background.overlayAsset':
        'the COV-2 rebrand ships no backdrop art: null => plain scaffold with '
        'no overlay (app_theme.dart:475-477). Decorative only; owner '
        'TOKENS/W1 if a map backdrop is ever commissioned.',
    'theme.animationStyle':
        'absent => AppMotionStyle.full, the engine documented shared baseline '
        '(app_theme.dart:668-674). Unset means the baseline renders, not '
        'that a client decision is missing; owner TOKENS/b10 to move a '
        'client to subtle/none.',
  },
};

/// The shipped configs (the same pair the AA guard reads — L-P5).
const Map<String, String> shippedConfigs = <String, String>{
  'core_app': 'assets/client_config.json',
  'halal_boyz': '../apps/halal_boyz/assets/client_config.json',
};

/// Value at a dotted path; any non-map hop yields null (= unset).
Object? valueAt(Map<String, dynamic> root, String path) {
  Object? cursor = root;
  for (final key in path.split('.')) {
    if (cursor is! Map) return null;
    cursor = cursor[key];
  }
  return cursor;
}

void main() {
  group('T-2: engine-read config keys x shipped configs (F-8 systemic fix)', () {
    test('every row cites an existing file:line that really mentions the key', () {
      for (final key in engineKeys) {
        final bits = key.readSite.split(':');
        expect(
          bits,
          hasLength(2),
          reason: 'read site must be file:line — ${key.readSite}',
        );
        final lineNo = int.tryParse(bits[1]);
        expect(lineNo, isNotNull, reason: 'bad line number in ${key.readSite}');
        if (lineNo == null) continue;

        final file = File('../${bits[0]}');
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'cited read site does not exist: ${key.readSite} (key ${key.path})',
        );
        final lines = file.readAsLinesSync();
        expect(
          lineNo,
          lessThanOrEqualTo(lines.length),
          reason:
              '${key.readSite} is past EOF (${lines.length} lines) for ${key.path}',
        );
        expect(
          lines.join('\n'),
          contains(key.leaf),
          reason:
              '${key.readSite} never mentions "${key.leaf}" — the citation for '
              '${key.path} is fabricated or stale',
        );
      }
    });

    test(
      'each shipped config SETS every engine key or ALLOWLISTS it with a reason',
      () {
        final offenders = <String>[];
        shippedConfigs.forEach((name, relPath) {
          final file = File(relPath);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'missing shipped config: $relPath',
          );
          final config =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          final allowed = allowlist[name] ?? <String, String>{};

          for (final key in engineKeys) {
            if (valueAt(config, key.path) != null) continue;
            final reason = allowed[key.path];
            if (reason == null) {
              offenders.add(
                '$name: ${key.path} is UNSET and not allowlisted '
                '(engine reads it at ${key.readSite})',
              );
            } else if (reason.trim().length < 20) {
              offenders.add(
                '$name: ${key.path} allowlist reason is not written out: "$reason"',
              );
            }
          }
        });

        expect(
          offenders,
          isEmpty,
          reason:
              'every unset engine-read key needs a written allowlist reason\n'
              '${offenders.map((o) => '  - $o').join('\n')}',
        );
      },
    );

    test('the allowlist carries no stale or dead entries', () {
      final stale = <String>[];
      allowlist.forEach((name, entries) {
        final file = File(shippedConfigs[name]!);
        final config =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        entries.forEach((path, reason) {
          expect(
            engineKeys.any((k) => k.path == path),
            isTrue,
            reason: '$name allowlists "$path", which is not an engine-read key',
          );
          expect(
            reason.trim().length,
            greaterThanOrEqualTo(20),
            reason: '$name/$path needs a WRITTEN reason, got: "$reason"',
          );
          if (valueAt(config, path) != null) {
            stale.add(
              '$name: $path is allowlisted but the config SETS it (stale entry)',
            );
          }
        });
      });
      expect(stale, isEmpty, reason: stale.join('\n'));
    });
  });

  // ── T-4 (p25): F3-05 residual ────────────────────────────────────────────
  // A capability DELETED from the service default must not survive as a flag in
  // a shipped client config: it would re-enable a feature the product removed
  // (UI-13/p21 D-2 deleted `referrals`). The parser tolerates an orphan
  // (core_app/test/core/feature_flags_test.dart:107-155 pins that tolerance with
  // an inline fixture), but tolerance is not permission — the config is cleaned
  // here instead. This is the only place both shipped configs are read together.
  group('T-4: a removed capability must not survive in a shipped config', () {
    test('neither shipped config ships the retired referrals flag', () {
      shippedConfigs.forEach((name, relPath) {
        final config =
            jsonDecode(File(relPath).readAsStringSync())
                as Map<String, dynamic>;
        final features = config['features'] as Map<String, dynamic>;
        final flags = features['flags'] as Map<String, dynamic>;
        expect(
          flags.keys,
          isNot(contains('referrals')),
          reason:
              '$name still ships "referrals": the capability was removed from '
              'the service default (UI-13/p21 D-2, register row F3-05), so a '
              'stale flag can only re-enable a feature the product deleted',
        );
        expect(
          flags.values.every((v) => v is bool),
          isTrue,
          reason: '$name features.flags must stay strictly boolean',
        );
        expect(
          flags,
          isNotEmpty,
          reason:
              '$name lost every flag — the block must still declare the '
              'client capability set',
        );
      });
    });

    test(
      'the generator accepts the generated config, template still fails closed',
      () {
        // Tolerance proof for the T-4 edit: the GENERATED config must pass the
        // fail-closed gate unchanged, and the TEMPLATE must keep failing it on its
        // placeholder credentials (W6.1/W6.3) — asserting "all clean" would be a
        // false claim about a template that ships REPLACE_ME on purpose.
        final generated = whitelabel.ClientConfig.load(
          shippedConfigs['halal_boyz']!,
        ).validate();
        expect(
          generated,
          isEmpty,
          reason:
              'the generated halal_boyz config must still validate: $generated',
        );

        final template = whitelabel.ClientConfig.load(
          shippedConfigs['core_app']!,
        ).validate();
        expect(
          template.any((e) => e.contains('placeholder values are rejected')),
          isTrue,
          reason:
              'the template must keep failing closed on placeholder '
              'credentials, got: $template',
        );
      },
    );
  });
}
