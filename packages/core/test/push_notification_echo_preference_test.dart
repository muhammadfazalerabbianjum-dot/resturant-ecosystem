import 'dart:async';
import 'dart:io';

import 'package:core/core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// UI-15 (p24) T-3 / `F3-04` — the END-USER notification preference.
///
/// The preference is one stored boolean; its ONLY shipped consumer is the
/// foreground local-echo path in [PushNotificationService] (the `listen(...)`
/// at `push_notification_service.dart:205-208` → `_onForegroundMessage`).
/// These tests drive the service through its real injectable seams (the
/// foreground stream + the local-notification plugin) and assert the ECHO —
/// not the write — so a key nothing reads can never pass as green (L-P1).
///
/// The stored key literal is the on-disk wire format the settings layer
/// writes (`PushNotificationService.foregroundEchoPreferenceKey`). Background
/// and tap delivery must be untouched by the preference: this is a
/// client-side courtesy switch, NOT a server unsubscribe (D-P24-1 option (a)).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String echoKey = 'settings_foreground_echo_enabled';

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

  /// Same real-time settle the PUSH-2 suite uses: echo handling crosses real
  /// file-IO awaits (LoggerService) plus stream microtasks.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  /// Awaits the ACTUAL echo (the mock's `show()`) with a fail-loud deadline —
  /// awaiting the real signal, never a tuned delay (15-tests).
  Future<void> awaitEcho() =>
      echoSeen.future.timeout(const Duration(seconds: 5));

  /// Awaits the ACTUAL navigation callback with a fail-loud deadline.
  Future<void> awaitNav() => navSeen.future.timeout(const Duration(seconds: 5));

  Future<void> initService({
    StreamController<RemoteMessage>? foreground,
    StreamController<RemoteMessage>? opened,
  }) async {
    await PushNotificationService.initialize(
      localNotifications: plugin,
      foregroundMessages: foreground?.stream ?? const Stream.empty(),
      openedMessages: opened?.stream ?? const Stream.empty(),
      initialMessage: Future<RemoteMessage?>.value(),
    );
  }

  void verifyNoEcho() => verifyNever(
    () =>
        plugin.show(any(), any(), any(), any(), payload: any(named: 'payload')),
  );

  void verifyOneEcho() => verify(
    () =>
        plugin.show(any(), any(), any(), any(), payload: any(named: 'payload')),
  ).called(1);

  group('p24 T-3 — the stored echo preference gates the foreground echo', () {
    test('preference OFF produces ZERO local echoes for a push', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{echoKey: false});
      final foreground = StreamController<RemoteMessage>();
      await initService(foreground: foreground);

      foreground.add(
        message(<String, dynamic>{'orderId': 'ECHO-OFF', 'status': 'ready'}),
      );
      await settle();
      await foreground.close();

      verifyNoEcho();
    });

    test('preference ON produces exactly ONE local echo', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{echoKey: true});
      final foreground = StreamController<RemoteMessage>();
      await initService(foreground: foreground);

      foreground.add(
        message(<String, dynamic>{'orderId': 'ECHO-ON', 'status': 'ready'}),
      );
      await awaitEcho();
      await foreground.close();

      verifyOneEcho();
    });

    test(
      'no stored preference keeps the echo (L-P2: today, unchanged)',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final foreground = StreamController<RemoteMessage>();
        await initService(foreground: foreground);

        foreground.add(
          message(<String, dynamic>{'orderId': 'ECHO-DEF', 'status': 'ready'}),
        );
        await awaitEcho();
        await foreground.close();

        verifyOneEcho();
      },
    );

    test('a non-bool stored value falls back to the echo (L-P2)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        echoKey: 'yes-please',
      });
      final foreground = StreamController<RemoteMessage>();
      await initService(foreground: foreground);

      foreground.add(
        message(<String, dynamic>{'orderId': 'ECHO-BAD', 'status': 'ready'}),
      );
      await awaitEcho();
      await foreground.close();

      verifyOneEcho();
    });

    test(
      'the preference never gates TAP delivery: echo OFF still navigates',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          echoKey: false,
        });
        final opened = StreamController<RemoteMessage>();
        await initService(opened: opened);

        opened.add(
          message(<String, dynamic>{'orderId': 'TAP-OFF', 'status': 'ready'}),
        );
        await awaitNav();
        await opened.close();

        expect(
          tappedPaths,
          <String>['/orders/TAP-OFF'],
          reason:
              'the switch is a client-side echo courtesy, not a delivery '
              'kill-switch (D-P24-1 option (a)): taps keep working',
        );
      },
    );
  });
}
