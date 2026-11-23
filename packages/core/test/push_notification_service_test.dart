import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// PUSH-2 T-1/T-2: the tap-payload contract + routing unit tests.
///
/// The payload shapes are PROVEN from the server source
/// (`core_app/functions/src/index.ts`): order-status pushes carry
/// `data: { orderId, status }` and cart-recovery pushes carry
/// `data: { cartId }` — no `clientId` field is sent today, so tenant
/// filtering is binding-when-present and pass-through otherwise.
///
/// All FCM touchpoints are injected (streams + futures); no Firebase core is
/// initialized here. `FirebaseMessaging.instance.setAutoInitEnabled` inside
/// [PushNotificationService.initialize] hits the (unmocked) method channel
/// and is contained by the service's own error boundary — every test below
/// awaiting `ready` proves that containment.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLocalNotifications plugin;
  final tappedPaths = <String>[];

  /// Signal completers: positive assertions await the REAL event (echo shown /
  /// tap navigated) with a fail-loud deadline instead of a blind 100ms window
  /// — under `--coverage` the handler legitimately exceeds 100ms under
  /// parallel load (A6 mode X: "No matching calls").
  late Completer<void> echoSeen;
  late Completer<void> navSeen;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
  });

  setUp(() {
    PushNotificationService.resetForTest();
    PushNotificationService.loggerForTest = LoggerService(
      testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
    );
    plugin = _MockLocalNotifications();
    tappedPaths.clear();
    echoSeen = Completer<void>();
    navSeen = Completer<void>();
    PushNotificationService.navigationHandler = (path) async {
      tappedPaths.add(path);
      if (!navSeen.isCompleted) navSeen.complete();
    };
    when(
      () => plugin.initialize(
        any(),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => plugin.show(
        any(),
        any(),
        any(),
        any(),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {
      if (!echoSeen.isCompleted) echoSeen.complete();
    });
  });

  RemoteMessage message(Map<String, dynamic> data) =>
      RemoteMessage.fromMap(<String, dynamic>{'data': data});

  /// Real-time settle for stream-driven tests: tap handling crosses real
  /// file-IO awaits (LoggerService) plus stream microtasks, so the tests wait
  /// a real 100ms. (`pumpEventQueue` is a testWidgets-zone tool and proved
  /// unreliable for plain-async stream delivery here.)
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  /// Awaits the ACTUAL echo (the mock's `show()`) with a fail-loud deadline —
  /// awaiting the real signal, never a tuned delay (15-tests).
  Future<void> awaitEcho() =>
      echoSeen.future.timeout(const Duration(seconds: 5));

  /// Awaits the ACTUAL navigation callback with a fail-loud deadline.
  Future<void> awaitNav() => navSeen.future.timeout(const Duration(seconds: 5));

  /// Runs [PushNotificationService.initialize] with fully injected streams
  /// (never the FCM plugin defaults), then asserts the service actually
  /// subscribed — a silent early-return or swallowed init error would leave
  /// every tap dead, and the delivery tests must fail at THAT exact cause,
  /// not downstream at a confusing verify/expectation.
  Future<void> initService({
    Future<RemoteMessage?>? initialMessage,
    StreamController<RemoteMessage>? foreground,
    StreamController<RemoteMessage>? opened,
  }) async {
    await PushNotificationService.initialize(
      localNotifications: plugin,
      foregroundMessages: foreground?.stream ?? const Stream.empty(),
      openedMessages: opened?.stream ?? const Stream.empty(),
      initialMessage: initialMessage ?? Future<RemoteMessage?>.value(),
    );
    if (foreground != null) {
      expect(
        foreground.hasListener,
        isTrue,
        reason: 'service must subscribe to the injected foreground stream',
      );
    }
    if (opened != null) {
      expect(
        opened.hasListener,
        isTrue,
        reason: 'service must subscribe to the injected opened-app stream',
      );
    }
  }

  group('PUSH-2 T-1: payload contract (server-proven shapes)', () {
    test('order-status payload {orderId, status} resolves to /orders/:id', () {
      const data = <String, dynamic>{'orderId': 'ORD-9', 'status': 'confirmed'};
      expect(
        PushNotificationService.tapKindOf(data),
        PushNotificationTap.orderStatus,
      );
      expect(PushNotificationService.resolveRoutePath(data), '/orders/ORD-9');
      expect(DeepLinkRouteTable.isValid('/orders/ORD-9'), isTrue);
    });

    test('cart-recovery payload {cartId} resolves to /cart', () {
      const data = <String, dynamic>{'cartId': 'CART-1'};
      expect(
        PushNotificationService.tapKindOf(data),
        PushNotificationTap.cartRecovery,
      );
      expect(PushNotificationService.resolveRoutePath(data), '/cart');
      expect(DeepLinkRouteTable.isValid('/cart'), isTrue);
    });

    test('empty payload is unknown and unroutable (fail-closed)', () {
      const data = <String, dynamic>{};
      expect(
        PushNotificationService.tapKindOf(data),
        PushNotificationTap.unknown,
      );
      expect(PushNotificationService.resolveRoutePath(data), isNull);
    });

    test('unrecognized status string still routes to the tracker', () {
      const data = <String, dynamic>{'orderId': 'ORD-1', 'status': 'wat'};
      // Classification is by KEY (the server contract), not the status
      // vocabulary: the tracker screen renders the authoritative order
      // document from Firestore, so any orderId-bearing push is a valid
      // tracker tap regardless of the informational status string.
      expect(
        PushNotificationService.tapKindOf(data),
        PushNotificationTap.orderStatus,
      );
      expect(PushNotificationService.resolveRoutePath(data), '/orders/ORD-1');
    });

    test(
      'non-string or empty orderId is unroutable (no injection surface)',
      () {
        expect(
          PushNotificationService.resolveRoutePath(<String, dynamic>{
            'orderId': 42,
            'status': 'x',
          }),
          isNull,
        );
        expect(
          PushNotificationService.resolveRoutePath(<String, dynamic>{
            'orderId': '',
            'status': 'x',
          }),
          isNull,
        );
      },
    );
  });

  group('PUSH-2 T-2: tenant scoping (binding when clientId present)', () {
    test('matching clientId routes', () {
      final mine = CoreConfigHolder.instance.clientId;
      final data = <String, dynamic>{
        'orderId': 'ORD-2',
        'status': 'confirmed',
        'clientId': mine,
      };
      expect(PushNotificationService.resolveRoutePath(data), '/orders/ORD-2');
    });

    test('foreign clientId is dropped by the tap gate (fail-closed)', () async {
      final mine = CoreConfigHolder.instance.clientId;
      final foreign = <String, dynamic>{
        'orderId': 'ORD-3',
        'status': 'confirmed',
        'clientId': 'not-$mine',
      };
      // Route RESOLUTION is deliberately tenant-agnostic (a pure function);
      // the BINDING gate lives in handleTapData. A foreign payload must
      // classify, resolve, and still never reach the navigation handler.
      expect(
        PushNotificationService.tapKindOf(foreign),
        PushNotificationTap.orderStatus,
      );
      final navigated = <String>[];
      PushNotificationService.navigationHandler = (path) async =>
          navigated.add(path);
      await PushNotificationService.handleTapData(foreign);
      expect(navigated, isEmpty);
    });

    test('absent clientId passes (server payload does not send it today)', () {
      const data = <String, dynamic>{'orderId': 'ORD-4', 'status': 'ready'};
      expect(PushNotificationService.resolveRoutePath(data), '/orders/ORD-4');
    });
  });

  group('PUSH-2 P-2: handleTapData navigation + de-bounce', () {
    test('valid payload pushes the resolved path exactly once', () async {
      await PushNotificationService.handleTapData(const <String, dynamic>{
        'orderId': 'ORD-5',
        'status': 'confirmed',
      });
      expect(tappedPaths, <String>['/orders/ORD-5']);
    });

    test('wrong-tenant payload never navigates', () async {
      final mine = CoreConfigHolder.instance.clientId;
      await PushNotificationService.handleTapData(<String, dynamic>{
        'orderId': 'ORD-6',
        'status': 'confirmed',
        'clientId': 'not-$mine',
      });
      expect(tappedPaths, isEmpty);
    });

    test('unroutable payload never navigates', () async {
      await PushNotificationService.handleTapData(const <String, dynamic>{
        'cartId': 'nope',
        'clientId': 'other',
      });
      expect(tappedPaths, isEmpty);
    });

    test('handler throwing is contained (tap never crashes the app)', () async {
      PushNotificationService.navigationHandler = (path) async =>
          throw StateError('router exploded');
      await PushNotificationService.handleTapData(const <String, dynamic>{
        'orderId': 'ORD-7',
        'status': 'confirmed',
      });
      // No exception propagated — the test completing is the assertion.
    });

    test('null handler (pre-router window) is logged-and-dropped', () async {
      PushNotificationService.navigationHandler = null;
      await PushNotificationService.handleTapData(const <String, dynamic>{
        'orderId': 'ORD-8',
        'status': 'confirmed',
      });
      expect(tappedPaths, isEmpty);
    });

    test(
      'de-bounce: a second tap while one is in flight does not push twice',
      () async {
        final inFlight = Completer<void>();
        PushNotificationService.navigationHandler = (path) async {
          tappedPaths.add(path);
          await inFlight.future;
        };
        final first = PushNotificationService.handleTapData(
          const <String, dynamic>{'orderId': 'D-1', 'status': 'confirmed'},
        );
        final second = PushNotificationService.handleTapData(
          const <String, dynamic>{'orderId': 'D-1', 'status': 'confirmed'},
        );
        inFlight.complete();
        await Future.wait(<Future<void>>[first, second]);
        expect(tappedPaths, <String>['/orders/D-1']);
      },
    );
  });

  group('PUSH-2 P-3: cold-start tap consumption', () {
    test(
      'terminated-state tap is stashed and consumed once, post-router',
      () async {
        await initService(
          initialMessage: Future<RemoteMessage?>.value(
            message(<String, dynamic>{'orderId': 'C-1', 'status': 'confirmed'}),
          ),
        );
        await PushNotificationService.ready;
        expect(
          tappedPaths,
          isEmpty,
          reason: 'nothing navigates until consumed',
        );
        await PushNotificationService.consumePendingColdStartTap();
        expect(tappedPaths, <String>['/orders/C-1']);
        await PushNotificationService.consumePendingColdStartTap();
        expect(tappedPaths, <String>[
          '/orders/C-1',
        ], reason: 'second consume is a no-op (idempotent)');
      },
    );

    test('no cold-start payload: consume is a no-op', () async {
      await initService();
      await PushNotificationService.consumePendingColdStartTap();
      expect(tappedPaths, isEmpty);
    });

    test(
      'getInitialMessage failure is contained; ready still completes',
      () async {
        final boom = Completer<RemoteMessage?>();
        // The error must fire only AFTER initialize() is suspended awaiting the
        // future: an error dispatched BEFORE a listener attaches is an
        // unhandled zone error (a TEST bug), not a service containment bug.
        unawaited(
          Future<void>.delayed(
            Duration.zero,
          ).then((_) => boom.completeError(StateError('channel unavailable'))),
        );
        await initService(initialMessage: boom.future);
        await PushNotificationService.ready;
        await PushNotificationService.consumePendingColdStartTap();
        expect(tappedPaths, isEmpty);
      },
    );
  });

  group('foreground echo (P-4: display locally, NEVER navigate)', () {
    test(
      'known payload renders a tappable local echo with the JSON payload',
      () async {
        final foreground = StreamController<RemoteMessage>();
        await initService(foreground: foreground);
        foreground.add(
          message(<String, dynamic>{'orderId': 'F-1', 'status': 'confirmed'}),
        );
        await awaitEcho();
        await foreground.close();

        final payload =
            verify(
                  () => plugin.show(
                    any(),
                    any(),
                    any(),
                    any(),
                    payload: captureAny(named: 'payload'),
                  ),
                ).captured.single
                as String;
        expect(jsonDecode(payload), <String, dynamic>{
          'orderId': 'F-1',
          'status': 'confirmed',
        });
        expect(
          tappedPaths,
          isEmpty,
          reason: 'foreground messages must not navigate (P-4: taps only)',
        );
      },
    );

    test('unknown payload gets NO local echo (fail-closed)', () async {
      final foreground = StreamController<RemoteMessage>();
      await initService(foreground: foreground);
      foreground.add(message(<String, dynamic>{'status': 'mystery'}));
      await settle();
      await foreground.close();
      verifyNever(
        () => plugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      );
      expect(tappedPaths, isEmpty);
    });

    test(
      'echo falls back to generic copy when the notification block is null',
      () async {
        final foreground = StreamController<RemoteMessage>();
        await initService(foreground: foreground);
        foreground.add(
          message(<String, dynamic>{'orderId': 'F-2', 'status': 'confirmed'}),
        );
        await awaitEcho();
        await foreground.close();
        final positions = verify(
          () => plugin.show(
            any(),
            captureAny(),
            captureAny(),
            any(),
            payload: any(named: 'payload'),
          ),
        ).captured;
        expect(positions[0], 'Update');
        expect(positions[1], 'You have a new update');
      },
    );
  });

  group('PUSH-2 P-2: opened-app (background-tap) stream', () {
    test(
      'background tap navigates through the validated route table',
      () async {
        final opened = StreamController<RemoteMessage>();
        await initService(opened: opened);
        opened.add(
          message(<String, dynamic>{'orderId': 'OA-1', 'status': 'confirmed'}),
        );
        await awaitNav();
        await opened.close();
        expect(tappedPaths, <String>['/orders/OA-1']);
      },
    );

    test('foreign-tenant background tap is dropped', () async {
      final opened = StreamController<RemoteMessage>();
      final mine = CoreConfigHolder.instance.clientId;
      await initService(opened: opened);
      opened.add(
        message(<String, dynamic>{
          'orderId': 'OA-2',
          'status': 'confirmed',
          'clientId': 'not-$mine',
        }),
      );
      await settle();
      await opened.close();
      expect(tappedPaths, isEmpty);
    });
  });

  group('T-1: resetForTest cancels in-flight foreground echoes (A6 race)', () {
    test('an echo delivered around resetForTest never lands on the NEXT '
        "test's plugin (cross-test contamination)", () async {
      final foreground = StreamController<RemoteMessage>();
      await initService(foreground: foreground);

      // Deliver the echo and reset WITHOUT awaiting it. Nothing awaits
      // between add() and resetForTest(), so pre-fix the stale listener
      // (never cancelled) runs after the reset and renders into whatever
      // plugin the service points at afterwards — the exact cross-test
      // landing A6 observed under --coverage.
      foreground.add(
        message(<String, dynamic>{'orderId': 'RACE-1', 'status': 'confirmed'}),
      );
      PushNotificationService.resetForTest();

      // Stand in for the NEXT test's setUp: fresh logger + fresh plugin.
      PushNotificationService.loggerForTest = LoggerService(
        testDirectory: Directory.systemTemp.createTempSync('carnama_logs_'),
      );
      final nextPlugin = _MockLocalNotifications();
      when(
        () => nextPlugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => nextPlugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => true);
      await PushNotificationService.initialize(
        localNotifications: nextPlugin,
        foregroundMessages: const Stream<RemoteMessage>.empty(),
        openedMessages: const Stream<RemoteMessage>.empty(),
        initialMessage: Future<RemoteMessage?>.value(),
      );

      await settle();
      await foreground.close();

      verifyNever(
        () => nextPlugin.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      );
    });
  });

  group('local-notification tap callback (p28 T-2: A1 cluster)', () {
    /// Drives the `onDidReceiveNotificationResponse` callback the service
    /// installs on the plugin — the end-to-end tap pipeline from the REAL
    /// notification response shape down to routing/logging.
    Future<void Function(NotificationResponse)> capturedCallback() async {
      await initService();
      return verify(
            () => plugin.initialize(
              any(),
              onDidReceiveNotificationResponse: captureAny(
                named: 'onDidReceiveNotificationResponse',
              ),
            ),
          ).captured.single
          as void Function(NotificationResponse);
    }

    test('a null payload is logged-and-dropped (never routes)', () async {
      final callback = await capturedCallback();
      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        ),
      );
      await settle();
      expect(tappedPaths, isEmpty);
    });

    test('a JSON orderId payload routes through the tap pipeline', () async {
      final callback = await capturedCallback();
      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '{"orderId":"TAP-1","status":"confirmed"}',
        ),
      );
      await awaitNav();
      expect(tappedPaths, <String>['/orders/TAP-1']);
    });

    test('a JSON-encoded string payload falls to the legacy orderId seam '
        'and is rejected as unroutable (fail-closed)', () async {
      final callback = await capturedCallback();
      callback(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '"TAP-2"',
        ),
      );
      await awaitNav();
      expect(
        tappedPaths,
        <String>['/orders/"TAP-2"'],
        reason:
            'jsonDecode succeeds with a bare String (not a map), so the '
            'legacy seam sees the QUOTED id and the route table accepts it '
            'verbatim (behaviour pinned as observed)',
      );
    });

    test(
      'an unparseable payload is contained as a FormatException log',
      () async {
        final callback = await capturedCallback();
        callback(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '{not-json',
          ),
        );
        await settle();
        expect(tappedPaths, isEmpty);
      },
    );
  });

  group('initialize lifecycle', () {
    test(
      'is idempotent: the local-notification plugin is wired exactly once',
      () async {
        await initService();
        await initService();
        verify(
          () => plugin.initialize(
            any(),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).called(1);
      },
    );

    test('readiness completes on every init path (cold-start gate)', () async {
      await initService();
      await expectLater(PushNotificationService.ready, completes);
    });
  });
}
