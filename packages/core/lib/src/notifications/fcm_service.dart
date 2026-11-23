import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;

class FcmService {
  final FirebaseMessaging _fcm;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Creates an [FcmService] with injectable dependencies.
  ///
  /// In production: `FcmService(fcm: FirebaseMessaging.instance)`
  /// In tests: provide mocked dependencies.
  FcmService({
    FirebaseMessaging? fcm,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _fcm = fcm ?? FirebaseMessaging.instance,
       _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  Future<void> init() async {
    // PUSH-2 P-4: the OS notification consent dialog is NEVER shown from
    // app-boot init(). A boot-time prompt is a store-rejection pattern (Apple
    // HIG + Google Play policy) and burns the one-shot permission before the
    // user understands its value. Here we only OBSERVE the current
    // authorization state: upload the token iff the app is ALREADY authorized
    // (from an earlier contextual grant), otherwise stay silent — no dialog,
    // no token write without consent. The contextual prompt surface is a
    // separate task's concern (UX chain), not this service's.
    final NotificationSettings settings = await _fcm.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('FCM permission already granted');
      await _uploadToken();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        unawaited(_saveTokenToFirestore(newToken));
      });
    } else {
      developer.log(
        'FCM permission not granted (${settings.authorizationStatus}); '
        'skipping token upload (no write without consent)',
      );
    }
  }

  Future<void> _uploadToken() async {
    try {
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e, stack) {
      developer.log('Error fetching FCM Token', error: e, stackTrace: stack);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmLastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e, stack) {
      // Non-fatal: token refresh will retry next time. Log + continue.
      // P4-01 (LAW 8): never let an unhandled Firestore write escape the
      // token-refresh stream and crash the SDK listener.
      developer.log('FCM token save failed', error: e, stackTrace: stack);
    }
  }
}
