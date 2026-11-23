import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/compliance/data_export_service.dart';
import '../../helpers/test_helpers.dart';
import '../../support/tenant_claim_fakes.dart';

/// UX-3 (W9.10): the export gained a server section (read-only `exportMyData`
/// callable) and a local-device section — these fakes inject them so the
/// tests exercise the FULL export contract without Firebase/Isar platforms.
class _FakeResult implements HttpsCallableResult<dynamic> {
  @override
  final dynamic data;
  _FakeResult(this.data);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([Object? data]) async =>
      _FakeResult({
            'sections': <String, dynamic>{
              'promoUsage': <dynamic>[],
              'reservationLocks': <dynamic>[],
              'notificationItems': <dynamic>[],
              'deliveries': <dynamic>[],
              'analyticsEvents': <dynamic>[],
              'fixedDocs': <String, dynamic>{},
            },
          })
          as HttpsCallableResult<T>;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctions implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Map<String, dynamic>> _fakeLocalSummary() async => {
  'isar': {
    'menuItems': 0,
    'carts': 0,
    'pendingOperations': 0,
    'deadLetters': 0,
  },
  'preferences': {'keys': <String>[]},
};

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeLogger fakeLogger;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeLogger = FakeLogger();
  });

  MockUser? signedOutAuth() => null;

  MockUser signedInAuth({String uid = 'user-123'}) => MockUser(uid: uid);

  group('DataExportService — GDPR Art.20 export', () {
    test('throws when the user is not signed in', () async {
      final service = DataExportService(
        firestore: fakeFirestore,
        currentUser: signedOutAuth,
        logger: fakeLogger,
        tenantClaim: const FixedTenantClaim(),
      );

      await expectLater(service.exportUserData(), throwsA(isA<Exception>()));
    });

    test(
      'collects the user profile and scoped collections for signed-in user',
      () async {
        const uid = 'user-123';
        await fakeFirestore.collection('users').doc(uid).set({
          'role': 'customer',
          'displayName': 'Ada',
        });
        await fakeFirestore.collection('orders').doc('o1').set({
          'tenantId': 'tenant_a',
          'customerId': uid,
          'totalCents': 1250,
        });
        // Another user's order must NOT leak into the export.
        await fakeFirestore.collection('orders').doc('o2').set({
          'tenantId': 'tenant_a',
          'customerId': 'user-other',
          'totalCents': 9999,
        });

        final service = DataExportService(
          firestore: fakeFirestore,
          currentUser: () => signedInAuth(uid: uid),
          logger: fakeLogger,
          tenantClaim: const FixedTenantClaim(),
          functions: _FakeFunctions(),
          localSummary: _fakeLocalSummary,
        );

        final json = await service.exportUserData();
        final data = jsonDecode(json) as Map<String, dynamic>;

        expect(data['userId'], uid);
        expect((data['userProfile'] as Map)['displayName'], 'Ada');
        final orders = (data['orders'] as List).cast<Map<String, dynamic>>();
        expect(orders, hasLength(1));
        expect(orders.single['totalCents'], 1250);
        // UX-3 (W9.10): the export now also carries the rules-gated server
        // section (read-only callable) and the local device summary.
        final serverExport = ((data['serverExport'] as Map)['sections'] as Map)
            .cast<String, dynamic>();
        expect(serverExport['promoUsage'], isEmpty);
        expect(serverExport['analyticsEvents'], isEmpty);
        final isar = (data['localData'] as Map)['isar'] as Map;
        expect(isar['menuItems'], 0);
      },
    );

    test('exports reservations keyed by userId (not customerId)', () async {
      const uid = 'user-9';
      await fakeFirestore.collection('reservations').add({
        'tenantId': 'tenant_a',
        'userId': uid,
        'status': 'confirmed',
      });

      final service = DataExportService(
        firestore: fakeFirestore,
        currentUser: () => signedInAuth(uid: uid),
        logger: fakeLogger,
        tenantClaim: const FixedTenantClaim(),
        functions: _FakeFunctions(),
        localSummary: _fakeLocalSummary,
      );

      final data =
          jsonDecode(await service.exportUserData()) as Map<String, dynamic>;
      final reservations = (data['reservations'] as List);
      expect(reservations, hasLength(1));
    });
  });
}
