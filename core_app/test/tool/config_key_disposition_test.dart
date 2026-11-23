import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UI-14 (p25) T-3 â€” AUD2R-04: the parsed-but-unread config key surface.
///
/// L-P2: a config key that is parsed but read by nobody is **disposed**, never
/// wired â€” wiring is a product change owned by a spec wave. This file IS the
/// disposition register: one row per key, each citing where it is parsed and
/// where (if anywhere) it is read, classified [KeyDisposition.wiredBy] /
/// [KeyDisposition.intentionalInert] / [KeyDisposition.removeHandoff].
///
/// It is falsifiable on purpose:
///   * every citation must exist AND mention the key (a stale citation fails),
///   * every INERT row must be PROVEN consumer-free by scanning the production
///     source set â€” so the day a wave actually wires the key, this test FIRES
///     and forces the row to become WIRED-BY,
///   * a row that cannot be scanned must say so in writing.
enum KeyDisposition {
  /// A real production read site exists (cited in [KeyRow.readSite]).
  wiredBy,

  /// Parsed and/or shipped, read by nobody: kept deliberately, with a reason.
  intentionalInert,

  /// Dead surface that should be deleted by the named owner.
  removeHandoff,
}

/// One disposition row. [site] strings are repo-relative `file:line`.
class KeyRow {
  const KeyRow({
    required this.path,
    required this.keyToken,
    required this.parserSite,
    required this.readSite,
    required this.disposition,
    required this.note,
    this.scanToken,
  });

  /// Dotted JSON path, rooted at the config root.
  final String path;

  /// Identifier that proves a cited site really touches this key.
  final String keyToken;

  /// Where the parser reads the key, or null when nothing parses it.
  final String? parserSite;

  /// Where production code READS the key, or null when nothing does.
  final String? readSite;

  final KeyDisposition disposition;

  /// Why this disposition is correct (and who owns the follow-up).
  final String note;

  /// Identifier scanned across the production source set for INERT rows.
  /// Null only when the note justifies why scanning is meaningless.
  final String? scanToken;

  String get leaf => path.split('.').last;
}

/// The register. AUD2R-04 (navigation/store/typography-size/spacing) plus the
/// F-AUD2-09 stragglers p25 also owns; `currency.code` is included so the table
/// is proven able to express a WIRED-BY row too (spec Â§1).
const List<KeyRow> dispositionRegister = <KeyRow>[
  KeyRow(
    path: 'navigation.tabs',
    keyToken: 'navigationTabs',
    parserSite: 'core_app/lib/app/config/app_config.dart:433',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'navigationTabs',
    note:
        'The shell NavigationBar is built from the RouteNames/screens registry '
        '(core_app/lib/app/app_router.dart:208), never from this list, so the '
        'parsed tabs are inert. Kept as the schema declaration of the five '
        'primary tabs (AUD2R-04); owner ROUTER/spec wave to wire or trim. Test '
        'consumer only: core_app/test/app/config_mode_route_names_test.dart:83. '
        'p33 T-2 evidence (B-1: p32 unmerged, no golden gate yet): the shipped '
        'nav is HARDCODED at core_app/lib/features/home/presentation/'
        'home_screen.dart:136-186 and carries a Search tab (:148-154) that '
        'navigation.tabs cannot represent — wiring the key would DELETE Search '
        '(owner-visible behavior change), so INTENTIONAL-INERT holds; tab '
        'redesign deferred to P35 (D-P33-2).',
  ),
  KeyRow(
    path: 'navigation.hiddenRoutes',
    keyToken: 'navigationHiddenRoutes',
    parserSite: 'core_app/lib/app/config/app_config.dart:437',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'navigationHiddenRoutes',
    note:
        'Route visibility is owned by the router guest/role gates, which do not '
        'consult this list (core_app/lib/app/app_router.dart:208 reads only '
        'AppConfig.screens), so the parsed list is inert. Retained as the schema '
        'declaration of admin/role routes (AUD2R-04); owner ROUTER/spec wave.',
  ),
  KeyRow(
    path: 'navigation.routes',
    keyToken: 'navigationRoutes',
    parserSite: 'core_app/lib/app/config/app_config.dart:445',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'navigationRoutes',
    note:
        'No production reader outside its own parser: the 27-screen router uses '
        'RouteNames + screenIdToRouteName, not this map (AUD2R-04). Its only '
        'consumer today is the ROUTER-3 test '
        '(config_mode_route_names_test.dart:83), which asserts the vocabulary '
        'resolves; owner ROUTER/spec wave to wire or trim, updating that test. '
        'p33 T-2 evidence: confirmed at HEAD — app_router.dart:208 builds the '
        'route table from AppConfig.screens only; wiring this map would either '
        'change nothing or fork a second source of route truth, so '
        'INTENTIONAL-INERT holds.',
  ),
  KeyRow(
    path: 'app.storeAndroidUrl',
    keyToken: 'storeAndroidUrl',
    parserSite: 'core_app/lib/app/config/app_config.dart:309',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'storeAndroidUrl',
    note:
        'Parsed from JSON (plus the STORE_ANDROID_URL env fallback at '
        'app_config.dart:263) and exposed by getter at :159, but no production '
        'consumer: force_update_guard.dart never reads it (AUD2R-04). Owner '
        'RELEASE/spec wave to wire the update prompt or drop the key. p33 T-2 '
        'evidence: the force-update copy is Remote-Config-driven (p31 §Q3-4) '
        'and firebase_remote_config is declared but unused in lib/ '
        '(D-P33-4); wiring this URL into the guard would change '
        'owner-visible update behavior — INTENTIONAL-INERT holds.',
  ),
  KeyRow(
    path: 'app.storeIosUrl',
    keyToken: 'storeIosUrl',
    parserSite: 'core_app/lib/app/config/app_config.dart:311',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'storeIosUrl',
    note:
        'Same as storeAndroidUrl: parsed at app_config.dart:311, env fallback '
        ':264, getter :160, zero production readers (no store link is opened by '
        'the force-update flow). Owner RELEASE/spec wave (AUD2R-04). p33 T-2: '
        'same evidence as storeAndroidUrl (Remote-Config-driven copy, '
        'D-P33-4) - INTENTIONAL-INERT holds.',
  ),
  KeyRow(
    path: 'theme.typography.headlineSize',
    keyToken: 'headlineSize',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'headlineSize',
    note:
        'Neither parsed nor read: AppTheme builds its TextTheme from '
        'typography.fontFamily/headingFont/bodyFont (app_theme.dart:149-158), so '
        'a client size never reaches the engine. Kept because the schema '
        'documents it (client_config_schema_20260814/CLIENT_CONFIG_SCHEMA.md:85); '
        'owner TOKENS/W1 to trim the schema or wire sizes.',
  ),
  KeyRow(
    path: 'theme.typography.titleSize',
    keyToken: 'titleSize',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'titleSize',
    note:
        'Same class as headlineSize: shipped in both client configs, parsed by '
        'nothing, read by nothing (engine type sizes come from the Material '
        'TextTheme plus the resolved families). Owner TOKENS/W1.',
  ),
  KeyRow(
    path: 'theme.typography.bodySize',
    keyToken: 'bodySize',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'bodySize',
    note:
        'Same class as headlineSize: an inert size token, documented in the '
        'schema and absent from every parser and reader. Owner TOKENS/W1.',
  ),
  KeyRow(
    path: 'theme.typography.captionSize',
    keyToken: 'captionSize',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'captionSize',
    note:
        'Same class as headlineSize: inert in both shipped configs. Owner '
        'TOKENS/W1 to trim the schema or wire sizes into the TextTheme.',
  ),
  KeyRow(
    path: 'theme.spacing.smallPadding',
    keyToken: 'smallPadding',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'smallPadding',
    note:
        'Not parsed, not read: layout rhythm comes from the library Gap '
        'vocabulary (packages/core_ui/lib/src/ui/adaptive_row.dart), so no '
        'spacing token reaches a widget. Owner TOKENS/W1 (AUD2R-04).',
  ),
  KeyRow(
    path: 'theme.spacing.mediumPadding',
    keyToken: 'mediumPadding',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'mediumPadding',
    note:
        'Same class as smallPadding: shipped in both configs, parsed by nothing, '
        'read by nothing. Owner TOKENS/W1 (AUD2R-04).',
  ),
  KeyRow(
    path: 'theme.spacing.largePadding',
    keyToken: 'largePadding',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'largePadding',
    note:
        'Same class as smallPadding: an inert spacing token in both shipped '
        'configs. Owner TOKENS/W1 (AUD2R-04).',
  ),
  KeyRow(
    path: 'environment.stripePublishableKey',
    keyToken: 'stripePublishableKey',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: 'stripePublishableKey',
    note:
        'Deliberately INERT in the app: the publishable key must never be '
        'embedded in generated source (the generator guards the real key against '
        'being baked in at tool/whitelabel.dart:3526), and the live value '
        'arrives at BUILD time through the STRIPE_PUBLISHABLE_KEY dart-define '
        'read at core_app/lib/app_bootstrap.dart:723. The JSON entry is a '
        'deploy-time placeholder (RUNBOOK_DEPLOY.md Stripe step), so dropping the '
        'key would break the documented deploy path; owner RUNBOOK/DEPLOY.',
  ),
  KeyRow(
    path: 'environment.devAdminPin',
    keyToken: 'devAdminPin',
    parserSite: null,
    readSite: null,
    disposition: KeyDisposition.removeHandoff,
    scanToken: 'devAdminPin',
    note:
        'Dead surface: the parser, field and getter were deleted by an earlier '
        'batch (FIX_VERIFICATION.md:5161) and a source-scan guard now forbids '
        'them (core_app/test/app/config/app_config_no_pin_test.dart). The JSON key '
        'survives in both shipped configs, empty and harmless; owner the operator '
        '/ deploy tooling to drop it from client configs (REMOVE candidate).',
  ),
  KeyRow(
    path: 'features.source',
    keyToken: 'features',
    parserSite: 'core_app/lib/app/config/app_config.dart:422',
    readSite: null,
    disposition: KeyDisposition.intentionalInert,
    scanToken: null,
    note:
        'Inert: the features block is parsed at app_config.dart:410-413 for its '
        'flags and unknownFlagDefault, but the "source" document path is never '
        'read â€” '
        'the Firestore doc id is hardcoded at '
        'core_app/lib/app/config/feature_flags_service.dart:33. Not scan-probed '
        'because the literal "source" is far too generic to prove anything by '
        'grep; owner FEATURES/spec wave to wire or drop the key.',
  ),
  KeyRow(
    path: 'features.flags',
    keyToken: 'featureFlags',
    parserSite: 'core_app/lib/app/config/app_config.dart:419',
    readSite: 'core_app/lib/app/config/feature_flag_gate.dart:27',
    disposition: KeyDisposition.wiredBy,
    scanToken: null,
    note:
        'WIRED-BY (D-P37-1 branch A, six Firestore flags): since p37 T-2 the '
        'flag surface gates production controls through FlagGate '
        '(feature_flag_gate.dart:26-32, default-TRUE) - smartReorder '
        'delivery_tracker_screen.dart:228, waitlist waitlist_screen.dart:175, '
        'promoCode checkout_screen.dart:833, deliveryTracking '
        'delivery_tracker_screen.dart:149, loyaltyPoints profile_screen.dart:78, '
        'tourMode onboarding_screen.dart:54; owner decision DECISIONS_LOG '
        'D-P37-1. The config-file half stays inert: AppConfig.featureEnabled '
        '(app_config.dart:217) still has 0 production callers (p33 T-1 truth), '
        'and D-P33-1 keeps the default INTENTIONAL-INERT for any unlisted '
        'flag. Pin: test/config/flag_surface_truth_test.dart.',
  ),
  KeyRow(
    path: 'currency.code',
    keyToken: 'currencyCode',
    parserSite: 'core_app/tool/whitelabel.dart:400',
    readSite: 'apps/halal_boyz/lib/app/core_config_adapter.dart:42',
    disposition: KeyDisposition.wiredBy,
    scanToken: null,
    note:
        'WIRED-BY(generated shell offline money display): the generator requires '
        'the key (validate() at whitelabel.dart:354) and emits an adapter that '
        'reads config.currency.code (template at whitelabel.dart:2986-2989) so '
        'offline money rendering is config-driven, delegating to the single '
        'formatter moneyCents. p37 T-3 added the core_app readers: '
        'AppConfig.currencyCode (core_app/lib/app/config/app_config.dart:187) '
        'feeds resolveCurrencyCode '
        '(core_app/lib/app/config/currency_format.dart:38) for the customer '
        'money path (menu_screen). Listed so the table is proven able to express a '
        'wired row (spec Â§1).',
  ),
];

/// Production source roots scanned for the zero-consumer proof. A generated
/// shell counts as production code: a wired shell proves the key is NOT inert.
const List<String> productionRoots = <String>[
  'lib',
  '../apps/halal_boyz/lib',
  '../packages',
];

/// This register itself, keyed repo-relative, so the scan can skip it.
const String registerSelfPath =
    'core_app/test/tool/config_key_disposition_test.dart';

/// Resolves a `file:line` citation recorded repo-relative (tests run with the
/// working directory set to `core_app/`).
String _citedLine(String site) {
  final bits = site.split(':');
  final file = File('../${bits[0]}');
  expect(file.existsSync(), isTrue, reason: 'cited file is missing: $site');
  final lines = file.readAsLinesSync();
  final line = int.parse(bits[1]);
  expect(
    line,
    lessThanOrEqualTo(lines.length),
    reason: '$site is past EOF (${lines.length} lines)',
  );
  return lines[line - 1];
}

/// Every `.dart` file under the production roots, keyed repo-relative.
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

/// Value at a dotted path; any non-map hop yields null (= absent).
Object? _valueAt(Map<String, dynamic> config, String path) {
  Object? cursor = config;
  for (final key in path.split('.')) {
    if (cursor is! Map) return null;
    cursor = cursor[key];
  }
  return cursor;
}

Map<String, dynamic> _decode(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The AUD2R-04 keys this batch is accountable for. Kept as data so the
/// coverage test fires when a row is dropped.
const List<String> aud2r04Keys = <String>[
  'navigation.tabs',
  'navigation.hiddenRoutes',
  'navigation.routes',
  'app.storeAndroidUrl',
  'app.storeIosUrl',
  'theme.typography.headlineSize',
  'theme.typography.titleSize',
  'theme.typography.bodySize',
  'theme.typography.captionSize',
  'theme.spacing.smallPadding',
  'theme.spacing.mediumPadding',
  'theme.spacing.largePadding',
];

void main() {
  group('T-3: AUD2R-04 config-key disposition register', () {
    test('every row is well formed and its reason is written out', () {
      for (final row in dispositionRegister) {
        expect(row.path.split('.').length, greaterThan(1), reason: row.path);
        expect(
          row.note.trim().length,
          greaterThanOrEqualTo(60),
          reason:
              '${row.path}: the reason must be written out, got: '
              '"${row.note}"',
        );
        if (row.disposition == KeyDisposition.wiredBy) {
          expect(
            row.readSite,
            isNotNull,
            reason: '${row.path} is WIRED-BY, so it must cite its read site',
          );
        } else {
          expect(
            row.readSite,
            isNull,
            reason:
                '${row.path} is ${row.disposition.name} but cites a read '
                'site (${row.readSite}) â€” a wired key needs the WIRED-BY row',
          );
        }
        if (row.disposition == KeyDisposition.intentionalInert) {
          expect(
            row.scanToken != null || row.note.length >= 150,
            isTrue,
            reason:
                '${row.path}: an inert row must either be scan-probed or '
                'explain in writing why it cannot be',
          );
        }
      }
    });

    test('the register covers every AUD2R-04 key exactly once', () {
      final paths = dispositionRegister.map((r) => r.path).toList();
      expect(paths.toSet().length, paths.length, reason: 'duplicates: $paths');
      for (final required in aud2r04Keys) {
        expect(
          paths,
          contains(required),
          reason: 'AUD2R-04 key "$required" has no disposition row',
        );
      }
    });

    test('every citation exists and really mentions the key', () {
      for (final row in dispositionRegister) {
        for (final site in <String?>[row.parserSite, row.readSite]) {
          if (site == null) continue;
          final text = _citedLine(site);
          expect(
            text,
            contains(row.keyToken),
            reason:
                '$site does not mention "${row.keyToken}" for ${row.path} â€” '
                'the citation is stale: "$text"',
          );
        }
      }
    });

    test('every INERT row is PROVEN consumer-free in production sources', () {
      final sources = _productionSources();
      expect(
        sources.length,
        greaterThan(100),
        reason:
            'the production scan found only ${sources.length} dart files â€” '
            'the roots are wrong, so the proof would be vacuous',
      );

      final offenders = <String>[];
      for (final row in dispositionRegister) {
        if (row.disposition != KeyDisposition.intentionalInert) continue;
        final token = row.scanToken;
        if (token == null) continue;
        final parserRel = row.parserSite?.split(':').first;

        sources.forEach((rel, file) {
          if (rel == parserRel || rel == registerSelfPath) return;
          if (file.readAsStringSync().contains(token)) {
            offenders.add(
              '${row.path} is declared INERT, but "$token" is referenced by '
              'production source $rel â€” move the row to WIRED-BY(<spec>) or '
              'delete the reference',
            );
          }
        });
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'L-P2: an inert key must have no production consumer\n'
            '${offenders.map((o) => '  - $o').join('\n')}',
      );
    });

    test('every inert row names a key the shipped configs really carry', () {
      final configs = <Map<String, dynamic>>[
        _decode('assets/client_config.json'),
        _decode('../apps/halal_boyz/assets/client_config.json'),
      ];
      final missing = <String>[];
      for (final row in dispositionRegister) {
        if (row.disposition == KeyDisposition.wiredBy) continue;
        if (configs.any((c) => _valueAt(c, row.path) != null)) continue;
        missing.add(
          '${row.path} has a disposition row but appears in neither shipped '
          'config â€” the register is documenting a phantom key',
        );
      }
      expect(missing, isEmpty, reason: missing.join('\n'));
    });
  });
}
