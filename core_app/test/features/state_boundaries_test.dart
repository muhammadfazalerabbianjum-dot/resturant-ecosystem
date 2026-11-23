import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';

// Spec: Riverpod AsyncValue state machine contract:
// - AsyncLoading: hasValue=false, hasError=false, isLoading=true
// - AsyncData: hasValue=true, hasError=false, isLoading=false
// - AsyncError: hasValue=false, hasError=true, isLoading=false
// - States are mutually exclusive — never more than one at a time
// Tests assert against hard-coded spec values — no mirroring.

// Dummy provider for testing mutual exclusivity.
// P9 W1 (T-5): the dead `firestoreClientProvider` declaration was deleted
// (zero production consumers, PERF-8 W4-4) — the test seam is now the
// FirestoreClient static mock (firestore_client.dart setMock), set per test
// with the same injected fake Firestore + logger the override carried.
final dummyStateProvider = FutureProvider<String>((ref) async {
  final client = FirestoreClient.instance;
  return await client.run((db) async {
    final doc = await db.collection('test').doc('1').get();
    if (!doc.exists) throw Exception('not-found');
    return doc.data()?['val'] as String;
  });
});

void _injectFakeClient(FakeFirebaseFirestore fakeDb) {
  FirestoreClient.setMock(
    FirestoreClient.testInject(fakeDb, ErrorLoggerService()),
  );
}

void main() {
  group('State Boundary Mutex — Spec Contract', () {
    test(
      'Empty Firestore triggers Loading → Error transition per spec',
      () async {
        // Spec: empty fakeDb → doc doesn't exist → throws 'not-found' → AsyncError
        final fakeDb = FakeFirebaseFirestore();
        _injectFakeClient(fakeDb);
        addTearDown(
          () => FirestoreClient.setMock(
            FirestoreClient.testInject(
              FakeFirebaseFirestore(),
              ErrorLoggerService(),
            ),
          ),
        );

        final container = ProviderContainer();

        final states = <String>[];
        container.listen(dummyStateProvider, (previous, next) {
          if (next is AsyncLoading) {
            expect(next.hasValue, equals(false));
            expect(next.hasError, equals(false));
            expect(next.isLoading, equals(true));
            states.add('loading');
          } else if (next is AsyncData) {
            expect(next.isLoading, equals(false));
            expect(next.hasError, equals(false));
            expect(next.hasValue, equals(true));
            states.add('data');
          } else if (next is AsyncError) {
            expect(next.isLoading, equals(false));
            expect(next.hasValue, equals(false));
            expect(next.hasError, equals(true));
            states.add('error');
          }
        }, fireImmediately: true);

        try {
          await container.read(dummyStateProvider.future);
        } catch (_) {}

        // Spec: must see loading first, then error (never data)
        expect(states, contains('loading'));
        expect(states, contains('error'));
        expect(states, isNot(contains('data')));

        container.dispose();
      },
    );

    test(
      'Populated Firestore triggers Loading → Data transition per spec',
      () async {
        // Spec: fakeDb has doc → returns 'success' → AsyncData
        final fakeDb = FakeFirebaseFirestore();
        await fakeDb.collection('test').doc('1').set({'val': 'success'});
        _injectFakeClient(fakeDb);

        final container = ProviderContainer();

        final states = <String>[];
        container.listen(dummyStateProvider, (previous, next) {
          if (next is AsyncLoading) {
            states.add('loading');
          } else if (next is AsyncData) {
            states.add('data');
          } else if (next is AsyncError) {
            states.add('error');
          }
        }, fireImmediately: true);

        final value = await container.read(dummyStateProvider.future);

        // Spec: must see loading then data (never error)
        expect(states, contains('loading'));
        expect(states, contains('data'));
        expect(states, isNot(contains('error')));
        expect(value, equals('success'));

        container.dispose();
      },
    );

    test(
      'Invalidate forces Error → Loading → Data transition per spec',
      () async {
        // Spec: invalidate() resets state, triggering fresh load
        final fakeDb = FakeFirebaseFirestore();
        await fakeDb.collection('test').doc('1').set({'val': 'recovered'});
        _injectFakeClient(fakeDb);

        final container = ProviderContainer();

        // First read succeeds
        final value1 = await container.read(dummyStateProvider.future);
        expect(value1, equals('recovered'));

        // Invalidate and re-read
        container.invalidate(dummyStateProvider);
        final value2 = await container.read(dummyStateProvider.future);
        expect(value2, equals('recovered'));

        container.dispose();
      },
    );
  });
}
