import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/client_config.dart';
import 'package:labs/app/config/screen_variants.dart';

/// PERF-5 T-4: the screen-variant registry's unit contract — the validated
/// vocabulary (fail-closed on anything outside it), the resolver's
/// byte-for-byte default, and the exact JSON paths the W6.5 gate reports.
void main() {
  group('ScreenVariants.validateScreens — absent/null keeps the default', () {
    test(
      'screens not a List → no violations (parse layer owns that shape)',
      () {
        expect(ScreenVariants.validateScreens(null), isEmpty);
        expect(ScreenVariants.validateScreens('not-a-list'), isEmpty);
        expect(ScreenVariants.validateScreens(42), isEmpty);
      },
    );

    test('entries without a variant key → no violations (byte-for-byte)', () {
      final screens = <dynamic>[
        {'id': 'HomeScreen', 'route': '/'},
        {'id': 'MenuScreen', 'route': '/menu'},
      ];
      expect(ScreenVariants.validateScreens(screens), isEmpty);
    });

    test('null variant value → no violations (treated as absent)', () {
      final screens = <dynamic>[
        {'id': 'HomeScreen', 'route': '/', 'variant': null},
      ];
      expect(ScreenVariants.validateScreens(screens), isEmpty);
    });

    test('non-Map entries are skipped (the parse layer drops them too)', () {
      expect(ScreenVariants.validateScreens(<dynamic>['junk', 42]), isEmpty);
    });
  });

  group(
    'ScreenVariants.validateScreens — present-but-invalid fails CLOSED',
    () {
      test(
        'unknown variant value on a catalog screen rejects with the path',
        () {
          final screens = <dynamic>[
            {'id': 'HomeScreen', 'route': '/', 'variant': 'carousel'},
          ];
          final violations = ScreenVariants.validateScreens(screens);
          expect(violations, hasLength(1));
          expect(violations.first.path, 'screens[0].variant');
          expect(violations.first.message, contains('carousel'));
          expect(violations.first.message, contains('HomeScreen'));
        },
      );

      test('non-string variant rejects with the exact path', () {
        final screens = <dynamic>[
          {'id': 'HomeScreen', 'route': '/', 'variant': 7},
        ];
        final violations = ScreenVariants.validateScreens(screens);
        expect(violations, hasLength(1));
        expect(violations.first.path, 'screens[0].variant');
        expect(violations.first.message, contains('non-empty string'));
      });

      test('empty-string variant rejects with the exact path', () {
        final screens = <dynamic>[
          {'id': 'HomeScreen', 'route': '/', 'variant': '   '},
        ];
        final violations = ScreenVariants.validateScreens(screens);
        expect(violations, hasLength(1));
        expect(violations.first.path, 'screens[0].variant');
      });

      test('variant on a screen id outside the catalog rejects', () {
        final screens = <dynamic>[
          {'id': 'MenuScreen', 'route': '/menu', 'variant': 'showcase'},
        ];
        final violations = ScreenVariants.validateScreens(screens);
        expect(violations, hasLength(1));
        expect(violations.first.path, 'screens[0].variant');
        expect(violations.first.message, contains('no variant vocabulary'));
        expect(violations.first.message, contains('MenuScreen'));
      });

      test('variant with a missing id rejects (cannot resolve vocabulary)', () {
        final screens = <dynamic>[
          {'route': '/', 'variant': 'showcase'},
        ];
        final violations = ScreenVariants.validateScreens(screens);
        expect(violations, hasLength(1));
        expect(violations.first.path, 'screens[0].variant');
        expect(violations.first.message, contains('missing'));
      });

      test('index in the path matches the entry position', () {
        final screens = <dynamic>[
          {'id': 'SplashScreen', 'route': '/splash'},
          {'id': 'HomeScreen', 'route': '/', 'variant': 'warp'},
        ];
        final violations = ScreenVariants.validateScreens(screens);
        expect(violations, hasLength(1));
        expect(violations.first.path, 'screens[1].variant');
      });

      test(
        'every violation accumulates (the gate reports them all at once)',
        () {
          final screens = <dynamic>[
            {'id': 'HomeScreen', 'route': '/', 'variant': 'carousel'},
            {'id': 'MenuScreen', 'route': '/menu', 'variant': 'showcase'},
          ];
          expect(ScreenVariants.validateScreens(screens), hasLength(2));
        },
      );
    },
  );

  group('ScreenVariants.validateScreens — valid vocab passes', () {
    test('both catalog values for the pilot screen pass', () {
      for (final variant
          in ScreenVariants.catalog[ScreenVariants.homeScreenId]!) {
        final screens = <dynamic>[
          {'id': 'HomeScreen', 'route': '/', 'variant': variant},
        ];
        expect(
          ScreenVariants.validateScreens(screens),
          isEmpty,
          reason: 'variant "$variant" is in the catalog and must pass',
        );
      }
    });

    test('a full config-shaped registry with mixed entries passes', () {
      final screens = <dynamic>[
        {'id': 'SplashScreen', 'route': '/splash'},
        {'id': 'HomeScreen', 'route': '/', 'variant': 'showcase'},
        {'id': 'MenuScreen', 'route': '/menu'},
      ];
      expect(ScreenVariants.validateScreens(screens), isEmpty);
    });
  });

  group('ScreenVariants.fromScreens + resolve — the byte-for-byte default', () {
    test(
      'no variant keys → empty table → resolve falls back to the default',
      () {
        final screens = <Map<String, dynamic>>[
          {'id': 'HomeScreen', 'route': '/'},
        ];
        final table = ScreenVariants.fromScreens(screens);
        expect(table, isEmpty);
        expect(
          ScreenVariants.resolve(table, ScreenVariants.homeScreenId),
          ScreenVariants.homeGridVariant,
          reason: 'the default MUST be today\'s layout (acceptance 2)',
        );
      },
    );

    test('explicit variant wins over the default', () {
      final screens = <Map<String, dynamic>>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 'showcase'},
      ];
      expect(
        ScreenVariants.resolve(
          ScreenVariants.fromScreens(screens),
          ScreenVariants.homeScreenId,
        ),
        ScreenVariants.homeShowcaseVariant,
      );
    });

    test('explicit default variant equals the implicit default', () {
      final screens = <Map<String, dynamic>>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 'grid'},
      ];
      expect(
        ScreenVariants.resolve(
          ScreenVariants.fromScreens(screens),
          ScreenVariants.homeScreenId,
        ),
        ScreenVariants.homeGridVariant,
      );
    });

    test('screen ids outside the catalog resolve to "" (never a variant)', () {
      expect(
        ScreenVariants.resolve(const {}, 'MenuScreen'),
        isEmpty,
        reason: 'a non-variant screen must never resolve to a variant name',
      );
    });

    test('non-string id/variant entries are dropped from the table', () {
      final screens = <Map<String, dynamic>>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 7},
        {'id': 9, 'route': '/', 'variant': 'showcase'},
      ];
      expect(ScreenVariants.fromScreens(screens), isEmpty);
    });
  });

  group('ScreenVariants — the ConfigException path (what the gate throws)', () {
    test('violations convert to a ConfigException naming the first path', () {
      final screens = <dynamic>[
        {'id': 'HomeScreen', 'route': '/', 'variant': 'carousel'},
      ];
      final violations = ScreenVariants.validateScreens(screens);
      final exception = ConfigException(
        List<ConfigViolation>.unmodifiable(violations),
      );
      expect(exception.jsonPath, 'screens[0].variant');
      expect(exception.toString(), contains('"screens[0].variant"'));
    });
  });

  test('the pilot vocabulary is exactly {grid, showcase} for HomeScreen', () {
    expect(ScreenVariants.catalog.keys, {'HomeScreen'});
    expect(ScreenVariants.catalog[ScreenVariants.homeScreenId], {
      'grid',
      'showcase',
    });
    expect(ScreenVariants.defaults[ScreenVariants.homeScreenId], 'grid');
  });
}
