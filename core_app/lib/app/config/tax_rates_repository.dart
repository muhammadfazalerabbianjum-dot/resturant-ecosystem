import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/tenancy/tenant_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart' show CoreConfigHolder, firestoreProvider;

/// Bounds for tax rates stored as FRACTIONS of 1 (CA = 0.0725), matching the
/// exact lookup `calculateTax` / `resolveChargeTaxAndPromo` performs
/// server-side (`functions/src/index.ts:127`, `payment.ts computeTaxCents`).
const double kMinTaxRate = 0.0;
const double kMaxTaxRate = 1.0;

/// PERF-6b: thrown by [TaxRatesRepository.saveClientRates] when a rate or a
/// state code violates the fail-closed contract. The server independently
/// fail-closes on unknown states (Law 8 — never zero tax), so a mistaken or
/// hostile write can never reach the money path; this validation is the
/// first of three gates (UI -> repository -> server).
class TaxRateValidationException implements Exception {
  final String message;
  TaxRateValidationException(this.message);
  @override
  String toString() => 'TaxRateValidationException: $message';
}

/// THIS client's row inside `settings/taxRates.clients[clientId]`.
class ClientTaxRates {
  final String clientId;
  final Map<String, double> stateRates;
  final double defaultRate;
  final String? currency;

  const ClientTaxRates({
    required this.clientId,
    required this.stateRates,
    required this.defaultRate,
    this.currency,
  });

  factory ClientTaxRates.fromMap(String clientId, Map<String, dynamic> map) {
    final rawRates = (map['stateRates'] as Map<String, dynamic>?) ?? const {};
    return ClientTaxRates(
      clientId: clientId,
      stateRates: rawRates.map(
        (k, v) => MapEntry(k.toUpperCase(), (v as num).toDouble()),
      ),
      defaultRate: ((map['defaultRate'] as num?) ?? 0.05).toDouble(),
      currency: map['currency'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    // PERF-6 post-merge gate catch: state codes MUST be normalized on WRITE
    // too, not just on read — a lowercase 'ny' stored verbatim would be
    // invisible to the server's uppercase `rates[stateCode]` lookup
    // (calculateTax) and silently fall back to the default rate. fromMap
    // uppercases; this is the same contract on the way out.
    'stateRates': {
      for (final e in stateRates.entries) e.key.toUpperCase(): e.value,
    },
    'defaultRate': defaultRate,
    if (currency != null) 'currency': currency,
  };
}

/// Repository for `settings/taxRates` — the per-client tax table the server
/// money path consumes. Mirrors [RestaurantConfigRepository]: injected
/// [FirebaseFirestore], provider overridable with fake_cloud_firestore.
class TaxRatesRepository {
  TaxRatesRepository({
    required FirebaseFirestore firestore,
    required TenantClaimReader tenantClaim,
  }) : _firestore = firestore,
       _tenantClaim = tenantClaim;

  final FirebaseFirestore _firestore;
  final TenantClaimReader _tenantClaim;

  /// D-038: the tax table lives at `settings/${tenantId}_taxRates`.
  DocumentReference<Map<String, dynamic>> _ref(String tenantId) => _firestore
      .collection('settings')
      .doc(settingsDocId(tenantId, 'taxRates'));

  /// Streams THIS app's tax row; null when the doc or the row is absent
  /// (the server then uses its documented offline fallback table — the UI
  /// surfaces that state so the owner knows the fallback is live).
  Stream<ClientTaxRates?> streamClientRates(String clientId) async* {
    final String? tenantId = await _tenantClaim.read();
    // Signed out there is no tenant table; the server's documented offline
    // fallback applies and the setup UI surfaces that state.
    if (tenantId == null) {
      yield null;
      return;
    }
    yield* _ref(tenantId).snapshots().map((snapshot) {
      final clients = snapshot.data()?['clients'] as Map<String, dynamic>?;
      final row = clients?[clientId] as Map<String, dynamic>?;
      if (row == null) return null;
      return ClientTaxRates.fromMap(clientId, row);
    });
  }

  /// Saves THIS client's row with `{merge: true}` so OTHER clients' rows in
  /// the shared multi-tenant doc are preserved (one row per clientId — the
  /// server lookup is per-client, never shared).
  Future<void> saveClientRates(ClientTaxRates rates) async {
    _validate(rates);
    final String? tenantId = await _tenantClaim.read();
    if (tenantId == null) {
      throw StateError('cannot write tax rates without a tenantId claim');
    }
    await _ref(tenantId).set({
      'clients': {rates.clientId: rates.toMap()},
    }, SetOptions(merge: true));
  }

  void _validate(ClientTaxRates rates) {
    void checkRate(double r, String what) {
      if (r.isNaN || r < kMinTaxRate || r > kMaxTaxRate) {
        throw TaxRateValidationException(
          '$what must be a fraction between 0 and 1, got $r',
        );
      }
    }

    checkRate(rates.defaultRate, 'defaultRate');
    for (final entry in rates.stateRates.entries) {
      final code = entry.key.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        throw TaxRateValidationException(
          'state code must be exactly 2 letters A-Z, got "${entry.key}"',
        );
      }
      checkRate(entry.value, 'stateRates[$code]');
    }
  }
}

final taxRatesRepositoryProvider = Provider<TaxRatesRepository>(
  (ref) => TaxRatesRepository(
    firestore: ref.watch(firestoreProvider),
    tenantClaim: ref.watch(tenantClaimProvider),
  ),
);

/// Streams THIS app's tax row for the setup UI (clientId = bundle id —
/// the same id the checkout path forwards to `calculateTax`).
final taxRatesRowProvider = StreamProvider<ClientTaxRates?>((ref) {
  final clientId = CoreConfigHolder.instance.clientId;
  return ref.watch(taxRatesRepositoryProvider).streamClientRates(clientId);
});
