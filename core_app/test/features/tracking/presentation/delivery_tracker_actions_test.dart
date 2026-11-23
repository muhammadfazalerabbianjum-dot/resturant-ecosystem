import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_tracker_screen.dart'
    show singleOrderProvider;
import 'package:labs/features/tracking/presentation/delivery_tracker_screen.dart';

import '../../../helpers/app_localizations_test_helper.dart';

const tBurger = MenuItemModel(
  id: 'i1',
  name: 'Burger',
  priceCents: 1000,
  category: 'mains',
  isAvailable: true,
  quantityRemaining: 10,
);

/// Capturing in-memory cart repository (the default Isar-backed repo errors
/// in widget tests) — same double as the cart/perf7 suite.
class CapturingCartRepo extends CartRepository {
  CapturingCartRepo(this._initial)
    : super(
        IsarService.shared(),
        LoggerService(
          testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
        ),
      );

  CartModel _initial;

  List<CartItemModel> get items => _initial.items;

  @override
  Future<CartModel> loadCart() async => _initial;

  @override
  Future<void> saveCart(CartModel cart) async => _initial = cart;
}

/// PERF-8 W2: DeliveryTrackerScreen customer actions — contact-driver,
/// reorder, and the degraded stream branches — driven against fakes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launchedUrls = <String>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          final args = call.arguments;
          if (args is Map && args['url'] != null) {
            launchedUrls.add(args['url'] as String);
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
    launchedUrls.clear();
  });

  Widget buildTracker(
    WidgetTester tester, {
    required Stream<OrderModel?> orderStream,
    RestaurantConfigModel config = const RestaurantConfigModel(),
    CapturingCartRepo? cartRepo,
  }) {
    final router = GoRouter(
      initialLocation: '/tracker/order-1',
      routes: [
        GoRoute(
          path: '/tracker/:orderId',
          builder: (context, state) =>
              DeliveryTrackerScreen(orderId: state.pathParameters['orderId']!),
        ),
        GoRoute(
          path: '/cart',
          name: RouteNames.cart,
          builder: (context, state) =>
              const Scaffold(body: Text('Cart Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        singleOrderProvider('order-1').overrideWith((ref) => orderStream),
        restaurantConfigProvider.overrideWith((ref) => Stream.value(config)),
        if (cartRepo != null)
          cartRepositoryProvider.overrideWith((ref) => cartRepo),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizationsTestHelper.delegates,
        supportedLocales: AppLocalizationsTestHelper.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  OrderModel orderWithBurger() => OrderModel(
    id: 'order-1',
    customerId: 'user-test',
    status: OrderStatus.cooking,
    totalCents: 1500,
    createdAt: DateTime(2026, 1, 1),
    items: const [CartItemModel(item: tBurger, quantity: 1)],
  );

  /// Forces the restaurant-config stream to deliver its first value, so a
  /// "not configured" assertion cannot pass vacuously on a still-loading
  /// provider (PERF-8 W2 — the cold-start gap this batch fixed).
  Future<void> settleConfig(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeliveryTrackerScreen)),
    );
    try {
      await container.read(restaurantConfigProvider.future);
    } catch (_) {
      // The error-stream case is settled by the AsyncError state itself.
    }
    await tester.pumpAndSettle();
  }

  group('DeliveryTrackerScreen actions (PERF-8 W2)', () {
    testWidgets(
      'contact driver dials the configured phone even before the config stream lands',
      (tester) async {
        await tester.pumpWidget(
          buildTracker(
            tester,
            orderStream: Stream<OrderModel?>.value(orderWithBurger()),
            config: const RestaurantConfigModel(contactPhone: '+971501234567'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Contact Driver'));
        await tester.pumpAndSettle();

        expect(
          launchedUrls,
          contains('tel:+971501234567'),
          reason:
              'a configured phone must be dialed as a tel: URI — including '
              'on a cold deep-link where the settings stream has not landed '
              '(PERF-8 W2: the old valueOrNull-only read reported "not '
              'configured" on the very first tap)',
        );
      },
    );

    testWidgets('a failed config stream shows the snackbar and dials nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            singleOrderProvider('order-1').overrideWith(
              (ref) => Stream<OrderModel?>.value(orderWithBurger()),
            ),
            restaurantConfigProvider.overrideWith(
              (ref) => Stream<RestaurantConfigModel>.error(
                StateError('settings unavailable'),
              ),
            ),
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizationsTestHelper.delegates,
            supportedLocales: AppLocalizationsTestHelper.supportedLocales,
            home: DeliveryTrackerScreen(orderId: 'order-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact Driver'));
      await tester.pumpAndSettle();

      expect(
        find.text('Restaurant contact number is not configured yet.'),
        findsOneWidget,
        reason:
            'a failed config stream must fail closed to the snackbar — '
            'never hang the tap waiting for a value that cannot arrive',
      );
      expect(launchedUrls, isEmpty);
    });

    testWidgets(
      'contact driver with a loaded but empty phone shows the snackbar and dials nothing',
      (tester) async {
        await tester.pumpWidget(
          buildTracker(
            tester,
            orderStream: Stream<OrderModel?>.value(orderWithBurger()),
          ),
        );
        await tester.pumpAndSettle();
        await settleConfig(tester);

        await tester.tap(find.text('Contact Driver'));
        await tester.pumpAndSettle();

        expect(
          find.text('Restaurant contact number is not configured yet.'),
          findsOneWidget,
        );
        expect(
          launchedUrls,
          isEmpty,
          reason: 'a missing phone must never fall through to a launch',
        );
      },
    );

    testWidgets(
      'reorder writes every order item into the cart and navigates to it',
      (tester) async {
        final cartRepo = CapturingCartRepo(const CartModel(items: []));
        await tester.pumpWidget(
          buildTracker(
            tester,
            orderStream: Stream<OrderModel?>.value(orderWithBurger()),
            cartRepo: cartRepo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reorder Items'));
        await tester.pumpAndSettle();

        expect(
          find.text('Cart Screen'),
          findsOneWidget,
          reason: 'reorder must navigate to the cart route',
        );
        expect(
          cartRepo.items.map((i) => i.item.id),
          contains('i1'),
          reason: 'reorder must add every order item back into the cart',
        );
      },
    );

    testWidgets('an errored order stream renders the retry copy, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTracker(
          tester,
          orderStream: Stream<OrderModel?>.error(StateError('stream broke')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load this order. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a null order renders the not-found copy, not a crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTracker(tester, orderStream: Stream<OrderModel?>.value(null)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order not found'), findsOneWidget);
    });
  });
}
