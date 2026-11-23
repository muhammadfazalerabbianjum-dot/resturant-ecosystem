import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/network/chaos_firestore.dart';

/// PERF-1 (T-6) — ChaosFirestore proxy coverage. The chaos switch is made
/// DETERMINISTIC in tests: `failureRate: 1.0` always faults, `failureRate:
/// 0.0` never faults. Every proxy (doc / collection / batch / transaction)
/// is proven to pass through to the delegate when chaos is off and to fault
/// BEFORE the write when chaos is on.

void main() {
  tearDown(() {
    // The static switch is global — always restore the safe default.
    ChaosFirestore.enableChaosMode = false;
  });

  group('ChaosFirestore — passthrough (chaos disabled)', () {
    test('doc.set / update / delete reach the delegate', () async {
      final delegate = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(delegate);

      await chaos.doc('orders/o1').set({'total': 100});
      await chaos.doc('orders/o1').update({'paid': true});
      expect((await delegate.collection('orders').doc('o1').get()).data(), {
        'total': 100,
        'paid': true,
      });

      await chaos.doc('orders/o1').delete();
      expect(
        (await delegate.collection('orders').doc('o1').get()).exists,
        isFalse,
      );
    });

    test('doc id/path pass through', () {
      final chaos = ChaosFirestore(FakeFirebaseFirestore());
      final doc = chaos.doc('orders/o1');
      expect(doc.id, 'o1');
      expect(doc.path, 'orders/o1');
    });

    test('collection.add + nested doc pass through', () async {
      final delegate = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(delegate);

      final ref = await chaos.collection('orders').add({'total': 5});
      expect(ref.id, isNotEmpty);

      final nested = chaos.collection('orders').doc('o2');
      expect(nested.path, 'orders/o2');
      expect(chaos.collection('orders').id, 'orders');
      expect(chaos.collection('orders').path, 'orders');
    });

    test(
      'batch set/update/delete/commit reach the delegate (raw + chaos refs)',
      () async {
        final delegate = FakeFirebaseFirestore();
        final chaos = ChaosFirestore(delegate);
        final rawDoc = delegate.collection('orders').doc('raw');
        final chaosDoc = chaos.doc('orders/chaos');

        final batch = chaos.batch();
        batch.set<Map<String, dynamic>>(chaosDoc, {'a': 1});
        batch.set<Map<String, dynamic>>(rawDoc, {'b': 2});
        batch.update(chaosDoc, {'c': 3});
        batch.delete(rawDoc);
        await batch.commit();

        expect(
          (await delegate.collection('orders').doc('chaos').get()).data(),
          {'a': 1, 'c': 3},
        );
        expect(
          (await delegate.collection('orders').doc('raw').get()).exists,
          isFalse,
        );
      },
    );

    test(
      'runTransaction reaches the delegate (with timeout/maxAttempts)',
      () async {
        final delegate = FakeFirebaseFirestore();
        final chaos = ChaosFirestore(delegate);

        final result = await chaos.runTransaction<int>(
          (txn) async {
            txn.set(delegate.collection('orders').doc('tx'), {'ok': true});
            return 42;
          },
          timeout: const Duration(seconds: 5),
          maxAttempts: 3,
        );
        expect(result, 42);
        expect((await delegate.collection('orders').doc('tx').get()).data(), {
          'ok': true,
        });
      },
    );
  });

  group('ChaosFirestore — injected faults (chaos ON, failureRate 1.0)', () {
    test('doc.set faults BEFORE the write reaches the delegate', () async {
      final delegate = FakeFirebaseFirestore();
      ChaosFirestore.enableChaosMode = true;
      final chaos = ChaosFirestore(delegate, failureRate: 1.0);

      // _maybeThrow fires synchronously (non-async wrappers), so the fault
      // escapes the call site itself — the closure form captures it.
      expect(
        () => chaos.doc('orders/o1').set({'total': 100}),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'chaos-injected',
          ),
        ),
      );
      expect(
        (await delegate.collection('orders').doc('o1').get()).exists,
        isFalse,
        reason: 'the fault must precede the write — no partial data',
      );
    });

    test('collection.add and batch.commit fault too', () async {
      final delegate = FakeFirebaseFirestore();
      ChaosFirestore.enableChaosMode = true;
      final chaos = ChaosFirestore(delegate, failureRate: 1.0);

      expect(
        () => chaos.collection('orders').add({'x': 1}),
        throwsA(isA<FirebaseException>()),
      );
      expect(() => chaos.batch().commit(), throwsA(isA<FirebaseException>()));
      expect(
        () => chaos.doc('orders/o9').update({'x': 1}),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => chaos.doc('orders/o9').delete(),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        () => chaos.runTransaction<int>((txn) async => 1),
        throwsA(isA<FirebaseException>()),
        reason: 'the fault fires before the delegate transaction starts',
      );
    });

    test('failureRate 0.0 never faults even with chaos enabled', () async {
      final delegate = FakeFirebaseFirestore();
      ChaosFirestore.enableChaosMode = true;
      final chaos = ChaosFirestore(delegate, failureRate: 0.0);

      await chaos.doc('orders/safe').set({'ok': true});
      expect((await delegate.collection('orders').doc('safe').get()).data(), {
        'ok': true,
      });
    });
  });
}
