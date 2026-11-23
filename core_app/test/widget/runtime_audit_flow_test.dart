import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';
import 'package:labs/features/orders/domain/order_number_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:labs/features/loyalty/domain/loyalty_model.dart';
import 'package:labs/features/loyalty/presentation/loyalty_provider.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/admin/domain/admin_data_service.dart';
import 'package:labs/features/admin/domain/kitchen_service.dart';
import 'package:labs/features/admin/domain/delivery_service.dart';
import 'package:labs/features/tracking/data/driver_location_service.dart';
import 'package:labs/features/tracking/data/driver_location_service_provider.dart';
import 'package:labs/features/reservations/presentation/reservation_screen.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/features/cart/presentation/cart_screen.dart';
import 'package:labs/features/home/presentation/home_screen.dart';
import 'package:labs/features/orders/presentation/order_history_screen.dart';
import 'package:labs/features/profile/presentation/profile_screen.dart';
import '../helpers/app_localizations_test_helper.dart';
import '../helpers/test_helpers.dart';
import 'dart:async';
import 'dart:io';
import '../support/tenant_claim_fakes.dart';

final mockCustomerUser = MockUser(uid: 'flow-cust-1', email: 'flow@test.com');

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

class FakeFraudScreeningService extends FraudScreeningService {
  @override
  Future<bool> screenPayment() async => true;
}

class FakeCartValidatorService extends CartValidatorService {
  FakeCartValidatorService() : super(firestore: FakeFirebaseFirestore());
  @override
  Future<CartValidationResult> validate(
    List<Map<String, dynamic>> cartItems,
  ) async {
    return const CartValidationSuccess();
  }
}

class FakeOrderNumberService extends OrderNumberService {
  FakeOrderNumberService() : super(firestore: FakeFirebaseFirestore());
  @override
  Future<String> nextOrderNumber() async => 'ORD-FLOW-001';
}

Widget buildFlowScope({
  required Widget child,
  required FakeFirebaseFirestore firestore,
  User? authUser,
  CartModel cart = const CartModel(items: []),
  List<MenuItemModel> menuItems = const [],
}) {
  final authStream = Stream<User?>.value(authUser);
  final panicSvc = PanicSwitchService(
    firestore: firestore,
    tenantClaim: const FixedTenantClaim(),
  );
  final checkoutSvc = CheckoutService(
    firestore: firestore,
    functions: FirebaseFunctions.instance,
    logger: LoggerService(),
    promoService: PromoCodeService(FirebaseFunctions.instance, LoggerService()),
    panicSvc: panicSvc,
    fraudSvc: FakeFraudScreeningService(),
    cartValidator: FakeCartValidatorService(),
    orderNumSvc: FakeOrderNumberService(),
    tenantClaim: const FixedTenantClaim(),
  );

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
      kitchenServiceProvider.overrideWithValue(
        KitchenService(
          firestore: firestore,
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
      deliveryServiceProvider.overrideWithValue(
        DeliveryService(
          firestore: firestore,
          locationService: _FakeDriverLocation(firestore),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          tenantClaim: const FixedTenantClaim(),
        ),
      ),
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
      mergedMenuProvider.overrideWith((ref) => Stream.value(menuItems)),
      cartRepositoryProvider.overrideWith((ref) => _InMemoryCartRepo(cart)),
      userOrdersProvider.overrideWith((ref) => Stream.value(<OrderModel>[])),
      userLoyaltyProvider.overrideWith(
        (ref) => Stream.value(const LoyaltyModel()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsTestHelper.delegates,
      supportedLocales: AppLocalizationsTestHelper.supportedLocales,
      home: child,
    ),
  );
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

  group('RUNTIME AUDIT — Critical Flows', () {
    testWidgets('CartScreen with items shows checkout button and total', (
      tester,
    ) async {
      const cartWithItems = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
            quantity: 2,
          ),
        ],
      );

      await tester.pumpWidget(
        buildFlowScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          cart: cartWithItems,
          child: const CartScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
      // Cart with items should show the checkout button
      expect(find.text('Proceed to Checkout'), findsOneWidget);
      // Total should be $25.98 (2 x $12.99)
      expect(find.text('\$25.98'), findsOneWidget);
    });

    testWidgets('CheckoutScreen renders with populated cart state', (
      tester,
    ) async {
      const cartWithItems = CartModel(
        items: [
          CartItemModel(
            item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
            quantity: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        buildFlowScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          cart: cartWithItems,
          child: const CheckoutScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutScreen), findsOneWidget);
      // Order summary should show the item after cart loads
      expect(find.text('Place Order'), findsOneWidget);
    });

    testWidgets('ReservationScreen: form renders and validates', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFlowScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          child: const ReservationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReservationScreen), findsOneWidget);
      // Form fields should be present
      expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
      // Submit button should be present
      expect(find.text('New Reservation'), findsOneWidget);
    });

    testWidgets('HomeScreen: menu items render from provider', (tester) async {
      final items = [
        const MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
        const MenuItemModel(id: 'm2', name: 'Sushi', priceCents: 1899),
      ];

      await tester.pumpWidget(
        buildFlowScope(
          firestore: firestore,
          authUser: mockCustomerUser,
          menuItems: items,
          child: const HomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeScreen), findsOneWidget);
      // Menu items should be visible after promotions async completes
      // (IndexedStack keeps all tabs alive, so items may appear in multiple)
      expect(find.text('Pizza'), findsWidgets);
      expect(find.text('Sushi'), findsWidgets);
    });

    testWidgets(
      'HomeScreen tabs build LAZILY and keep visited-tab state (W8.9 T-4)',
      (tester) async {
        // The GDPR ask is decided upfront so it can never block tab taps.
        SharedPreferences.setMockInitialValues({
          kGdprAnalyticsConsentKey: true,
        });
        final items = [
          const MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299),
          const MenuItemModel(id: 'm2', name: 'Sushi', priceCents: 1899),
        ];

        await tester.pumpWidget(
          buildFlowScope(
            firestore: firestore,
            authUser: mockCustomerUser,
            menuItems: items,
            child: const HomeScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // LAZY: only the home feed (the launch tab) is built at boot — the
        // unvisited tab bodies never mount, so their heavy providers/streams
        // never fire during startup (W8.9 04-P2-1).
        expect(find.byType(CartScreen), findsNothing);
        expect(find.byType(OrderHistoryScreen), findsNothing);
        expect(find.byType(ProfileScreen), findsNothing);
        expect(find.text('Pizza'), findsWidgets);

        // Scope taps to the NavigationBar: tab bodies may contain the same
        // icons as the destinations.
        Finder navIcon(IconData icon) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(icon),
        );

        // First visit to the cart tab mounts it.
        await tester.tap(navIcon(Icons.shopping_cart_outlined));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(CartScreen), findsOneWidget);
        final cartElement = tester.element(find.byType(CartScreen));
        // Leave and come back: the visited tab STAYS MOUNTED in the
        // IndexedStack — the ELEMENT identity is preserved, which is the
        // Flutter-correct proof that its State (scroll position, form input)
        // was kept, not rebuilt (state-kept half of W8.9 04-P2-1).
        // NOTE: default finders skip non-active IndexedStack children (they
        // are laid out but not painted), so the hidden-tab proof must use
        // `skipOffstage: false` — it walks the FULL element tree and would
        // still find nothing if the tab were truly unmounted (placeholder),
        // which keeps the assertion honest.
        await tester.tap(navIcon(Icons.home_outlined));
        await tester.pump(const Duration(milliseconds: 300));
        // Hidden but STILL MOUNTED (skipOffstage:false walks the full tree;
        // a truly unmounted placeholder would find nothing):
        expect(find.byType(CartScreen, skipOffstage: false), findsOneWidget);
        await tester.tap(navIcon(Icons.shopping_cart_outlined));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        // The SAME element as the first visit — State was kept, not rebuilt.
        expect(
          identical(
            tester.element(find.byType(CartScreen, skipOffstage: false)),
            cartElement,
          ),
          isTrue,
        );
      },
    );

    // Waits until the cart provider's initial async load completes.
    // Read once to instantiate the provider, then wait for its state to settle.
    Future<void> waitForCartLoad(ProviderContainer container) async {
      final initial = container.read(cartProvider);
      if (initial is AsyncData<CartModel> || initial is AsyncError<CartModel>) {
        return;
      }
      // Use a listener to catch the transition to data/error.
      final completer = Completer<void>();
      final sub = container.listen<AsyncValue<CartModel>>(cartProvider, (
        prev,
        next,
      ) {
        if (next is AsyncData<CartModel> || next is AsyncError<CartModel>) {
          if (!completer.isCompleted) completer.complete();
        }
      }, fireImmediately: true);
      await completer.future.timeout(const Duration(seconds: 2));
      sub.close();
    }

    test('CartProvider: addItem updates cart state', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWith(
            (ref) => _InMemoryCartRepo(const CartModel(items: [])),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockCustomerUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForCartLoad(container);
      const item = MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(item);

      final cart = container.read(cartProvider).value;
      expect(cart, isNotNull);
      expect(cart!.items.length, 1);
      expect(cart.items.first.item.name, 'Pizza');
      expect(cart.items.first.quantity, 1);
      expect(cart.totalCents, 1299);
    });

    test('CartProvider: addItem twice increments quantity', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWith(
            (ref) => _InMemoryCartRepo(const CartModel(items: [])),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockCustomerUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForCartLoad(container);
      const item = MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(item);
      await notifier.addItem(item);

      final cart = container.read(cartProvider).value;
      expect(cart, isNotNull);
      expect(cart!.items.length, 1);
      expect(cart.items.first.quantity, 2);
      expect(cart.totalCents, 2598);
    });

    test('CartProvider: removeItem decrements quantity', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWith(
            (ref) => _InMemoryCartRepo(const CartModel(items: [])),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockCustomerUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForCartLoad(container);
      const item = MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(item);
      await notifier.addItem(item);
      // No modifiers selected for this line — pass the exact variant (B2-1).
      await notifier.removeItem(item.id, selectedOptions: const []);

      final cart = container.read(cartProvider).value;
      expect(cart, isNotNull);
      expect(cart!.items.length, 1);
      expect(cart.items.first.quantity, 1);
    });

    test('CartProvider: clearCart empties cart', () async {
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWith(
            (ref) => _InMemoryCartRepo(const CartModel(items: [])),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(mockCustomerUser),
          ),
        ],
      );
      addTearDown(container.dispose);

      await waitForCartLoad(container);
      const item = MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 1299);
      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(item);
      await notifier.clearCart();

      final cart = container.read(cartProvider).value;
      expect(cart, isNotNull);
      expect(cart!.items, isEmpty);
    });
  });
}
