import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:core/src/utils/json_converters.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Roles that can be assigned to staff users.
enum UserRole { owner, manager, kitchen, delivery, customer }

/// Presentation capability gates for [UserRole] (Law 12): these answer "which
/// affordances does this role SEE?" — a UX question, never an access decision
/// (firestore.rules owns that). Centralising the mapping here keeps the
/// `role ==` comparisons out of feature screens — one auditable place (Law 3)
/// instead of an inline OR-list per screen.
extension UserRolePresentationCapabilities on UserRole {
  /// Every non-customer role — the admin gateway's role-router whitelist.
  bool get isBackOfficeRole => this != UserRole.customer;

  /// Owner/manager only — the dead-letter-queue link on Home.
  bool get canViewDeadLetterQueue =>
      this == UserRole.owner || this == UserRole.manager;
}

/// json_serializable converter for [UserRole]: an unknown or missing role
/// string falls back to [UserRole.customer].
///
/// B3 P2 (finding 2.7): a `@JsonConverter` (rather than
/// `@JsonKey(unknownEnumValue: ...)`) lets the freezed factory annotate the
/// constructor parameter directly without the `invalid_annotation_target`
/// false positive — json_annotation 4.9.0 restricts `JsonKey` to
/// fields/getters only, while `JsonConverter` permits parameters.
class UserRoleConverter extends JsonConverter<UserRole, Object?> {
  const UserRoleConverter();

  @override
  UserRole fromJson(Object? json) {
    if (json == null) return UserRole.customer;
    return UserRole.values.firstWhere(
      (r) => r.name == json.toString(),
      orElse: () => UserRole.customer,
    );
  }

  @override
  Object? toJson(UserRole object) => object.name;
}

@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  /// Gracefully falls back to the most human-readable identifier available
  String get displayTitle => username ?? name ?? displayName ?? email ?? id;

  const factory UserModel({
    required String id,
    String? email,
    String? name,
    String? displayName,
    String? username,
    String? phone,
    String? phoneNumber,
    @Default(0) int loyaltyPoints,
    String? stripeCustomerId,
    String? pushToken,
    @Default('starter') String tier,
    @Default(UserRole.customer)
    // B3 P2: `@UserRoleConverter()` gives a graceful customer fallback for
    // unknown/missing role strings — no annotation-target suppression needed.
    @UserRoleConverter()
    UserRole role,
    String? branchId,
    @Default(false) bool isOnline,
    @Default([]) List<String> assignedOrderIds,
    @DateTimeConverter() DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromDoc(Map<String, dynamic> json, String id) {
    final data = Map<String, dynamic>.from(json);
    data['id'] = id;
    final createdAt = timestampToDateTimeNullable(data['createdAt']);
    if (createdAt != null) {
      data['createdAt'] = createdAt.toIso8601String();
    }
    return UserModel.fromJson(data);
  }
}

/// WHY: Firestore Timestamps must be normalised to ISO-8601 strings
/// before passing to json_serializable's generated fromJson.
class DateTimeConverter extends JsonConverter<DateTime?, Object?> {
  const DateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    return timestampToDateTimeNullable(json);
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}
