import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/app/navigation/route_names.dart';

void main() {
  testWidgets('Browse Menu CTA navigates to menu route', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return Scaffold(
              body: EmptyStateWidget(
                icon: Icons.shopping_cart_outlined,
                title: 'Cart empty',
                subtitle: 'No items',
                ctaText: 'Browse Menu',
                onCtaPressed: () => context.pushNamed(RouteNames.menu),
              ),
            );
          },
        ),
        GoRoute(
          name: RouteNames.menu,
          path: '/menu',
          builder: (_, __) => const Scaffold(body: Text('Menu')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('Order Now CTA navigates to menu route', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Hungry?',
              ctaText: 'Order Now',
              onCtaPressed: () => context.pushNamed(RouteNames.menu),
            ),
          ),
        ),
        GoRoute(
          name: RouteNames.menu,
          path: '/menu',
          builder: (_, __) => const Scaffold(body: Text('Menu')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Order Now'));
    await tester.pumpAndSettle();

    expect(find.text('Menu'), findsOneWidget);
  });
}
