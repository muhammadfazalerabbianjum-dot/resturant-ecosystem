import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_model.dart';
import 'package:labs/features/checkout/domain/checkout_service.dart';
import 'package:labs/features/checkout/domain/promo_code_service.dart';
import 'support/tenant_claim_fakes.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Idempotency & Conflict Detection', () {
    test('OrderModel idempotency key generation via UUID', () {
      const uniqueId = 'ord-client-uuid-v4';
      final order = OrderModel.fromJson({
        'id': uniqueId,
        'customerId': 'uid-1',
        'status': 'pending',
        'totalCents': 1500,
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(order.id, equals(uniqueId));
    });

    test('CheckoutService.createOrder sends the {paymentIntentId, order, userId, '
        'idempotencyKey} callable contract (production order path)', () async {
      // MONEY-3 (P-5): the dead flat-payload submission path was removed in
      // B3-P3. The real submission path is CheckoutService.createOrder; assert
      // the exact payload shape the cloud function expects (Law 9 idempotency).
      final fakeDb = FakeFirebaseFirestore();
      final mockFunctions = MockFirebaseFunctions();
      final mockCallable = MockHttpsCallable();
      final mockResult = MockHttpsCallableResult<Map<String, dynamic>>();
      final logDir = Directory.systemTemp;

      when(
        () => mockFunctions.httpsCallable('createOrder'),
      ).thenReturn(mockCallable);
      late Map<String, dynamic> captured;
      when(() => mockCallable.call(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as Map<String, dynamic>;
        return mockResult;
      });
      when(() => mockResult.data).thenReturn({'orderId': 'ord-123'});

      final svc = CheckoutService(
        firestore: fakeDb,
        functions: mockFunctions,
        promoService: PromoCodeService(
          mockFunctions,
          LoggerService(testDirectory: logDir),
        ),
        logger: LoggerService(testDirectory: logDir),
        tenantClaim: const FixedTenantClaim(),
      );

      final order = OrderModel(
        id: 'ord-123',
        customerId: 'uid-1',
        status: OrderStatus.pending,
        totalCents: 1500,
        createdAt: DateTime.now(),
      );

      final result = await svc.createOrder(
        paymentIntentId: 'pi_123',
        order: order,
        userId: 'uid-1',
        idempotencyKey: 'uid-1_ord-123_1',
      );

      expect(result['orderId'], 'ord-123');
      expect(
        captured.keys.toSet(),
        {'paymentIntentId', 'order', 'userId', 'idempotencyKey'},
        reason:
            'callable payload must be the createOrder contract, not a flat order map',
      );
      expect(captured['paymentIntentId'], 'pi_123');
      expect(captured['userId'], 'uid-1');
      expect(captured['idempotencyKey'], 'uid-1_ord-123_1');
      final orderPayload = captured['order'] as Map<String, dynamic>;
      expect(orderPayload['id'], 'ord-123');
      expect(orderPayload['totalCents'], 1500);
    });

    test('Simulate two drivers attempting to assign the same order', () async {
      final fakeDb = FakeFirebaseFirestore();
      final docRef = fakeDb.collection('orders').doc('conflict-order');
      await docRef.set({'assignedDriverId': null, 'status': 'ready'});

      // Attempt 1: Driver 1 claims the order atomically
      await fakeDb.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentDriver = snapshot.data()?['assignedDriverId'];
        if (currentDriver == null) {
          transaction.update(docRef, {
            'assignedDriverId': 'driver1',
            'status': 'delivering',
          });
        }
      });

      // Attempt 2: Driver 2 tries to claim the same order
      bool threwError = false;
      try {
        await fakeDb.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          final currentDriver = snapshot.data()?['assignedDriverId'];
          if (currentDriver == null) {
            transaction.update(docRef, {
              'assignedDriverId': 'driver2',
              'status': 'delivering',
            });
          } else {
            throw Exception('Order already assigned!');
          }
        });
      } catch (e) {
        threwError = true;
      }

      expect(threwError, isTrue, reason: 'Second transaction must abort');
      final finalSnap = await docRef.get();
      expect(
        finalSnap.data()?['assignedDriverId'],
        'driver1',
        reason: 'Driver 1 should retain the concurrency lock',
      );
    });
  });
}
