import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:core/core.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/orders/domain/order_number_service.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../../support/tenant_claim_fakes.dart';

/// Fake [FraudScreeningService] that returns a canned response.
class FakeFraudScreeningService extends FraudScreeningService {
  final bool _screenResult;
  FakeFraudScreeningService(this._screenResult);
  @override
  Future<bool> screenPayment() async => _screenResult;
}

/// Fake [PanicSwitchService] that returns a canned response.
class FakePanicSwitchService extends PanicSwitchService {
  final bool _accepting;
  FakePanicSwitchService(this._accepting)
    : super(
        firestore: FakeFirebaseFirestore(),
        tenantClaim: const FixedTenantClaim(),
      );
  @override
  Future<bool> isOrdersAccepting() async => _accepting;
}

/// Fake [CartValidatorService] that returns a canned response.
class FakeCartValidatorService extends CartValidatorService {
  final CartValidationResult _result;
  FakeCartValidatorService(this._result)
    : super(firestore: FakeFirebaseFirestore());
  @override
  Future<CartValidationResult> validate(
    List<Map<String, dynamic>> cartItems,
  ) async {
    return _result;
  }
}

/// Fake [OrderNumberService] that returns a canned response.
class FakeOrderNumberService extends OrderNumberService {
  final String _orderNumber;
  FakeOrderNumberService(this._orderNumber)
    : super(firestore: FakeFirebaseFirestore());
  @override
  Future<String> nextOrderNumber() async => _orderNumber;
}

CheckoutService _createService({
  required FakeFirebaseFirestore firestore,
  FirebaseFunctions? functions,
  FraudScreeningService? fraudSvc,
  PanicSwitchService? panicSvc,
  CartValidatorService? cartValidator,
  OrderNumberService? orderNumSvc,
}) {
  final logger = LoggerService(
    testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
  );
  final promoService = PromoCodeService(
    functions ?? FirebaseFunctions.instance,
    logger,
  );
  return CheckoutService(
    firestore: firestore,
    functions: functions ?? FirebaseFunctions.instance,
    logger: logger,
    promoService: promoService,
    fraudSvc: fraudSvc,
    panicSvc: panicSvc,
    cartValidator: cartValidator,
    orderNumSvc: orderNumSvc,
    tenantClaim: const FixedTenantClaim(),
  );
}

/// REC-B2-2 re-pin fixtures (p26 T-3): the attempt identity the checkout
/// screen passes on the production path (`checkout_screen.dart:378`) — the
/// attempt-scoped equivalent of what the former no-arg session-bookkeeping
/// pins called directly.
const String _kPinUserId = 'pin-user-1';
const CartModel _kPinCart = CartModel(
  items: [
    CartItemModel(item: MenuItemModel(id: 'pin-pizza', priceCents: 1200)),
  ],
);

void main() {
  // QUEUE-2: production now retries transient failures with REAL exponential
  // backoff (NetworkRetry). These fail-closed tests assert that errors still
  // RETHROW regardless of classification, so the delay is neutralized to keep
  // them fast and under the default per-test timeout. Retry semantics are
  // proven in test/core/network/retry_wrapping_test.dart.
  setUp(() {
    NetworkRetry.delay = (_) async {};
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('CheckoutService - generateToken', () {
    test('generates token of length 8', () {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      final token = service.generateToken();
      expect(token.length, 8);
    });

    test('generates token with only uppercase alphanumeric chars', () {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      final token = service.generateToken();
      expect(RegExp(r'^[A-Z0-9]{8}$').hasMatch(token), isTrue);
    });
  });

  group('CheckoutService - generateSessionOrderId', () {
    test('generates valid order ID format', () {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      final orderId = service.generateSessionOrderId('user123');
      expect(orderId, startsWith('ORD-'));
      expect(orderId.length, greaterThan(10));
    });
  });

  group('CheckoutService - calculateFinalTotal (B1 server-derived)', () {
    test('throws on Cloud Function failure (fail-closed, Law 8)', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      // No Cloud Function is available in test mode — the method MUST
      // rethrow (fail-closed) rather than silently returning $0 tax.
      await expectLater(
        service.calculateFinalTotal(1000),
        throwsA(isA<Object>()),
      );
    });

    test('handles zero subtotal', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      // Zero subtotal still requires the Cloud Function — it throws.
      await expectLater(service.calculateFinalTotal(0), throwsA(isA<Object>()));
    });

    test('does not go negative', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      // Even with a discounted subtotal, the Cloud Function is required.
      await expectLater(
        service.calculateFinalTotal(100, promoCode: 'SAVE5'),
        throwsA(isA<Object>()),
      );
    });
  });

  group('CheckoutService - calculateTax', () {
    test('throws on Cloud Function failure (fail-closed, Law 8)', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      // No Cloud Function in test mode — must rethrow, never return 0.
      await expectLater(service.calculateTax(1000), throwsA(isA<Object>()));
    });
  });

  group('CheckoutService - isBelowMinimumOrderTotal', () {
    test('accepts totals at or above the minimum order value', () {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      expect(service.isBelowMinimumOrderTotal(0), isFalse);
      expect(service.isBelowMinimumOrderTotal(50), isFalse);
      expect(service.isBelowMinimumOrderTotal(500), isFalse);
      expect(service.isBelowMinimumOrderTotal(10000), isFalse);
    });

    test('rejects totals strictly between 1 and 49 cents', () {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      expect(service.isBelowMinimumOrderTotal(1), isTrue);
      expect(service.isBelowMinimumOrderTotal(25), isTrue);
      expect(service.isBelowMinimumOrderTotal(49), isTrue);
    });
  });

  group('CheckoutService - validatePromo (B1 server-authoritative)', () {
    test('delegates to PromoCodeService (applyPromo Cloud Function)', () async {
      final firestore = FakeFirebaseFirestore();
      // No deployable applyPromo callable in the test env — the delegate must
      // throw, and the facade must NOT fabricate a discount.
      final service = _createService(firestore: firestore);
      final result = await service.validatePromo('SAVE5', 2000);
      expect(result.isValid, false);
    });
  });

  group('CheckoutService - screenPayment', () {
    test('blocks payment when fraud screening fails', () async {
      final firestore = FakeFirebaseFirestore();
      final fraudSvc = FakeFraudScreeningService(false);
      final service = _createService(firestore: firestore, fraudSvc: fraudSvc);
      final allowed = await service.screenPayment();
      expect(allowed, false);
    });

    test('allows payment when fraud screening passes', () async {
      final firestore = FakeFirebaseFirestore();
      final fraudSvc = FakeFraudScreeningService(true);
      final service = _createService(firestore: firestore, fraudSvc: fraudSvc);
      final allowed = await service.screenPayment();
      expect(allowed, true);
    });
  });

  group('CheckoutService - isOrdersAccepting', () {
    test('blocks orders when panic switch is on', () async {
      final firestore = FakeFirebaseFirestore();
      final panicSvc = FakePanicSwitchService(false);
      final service = _createService(firestore: firestore, panicSvc: panicSvc);
      final accepting = await service.isOrdersAccepting();
      expect(accepting, false);
    });

    test('accepts orders when panic switch is off', () async {
      final firestore = FakeFirebaseFirestore();
      final panicSvc = FakePanicSwitchService(true);
      final service = _createService(firestore: firestore, panicSvc: panicSvc);
      final accepting = await service.isOrdersAccepting();
      expect(accepting, true);
    });
  });

  group('CheckoutService - validateCart', () {
    test('uses injected CartValidatorService', () async {
      final firestore = FakeFirebaseFirestore();
      final cartValidator = FakeCartValidatorService(
        const CartValidationSuccess(),
      );
      final service = _createService(
        firestore: firestore,
        cartValidator: cartValidator,
      );
      final result = await service.validateCart([
        {'id': 'test', 'name': 'Test Item', 'priceCents': 1000},
      ]);
      expect(result, isA<CartValidationSuccess>());
    });

    test('returns validation failures', () async {
      final firestore = FakeFirebaseFirestore();
      final failures = [
        const CartValidationFailure(
          itemId: '1',
          itemName: 'Item 1',
          reason: 'Price changed',
        ),
      ];
      final cartValidator = FakeCartValidatorService(
        CartValidationFailed(failures),
      );
      final service = _createService(
        firestore: firestore,
        cartValidator: cartValidator,
      );
      final result = await service.validateCart([
        {'id': '1', 'name': 'Item 1', 'priceCents': 1000},
      ]);
      expect(result, isA<CartValidationFailed>());
      if (result is CartValidationFailed) {
        expect(result.failures.length, 1);
      }
    });
  });

  group('CheckoutService - fetchBranch', () {
    test('returns branch document snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);

      await firestore.collection('branches').doc('branch1').set({
        'name': 'Test Branch',
        'isActive': true,
      });

      final doc = await service.fetchBranch('branch1');
      expect(doc.exists, true);
      expect(doc.data(), containsPair('name', 'Test Branch'));
    });

    test('returns non-existent document for invalid branch', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);
      final doc = await service.fetchBranch('nonexistent');
      expect(doc.exists, false);
    });
  });

  group('CheckoutService - nextOrderNumber', () {
    test('returns order number from service', () async {
      final firestore = FakeFirebaseFirestore();
      final orderNumSvc = FakeOrderNumberService('#0042');
      final service = _createService(
        firestore: firestore,
        orderNumSvc: orderNumSvc,
      );
      final orderNumber = await service.nextOrderNumber();
      expect(orderNumber, '#0042');
    });
  });

  group('T1 - computeChargedTotal exact-cents money matrix (Law 3)', () {
    test('modifiers + tax + tip + promo + delivery totals exactly', () {
      // subtotal(1250) + tax(80) - discount(100) + tip(150) + delivery(299)
      expect(
        CheckoutService.computeChargedTotal(
          subtotalCents: 1250,
          taxCents: 80,
          discountCents: 100,
          tipCents: 150,
          deliveryFeeCents: 299,
        ),
        equals(1679),
      );
    });

    test('a promo that exceeds subtotal+tax clamps the total to 0', () {
      expect(
        CheckoutService.computeChargedTotal(
          subtotalCents: 100,
          taxCents: 10,
          discountCents: 500,
        ),
        equals(0),
      );
    });

    test('zero subtotal with tip/delivery still charges only extras', () {
      expect(
        CheckoutService.computeChargedTotal(
          subtotalCents: 0,
          taxCents: 0,
          discountCents: 0,
          tipCents: 300,
          deliveryFeeCents: 299,
        ),
        equals(599),
      );
    });

    test('exact one-dollar math across a histogram of prices', () {
      for (final entry in <(int, int, int, int, int, int)>[
        (100, 0, 0, 0, 0, 100),
        (199, 1, 0, 0, 0, 200),
        (9999, 899, 500, 100, 200, 10698),
        (50, 0, 0, 0, 0, 50),
        (100000, 7000, 20000, 5000, 999, 92999),
      ]) {
        expect(
          CheckoutService.computeChargedTotal(
            subtotalCents: entry.$1,
            taxCents: entry.$2,
            discountCents: entry.$3,
            tipCents: entry.$4,
            deliveryFeeCents: entry.$5,
          ),
          equals(entry.$6),
          reason:
              'computeChargedTotal(${entry.$1}, ${entry.$2}, ${entry.$3}, ${entry.$4}, ${entry.$5})',
        );
      }
    });
  });

  group('CheckoutService - idempotency key (T2, Law 9)', () {
    test('getOrCreateSessionId returns the SAME key on repeat calls', () async {
      SharedPreferences.setMockInitialValues({});
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);

      // REC-B2-2 re-pin (p26 T-3): formerly the no-arg session-bookkeeping
      // call; the SAME intent through the attempt-scoped API — a retry of the
      // same attempt (same cart, same user, same session) reuses ONE key, so
      // Stripe and the server's dedupe see a single chargeable attempt.
      final first = await service.getOrCreateSessionId(
        cart: _kPinCart,
        userId: _kPinUserId,
      );
      final second = await service.getOrCreateSessionId(
        cart: _kPinCart,
        userId: _kPinUserId,
      );

      expect(first, isNotEmpty);
      expect(second, equals(first));
    });

    test('clearSessionId forces a NEW key (full checkout completes)', () async {
      SharedPreferences.setMockInitialValues({});
      final firestore = FakeFirebaseFirestore();
      final service = _createService(firestore: firestore);

      // REC-B2-2 re-pin (p26 T-3): retirement still rotates the key the
      // production path mints — same attempt identity, but the session slot
      // it composes from was retired by the completed checkout.
      final first = await service.getOrCreateSessionId(
        cart: _kPinCart,
        userId: _kPinUserId,
      );
      await service.clearSessionId();
      final afterClear = await service.getOrCreateSessionId(
        cart: _kPinCart,
        userId: _kPinUserId,
      );

      expect(afterClear, isNot(equals(first)));
    });

    test(
      'production-path call cannot mint a session-wide key (REC-B2-2)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = _createService(firestore: FakeFirebaseFirestore());

        final key = await service.getOrCreateSessionId(
          cart: _kPinCart,
          userId: _kPinUserId,
        );

        // The slot the BARE session id lives in (same storage literal the
        // order-scoped suite pins: checkout_order_scoped_idempotency_test
        // reads 'checkout_session_id').
        final prefs = await SharedPreferences.getInstance();
        final bareSessionId = prefs.getString('checkout_session_id');

        expect(
          bareSessionId,
          isNotNull,
          reason: 'the scoped mint persists the session slot it composes from',
        );
        expect(
          key,
          isNot(equals(bareSessionId)),
          reason:
              'R-B2-1 closed: the order path can never receive the bare '
              'session-wide id (private mint, required attempt identity)',
        );
        expect(
          key,
          equals(
            '$bareSessionId${CheckoutService.kAttemptKeySeparator}'
            '${CheckoutService.buildOrderAttemptFingerprint(userId: _kPinUserId, cart: _kPinCart)}',
          ),
          reason: 'the production mint IS the scoped composition, exactly',
        );
      },
    );

    test(
      'processStripePayment mints NO intent for a zero/negative total',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _createService(firestore: firestore);

        final intentId = await service.processStripePayment(
          finalTotal: 0,
          cart: const CartModel(),
          idempotencyKey: 'key_abc',
        );

        expect(intentId, isNull);
      },
    );
  });

  group('T11 - empty-key honesty: never fake a paid order', () {
    test(
      'processStripePayment FAILS CLOSED on payment error (rethrows)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _createService(firestore: firestore);

        // In the test environment there is no deployable Cloud Function /
        // no Stripe publishable key. The method MUST throw — it must NEVER
        // return a fake paymentIntentId that would let the UI show "Paid".
        await expectLater(
          service.processStripePayment(
            finalTotal: 1000,
            cart: const CartModel(),
            idempotencyKey: 'key_abc',
          ),
          throwsA(isA<Object>()),
        );
      },
    );

    test(
      'createOrder rethrows on failure and never fabricates an order id',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _createService(firestore: firestore);

        final order = OrderModel(
          id: 'ORD-1-ABC12345',
          customerId: 'user1',
          status: OrderStatus.confirmed,
          totalCents: 1000,
          createdAt: DateTime.now(),
        );

        await expectLater(
          service.createOrder(
            paymentIntentId: 'pi_fake',
            order: order,
            userId: 'user1',
            idempotencyKey: 'key_abc',
          ),
          throwsA(isA<Object>()),
        );
      },
    );
  });

  group('P8(W3) - demo mode can never bypass the money path', () {
    test('demo-mode branching does not exist inside checkout sources '
        '(tax/charge fail-closed is unconditional)', () {
      // The fail-closed tax/charge chain (calculateFinalTotal ->
      // calculateTax callable -> rethrow) is only honest if NO demo-mode
      // shortcut can route around it. A `kDemoMode` reference inside
      // features/checkout would mean a demo config could skip the
      // server-derived invoice — this scan pins the absence.
      final checkoutDir = Directory('lib/features/checkout');
      expect(
        checkoutDir.existsSync(),
        isTrue,
        reason: 'the scan must actually read the checkout sources',
      );
      final offenders = <String>[];
      for (final entity in checkoutDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('kDemoMode')) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'demo-mode branching inside checkout would let a demo config '
            'bypass the fail-closed tax/charge path',
      );
    });
  });
}
