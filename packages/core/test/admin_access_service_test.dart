import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';

import 'helpers/recording_logger.dart';

/// CORE-COV ADMIN module test: the email-authorization cascade (ownerInfo →
/// admins doc → users role) with a fail-closed behavior when Firestore is
/// unreachable, and the fail-closed PIN verdict when no PIN is configured.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  AdminAccessService service() => AdminAccessService(db);

  group('isEmailAuthorized — whitelist cascade', () {
    test(
      'settings/ownerInfo.ownerEmail authorizes (case + whitespace normalized)',
      () async {
        await db.collection('settings').doc('ownerInfo').set(<String, dynamic>{
          'ownerEmail': 'Owner@Example.COM',
        });

        expect(
          await service().isEmailAuthorized('  owner@example.com '),
          isTrue,
        );
      },
    );

    test('the admins collection authorizes by email doc id', () async {
      await db.collection('admins').doc('admin@example.com').set(
        <String, dynamic>{'role': 'admin'},
      );

      expect(await service().isEmailAuthorized('admin@example.com'), isTrue);
    });

    test('users with a staff role authorize via the role query', () async {
      await db.collection('users').add(<String, dynamic>{
        'email': 'staff@example.com',
        'role': 'manager',
      });

      expect(await service().isEmailAuthorized('staff@example.com'), isTrue);
    });

    test('a customer-only email is NOT authorized', () async {
      await db.collection('users').add(<String, dynamic>{
        'email': 'customer@example.com',
        'role': 'customer',
      });

      expect(
        await service().isEmailAuthorized('customer@example.com'),
        isFalse,
      );
    });

    test('unknown emails are NOT authorized', () async {
      expect(await service().isEmailAuthorized('ghost@example.com'), isFalse);
    });

    test('Firestore failure is FAIL-CLOSED (deny, never allow)', () async {
      final broken = _ThrowingFirestore();
      expect(
        await AdminAccessService(broken).isEmailAuthorized('a@b.com'),
        isFalse,
      );
    });
  });

  group('verifyPin — fail-closed without a configured PIN', () {
    test('no dev PIN (no dart-define) rejects every input', () async {
      final access = service();
      expect(await access.verifyPin('0000'), isFalse);
      expect(await access.verifyPin(''), isFalse);
    });
  });

  group('adminAccessProvider — DI resolution (PERF-1)', () {
    test('resolves from the container via the canonical Firestore client', () {
      // The provider reads FirestoreClient.instance.db — inject the mock so
      // the DI resolution runs without a Firebase app.
      FirestoreClient.setMock(
        FirestoreClient.testInject(db, ErrorLoggerService(null)),
      );
      final container = ProviderContainer(
        overrides: [loggerProvider.overrideWithValue(RecordingLogger())],
      );
      addTearDown(container.dispose);

      expect(container.read(adminAccessProvider), isA<AdminAccessService>());
    });
  });
}

class _ThrowingFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw StateError('unreachable');
  }
}
