import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/app/compliance/data_export_service.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/tenant_claim_fakes.dart';

/// Records every Crashlytics-bound error (no real file I/O in tests).
class _MockLogger extends Mock implements LoggerService {}

/// Fake `exportMyData` callable: returns the SERVER-ONLY sections (the
/// rules-gated stores a client query cannot read — W9.10).
class _FakeResult implements HttpsCallableResult<dynamic> {
  _FakeResult(this.data);
  @override
  final dynamic data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this.result);
  final HttpsCallableResult<dynamic> result;
  int calls = 0;
  @override
  Future<HttpsCallableResult<T>> call<T>([Object? data]) async {
    calls++;
    if (result.data is Exception) throw result.data as Exception;
    return result as HttpsCallableResult<T>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions(this.callable);
  final HttpsCallable callable;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      callable;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Map<String, dynamic>> _fakeLocalSummary() async => {
  'isar': {
    'menuItems': 3,
    'carts': 1,
    'pendingOperations': 0,
    'deadLetters': 0,
  },
  'preferences': {
    'keys': ['onboarding_completed'],
    'onboardingCompleted': true,
  },
};

DataExportService _service(
  FakeFirebaseFirestore firestore,
  MockUser user,
  _FakeCallable callable,
  _MockLogger logger,
) => DataExportService(
  firestore: firestore,
  currentUser: () => user,
  logger: logger,
  tenantClaim: const FixedTenantClaim(),
  functions: _FakeFunctions(callable),
  localSummary: _fakeLocalSummary,
);

void main() {
  final user = MockUser(uid: 'u-1', email: 'user1@test.dev');
  late _MockLogger logger;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    logger = _MockLogger();
    when(
      () => logger.error(any(), any(), stack: any(named: 'stack')),
    ).thenAnswer((_) async {});
  });

  test(
    'T-3: export contains ALL sections incl. the new server-only stores',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u-1').set({
        'email': 'user1@test.dev',
        'role': 'customer',
      });
      await firestore.collection('orders').doc('o-1').set({
        'tenantId': 'tenant_a',
        'customerId': 'u-1',
        'totalCents': 2500,
      });
      await firestore.collection('loyalty').doc('u-1').set({'points': 10});
      await firestore.collection('reservations').doc('r-1').set({
        'tenantId': 'tenant_a',
        'userId': 'u-1',
        'partySize': 2,
      });
      await firestore.collection('carts').doc('u-1').set({
        'items': <dynamic>[],
      });
      await firestore.collection('presence').doc('u-1').set({'lastSeen': 'x'});
      await firestore.collection('waitlist').doc('w-1').set({
        'tenantId': 'tenant_a',
        'userId': 'u-1',
      });

      final sections = <String, dynamic>{
        'promoUsage': [
          {'id': 'pu-1', 'userId': 'u-1', 'code': 'HELLO10'},
        ],
        'reservationLocks': [
          {'id': 'lock-1', 'userId': 'u-1'},
        ],
        'notificationItems': [
          {'id': 'n-1', 'title': 'hello'},
        ],
        'deliveries': [
          {'id': 'o-1', 'status': 'confirmed'},
        ],
        'analyticsEvents': [
          {'id': 'ev-1', 'uid': 'u-1', 'event': 'screen_view'},
        ],
        'fixedDocs': {
          'driverLocation': {'id': 'u-1', 'lat': 1, 'lng': 2},
        },
        'userProfile': {'email': 'user1@test.dev'},
      };
      final callable = _FakeCallable(_FakeResult({'sections': sections}));
      final loggerLocal = logger;

      final json = await _service(
        firestore,
        user,
        callable,
        loggerLocal,
      ).exportAsJsonString();
      final data = jsonDecode(json) as Map<String, dynamic>;

      // Pre-existing sections (client-readable).
      expect(data['userProfile'], isNotNull);
      expect((data['orders'] as List).length, 1);
      expect(data['loyalty'], isNotNull);
      expect((data['reservations'] as List).length, 1);
      expect(data['cart'], isNotNull);
      expect(data['presence'], isNotNull);
      expect((data['waitlistEntries'] as List).length, 1);
      // NEW: the rules-gated server section (W9.10) mirrors the erasure set.
      final serverExport = ((data['serverExport'] as Map)['sections'] as Map)
          .cast<String, dynamic>();
      expect(serverExport['promoUsage'], isNotEmpty);
      expect(serverExport['reservationLocks'], isNotEmpty);
      expect(serverExport['notificationItems'], isNotEmpty);
      expect(serverExport['deliveries'], isNotEmpty);
      expect(serverExport['analyticsEvents'], isNotEmpty);
      final fixedDocs = serverExport['fixedDocs'] as Map;
      expect(fixedDocs['driverLocation'], isNotNull);
      // NEW: the local device summary.
      final isar = (data['localData'] as Map)['isar'] as Map;
      expect(isar['menuItems'], 3);
      final preferences = (data['localData'] as Map)['preferences'] as Map;
      expect(preferences['onboardingCompleted'], isTrue);
      expect(callable.calls, 1);
    },
  );

  test(
    'T-3: a server-export failure FAILS THE EXPORT (no silent section drop)',
    () async {
      final firestore = FakeFirebaseFirestore();
      final callable = _FakeCallable(_FakeResult(Exception('functions down')));

      await expectLater(
        _service(firestore, user, callable, logger).exportAsJsonString(),
        throwsA(isA<Exception>()),
      );
      verify(
        () => logger.error(
          any(),
          'data_export_server_failed',
          stack: any(named: 'stack'),
        ),
      ).called(1);
    },
  );
}
