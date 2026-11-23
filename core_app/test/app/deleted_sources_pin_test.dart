// P9 W1 (T-5) — the absence pin: the dead sources deleted by this wave must
// never return. File paths are asserted non-existent; public symbols are
// asserted ABSENT as DECLARATIONS (declaration-shaped regexes, so a historical
// comment mentioning a deleted name cannot fake a hit — and the pin cannot be
// satisfied by a mention instead of a declaration).
//
// Mechanism mirrors test/ui/app_colors_theme_ban_test.dart (repo-root
// discovery + recursive scan + positive control), because `custom_lint` is
// not a repo dependency. Scans core_app/lib + packages/*/lib + apps/*/lib +
// the generator (core_app/tool/whitelabel.dart): a regenerated shell or a
// re-added declaration fails the build in CI's unit-tests tier.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final deletedFilePaths = <String>[
    'core_app/lib/features/admin/presentation/admin_provider.dart',
    'core_app/lib/features/admin/presentation/admin_dashboard.dart',
    'core_app/lib/app/config/env.dart',
    'core_app/lib/app/config/theme_config_provider.dart',
    'core_app/lib/features/cart/domain/cart_calculator.dart',
    'core_app/lib/features/checkout/domain/promo_calculator.dart',
    'core_app/lib/features/loyalty/domain/referral_engine.dart',
    'core_app/lib/features/admin/domain/analytics_helpers.dart',
    'core_app/lib/features/menu/presentation/widgets/allergen_disclaimer_banner.dart',
    // their property tests died with them:
    'core_app/test/features/cart/cart_calculator_property_test.dart',
    'core_app/test/features/checkout/promo_calculator_property_test.dart',
    'core_app/test/features/promo_code/promo_code_property_test.dart',
    'core_app/test/property/cart_calculator_property_test.dart',
    'core_app/test/property/promo_calculator_property_test.dart',
    'core_app/test/property/promo_discount_property_test.dart',
    'core_app/test/wiring/analytics_wiring_test.dart',
  ];

  final deletedDeclarationPattern = RegExp(
    r'(final|class|factory)\s+'
    r'(AdminRepository|adminsStreamProvider|adminRepositoryProvider|'
    r'InvalidEmailException|AdminDashboard|selectedBranchProvider|'
    r'cartValidatorServiceProvider|orderNumberServiceProvider|'
    r'firestoreClientProvider|themeConfigProvider|appThemeProvider|'
    r'CartCalculator|PromoCalculator|ReferralEngine|'
    r'AllergenDisclaimerBanner)\b|'
    r'\ballergenDisclaimerEnabled\b|'
    r'factory\s+ReservationModel\.fromDoc\b|'
    r'(streamAdmins|addAdmin|removeAdmin)\s*\(|'
    r'\b(groupByDay|topItems)\s*\(',
  );

  /// T-5 / B-6: `admin_provider.dart` carried the app's ONLY **unscoped**
  /// `admins` access — a live stream of the whole whitelist collection
  /// (`collection('admins').snapshots()`) plus client-side add/remove writes.
  /// The surviving client access is a *scoped single-document* read of the
  /// owner/e-mail whitelist (`packages/core/lib/src/admin/admin_access_service.dart`,
  /// `collection('admins').doc(email).get()`), which the rules cover with
  /// `isOwner()` (firestore.rules:305-307).
  ///
  /// The pin below therefore asserts the *shape*, not the token: every
  /// `collection('admins')` site must resolve to a `.doc(...)` chain within the
  /// following window. An enumeration (`snapshots()` / `where(` / bare `get()`)
  /// has no `.doc(` and is flagged. This keeps a legitimate scoped read
  /// passing while making the deleted anomaly impossible to reintroduce
  /// silently. (Verified count at HEAD: exactly one site — the scoped read.)
  final unscopedAdminsAccessPattern = RegExp(
    r'''collection\(\s*['"]admins['"]\s*\)''',
  );

  Directory repoRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      if (Directory('${dir.path}/core_app').existsSync() &&
          Directory('${dir.path}/packages').existsSync() &&
          File('${dir.path}/PRODUCTION_FIX_BATCHES.md').existsSync()) {
        return dir;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    fail('repo root not found upward from ${Directory.current.path}');
  }

  test(
    'positive control — the scan trees are live (never vacuously green)',
    () {
      final root = repoRoot();
      final probe = File(
        '${root.path}/core_app/lib/features/reservations/data/'
        'reservations_repository.dart',
      );
      expect(probe.existsSync(), isTrue);
      expect(
        probe.readAsStringSync().contains('class ReservationsRepository'),
        isTrue,
        reason:
            'if this ever fails, the scan below is scanning the wrong trees',
      );
    },
  );

  test('deleted files stay deleted (T-5)', () {
    final root = repoRoot();
    final returned = deletedFilePaths
        .where((p) => File('${root.path}/$p').existsSync())
        .toList();
    expect(
      returned,
      isEmpty,
      reason:
          'PERF-8 W5 dead-10 + T-5 files must never be restored:\n'
          '${returned.join('\n')}',
    );
  });

  test('deleted public symbols never re-declare in source (T-5)', () {
    final root = repoRoot();
    final scopes = <File>[
      ...Directory('${root.path}/core_app/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      ...Directory('${root.path}/packages/core/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      ...Directory('${root.path}/packages/core_ui/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      File('${root.path}/core_app/tool/whitelabel.dart'),
      ...Directory('${root.path}/apps')
          .listSync()
          .whereType<Directory>()
          .map((shell) => Directory('${shell.path}/lib'))
          .where((dir) => dir.existsSync())
          .expand(
            (dir) => dir
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart')),
          ),
    ];

    final offenders = <String>[];
    for (final file in scopes) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (deletedDeclarationPattern.hasMatch(lines[i])) {
          offenders.add(
            '${file.path.substring(root.path.length + 1)}:${i + 1}: '
            '${lines[i].trim()}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'T-5/W4-4 absence pin: a deleted dead-code symbol was '
          're-declared — resurrecting dead code without a new wave is '
          'prohibited. Offending sites:\n${offenders.join('\n')}',
    );
  });

  test('no UNscoped `admins` collection access returns (T-5 / B-6)', () {
    final root = repoRoot();
    final scopes = <File>[
      ...Directory('${root.path}/core_app/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      ...Directory('${root.path}/packages/core/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      ...Directory('${root.path}/packages/core_ui/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ];

    var sitesSeen = 0;
    final offenders = <String>[];
    for (final file in scopes) {
      final source = file.readAsStringSync();
      for (final match in unscopedAdminsAccessPattern.allMatches(source)) {
        sitesSeen++;
        // The chain must reach `.doc(` (a single-document access) within a
        // short window; anything else is an enumeration of the whitelist.
        final tail = source.substring(
          match.end,
          (match.end + 160).clamp(0, source.length),
        );
        if (!tail.contains('.doc(')) {
          final line = source.substring(0, match.start).split('\n').length;
          offenders.add('${file.path.substring(root.path.length + 1)}:$line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'B-6: the unscoped `admins` access (whole-collection stream / '
          'query) was deleted with admin_provider.dart — a scoped '
          '`.doc(...)` read of the whitelist is the only allowed shape.\n'
          'Offending sites:\n${offenders.join('\n')}',
    );
    expect(
      sitesSeen,
      greaterThan(0),
      reason:
          'positive control: the scoped whitelist read in '
          'admin_access_service.dart must still be found, otherwise this '
          'scan is vacuous',
    );
  });

  test('the unscoped-admins detector actually fires (never vacuous)', () {
    // Mirrors the deleted admin_provider.dart shape (an enumeration) followed
    // by the surviving scoped shape, with enough filler that the scoped
    // `.doc(` falls outside the scan's 160-char window from the enumeration.
    const filler =
        '// filler keeps the next chain outside the scan window ............';
    const deletedShape =
        "final s = db.collection('admins').snapshots();\n"
        '$filler$filler$filler\n'
        "await db.collection(\"admins\").doc(email).set({'email': email});";

    String window(int end) =>
        deletedShape.substring(end, (end + 160).clamp(0, deletedShape.length));

    final matches = unscopedAdminsAccessPattern.allMatches(deletedShape);
    expect(matches.length, 2, reason: 'both quote styles are recognised');
    expect(
      window(matches.first.end).contains('.doc('),
      isFalse,
      reason:
          'the deleted admin_provider.dart shape (collection enumeration) '
          'must be detectable by this pin',
    );
    expect(
      window(matches.last.end).contains('.doc('),
      isTrue,
      reason: 'the scoped shape must NOT be flagged',
    );
  });
}
