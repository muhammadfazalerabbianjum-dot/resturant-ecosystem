import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core/src/config/core_config.dart';

/// Wraps the `screenPaymentFraud` Cloud Function in production.
/// In demo mode, performs a simple local Firestore order-count check.
class FraudScreeningService {
  final FirebaseFunctions _fn;

  FraudScreeningService({FirebaseFunctions? functions})
    : _fn = functions ?? FirebaseFunctions.instance;

  /// Returns true if the payment is allowed to proceed.
  /// Returns false if the user is rate-limited (>10 orders/hour).
  /// FAILS CLOSED on errors (Law 8/12) — a security control that silently
  /// disables itself is worse than no control. On any error, the payment
  /// is REJECTED so the user can retry or contact support.
  Future<bool> screenPayment() async {
    // ── DEMO MODE: Local Firestore count ─────────────────────────────────────
    if (CoreConfigHolder.instance.isDemoMode) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return false; // fail-closed: no user, no payment
        final oneHourAgo = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1)),
        );
        final snap = await FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: uid)
            .where('createdAt', isGreaterThan: oneHourAgo)
            .count()
            .get();
        return (snap.count ?? 0) < 10;
      } catch (_) {
        return false; // FAIL-CLOSED — reject on error
      }
    }
    // ── PRODUCTION MODE: Cloud Function ──────────────────────────────────────
    try {
      final result = await _fn.httpsCallable('screenPaymentFraud').call();
      return result.data['allowed'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') return false;
      return false; // FAIL-CLOSED — reject on any function error
    } catch (_) {
      return false; // FAIL-CLOSED — reject on any error
    }
  }
}
