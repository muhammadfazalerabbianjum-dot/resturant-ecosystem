import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart' show authStateProvider, firestoreProvider;
import '../domain/loyalty_model.dart';

class LoyaltyRepository {
  final FirebaseFirestore _firestore;
  LoyaltyRepository(this._firestore);

  Stream<LoyaltyModel> getUserLoyalty(String userId) {
    if (userId.isEmpty) return Stream.value(const LoyaltyModel());
    return _firestore.collection('loyalty').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return LoyaltyModel(uid: userId);
      final data = Map<String, dynamic>.from(
        doc.data() as Map<dynamic, dynamic>,
      );
      data['uid'] = userId;
      return LoyaltyModel.fromJson(data);
    });
  }
}

final loyaltyRepositoryProvider = Provider.autoDispose<LoyaltyRepository>((
  ref,
) {
  return LoyaltyRepository(ref.watch(firestoreProvider));
});

final userLoyaltyProvider = StreamProvider.autoDispose<LoyaltyModel>((ref) {
  final user = ref.watch(authStateProvider).value;
  return ref.watch(loyaltyRepositoryProvider).getUserLoyalty(user?.uid ?? '');
});
