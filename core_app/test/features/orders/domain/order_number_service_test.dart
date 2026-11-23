import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/features/orders/domain/order_number_service.dart';

/// A [FirebaseCoreHostApi] test double that registers the Crashlytics plugin
/// constants the real native host provides at initializeApp time. Without
/// them, `FirebaseCrashlytics.instance` fails its platform-interface
/// assertion and `nextOrderNumber`'s catch-and-fallback branch (which
/// reports through Crashlytics before returning the shortcode) can never run
/// on a test host.
class CrashlyticsConstantsCoreHost implements TestFirebaseCoreHostApi {
  static const Map<String, dynamic> _constants = <String, dynamic>{
    'plugins.flutter.io/firebase_crashlytics': <String, dynamic>{
      'isCrashlyticsCollectionEnabled': true,
    },
  };

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: initializeAppRequest,
      pluginConstants: _constants,
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async =>
      <CoreInitializeResponse>[
        // The default app must exist natively so `Firebase.initializeApp()`
        // (no options) resolves against it — carrying the plugin constants.
        CoreInitializeResponse(
          name: defaultFirebaseAppName,
          options: CoreFirebaseOptions(
            apiKey: '123',
            projectId: 'test',
            appId: '123',
            messagingSenderId: '123',
          ),
          pluginConstants: _constants,
        ),
      ];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    return CoreFirebaseOptions(
      apiKey: '123',
      projectId: 'test',
      appId: '123',
      messagingSenderId: '123',
    );
  }
}

/// A [FirebaseFirestore] double whose transaction entry point fails — the
/// test host for `nextOrderNumber`'s catch-and-fallback branch (the crash
/// log + timestamp shortcode), which a healthy FakeFirebaseFirestore can
/// never reach.
class ThrowingFirestore extends Fake implements FirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    throw StateError('transaction unavailable (test)');
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The package's own customization seam (see MockFirebaseApp doc comment):
    // seed the plugin constants the Crashlytics platform interface asserts on.
    TestFirebaseCoreHostApi.setUp(CrashlyticsConstantsCoreHost());
    // The fallback branch reports through Crashlytics before returning the
    // shortcode; the method channel is answered so the awaited recordError
    // completes instead of surfacing a MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_crashlytics'),
          (call) async => <String, dynamic>{
            'isCrashlyticsCollectionEnabled': true,
          },
        );
    await Firebase.initializeApp();
  });

  group('OrderNumberService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late OrderNumberService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = OrderNumberService(firestore: fakeFirestore);
    });

    test('nextOrderNumber returns a formatted string with # prefix', () async {
      final orderNum = await service.nextOrderNumber();
      expect(orderNum, startsWith('#'));
    });

    test('nextOrderNumber increments sequentially', () async {
      final first = await service.nextOrderNumber();
      final second = await service.nextOrderNumber();
      expect(first, isNot(equals(second)));
    });

    test('nextOrderNumber persists across calls', () async {
      await service.nextOrderNumber();
      final num2 = await service.nextOrderNumber();
      expect(num2, contains(RegExp(r'#\d{4}')));
    });

    test('fromDocId formats short doc IDs correctly', () {
      expect(OrderNumberService.fromDocId('abc123'), '#ABC123');
    });

    test('fromDocId handles long doc IDs', () {
      const longId = 'abcdef1234567890';
      expect(OrderNumberService.fromDocId(longId), '#ABCDEF');
    });

    // ── PERF-2 S1 EXTENSION: EXACT SEQUENCE + FALLBACK CONTRACT ──
    test(
      'the first order number is #0001 (an empty counter starts the sequence)',
      () async {
        expect(await service.nextOrderNumber(), '#0001');
      },
    );

    test('a seeded counter continues its sequence (#0041 -> #0042)', () async {
      await fakeFirestore.doc('settings/orderCounter').set(<String, dynamic>{
        'seq': 41,
      });
      expect(await service.nextOrderNumber(), '#0042');
    });

    test(
      'the counter document is persisted for the next call (atomic increment)',
      () async {
        await service.nextOrderNumber();
        await service.nextOrderNumber();

        final snapshot = await fakeFirestore.doc('settings/orderCounter').get();
        expect(snapshot.data()?['seq'], 2);
      },
    );

    test(
      'a failed transaction falls back to a timestamp shortcode (never throws)',
      () async {
        final throwing = OrderNumberService(firestore: ThrowingFirestore());

        final fallback = await throwing.nextOrderNumber();

        expect(fallback, matches(RegExp(r'^#\d{4}$')));
      },
    );
  });
}
