import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:core/core.dart';

import 'helpers/mock_firebase.dart';

/// CORE-COV Tier-2 NOTIFICATIONS suite (PUSH-2 P-4): boot init() must NEVER
/// prompt for OS notification consent — it only observes the current
/// authorization state and uploads the token IFF the app is ALREADY
/// authorized. Token writes merge into users/{uid} and never clobber.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseMessaging messaging;
  late MockFirebaseAuth auth;
  late MockFirebaseUser user;
  late MockNotificationSettings settings;
  late FakeFirebaseFirestore db;
  late FcmService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    messaging = MockFirebaseMessaging();
    auth = MockFirebaseAuth();
    user = MockFirebaseUser();
    settings = MockNotificationSettings();
    db = FakeFirebaseFirestore();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('u1');
    when(
      () => messaging.onTokenRefresh,
    ).thenAnswer((_) => const Stream<String>.empty());
    service = FcmService(fcm: messaging, db: db, auth: auth);
  });

  Future<void> onAuthorizedSettings() async {
    when(
      () => settings.authorizationStatus,
    ).thenReturn(AuthorizationStatus.authorized);
    when(
      () => messaging.getNotificationSettings(),
    ).thenAnswer((_) async => settings);
    when(() => messaging.getToken()).thenAnswer((_) async => 'tok-1');
  }

  test(
    'init never prompts: notDetermined → no token fetch, no users write',
    () async {
      when(
        () => settings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.notDetermined);
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => settings);

      await service.init();

      verifyNever(() => messaging.getToken());
      expect((await db.collection('users').get()).docs, isEmpty);
    },
  );

  test(
    'init never prompts: declined → no token fetch, no users write',
    () async {
      when(
        () => settings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.denied);
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => settings);

      await service.init();

      verifyNever(() => messaging.getToken());
      expect((await db.collection('users').get()).docs, isEmpty);
    },
  );

  test(
    'an existing grant uploads the token as a MERGE (other fields survive)',
    () async {
      await db.collection('users').doc('u1').set(<String, dynamic>{
        'name': 'Staff',
      });
      await onAuthorizedSettings();

      await service.init();

      final doc = await db.collection('users').doc('u1').get();
      expect(doc.data()!['fcmToken'], 'tok-1');
      expect(doc.data()!['fcmLastUpdated'], isA<Timestamp>());
      expect(doc.data()!['name'], 'Staff');
    },
  );

  test('token refresh re-saves through the stream listener', () async {
    await onAuthorizedSettings();
    final controller = StreamController<String>();
    when(() => messaging.onTokenRefresh).thenAnswer((_) => controller.stream);

    await service.init();
    controller.add('tok-2');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await controller.close();

    final doc = await db.collection('users').doc('u1').get();
    expect(doc.data()!['fcmToken'], 'tok-2');
  });

  test(
    'a failing token fetch is non-fatal (P4-01 — init still completes)',
    () async {
      await onAuthorizedSettings();
      when(() => messaging.getToken()).thenThrow(StateError('messaging down'));

      await service.init();

      // Reached here — the error was contained (developer.log path, no throw).
      expect((await db.collection('users').get()).docs, isEmpty);
    },
  );
}
