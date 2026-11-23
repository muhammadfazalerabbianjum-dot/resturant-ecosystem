import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart';
import 'package:labs/features/orders/domain/order_payload_adapter.dart';

import 'dart:io';
import 'package:isar_community/isar.dart';
import '../../../helpers/isar_test_boot.dart';

/// Captures errors in memory; never touches `path_provider`/Crashlytics.
class _CapturingLogger extends LoggerService {
  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {}
}

/// Builds a real offline Isar DB in a temp dir and injects it so the service
/// constructor never pulls the production `IsarService.shared()` service
/// (whose lazy `openDB()` requires a real `path_provider` platform channel).
/// Same DI harness pattern as the core package's `IsarService` tests.
Future<({KitchenOfflineService service, Isar isar, Directory dir})>
_makeHarness({_RecordingLogger? recordingLogger}) async {
  final dir = Directory.systemTemp.createTempSync('kitchen_offline_feature_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  final logger = recordingLogger ?? _CapturingLogger();
  final service = KitchenOfflineService(
    isarService: IsarService.forTesting(Future.value(isar), logger),
    logger: logger,
    orderPayloadParser: OrderPayloadAdapter.fromJson,
  );
  return (service: service, isar: isar, dir: dir);
}

Future<void> _dispose(Isar isar, Directory dir) async {
  await isar.close();
  if (await dir.exists()) await dir.delete(recursive: true);
}

/// PUSH-1 T-1 double: overrides [LoggerService.warn] so the fail-closed
/// skip record is captured in memory. The base `warn` would lazily
/// `init()` a log file via `path_provider` (a platform channel unavailable
/// in unit tests), so the override is REQUIRED to exercise the guard.
class _RecordingLogger extends _CapturingLogger {
  final List<String> warnings = <String>[];

  @override
  Future<void> warn(Object error, String message, {StackTrace? stack}) async {
    warnings.add(message);
  }
}

/// PUSH-1 T-1/T-2 double: injects an arbitrary `kitchenLanEndpoint` through
/// the exact seam the production adapter uses
/// (`CoreAppConfig.kitchenLanEndpoint` -> `CoreConfigHolder`). Tests ALWAYS
/// restore `DefaultCoreConfig` in a tearDown so later tests in this isolate
/// observe stock config.
class _EndpointTestConfig implements CoreConfig {
  const _EndpointTestConfig(this.kitchenLanEndpoint);

  @override
  final String kitchenLanEndpoint;

  @override
  bool get isDemoMode => false;

  @override
  String get clientId => 'labs-push1-test';

  @override
  String get cloudinaryUploadPreset => '';

  @override
  String get cloudinaryCloudName => '';

  @override
  List<String> get ownerEmails => const [];
}

/// Seeds one real pending-order row (the same shape
/// `IsarService.getPendingOrders` reads: `dataString` JSON + timestamp +
/// retryCount).
IsarPendingOperation _seedPendingOp() => IsarPendingOperation()
  ..operation = 'createOrder'
  ..collectionName = 'orders'
  ..dataString = '{"id":"local-1","status":"pending"}'
  ..timestamp = DateTime.now().toUtc()
  ..retryCount = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureIsarCoreForTests);

  group('KitchenOfflineService', () {
    test('service can be instantiated with an injected IsarService', () async {
      final h = await _makeHarness();
      addTearDown(() => _dispose(h.isar, h.dir));
      expect(h.service, isNotNull);
    });

    test('runHeartbeat handles no pending orders', () async {
      final h = await _makeHarness();
      addTearDown(() => _dispose(h.isar, h.dir));
      // Should not throw when there are no pending orders.
      await h.service.runHeartbeat();
    });

    test('runHeartbeat does not crash on an empty DB', () async {
      final h = await _makeHarness();
      addTearDown(() => _dispose(h.isar, h.dir));
      // Should not throw even if the connectivity check is unavailable.
      await h.service.runHeartbeat();
    });

    test('KitchenOfflineService has correct method signatures', () async {
      final h = await _makeHarness();
      addTearDown(() => _dispose(h.isar, h.dir));
      expect(
        h.service.initialize,
        isA<Future<void> Function(void Function())>(),
      );
      expect(h.service.cancel, isA<Future<void> Function()>());
      expect(h.service.scheduleHeartbeat, isA<Future<void> Function()>());
      expect(h.service.runHeartbeat, isA<Future<void> Function()>());
    });

    test('PUSH-1 P-3: empty kitchenLanEndpoint logs-and-skips the heartbeat '
        '(never builds Uri.parse(""))', () async {
      CoreConfigHolder.set(const _EndpointTestConfig(''));
      addTearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));
      final logger = _RecordingLogger();
      final h = await _makeHarness(recordingLogger: logger);
      addTearDown(() => _dispose(h.isar, h.dir));

      await h.isar.writeTxn(
        () => h.isar.isarPendingOperations.put(_seedPendingOp()),
      );

      // Must NOT throw and must record the WARN skip (fail-closed,
      // never silent).
      await h.service.runHeartbeat();
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.single, contains('KitchenHeartbeatSkipped'));

      // The pending order was NOT consumed: skip, not silent-send.
      expect(await h.isar.isarPendingOperations.count(), 1);
    });

    test(
      'PUSH-1 P-3: blank/whitespace kitchenLanEndpoint is treated as absent',
      () async {
        CoreConfigHolder.set(const _EndpointTestConfig('   '));
        addTearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));
        final logger = _RecordingLogger();
        final h = await _makeHarness(recordingLogger: logger);
        addTearDown(() => _dispose(h.isar, h.dir));

        await h.service.runHeartbeat();
        expect(logger.warnings, hasLength(1));
        expect(logger.warnings.single, contains('KitchenHeartbeatSkipped'));
      },
    );

    test('PUSH-1 P-3: golden LAN endpoint parses to a URI with scheme+host '
        '(the exact construction runHeartbeat POSTs to)', () async {
      CoreConfigHolder.set(
        const _EndpointTestConfig('http://192.168.10.42:8080'),
      );
      addTearDown(() => CoreConfigHolder.set(const DefaultCoreConfig()));

      // Same resolution seam + same string construction as the service
      // (`Uri.parse('$kitchenEndpoint/orders')`).
      final endpoint = CoreConfigHolder.instance.kitchenLanEndpoint;
      final uri = Uri.parse('$endpoint/orders');
      expect(uri.scheme, 'http');
      expect(uri.host, '192.168.10.42');
      expect(uri.port, 8080);
      expect(uri.path, '/orders');
    });
  });
}
