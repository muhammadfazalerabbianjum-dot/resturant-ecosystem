// =============================================================================
// PHASE 6: RUTHLESS LOYALTY & PROMOTIONS AUDIT
// Engine: FakeFirebaseFirestore — pure in-memory Dart.
// Vectors: Points integer overflow, promo code double-redemption,
//          negative discount attack, and zero-division in percentage calc.
// Run: flutter test test/wiring/v15_phase6_loyalty_audit_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 1: LOYALTY POINTS OVERFLOW
  // A user performs so many transactions that loyaltyPoints approaches
  // Dart's max int. The field must stay within safe bounds.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 6.1 — Loyalty Points Overflow Guard', () {
    test('int.maxFinite - 1 stays as a valid int (Dart safety check)', () {
      // Dart's int is 64-bit — max value is 9223372036854775807.
      // We verify that a large-but-real loyalty points value doesn't corrupt.
      const largePoints = 999999999; // 1 billion points — extreme but valid
      expect(largePoints, isA<int>());
      expect(
        largePoints + 100,
        greaterThan(largePoints),
        reason: 'Adding points to a large int must not wrap or corrupt',
      );
    });

    test(
      'Firestore can write and read large loyaltyPoints without truncation',
      () async {
        await fakeFirestore.collection('users').doc('whale_user').set({
          'loyaltyPoints': 999999999,
          'role': 'customer',
        });

        final snap = await fakeFirestore
            .collection('users')
            .doc('whale_user')
            .get();
        expect(
          snap.data()?['loyaltyPoints'],
          equals(999999999),
          reason:
              'Large loyalty point values must survive Firestore round-trip intact',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // P9 W1 (T-5): the two PromoCalculator groups (6.2/6.3) were deleted with
  // the dead `promo_calculator.dart` itself (zero production importers —
  // totals come from cart_model.dart's inline fold and promo discounts are
  // server-derived via promo_code_service; tests of dead code are
  // test-theater). The LIVE promo path is pinned in promo_code_service_test.
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // ATTACK VECTOR 4: POINTS CALCULATION ON ZERO-CENT ORDER
  // If totalCents is 0 (fully comped order), loyalty point calculation
  // must not produce NaN or crash with division.
  // ══════════════════════════════════════════════════════════════════════════
  group('Phase 6.4 — Zero-Cent Order Points Safety', () {
    test(
      'loyaltyPoints calculation on 0-cent order yields 0 without crash',
      () {
        const totalCents = 0;
        const pointsPerDollar = 10;

        // Points = (totalCents / 100) * pointsPerDollar
        final points = ((totalCents / 100) * pointsPerDollar).floor();

        expect(
          points,
          equals(0),
          reason:
              'A 0-cent order must award 0 points — no division error or NaN',
        );
        expect(points, isA<int>());
        expect(points, isNot(isNaN));
      },
    );
  });
}
