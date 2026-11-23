import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';
import 'package:labs/services/notification_service.dart';

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// PUSH-2 T-5: the local-notification surface.
///
/// Two harnesses:
/// 1. The REAL plugin over a mocked method channel (`log`) — asserts actual
///    channel traffic (initialize/show + payloads), preserving the original
///    tests unchanged.
/// 2. A mocktail-injected plugin via `pluginForTest` — captures the tap
///    callback so the T-5 tap wiring is driven END-TO-END through
///    `PushNotificationService.handleTapData` (the real routing pipeline).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final List<MethodCall> log = <MethodCall>[];
  late _MockLocalNotifications mockPlugin;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
  });

  setUp(() {
    log.clear();
    PushNotificationService.resetForTest();
    PushNotificationService.loggerForTest = LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    );
    // Reset the idempotency seam so each test re-drives initialize().
    LocalNotificationService.pluginForTest = null;
    mockPlugin = _MockLocalNotifications();
    when(
      () => mockPlugin.initialize(
        any(),
        onDidReceiveNotificationResponse: captureAny(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall? methodCall) async {
          if (methodCall != null) {
            log.add(methodCall);
          }
          switch (methodCall?.method) {
            case 'initialize':
              return true;
            case 'show':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    LocalNotificationService.pluginForTest = null;
  });

  group('LocalNotificationService', () {
    test('initialize sends correct method channel call', () async {
      await LocalNotificationService.initialize();
      expect(log.length, greaterThanOrEqualTo(1));
      expect(log[0].method, 'initialize');
    });

    test(
      'showOrderStatusNotification sends show method channel call',
      () async {
        await LocalNotificationService.showOrderStatusNotification(
          'order1',
          'Your order is ready',
        );
        expect(log.any((call) => call.method == 'show'), isTrue);
      },
    );

    test('showOrderStatusNotification includes orderId in payload', () async {
      await LocalNotificationService.showOrderStatusNotification(
        'ABC-123',
        'Order confirmed',
      );
      final showCall = log.firstWhere((call) => call.method == 'show');
      final args = Map<String, Object?>.from(showCall.arguments as Map);
      expect(args['payload'], 'ABC-123');
    });

    test('showOrderStatusNotification sends payload and arguments', () async {
      await LocalNotificationService.showOrderStatusNotification(
        'order1',
        'Your order has been delivered',
      );
      final showCall = log.firstWhere((call) => call.method == 'show');
      expect(showCall.arguments, isNotNull);
    });

    test('showOrderStatusNotification sends a Map payload', () async {
      await LocalNotificationService.showOrderStatusNotification(
        'order1',
        'Ready',
      );
      final showCall = log.firstWhere((call) => call.method == 'show');
      expect(showCall.arguments, isA<Map<Object?, Object?>>());
    });

    test('showOrderStatusNotification payload contains payload key', () async {
      await LocalNotificationService.showOrderStatusNotification(
        'order1',
        'Your order is ready',
      );
      final showCall = log.firstWhere((call) => call.method == 'show');
      final args = Map<String, Object?>.from(showCall.arguments as Map);
      expect(args.containsKey('payload'), isTrue);
    });

    test('initialize calls with arguments', () async {
      await LocalNotificationService.initialize();
      expect(log.length, greaterThanOrEqualTo(1));
      final initCall = log.firstWhere((call) => call.method == 'initialize');
      expect(initCall.arguments, isNotNull);
    });
  });

  group('LocalNotificationService (PUSH-2 lifecycle + T-5 tap wiring)', () {
    test(
      'initialize is IDEMPOTENT: the channel init runs exactly once',
      () async {
        await LocalNotificationService.initialize();
        await LocalNotificationService.initialize();
        await LocalNotificationService.initialize();
        expect(
          log.where((call) => call.method == 'initialize').length,
          1,
          reason:
              'checkout re-initializes before every show — the plugin setup and '
              'tap handler must be wired exactly once',
        );
      },
    );

    test(
      'initialize wires a tap handler (T-5: previously a dead end)',
      () async {
        LocalNotificationService.pluginForTest = mockPlugin;
        await LocalNotificationService.initialize();
        final captured = verify(
          () => mockPlugin.initialize(
            any(),
            onDidReceiveNotificationResponse: captureAny(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).captured;
        expect(captured.single, isNotNull);
      },
    );

    test(
      'tapping a local notification routes {orderId: payload} end-to-end',
      () async {
        LocalNotificationService.pluginForTest = mockPlugin;
        await LocalNotificationService.initialize();
        final callback =
            verify(
                  () => mockPlugin.initialize(
                    any(),
                    onDidReceiveNotificationResponse: captureAny(
                      named: 'onDidReceiveNotificationResponse',
                    ),
                  ),
                ).captured.single
                as DidReceiveNotificationResponseCallback;

        final tappedPaths = <String>[];
        PushNotificationService.navigationHandler = (path) async =>
            tappedPaths.add(path);

        callback(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'TAP-1',
          ),
        );
        expect(
          tappedPaths,
          <String>['/orders/TAP-1'],
          reason:
              'tapping "Order Confirmed" must open the order tracker through '
              'the SAME validated push bridge as FCM taps (PUSH-2 P-2)',
        );
      },
    );

    test('tap with an empty payload is dropped, never navigates', () async {
      LocalNotificationService.pluginForTest = mockPlugin;
      await LocalNotificationService.initialize();
      final callback =
          verify(
                () => mockPlugin.initialize(
                  any(),
                  onDidReceiveNotificationResponse: captureAny(
                    named: 'onDidReceiveNotificationResponse',
                  ),
                ),
              ).captured.single
              as DidReceiveNotificationResponseCallback;

      final tappedPaths = <String>[];
      PushNotificationService.navigationHandler = (path) async =>
          tappedPaths.add(path);

      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        ),
      );
      expect(tappedPaths, isEmpty);
    });
  });
}
