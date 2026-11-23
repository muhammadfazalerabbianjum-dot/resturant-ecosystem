import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:labs/features/cart/data/cart_repository.dart';
import 'package:labs/features/cart/domain/cart_model.dart';
import 'package:labs/features/cart/presentation/cart_provider.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'package:labs/features/checkout/presentation/checkout_screen.dart';
import 'package:labs/features/menu/domain/menu_item_model.dart';
import 'package:labs/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../support/tenant_claim_fakes.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

/// UX-2 T-3 harness: a real [CheckoutService] subclass whose
/// [CheckoutService.nextOrderNumber] and [CheckoutService.validatePromo]
/// NEVER complete — simulating an in-flight charge / promo request so the
/// screen stays in the `_isProcessing` / `_promoApplying` state under test.
class _StalledCheckoutService extends CheckoutService {
  _StalledCheckoutService()
    : super(
        firestore: FakeFirebaseFirestore(),
        functions: _MockFirebaseFunctions(),
        promoService: PromoCodeService(
          _MockFirebaseFunctions(),
          LoggerService(),
        ),
        logger: LoggerService(),
        tenantClaim: const FixedTenantClaim(),
      );

  @override
  Future<InvoiceTotal> calculateFinalTotal(
    int subtotalCents, {
    String? promoCode,
    String? userId,
    int tipCents = 0,
    int deliveryFeeCents = 0,
  }) async {
    return InvoiceTotal(
      netCents: subtotalCents + tipCents + deliveryFeeCents,
      taxCents: 0,
      discountCents: 0,
      tipCents: tipCents,
      deliveryFeeCents: deliveryFeeCents,
    );
  }

  @override
  Future<String> nextOrderNumber() => Completer<String>().future;

  @override
  Future<PromoCodeResult> validatePromo(String code, int cartTotalCents) =>
      Completer<PromoCodeResult>().future;
}

class _StubCartRepository implements CartRepository {
  final CartModel cart;
  _StubCartRepository(this.cart);

  @override
  Future<CartModel> loadCart() async => cart;

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

Future<void> pumpCheckout(
  WidgetTester tester, {
  required CheckoutService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartRepositoryProvider.overrideWithValue(
          _StubCartRepository(_oneItemCart),
        ),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        currentUserIdProvider.overrideWithValue('test-uid'),
        checkoutServiceProvider.overrideWithValue(service),
        // D-038: the panic gate is now claim-required, so the screen's real
        // provider must resolve a tenant or it renders an error instead of the
        // checkout the test is about.
        tenantClaimProvider.overrideWithValue(const FixedTenantClaim()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // A host route so CheckoutScreen is PUSHED — an idle back press must
        // pop it (a root route cannot pop at all, which would make the
        // "pops normally" contract untestable).
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CheckoutScreen(),
                  ),
                ),
                child: const Text('go-to-checkout'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pushes the real CheckoutScreen (already inside the ProviderScope).
Future<void> openCheckout(WidgetTester tester) async {
  await tester.tap(find.text('go-to-checkout'));
  await tester.pumpAndSettle();
  expect(find.byType(CheckoutScreen), findsOneWidget);
}

Future<void> simulateBack(WidgetTester tester) async {
  // Canonical system-back simulation: WidgetsBinding.handlePopRoute mirrors
  // the platform pop route, honoring PopScope (canPop false →
  // onPopInvokedWithResult) and completing the route exit animation.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
  });

  group(
    'CheckoutScreen — T-3 PopScope back guard (UX-2 / 05-P1-UX-POPSCOPE)',
    () {
      testWidgets(
        'back press during an in-flight charge/promo does NOT pop and shows '
        'the in-flight dialog',
        (tester) async {
          await pumpCheckout(tester, service: _StalledCheckoutService());
          await openCheckout(tester);
          expect(find.byType(CheckoutScreen), findsOneWidget);

          // Drive the REAL promo path: a validation request that never
          // completes (validatePromo hangs) → the screen enters
          // _promoApplying, which PopScope must block on back.
          final promoField = find.byType(TextField);
          expect(promoField, findsOneWidget);
          await tester.ensureVisible(promoField);
          await tester.pumpAndSettle();
          await tester.enterText(promoField, 'WELCOME20');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          await simulateBack(tester);
          expect(
            find.byType(CheckoutScreen),
            findsOneWidget,
            reason: 'a request is in flight — the route must not pop',
          );
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.text('Please wait'),
            findsOneWidget,
            reason: 'the in-flight dialog is localized and visible',
          );

          // OK dismisses only the DIALOG — the route stays put.
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            find.byType(CheckoutScreen),
            findsOneWidget,
            reason: 'dismissing the dialog must not dismiss the checkout',
          );
        },
      );

      testWidgets(
        'back press while a promo application is in flight is blocked too',
        (tester) async {
          await pumpCheckout(tester, service: _StalledCheckoutService());
          await openCheckout(tester);

          // The promo field is the only TextField on the checkout screen.
          final promoField = find.byType(TextField);
          expect(promoField, findsOneWidget);
          await tester.ensureVisible(promoField);
          await tester.pumpAndSettle();
          await tester.enterText(promoField, 'WELCOME20');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          await simulateBack(tester);
          expect(
            find.byType(CheckoutScreen),
            findsOneWidget,
            reason: 'a promo request is in flight — back must not pop',
          );
          expect(find.byType(AlertDialog), findsOneWidget);
        },
      );

      testWidgets('back press while idle pops normally', (tester) async {
        await pumpCheckout(tester, service: _StalledCheckoutService());
        await openCheckout(tester);
        expect(find.byType(CheckoutScreen), findsOneWidget);

        await simulateBack(tester);
        expect(
          find.byType(CheckoutScreen),
          findsNothing,
          reason: 'nothing is in flight — back must work normally',
        );
      });
    },
  );
}
