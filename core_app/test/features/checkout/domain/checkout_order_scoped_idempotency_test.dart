import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/features/menu/domain/menu_modifier_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/tenant_claim_fakes.dart';

/// MONEY-4 (`AUD1-01`) — the checkout idempotency key is scoped to **ONE ORDER
/// ATTEMPT**, never to the session.
///
/// Invariant under test (FIX_b2_money_idempotency.md §3):
/// * a retry of the SAME attempt (same cart, same session) reuses the SAME key
///   → Stripe returns the existing PaymentIntent, the server returns the
///   existing order → no double charge, no duplicate order (T-3);
/// * a DIFFERENT cart in the same session gets a DIFFERENT key → the server's
///   `where('idempotencyKey','==',key)` dedupe can never resolve it to another
///   order's id (T-2, T-5);
/// * a FULLY successful checkout retires the key → the next attempt mints a
///   fresh one (T-4);
/// * when the attempt identity cannot be derived the mint FAILS CLOSED — it
///   never falls back to a session-wide/shared key (T-6).
///
/// The money server below is a faithful stand-in for the two callables the key
/// travels through, so the defect is reproduced end-to-end at the service
/// boundary instead of being asserted on local strings.
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

const String kUid = 'user-1';

/// Cart A — one pizza.
const CartModel kCartA = CartModel(
  items: [CartItemModel(item: MenuItemModel(id: 'pizza', priceCents: 1200))],
);

/// Cart B — a DIFFERENT order (two burgers) placed in the same session.
const CartModel kCartB = CartModel(
  items: [
    CartItemModel(
      item: MenuItemModel(id: 'burger', priceCents: 900),
      quantity: 2,
    ),
  ],
);

/// A two-line purchase WITH a paid modifier — the fingerprint must track *what
/// is being bought* (item + quantity + chosen options), not just item ids.
const CartItemModel kPizzaWithExtraCheese = CartItemModel(
  item: MenuItemModel(id: 'pizza', priceCents: 1200),
  selectedOptions: [
    ModifierOption(
      id: 'extra-cheese',
      name: 'Extra cheese',
      upchargeCents: 150,
    ),
  ],
);

const CartItemModel kFries = CartItemModel(
  item: MenuItemModel(id: 'fries', priceCents: 400),
);

const CartModel kPurchase = CartModel(items: [kPizzaWithExtraCheese, kFries]);

/// The SAME purchase with the cart lines in the opposite order — line order is
/// not part of the attempt identity (the customer is buying the same thing).
const CartModel kPurchaseReordered = CartModel(
  items: [kFries, kPizzaWithExtraCheese],
);

/// The same two dishes, no modifier — a materially DIFFERENT purchase.
const CartModel kPurchaseWithoutOption = CartModel(
  items: [
    CartItemModel(item: MenuItemModel(id: 'pizza', priceCents: 1200)),
    kFries,
  ],
);

/// Canonical item/qty/option signature — the server-side view of an order's
/// content. Accepts the submitted payload's `items` in either of the two
/// shapes that cross the callable boundary (serialized maps, or the model
/// objects `OrderModel.toJson()` emits for `items`).
String submittedContentSignature(List<dynamic> items) => _signatureOfRows(
  items.map((dynamic raw) {
    if (raw is CartItemModel) {
      return _row(
        raw.item.id,
        raw.quantity,
        raw.selectedOptions.map((o) => o.id).toList(),
      );
    }
    final item = raw as Map<String, dynamic>;
    final menu = item['item'] as Map<String, dynamic>;
    return _row(
      menu['id'] as String,
      item['quantity'] as int,
      ((item['selectedOptions'] as List<dynamic>?) ?? const [])
          .map((dynamic o) => (o as Map<String, dynamic>)['id'] as String)
          .toList(),
    );
  }),
);

/// The client's own view of what the attempt is buying.
String cartContentSignature(CartModel cart) => _signatureOfRows(
  cart.items.map(
    (i) => _row(
      i.item.id,
      i.quantity,
      i.selectedOptions.map((o) => o.id).toList(),
    ),
  ),
);

({String id, int qty, List<String> options}) _row(
  String id,
  int qty,
  List<String> options,
) {
  options.sort();
  return (id: id, qty: qty, options: options);
}

String _signatureOfRows(
  Iterable<({String id, int qty, List<String> options})> rows,
) {
  final encoded =
      rows.map((r) => '${r.id}x${r.qty}[${r.options.join(',')}]').toList()
        ..sort();
  return encoded.join('|');
}

/// The money server the attempt key travels through.
///
/// * `createPaymentIntent` reproduces Stripe's `idempotency_key` semantics —
///   the SAME key returns the SAME PaymentIntent and amount (never a second
///   chargeable intent);
/// * `createOrder` mirrors `core_app/functions/src/index.ts:1100-1108`:
///   `where('idempotencyKey','==',key).limit(1)` → the FIRST order id wins and
///   is returned with `idempotent: true`.
class FakeMoneyServer {
  FakeMoneyServer() {
    when(
      () => functions.httpsCallable('createPaymentIntent'),
    ).thenReturn(_intentCall);
    when(() => functions.httpsCallable('createOrder')).thenReturn(_orderCall);
    when(() => _intentCall.call(any())).thenAnswer(_onCreatePaymentIntent);
    when(() => _orderCall.call(any())).thenAnswer(_onCreateOrder);
  }

  final MockFirebaseFunctions functions = MockFirebaseFunctions();
  final MockHttpsCallable _intentCall = MockHttpsCallable();
  final MockHttpsCallable _orderCall = MockHttpsCallable();

  /// Order doc ids written, in write order.
  final List<String> orderIdsWritten = <String>[];

  /// The server's dedupe index: `orders` doc id by `idempotencyKey`.
  final Map<String, String> orderIdByKey = <String, String>{};

  /// The content the FIRST order under this key carried (the server's view).
  final Map<String, String> contentByKey = <String, String>{};

  /// Every key the client sent, in call order (retries included).
  final List<String> createOrderKeys = <String>[];

  /// Stripe: the PaymentIntent id per `idempotency_key`.
  final Map<String, String> paymentIntentByKey = <String, String>{};
  final Map<String, int> amountByKey = <String, int>{};
  final List<String> createPaymentIntentKeys = <String>[];

  /// Simulates "the order was committed server-side but the response never
  /// reached the client" — AUD1-01's `network loss after createOrder` row.
  /// The write happens on the first call; EVERY call then throws a transient
  /// error so the client exhausts [NetworkRetry] and observes a real failure.
  bool loseCreateOrderResponses = false;

  HttpsCallableResult<Map<String, dynamic>> _result(Map<String, dynamic> data) {
    final result = MockCallableResult<Map<String, dynamic>>();
    when(() => result.data).thenReturn(data);
    return result;
  }

  Future<HttpsCallableResult<Map<String, dynamic>>> _onCreatePaymentIntent(
    Invocation invocation,
  ) async {
    final data = invocation.positionalArguments.first as Map<String, dynamic>;
    final key = data['idempotencyKey'] as String;
    createPaymentIntentKeys.add(key);

    final existing = paymentIntentByKey[key];
    if (existing != null) {
      // Stripe idempotency: the SAME key returns the SAME intent + amount.
      return _result({
        'clientSecret': 'secret_$existing',
        'paymentIntentId': existing,
        'amountCents': amountByKey[key],
      });
    }

    final amountCents = (data['items'] as List<dynamic>).fold<int>(0, (
      sum,
      dynamic raw,
    ) {
      final item = raw as Map<String, dynamic>;
      return sum + (item['priceCents'] as int) * (item['quantity'] as int);
    });
    final intentId = 'pi_${paymentIntentByKey.length + 1}';
    paymentIntentByKey[key] = intentId;
    amountByKey[key] = amountCents;
    return _result({
      'clientSecret': 'secret_$intentId',
      'paymentIntentId': intentId,
      'amountCents': amountCents,
    });
  }

  Future<HttpsCallableResult<Map<String, dynamic>>> _onCreateOrder(
    Invocation invocation,
  ) async {
    final data = invocation.positionalArguments.first as Map<String, dynamic>;
    final key = data['idempotencyKey'] as String;
    final order = data['order'] as Map<String, dynamic>;
    createOrderKeys.add(key);

    final existing = orderIdByKey[key];
    final Map<String, dynamic> response;
    if (existing != null) {
      // index.ts:1100-1108 — dedupe by key, the FIRST order wins.
      response = {'orderId': existing, 'idempotent': true};
    } else {
      final orderId = order['id'] as String;
      orderIdByKey[key] = orderId;
      orderIdsWritten.add(orderId);
      contentByKey[key] = submittedContentSignature(
        order['items'] as List<dynamic>,
      );
      response = {'orderId': orderId, 'idempotent': false};
    }

    if (loseCreateOrderResponses) {
      // Transport-level failure: retryable, so the client burns its bounded
      // retries and finally surfaces the error — with the order already
      // written server-side (committed-but-unacked).
      throw Exception('connection closed before the response was read');
    }
    return _result(response);
  }
}

OrderModel orderFor(String id, CartModel cart) => OrderModel(
  id: id,
  customerId: kUid,
  totalCents: cart.totalCents,
  createdAt: DateTime.now(),
  items: cart.items,
);

CheckoutService createService(FirebaseFunctions functions) {
  final logger = LoggerService(
    testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
  );
  return CheckoutService(
    firestore: FakeFirebaseFirestore(),
    functions: functions,
    promoService: PromoCodeService(functions, logger),
    logger: logger,
    tenantClaim: const FixedTenantClaim(),
  );
}

// ---------------------------------------------------------------------------
// The call the checkout screen makes to mint the attempt key
// (`checkout_screen.dart:318`) — the cart being charged IS the attempt
// identity, which is what makes the key order-scoped instead of session-scoped.
// ---------------------------------------------------------------------------

/// Mints the idempotency key for [cart] the way the screen does.
Future<String> mintAttemptKey(CheckoutService service, CartModel cart) =>
    service.getOrCreateSessionId(cart: cart, userId: kUid);

/// Mints for a degenerate attempt whose identity cannot be derived (T-6).
Future<String> mintUnusableAttempt(
  CheckoutService service, {
  CartModel cart = const CartModel(items: []),
  String userId = kUid,
}) => service.getOrCreateSessionId(cart: cart, userId: userId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  // QUEUE-2: production retries transient failures with real exponential
  // backoff; these assertions are about the KEY, never the timing, so the
  // delay is neutralized (the same seam checkout_service_test.dart uses).
  setUp(() {
    NetworkRetry.delay = (_) async {};
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    NetworkRetry.delay = Future<void>.delayed;
  });

  group(
    'MONEY-4 (AUD1-01) — the idempotency key is scoped to ONE order attempt',
    () {
      test(
        'T-2 (CRITICAL) a DIFFERENT cart in the same session creates its OWN '
        'order — never cart A\'s id',
        () async {
          final server = FakeMoneyServer();
          final service = createService(server.functions);

          // Attempt A: cart A reaches the server and ORD-A is WRITTEN, but the
          // response never reaches the client — AUD1-01's "network loss after
          // createOrder / app killed" row. The client's bounded retries are
          // exhausted and it observes a real failure.
          server.loseCreateOrderResponses = true;
          final keyA = await mintAttemptKey(service, kCartA);
          await expectLater(
            service.createOrder(
              paymentIntentId: 'pi_A',
              order: orderFor('ORD-A', kCartA),
              userId: kUid,
              idempotencyKey: keyA,
            ),
            throwsA(isA<Object>()),
          );
          expect(
            server.orderIdsWritten,
            ['ORD-A'],
            reason: 'the order committed server-side; only the ack was lost',
          );
          // The transport recovers; the client never ran the success path.
          server.loseCreateOrderResponses = false;

          // The recovery path deliberately does NOT retire the key
          // (checkout_screen.dart:446 — "do NOT clear the session key here").
          // Now a DIFFERENT cart is checked out in the SAME session: MONEY-4
          // requires a NEW order — before the fix this resolved to ORD-A.
          final keyB = await mintAttemptKey(service, kCartB);
          final orderB = await service.createOrder(
            paymentIntentId: 'pi_B',
            order: orderFor('ORD-B', kCartB),
            userId: kUid,
            idempotencyKey: keyB,
          );

          expect(
            orderB['orderId'],
            'ORD-B',
            reason:
                'cart B must create its OWN order — never resolve to cart A\'s '
                'id (AUD1-01)',
          );
          expect(
            orderB['idempotent'],
            isFalse,
            reason: 'idempotent:true may only occur for a TRUE retry',
          );
          expect(
            keyB,
            isNot(equals(keyA)),
            reason: 'a different cart must mint a different attempt key',
          );
          expect(server.orderIdsWritten, ['ORD-A', 'ORD-B']);
        },
      );

      test('T-3 a genuine retry of the SAME attempt reuses the SAME key — no '
          'duplicate charge and no duplicate order', () async {
        final server = FakeMoneyServer();
        final service = createService(server.functions);

        final keyFirst = await mintAttemptKey(service, kCartA);
        final first = await service.createOrder(
          paymentIntentId: 'pi_1',
          order: orderFor('ORD-A', kCartA),
          userId: kUid,
          idempotencyKey: keyFirst,
        );
        expect(first['orderId'], 'ORD-A');
        expect(first['idempotent'], isFalse);

        // The retry after a createOrder failure: the SAME cart, the SAME
        // session — this is the behaviour the mechanism exists for.
        final keyRetry = await mintAttemptKey(service, kCartA);
        expect(
          keyRetry,
          equals(keyFirst),
          reason: 'a genuine retry must reuse the SAME key (no second intent)',
        );
        final retry = await service.createOrder(
          paymentIntentId: 'pi_1',
          order: orderFor('ORD-A', kCartA),
          userId: kUid,
          idempotencyKey: keyRetry,
        );
        expect(retry['orderId'], 'ORD-A');
        expect(retry['idempotent'], isTrue);
        expect(
          server.orderIdsWritten,
          ['ORD-A'],
          reason: 'a retry must never write a second order',
        );

        // The SAME key is what Stripe receives as `idempotency_key`, so the
        // retry re-presents the SAME PaymentIntent. (The Law-12 amount guard
        // throws before the sheet, keeping this a unit test — the intent id
        // and key are still asserted.)
        await expectLater(
          service.processStripePayment(
            finalTotal: kCartA.totalCents + 1,
            cart: kCartA,
            idempotencyKey: keyRetry,
            orderId: 'ORD-A',
          ),
          throwsA(isA<StateError>()),
        );
        expect(
          server.createPaymentIntentKeys,
          [keyFirst],
          reason: 'Stripe must get the SAME attempt key on retry',
        );
        expect(server.paymentIntentByKey, hasLength(1));
      });

      test(
        'T-4 a FULLY successful checkout retires the key — the next order mints '
        'a fresh one',
        () async {
          final server = FakeMoneyServer();
          final service = createService(server.functions);

          final key1 = await mintAttemptKey(service, kCartA);
          final first = await service.createOrder(
            paymentIntentId: 'pi_1',
            order: orderFor('ORD-A-1', kCartA),
            userId: kUid,
            idempotencyKey: key1,
          );
          expect(first['idempotent'], isFalse);

          // Full success → checkout_screen.dart:472 retires the key.
          await service.clearSessionId();

          // The customer re-orders the SAME cart: a new attempt, a new order.
          final key2 = await mintAttemptKey(service, kCartA);
          expect(
            key2,
            isNot(equals(key1)),
            reason:
                'a finished order\'s key must never leak into the next order',
          );
          final second = await service.createOrder(
            paymentIntentId: 'pi_2',
            order: orderFor('ORD-A-2', kCartA),
            userId: kUid,
            idempotencyKey: key2,
          );
          expect(second['orderId'], 'ORD-A-2');
          expect(
            second['idempotent'],
            isFalse,
            reason: 'a re-order after success is a NEW order, not a retry',
          );
          expect(server.orderIdsWritten, ['ORD-A-1', 'ORD-A-2']);
        },
      );

      test('T-5 the server can never match one attempt key to another cart\'s '
          'content', () async {
        final server = FakeMoneyServer();
        final service = createService(server.functions);

        final keyA = await mintAttemptKey(service, kCartA);
        await service.createOrder(
          paymentIntentId: 'pi_A',
          order: orderFor('ORD-A', kCartA),
          userId: kUid,
          idempotencyKey: keyA,
        );
        final keyB = await mintAttemptKey(service, kCartB);
        await service.createOrder(
          paymentIntentId: 'pi_B',
          order: orderFor('ORD-B', kCartB),
          userId: kUid,
          idempotencyKey: keyB,
        );

        // Each key is bound server-side to exactly the content it was charged
        // under — a key can never carry two different carts.
        expect(server.contentByKey[keyA], cartContentSignature(kCartA));
        expect(server.contentByKey[keyB], cartContentSignature(kCartB));
        expect(
          server.contentByKey[keyA],
          isNot(equals(server.contentByKey[keyB])),
        );
        expect(
          server.createOrderKeys.toSet(),
          hasLength(2),
          reason: 'two different carts must travel under two different keys',
        );
        expect(server.orderIdByKey[keyB], 'ORD-B');
        expect(server.orderIdByKey, hasLength(2));
      });

      test('T-6 FAIL-CLOSED: an attempt whose identity cannot be derived never '
          'falls back to a shared key', () async {
        final server = FakeMoneyServer();
        final service = createService(server.functions);

        // (a) an empty cart — there is no order attempt to scope a key to.
        await expectLater(
          mintUnusableAttempt(service, cart: const CartModel(items: [])),
          throwsA(isA<StateError>()),
        );
        // (b) no authenticated customer — the attempt cannot be attributed.
        await expectLater(
          mintUnusableAttempt(service, cart: kCartA, userId: ''),
          throwsA(isA<StateError>()),
        );

        // Nothing was charged or ordered, and no session-wide key was minted.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('checkout_session_id'),
          isNull,
          reason:
              'a refused attempt must not mint/return a session-wide key — '
              'the attempt must not be able to charge at all',
        );
        expect(server.createPaymentIntentKeys, isEmpty);
        expect(server.orderIdsWritten, isEmpty);
      });

      test(
        'T-1 the invariant is named in code: the key is scoped to the ATTEMPT, '
        'not to the session',
        () async {
          final server = FakeMoneyServer();
          final service = createService(server.functions);

          final key = await mintAttemptKey(service, kCartA);
          final prefs = await SharedPreferences.getInstance();
          final sessionId = prefs.getString('checkout_session_id');
          expect(sessionId, isNotNull);
          expect(
            key,
            isNot(equals(sessionId)),
            reason:
                'the key handed to Stripe/createOrder must carry the ATTEMPT '
                'identity, not merely the persisted session id',
          );
          // The session half stays persisted so a restart recomputes the key…
          expect(key, startsWith(sessionId!));
          // …and a different cart in the same session gets a different key.
          expect(await mintAttemptKey(service, kCartB), isNot(equals(key)));

          // The attempt half IS the content fingerprint: it names exactly what
          // this key is allowed to be spent on.
          final fingerprint = CheckoutService.buildOrderAttemptFingerprint(
            userId: kUid,
            cart: kCartA,
          );
          expect(key, endsWith(fingerprint));
          expect(
            key,
            equals(
              '$sessionId${CheckoutService.kAttemptKeySeparator}$fingerprint',
            ),
            reason: 'the key is <sessionId><separator><attempt fingerprint>',
          );

          // Content-addressed: deterministic, insensitive to cart line order,
          // sensitive to what is bought and to who is buying.
          const fingerprintOf = CheckoutService.buildOrderAttemptFingerprint;
          expect(
            fingerprintOf(userId: kUid, cart: kPurchase),
            equals(fingerprintOf(userId: kUid, cart: kPurchaseReordered)),
            reason: 'cart line order is not part of the purchase identity',
          );
          expect(
            fingerprintOf(userId: kUid, cart: kPurchase),
            isNot(
              equals(fingerprintOf(userId: kUid, cart: kPurchaseWithoutOption)),
            ),
            reason: 'a different dish/option set is a different purchase',
          );
          expect(
            fingerprintOf(userId: kUid, cart: kPurchase),
            isNot(equals(fingerprintOf(userId: 'user-2', cart: kPurchase))),
            reason:
                'an identical cart bought by another customer must never share '
                'the key (the server would return the other customer\'s order)',
          );
          expect(
            fingerprintOf(userId: kUid, cart: kCartB),
            isNot(equals(fingerprintOf(userId: kUid, cart: kCartA))),
          );
        },
      );

      test('T-1b an app restart reuses the SAME attempt key for the same cart — '
          'never a second chargeable intent', () async {
        final server = FakeMoneyServer();
        final keyBefore = await mintAttemptKey(
          createService(server.functions),
          kCartA,
        );

        // App killed and restarted: a NEW service over the SAME persisted
        // session, with the cart restored from local storage.
        final keyAfter = await mintAttemptKey(
          createService(server.functions),
          kCartA,
        );

        expect(
          keyAfter,
          equals(keyBefore),
          reason:
              'a retry after an app restart must reuse the SAME key so Stripe '
              'returns the existing PaymentIntent (no double charge)',
        );
      });
    },
  );
}
