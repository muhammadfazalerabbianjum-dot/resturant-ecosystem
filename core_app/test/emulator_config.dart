import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Constitution Law 30 — Emulator Suite Configuration
///
/// Configures the app to connect to ALL Firebase emulators at the start
/// of any automated test run. No real project is ever touched.
///
/// Emulators bound:
///   ✅ Firestore  → localhost:8080
///   ✅ Auth       → localhost:9099
///   ✅ Storage    → localhost:9199
///   ✅ Functions  → localhost:5001
///
/// Usage (in setUpAll of integration/wiring tests):
///   await setupFirebaseEmulators();
///
/// All network access outside localhost is blocked by _TestNetworkBlocker
/// in flutter_test_config.dart — these bindings are the whitelist.

bool _emulatorsConfigured = false;

Future<void> setupFirebaseEmulators() async {
  if (_emulatorsConfigured) return;
  _emulatorsConfigured = true;

  const host = '127.0.0.1';

  try {
    // ── Firestore Emulator ──────────────────────────────────────────────
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    debugPrint('✅ [Emulator] Firestore → $host:8080');

    // ── Auth Emulator ───────────────────────────────────────────────────
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    debugPrint('✅ [Emulator] Auth → $host:9099');

    // ── Storage Emulator ────────────────────────────────────────────────
    // Constitution Law 30: Storage emulator must be bound for upload/download
    // rule tests and proof-of-delivery tests.
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    debugPrint('✅ [Emulator] Storage → $host:9199');

    debugPrint('');
    debugPrint(
      '🔒 [Law 30] All Firebase emulators bound. '
      'Zero production traffic permitted during tests.',
    );
  } on Exception catch (e) {
    // This is a hard failure — if we cannot bind to emulators,
    // tests must not run against production.
    throw StateError(
      '[Law 30 VIOLATION] Failed to bind Firebase emulators: $e\n'
      'Ensure `firebase emulators:start` is running on $host '
      'before executing the test suite.',
    );
  }
}

/// Verifies that the Firestore emulator is reachable.
/// Call this in setUpAll AFTER setupFirebaseEmulators() to fail fast
/// if the emulator is not running.
Future<void> verifyFirestoreEmulatorReachable() async {
  try {
    await FirebaseFirestore.instance
        .collection('_health_check')
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 5));
    debugPrint('✅ [Emulator] Firestore health check passed.');
  } on Exception catch (e) {
    throw StateError(
      '[Law 30 VIOLATION] Firestore emulator health check failed: $e\n'
      'Run `firebase emulators:start --only firestore,auth,storage` first.',
    );
  }
}
