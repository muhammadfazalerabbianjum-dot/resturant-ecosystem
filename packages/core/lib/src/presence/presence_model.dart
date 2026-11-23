import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:core/src/auth/user_model.dart';

part 'presence_model.freezed.dart';
part 'presence_model.g.dart';

@freezed
class PresenceModel with _$PresenceModel {
  const factory PresenceModel({
    required String userId,
    @Default(false) bool isOnline,
    DateTime? lastSeen,
    @Default('') String branchId,
    // B3 P2: `@UserRoleConverter()` (imported from user_model.dart) gives a
    // graceful customer fallback for unknown/missing role strings — no
    // annotation-target suppression needed.
    @UserRoleConverter() @Default(UserRole.customer) UserRole role,
  }) = _PresenceModel;

  factory PresenceModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final roleStr = data['role'] as String?;
    final role = roleStr != null
        ? UserRole.values.firstWhere(
            (r) => r.name == roleStr,
            orElse: () => UserRole.customer,
          )
        : UserRole.customer;

    return PresenceModel(
      userId: doc.id,
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      branchId: data['branchId'] as String? ?? '',
      role: role,
    );
  }

  factory PresenceModel.fromJson(Map<String, dynamic> json) =>
      _$PresenceModelFromJson(json);
}
