/// Encapsulates admin PIN verification with rate limiting.
/// Loads PIN from Remote Config (production) or --dart-define (dev).
/// Complies with Law 16 (Secret Guarding). Privileged-access audit logging is
/// CF-owned — see the audit note below; the client cannot write `audit_log`
/// (firestore.rules deny client writes).
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:core/src/network/firestore_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev-only PIN from environment — no default fallback.
const String _kDevAdminPin = String.fromEnvironment(
  'ADMIN_PIN',
  // No defaultValue — forces --dart-define in release
);

final adminAccessProvider = Provider<AdminAccessService>((ref) {
  return AdminAccessService(FirestoreClient.instance.db);
});

class AdminAccessService {
  final FirebaseFirestore _firestore;
  FirebaseRemoteConfig? _remoteConfig;

  // Rate limiting state
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  static const int _kMaxFailedAttempts = 5;
  static const Duration _kLockoutDuration = Duration(seconds: 60);

  AdminAccessService(this._firestore, {FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig;

  Future<bool> verifyPin(String pin) async {
    // Rate limit check
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      return false;
    }

    final expectedPin = await _getExpectedPin();
    if (expectedPin == null || expectedPin.isEmpty) {
      return false;
    }

    final isValid = pin.isNotEmpty && pin == expectedPin;

    if (!isValid) {
      _failedAttempts++;
      if (_failedAttempts >= _kMaxFailedAttempts) {
        _lockoutUntil = DateTime.now().add(_kLockoutDuration);
        _failedAttempts = 0;
      }
    } else {
      _failedAttempts = 0;
    }

    return isValid;
  }

  /// Loads PIN from Remote Config (production) or --dart-define (dev).
  Future<String?> _getExpectedPin() async {
    if (kDebugMode) {
      return _kDevAdminPin.isNotEmpty ? _kDevAdminPin : null;
    }
    try {
      _remoteConfig ??= FirebaseRemoteConfig.instance;
      await _remoteConfig!.fetchAndActivate();
      return _remoteConfig!.getString('admin_pin');
    } catch (_) {
      return null;
    }
  }

  // AUDIT NOTE (01-P2-3 / 01-P2-6b, batch RULES-2): the former `_logAudit`
  // client write path was DELETED, not migrated — firestore.rules fail closed
  // on `audit_log` (`allow write: if false`, firestore.rules:631-634: the
  // trail is written ONLY by the Cloud Functions Admin SDK), so every client
  // write here was DENIED and silently swallowed by the non-blocking catch:
  // PIN attempts were never actually recorded. The authoritative audit trail
  // for privileged access is the CF-owned one (functions/src writes to
  // `audit_log` via the Admin SDK; owner-read only). Do NOT reintroduce
  // client-side audit writes — they are denied by design (fail-closed).

  /// Validates if an email is globally authorized via `settings` or `admins` whitelist.
  Future<bool> isEmailAuthorized(String email) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Security validation cascades purely dynamically

    try {
      // C3 FIX: Read settings/ownerInfo (not settings/featureFlags); the
      // canonical field is `ownerEmail` — the same field firestore.rules:51
      // isOwner() and the v003 bootstrap migration provision.
      final settings = await _firestore
          .collection('settings')
          .doc('ownerInfo')
          .get();
      if (settings.exists) {
        final ownerEmail = (settings.data()?['ownerEmail'] as String?)
            ?.toLowerCase();
        if (ownerEmail != null && ownerEmail == normalizedEmail) return true;
      }

      // Check admins collection (email as doc id)
      final admin = await _firestore
          .collection('admins')
          .doc(normalizedEmail)
          .get();
      if (admin.exists) return true;

      // Also check users collection (email as field, role is admin/manager)
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .where('role', whereIn: ['admin', 'manager', 'owner'])
          .limit(1)
          .get();
      return userQuery.docs.isNotEmpty;
    } catch (e) {
      // If Firestore is unreachable, fail securely
      return false;
    }
  }
}
