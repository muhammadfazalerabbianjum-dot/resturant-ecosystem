import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/navigation/route_names.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/presentation/merged_menu_provider.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:labs/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/locations/data/location_repository.dart';

import '../../../helpers/test_helpers.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import '../../../support/tenant_claim_fakes.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// Scripted [CheckoutService]: every async dependency of the place-order
/// flow is overridable per-test while everything NOT overridden
/// (fetchBranch / getOrCreateSessionId / clearSessionId /
/// isBelowMinimumOrderTotal / generateSessionOrderId) runs the REAL
/// implementation against the injected [FakeFirebaseFirestore] and mocked
/// SharedPreferences. A test therefore proves a specific gate
/// (fraud / panic / cart-validation / location / tax fail-closed / min-total
/// / sign-in / branch / offline / idempotency) without ever stubbing the
/// money invariants themselves.
class _ScriptedCheckoutService extends CheckoutService {
  _ScriptedCheckoutService({FakeFirebaseFirestore? firestore})
    : super(
        firestore: firestore ?? FakeFirebaseFirestore(),
        functions: _MockFirebaseFunctions(),
        promoService: PromoCodeService(_MockFirebaseFunctions(), FakeLogger()),
        logger: FakeLogger(),
        tenantClaim: const FixedTenantClaim(),
      );

  bool screenResult = true;
  bool acceptingResult = true;
  CartValidationResult cartValidationResult = const CartValidationSuccess();
  PromoCodeResult? promoResult;
  InvoiceTotal? invoiceResult;
  Object? invoiceThrow;
  StripePaymentResult? paymentResult;
  Object? paymentThrow;
  Object? createOrderThrow;
  String orderNumber = 'TKT-000001';

  // P8(W3) concurrency instrumentation: how many times the screen ENTERED
  // each money stage. A double-submit must never enter a stage twice —
  // the counters are the assertion surface for the re-entrancy fence.
  int screenPaymentCalls = 0;
  int createOrderCalls = 0;

  /// When set, screenPayment() suspends until the test completes it — the
  /// harness for pinning the place-order fence while the pipeline hangs
  /// mid pre-flight (exactly the window where the old code had no fence).
  Completer<void>? screenPaymentGate;

  // Captured arguments - the assertion surface for what the screen actually
  // submitted to the server-side money pipeline.
  int? capturedTipCents;
  int? capturedDeliveryFeeCents;
  String? capturedPromoCode;
  final List<CartModel> capturedChargedCarts = [];

  int get _promoDiscount =>
      (promoResult?.isValid ?? false) ? promoResult!.discountCents : 0;

  @override
  Future<bool> screenPayment() async {
    screenPaymentCalls++;
    if (screenPaymentGate != null) await screenPaymentGate!.future;
    return screenResult;
  }

  @override
  Future<bool> isOrdersAccepting() async => acceptingResult;

  @override
  Future<CartValidationResult> validateCart(
    List<Map<String, dynamic>> items,
  ) async => cartValidationResult;

  @override
  Future<PromoCodeResult> validatePromo(String code, int cartTotalCents) async {
    return promoResult ?? const PromoCodeResult(isValid: false);
  }

  @override
  Future<InvoiceTotal> calculateFinalTotal(
    int subtotalCents, {
    String? promoCode,
    String? userId,
    int tipCents = 0,
    int deliveryFeeCents = 0,
  }) async {
    capturedTipCents = tipCents;
    capturedDeliveryFeeCents = deliveryFeeCents;
    capturedPromoCode = promoCode;
    if (invoiceThrow != null) throw invoiceThrow!;
    return invoiceResult ??
        InvoiceTotal(
          netCents:
              subtotalCents - _promoDiscount + tipCents + deliveryFeeCents,
          taxCents: 0,
          discountCents: _promoDiscount,
          tipCents: tipCents,
          deliveryFeeCents: deliveryFeeCents,
        );
  }

  @override
  Future<String> nextOrderNumber() async => orderNumber;

  @override
  Future<StripePaymentResult?> processStripePayment({
    required int finalTotal,
    required CartModel cart,
    required String idempotencyKey,
    int tipCents = 0,
    int deliveryFeeCents = 0,
    String? promoCode,
    String? orderId,
  }) async {
    capturedChargedCarts.add(cart);
    if (paymentThrow != null) throw paymentThrow!;
    return paymentResult ??
        StripePaymentResult(
          paymentIntentId: 'pi_test_1',
          amountCents: finalTotal,
          taxCents: 0,
          discountCents: _promoDiscount,
        );
  }

  @override
  Future<Map<String, dynamic>> createOrder({
    required String paymentIntentId,
    required OrderModel order,
    required String userId,
    required String idempotencyKey,
  }) async {
    createOrderCalls++;
    if (createOrderThrow != null) throw createOrderThrow!;
    return <String, dynamic>{'orderId': 'server-1'};
  }
}

/// Wires the screen under test with a [GoRouter] registering the two
/// navigation targets checkout can reach on its own: the menu (empty-cart
/// CTA) and the order tracker (post-payment redirect).
Widget _buildHarness({
  required CheckoutService service,
  required CartRepository cartRepository,
  required FakeLogger logger,
  required RecordingSyncQueue syncQueue,
  String? userId = 'test-uid',
  String? branchId = 'b1',
  RestaurantConfigModel? config,
}) {
  return ProviderScope(
    overrides: [
      cartRepositoryProvider.overrideWithValue(cartRepository),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      currentUserIdProvider.overrideWithValue(userId),
      checkoutServiceProvider.overrideWithValue(service),
      restaurantConfigProvider.overrideWith(
        (ref) => Stream.value(
          config ??
              const RestaurantConfigModel(
                currency: 'USD',
                deliveryFeeCents: 300,
                tipEnabled: true,
              ),
        ),
      ),
      locationsProvider.overrideWith((ref) async => const []),
      loggerProvider.overrideWithValue(logger),
      tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
      syncQueueProvider.overrideWithValue(syncQueue),
      currentBranchIdProvider.overrideWith(
        (ref) => _FixedBranchNotifier(
          FakeFirebaseFirestore(),
          BranchService(FakeFirebaseFirestore(), logger: logger),
        )..fix(branchId),
      ),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _TestRouter.routerConfig,
    ),
  );
}

/// [CurrentBranchNotifier] whose selected branch is pinned by the test (the
/// real notifier auto-resolves from Firestore streams - not under test here).
class _FixedBranchNotifier extends CurrentBranchNotifier {
  _FixedBranchNotifier(super.db, super.branchService);

  void fix(String? branchId) => state = branchId;
}

/// The GoRouter shared by the harness: checkout, menu (CTA target) and the
/// order tracker (post-payment redirect) under their REAL route names.
class _TestRouter {
  static GoRouter get routerConfig => GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(
        path: '/checkout',
        name: RouteNames.checkout,
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/menu',
        name: RouteNames.menu,
        builder: (_, __) => const Scaffold(
          key: ValueKey('menu-marker'),
          body: Text('MENU-MARKER'),
        ),
      ),
      GoRoute(
        path: '/orders/:orderId/track',
        name: RouteNames.orderTracker,
        builder: (_, state) => Scaffold(
          key: const ValueKey('tracker-marker'),
          body: Text('TRACKER-MARKER:${state.pathParameters['orderId'] ?? ''}'),
        ),
      ),
    ],
  );
}

class _StubCartRepository implements CartRepository {
  _StubCartRepository(this.cart) : _never = null, throwOnLoad = null;

  _StubCartRepository.hanging()
    : _never = Completer<CartModel>(),
      cart = const CartModel(items: []),
      throwOnLoad = null;

  _StubCartRepository.throwing(this.throwOnLoad)
    : _never = null,
      cart = const CartModel(items: []);

  final CartModel cart;
  final Completer<CartModel>? _never;
  final Object? throwOnLoad;

  @override
  Future<CartModel> loadCart() async {
    if (throwOnLoad != null) throw throwOnLoad!;
    if (_never != null) return _never.future;
    return cart;
  }

  @override
  Future<void> saveCart(CartModel cart) async {}
}

const _oneItemCart = CartModel(
  items: [
    CartItemModel(
      item: MenuItemModel(id: 'm1', name: 'Pizza', priceCents: 5000),
      quantity: 1,
    ),
  ],
);

/// Drives the screen's real `_openMapPicker` -> LiveMapPickerWidget ->
/// `onLocationPicked` -> `_selectedLatLng` path end-to-end (the picker's GPS
/// probe fails under the test binding and falls back to the neutral pin -
/// its documented test behavior).
Future<void> _setDeliveryLocationViaPicker(WidgetTester tester) async {
  // Fixed pumps, never pumpAndSettle: the map's tile layer keeps retrying
  // its blocked network fetches under the test binding, which never settles.
  // The geolocator channel mock makes the picker's GPS probe succeed, which
  // enables confirm on the first frames.
  await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
  // Tap confirm EXACTLY ONCE: the sheet route stays mounted (and its button
  // stays alive) for the ~200ms exit animation, so any re-tap would fire
  // onLocationPicked again and pop the CHECKOUT route underneath.
  await tester.tap(find.byIcon(Icons.check), warnIfMissed: false);
  for (
    var i = 0;
    i < 8 && find.byIcon(Icons.check).evaluate().isNotEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    find.byIcon(Icons.check),
    findsNothing,
    reason: 'the map picker must close after confirming the pin',
  );
  expect(
    find.byIcon(Icons.location_on),
    findsOneWidget,
    reason: 'the picked delivery location must be stored by the screen',
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Brings the flow to the Place Order tap with every pre-tax gate passing
/// (fraud/panic allow, cart valid, location set via the real picker, branch
/// doc seeded), then lets the charge pipeline fully execute.
Future<void> _runChargeScenario(
  WidgetTester tester, {
  required _ScriptedCheckoutService service,
  required FakeLogger logger,
  required RecordingSyncQueue queue,
  required FakeFirebaseFirestore firestore,
}) async {
  await firestore.collection('branches').doc('b1').set({
    'name': 'Main Branch',
    'isActive': true,
  });
  await tester.pumpWidget(
    _buildHarness(
      service: service,
      cartRepository: _StubCartRepository(_oneItemCart),
      logger: logger,
      syncQueue: queue,
    ),
  );
  await tester.pumpAndSettle();
  await _setDeliveryLocationViaPicker(tester);
  await tester.ensureVisible(find.text('Place Order'));
  await tester.tap(find.text('Place Order'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(
      const NotificationDetails(
        android: AndroidNotificationDetails('ch', 'Ch'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  setUp(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    // Geolocator: the real plugin is absent under the test binding and its
    // missing-channel future never completes, leaving the map picker's
    // confirm button disabled forever. A platform-channel mock returns a
    // REAL position, so the picker takes its documented success path
    // (pin moves, confirm enabled) deterministically.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (call) async {
            if (call.method == 'getCurrentPosition') {
              return <String, dynamic>{
                'latitude': 37.7749,
                'longitude': -122.4194,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
            }
            return null;
          },
        );
    // The success path initializes the notification plugin; a mock keeps the
    // REAL initialize/show contract exercised without platform channels.
    // The success path initializes the notification plugin; a mock keeps the
    // REAL initialize/show contract exercised without platform channels.
    final plugin = _MockNotificationsPlugin();
    when(
      () => plugin.initialize(
        any(),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.show(
        any(),
        any(),
        any(),
        any(),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    LocalNotificationService.pluginForTest = plugin;
  });

  group('CheckoutScreen - cart states', () {
    testWidgets('loading cart shows the localized loading shell', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          service: _ScriptedCheckoutService(),
          cartRepository: _StubCartRepository.hanging(),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
        ),
      );
      await tester.pump();
      // UI-13 (p21 F3-09): the loading shell is the library skeleton row set
      // (three full-width `TileSkeletons.setting()` placeholders) — the
      // pre-adoption single `CircularProgressIndicator` is gone.
      expect(find.byType(SkeletonLoader), findsNWidgets(3));
      expect(
        find.text('Checkout'),
        findsOneWidget,
        reason: 'the checkout app bar is present while loading',
      );
    });

    testWidgets(
      'cart load failure surfaces the mapped error, never a blank body',
      (tester) async {
        final err = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'denied',
        );
        await tester.pumpWidget(
          _buildHarness(
            service: _ScriptedCheckoutService(),
            cartRepository: _StubCartRepository.throwing(err),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(FirebaseExceptionMapper.map(err)), findsOneWidget);
      },
    );

    testWidgets(
      'empty cart shows the recoverable browse-menu CTA that lands on the '
      'menu route',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            service: _ScriptedCheckoutService(),
            cartRepository: _StubCartRepository(const CartModel(items: [])),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Your cart is empty'), findsOneWidget);
        await tester.tap(find.text('Browse Menu'));
        await tester.pumpAndSettle();
        expect(
          find.text('MENU-MARKER'),
          findsOneWidget,
          reason: 'the CTA must land on RouteNames.menu, not a dead end',
        );
      },
    );
  });

  group('CheckoutScreen - promo application (real validatePromo path)', () {
    testWidgets(
      'valid promo: server message shown and discount reflected in the '
      'preview total',
      (tester) async {
        final service = _ScriptedCheckoutService()
          ..promoResult = const PromoCodeResult(
            isValid: true,
            discountCents: 500,
            message: 'WELCOME20 applied',
          );
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();

        // subtotal 5000 + delivery 300 = 5300 preview before the promo.
        expect(
          find.text(moneyCents(5300, currencyCode: 'USD')),
          findsOneWidget,
        );
        final promoField = find.byType(TextField);
        // The promo row sits inside the lazy ListView below the fold (the
        // totals footer is a sibling Container, always built) — drag the list
        // until the field is actually built and visible.
        await tester.dragUntilVisible(
          promoField,
          find.byType(ListView),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        await tester.enterText(promoField, 'WELCOME20');
        // Nudge back: dragUntilVisible can leave the row half-behind the app
        // bar, where taps cannot land.
        await tester.drag(find.byType(ListView), const Offset(0, 150));
        await tester.pumpAndSettle();
        // The done-action submits: onSubmitted drives the real _applyPromo.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(
          find.text('WELCOME20 applied'),
          findsOneWidget,
          reason: 'the SERVER message is what the customer sees',
        );
        expect(
          find.text(moneyCents(4800, currencyCode: 'USD')),
          findsOneWidget,
          reason: 'preview total = subtotal - discount + tip + delivery fee',
        );
      },
    );

    testWidgets(
      'invalid promo zeroes a previously applied discount (never stale) and '
      'shows the server message',
      (tester) async {
        final service = _ScriptedCheckoutService();
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();

        // First apply a VALID promo, then re-validate an expired code: this
        // proves the reset path instead of the was-already-zero trivial one.
        service.promoResult = const PromoCodeResult(
          isValid: true,
          discountCents: 500,
        );
        await tester.dragUntilVisible(
          find.byType(TextField),
          find.byType(ListView),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        // Nudge back: dragUntilVisible can leave the row half-behind the app
        // bar, where taps cannot land.
        await tester.drag(find.byType(ListView), const Offset(0, 150));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'WELCOME20');
        // The done-action submits: onSubmitted drives the real _applyPromo.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(
          find.text(moneyCents(4800, currencyCode: 'USD')),
          findsOneWidget,
        );

        service.promoResult = const PromoCodeResult(
          isValid: false,
          message: 'Expired code',
        );
        // Phase 1's snackbar is still on its 4s clock and ScaffoldMessenger
        // QUEUES the next snackbar behind it — wind the fake clock so it
        // dismisses fully before the second apply.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        // The field is already built from phase 1's scroll; dragUntilVisible
        // only has to keep it built. NO nudge here: the extra scroll can push
        // the row back out of the lazy ListView's built range.
        await tester.dragUntilVisible(
          find.byType(TextField),
          find.byType(ListView),
          const Offset(0, -150),
        );
        await tester.pumpAndSettle();
        // Phase 1's done-action dismissed the keyboard, so re-acquire the
        // input connection EXPLICITLY and let a frame process the focus
        // before submitting.
        await tester.showKeyboard(find.byType(TextField));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'EXPIRED1');
        await tester.pump();
        // The done-action submits: onSubmitted drives the real _applyPromo.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Expired code'), findsOneWidget);
        expect(
          find.text(moneyCents(5300, currencyCode: 'USD')),
          findsOneWidget,
          reason: 'an invalid promo must zero the discount the customer sees',
        );
      },
    );
  });

  group('CheckoutScreen - place-order gates (each gate in isolation)', () {
    testWidgets(
      'fraud screening denial blocks the charge before any money math',
      (tester) async {
        final service = _ScriptedCheckoutService()..screenResult = false;
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();

        expect(
          find.text('Too many recent transactions. Please contact support.'),
          findsOneWidget,
        );
        expect(
          service.capturedChargedCarts,
          isEmpty,
          reason: 'a denied payment must never reach the charge call',
        );
      },
    );

    testWidgets('panic switch paused blocks checkout', (tester) async {
      final service = _ScriptedCheckoutService()..acceptingResult = false;
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Place Order'));
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(
        find.text('Orders are temporarily paused. Please try again shortly.'),
        findsOneWidget,
      );
      expect(service.capturedChargedCarts, isEmpty);
    });

    testWidgets('cart validation failures surface the joined reasons', (
      tester,
    ) async {
      final service = _ScriptedCheckoutService()
        ..cartValidationResult = const CartValidationFailed([
          CartValidationFailure(
            itemId: 'm1',
            itemName: 'Pizza',
            reason: 'Pizza has been removed from the menu.',
          ),
        ]);
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Place Order'));
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Pizza has been removed from the menu.'),
        findsOneWidget,
      );
      expect(service.capturedChargedCarts, isEmpty);
    });

    testWidgets('missing delivery location blocks before any money math', (
      tester,
    ) async {
      final service = _ScriptedCheckoutService();
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Place Order'));
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please set your delivery location on the map first.'),
        findsOneWidget,
      );
      expect(
        service.capturedChargedCarts,
        isEmpty,
        reason: 'the location gate sits BEFORE calculateFinalTotal',
      );
    });

    testWidgets(
      'tax calculation failure is FAIL-CLOSED: logged + aborted, never a '
      'zero-tax charge',
      (tester) async {
        final logger = FakeLogger();
        final service = _ScriptedCheckoutService()
          ..invoiceThrow = FirebaseException(
            plugin: 'cloud_functions',
            code: 'failed-precondition',
            message: 'no tax rates configured',
          );
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: logger,
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        await _setDeliveryLocationViaPicker(tester);
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Tax could not be calculated. Check your connection and try again.',
          ),
          findsOneWidget,
        );
        expect(
          logger.loggedErrors,
          contains('checkout_tax_calculation_failed'),
          reason: 'Law 8: the abort is logged for the operator, not silent',
        );
        expect(service.capturedChargedCarts, isEmpty);
      },
    );

    testWidgets(
      'total below the service minimum is rejected with the localized '
      'minimum',
      (tester) async {
        final service = _ScriptedCheckoutService()
          ..invoiceResult = const InvoiceTotal(
            netCents: 30,
            taxCents: 0,
            discountCents: 0,
          );
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        await _setDeliveryLocationViaPicker(tester);
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            moneyCents(CheckoutService.minimumOrderCents, currencyCode: 'USD'),
          ),
          findsOneWidget,
        );
        expect(service.capturedChargedCarts, isEmpty);
      },
    );

    testWidgets('signed-out user cannot place an order', (tester) async {
      final service = _ScriptedCheckoutService();
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          userId: null,
        ),
      );
      await tester.pumpAndSettle();
      await _setDeliveryLocationViaPicker(tester);
      await tester.ensureVisible(find.text('Place Order'));
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('Please sign in to place an order.'), findsOneWidget);
      expect(service.capturedChargedCarts, isEmpty);
    });

    testWidgets('no branch selected blocks the submission', (tester) async {
      final service = _ScriptedCheckoutService();
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          branchId: null,
        ),
      );
      await tester.pumpAndSettle();
      await _setDeliveryLocationViaPicker(tester);
      await tester.ensureVisible(find.text('Place Order'));
      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a branch first.'), findsOneWidget);
      expect(service.capturedChargedCarts, isEmpty);
    });

    testWidgets(
      'unavailable branch (doc missing) blocks the submission - the REAL '
      'fetchBranch runs against Firestore',
      (tester) async {
        final service = _ScriptedCheckoutService();
        // branchId 'b1' is selected but NO branches/b1 doc exists.
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        await _setDeliveryLocationViaPicker(tester);
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();

        expect(find.text('Selected branch is unavailable.'), findsOneWidget);
        expect(service.capturedChargedCarts, isEmpty);
      },
    );
  });

  group('CheckoutScreen - offline resilience + idempotency (Law 9/15)', () {
    testWidgets(
      'charge failure queues the rules-legal offline payload and tells the '
      'customer the order will sync',
      (tester) async {
        final service = _ScriptedCheckoutService(firestore: fakeFirestore)
          ..paymentThrow = FirebaseException(
            plugin: 'cloud_functions',
            code: 'unavailable',
            message: 'network down',
          );
        final queue = RecordingSyncQueue();
        await _runChargeScenario(
          tester,
          service: service,
          logger: FakeLogger(),
          queue: queue,
          firestore: fakeFirestore,
        );

        expect(
          find.text(
            'Order saved offline. It will be submitted when you are back '
            'online.',
          ),
          findsOneWidget,
        );
        // Exactly ONE durable intent was queued for this order.
        expect(queue.events, hasLength(1));
        expect(queue.events.single, startsWith('enqueue:create:'));
        final payload = queue.enqueuedPayloads.single;
        expect(payload['id'], startsWith('ORD-'));
        // QUEUE-1 (W5.1(a)): the OFFLINE payload - not the UI object - is
        // enqueued, with its rules-legal status and offline markers.
        expect(payload['status'], 'pending');
        expect(payload['offlineQueued'], true);
        expect(payload['queuedAt'], isNotNull);
        expect(service.capturedChargedCarts, hasLength(1));
      },
    );

    testWidgets(
      'createOrder failure keeps the queued payload + session key (retry '
      'cannot double charge)',
      (tester) async {
        final service = _ScriptedCheckoutService(firestore: fakeFirestore)
          ..createOrderThrow = FirebaseException(
            plugin: 'cloud_functions',
            code: 'internal',
            message: 'boom',
          );
        final queue = RecordingSyncQueue();
        await _runChargeScenario(
          tester,
          service: service,
          logger: FakeLogger(),
          queue: queue,
          firestore: fakeFirestore,
        );

        expect(
          find.text('Order not confirmed. Retrying will not double charge.'),
          findsOneWidget,
        );
        // CRITICAL (Law 9): the queued intent is NOT removed - the retry path
        // reuses the SAME idempotency key / PaymentIntent.
        expect(queue.events.single, startsWith('enqueue:create:'));
        expect(queue.removedIds, isEmpty);
      },
    );

    testWidgets(
      'full success: queue cleared, confirmation shown, tracker opened with '
      'this order id, session key cleared',
      (tester) async {
        // Same Firestore the screen's service reads — fetchBranch('b1') must
        // find the seeded branch doc.
        final service = _ScriptedCheckoutService(firestore: fakeFirestore);
        final queue = RecordingSyncQueue();
        await _runChargeScenario(
          tester,
          service: service,
          logger: FakeLogger(),
          queue: queue,
          firestore: fakeFirestore,
        );

        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();

        expect(find.text('Payment successful!'), findsOneWidget);
        // The confirmed order removed its queued offline intent (T-4).
        expect(queue.removedIds, hasLength(1));
        expect(queue.removedIds.single, startsWith('ORD-'));
        expect(
          queue.pendingPayloads,
          isEmpty,
          reason: 'a successfully written order must leave the queue empty',
        );
        // The delayed redirect lands on the order tracker with THIS order id.
        expect(find.textContaining('TRACKER-MARKER:ORD-'), findsOneWidget);
        // Law 9: success clears the idempotency session key.
        final sp = await SharedPreferences.getInstance();
        expect(sp.getKeys(), isNot(contains('checkout_session_id')));
        // Wind the fake clock past ConfettiOverlay's RAW cleanup timer
        // (duration 1500ms + 2000ms margin) — it is a bare dart:async timer,
        // not owned by any State, so the widget-tree teardown cannot cancel
        // it. Its repeating confetti ticker must also be gone before the
        // invariant check.
        await tester.pump(const Duration(milliseconds: 3600));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('tip chip selection is forwarded into the server-side total '
        'calculation', (tester) async {
      final service = _ScriptedCheckoutService();
      final queue = RecordingSyncQueue();
      await fakeFirestore.collection('branches').doc('b1').set({
        'name': 'Main Branch',
        'isActive': true,
      });
      await tester.pumpWidget(
        _buildHarness(
          service: service,
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: queue,
        ),
      );
      await tester.pumpAndSettle();

      // The selector renders because the config has tipEnabled: true; the
      // second option chip is the 10% option (index 0 = No Tip). The tip
      // selector lives in the always-built totals footer.
      //
      // UI-13 (p21 A2): the option surface is now the frozen library
      // `TipSelector` rendered inline in the totals footer (the hand-rolled
      // `TipSelectorWidget` file is deleted). The finder is scoped to the
      // selector subtree so the chip INDEX semantics — and this test's
      // behaviour assertion — are unchanged.
      expect(find.byType(TipSelector<int>), findsOneWidget);
      final chips = find.descendant(
        of: find.byType(TipSelector<int>),
        matching: find.byType(BrandChip),
      );
      expect(chips, findsAtLeastNWidgets(2));
      // L28 label parity: the pre-adoption option label composition
      // (`tipOptionLabel(pct, moneyCents(...))`) is unchanged — 10% of the
      // 5000-cent subtotal renders as `10% ($5.00)` before the tap.
      expect(find.text('10% (\$5.00)'), findsOneWidget);
      await tester.tap(chips.at(1));
      await tester.pumpAndSettle();

      // NOW place the order with the tip selected: the picker runs first,
      // then the charge — the captured arguments prove the forwarding.
      await _setDeliveryLocationViaPicker(tester);
      await tester.tap(find.text('Place Order'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        service.capturedTipCents,
        500,
        reason:
            '10% of the 5000-cent subtotal, integer math, forwarded '
            'verbatim to calculateFinalTotal',
      );
      expect(service.capturedDeliveryFeeCents, 300);
    });

    testWidgets('tip selector is hidden when the config disables tipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          service: _ScriptedCheckoutService(),
          cartRepository: _StubCartRepository(_oneItemCart),
          logger: FakeLogger(),
          syncQueue: RecordingSyncQueue(),
          config: const RestaurantConfigModel(
            currency: 'USD',
            deliveryFeeCents: 300,
            tipEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TipSelector<int>), findsNothing);
    });
  });

  group('CheckoutScreen - double-submit fence (P8 W3 concurrency)', () {
    testWidgets(
      'a double-tap during the pre-flight window starts exactly ONE money '
      'pipeline',
      (tester) async {
        final service = _ScriptedCheckoutService(firestore: fakeFirestore);
        final gate = Completer<void>();
        service.screenPaymentGate = gate;
        final queue = RecordingSyncQueue();
        await _runChargeScenario(
          tester,
          service: service,
          logger: FakeLogger(),
          queue: queue,
          firestore: fakeFirestore,
        );
        // _runChargeScenario performed the FIRST Place Order tap: the
        // pipeline is now suspended inside screenPayment (pre-flight). Under
        // the pre-fix code _isProcessing is still false here, so the second
        // tap sails past the guard and starts a SECOND pipeline — exactly
        // the window this test pins shut.
        await tester.tap(find.byType(BrandButton), warnIfMissed: false);
        await tester.pump();

        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          service.screenPaymentCalls,
          1,
          reason:
              'a second tap while the first pipeline is in pre-flight must '
              'be fenced, not served by a second pipeline',
        );
        expect(
          service.createOrderCalls,
          1,
          reason:
              'server idempotency dedupes the WRITE, but the client must '
              'never invoke the order callable twice from one purchase',
        );
        // Wind past ConfettiOverlay's raw cleanup timer (1500ms + margin),
        // then settle — same closing sequence as the full-success test.
        await tester.pump(const Duration(milliseconds: 3600));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a tax fail-closed abort RESETS the submit flag — the customer can '
      'retry (no stuck spinner)',
      (tester) async {
        final service = _ScriptedCheckoutService(firestore: fakeFirestore)
          ..invoiceThrow = Exception('tax unavailable');
        await tester.pumpWidget(
          _buildHarness(
            service: service,
            cartRepository: _StubCartRepository(_oneItemCart),
            logger: FakeLogger(),
            syncQueue: RecordingSyncQueue(),
          ),
        );
        await tester.pumpAndSettle();
        await _setDeliveryLocationViaPicker(tester);
        await tester.ensureVisible(find.text('Place Order'));
        await tester.tap(find.text('Place Order'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Tax could not be calculated. Check your connection and try '
            'again.',
          ),
          findsOneWidget,
          reason: 'the fail-closed tax abort must be user-visible',
        );
        // The fence reset is the behavior under test: the SAME tap target
        // must be re-armed — a second invocation must re-enter the pipeline
        // (the pre-P8 code reset only in the charge's finally, so an abort
        // HERE left the button dead... and worse, the old code never set the
        // flag here at all; the reset keeps the fence honest both ways).
        final submitButton = tester.widget<BrandButton>(
          find.byType(BrandButton),
        );
        expect(
          submitButton.isLoading,
          isFalse,
          reason: 'an aborted checkout must not leave the button spinning',
        );
        expect(
          submitButton.onPressed,
          isNotNull,
          reason:
              'the reset must RE-ARM the submit — a flag left true would '
              'leave onPressed null forever (the stuck-button class)',
        );
        // Drive the re-armed handler directly: proves the retry re-enters
        // the pipeline rather than hitting a stale guard.
        submitButton.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          service.screenPaymentCalls,
          2,
          reason: 'the retry must re-enter the money pipeline',
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'a cancelled payment sheet queues offline and KEEPS the idempotency '
      'key (cancel-after-intent cannot double charge)',
      (tester) async {
        final service = _ScriptedCheckoutService(firestore: fakeFirestore)
          ..paymentThrow = Exception('PaymentSheet canceled by the user');
        final queue = RecordingSyncQueue();
        await _runChargeScenario(
          tester,
          service: service,
          logger: FakeLogger(),
          queue: queue,
          firestore: fakeFirestore,
        );

        // The sheet-cancel surfaces like any charge failure: the durable
        // offline payload is queued and the customer is told it will sync.
        expect(
          find.text(
            'Order saved offline. It will be submitted when you are back '
            'online.',
          ),
          findsOneWidget,
        );
        expect(queue.events, hasLength(1));
        expect(queue.events.single, startsWith('enqueue:create:'));
        expect(
          queue.removedIds,
          isEmpty,
          reason: 'the queued intent must survive a cancel-after-intent',
        );
        // CRITICAL (Law 9): the PaymentIntent was created server-side; the
        // session key must STILL be present so the retry reuses the SAME
        // intent instead of creating a second chargeable one.
        final sp = await SharedPreferences.getInstance();
        expect(
          sp.getString('checkout_session_id'),
          isNotNull,
          reason:
              'cancel-after-intent must preserve the idempotency key so the '
              'retry reuses the created PaymentIntent',
        );
      },
    );
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
