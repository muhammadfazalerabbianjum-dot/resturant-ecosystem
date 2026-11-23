import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:core/src/notifications/fcm_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockFcmAuth extends Mock implements FirebaseAuth {}

class _MockFcmUser extends Mock implements User {}

void main() {
  late FcmService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    service = FcmService();
  });

  group('FcmService - Construction', () {
    test('Service can be instantiated with default constructor', () {
      final svc = FcmService();
      expect(svc, isNotNull);
    });

    test('Service can be instantiated with injected dependencies', () {
      final svc = FcmService(
        fcm: FirebaseMessaging.instance,
        db: FirebaseFirestore.instance,
        auth: FirebaseAuth.instance,
      );
      expect(svc, isNotNull);
    });

    test('Service can be created with partial dependencies (only fcm)', () {
      final svc = FcmService(fcm: FirebaseMessaging.instance);
      expect(svc, isNotNull);
    });

    test('Service can be created with only Firestore override', () {
      final svc = FcmService(db: FirebaseFirestore.instance);
      expect(svc, isNotNull);
    });

    test('Service can be created with only Auth override', () {
      final svc = FcmService(auth: FirebaseAuth.instance);
      expect(svc, isNotNull);
    });
  });

  group('FcmService - Method Signatures', () {
    test('init method returns Future<void>', () {
      expect(service.init, isA<Future<void> Function()>());
    });

    test('Service has correct type for init method', () {
      expect(service.init.runtimeType.toString(), contains('Future<void>'));
    });
  });

  group('FcmService - Constructor defaults', () {
    test('default constructor does not crash', () {
      final svc = FcmService();
      expect(svc, isNotNull);
    });

    test('service can be created then recreated', () {
      final s1 = FcmService();
      final s2 = FcmService();
      expect(s1, isNotNull);
      expect(s2, isNotNull);
    });
  });

  group('FcmService - Edge Cases', () {
    test('FcmService accepts null db parameter', () {
      // The constructor uses ?? fallback, so null should be handled
      final svc = FcmService(db: null);
      expect(svc, isNotNull);
    });

    test('FcmService accepts null auth parameter', () {
      final svc = FcmService(auth: null);
      expect(svc, isNotNull);
    });

    test('FcmService accepts null fcm parameter', () {
      final svc = FcmService(fcm: null);
      expect(svc, isNotNull);
    });
  });

  group(
    'FcmService — self-healing re-upload after signOut (01-P1-D, batch RULES-2)',
    () {
      test(
        'init() after signOut re-writes a fresh fcmToken to users/{uid}',
        () async {
          final fcm = _MockFirebaseMessaging();
          final auth = _MockFcmAuth();
          final user = _MockFcmUser();
          when(() => user.uid).thenReturn('uid_relogin');
          when(() => auth.currentUser).thenReturn(user);
          // PUSH-2 P-4: init() only OBSERVES consent - the OS consent dialog is never
          // shown from boot. The stub answers getNotificationSettings instead.
          when(() => fcm.getNotificationSettings()).thenAnswer(
            (_) async => const NotificationSettings(
              authorizationStatus: AuthorizationStatus.authorized,
              alert: AppleNotificationSetting.enabled,
              announcement: AppleNotificationSetting.disabled,
              badge: AppleNotificationSetting.enabled,
              carPlay: AppleNotificationSetting.disabled,
              criticalAlert: AppleNotificationSetting.disabled,
              lockScreen: AppleNotificationSetting.enabled,
              notificationCenter: AppleNotificationSetting.enabled,
              providesAppNotificationSettings:
                  AppleNotificationSetting.disabled,
              showPreviews: AppleShowPreviewSetting.always,
              sound: AppleNotificationSetting.enabled,
              timeSensitive: AppleNotificationSetting.disabled,
            ),
          );
          when(() => fcm.getToken()).thenAnswer((_) async => 'fresh-token-123');
          when(
            () => fcm.onTokenRefresh,
          ).thenAnswer((_) => const Stream.empty());

          final db = FakeFirebaseFirestore();
          final svc = FcmService(fcm: fcm, db: db, auth: auth);

          await svc.init();

          final doc = await db.collection('users').doc('uid_relogin').get();
          expect(doc.data(), isNotNull);
          expect(
            doc.data()!['fcmToken'],
            equals('fresh-token-123'),
            reason:
                'the next login re-uploads the token — self-healing covers '
                'the best-effort signOut deletion (auth_repository.dart)',
          );
          expect(doc.data()!['fcmLastUpdated'], isNotNull);
        },
      );

      test(
        'declined permission never writes a token (no write without consent)',
        () async {
          final fcm = _MockFirebaseMessaging();
          final auth = _MockFcmAuth();
          final user = _MockFcmUser();
          when(() => user.uid).thenReturn('uid_declined');
          when(() => auth.currentUser).thenReturn(user);
          // PUSH-2 P-4: init() only OBSERVES consent - the OS consent dialog is never
          // shown from boot. The stub answers getNotificationSettings instead.
          when(() => fcm.getNotificationSettings()).thenAnswer(
            (_) async => const NotificationSettings(
              authorizationStatus: AuthorizationStatus.denied,
              alert: AppleNotificationSetting.disabled,
              announcement: AppleNotificationSetting.disabled,
              badge: AppleNotificationSetting.disabled,
              carPlay: AppleNotificationSetting.disabled,
              criticalAlert: AppleNotificationSetting.disabled,
              lockScreen: AppleNotificationSetting.disabled,
              notificationCenter: AppleNotificationSetting.disabled,
              providesAppNotificationSettings:
                  AppleNotificationSetting.disabled,
              showPreviews: AppleShowPreviewSetting.never,
              sound: AppleNotificationSetting.disabled,
              timeSensitive: AppleNotificationSetting.disabled,
            ),
          );

          final db = FakeFirebaseFirestore();
          final svc = FcmService(fcm: fcm, db: db, auth: auth);

          await svc.init();

          // PUSH-2 P-4 proof: the boot path never triggers the OS consent
          // dialog - not even when permission is already denied.
          verifyNever(
            () => fcm.requestPermission(
              alert: any(named: 'alert'),
              announcement: any(named: 'announcement'),
              badge: any(named: 'badge'),
              carPlay: any(named: 'carPlay'),
              criticalAlert: any(named: 'criticalAlert'),
              provisional: any(named: 'provisional'),
              sound: any(named: 'sound'),
            ),
          );

          final doc = await db.collection('users').doc('uid_declined').get();
          expect(
            doc.exists,
            isFalse,
            reason: 'no token is fetched/uploaded when permission is declined',
          );
        },
      );
    },
  );
}
