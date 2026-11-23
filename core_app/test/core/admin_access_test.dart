@Tags(['needs-emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:core/core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('AdminAccessService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AdminAccessService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AdminAccessService(fakeFirestore);
    });

    test(
      'rejects PIN when no admin PIN is configured (empty dart-define)',
      () async {
        expect(await service.verifyPin('3049'), isFalse);
      },
    );

    test('rejects wrong or empty PIN', () async {
      expect(await service.verifyPin('0000'), isFalse);
      expect(await service.verifyPin(''), isFalse);
    });

    test(
      'isEmailAuthorized returns true for super admin (ownerEmail)',
      () async {
        await fakeFirestore.collection('settings').doc('ownerInfo').set({
          'ownerEmail': 'owner@carnama.com',
        });

        final result = await service.isEmailAuthorized('owner@carnama.com');
        expect(result, isTrue);
      },
    );

    test(
      'isEmailAuthorized no longer reads the legacy `email` field (01-P2-6c drift guard)',
      () async {
        await fakeFirestore.collection('settings').doc('ownerInfo').set({
          'email': 'owner@carnama.com',
        });

        final result = await service.isEmailAuthorized('owner@carnama.com');
        expect(
          result,
          isFalse,
          reason:
              'rules + v003 provision ownerEmail — reading `email` would '
              'authorize against a field the rules never consult',
        );
      },
    );

    test('isEmailAuthorized returns true for whitelisted admin', () async {
      await fakeFirestore.collection('users').doc('manager1_uid').set({
        'email': 'manager@carnama.com',
        'role': 'manager',
      });

      final result = await service.isEmailAuthorized('manager@carnama.com');
      expect(result, isTrue);
    });

    test('isEmailAuthorized returns false for unauthorized user', () async {
      final result = await service.isEmailAuthorized('random@user.com');
      expect(result, isFalse);
    });
  });
}
