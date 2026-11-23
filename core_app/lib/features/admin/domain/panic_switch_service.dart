import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/tenancy/tenant_settings.dart';

/// WHY: Gap 8 — Kitchen Panic Switch.
/// A viral TikTok review sends 500 orders in 10 minutes. The kitchen
/// cannot cope. The owner needs a single toggle that INSTANTLY halts all
/// new incoming checkout orders until they recover.
///
/// Architecture:
/// - The field `settings/restaurantConfig.ordersAccepting` is the gate.
/// - When `false`, the `isOrdersAccepting()` rule in `firestore.rules`
///   denies all new order CREATES at the database layer (B5 fix).
///   A missing config doc or missing field defaults to true (open).
/// - The Admin SDK (Cloud Functions `createOrder`) bypasses rules by
///   design — server-side order accepts are unaffected by the panic switch.
/// - This service provides the reactive stream and the toggle for the UI.
/// - The checkout screen MUST also read this value before even showing
///   the "Place Order" button (client-side UX guard, defense-in-depth).

class PanicSwitchService {
  final FirebaseFirestore _firestore;
  final TenantClaimReader _tenantClaim;

  /// The claim is REQUIRED. An optional one left a second, unprefixed document
  /// reachable (D-038 retired the legacy path): two documents, one of them read
  /// by nobody, is how a switch appears to work while orders keep flowing.
  PanicSwitchService({
    required FirebaseFirestore firestore,
    required TenantClaimReader tenantClaim,
  }) : _firestore = firestore,
       _tenantClaim = tenantClaim;

  static const _field = 'ordersAccepting';

  /// D-038: the config lives at `settings/${tenantId}_restaurantConfig`.
  Future<DocumentReference<Map<String, dynamic>>> _configRef() async {
    final String? tenantId = await _tenantClaim.read();
    if (tenantId == null) {
      throw StateError(
        'panic switch needs a tenantId claim to name its document',
      );
    }
    return _firestore
        .collection('settings')
        .doc(settingsDocId(tenantId, 'restaurantConfig'));
  }

  /// Live stream of the current panic switch state.
  /// `true` = accepting orders (normal), `false` = paused (panic mode).
  Stream<bool> get ordersAcceptingStream async* {
    final ref = await _configRef();
    yield* ref.snapshots().map(
      (snap) => (snap.data()?[_field] as bool?) ?? true,
    );
  }

  /// Toggle the panic switch.
  /// Owner presses "Pause Orders" → sets to false.
  /// Owner presses "Resume Orders" → sets to true.
  Future<void> setOrdersAccepting(bool accepting) async {
    final ref = await _configRef();
    await ref.set({
      _field: accepting,
      'panicUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// One-shot read of the panic gate (batch QUEUE-2, P-2).
  ///
  /// Retried on transient failures with bounded classified backoff so a
  /// network blip during checkout does not spuriously fail the guard.
  /// Permanent errors (rules `permission-denied`, ...) rethrow immediately;
  /// a missing config doc still defaults to `true` (open) — unchanged.
  Future<bool> isOrdersAccepting() async {
    return NetworkRetry.withExponentialBackoff(() async {
      final ref = await _configRef();
      final snap = await ref.get();
      return (snap.data()?[_field] as bool?) ?? true;
    });
  }
}

/// Riverpod provider for the live accepting-orders state.
final ordersAcceptingProvider = StreamProvider<bool>((ref) {
  return ref.watch(panicSwitchServiceProvider).ordersAcceptingStream;
});

final panicSwitchServiceProvider = Provider<PanicSwitchService>((ref) {
  return PanicSwitchService(
    firestore: ref.watch(firestoreProvider),
    tenantClaim: ref.watch(tenantClaimProvider),
  );
});
