import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/src/auth/auth_provider.dart';
import 'package:core/src/auth/user_model.dart';
import 'package:core/src/error_logger/logger_provider.dart';
import 'package:core/src/error_logger/logger_service.dart';
import 'package:core/src/providers/firestore_provider.dart';

/// Tracks staff online/offline status in Firestore presence/{uid}.
/// Attach via [WidgetsBindingObserver] on app start.
///
/// B4-7: the [FirebaseFirestore] instance and [LoggerService] are INJECTED
/// (never `FirebaseFirestore.instance` / inline `LoggerService()`), so this
/// service is testable and never bypasses the DI graph.
class PresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _db;
  final LoggerService _logger;
  final String userId;
  final String branchId;
  final UserRole role;

  PresenceService({
    required this.userId,
    required this.branchId,
    required this.role,
    required FirebaseFirestore db,
    required LoggerService logger,
  }) : _db = db,
       _logger = logger;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('presence').doc(userId);

  Future<void> goOnline() => _ref.set({
    'isOnline': true,
    'lastSeen': FieldValue.serverTimestamp(),
    'branchId': branchId,
    'role': role.name,
  }, SetOptions(merge: true));

  Future<void> goOffline() => _ref.set({
    'isOnline': false,
    'lastSeen': FieldValue.serverTimestamp(),
    'branchId': branchId,
    'role': role.name,
  }, SetOptions(merge: true));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // P4-02 (LAW 8): wrap in catch so a Firestore failure can NEVER crash
        // the app-lifecycle observer, and break prevents fall-through to
        // goOffline (which would immediately render the user offline on resume).
        unawaited(_safeGoOnline());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        unawaited(_safeGoOffline());
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _safeGoOnline() async {
    try {
      await goOnline();
    } catch (e, stack) {
      _logPresenceError('presence_online_failed', e, stack);
    }
  }

  Future<void> _safeGoOffline() async {
    try {
      await goOffline();
    } catch (e, stack) {
      _logPresenceError('presence_offline_failed', e, stack);
    }
  }

  void _logPresenceError(String message, Object error, StackTrace stack) {
    // Presence is best-effort telemetry. Never let a transient Firestore
    // failure propagate to the framework — log via the injected logger
    // (B4-7: no inline LoggerService, no dart:developer side-channel).
    unawaited(_logger.warn(error, 'PresenceService.$message', stack: stack));
  }

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_safeGoOnline());
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_safeGoOffline());
  }
}

/// Streams a [PresenceService] for the currently signed-in STAFF user.
///
/// B4-7: wiring the (previously dead) presence feature into the lifecycle.
/// * Customers, signed-out users, and staff with no assigned branch get
///   `null` — no presence doc is written for them.
/// * Everything is injected from the DI graph (never `FirebaseFirestore.instance`
///   or inline `LoggerService()`).
final presenceServiceProvider = Provider<PresenceService?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null || user.role == UserRole.customer) return null;
  final branchId = user.branchId ?? '';
  if (branchId.isEmpty) return null;
  return PresenceService(
    userId: user.id,
    branchId: branchId,
    role: user.role,
    db: ref.watch(firestoreProvider),
    logger: ref.read(loggerProvider),
  );
});
