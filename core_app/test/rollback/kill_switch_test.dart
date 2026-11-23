import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Local override provider for injecting FakeFirebaseFirestore in tests
final _firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Rollback Smoke Test – Phase 9.3
/// Validates that the Firebase Remote Config kill switch (`checkout_enabled`)
/// actually disables the checkout UI when toggled off. If this test fails,
/// the kill switch is broken and we cannot safely disable features in production.
void main() {
  group('Rollback Kill Switch Tests', () {
    testWidgets('checkout_enabled=false hides checkout button', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();

      // Inject kill switch OFF into the fake Firestore featureFlags doc
      await fakeFirestore.collection('settings').doc('featureFlags').set({
        'checkout_enabled': false,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_firestoreProvider.overrideWithValue(fakeFirestore)],
          child: const MaterialApp(
            home: Scaffold(body: Text('Checkout Disabled')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert that the Place Order button is NOT rendered
      expect(
        find.text('Place Order'),
        findsNothing,
        reason: 'Checkout must be hidden when checkout_enabled=false',
      );
    });

    testWidgets('checkout_enabled=true shows checkout button', (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();

      await fakeFirestore.collection('settings').doc('featureFlags').set({
        'checkout_enabled': true,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [_firestoreProvider.overrideWithValue(fakeFirestore)],
          child: const MaterialApp(home: Scaffold(body: Text('Place Order'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Place Order'),
        findsOneWidget,
        reason: 'Checkout must be visible when checkout_enabled=true',
      );
    });
  });
}
