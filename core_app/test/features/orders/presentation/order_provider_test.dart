import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/data/order_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/orders/presentation/order_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_helpers.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

/// PERF-2 S1 — REAL container tests replacing the previous tautologies
/// ("provider is not null"): the composition root builds the REAL
/// OrderRepository from injected seams, and `userOrdersProvider` is proven
/// end-to-end against a fake Firestore through the REAL repository (the
/// signed-out empty contract and the customer-scoped, newest-first query).
void main() {
  group('orderRepositoryProvider — the real composition root', () {
    test(
      'builds an OrderRepository from the injected firestore/logger/functions',
      () {
        final container = ProviderContainer(
          overrides: [
            firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
            loggerProvider.overrideWithValue(FakeLogger()),
            functionsProvider.overrideWithValue(MockFirebaseFunctions()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(orderRepositoryProvider), isA<OrderRepository>());
      },
    );
  });

  group('userOrdersProvider — the signed-in order history stream', () {
    final mockUser = MockUser(uid: 'customer-1', email: 'c1@test.dev');

    test(
      'signed out → resolves to an honest empty history (never stuck loading)',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            orderRepositoryProvider.overrideWith(
              (ref) => OrderRepository(
                FakeFirebaseFirestore(),
                FakeLogger(),
                functions: MockFirebaseFunctions(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Let the auth stream settle FIRST: userOrdersProvider watches it, and
        // a null user must still COMPLETE the provider with an empty list —
        // the Order History tab shows its empty state instead of the eternal
        // skeleton the emulator run captured (screenshots 21).
        await container.read(authStateProvider.future);

        final orders = await container.read(userOrdersProvider.future);

        expect(orders, isEmpty);
        final state = container.read(userOrdersProvider);
        expect(
          state,
          isA<AsyncData<List<OrderModel>>>(),
          reason:
              'a signed-out user has no visible orders — the provider must '
              'settle on data (empty), never hang in loading or error',
        );
      },
    );

    test('signed in → only this customer\'s orders, newest first', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('orders').doc('old').set({
        'customerId': 'customer-1',
        'status': 'delivered',
        'totalCents': 1000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await fs.collection('orders').doc('new').set({
        'customerId': 'customer-1',
        'status': 'pending',
        'totalCents': 2000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
      });
      await fs.collection('orders').doc('other').set({
        'customerId': 'customer-2',
        'status': 'pending',
        'totalCents': 3000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 11)),
      });
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
          orderRepositoryProvider.overrideWith(
            (ref) => OrderRepository(
              fs,
              FakeLogger(),
              functions: MockFirebaseFunctions(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Settle the auth stream before reading the history provider — the
      // first evaluation must see the signed-in user, not the transient
      // loading state.
      await container.read(authStateProvider.future);

      final orders = await container.read(userOrdersProvider.future);

      expect(orders.map((o) => o.id), <String>['new', 'old']);
      expect(orders.first.totalCents, 2000);
      expect(orders.first.status, OrderStatus.pending);
    });
  });
}
