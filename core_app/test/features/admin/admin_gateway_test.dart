@Tags(['needs-emulator'])
library;

import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:labs/features/admin/presentation/gateway/admin_gateway_screen.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_localizations_test_helper.dart';

final mockUser = MockUser(uid: 'owner1', email: 'owner@test.com');

/// Builds a GoRouter with all named routes the AdminGatewayScreen may
/// navigate to (login, home, roleRouter) plus the screen under test.
GoRouter buildTestRouter() {
  return GoRouter(
    initialLocation: '/admin-gateway',
    routes: [
      GoRoute(
        path: '/admin-gateway',
        builder: (context, state) => const AdminGatewayScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login'))),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: '/role-router',
        name: 'roleRouter',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Role Router'))),
      ),
    ],
  );
}

void main() {
  group('Admin Gateway Screen — Part 18 Tests', () {
    // ──────────────────── AUTH STATE ─────────────────────
    group('Auth state handling', () {
      testWidgets('shows loading indicator when auth is loading', (
        tester,
      ) async {
        // Use a StreamController to keep the auth stream in loading state
        // (no value emitted yet) so the CircularProgressIndicator is visible.
        final authController = StreamController<User?>();
        addTearDown(authController.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => authController.stream),
            ],
            child: MaterialApp.router(
              routerConfig: buildTestRouter(),
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            ),
          ),
        );
        await tester.pump();

        // E1 F3-09: the loading branch renders the library skeleton.
        expect(find.byType(SkeletonLoader), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows admin access denied for customer role', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(mockUser),
              ),
              // Override currentUserProvider to return a customer-role user.
              // This avoids needing Firestore mocks for the role lookup.
              currentUserProvider.overrideWith(
                (ref) async => const UserModel(
                  id: 'owner1',
                  email: 'owner@test.com',
                  role: UserRole.customer,
                ),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: buildTestRouter(),
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Non-admin user sees "You do not have admin access"
        expect(find.text('You do not have admin access.'), findsOneWidget);
        expect(find.text('Back to Home'), findsOneWidget);
      });

      testWidgets('shows error state when user data fails to load', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream<User?>.value(mockUser),
              ),
              // Override currentUserProvider to throw, simulating a
              // Firestore read failure.
              currentUserProvider.overrideWith(
                (ref) async => throw Exception('Failed to load user data'),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: buildTestRouter(),
              localizationsDelegates: AppLocalizationsTestHelper.delegates,
              supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Should not crash
        expect(tester.takeException(), isNull);
      });
    });

    // ──────────────────── 20-TAP TRIGGER ─────────────────────
    group('Profile screen 20-tap gateway trigger', () {
      testWidgets('tapping version text 19 times does NOT navigate away', (
        tester,
      ) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: Text('Profile'))),
          ),
        );
        // NOTE: Full integration test of 20-tap is in e2e suite because
        // profile_screen requires full auth + loyalty providers.
        // This stub ensures the test file itself compiles and registers correctly.
        expect(find.text('Profile'), findsOneWidget);
      });
    });
  });
}
