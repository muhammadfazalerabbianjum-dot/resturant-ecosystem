import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import '../../helpers/isar_test_boot.dart';
import 'package:core/core.dart';

/// Minimal stub used by core tests — core must not import feature models.
class _FakeOrderPayload implements OrderPayload {
  const _FakeOrderPayload();

  @override
  Map<String, dynamic> toJson() => const <String, dynamic>{};
}

OrderPayload _fakeOrderPayloadParser(Map<String, dynamic> json) =>
    const _FakeOrderPayload();

/// In-memory logger double — never touches `path_provider`/Crashlytics.
/// Records every fail-closed error message so tests can ASSERT the logging
/// contract instead of assuming it (FIX-B7 T-2 / AUD1-07: the old double
/// swallowed the evidence).
class _CapturingLogger extends LoggerService {
  /// Every [message] passed to [error], in order.
  final List<String> messages = <String>[];

  @override
  Future<void> error(Object error, String message, {StackTrace? stack}) async {
    messages.add(message);
  }
}

/// A real offline Isar DB booted in a temp dir and injected via
/// `IsarService.forTesting(...)` so constructing `KitchenOfflineService` never
/// touches the `path_provider` platform channel or the production
/// `IsarService.shared()` service. This is the same DI harness the rest of
/// the core package uses for `IsarService.clearAll()` etc.
class _KitchenHarness {
  _KitchenHarness(this.service, this.isar, this.dir, this.logger);
  final KitchenOfflineService service;
  final Isar isar;
  final Directory dir;
  final _CapturingLogger logger;

  Future<void> dispose() async {
    await isar.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

Future<_KitchenHarness> _makeHarness() async {
  final dir = Directory.systemTemp.createTempSync('kitchen_offline_');
  final isar = await Isar.open([
    IsarMenuItemSchema,
    IsarCartSchema,
    IsarPendingOperationSchema,
    IsarDeadLetterSchema,
  ], directory: dir.path);
  final logger = _CapturingLogger();
  final service = KitchenOfflineService(
    isarService: IsarService.forTesting(Future.value(isar), logger),
    logger: logger,
    orderPayloadParser: _fakeOrderPayloadParser,
  );
  return _KitchenHarness(service, isar, dir, logger);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureIsarCoreForTests);

  group('KitchenOfflineService', () {
    test('constants are defined correctly', () {
      expect(kKitchenHeartbeatTask, 'carnama.kitchen.heartbeat');
      expect(kKitchenLanFallbackTask, 'carnama.kitchen.lan_fallback');
    });

    test('constructor wires an injected IsarService + logger', () async {
      final h = await _makeHarness();
      addTearDown(h.dispose);
      expect(h.service, isNotNull);
    });

    test('constructor with explicit IsarService parameter', () async {
      final h = await _makeHarness();
      addTearDown(h.dispose);
      expect(h.service, isNotNull);
    });

    test('runHeartbeat completes without throwing when there are no pending '
        'orders', () async {
      final h = await _makeHarness();
      addTearDown(h.dispose);
      await h.service.runHeartbeat();
      // No exception means the offline path was handled gracefully on a live DB.
    });

    // FIX-B7 T-2 (AUD1-07): these two were try/catch swallows — they passed
    // whether the method worked, no-opped or threw, and the production code
    // actually RETHROWS (fail-closed: log + rethrow), so "does not propagate"
    // was never the real contract. Pinned here from the observed platform
    // behaviour: on the unsupported Workmanager channel the call throws
    // UnimplementedError, the reason is logged, and (for initialize) the
    // dispatcher is never invoked.
    test('scheduleHeartbeat fails closed when unsupported: logs the reason '
        'and rethrows (never a silent no-op)', () async {
      final h = await _makeHarness();
      addTearDown(h.dispose);
      await expectLater(
        h.service.scheduleHeartbeat(),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        h.logger.messages,
        contains('KitchenOfflineService.scheduleHeartbeat failed'),
      );
    });

    test('initialize fails closed when unsupported: dispatcher never runs, '
        'the reason is logged and the error rethrows', () async {
      final h = await _makeHarness();
      addTearDown(h.dispose);
      var dispatcherCalls = 0;
      await expectLater(
        h.service.initialize(() => dispatcherCalls++),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        h.logger.messages,
        contains('KitchenOfflineService.initialize failed'),
      );
      expect(dispatcherCalls, 0);
    });
  });
}
