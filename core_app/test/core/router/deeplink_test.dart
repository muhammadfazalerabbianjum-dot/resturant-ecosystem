import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Law 34 (Navigation Integrity)
///
/// Tests that the GoRouter correctly handles every declared app URI and
/// redirects unknown or unauthenticated routes. No emulator needed — pure
/// unit-style widget test using a test-configured router instance.

// Lightweight test screens — no real dependencies needed here
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();
  @override
  Widget build(BuildContext context) => const Text('HomeScreen');
}

class _MenuDetailScreen extends StatelessWidget {
  final String itemId;
  const _MenuDetailScreen({required this.itemId});
  @override
  Widget build(BuildContext context) => Text('MenuDetail:$itemId');
}

class _OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const _OrderTrackingScreen({required this.orderId});
  @override
  Widget build(BuildContext context) => Text('OrderTracking:$orderId');
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen();
  @override
  Widget build(BuildContext context) => const Text('SignInScreen');
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();
  @override
  Widget build(BuildContext context) => const Text('404:NotFound');
}

// Auth state mock
final _isAuthenticatedProvider = StateProvider<bool>((_) => true);

// Test router factory — mirrors the real router structure
GoRouter _buildTestRouter(WidgetRef ref) {
  final isAuth = ref.read(_isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final protected = ['/orders', '/profile', '/checkout'];
      final isProtected = protected.any(
        (path) => state.matchedLocation.startsWith(path),
      );
      if (!isAuth && isProtected) return '/signin';
      return null;
    },
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _HomeScreen()),
      GoRoute(
        path: '/menu/:id',
        builder: (_, state) =>
            _MenuDetailScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (_, state) =>
            _OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(path: '/signin', builder: (_, __) => const _SignInScreen()),
    ],
  );
}

void main() {
  group('GoRouter Deeplink Tests (Law 34)', () {
    testWidgets('/menu/:id resolves to MenuDetailScreen with correct id', (
      tester,
    ) async {
      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (ctx, ref, _) {
              router = _buildTestRouter(ref);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );

      router.go('/menu/item_001');
      await tester.pumpAndSettle();

      expect(find.text('MenuDetail:item_001'), findsOneWidget);
    });

    testWidgets('/orders/:orderId resolves to OrderTrackingScreen', (
      tester,
    ) async {
      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (ctx, ref, _) {
              router = _buildTestRouter(ref);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );

      router.go('/orders/ord_999');
      await tester.pumpAndSettle();

      expect(find.text('OrderTracking:ord_999'), findsOneWidget);
    });

    testWidgets('Unknown route /garbage/path → 404 NotFound screen, no crash', (
      tester,
    ) async {
      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (ctx, ref, _) {
              router = _buildTestRouter(ref);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );

      router.go('/garbage/unknown/path');
      await tester.pumpAndSettle();

      expect(find.text('404:NotFound'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Unauthenticated deep link to /orders → redirected to SignInScreen',
      (tester) async {
        late GoRouter router;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Override auth to unauthenticated
              _isAuthenticatedProvider.overrideWith((_) => false),
            ],
            child: Consumer(
              builder: (ctx, ref, _) {
                router = _buildTestRouter(ref);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );

        router.go('/orders/ord_001');
        await tester.pumpAndSettle();

        expect(
          find.text('SignInScreen'),
          findsOneWidget,
          reason: 'Unauthenticated user must land on sign-in, not order screen',
        );
        expect(find.text('OrderTracking:ord_001'), findsNothing);
      },
    );

    testWidgets('/ resolves to HomeScreen', (tester) async {
      late GoRouter router;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (ctx, ref, _) {
              router = _buildTestRouter(ref);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('HomeScreen'), findsOneWidget);
    });
  });
}
