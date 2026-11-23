import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core/src/config/core_config.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/navigation/deep_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The kind of push notification inferred from the FCM `data` payload
/// (PUSH-2 P-2). The server sends exactly two push shapes today — proven in
/// `core_app/functions/src/index.ts`:
/// - `onOrderStatusChange` → `data: { orderId, status }` (index.ts:1531)
/// - cart recovery         → `data: { cartId }`          (index.ts:1452)
enum PushNotificationTap {
  /// `{ orderId, status }` → navigate to the order tracker.
  orderStatus,

  /// `{ cartId }` → navigate to the cart.
  cartRecovery,

  /// Anything else. Fail-closed: logged-and-dropped, never navigated.
  unknown,
}

/// Bridge through which a validated push-tap route is navigated.
///
/// The app layer installs a go_router-backed handler at boot (the same shape
/// as [DeepLinkService.navigationHandler]) — core must never depend on the
/// app layer (Law 3), so the live router is reached through this seam.
typedef PushNavigationHandler = Future<void> Function(String path);

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static FlutterLocalNotificationsPlugin? _localNotifications;

  /// Installed by the app layer at boot (`core_app/lib/app_bootstrap.dart:700`). The ONLY
  /// navigation seam — no tap navigates without it (PUSH-2 P-2).
  static PushNavigationHandler? navigationHandler;

  static LoggerService _logger = LoggerService();
  static bool _initialized = false;
  static bool _handlingTap = false;

  /// Reset generation (A6/T-1): [resetForTest] bumps it, and every listener
  /// closure and echo handler captures the generation it was created under —
  /// a mismatch means the callback belongs to a previous test and must abort
  /// before it can log into or render through the NEXT test's seams.
  static int _epoch = 0;

  /// The live FCM stream subscriptions. [resetForTest] cancels both so a
  /// stale message can never be delivered across a test boundary (Law 9:
  /// no leaked listeners).
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  /// Completes once the cold-start scan (`getInitialMessage`) has resolved —
  /// successfully or with an error — so the app layer can consume a pending
  /// cold-start tap at a safe moment (see [consumePendingColdStartTap]).
  static Future<void> get ready => _coldStartScan.future;
  static final Completer<void> _coldStartScan = Completer<void>();
  static Map<String, dynamic>? _pendingColdStartTap;

  /// Test seam: resets every static so tests are order-independent.
  ///
  /// Also the cancellation point for in-flight notification echoes (A6/T-1):
  /// bumping [_epoch] invalidates every listener/handler created under the
  /// previous generation, and cancelling both stream subscriptions stops any
  /// not-yet-delivered message — all synchronously, so no echo can reach
  /// `plugin.show(...)` after this method returns.
  @visibleForTesting
  static void resetForTest() {
    _epoch++;
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    _foregroundSubscription = null;
    _openedSubscription = null;
    _localNotifications = null;
    navigationHandler = null;
    _logger = LoggerService();
    _initialized = false;
    _handlingTap = false;
  }

  /// Test seam: injects a logger so routing decisions can be observed.
  @visibleForTesting
  static set loggerForTest(LoggerService logger) => _logger = logger;

  /// UI-15 (p24) T-3 / `F3-04` — the END-USER notification preference.
  ///
  /// One stored boolean, consumed in exactly ONE shipped place: the foreground
  /// local-echo path ([_onForegroundMessage]). The key and its I/O live here,
  /// next to that consumer, so the settings UI can never drift into a second
  /// key or a second read site (the settings row writes through
  /// [setForegroundEchoEnabled]).
  ///
  /// Scope (D-P24-1 option (a)): turning this OFF suppresses only the
  /// client-side echo while the app is open. Server-sent delivery, the
  /// background/tap paths and the FCM token are untouched — there is no
  /// server-side unsubscribe.
  static const String foregroundEchoPreferenceKey =
      'settings_foreground_echo_enabled';

  /// Reads the stored preference. Absent, mistyped or unreadable ⇒ `true`:
  /// exactly today's behaviour (L-P2). Never throws — a preference read must
  /// never become an app-level failure.
  static Future<bool> foregroundEchoEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Typed read: a value stored under another type reads as "nothing
      // stored" and keeps the echo. (`getBool` would throw on a mistyped
      // value, which a preference must never do.)
      final stored = prefs.get(foregroundEchoPreferenceKey);
      return stored is bool ? stored : true;
    } catch (e, stack) {
      await _logForegroundEchoFailure(e, stack, 'PushForegroundEchoPrefRead');
      return true;
    }
  }

  /// Persists the preference (the settings row is the only caller). Never
  /// throws: a failed write leaves the previous stored value in place, which is
  /// the safe direction (the echo keeps its old, known state).
  static Future<void> setForegroundEchoEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(foregroundEchoPreferenceKey, enabled);
    } catch (e, stack) {
      await _logForegroundEchoFailure(e, stack, 'PushForegroundEchoPrefWrite');
    }
  }

  /// Reports a preference I/O failure without letting the REPORT become the
  /// failure: on a host with no platform channel or disk the logger's own
  /// write throws (observed in headless test hosts as
  /// `MissingPluginException ... getApplicationDocumentsDirectory`), so it is
  /// contained here with a last-resort `developer.log`, which needs no plugin.
  static Future<void> _logForegroundEchoFailure(
    Object error,
    StackTrace stack,
    String message,
  ) async {
    try {
      await _logger.error(error, message, stack: stack);
    } catch (logFailure) {
      developer.log('$message log failed: $logFailure');
    }
  }

  /// Classifies a raw FCM `data` map. Public so tests pin the server contract.
  static PushNotificationTap tapKindOf(Map<String, dynamic> data) {
    if (data.containsKey('orderId')) return PushNotificationTap.orderStatus;
    if (data.containsKey('cartId')) return PushNotificationTap.cartRecovery;
    return PushNotificationTap.unknown;
  }

  /// Resolves the in-app route for a push payload, or null when the payload
  /// must be dropped (PUSH-2 P-2, fail-closed).
  ///
  /// The path is validated against [DeepLinkRouteTable] — the SAME route
  /// vocabulary deep links use — so a tap can never navigate to an
  /// unregistered route (router error page). `/orders/:orderId` is the
  /// tracker path registered in BOTH router modes (static fallback table
  /// `app_router.dart` and the config-mode screens), which is why it — and
  /// not the config-only `/tracking/:orderId` — is the tap target.
  static String? resolveRoutePath(Map<String, dynamic> data) {
    switch (tapKindOf(data)) {
      case PushNotificationTap.orderStatus:
        final orderId = data['orderId'];
        if (orderId is! String || orderId.isEmpty) return null;
        final path = '/orders/$orderId';
        return DeepLinkRouteTable.isValid(path)
            ? path
            : _logInvalid(path, 'orderStatus');
      case PushNotificationTap.cartRecovery:
        const path = '/cart';
        return DeepLinkRouteTable.isValid(path)
            ? path
            : _logInvalid(path, 'cartRecovery');
      case PushNotificationTap.unknown:
        return null;
    }
  }

  static String? _logInvalid(String path, String kind) {
    _logger.error(
      StateError('push tap resolved outside the route table: $path'),
      'PushTapInvalidRoute ($kind)',
    );
    return null;
  }

  /// True when the payload is addressable to THIS white-label app.
  ///
  /// The server's current payload carries NO `clientId` (proven:
  /// index.ts:1531/1452 send only orderId/status/cartId), so absence is the
  /// compatible path. When the field IS present it is BINDING: a payload for
  /// another install must never navigate here (PUSH-2 P-2 hardening).
  static bool _belongsToThisApp(Map<String, dynamic> data) {
    final payloadClient = data['clientId'];
    if (payloadClient == null) return true;
    return payloadClient is String &&
        payloadClient.isNotEmpty &&
        payloadClient == CoreConfigHolder.instance.clientId;
  }

  /// Handles a decoded push payload: validates, de-bounces, navigates.
  ///
  /// Entry point for BOTH FCM taps (background `onMessageOpenedApp`, local
  /// echo taps, cold-start consumption) and local-notification taps. Never
  /// throws — a broken tap must never crash the app (PUSH-2 P-2).
  static Future<void> handleTapData(Map<String, dynamic> data) async {
    if (!_belongsToThisApp(data)) {
      await _logger.error(
        StateError('push payload addressed to another clientId'),
        'PushTapWrongTenant',
      );
      return;
    }
    final path = resolveRoutePath(data);
    if (path == null) {
      await _logger.error(
        StateError('unroutable push payload: ${jsonEncode(data)}'),
        'PushTapRejected',
      );
      return;
    }
    if (_handlingTap) {
      // P-2: de-bounce. Two taps landing in the same window (double-tap, or a
      // tap racing an in-flight cold-start tap) must not push twice.
      await _logger.info({'path': path}, 'PushTapDeduped');
      return;
    }
    _handlingTap = true;
    try {
      final handler = navigationHandler;
      if (handler == null) {
        // Same guard as the deep-link handler before the router exists.
        await _logger.info({'path': path}, 'PushNavigationSkipped: no handler');
        return;
      }
      await handler(path);
    } catch (e, stack) {
      await _logger.error(e, 'PushTapNavigationError', stack: stack);
    } finally {
      _handlingTap = false;
    }
  }

  /// Consumes a cold-start (terminated-state) tap, if one is pending.
  ///
  /// PUSH-2 P-3: at [initialize] time no router exists yet, so a cold-start
  /// payload must be stashed and consumed AFTER the app layer mounts the
  /// router (called from `CoreApp.initState`). Idempotent — the second call
  /// is a no-op.
  static Future<void> consumePendingColdStartTap() async {
    final data = _pendingColdStartTap;
    if (data == null) return;
    _pendingColdStartTap = null;
    await _logger.info({'data': jsonEncode(data)}, 'PushTapColdStartConsumed');
    await handleTapData(data);
  }

  /// Initializes FCM tap routing + the local-notification echo surface.
  ///
  /// All FCM/plugin touchpoints are injectable for tests; production call
  /// sites pass nothing. NEVER requests permission (PUSH-2 P-4: FcmService
  /// only OBSERVES consent — prompting is a contextual, task-owned moment).
  static Future<void> initialize({
    FlutterLocalNotificationsPlugin? localNotifications,
    Stream<RemoteMessage>? foregroundMessages,
    Stream<RemoteMessage>? openedMessages,
    Future<RemoteMessage?>? initialMessage,
  }) async {
    if (_initialized) return;
    _initialized = true;
    try {
      _localNotifications =
          localNotifications ?? FlutterLocalNotificationsPlugin();
      await _initLocalNotifications(_localNotifications!);

      // Foreground: the system does NOT auto-display FCM messages while the
      // app is foregrounded — render a local echo so the user gets a TAPPABLE
      // notification instead of nothing (P-4: navigation ONLY via taps).
      final epoch = _epoch;
      _foregroundSubscription =
          (foregroundMessages ?? FirebaseMessaging.onMessage).listen(
            (message) {
              if (epoch != _epoch) return;
              unawaited(_onForegroundMessage(message));
            },
            onError: (Object e) =>
                _logger.error(e, 'PushForegroundStreamError'),
          );

      // Background → tap: the user opened the app FROM the notification.
      _openedSubscription =
          (openedMessages ?? FirebaseMessaging.onMessageOpenedApp).listen((
            message,
          ) {
            if (epoch != _epoch) return;
            unawaited(_onTapData(message.data, source: 'opened-app'));
          }, onError: (Object e) => _logger.error(e, 'PushOpenedStreamError'));

      // Terminated → tap: stashed for deferred consumption (P-3) — the router
      // does not exist yet at init time.
      final initial =
          await (initialMessage ??
              FirebaseMessaging.instance.getInitialMessage());
      if (initial != null) {
        _pendingColdStartTap = initial.data;
      }
    } catch (e, stack) {
      await _logger.error(e, 'PushNotificationInit', stack: stack);
    } finally {
      // Complete in ALL paths — consumers await [ready] before consuming.
      if (!_coldStartScan.isCompleted) _coldStartScan.complete();
    }

    // P-5: defensively re-assert FCM auto-init ON at push init. Today's tree
    // contains NO disabling call site (grep-proven), but the shared Firebase
    // app's messaging auto-init is process-global: one future regression
    // (e.g. a sign-out hook flipping it off) would silently kill token
    // delivery for every consumer. This makes push init self-healing.
    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (e) {
      // No-op on platforms without the API; logged, never fatal.
      await _logger.info({'error': '$e'}, 'PushAutoInitRestoreSkipped');
    }
  }

  static Future<void> _initLocalNotifications(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    const initSettings = InitializationSettings(
      // WHY ic_launcher: the resource every Android head ships (the
      // manifest's android:icon). The previous '@mipmap/launcher_icon' name
      // exists in no white-label app head — AndroidFlutterLocalNotifications
      // rejected it with PlatformException(invalid_icon) at boot.
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) =>
          unawaited(_onLocalNotificationTap(response)),
    );
  }

  static Future<void> _onLocalNotificationTap(
    NotificationResponse response,
  ) async {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) {
      await _logger.info({}, 'PushTapEmptyLocalPayload');
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        await handleTapData(decoded);
        return;
      }
      // Legacy local payloads carry a bare orderId string (checkout's
      // showOrderStatusNotification payload).
      await handleTapData({'orderId': raw});
    } on FormatException catch (e) {
      await _logger.error(e, 'PushTapLocalPayloadUnparseable');
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final epoch = _epoch;
    // UI-15 (p24) T-3 / F3-04 — THE GATE, and the ONLY shipped consumer of the
    // stored end-user notification preference. With it OFF the foreground local
    // echo is skipped; the tap paths (`openedMessages` above, the cold-start
    // stash) and server delivery are untouched (D-P24-1 option (a)).
    if (!await foregroundEchoEnabled()) {
      await _logger.info({
        'messageId': message.messageId,
      }, 'PushForegroundEchoSuppressed');
      return;
    }
    final data = message.data;
    await _logger.info({
      'messageId': message.messageId,
      'data': jsonEncode(data),
    }, 'PushForegroundMessage');
    // Unknown payloads get NO local echo — a notification the app cannot
    // route would train users to tap into dead ends (fail-closed).
    if (tapKindOf(data) == PushNotificationTap.unknown) return;
    if (epoch != _epoch) return; // reset mid-flight → echo cancelled (A6)
    final plugin = _localNotifications;
    if (plugin == null) return;
    final title = message.notification?.title ?? 'Update';
    final body = message.notification?.body ?? 'You have a new update';
    const androidDetails = AndroidNotificationDetails(
      'fcm_push_channel',
      'Push notifications',
      channelDescription: 'Order and cart notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff),
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(data),
      );
    } catch (e, stack) {
      await _logger.error(e, 'PushLocalEchoFailed', stack: stack);
    }
  }

  static Future<void> _onTapData(
    Map<String, dynamic> data, {
    required String source,
  }) async {
    await _logger.info({'source': source, 'data': jsonEncode(data)}, 'PushTap');
    await handleTapData(data);
  }
}
