import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/data/order_repository.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_helpers.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

/// PERF-2 S1 — REAL behavioral tests replacing the previous tautologies
/// ("class exists" / "can be referenced"): the repository's Firestore
/// mapping and the production `cancelOrder` callable contract are asserted
/// against real data flow.
///
/// HONEST RESIDUAL (batch addendum): the `handleError` log-and-rethrow seams
/// of `streamOrder`/`getUserOrders` resist a unit-host test — injecting a
/// stream error requires mocking `Query`/`DocumentReference`//
/// `CollectionReference`, which cloud_firestore 6.x declares SEALED (and the
/// gate set bans `// ignore:`). These paths run in production on real
/// Firestore stream failures; recorded, not hidden. The demo-mode branch of
/// `cancelOrder` is likewise unreachable in the default suite (`kDemoMode`
/// is a compile-time dart-define, default false).
void main() {
  late FakeLogger logger;

  setUp(() {
    logger = FakeLogger();
  });

  Map<String, dynamic> orderDoc({
    required String customerId,
    required String status,
    required int totalCents,
    required DateTime createdAt,
  }) => {
    'customerId': customerId,
    'status': status,
    'totalCents': totalCents,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  group('OrderRepository.streamOrder — real Firestore mapping', () {
    test(
      'a seeded order document maps to an OrderModel (Timestamp + status normalised)',
      () async {
        final fs = FakeFirebaseFirestore();
        await fs
            .collection('orders')
            .doc('o1')
            .set(
              orderDoc(
                customerId: 'c1',
                status: 'ready',
                totalCents: 1250,
                createdAt: DateTime(2026, 9, 1, 12),
              ),
            );
        final repo = OrderRepository(
          fs,
          logger,
          functions: MockFirebaseFunctions(),
        );

        final order = await repo.streamOrder('o1').first;

        expect(order, isNotNull);
        expect(order!.id, 'o1');
        expect(order.status, OrderStatus.ready);
        expect(order.totalCents, 1250);
        expect(order.customerId, 'c1');
        expect(order.createdAt, DateTime(2026, 9, 1, 12));
      },
    );

    test(
      'a missing order document streams null (never a cast crash)',
      () async {
        final repo = OrderRepository(
          FakeFirebaseFirestore(),
          logger,
          functions: MockFirebaseFunctions(),
        );

        expect(await repo.streamOrder('missing').first, isNull);
      },
    );
  });

  group('OrderRepository.getUserOrders — the customer order history query', () {
    test(
      'returns only the caller\'s orders, newest first (where + orderBy + limit)',
      () async {
        final fs = FakeFirebaseFirestore();
        await fs
            .collection('orders')
            .doc('old')
            .set(
              orderDoc(
                customerId: 'c1',
                status: 'delivered',
                totalCents: 1000,
                createdAt: DateTime(2026, 1, 1),
              ),
            );
        await fs
            .collection('orders')
            .doc('new')
            .set(
              orderDoc(
                customerId: 'c1',
                status: 'pending',
                totalCents: 2000,
                createdAt: DateTime(2026, 9, 10),
              ),
            );
        await fs
            .collection('orders')
            .doc('other')
            .set(
              orderDoc(
                customerId: 'c2',
                status: 'pending',
                totalCents: 3000,
                createdAt: DateTime(2026, 9, 11),
              ),
            );
        final repo = OrderRepository(
          fs,
          logger,
          functions: MockFirebaseFunctions(),
        );

        final orders = await repo.getUserOrders('c1').first;

        expect(orders.map((o) => o.id), <String>['new', 'old']);
        expect(orders.first.status, OrderStatus.pending);
      },
    );
  });

  group('OrderRepository.cancelOrder — the production callable contract', () {
    late MockFirebaseFunctions functions;
    late MockHttpsCallable callable;

    setUp(() {
      functions = MockFirebaseFunctions();
      callable = MockHttpsCallable();
      when(() => functions.httpsCallable('cancelOrder')).thenReturn(callable);
    });

    test(
      'calls the cancelOrder callable with the exact payload shape',
      () async {
        when(
          () => callable.call(any()),
        ).thenAnswer((_) async => MockHttpsCallableResult());
        final repo = OrderRepository(
          FakeFirebaseFirestore(),
          logger,
          functions: functions,
        );

        await repo.cancelOrder('order-1');

        verify(
          () => callable.call(<String, dynamic>{'orderId': 'order-1'}),
        ).called(1);
      },
    );

    test(
      'a permanent callable failure is logged with context and rethrown as a '
      'mapped exception — permanent errors burn no retry ladder',
      () async {
        when(() => callable.call(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'denied',
          ),
        );
        final repo = OrderRepository(
          FakeFirebaseFirestore(),
          logger,
          functions: functions,
        );

        await expectLater(
          repo.cancelOrder('order-1'),
          throwsA(isA<Exception>()),
        );
        verify(() => callable.call(any())).called(1);
        expect(
          logger.loggedErrors,
          contains('cancelOrder failed for orderId: order-1'),
        );
      },
    );
  });
}
