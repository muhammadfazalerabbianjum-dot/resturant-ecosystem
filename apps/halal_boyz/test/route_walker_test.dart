import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/labs.dart'
    show AppConfig, RouteNames, appRouterProvider, screenIdToRouteName;

import 'helpers/router_test_harness.dart';

const kClientAppName = 'Halal Boyz';

const kClientEntryPoint = '/';

/// ARCH-1 T-3: the route-walker gate (the ROUTER-3 pattern, ported into the
/// shell). The shell's REAL router — built through the production
/// `appRouterProvider` from the shell's OWN bundled `assets/client_config.json`
/// — must register EVERY whitelisted `screens[].id` under its `RouteNames`
/// name with the exact config path, plus the ONE sanctioned internal DLQ ops
/// route (QUEUE-1, W5.1(d)).
///
/// SPEC-DRIFT NOTE (recorded in the ARCH-1 addendum): the spec says "all 42
/// routes registered". The live tree registers 28 NAMED routes in config
/// mode (26 whitelisted screens + DLQ); 42 was a stale count. The INTENDED
/// contract — the exact whitelisted route table, no more, no less — is
/// asserted here against the code as it actually is (exact map equality is
/// strictly stronger than a count).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-1 T-3: the shell config-mode route table', () {
    setUp(() async {
      await loadRealConfigMode();
    });

    test('registers exactly the whitelisted screens plus the DLQ ops route '
        '(never the error fallback)', () {
      expect(AppConfig.loadFailed, isFalse);
      expect(AppConfig.screens, isNotEmpty);

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
              'screen id "$id" has no RouteNames mapping — a config '
              'route without one crashes every goNamed call site (00-P0-1)',
        );
        expected[name!] = route;
      }
      // QUEUE-1 (W5.1(d)): the DLQ ops route is the ONE sanctioned
      // internal route registered in config mode.
      expected[RouteNames.deadLetterQueue] = '/dead-letters';

      expect(
        registered,
        expected,
        reason:
            'config mode must register exactly the whitelisted screens '
            'plus the DLQ internal ops route — nothing may leak in or out',
      );
      expect(registered.length, 27);
    });

    test('the shell entry point comes from the shell config (not the labs '
        'default "/splash")', () {
      // The client's navigation.entryPoint is interpolated from the client's
      // own config (kClientEntryPoint); the labs in-code default is
      // '/splash' — proving the SHELL's asset hydrated AppConfig, not the
      // template defaults.
      expect(AppConfig.navigationEntryPoint, kClientEntryPoint);
      expect(AppConfig.appName, kClientAppName);
    });
  });
}
