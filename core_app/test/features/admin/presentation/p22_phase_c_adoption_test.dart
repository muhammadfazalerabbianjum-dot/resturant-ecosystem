import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
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

import '../../../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Phase C adoption — C4: AdminMenuManager', () {
    testWidgets('renders MenuTile and no raw ListTile', (tester) async {
      final items = [
        const MenuItemModel(
          id: 'm1',
          name: 'Classic Burger',
          priceCents: 1299,
          isAvailable: true,
          category: 'Burgers',
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
              (ref) =>
                  Stream.value(const RestaurantConfigModel(currency: 'USD')),
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

      expect(find.byType(MenuTile), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('renders EmptyStateWidget when menu is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
            currentUserProvider.overrideWith(
              (ref) async => const UserModel(id: 'u1', role: UserRole.owner),
            ),
            mergedMenuProvider.overrideWith(
              (ref) => Stream<List<MenuItemModel>>.value(const []),
            ),
            restaurantConfigProvider.overrideWith(
              (ref) =>
                  Stream.value(const RestaurantConfigModel(currency: 'USD')),
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

      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });
  });

  group('Phase C adoption — C2: OperatingHoursScreen', () {
    testWidgets('renders BrandCard and BrandButton, no raw Card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = FakeFirebaseFirestore();
      await db.collection('settings').doc('tenant_a_defaultOperatingHours').set(
        {
          'monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
        },
      );

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

      expect(find.byType(BrandCard), findsWidgets);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(BrandButton), findsOneWidget);
    });
  });

  group('Phase C adoption — C3: TierFlagManagerScreen', () {
    testWidgets('renders SettingTile or BrandCard, BrandButton', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.collection('settings').doc('featureFlags').set({
        'enableLoyalty': true,
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

      expect(find.byType(SettingTile), findsWidgets);
      expect(find.byType(BrandButton), findsOneWidget);
    });
  });

  group('Phase C adoption — C5: AdminGatewayScreen', () {
    testWidgets('denied screen renders BrandButton instead of ElevatedButton', (
      tester,
    ) async {
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

      expect(find.byType(BrandButton), findsOneWidget);
    });
  });

  group('Phase C adoption — C1: RestaurantSetupScreen', () {
    testWidgets('renders SectionHeader in setup tabs', (tester) async {
      final db = FakeFirebaseFirestore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
            firestoreProvider.overrideWithValue(db),
            restaurantConfigProvider.overrideWith(
              (_) => Stream.value(
                const RestaurantConfigModel(restaurantName: 'Carnama Kitchen'),
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

      expect(find.byType(SectionHeader), findsWidgets);
    });

    testWidgets(
      'Hours tab day rows are SettingTiles with >=48 dp switch targets',
      (tester) async {
        // Tall viewport: all seven day rows must be laid out (L19 target audit).
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        // Pre-p22 the Hours tab used raw CheckboxListTile rows.
        await tester.tap(find.text('Hours'));
        await tester.pumpAndSettle();

        expect(find.byType(SettingTile), findsNWidgets(7));
        expect(find.byType(CheckboxListTile), findsNothing);

        // L19: every new interactive target is at least 48x48 dp.
        for (final target in find.byType(Switch).evaluate()) {
          final size = tester.getSize(find.byWidget(target.widget));
          expect(size.height, greaterThanOrEqualTo(48.0));
          expect(size.width, greaterThanOrEqualTo(48.0));
        }

        // The SettingTile conversion kept the toggle functional: Monday starts
        // open and flips to closed on tap.
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      },
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
