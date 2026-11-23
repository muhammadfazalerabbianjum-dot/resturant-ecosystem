import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/network/chaos_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('ChaosFirestore', () {
    test('ChaosFirestore class exists', () {
      expect(ChaosFirestore, isA<Type>());
    });

    test('ChaosFirestore is constructable with FirebaseFirestore', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake);
      expect(chaos, isA<ChaosFirestore>());
    });

    test('ChaosFirestore has doc method', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake);
      final doc = chaos.doc('test/path');
      expect(doc, isA<ChaosDocumentRef>());
    });

    test('ChaosFirestore has collection method', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake);
      final coll = chaos.collection('test');
      expect(coll, isA<ChaosCollectionRef>());
    });

    test('ChaosFirestore has batch method', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake);
      final batch = chaos.batch();
      expect(batch, isA<ChaosBatch>());
    });

    test('ChaosFirestore default failureRate is 0.1', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake);
      expect(chaos.failureRate, 0.1);
    });

    test('ChaosFirestore accepts custom failureRate', () async {
      final fake = FakeFirebaseFirestore();
      final chaos = ChaosFirestore(fake, failureRate: 0.5);
      expect(chaos.failureRate, 0.5);
    });
  });
}
