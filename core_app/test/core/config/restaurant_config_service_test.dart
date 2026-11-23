import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/core.dart' show firestoreProvider;
import 'package:labs/app/config/restaurant_config_service.dart';
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';

void main() {
  group(
    'RestaurantConfigRepository (B3 P1 — DI, no direct static Firestore instance)',
    () {
      test('save writes the config via an injected fake DB', () async {
        final firestore = FakeFirebaseFirestore();
        final repo = RestaurantConfigRepository(
          firestore: firestore,
          tenantClaim: _FixedTenantClaim(),
        );

        const config = RestaurantConfigModel(
          restaurantName: 'Test Restaurant',
          currency: 'USD',
          tagline: 'Fresh',
        );
        await repo.save(config);

        final doc = await firestore
            .collection('settings')
            .doc('tenant_a_restaurantConfig')
            .get();
        expect(doc.data()?['restaurantName'], 'Test Restaurant');
        expect(doc.data()?['currency'], 'USD');
        expect(doc.data()?['tagline'], 'Fresh');
      });

      test(
        'patch updates a single field and preserves existing ones (merge)',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repo = RestaurantConfigRepository(
            firestore: firestore,
            tenantClaim: _FixedTenantClaim(),
          );
          await firestore
              .collection('settings')
              .doc('tenant_a_restaurantConfig')
              .set({'restaurantName': 'Initial Name', 'currency': 'USD'});

          await repo.patch({'currency': 'EUR'});

          final doc = await firestore
              .collection('settings')
              .doc('tenant_a_restaurantConfig')
              .get();
          expect(doc.data()?['restaurantName'], 'Initial Name');
          expect(doc.data()?['currency'], 'EUR');
        },
      );

      test('streamConfig emits a value read through the injected DB', () async {
        final firestore = FakeFirebaseFirestore();
        final repo = RestaurantConfigRepository(
          firestore: firestore,
          tenantClaim: _FixedTenantClaim(),
        );
        await firestore
            .collection('settings')
            .doc('tenant_a_restaurantConfig')
            .set({'restaurantName': 'Stream Test', 'currency': 'USD'});

        final model = await repo.streamConfig().first;
        expect(model.restaurantName, 'Stream Test');
        expect(model.currency, 'USD');
      });

      test(
        'streamConfig emits an empty config when the doc is absent (no crash)',
        () async {
          final firestore = FakeFirebaseFirestore();
          final repo = RestaurantConfigRepository(
            firestore: firestore,
            tenantClaim: _FixedTenantClaim(),
          );

          final model = await repo.streamConfig().first;
          expect(model.restaurantName, '');
          expect(model.currency, 'USD'); // model default
        },
      );
    },
  );

  group(
    'restaurantConfigProvider wiring (B3 P1 — DI via firestoreProvider)',
    () {
      test(
        'resolves through the repository using an overridden fake DB',
        () async {
          final firestore = FakeFirebaseFirestore();
          await firestore
              .collection('settings')
              .doc('tenant_a_restaurantConfig')
              .set({'restaurantName': 'Provider Test', 'currency': 'AED'});

          final container = ProviderContainer(
            overrides: [
              firestoreProvider.overrideWithValue(firestore),
              tenantClaimProvider.overrideWithValue(_FixedTenantClaim()),
            ],
          );
          addTearDown(container.dispose);

          // Awaiting the provider's future proves the stream flows through the
          // injected DB (never a FirebaseFirestore.instance).
          final value = await container.read(restaurantConfigProvider.future);
          expect(value.restaurantName, 'Provider Test');
          expect(value.currency, 'AED');
        },
      );
    },
  );
}

class _FixedTenantClaim implements TenantClaimReader {
  @override
  Future<String?> read({bool forceRefresh = false}) async => 'tenant_a';
}
