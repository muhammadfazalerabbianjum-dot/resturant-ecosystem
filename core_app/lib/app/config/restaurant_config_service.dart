import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart' show firestoreProvider;
import 'package:labs/app/models/restaurant_config_model.dart';
import 'package:labs/app/tenancy/tenant_claim.dart';
import 'package:labs/app/tenancy/tenant_settings.dart';

/// Repository for `settings/restaurantConfig`, backed by an injected
/// [FirebaseFirestore].
///
/// B3 P1 (finding 2.5): the previous top-level functions called a direct
/// static Firestore instance (bypassing DI + testability). Every
/// read/write now flows through an injected instance — in tests you override
/// `firestoreProvider` with a `fake_cloud_firestore` instance and this
/// repository receives the same one via `ref.watch(firestoreProvider)`.
class RestaurantConfigRepository {
  RestaurantConfigRepository({
    required FirebaseFirestore firestore,
    required TenantClaimReader tenantClaim,
  }) : _firestore = firestore,
       _tenantClaim = tenantClaim;

  final FirebaseFirestore _firestore;
  final TenantClaimReader _tenantClaim;

  /// D-038: the config lives at `settings/${tenantId}_restaurantConfig`.
  DocumentReference<Map<String, dynamic>> _configRef(String tenantId) =>
      _firestore
          .collection('settings')
          .doc(settingsDocId(tenantId, 'restaurantConfig'));

  /// Streams this tenant's restaurant config.
  ///
  /// Signed out there is no tenant and therefore no document: the model's
  /// defaults are the documented pre-login state, because identity before login
  /// comes from the bundled config, never from a tenant's Firestore document.
  Stream<RestaurantConfigModel> streamConfig() async* {
    final String? tenantId = await _tenantClaim.read();
    if (tenantId == null) {
      yield const RestaurantConfigModel();
      return;
    }
    yield* _configRef(
      tenantId,
    ).snapshots().map(RestaurantConfigModel.fromFirestore);
  }

  /// Writes the entire config map to this tenant's document.
  Future<void> save(RestaurantConfigModel config) async {
    await _configRef(
      await _requireTenant(),
    ).set(config.toFirestore(), SetOptions(merge: true));
  }

  /// Convenience: updates a single field without rewriting the entire doc.
  Future<void> patch(Map<String, dynamic> fields) async {
    await _configRef(
      await _requireTenant(),
    ).set(fields, SetOptions(merge: true));
  }

  /// A write with no claim has no correct target document: fail, never guess.
  Future<String> _requireTenant() async {
    final String? tenantId = await _tenantClaim.read();
    if (tenantId == null) {
      throw StateError(
        'cannot write restaurant config without a tenantId claim',
      );
    }
    return tenantId;
  }
}

/// Injectable provider — overrides [firestoreProvider] with a fake in tests.
final restaurantConfigRepositoryProvider = Provider<RestaurantConfigRepository>(
  (ref) {
    return RestaurantConfigRepository(
      firestore: ref.watch(firestoreProvider),
      tenantClaim: ref.watch(tenantClaimProvider),
    );
  },
);

/// Streams the restaurant config. Used globally by any widget that needs
/// restaurant identity or rules.
final restaurantConfigProvider = StreamProvider<RestaurantConfigModel>((ref) {
  return ref.watch(restaurantConfigRepositoryProvider).streamConfig();
});
