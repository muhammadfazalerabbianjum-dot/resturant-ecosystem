import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/app_router.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/privacy_policy_screen.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/auth/presentation/terms_of_service_screen.dart';

import '../helpers/router_test_harness.dart';

/// ROUTER-3 T-1 (W2.7, 07-P1-5) — the ACTUAL config-driven router, built from
/// the REAL bundled config through the production `appRouterProvider`, is
/// asserted to resolve EVERY whitelisted `screens[].id` route — never the
/// router error fallback ("Route Error").
///
/// SPEC-DRIFT NOTE (recorded in the ROUTER-3 addendum): the audit text refers
/// to a `ConfigMode` enum and a `NotFoundScreen` widget; neither exists in the
/// live tree. The real router has exactly one "mode" switch — config routes
/// when `screens` is non-empty, static fallback otherwise — and the real
/// error surface is the inline `errorBuilder` Scaffold titled "Route Error".
/// The INTENDED contract (whitelisted routes resolve, never the error page)
/// is asserted against the code as it actually is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ROUTER-3 T-1: config-mode whitelist resolves', () {
    setUp(() async {
      await loadRealConfigMode();
    });

    test('the real bundled config enters config mode', () {
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.screens, isNotEmpty);
    });

    test('every whitelisted screens[].id is registered under its RouteNames '
        'name with the exact config path (never the error fallback)', () {
      final container = ProviderContainer(overrides: routerAuthOverrides());
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final registered = routerNamedRoutes(router);

      final expected = <String, String>{};
      for (final screen in AppConfig.screens) {
        final id = screen['id'] as String;
        final route = screen['route'] as String;
        final name = screenIdToRouteName[id];
        expect(
          name,
          isNotNull,
          reason:
              'ROUTER-1 guard: screen id "$id" must have a RouteNames '
              'mapping (screenIdToRouteName)',
        );
        expected[name!] = route;
      }

      expect(expected.length, AppConfig.screens.length);
      for (final entry in expected.entries) {
        expect(
          registered[entry.key],
          entry.value,
          reason:
              'whitelisted route "${entry.key}" must resolve to '
              '"${entry.value}" in config mode — a missing/renamed registration '
              'would land on the router error page',
        );
      }
    });
    test('config-mode route table is EXACTLY the screens whitelist PLUS the '
        'one QUEUE-1 internal DLQ route — no other config-forbidden route '
        'leaks in', () {
      final container = ProviderContainer(overrides: routerAuthOverrides());
      addTearDown(container.dispose);
      final registered = routerNamedRoutes(container.read(appRouterProvider));

      final expected = <String, String>{};
      for (final screen in AppConfig.screens) {
        final id = screen['id'] as String;
        expected[screenIdToRouteName[id]!] = screen['route'] as String;
      }
      // QUEUE-1 (W5.1(d)): the DLQ ops route is the ONE sanctioned internal
      // route registered in config mode (it is not a client-config screen).
      expected[RouteNames.deadLetterQueue] = '/dead-letters';

      expect(
        registered,
        expected,
        reason:
            'config mode must register exactly the whitelisted screens plus '
            'the DLQ internal ops route — the static-only orphans '
            '(admin/logs/dashboards) must not leak in',
      );
    });

    test(
      'T-3 guard: BOTH client_config.jsons screens[].id sets EXACTLY equal '
      'the screenIdToRouteName key set (ROUTER-1 guard, completeness side)',
      () {
        const configAssets = <String>[
          'assets/client_config.json',
          '../apps/halal_boyz/assets/client_config.json',
        ];
        final idSets = <Set<String>>[];
        for (final asset in configAssets) {
          final file = File(asset);
          expect(file.existsSync(), isTrue, reason: 'missing config: $asset');
          final json =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          final ids = (json['screens'] as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()
              .map((s) => s['id'] as String)
              .toSet();
          expect(ids, isNotEmpty, reason: '$asset must declare screens');
          expect(
            ids,
            screenIdToRouteName.keys.toSet(),
            reason:
                'every screens[].id in "$asset" must be an EXACT key of '
                'screenIdToRouteName and every map key must be a real '
                'screens[].id — a config naming an unmapped id ships a route '
                'that no named navigation can reach (00-P0-1)',
          );
          idSets.add(ids);
        }
        expect(
          idSets[0],
          idSets[1],
          reason: 'both configs must enumerate the SAME screen whitelist',
        );
      },
    );

    testWidgets('widget-level: whitelisted public routes render their screen, '
        'never the router error page', (tester) async {
      final router = await pumpRouterApp(
        tester,
        overrides: routerAuthOverrides(),
      );

      // The landing screen (entry point '/' = HomeScreen) must not be the
      // error page on the first frame.
      expect(find.text('Route Error'), findsNothing);
      expect(tester.takeException(), isNull);

      const probes = <(String, Type)>[
        (RouteNames.login, LoginScreen),
        (RouteNames.privacy, PrivacyPolicyScreen),
        (RouteNames.terms, TermsOfServiceScreen),
      ];
      for (final (name, screenType) in probes) {
        router.goNamed(name);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byType(screenType),
          findsOneWidget,
          reason: 'goNamed($name) must land on $screenType in config mode',
        );
        expect(
          find.text('Route Error'),
          findsNothing,
          reason: 'goNamed($name) must never render the router error page',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
