// PERF-6b — unit coverage for the per-client tax table repository.
//
// Contract under test (mirrors the server's `calculateTax` /
// `resolveChargeTaxAndPromo` lookup at functions/src/index.ts:127 and
// payment.ts computeTaxCents):
//   * rates are FRACTIONS of 1 — a percent-confused 7.25 must be REJECTED,
//     never stored (fail-closed, Law 8)
//   * state codes must be exactly 2 letters A-Z (normalized to uppercase)
//   * a save is `{merge: true}` and MUST NOT clobber OTHER clients' rows in
//     the shared multi-tenant doc (one row per clientId, never shared)
//   * streamClientRates maps the row and reports null when absent (the UI
//     then surfaces that the documented offline fallback table is live)
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labs/app/config/tax_rates_repository.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  group('TaxRatesRepository — fail-closed validation', () {
    test('rejects a default rate above 1 (percent-confusion guard)', () {
      final repo = TaxRatesRepository(
        firestore: FakeFirebaseFirestore(),
        tenantClaim: _FixedTenantClaim(),
      );
      expect(
        () => repo.saveClientRates(
          const ClientTaxRates(
            clientId: 'labs.carnama.halalboys',
            stateRates: {},
            defaultRate: 7.25,
          ),
        ),
        throwsA(isA<TaxRateValidationException>()),
      );
    });

    test('rejects negative rates', () {
      final repo = TaxRatesRepository(
        firestore: FakeFirebaseFirestore(),
        tenantClaim: _FixedTenantClaim(),
      );
      expect(
        () => repo.saveClientRates(
          const ClientTaxRates(
            clientId: 'labs.carnama.halalboys',
            stateRates: {'NY': -0.01},
            defaultRate: 0.05,
          ),
        ),
        throwsA(isA<TaxRateValidationException>()),
      );
    });

    test('rejects a malformed state code', () {
      final repo = TaxRatesRepository(
        firestore: FakeFirebaseFirestore(),
        tenantClaim: _FixedTenantClaim(),
      );
      expect(
        () => repo.saveClientRates(
          const ClientTaxRates(
            clientId: 'labs.carnama.halalboys',
            stateRates: {'NewYork': 0.08},
            defaultRate: 0.05,
          ),
        ),
        throwsA(isA<TaxRateValidationException>()),
      );
    });

    test('saves THIS client row with merge preserving other tenants', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('settings').doc('tenant_a_taxRates').set({
        'clients': {
          'other.app': {
            'stateRates': {'CA': 0.09},
            'defaultRate': 0.06,
          },
        },
      });
      final repo = TaxRatesRepository(
        firestore: fs,
        tenantClaim: _FixedTenantClaim(),
      );

      await repo.saveClientRates(
        const ClientTaxRates(
          clientId: 'labs.carnama.halalboys',
          stateRates: {'ny': 0.08},
          defaultRate: 0.05,
        ),
      );

      final doc = await fs
          .collection('settings')
          .doc('tenant_a_taxRates')
          .get();
      final clients = doc.data()!['clients'] as Map<String, dynamic>;
      expect(
        clients.containsKey('other.app'),
        isTrue,
        reason: 'merge write must never clobber another tenant row',
      );
      final row = clients['labs.carnama.halalboys'] as Map<String, dynamic>;
      expect((row['stateRates'] as Map)['NY'], 0.08);
      expect(row['defaultRate'], 0.05);
    });

    test('streamClientRates maps the row; null when absent', () async {
      final fs = FakeFirebaseFirestore();
      final repo = TaxRatesRepository(
        firestore: fs,
        tenantClaim: _FixedTenantClaim(),
      );

      expect(await repo.streamClientRates('missing.app').first, isNull);

      await repo.saveClientRates(
        const ClientTaxRates(
          clientId: 'x.app',
          stateRates: {'CA': 0.0725},
          defaultRate: 0.05,
        ),
      );
      final row = await repo.streamClientRates('x.app').first;
      expect(row!.stateRates['CA'], 0.0725);
      expect(row.defaultRate, 0.05);
    });

    // PERF-10 T-8 mutant-kill pin (M-D07): the bounds are INCLUSIVE at 0 —
    // 0.0 is a legitimate tax-free rate. A `<=` flip at kMinTaxRate would
    // reject a save in a tax-free jurisdiction at the first of the three
    // fail-closed gates (UI -> repository -> server).
    test('accepts 0.0 (tax-free) — bounds are inclusive', () async {
      final fs = FakeFirebaseFirestore();
      final repo = TaxRatesRepository(
        firestore: fs,
        tenantClaim: _FixedTenantClaim(),
      );

      await repo.saveClientRates(
        const ClientTaxRates(
          clientId: 'labs.carnama.halalboys',
          stateRates: {'OR': 0.0},
          defaultRate: 0.0,
        ),
      );

      final row = await repo.streamClientRates('labs.carnama.halalboys').first;
      expect(row, isNotNull);
      expect(row!.stateRates['OR'], 0.0);
      expect(row.defaultRate, 0.0);
    });
  });
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
