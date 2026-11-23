import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/admin/presentation/admin_menu_manager.dart';
import 'package:labs/features/admin/presentation/gateway/admin_gateway_screen.dart';
import 'package:labs/features/admin/presentation/setup/operating_hours_screen.dart';
import 'package:labs/features/admin/presentation/setup/restaurant_setup_screen.dart';
import 'package:labs/features/admin/presentation/setup/tier_flag_manager_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/l10n/app_localizations.dart';

import '../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  void setSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('p22: AdminMenuManager golden', (tester) async {
    setSurfaceSize(tester);
    final items = [
      const MenuItemModel(
        id: 'm1',
        name: 'Classic Burger',
        priceCents: 1299,
        isAvailable: true,
        category: 'Burgers',
      ),
      const MenuItemModel(
        id: 'm2',
        name: 'Truffle Fries',
        priceCents: 699,
        isAvailable: false,
        category: 'Sides',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
          ),
          mergedMenuProvider.overrideWith(
            (ref) => Stream<List<MenuItemModel>>.value(items),
          ),
          restaurantConfigProvider.overrideWith(
            (ref) => Stream.value(const RestaurantConfigModel(currency: 'USD')),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminMenuManager(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AdminMenuManager),
      matchesGoldenFile('goldens/p22_admin_menu_manager.png'),
    );
  });

  testWidgets('p22: OperatingHoursScreen golden', (tester) async {
    setSurfaceSize(tester);
    final db = FakeFirebaseFirestore();
    await db.collection('settings').doc('tenant_a_defaultOperatingHours').set({
      'monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
      'tuesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
      'wednesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
      'thursday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
      'friday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '23:00'},
      'saturday': {'isOpen': true, 'openTime': '10:00', 'closeTime': '23:00'},
      'sunday': {'isOpen': false, 'openTime': '10:00', 'closeTime': '20:00'},
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
          firestoreProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(FakeLogger()),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/operating-hours',
            routes: [
              GoRoute(
                path: '/operating-hours',
                builder: (_, _) => const OperatingHoursScreen(),
              ),
              GoRoute(
                path: '/',
                name: RouteNames.home,
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Home'))),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OperatingHoursScreen),
      matchesGoldenFile('goldens/p22_operating_hours.png'),
    );
  });

  testWidgets('p22: TierFlagManagerScreen golden', (tester) async {
    setSurfaceSize(tester);
    final db = FakeFirebaseFirestore();
    await db.collection('settings').doc('featureFlags').set({
      'enableLoyalty': true,
      'holidayMode': false,
      'selfServiceKiosk': true,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
          firestoreProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(FakeLogger()),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TierFlagManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TierFlagManagerScreen),
      matchesGoldenFile('goldens/p22_tier_flag_manager.png'),
    );
  });

  testWidgets('p22: AdminGatewayScreen denied golden', (tester) async {
    setSurfaceSize(tester);
    final mockUser = MockUser(uid: 'c1', email: 'cust@test.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockUser),
          ),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(
              id: 'c1',
              email: 'cust@test.com',
              role: UserRole.customer,
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/admin-gateway',
            routes: [
              GoRoute(
                path: '/admin-gateway',
                builder: (_, _) => const AdminGatewayScreen(),
              ),
              GoRoute(
                path: '/home',
                name: RouteNames.home,
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Home'))),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AdminGatewayScreen),
      matchesGoldenFile('goldens/p22_admin_gateway_denied.png'),
    );
  });

  testWidgets('p22: RestaurantSetupScreen brand golden', (tester) async {
    setSurfaceSize(tester);
    final db = FakeFirebaseFirestore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
          firestoreProvider.overrideWithValue(db),
          restaurantConfigProvider.overrideWith(
            (_) => Stream.value(
              const RestaurantConfigModel(
                restaurantName: 'Carnama Kitchen',
                tagline: 'Artisanal Street Food',
                contactEmail: 'hello@carnama.com',
              ),
            ),
          ),
          currentUserProvider.overrideWith(
            (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RestaurantSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RestaurantSetupScreen),
      matchesGoldenFile('goldens/p22_restaurant_setup_brand.png'),
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
