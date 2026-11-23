import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:core/src/cache/isar_service.dart';
import 'package:core/src/config/core_config.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/kitchen/order_payload.dart';

const kKitchenHeartbeatTask = 'carnama.kitchen.heartbeat';
const kKitchenLanFallbackTask = 'carnama.kitchen.lan_fallback';
const int _kMaxSyncBatch = 20;

/// Offline synchronisation for kitchen orders.
///
/// Decoupled from feature models via [OrderPayload] and an injected
/// [OrderPayloadParser]. The feature layer supplies the parser via its
/// adapter — core never imports `features/`.
class KitchenOfflineService {
  final IsarService _isarService;
  final LoggerService _logger;
  final OrderPayloadParser _orderPayloadParser;

  /// Creates a [KitchenOfflineService] with an injectable [IsarService]
  /// and the [OrderPayloadParser] used to rehydrate pending orders.
  ///
  /// In production:
  /// `KitchenOfflineService(orderPayloadParser: OrderPayloadAdapter.fromJson)`
  /// In tests: provide a mock or in-memory Isar service plus a parser stub.
  KitchenOfflineService({
    IsarService? isarService,
    LoggerService? logger,
    required OrderPayloadParser orderPayloadParser,
  }) : _isarService = isarService ?? IsarService.shared(),
       _logger = logger ?? LoggerService(),
       _orderPayloadParser = orderPayloadParser;

  /// The kitchen LAN endpoint, resolved from [CoreConfigHolder].
  ///
  /// Every restaurant has a DIFFERENT kitchen terminal IP. The endpoint is
  /// configurable per-restaurant at runtime (from Firestore restaurant_config
  /// or --dart-define), NOT a compile-time constant (Law 3).
  String get _kitchenEndpoint => CoreConfigHolder.instance.kitchenLanEndpoint;

  /// Initialises the Workmanager background heartbeat task.
  ///
  /// [dispatcher] must be a top-level, `@pragma('vm:entry-point')`-annotated
  /// callback provided by the feature/app layer. Core cannot provide it
  /// because it must not depend on feature models.
  Future<void> initialize(void Function() dispatcher) async {
    try {
      await Workmanager().initialize(dispatcher);
    } catch (e, stack) {
      await _logger.error(
        e,
        'KitchenOfflineService.initialize failed',
        stack: stack,
      );
      rethrow;
    }
  }

  Future<void> scheduleHeartbeat() async {
    try {
      await Workmanager().registerPeriodicTask(
        kKitchenHeartbeatTask,
        kKitchenHeartbeatTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e, stack) {
      await _logger.error(
        e,
        'KitchenOfflineService.scheduleHeartbeat failed',
        stack: stack,
      );
      rethrow;
    }
  }

  Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(kKitchenHeartbeatTask);
    } catch (e, stack) {
      await _logger.error(
        e,
        'KitchenOfflineService.cancel failed',
        stack: stack,
      );
      rethrow;
    }
  }

  /// Runs the heartbeat synchronisation – exposed for testing.
  Future<void> runHeartbeat() async {
    try {
      // PUSH-1 (P-3): fail-closed empty-endpoint guard. The endpoint is
      // resolved ONCE into a local so the check and the POST cannot observe
      // different config values. Empty/absent => log-and-skip: NEVER build
      // `Uri.parse('/orders')` (a relative URL that makes `http.post` throw
      // on every heartbeat tick) and never POST orders to a bogus
      // destination. The queued orders stay parked for the next configured
      // run — the heartbeat is a LAN safety net, the sync queue remains the
      // primary delivery path (QUEUE-1).
      final kitchenEndpoint = _kitchenEndpoint;
      if (kitchenEndpoint.trim().isEmpty) {
        await _logger.warn(
          StateError(
            'CoreConfigHolder.instance.kitchenLanEndpoint is empty/absent',
          ),
          'KitchenHeartbeatSkipped: no kitchen LAN endpoint configured '
          '(environment.kitchenLanEndpoint / KITCHEN_LAN_ENDPOINT / Firestore '
          'settings/restaurantConfig.kitchenLanEndpoint)',
        );
        return;
      }

      final isOnline = await _checkConnectivity();
      if (isOnline) return;

      final pendingOps = await _isarService.getPendingOrders(
        limit: _kMaxSyncBatch,
      );
      if (pendingOps.isEmpty) return;

      final pendingOrders = pendingOps
          .map(
            (op) => _orderPayloadParser(
              Map<String, dynamic>.from(
                jsonDecode(op.dataString) as Map<String, dynamic>,
              ),
            ),
          )
          .toList();

      // Fire-and-forget with error handling — NEVER fire-and-forget without
      // catching errors (Law 8: Defensive Execution).
      final future = http.post(
        Uri.parse('$kitchenEndpoint/orders'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(pendingOrders.map((o) => o.toJson()).toList()),
      );
      unawaited(
        future
            .then((response) {
              if (response.statusCode == 200) {
                unawaited(
                  _isarService.markOrdersSynced(
                    pendingOps.map((op) => op.id).toList(),
                  ),
                );
              } else {
                FirebaseCrashlytics.instance.recordError(
                  Exception('LAN sync failed: HTTP ${response.statusCode}'),
                  StackTrace.current,
                  fatal: false,
                );
              }
            })
            .catchError((Object e, StackTrace s) {
              _logger.error(e, 'kitchen_order_push_failed', stack: s);
            }),
      );
    } catch (e, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          fatal: false,
          information: ['context=KitchenOfflineService._runHeartbeat'],
        ),
      );
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }
}
