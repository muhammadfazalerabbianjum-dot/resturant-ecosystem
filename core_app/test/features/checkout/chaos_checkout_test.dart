// test/features/checkout/chaos_checkout_test.dart
//
// MONEY-3 (P-5): the dead flat-payload order-submission path (whose production
// branch did not match the `createOrder` callable contract) was removed in
// B3-P3, along with its dedicated tests (Scenario A/B + the chaos repository
// subclass). The production order path is `CheckoutService.createOrder` — its
// payload contract is asserted in test/idempotency_test.dart.
//
// This file retains the independent probabilistic `ChaosFirestore` stress test
// (Scenario C), which does not depend on the removed method.
//
// Requires: fake_cloud_firestore, ChaosFirestore (package:core).

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:core/core.dart';

void main() {
  tearDown(() => ChaosFirestore.enableChaosMode = false);

  // ════════════════════════════════════════════════════════════════════════
  // Scenario C: Probabilistic chaos (10% failure rate) — statistical test
  // ════════════════════════════════════════════════════════════════════════
  group('ChaosFirestore — 10% failure rate stress test', () {
    test(
      'majority of 50 sequential operations complete without throwing',
      () async {
        final fakeFirestore = FakeFirebaseFirestore();
        ChaosFirestore.enableChaosMode = true;

        int successes = 0;
        int failures = 0;

        // Use a 10 % rate — statistically at most 30 % should fail.
        final chaos = ChaosFirestore(fakeFirestore, failureRate: 0.10);

        for (var i = 0; i < 50; i++) {
          try {
            chaos.collection('orders').doc('order-$i');
            // Directly test collection proxy — no actual write needed for rate check
            successes++;
          } on FirebaseException {
            failures++;
          }
        }

        // With 10 % rate across 50 attempts the probability of >25 failures
        // (50 %) is astronomically small (Binomial(50,0.1) tail).
        expect(
          successes,
          greaterThan(failures),
          reason: 'Majority of ops should succeed at 10% chaos rate',
        );
      },
    );
  });
}
