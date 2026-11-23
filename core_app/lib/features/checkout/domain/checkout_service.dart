import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:labs/app/config/app_config.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:core/core.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/cart/domain/cart_validator_service.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/features/orders/domain/order_number_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Result type for order submission.
class OrderSubmissionResult {
  final bool success;
  final String? errorMessage;
  final String? paymentIntentId;
  final String? orderId;

  const OrderSubmissionResult({
    required this.success,
    this.errorMessage,
    this.paymentIntentId,
    this.orderId,
  });
}

/// FIX-B12 (REC-B2-1) - the server rejected this order because the
/// idempotency key belongs to a DIFFERENT order attempt: `createOrder` threw
/// `already-exists` with `details.code == 'IDEMPOTENCY_CONFLICT'`, so the
/// foreign orderId was never returned (fail-closed).
///
/// DISTINCT + NON-RETRYABLE: `already-exists` is permanent for
/// `NetworkRetry` (FIX-B5), so no client path retries it - the checkout
/// surfaces this typed failure instead of ever showing "order placed".
class IdempotencyConflictException implements Exception {
  const IdempotencyConflictException({required this.reason});

  /// The server's field-level reason: `customer_mismatch`,
  /// `payment_intent_mismatch` or `amount_mismatch`.
  final String reason;

  /// User-visible message - an abort, never a success.
  final String message =
      'This checkout attempt was already used. '
      'No duplicate order was placed - please start a new checkout.';

  @override
  String toString() => 'IdempotencyConflictException($reason): $message';
}

/// Encapsulates all business logic for the checkout flow.
///
/// Extracted from [CheckoutScreen] to enable unit testing.
/// All platform dependencies (FirebaseFirestore, FirebaseFunctions, Stripe)
/// are injected so they can be mocked in tests.
class CheckoutService {
  /// Pseudo state code used for checkout tax lookups. The server derives the
  /// rate from `settings/taxRates.clients[clientId].stateRates['DEFAULT']` or
  /// the configured per-client `defaultRate`; with neither configured the
  /// charge FAILS CLOSED (`failed-precondition`) — never a silent $0 tax.
  static const String kCheckoutStateCode = 'DEFAULT';

  static const _checkoutSessionKey = 'checkout_session_id';

  /// Separator between the session id and the attempt fingerprint inside the
  /// scoped key: `<sessionId>_<fingerprint>` (MONEY-4).
  static const String kAttemptKeySeparator = '_';

  /// MONEY-4 (`AUD1-01`) — **the idempotency key belongs to ONE ORDER
  /// ATTEMPT**, never to the session.
  ///
  /// The key minted by [getOrCreateSessionId] travels BOTH money paths: the
  /// `createPaymentIntent` Cloud Function forwards it as Stripe's
  /// `idempotency_key`, and `createOrder` is the server's order-dedupe key
  /// (`where('idempotencyKey','==',key)` → `functions/src/index.ts:1100-1108`).
  /// It is therefore scoped to the attempt:
  ///
  /// * a **retry** of the same attempt (same cart, same session — including
  ///   after an app kill) ⇒ the SAME key ⇒ Stripe returns the existing
  ///   PaymentIntent and the server returns the existing order: no double
  ///   charge, no duplicate order;
  /// * a **different cart/attempt** ⇒ a DIFFERENT key ⇒ the server can never
  ///   resolve the new order to another order's id;
  /// * a **fully successful** checkout retires the key ([clearSessionId]) ⇒ the
  ///   next attempt mints a fresh one;
  /// * an attempt whose identity cannot be derived ⇒ **FAIL CLOSED**
  ///   ([buildOrderAttemptFingerprint] throws) — never a session-wide/shared
  ///   key, never a charge under doubt.
  ///
  /// The persisted slot keeps the bare session id (the value `clearSessionId`
  /// retires); the scoped key is RECOMPUTED deterministically on every call,
  /// which is exactly what lets a retry after an app kill reuse the same key
  /// instead of minting a second chargeable intent.
  ///
  /// Shape: `<sessionId><kAttemptKeySeparator><fingerprint>`.
  ///
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final PromoCodeService _promoService;
  final LoggerService _logger;
  final FraudScreeningService _fraudSvc;
  final CartValidatorService _cartValidator;
  final PanicSwitchService _panicSvc;
  final OrderNumberService _orderNumSvc;

  CheckoutService({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required PromoCodeService promoService,
    required LoggerService logger,
    FraudScreeningService? fraudSvc,
    CartValidatorService? cartValidator,
    PanicSwitchService? panicSvc,
    OrderNumberService? orderNumSvc,
    // Required: the panic gate cannot name its document without a tenant, and
    // an optional claim here would silently fall back to a legacy path that
    // D-038 removed.
    required TenantClaimReader tenantClaim,
  }) : _firestore = firestore,
       _functions = functions,
       _promoService = promoService,
       _logger = logger,
       _fraudSvc = fraudSvc ?? FraudScreeningService(functions: functions),
       _cartValidator =
           cartValidator ?? CartValidatorService(firestore: firestore),
       _panicSvc =
           panicSvc ??
           // The panic gate reads `settings/${tenantId}_restaurantConfig`, so the
           // claim has to travel with the service that builds it (D-038).
           PanicSwitchService(firestore: firestore, tenantClaim: tenantClaim),
       _orderNumSvc = orderNumSvc ?? OrderNumberService(firestore: firestore);

  /// Generate a random 8-character token for order IDs.
  String generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ9876543210';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Generate a session order ID.
  String generateSessionOrderId(String? uid) {
    final token = generateToken();
    return 'ORD-${uid.hashCode.abs()}-$token';
  }

  /// Get or create the idempotency key for the checkout attempt.
  ///
  /// Pass the [cart] being charged and its [userId] to mint the key for THAT
  /// order attempt (MONEY-4): the result is stable while the same cart is
  /// retried and DIFFERENT for a different cart, so a new order can never be
  /// resolved to an earlier order's id by the server's key dedupe.
  ///
  /// REC-B2-2 (p26 T-3): the mint is ATTEMPT-SCOPED ONLY — both arguments are
  /// REQUIRED (a caller must state the attempt identity explicitly; the old
  /// no-arg call is now a compile error), and an identity that cannot derive a
  /// fingerprint FAILS CLOSED instead of minting a key. The bare session id
  /// lives in the private [_getOrCreateSessionId] below and is only ever
  /// composed here as `<sessionId><kAttemptKeySeparator><fingerprint>`.
  ///
  /// FAIL-CLOSED (T-6): when the attempt identity cannot be derived,
  /// [buildOrderAttemptFingerprint] throws and NO key is minted.
  Future<String> getOrCreateSessionId({
    required CartModel? cart,
    required String? userId,
  }) async {
    // Validate the attempt identity BEFORE persisting anything: a refused
    // attempt must leave no key behind (it must not be able to charge at all).
    final fingerprint = buildOrderAttemptFingerprint(
      userId: userId ?? '',
      cart: cart ?? const CartModel(),
    );

    final sessionId = await _getOrCreateSessionId();
    return '$sessionId$kAttemptKeySeparator$fingerprint';
  }

  /// Get or create the bare checkout session id — the slot [clearSessionId]
  /// retires after a fully successful checkout.
  ///
  /// Session bookkeeping only; NOT the order path: a bare session id carries
  /// no attempt identity, so handing one to an order caller would mint a
  /// session-wide/shared key (the charge-under-doubt case MONEY-4 forbids).
  /// Its only caller composes it as
  /// `<sessionId><kAttemptKeySeparator><fingerprint>` — never a bare return.
  Future<String> _getOrCreateSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_checkoutSessionKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final sessionId = const Uuid().v4();
    await prefs.setString(_checkoutSessionKey, sessionId);
    return sessionId;
  }

  /// The attempt fingerprint — a deterministic digest of **what this attempt is
  /// buying**: the customer plus the item/option/quantity multiset.
  ///
  /// Deliberately EXCLUDES money and fulfilment parameters (tip, delivery fee,
  /// promo code, address, branch): changing one of those mid-attempt must not
  /// rotate the key and orphan a PaymentIntent that may already be captured.
  /// Those dimensions stay guarded server-side by the Law-12 amount check, the
  /// PaymentIntent-metadata cross-check and the compensating refund.
  ///
  /// Cart line ORDER is not part of the identity; the customer, the items, the
  /// quantities and the chosen options are. The digest is SHA-256 (declared
  /// dependency `crypto`, already used by `packages/core`) so the key stays a
  /// bounded length whatever the cart size.
  ///
  /// FAIL-CLOSED (T-6): a missing customer or an empty line-item set cannot
  /// identify an attempt ⇒ [StateError], so the caller aborts without charging
  /// instead of charging under a session-wide/shared key.
  @visibleForTesting
  static String buildOrderAttemptFingerprint({
    required String userId,
    required CartModel cart,
  }) {
    final customer = userId.trim();
    if (customer.isEmpty) {
      throw StateError(
        'MONEY-4: refusing to mint an idempotency key for an unattributable '
        'checkout attempt (no user id) — an attempt must never share a key.',
      );
    }
    if (cart.items.isEmpty) {
      throw StateError(
        'MONEY-4: refusing to mint an idempotency key for an empty cart — '
        'there is no order attempt to scope the key to.',
      );
    }
    final rows = cart.items.map((i) {
      final options = i.selectedOptions.map((o) => o.id).toList()..sort();
      return '${i.item.id}x${i.quantity}[${options.join(',')}]';
    }).toList()..sort();
    final canonical = '$customer|${rows.join('|')}';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Clear the idempotency key after a FULLY successful checkout (retire the
  /// attempt). The scoped key is derived, so retiring the session id is what
  /// rotates it: the next attempt composes a different key (MONEY-4).
  Future<void> clearSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_checkoutSessionKey);
  }

  /// Validate a promo code — server-authoritative (applyPromo Cloud Function).
  Future<PromoCodeResult> validatePromo(String code, int cartTotalCents) {
    return _promoService.validate(code, cartTotalCents);
  }

  /// Screen payment for fraud.
  Future<bool> screenPayment() {
    return _fraudSvc.screenPayment();
  }

  /// Check if panic switch allows orders.
  Future<bool> isOrdersAccepting() {
    return _panicSvc.isOrdersAccepting();
  }

  /// Validate cart items against the current menu.
  Future<CartValidationResult> validateCart(
    List<Map<String, dynamic>> cartForValidation,
  ) {
    return _cartValidator.validate(cartForValidation);
  }

  /// Fetch branch document from Firestore.
  ///
  /// QUEUE-2 (P-2): the one-shot branch read is retried on transient
  /// failures (bounded, classified backoff). Permanent errors like a rules
  /// `permission-denied` rethrow immediately; fail-closed semantics of the
  /// caller are unchanged.
  Future<DocumentSnapshot> fetchBranch(String branchId) async {
    try {
      return await NetworkRetry.withExponentialBackoff(
        () => _firestore.collection('branches').doc(branchId).get(),
      );
    } catch (e, stack) {
      await _logger.error(
        e,
        'fetchBranch failed for branchId: $branchId',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Calculate the final total including tax, discount, tip, and delivery.
  ///
  /// THROWS on failure — the caller MUST abort checkout (fail-closed, Law 8).
  /// B1: tax comes from the `calculateTax` Cloud Function and the discount from
  /// the server-authoritative `applyPromo` Cloud Function — the client never
  /// SUPPLIES a discount value. [clientId] is forwarded so the server uses THIS
  /// client's tax rates (multi-app white-label).
  Future<InvoiceTotal> calculateFinalTotal(
    int subtotalCents, {
    String? promoCode,
    String? userId,
    int tipCents = 0,
    int deliveryFeeCents = 0,
  }) async {
    try {
      var discountCents = 0;
      if (promoCode != null && promoCode.trim().isNotEmpty) {
        final promoResult = await _promoService.validate(
          promoCode,
          subtotalCents,
        );
        if (!promoResult.isValid) {
          throw StateError(promoResult.message ?? 'Promo code rejected');
        }
        discountCents = promoResult.discountCents;
      }

      // QUEUE-2 (P-3): `calculateTax` is a pure read — transient failures
      // are retried with bounded classified backoff; on final failure this
      // method still throws (fail-closed, Law 8) exactly as before.
      final result = await NetworkRetry.withExponentialBackoff(
        () => _functions.httpsCallable('calculateTax').call({
          'subtotalCents': subtotalCents,
          'stateCode': kCheckoutStateCode,
          'clientId': CoreConfigHolder.instance.clientId,
        }),
      );
      final data = result.data as Map<String, dynamic>;
      final taxCents = (data['taxCents'] as num).toInt();
      final finalTotal = computeChargedTotal(
        subtotalCents: subtotalCents,
        taxCents: taxCents,
        discountCents: discountCents,
        tipCents: tipCents,
        deliveryFeeCents: deliveryFeeCents,
      );
      return InvoiceTotal(
        netCents: finalTotal,
        taxCents: taxCents,
        discountCents: discountCents,
      );
    } catch (e, stack) {
      await _logger.error(
        e,
        'CheckoutService_calculateFinalTotal',
        stack: stack,
      );
      rethrow; // FAIL-CLOSED — caller shows error, no silent $0 tax
    }
  }

  /// Pure integer-cents arithmetic for the charged total (Law 3: no floats).
  ///
  /// Has the final-presentation order: subtotal + tax − discount + tip +
  /// delivery. The result is clamped at 0 so a promo can never make the total
  /// negative. Extracted as a static so the full money matrix is unit-testable
  /// without a Cloud Function (exact integer cents, no rounding).
  @visibleForTesting
  static int computeChargedTotal({
    required int subtotalCents,
    required int taxCents,
    required int discountCents,
    int tipCents = 0,
    int deliveryFeeCents = 0,
  }) {
    final raw =
        subtotalCents + taxCents - discountCents + tipCents + deliveryFeeCents;
    if (raw < 0) return 0;
    return raw;
  }

  /// Calculate tax via the Cloud Function.
  /// Throws on failure — the caller MUST abort checkout (fail-closed, Law 8).
  Future<int> calculateTax(int subtotalCents) async {
    try {
      // QUEUE-2 (P-3): same classified backoff as [calculateFinalTotal];
      // final failure rethrows (fail-closed, never charge $0 tax).
      final result = await NetworkRetry.withExponentialBackoff(
        () => _functions.httpsCallable('calculateTax').call({
          'subtotalCents': subtotalCents,
          'stateCode': 'DEFAULT',
          'clientId': CoreConfigHolder.instance.clientId,
        }),
      );
      final data = result.data as Map<String, dynamic>;
      return (data['taxCents'] as num).toInt();
    } catch (e, stack) {
      await _logger.error(e, 'CheckoutService_calculateTax', stack: stack);
      rethrow; // FAIL-CLOSED
    }
  }

  /// Whether [finalTotal] is a valid order amount below the minimum spend.
  ///
  /// The minimum is shared as an integer-cents contract so the UI can build a
  /// currency-agnostic, localized rejection message — no app hardcodes a
  /// currency symbol (multi-app, Law 3).
  static const int minimumOrderCents = 50;

  bool isBelowMinimumOrderTotal(int finalTotal) =>
      finalTotal > 0 && finalTotal < minimumOrderCents;

  /// Create a Stripe Payment Intent and present the payment sheet.
  /// Returns the payment intent ID, or null on failure.
  ///
  /// The [idempotencyKey] is forwarded to the `createPaymentIntent` Cloud
  /// Function which passes it to Stripe's `idempotency_key` header. On retry
  /// with the SAME key, Stripe returns the existing intent — no double charge.
  /// Builds the flat line-item payload the `createPaymentIntent` Cloud
  /// Function expects.
  ///
  /// WHY NOT `cart.items.map((i) => i.toJson())`:
  /// `CartItemModel.toJson()` nests the menu item under `item:` (`{priceCents,
  /// name, ...}`), but the server recomputes the amount from the FLAT
  /// `priceCents` field. Sending the nested shape makes the server compute
  /// `amountCents = 0` → every PaymentIntent fails the positive-amount check.
  /// This shape mirrors exactly what the server reads.
  @visibleForTesting
  List<Map<String, dynamic>> buildStripeLineItems(CartModel cart) {
    return cart.items.map((i) {
      return {
        // MONEY-1: the `menus/{id}` doc id — the server re-prices every line
        // against it (createPaymentIntent menu cross-check) and fails closed
        // when a client price differs from the menu price + server upcharges.
        'id': i.item.id,
        'priceCents': i.item.priceCents,
        'quantity': i.quantity,
        'selectedOptions': i.selectedOptions
            .map(
              (o) => {
                'id': o.id,
                'name': o.name,
                'upchargeCents': o.upchargeCents,
              },
            )
            .toList(),
      };
    }).toList();
  }

  /// Present the Stripe payment sheet and return the SERVER-authoritative result.
  ///
  /// B1: the client only forwards the item subtotal line items + the promo
  /// CODE; the server derives tax/discount/currency and returns
  /// [StripePaymentResult]. The server-derived amount MUST equal the approved
  /// [finalTotal] (Law 12) — otherwise the charge is aborted before any sheet
  /// is presented (never charge a different amount than the customer approved).
  Future<StripePaymentResult?> processStripePayment({
    required int finalTotal,
    required CartModel cart,
    required String idempotencyKey,
    int tipCents = 0,
    int deliveryFeeCents = 0,
    String? promoCode,
    String? orderId,
  }) async {
    if (finalTotal <= 0) return null;

    try {
      // QUEUE-2 (P-3): the PaymentIntent creation is retried on transient
      // failures. Stripe-side idempotency (the `idempotencyKey` forwarded
      // below) makes a re-run after a committed-but-unacked attempt return
      // the SAME intent — no duplicate charge. The Law-12 amount guard
      // below still aborts on any server-amount mismatch.
      final response = await NetworkRetry.withExponentialBackoff(
        () => _functions.httpsCallable('createPaymentIntent').call({
          'items': buildStripeLineItems(cart),
          'idempotencyKey': idempotencyKey,
          'tipCents': tipCents,
          'deliveryFeeCents': deliveryFeeCents,
          'stateCode': kCheckoutStateCode,
          'clientId': CoreConfigHolder.instance.clientId,
          'code': (promoCode == null || promoCode.trim().isEmpty)
              ? null
              : promoCode.trim().toUpperCase(),
          'orderId': orderId ?? '',
        }),
      );
      final data = response.data as Map<String, dynamic>;
      final clientSecret = data['clientSecret'] as String;
      final paymentIntentId = data['paymentIntentId'] as String;
      final serverAmountCents = (data['amountCents'] as num?)?.toInt();
      final serverTaxCents = (data['taxCents'] as num?)?.toInt() ?? 0;
      final serverDiscountCents = (data['discountCents'] as num?)?.toInt() ?? 0;

      // Law-12 FAIL-CLOSED: never present a charge that differs from the total
      // the customer approved on screen.
      if (serverAmountCents == null || serverAmountCents != finalTotal) {
        throw StateError(
          'Server amount ($serverAmountCents) does not match the approved total ($finalTotal)',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: AppConfig.appName,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return StripePaymentResult(
        paymentIntentId: paymentIntentId,
        amountCents: serverAmountCents,
        taxCents: serverTaxCents,
        discountCents: serverDiscountCents,
      );
    } catch (e) {
      await _logger.error(e, 'CheckoutService_processStripePayment');
      rethrow;
    }
  }

  /// Create an order via Firebase Functions.
  ///
  /// The [idempotencyKey] is forwarded to the `createOrder` Cloud Function
  /// which checks for an existing order with the same key before writing —
  /// making retries idempotent (Law 9).
  Future<Map<String, dynamic>> createOrder({
    required String paymentIntentId,
    required OrderModel order,
    required String userId,
    required String idempotencyKey,
  }) async {
    try {
      // QUEUE-2 (P-3): the submission callable is retried on transient
      // failures. The `idempotencyKey` contract (Law 9 — the Cloud Function
      // checks for an existing order with the same key before writing) makes
      // a re-run after a committed-but-unacked attempt return the SAME
      // order — no duplicate order write, no double charge.
      final result = await NetworkRetry.withExponentialBackoff(
        () => _functions.httpsCallable('createOrder').call({
          'paymentIntentId': paymentIntentId,
          'order': order.toJson(),
          'userId': userId,
          'idempotencyKey': idempotencyKey,
        }),
      );
      return result.data as Map<String, dynamic>;
    } catch (e) {
      await _logger.error(e, 'CheckoutService_createOrder');
      // FIX-B12 (REC-B2-1): the server rejected this key because it belongs to
      // a DIFFERENT order attempt - map the marker error to a DISTINCT,
      // non-retryable failure (never a success map, never "order placed").
      if (e is FirebaseFunctionsException &&
          e.code == 'already-exists' &&
          e.details is Map &&
          (e.details as Map)['code'] == 'IDEMPOTENCY_CONFLICT') {
        throw IdempotencyConflictException(
          reason: (e.details as Map)['reason']?.toString() ?? 'unknown',
        );
      }
      rethrow;
    }
  }

  /// Get the next order number.
  Future<String> nextOrderNumber() async {
    return _orderNumSvc.nextOrderNumber();
  }
}

/// Riverpod provider for [CheckoutService].
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return CheckoutService(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
    logger: ref.watch(loggerProvider), // DI: never construct an inline logger
    promoService: PromoCodeService(
      ref.watch(functionsProvider),
      ref.watch(loggerProvider), // DI: never construct an inline logger
    ),
    tenantClaim: ref.watch(tenantClaimProvider),
  );
});

/// The server-authoritative Stripe charge result (B1).
///
/// [amountCents], [taxCents] and [discountCents] are RE-DERIVED server-side by
/// `createPaymentIntent` and are the ONLY values the client may store on the
/// order (belt-and-suspenders — `createOrder` re-verifies them against the
/// PaymentIntent metadata).
class StripePaymentResult {
  final String paymentIntentId;
  final int amountCents;
  final int taxCents;
  final int discountCents;

  const StripePaymentResult({
    required this.paymentIntentId,
    required this.amountCents,
    required this.taxCents,
    required this.discountCents,
  });
}

/// The server-derived invoice breakdown the checkout flow uses to
/// (a) display the final total, and (b) submit the SAME tax/discount line
/// items to `createOrder` so the stored order equals the charged amount
/// (Law 12 — never store an amount different from what was charged).
class InvoiceTotal {
  final int netCents;
  final int taxCents;
  final int discountCents;
  final int tipCents;
  final int deliveryFeeCents;

  const InvoiceTotal({
    required this.netCents,
    required this.taxCents,
    required this.discountCents,
    this.tipCents = 0,
    this.deliveryFeeCents = 0,
  });

  /// The total the Stripe PaymentIntent should charge.
  int get chargedCents => netCents;
}
