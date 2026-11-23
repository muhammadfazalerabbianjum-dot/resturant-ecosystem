import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/admin/domain/panic_switch_service.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  group('PanicSwitchService', () {
    late FakeFirebaseFirestore firestore;
    late PanicSwitchService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PanicSwitchService(
        firestore: firestore,
        tenantClaim: _FixedTenantClaim(),
      );
    });

    test('a tenant claim reads the tenant-keyed config document', () async {
      // D-038: the gate lives at settings/${tenantId}_restaurantConfig. The
      // unprefixed document is written with the OPEN value on purpose, so this
      // only passes if the claim actually decides which document is read.
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('settings').doc('restaurantConfig').set({
        'ordersAccepting': true,
      });
      await firestore
          .collection('settings')
          .doc('tenant_a_restaurantConfig')
          .set({'ordersAccepting': false});
      final service = PanicSwitchService(
        firestore: firestore,
        tenantClaim: _FixedTenantClaim(),
      );

      expect(await service.isOrdersAccepting(), isFalse);
    });

    test('isOrdersAccepting returns true by default', () async {
      final accepting = await service.isOrdersAccepting();
      expect(accepting, true);
    });

    test(
      'setOrdersAccepting false then isOrdersAccepting returns false',
      () async {
        await service.setOrdersAccepting(false);
        final accepting = await service.isOrdersAccepting();
        expect(accepting, false);
      },
    );

    test(
      'setOrdersAccepting true then isOrdersAccepting returns true',
      () async {
        await service.setOrdersAccepting(false);
        await service.setOrdersAccepting(true);
        final accepting = await service.isOrdersAccepting();
        expect(accepting, true);
      },
    );

    test('ordersAcceptingStream emits correct values', () async {
      // Set initial state
      await service.setOrdersAccepting(true);

      final stream = service.ordersAcceptingStream;
      final first = await stream.first;
      expect(first, true);
    });

    test('ordersAcceptingStream emits false after toggle', () async {
      await service.setOrdersAccepting(false);
      final stream = service.ordersAcceptingStream;
      final first = await stream.first;
      expect(first, false);
    });

    test('setOrdersAccepting stores panicUpdatedAt timestamp', () async {
      await service.setOrdersAccepting(false);
      final doc = await firestore
          .doc('settings/tenant_a_restaurantConfig')
          .get();
      expect(doc.data()?['ordersAccepting'], false);
      expect(doc.data()?['panicUpdatedAt'], isNotNull);
    });

    test(
      'isOrdersAccepting returns true when doc has no ordersAccepting field',
      () async {
        // Write a doc without the field
        await firestore.doc('settings/tenant_a_restaurantConfig').set({
          'otherField': 'value',
        });
        final accepting = await service.isOrdersAccepting();
        expect(accepting, true);
      },
    );

    test(
      'isOrdersAccepting returns false when explicitly set to false',
      () async {
        await firestore.doc('settings/tenant_a_restaurantConfig').set({
          'ordersAccepting': false,
        });
        final accepting = await service.isOrdersAccepting();
        expect(accepting, false);
      },
    );

    test('multiple toggles work correctly', () async {
      await service.setOrdersAccepting(false);
      expect(await service.isOrdersAccepting(), false);

      await service.setOrdersAccepting(true);
      expect(await service.isOrdersAccepting(), true);

      await service.setOrdersAccepting(false);
      expect(await service.isOrdersAccepting(), false);
    });
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
