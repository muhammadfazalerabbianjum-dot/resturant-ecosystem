import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/compliance/data_export_service.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import 'package:labs/l10n/app_localizations.dart';

class _FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDataExportService implements DataExportService {
  bool exportAndShareCalled = false;

  @override
  Future<void> exportAndShare({
    required String shareSubject,
    required String shareText,
  }) async {
    exportAndShareCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ProfileScreen Behavior Tests', () {
    late _FakeAuthRepository fakeAuth;
    late _FakeDataExportService fakeExport;

    setUp(() {
      fakeAuth = _FakeAuthRepository();
      fakeExport = _FakeDataExportService();
    });

    Widget createRouterApp() {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/login',
            name: RouteNames.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Login Screen')),
          ),
          GoRoute(
            path: '/orders',
            name: RouteNames.orders,
            builder: (context, state) =>
                const Scaffold(body: Text('Orders Screen')),
          ),
          GoRoute(
            path: '/loyalty',
            name: RouteNames.loyalty,
            builder: (context, state) =>
                const Scaffold(body: Text('Loyalty Screen')),
          ),
          GoRoute(
            path: '/reservations',
            name: RouteNames.reservations,
            builder: (context, state) =>
                const Scaffold(body: Text('Reservations Screen')),
          ),
          GoRoute(
            path: '/delete-account',
            name: RouteNames.deleteAccount,
            builder: (context, state) =>
                const Scaffold(body: Text('Delete Account Screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          dataExportServiceProvider.overrideWithValue(fakeExport),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    testWidgets('Renders all main sections and menu items', (tester) async {
      await tester.pumpWidget(createRouterApp());
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsAtLeastNWidgets(1));
      expect(find.text('Order History'), findsOneWidget);
      expect(find.text('Loyalty & Rewards'), findsOneWidget);
      expect(find.text('My Reservations'), findsOneWidget);
      expect(find.text('Export My Data'), findsOneWidget);
      expect(find.text('Delete My Account'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets(
      'Tapping Export My Data calls DataExportService.exportAndShare',
      (tester) async {
        await tester.pumpWidget(createRouterApp());
        await tester.pumpAndSettle();

        final exportTile = find.text('Export My Data');
        expect(exportTile, findsOneWidget);

        // UI-15 (p24): the settings block above pushes the Art.20 row below
        // the default test viewport — the screen is a scroll view, so scroll
        // the row into view before tapping it (an off-screen tap hits nothing).
        await tester.ensureVisible(exportTile);
        await tester.pumpAndSettle();

        await tester.tap(exportTile);
        await tester.pumpAndSettle();

        expect(fakeExport.exportAndShareCalled, isTrue);
      },
    );

    testWidgets('Tapping Logout icon calls AuthRepository.signOut', (
      tester,
    ) async {
      await tester.pumpWidget(createRouterApp());
      await tester.pumpAndSettle();

      final logoutBtn = find.byIcon(Icons.logout);
      expect(logoutBtn, findsOneWidget);

      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.signOutCalled, isTrue);
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
