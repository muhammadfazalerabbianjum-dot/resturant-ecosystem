import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core/core.dart';
import 'package:labs/app/config/app_config.dart';

/// Local notification surface for the app layer (PUSH-2 T-5).
///
/// - [initialize] is IDEMPOTENT: the plugin instance and its tap handler are
///   wired exactly once; every later call is a no-op (checkout calls this
///   before every show).
/// - iOS: `requestAlertPermission` is FALSE (PUSH-2 P-4 — this batch never
///   triggers an OS notification consent dialog from app code; the
///   contextual grant moment is owned by the UX chain). Displaying still
///   works once ANY notification authorization has been granted, and FCM
///   settings are observed, never requested, at boot.
/// - Taps route through [PushNotificationService.handleTapData] — the SAME
///   validated route table + go_router bridge as FCM taps (PUSH-2 P-2), so
///   tapping "Order Confirmed" opens the order tracker instead of doing
///   nothing.
class LocalNotificationService {
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  /// Test seam: whether [initialize] has completed at least once.
  @visibleForTesting
  static bool get isInitialized => _initialized;

  /// Test seam: replaces the plugin (and unsets the initialized flag) so a
  /// test can drive [initialize] against a mock.
  @visibleForTesting
  static set pluginForTest(FlutterLocalNotificationsPlugin? plugin) {
    _plugin = plugin;
    _initialized = false;
  }

  static FlutterLocalNotificationsPlugin get _notificationsPlugin =>
      _plugin ??= FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (_initialized) return;
    // WHY ic_launcher: this is the resource every Android head ships (the
    // manifest's own android:icon), while the old '@mipmap/launcher_icon'
    // name exists in no white-label app — flutter_local_notifications threw
    // PlatformException(invalid_icon) at every boot (emulator log capture).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      // PUSH-2 T-5: the tap handler is wired AT INITIALIZE TIME — previously
      // no handler existed, so every local notification tap was a dead end.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        // Order-status notifications carry the raw orderId as payload —
        // resolved against the shared route table (fail-closed on unknown).
        unawaited(PushNotificationService.handleTapData({'orderId': payload}));
      },
    );
    _initialized = true;
  }

  static Future<void> showOrderStatusNotification(
    String orderId,
    String statusMessage,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      'order_updates_channel',
      'Order Updates',
      channelDescription: AppConfig.fcmChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      'Order Confirmed',
      statusMessage,
      notificationDetails,
      payload: orderId,
    );
  }
}
