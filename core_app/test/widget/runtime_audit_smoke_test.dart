import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:labs/features/auth/presentation/login_screen.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/menu/presentation/menu_screen.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/admin/presentation/owner/owner_dashboard.dart';
import 'package:labs/features/admin/presentation/manager/manager_dashboard.dart';
import 'package:labs/features/admin/presentation/kitchen/kitchen_dashboard.dart';
import 'package:labs/features/admin/presentation/delivery/delivery_dashboard.dart';
import 'package:labs/features/admin/presentation/role_router_screen.dart';
import 'package:labs/features/admin/presentation/gateway/admin_gateway_screen.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:labs/features/tracking/data/driver_location_service_provider.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';
import 'package:labs/features/orders/domain/order_number_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import '../helpers/app_localizations_test_helper.dart';
import '../helpers/test_helpers.dart';
import 'dart:io';
import 'package:labs/app/tenancy/tenant_claim.dart';
import '../support/tenant_claim_fakes.dart';

// Mock auth users for role-based dashboards
final mockCustomerUser = MockUser(uid: 'cust-1', email: 'customer@test.com');
final mockOwnerUser = MockUser(uid: 'owner-1', email: 'owner@test.com');
final mockManagerUser = MockUser(uid: 'mgr-1', email: 'manager@test.com');
final mockKitchenUser = MockUser(uid: 'kitchen-1', email: 'kitchen@test.com');
final mockDeliveryUser = MockUser(
  uid: 'delivery-1',
  email: 'delivery@test.com',
);

/// Fake DriverLocationService that does nothing (avoids platform channels).
class _FakeDriverLocation extends DriverLocationService {
  _FakeDriverLocation(FirebaseFirestore firestore)
    : super(
        firestore,
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );
  @override
  Future<void> startTracking(String orderId) async {}
  @override
  Future<void> stopTracking() async {}
}

/// Returns a [ProviderScope] with all necessary overrides for screen-level
/// widget tests. Every screen in the app is pumped with mocked Firestore,
/// mocked auth stream, mocked cart (Isar via a test in-memory repo), and
/// mocked services that would otherwise hit platform channels.
Widget buildAuditScope({
  required Widget child,
  required FakeFirebaseFirestore firestore,
  User? authUser,
  Stream<User?>? authStream,
  List<MenuItemModel> menuItems = const [],
  CartModel cart = const CartModel(items: []),
}) {
  final effectiveAuthStream = authStream ?? Stream<User?>.value(authUser);

  // Services
  final adminSvc = AdminDataService(
    firestore: firestore,
    logger: FakeLogger(),
    tenantClaim: _FixedTenantClaim(),
  );
  final kitchenSvc = KitchenService(
    firestore: firestore,
    logger: FakeLogger(),
    syncQueue: RecordingSyncQueue(),
    tenantClaim: const FixedTenantClaim(),
  );
  final deliverySvc = DeliveryService(
    firestore: firestore,
    locationService: _FakeDriverLocation(firestore),
    logger: FakeLogger(),
    syncQueue: RecordingSyncQueue(),
    tenantClaim: const FixedTenantClaim(),
  );
  final panicSvc = PanicSwitchService(
    firestore: firestore,
    tenantClaim: _FixedTenantClaim(),
  );
  final checkoutSvc = CheckoutService(
    firestore: firestore,
    functions: FirebaseFunctions.instance,
    promoService: PromoCodeService(FirebaseFunctions.instance, LoggerService()),
    logger: LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    ),
    panicSvc: panicSvc,
    fraudSvc: FakeFraudScreeningService(),
    cartValidator: FakeCartValidatorService(),
    orderNumSvc: FakeOrderNumberService(),
    tenantClaim: _FixedTenantClaim(),
  );

  // Minimal router for screens that call context.goNamed() such as
  // AdminGatewayScreen and RoleRouterScreen.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', name: 'home', builder: (_, __) => child),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Login'))),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Admin'))),
      ),
      GoRoute(
        path: '/role-router',
        name: 'roleRouter',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('RoleRouter'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      firestoreProvider.overrideWithValue(firestore),
      authStateProvider.overrideWith((ref) => effectiveAuthStream),
      // W2.9: dashboards are role-gated. currentUserProvider reads the
      // signed-in user's role from users/{uid} through authRepositoryProvider;
      // the default is a FallbackAuthRepository that returns null, so wire the
      // real repository to the fake Firestore where seedUserRole() writes.
      authRepositoryProvider.overrideWith(
        (ref) => FirebaseAuthRepository(
          FirebaseAuth.instance,
          firestore,
          FakeLogger(),

          cache: const NoOpLocalCache(),
        ),
      ),
      adminDataServiceProvider.overrideWithValue(adminSvc),
      kitchenServiceProvider.overrideWithValue(kitchenSvc),
      deliveryServiceProvider.overrideWithValue(deliverySvc),
      driverLocationServiceProvider.overrideWithValue(
        _FakeDriverLocation(firestore),
      ),
      ordersAcceptingProvider.overrideWith((ref) => Stream<bool>.value(true)),
      panicSwitchServiceProvider.overrideWithValue(panicSvc),
      checkoutServiceProvider.overrideWithValue(checkoutSvc),
      syncQueueProvider.overrideWith(
        (ref) => IsarSyncQueue(
          IsarService.shared(),
          LoggerService(),
          firestore: FirestoreQueueWriter(firestore),
        ),
      ),
      pendingSyncCountProvider.overrideWith((ref) => Stream.value(0)),
      deadLetterCountProvider.overrideWith((ref) => Stream.value(0)),
      // Menu: override mergedMenuProvider to avoid Firestore stream queries
      mergedMenuProvider.overrideWith((ref) => Stream.value(menuItems)),
      // Cart: override cartProvider's repository to avoid Isar
      cartRepositoryProvider.overrideWith((ref) => _InMemoryCartRepo(cart)),
      userOrdersProvider.overrideWith((ref) => Stream.value(<OrderModel>[])),
      userLoyaltyProvider.overrideWith(
        (ref) => Stream.value(const LoyaltyModel()),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
    ),
  );
}

/// In-memory cart repository that avoids requiring Isar native libs.
/// Uses IsarService.shared() — never opens the real store (the overridden
/// loadCart/saveCart never touch `db`).
class _InMemoryCartRepo extends CartRepository {
  CartModel current;
  _InMemoryCartRepo(this.current)
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  @override
  Future<CartModel> loadCart() async => current;

  @override
  Future<void> saveCart(CartModel cart) async {
    current = cart;
  }
}

/// Fake fraud screening service.
class FakeFraudScreeningService extends FraudScreeningService {
  @override
  Future<bool> screenPayment() async => true;
}

/// Fake cart validator.
class FakeCartValidatorService extends CartValidatorService {
  FakeCartValidatorService() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<CartValidationResult> validate(
    List<Map<String, dynamic>> cartItems,
  ) async {
    return const CartValidationSuccess();
  }
}

/// Fake order number service.
class FakeOrderNumberService extends OrderNumberService {
  FakeOrderNumberService() : super(firestore: FakeFirebaseFirestore());
  @override
  Future<String> nextOrderNumber() async => 'ORD-123456';
}

// Seed a user doc for the auth'd user so currentUserProvider resolves with data.
Future<void> seedUserRole(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String role,
}) async {
  await firestore.collection('users').doc(uid).set({
    'email': '$role@test.com',
    'role': role,
    'name': 'Test $role',
    'branchId': 'branch-1',
  });
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('RUNTIME AUDIT — Smoke Test: All Screens Render', () {
    testWidgets('LoginScreen renders, no infinite spinner', (tester) async {
      await tester.pumpWidget(
        buildAuditScope(firestore: firestore, child: const LoginScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      // The screen may briefly show a spinner while loading auth; after pumps,
      // it must settle to a stable UI — no infinite CircularProgressIndicator.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'LoginScreen stuck in infinite loading',
      );
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('HomeScreen renders with mock data', (tester) async {
      await seedUserRole(
        firestore,
        uid: mockCustomerUser.uid,
        role: 'customer',
      );
      final items = [
        const MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
        const MenuItemModel(id: 'm2', name: 'Sushi', priceCents: 1899),
      ];
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          menuItems: items,
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);
      // After async resolves, no infinite loading spinner.
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'HomeScreen stuck in infinite loading',
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('CartScreen renders empty state', (tester) async {
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          cart: const CartModel(items: []),
          child: const CartScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CartScreen), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'CartScreen stuck in infinite loading',
      );
      // Empty cart shows the empty state
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('MenuScreen renders', (tester) async {
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          menuItems: [],
          child: const MenuScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(MenuScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'MenuScreen stuck in infinite loading',
      );
    });

    testWidgets('CheckoutScreen renders with cart', (tester) async {
      const cartWithItems = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
            quantity: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          cart: cartWithItems,
          child: const CheckoutScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CheckoutScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'CheckoutScreen stuck in infinite loading',
      );
      // Checkout UI with cart should show delivery details
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('OrderHistoryScreen renders empty state', (tester) async {
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          child: const OrderHistoryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(OrderHistoryScreen), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'OrderHistoryScreen stuck in infinite loading',
      );
    });

    testWidgets('OwnerDashboard renders navigation', (tester) async {
      await seedUserRole(firestore, uid: mockOwnerUser.uid, role: 'owner');
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockOwnerUser,
          child: const OwnerDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(OwnerDashboard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      // Should show the NavigationBar or tab content — not stuck on spinner
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'OwnerDashboard stuck in infinite loading',
      );
    });

    testWidgets('ManagerDashboard renders', (tester) async {
      await seedUserRole(firestore, uid: mockManagerUser.uid, role: 'manager');
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockManagerUser,
          child: const ManagerDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ManagerDashboard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'ManagerDashboard stuck in infinite loading',
      );
    });

    testWidgets('KitchenDashboard renders', (tester) async {
      await seedUserRole(firestore, uid: mockKitchenUser.uid, role: 'kitchen');
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockKitchenUser,
          child: const KitchenDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(KitchenDashboard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'KitchenDashboard stuck in infinite loading',
      );
    });

    testWidgets('DeliveryDashboard renders', (tester) async {
      await seedUserRole(
        firestore,
        uid: mockDeliveryUser.uid,
        role: 'delivery',
      );
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockDeliveryUser,
          child: const DeliveryDashboard(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(DeliveryDashboard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'DeliveryDashboard stuck in infinite loading',
      );
    });

    testWidgets('ReservationScreen renders', (tester) async {
      await tester.pumpWidget(
        buildAuditScope(firestore: firestore, child: const ReservationScreen()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReservationScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'ReservationScreen stuck in infinite loading',
      );
    });

    testWidgets('RoleRouterScreen renders with authenticated customer', (
      tester,
    ) async {
      await seedUserRole(
        firestore,
        uid: mockCustomerUser.uid,
        role: 'customer',
      );
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          child: const RoleRouterScreen(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // RoleRouterScreen redirects to home for customer role, potentially
      // leaving the original widget in the tree during transition. The key
      // check is that it renders and doesn't crash with an unrecoverable
      // error state — a Scaffold must always be present.
      expect(
        find.byType(RoleRouterScreen),
        findsAtLeastNWidgets(1),
        reason: 'RoleRouterScreen must render for authenticated user',
      );
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'RoleRouterScreen must not crash',
      );
    });

    testWidgets('AdminGatewayScreen renders denied state for customer', (
      tester,
    ) async {
      await seedUserRole(
        firestore,
        uid: mockCustomerUser.uid,
        role: 'customer',
      );
      await tester.pumpWidget(
        buildAuditScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          child: const AdminGatewayScreen(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(AdminGatewayScreen), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'AdminGatewayScreen stuck in infinite loading',
      );
      // Customer role should see the denied state
      expect(find.textContaining('admin access'), findsWidgets);
    });
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
