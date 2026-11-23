import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/navigation/deep_link_service.dart';

void main() {
  group('DeepLinkRouteTable — the ONE real route table (config-mode truth)', () {
    test(
      'declares exactly the 26 ACTIVE config-mode route paths (W2.2 prune)',
      () {
        for (final pattern in const [
          // Auth / onboarding
          '/splash',
          '/onboarding',
          '/login',
          '/signup',
          // Home / public
          '/',
          '/menu',
          '/dish/:id',
          '/cart',
          '/checkout',
          '/locations',
          '/waitlist',
          '/privacy',
          '/terms',
          '/admin-gateway',
          // Customer features
          '/orders',
          '/orders/:orderId',
          '/tracking/:orderId',
          '/reservations',
          '/loyalty',
          '/profile',
          '/delete-account',
          '/location/map',
          // Role gateway + config-driven admin setup flows
          '/role-router',
          '/admin/setup/tier-flags',
          '/admin/setup/restaurant',
          '/admin/setup/hours',
        ]) {
          expect(
            DeepLinkRouteTable.validRoutePatterns,
            contains(pattern),
            reason:
                'active config route pattern "$pattern" missing from the table',
          );
        }
        expect(
          DeepLinkRouteTable.validRoutePatterns.length,
          26,
          reason:
              'the table must be pruned to exactly the 26 active '
              'config-mode paths (ROUTER-1 / W2.2)',
        );
      },
    );

    test('mirrors the client config routes of BOTH apps bidirectionally', () {
      for (final configPath in const [
        'assets/client_config.json',
        '../apps/halal_boyz/assets/client_config.json',
      ]) {
        final file = File(configPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'config asset missing at $configPath '
              '(run flutter test from the package root)',
        );
        final decoded =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final screens = (decoded['screens'] as List)
            .whereType<Map<dynamic, dynamic>>()
            .toList();
        final routes = screens
            .map((s) => s['route'])
            .whereType<String>()
            .toSet();
        expect(
          routes,
          DeepLinkRouteTable.validRoutePatterns,
          reason:
              'DeepLinkRouteTable must mirror the registered config routes '
              'in $configPath exactly (both directions)',
        );
      }
    });

    test(
      'rejects static-fallback-only paths (config mode does not register them)',
      () {
        for (final staticOnly in const [
          '/admin',
          '/admin/menu',
          '/owner',
          '/manager',
          '/kitchen',
          '/delivery',
          '/logs',
          '/error-logs',
        ]) {
          expect(
            DeepLinkRouteTable.validRoutePatterns,
            isNot(contains(staticOnly)),
          );
          expect(
            DeepLinkRouteTable.isValid(staticOnly),
            isFalse,
            reason:
                'config-inactive route "$staticOnly" must be dropped '
                'fail-closed instead of landing on the router error page',
          );
        }
      },
    );

    test('rejects stale /admin/... routes that are NOT real app routes', () {
      for (final stale in const [
        '/admin/owner',
        '/admin/manager',
        '/admin/kitchen',
        '/admin/driver',
        '/menu/:id', // real menu detail route is /dish/:id
      ]) {
        expect(DeepLinkRouteTable.validRoutePatterns, isNot(contains(stale)));
        expect(
          DeepLinkRouteTable.isValid(stale),
          isFalse,
          reason: 'stale route "$stale" must be treated as invalid',
        );
      }
    });

    test('accepts real deep links incl. parameterized order/dish routes', () {
      expect(DeepLinkRouteTable.isValid('/orders/ORD-123'), isTrue);
      expect(DeepLinkRouteTable.isValid('/tracking/ORD-123'), isTrue);
      expect(DeepLinkRouteTable.isValid('/dish/pizza-001'), isTrue);
      expect(DeepLinkRouteTable.isValid('/role-router'), isTrue);
      expect(DeepLinkRouteTable.isValid('/admin/setup/tier-flags'), isTrue);
    });

    test('rejects garbage, extra segments and bare tokens', () {
      expect(DeepLinkRouteTable.isValid('/garbage/path'), isFalse);
      expect(DeepLinkRouteTable.isValid('/admin/owner'), isFalse);
      expect(DeepLinkRouteTable.isValid('/orders/ORD/x'), isFalse);
      expect(DeepLinkRouteTable.isValid('/profile/extra'), isFalse);
      expect(DeepLinkRouteTable.isValid('orders'), isFalse);
      // Root remains a valid internal route.
      expect(DeepLinkRouteTable.isValid('/'), isTrue);
    });
  });

  group('DeepLinkService', () {
    test('instantiates and exposes lifecycle', () {
      final service = DeepLinkService();
      expect(service, isA<DeepLinkService>());
      expect(service.dispose, isNotNull);
      expect(service.init, isNotNull);
      service.dispose();
    });

    test('deepLinkServiceProvider keeps service alive until disposed', () {
      expect(deepLinkServiceProvider, isNotNull);
    });
  });
}
