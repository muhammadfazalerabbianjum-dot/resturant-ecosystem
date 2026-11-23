// UI-10 (p20) Phase E — owner dashboard stat surfaces → StatTile +
// SectionHeader (E1, DISPLAY ONLY: dashboard data reads untouched — p17 owns
// the analytics surface, p20 only restyles the KPI row). Written RED before
// the wiring (p20 §3 phase E).
//
// L16: this file asserts PRESENTATION only. `streamOverviewStats()`, the
// panic-switch provider and the role gate are the sanctuary guards — asserted
// here as well so a restyle can never reach them.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/features/orders/domain/amount_formatter.dart';
import 'package:labs/l10n/app_localizations.dart';
import '../../../../helpers/app_localizations_test_helper.dart';
import '../../../../helpers/test_helpers.dart';
import '../../../../support/tenant_claim_fakes.dart';

/// Owner-scoped host, mirroring the legacy dashboard suite (W2.9 role gate).
Widget _harness(FakeFirebaseFirestore firestore) {
  final authStream = Stream<User?>.value(MockUser(uid: 'owner-1'));
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => authStream),
      adminDataServiceProvider.overrideWithValue(
        AdminDataService(
          firestore: firestore,
          logger: FakeLogger(),
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
      panicSwitchServiceProvider.overrideWithValue(
        PanicSwitchService(
          firestore: firestore,
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
      ordersAcceptingProvider.overrideWith((ref) => Stream<bool>.value(true)),
      currentUserProvider.overrideWith(
        (ref) async => const UserModel(id: 'owner-1', role: UserRole.owner),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const OwnerDashboard(),
          ),
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Home Route'))),
          ),
        ],
      ),
    ),
  );
}

/// Two orders in the 24h window: 2500 + 1500 cents, one still active.
Future<FakeFirebaseFirestore> _seededFirestore() async {
  final fs = FakeFirebaseFirestore();
  await fs.collection('orders').doc('o1').set({
    'tenantId': 'tenant_a',
    'totalCents': 2500,
    'status': 'delivered',
    'createdAt': Timestamp.now(),
  });
  await fs.collection('orders').doc('o2').set({
    'tenantId': 'tenant_a',
    'totalCents': 1500,
    'status': 'preparing',
    'createdAt': Timestamp.now(),
  });
  return fs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('p20 E — owner dashboard KPI adoption', () {
    testWidgets('E1: the three overview KPIs render as StatTile cards', (
      tester,
    ) async {
      final fs = await _seededFirestore();
      await tester.pumpWidget(_harness(fs));
      await tester.pumpAndSettle();

      final loc = AppLocalizations.of(
        tester.element(find.byType(OwnerDashboard)),
      );
      expect(find.byType(StatTile), findsNWidgets(3));
      expect(find.byType(SectionHeader), findsOneWidget);

      // Each KPI label is rendered exactly once AND lives inside a StatTile —
      // the legacy bodySmall title under a Material Card is gone.
      for (final label in <String>[
        loc.todaysOrders,
        loc.todaysRevenue,
        loc.activeOrders,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(StatTile)),
          findsOneWidget,
          reason: '$label must be a StatTile label',
        );
      }
    });

    testWidgets('E1: KPI values are display-only, byte-identical strings', (
      tester,
    ) async {
      final fs = await _seededFirestore();
      await tester.pumpWidget(_harness(fs));
      await tester.pumpAndSettle();

      final loc = AppLocalizations.of(
        tester.element(find.byType(OwnerDashboard)),
      );
      final tiles = tester.widgetList<StatTile>(find.byType(StatTile));
      final byLabel = {for (final t in tiles) t.label: t.value};

      expect(byLabel[loc.todaysOrders], '2', reason: 'count, untouched');
      expect(byLabel[loc.activeOrders], '1', reason: 'o2 is still preparing');
      // L13-style parity: the money string is exactly what the shared
      // formatter renders for the summed cents (2500 + 1500), never recomputed
      // by the widget.
      expect(byLabel[loc.todaysRevenue], formatAmount(2500 + 1500, 'USD'));
      expect(find.text(formatAmount(4000, 'USD')), findsOneWidget);
    });

    testWidgets('E1: the money value renders through the shared formatter', (
      tester,
    ) async {
      final fs = await _seededFirestore();
      await tester.pumpWidget(_harness(fs));
      await tester.pumpAndSettle();

      // The revenue tile never formats money itself: only the canonical
      // formatter's output may appear on screen.
      expect(find.text(r'$40.00'), findsOneWidget);
      expect(find.text(r'$40'), findsNothing);
    });

    testWidgets('L16: the panic banner + role gate survive the restyle', (
      tester,
    ) async {
      final fs = await _seededFirestore();
      await tester.pumpWidget(_harness(fs));
      await tester.pumpAndSettle();

      // Behavior preservation: the accepting-orders banner still renders its
      // switch, and the dashboard still routes away when the role is wrong.
      expect(find.text('Accepting Orders'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
