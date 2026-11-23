import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

/// CORE-COV NAVIGATION module test: the single source of truth for deep-link
/// route patterns. Config mode registers ONLY these paths — a stale link to a
/// static-fallback-only route must be dropped (fail-closed) instead of landing
/// on the router error page.
void main() {
  group('DeepLinkRouteTable.isValid', () {
    test('accepts every registered route pattern', () {
      for (final route in DeepLinkRouteTable.validRoutePatterns) {
        expect(
          DeepLinkRouteTable.isValid(route),
          isTrue,
          reason: 'every declared pattern must validate itself: $route',
        );
      }
    });

    test(':param segments act as wildcards', () {
      expect(DeepLinkRouteTable.isValid('/orders/ORD-123'), isTrue);
      expect(DeepLinkRouteTable.isValid('/orders/ORD-123/details'), isFalse);
      expect(DeepLinkRouteTable.isValid('/tracking/ORD-9'), isTrue);
      expect(DeepLinkRouteTable.isValid('/dish/abc-42'), isTrue);
    });

    test('static-fallback-only routes are NOT deep-linkable (fail-closed)', () {
      expect(DeepLinkRouteTable.isValid('/owner'), isFalse);
      expect(DeepLinkRouteTable.isValid('/manager'), isFalse);
      expect(DeepLinkRouteTable.isValid('/kitchen'), isFalse);
      expect(DeepLinkRouteTable.isValid('/delivery'), isFalse);
      expect(DeepLinkRouteTable.isValid('/admin'), isFalse);
      expect(DeepLinkRouteTable.isValid('/logs'), isFalse);
      expect(DeepLinkRouteTable.isValid('/error-logs'), isFalse);
    });

    test('unknown and malformed paths are dropped', () {
      expect(DeepLinkRouteTable.isValid('/nonsense'), isFalse);
      expect(DeepLinkRouteTable.isValid('/menu/extra/parts'), isFalse);
      expect(DeepLinkRouteTable.isValid('menu'), isFalse);
      expect(DeepLinkRouteTable.isValid('/'), isTrue);
    });
  });
}
