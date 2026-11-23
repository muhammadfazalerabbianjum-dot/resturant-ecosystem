import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async' show unawaited;
import 'package:core/src/auth/user_model.dart';
import 'package:core/src/cache/local_cache.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/error_logger/logger_provider.dart';
import 'package:core/src/error_logger/firebase_exception_mapper.dart';
import 'package:core/src/network/network_retry.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;

// Core's auth API SPEAKS these types (`Stream<User?> authStateChanges()`, the
// typed `FirebaseAuthException` signUp rethrows, the `FirebaseException` type
// test the signup screen runs on its generic catch), so they are part of this
// library's public surface: consumers take them from HERE, never from the SDK.
// That is what keeps `core_app/lib` at zero direct firebase_auth imports
// (Law 12/DI — instances stay behind the repository). `FirebaseException` is
// the identical element firebase_core exports, so files importing both never
// see an ambiguity.
export 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, FirebaseException, User;

abstract class AuthRepository {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserModel?> getUserData(String uid);
  Future<void> signInAnonymously();
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> signUp(String email, String password, String name);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LoggerService _logger;
  final LocalCache _cache;
  final void Function()? _onSignOutNavigated;

  /// P2-1a (D-050): [cache] is REQUIRED. The auth repository used to call
  /// `IsarService.shared()` directly, which put Isar in every import graph that
  /// touched auth and broke the web build (`checkpoints/P2-00.md`). Naming the
  /// cache at each construction site keeps the sign-out wipe explicit — the
  /// mobile app passes `IsarLocalCache`, the web shell `NoOpLocalCache`.
  FirebaseAuthRepository(
    this._auth,
    this._firestore,
    this._logger, {
    required LocalCache cache,
    void Function()? onSignOutNavigated,
  }) : _cache = cache,
       _onSignOutNavigated = onSignOutNavigated;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserModel?> getUserData(String uid) async {
    try {
      // QUEUE-2 (P-2): the profile read is retried on transient failures
      // (bounded, classified backoff); on final failure the existing
      // mapped-exception rethrow below is unchanged.
      final snapshot = await NetworkRetry.withExponentialBackoff(
        () => _firestore.collection('users').doc(uid).get(),
      );
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromDoc(snapshot.data()!, snapshot.id);
      }
      return null;
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_getUserData',
        stack: stack,
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  @override
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_signInAnonymously',
        stack: stack,
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_signInWithEmailAndPassword',
        stack: stack,
      );
      // PERF-1 H-1: rethrow the TYPED exception (mirrors the signUp contract
      // below) — the login screen catches `on FirebaseAuthException` and maps
      // it into a clean localized message. Wrapping into a generic `Exception`
      // here would never match that typed catch, silently swallowing the
      // failure (no UI feedback). The log above still records the failure.
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_sendPasswordResetEmail',
        stack: stack,
      );
      // PERF-1 H-1: same contract as signInWithEmailAndPassword — rethrow the
      // typed exception so the login screen's `on FirebaseAuthException` catch
      // surfaces the mapped message (a generic wrap is silently swallowed).
      rethrow;
    }
  }

  @override
  Future<void> signUp(String email, String password, String name) async {
    try {
      // Auth is the fragile step: invalid credentials, existing email, or
      // weak password throw here. We let the typed exception propagate so the
      // caller shows a clean localized message for the AUTH failure.
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'create-user-empty-result',
          message: 'createUserWithEmailAndPassword returned no user',
        );
      }
      await user.updateDisplayName(name);
      await user.reload();
      // Persist the Firestore profile doc (idempotent; preserves any existing
      // fields) so dashboards never render a fallback name. Reuses the same
      // create-if-absent sync used by Google/Apple sign-in.
      await syncUserProfile(user, displayName: name);
    } catch (e, stack) {
      await _logger.error(e, 'FirebaseAuthRepository_signUp', stack: stack);
      rethrow;
    }
  }

  @override
  Future<void> signInWithApple() async {
    try {
      // Generate a cryptographic nonce to prevent replay attacks (Apple requirement)
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      final result = await _auth.signInWithCredential(oauthCredential);
      if (result.user != null) {
        await syncUserProfile(
          result.user!,
          displayName: appleCredential.givenName,
        );
      }
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_signInWithApple',
        stack: stack,
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow — not an error
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential to pass to Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      // WHY: New Google users don't have a UserModel yet.
      // Without this sync, the UI crashes when providers try to read a null profile.
      if (result.user != null) {
        await syncUserProfile(
          result.user!,
          displayName: googleUser.displayName,
        );
      }
    } catch (e, stack) {
      await _logger.error(
        e,
        'FirebaseAuthRepository_signInWithGoogle',
        stack: stack,
      );
      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }

  /// WHY: After any social auth flow, the Firestore `users/{uid}` document
  /// may not yet exist. This helper checks and creates a customer profile
  /// atomically if missing. It is idempotent — calling twice does nothing.
  /// Public so a real (non-simulated) test can drive concurrent syncs.
  ///
  /// Race-safety: the existence check + create run inside a single Firestore
  /// transaction, so N concurrent syncs for a brand-new user can never each see
  /// "not exists" and clobber a just-written doc (e.g. wiping loyaltyPoints).
  ///
  /// B8-1: `locale` is persisted so the push-notification Cloud Functions can
  /// render localized copy for the recipient. It defaults to the device/app
  /// language mapped to one of the push-supported locales ('en' | 'ar') — the
  /// exact mapping the server dictionary understands; unknown values FAIL
  /// CLOSED to 'en' there.
  Future<void> syncUserProfile(
    User user, {
    String? displayName,
    String? locale,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (snap.exists) return;
      txn.set(docRef, {
        'id': user.uid,
        'email': user.email,
        'name': displayName ?? user.displayName,
        'role': 'customer',
        'locale': resolvePushLocale(locale),
        'loyaltyPoints': 0,
        'tier': 'starter',
        'isOnline': false,
        'assignedOrderIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Generate a random nonce string for Apple Sign In security
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// SHA-256 hash of the nonce for Apple's IdToken validation
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<void> signOut() async {
    try {
      // Clear the local cache first — prevent cross-user data leak (P0-07).
      // The STORE is injected (P2-1a); the obligation is unchanged.
      try {
        await _cache.clearAll();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutClearAllError', stack: stack);
      }

      // Stop analytics collection and reset session (GDPR Art. 17)
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
        await FirebaseAnalytics.instance.resetAnalyticsData();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutAnalyticsError', stack: stack);
      }

      // Clear SharedPreferences user-specific data (P1-05)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_branch_id');
        await prefs.remove('onboarding_completed');
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutPrefsError', stack: stack);
      }

      // Clear the stored FCM token BEFORE the Firestore SDK terminates
      // (01-P1-D): on shared devices, users/{uid}.fcmToken is what routes
      // pushes to THIS install — leaving it behind leaks the previous user's
      // notifications to the next one. Best-effort per step, matching the
      // try/catch pattern of every other signOut step.
      try {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          await _firestore.collection('users').doc(uid).update({
            'fcmToken': FieldValue.delete(),
            'fcmLastUpdated': FieldValue.delete(),
          });
        }
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutFcmFieldClearError', stack: stack);
      }
      // Platform hygiene: delete the FCM registration token itself so this
      // install stops receiving pushes for the signed-out user. Guarded like
      // the GoogleSignIn().signOut() step below — unsupported platforms may
      // throw. Self-healing: FcmService.init() re-uploads a fresh token on
      // the next login (fcm_service.dart:24-43).
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutFcmTokenError', stack: stack);
      }

      // WHY: Terminate the Firestore SDK before signing out.
      // Active stream subscriptions fire one final event under the old auth
      // identity after signOut(), causing a cascade of permission-denied errors
      // on every screen. Terminating + clearing persistence kills all listeners
      // synchronously before the auth token is invalidated. (Law 8, Law 9)
      await _firestore.terminate();
      await _firestore.clearPersistence();
      // WHY: Also disconnect Google silently so the account picker re-appears
      // on the next login instead of silently reusing the cached credential.
      try {
        await GoogleSignIn().signOut();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutGoogleError', stack: stack);
      }
      await _auth.signOut();

      // Reset app state — navigate to login and clear entire stack (P0-18)
      _onSignOutNavigated?.call();
    } catch (e, stack) {
      await _logger.error(e, 'FirebaseAuthRepository_signOut', stack: stack);
      // Force sign out even if cleanup fails — prevents unrecoverable auth limbo
      try {
        await _auth.signOut();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutError', stack: stack);
      }

      // STILL try to reset navigation even if cleanup failed
      try {
        _onSignOutNavigated?.call();
      } catch (e, stack) {
        await _logger.error(e, 'AuthSignOutFinalNavError', stack: stack);
      }

      throw Exception(FirebaseExceptionMapper.map(e));
    }
  }
}

/// Minimal fallback implementation used when the provider is not overridden.
/// Security enforced by ProviderScope overrides in `core_app/lib/app_bootstrap.dart`.
class FallbackAuthRepository implements AuthRepository {
  final LoggerService _logger;
  FallbackAuthRepository(this._logger);

  @override
  Stream<User?> authStateChanges() {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: authStateChanges not overridden',
      ),
    );
    return const Stream.empty();
  }

  @override
  User? get currentUser => null;

  @override
  Future<UserModel?> getUserData(String uid) async {
    unawaited(
      _logger.info({}, 'FallbackAuthRepository: getUserData not overridden'),
    );
    return null;
  }

  @override
  Future<void> signInAnonymously() async {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: signInAnonymously not overridden',
      ),
    );
  }

  @override
  Future<void> signInWithApple() async {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: signInWithApple not overridden',
      ),
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: signInWithGoogle not overridden',
      ),
    );
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: signInWithEmailAndPassword not overridden',
      ),
    );
  }

  @override
  Future<void> signUp(String email, String password, String name) async {
    unawaited(
      _logger.info({}, 'FallbackAuthRepository: signUp not overridden'),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    unawaited(
      _logger.info(
        {},
        'FallbackAuthRepository: sendPasswordResetEmail not overridden',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    unawaited(
      _logger.info({}, 'FallbackAuthRepository: signOut not overridden'),
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Fallback – log and return a safe default.
  // Override in `core_app/lib/app_bootstrap.dart` via ProviderScope overrides for production.
  final logger = ref.watch(loggerProvider);
  unawaited(
    logger.info(
      {},
      'AuthRepository not overridden; using FallbackAuthRepository.',
    ),
  );
  return FallbackAuthRepository(logger);
});

/// Maps the app's current language to one of the push-supported locales
/// ('en' | 'ar'), which the Cloud Functions notification dictionary reads from
/// Composition-root bindings for the auth SDK (Law 12/DI: `core_app/lib` never
/// binds `FirebaseAuth.instance` — it calls these instead).
///
/// [app_bootstrap] is the fleet's composition root: it wires the real
/// repository into `authRepositoryProvider` and points the SDK at the auth
/// emulator when `USE_EMULATORS` is set. Keeping both operations here is what
/// lets the constitution guard report zero direct `firebase_auth` imports in
/// the app layer while the boot chain keeps identical behaviour.
AuthRepository createPlatformAuthRepository({
  required FirebaseFirestore firestore,
  required LoggerService logger,
  required LocalCache cache,
  void Function()? onSignOutNavigated,
}) {
  return FirebaseAuthRepository(
    FirebaseAuth.instance,
    firestore,
    logger,
    cache: cache,
    onSignOutNavigated: onSignOutNavigated,
  );
}

/// Points the platform auth SDK at a local emulator (boot STEP 14; a no-op
/// unless the build passes `USE_EMULATORS`).
Future<void> usePlatformAuthEmulator(String host, int port) =>
    FirebaseAuth.instance.useAuthEmulator(host, port);

/// `users/{uid}.locale`. Unknown/missing languages FAIL CLOSED to 'en' — the
/// dictionary's declared fallback.
String resolvePushLocale([String? raw]) {
  final languageCode =
      raw?.trim().toLowerCase() ??
      PlatformDispatcher.instance.locale.languageCode.toLowerCase();
  return languageCode.startsWith('ar') ? 'ar' : 'en';
}
